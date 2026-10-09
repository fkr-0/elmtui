;;; == src/platform/driver.lisp ===============================================
;;; Platform Driver - Generic Application Runner
;;;============================================================================

(uiop:define-package :elmtui.platform.driver
  (:use #:cl)
  (:import-from :bt
    #:thread #:thread-alive-p #:join-thread #:destroy-thread)
  (:import-from :log4cl
    #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.core.system-events
    #:make-appshutdown-systemevent
    #:make-terminalresized-systemevent
    #:make-cursorposition-systemevent)
  (:import-from :elmtui.core.event-types
    #:key-event)
  (:import-from :elmtui.pipeline #:full-view-pipeline)
  (:import-from :elmtui.core.globals
    #:*app-sender* #:*app-message-processor*)
  (:import-from :elmtui.core.focus
    #:get-current-focus
    #:make-focus-manager)
  (:import-from :elmtui.keymaps
    #:initialise
    #:process-key-event)
  (:import-from :elmtui.state.api #:get-path)
  (:import-from :elmtui.platform.api
    #:initialize-backend #:shutdown-backend #:render-and-present
    #:term-w #:term-h #:handle-backend-resize #:get-screen-dimensions
    #:flush-output #:get-cursor-position #:set-cursor-position #:clear-lines #:scroll-up #:scroll-down
    #:term-stream
    #:backend-input-device #:backend-input-source)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer
    #:compute-buffer-diff
    #:apply-diff-to-backend)
  (:import-from :elmtui.platform.backend.terminal
    #:terminal-instance-front-buffer
    #:terminal-instance-back-buffer)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:copy-virtual-buffer)
  (:import-from :elmtui.platform.tmux
    #:tmux-available-p
    #:prefill-backend-from-tmux
    #:save-tmux-capture
    #:restore-to-tmux-capture)
  (:import-from :cl-inputs.device.api)
  (:import-from :elmtui.runtime.protocol
    #:run-application
    #:get-component-instance)
  (:import-from :elmtui.runtime.effects
    #:run-commands-with-policy
    #:apply-update-effects
    #:reconcile-model-subscriptions
    #:clear-subscription-registry)
  (:import-from :elmtui.core.loop
    #:publish #:start-loop #:elm-stop-loop #:event-loop #:*shutdown-requested*)
  ;; (:import-from :elmtui.style-lib.api #:stylesheet) ; legacy
  (:import-from :elmtui.style.manager #:compute-active-stylesheet)
  (:import-from :elmtui.platform.input #:cl-inputs-token->event)
  (:import-from :bordeaux-threads #:mailbox)
  (:import-from :cl-events.channel #:->)
  (:import-from :cl-events.loop #:poll-until)
  (:import-from :cl-state.core
    #:*state-mutation-policy*
    #:state-mutation-forbidden)
  (:import-from :elmtui.core.event-channels #:channel-of)
  (:export #:run-app-platform
    #:driver-context #:make-driver-context
    #:driver-context-backend #:driver-context-device
    #:driver-context-input-source #:driver-context-publish-fn
    #:driver-context-input-thread #:driver-context-stop-flag
    #:start-driver-input-loop #:stop-driver-input-loop
    #:execute-render-command))
(in-package #:elmtui.platform.driver)

;;; ---------------------------------------------------------------------------
;;; == Driver Global State ==
;;; ---------------------------------------------------------------------------
;; These variables hold the driver-level state for the running application.
(declaim (type t *backend*))
(declaim (type (or null bt:thread) *input-thread*))
(declaim (type (or null function) *stop-input-fn*))
(declaim (type boolean *driver-initiated-shutdown-p*))
(declaim (type (or null elmtui.platform.backend.common.virtual-buffer:virtual-terminal-buffer) *previous-frame-buffer*))
(declaim (type t *current-app-model*)) ; Holds the application state object
(declaim (type list *root-viewport-id-path*)) ; e.g., '(:components :my-root-vp)
;;; ---------------------------------------------------------------------------
;;; Global state (driver-level)
;;; ---------------------------------------------------------------------------

(defvar *backend* nil
  "Current platform backend instance.
  Type: t
  Side-effects: Mutable global state.")

(defvar *input-thread* nil
  "Thread handling input events.
  Type: (or null bt:thread)
  Side-effects: Mutable global state.")

(defvar *stop-input-fn* nil
  "Function to stop the input thread.
  Type: (or null function)
  Side-effects: Mutable global state.")

(defvar *driver-initiated-shutdown-p* nil
  "T if driver requested shutdown.
  Type: boolean
  Side-effects: Mutable global state.")

(defvar *previous-frame-buffer* nil
  "Buffer from the previous frame for diffing, matches root viewport dimensions.
  Type: (or null elmtui.platform.backend.common.virtual-buffer:virtual-terminal-buffer)
  Side-effects: Mutable global state.")

(defvar *current-app-model* nil
  "Holds the current application model (state).
  Type: t
  Side-effects: Mutable global state.")

(defvar *root-viewport-id-path* nil
  "ID path of the root-viewport component.
  Type: list
  Side-effects: Mutable global state.")

(defvar *global-term-size* nil
  "Global terminal size, used for initial terminal dimensions.
  Type: t
  Side-effects: Mutable global state.")

(defvar *app-spec* nil
  "Application specification plist for the running app.
  Type: list
  Side-effects: Mutable global state.")

(defvar *last-ctx* nil
  "Last computed app context, used for rendering.
  Type: t
  Side-effects: Mutable global state.")

(defvar *focus-manager* nil
  "Holds the application's focus manager instance.")

(defvar *active-app-subscriptions* (make-hash-table :test 'equal)
  "Driver-managed active app subscriptions keyed by canonical descriptor.")

(defvar *preserve-underlay* nil
  "When true, render pipeline preserves prefilled terminal content under app drawing.")

(defvar *use-alternate-screen* nil
  "When true, run app rendering inside terminal alternate screen mode.")

(defvar *initial-render-done* nil
  "Tracks if the initial render has been performed after terminal size and cursor position are known.")

(defvar *startup-presentation-deferred* nil
  "Defer painting until startup events have reserved terminal viewport rows.")

(defvar *last-cursor-pos* '(0 . 0)
  "Last known cursor position as a cons (row . col). Used for anchoring.")

(defparameter +runtime-startup-phases+ '(:booting :awaiting-terminal-info :running :shutting-down)
  "Allowed startup/runtime phase values for the driver lifecycle.")

(defvar *runtime-phase* :booting
  "Current driver runtime phase.")

(defstruct (startup-message-buffer-state
             (:constructor make-startup-message-buffer-state
                 (&key (queue '()))))
  "Temporary queue for app messages that arrive before the real processor is bound."
  (queue '() :type list))

(defun startup-message-buffer-processor (state)
  "Return a processor function that buffers incoming messages into STATE."
  (lambda (msg)
    (push msg (startup-message-buffer-state-queue state))
    nil))

(defun startup-message-buffer-count (state)
  (length (startup-message-buffer-state-queue state)))

(defun drain-startup-message-buffer (state processor-fn)
  "Replay buffered messages in arrival order into PROCESSOR-FN and clear STATE."
  (let ((buffered (nreverse (startup-message-buffer-state-queue state))))
    (setf (startup-message-buffer-state-queue state) nil)
    (dolist (msg buffered)
      (funcall processor-fn msg))
    (length buffered)))

(defun %set-runtime-phase (next-phase &key reason)
  "Transition runtime phase to NEXT-PHASE with optional REASON for diagnostics."
  (unless (member next-phase +runtime-startup-phases+)
    (error "DRIVER: Invalid runtime phase transition target: ~S" next-phase))
  (let ((old-phase *runtime-phase*))
    (setf *runtime-phase* next-phase)
    (log-debug "DRIVER: runtime phase ~S -> ~S~@[ (~A)~]" old-phase next-phase reason))
  *runtime-phase*)

;;; ---------------------------------------------------------------------------
;;; == Application Entry Point ==
;;; ---------------------------------------------------------------------------
;; Method for elmtui.runtime.protocol:run-application
(defmethod elmtui.runtime.protocol:run-application ((app-spec list)
                                                     &key (backend-type :tty)
                                                     platform-options)
  "Entry point for running an application from an APP-SPEC plist."
  (declare (type list app-spec platform-options)
    (type keyword backend-type))
  (log:info "DRIVER: run-application called for ~S with backend ~A."
    (getf app-spec :name) backend-type)
  (run-app-platform app-spec
    :backend-type backend-type
    :platform-options platform-options))

(defun %resolve-generated-runner (app-name)
  "Resolve DEFAPPLICATION-generated RUN-<APP-NAME> function symbol."
  (let* ((runner-name (format nil "RUN-~A" app-name))
         (runner-sym (intern runner-name (symbol-package app-name))))
    (and (fboundp runner-sym) runner-sym)))

(defmethod elmtui.runtime.protocol:run-application ((app-spec symbol)
                                                     &key (backend-type :tty)
                                                     platform-options)
  "Dispatch symbolic app specs via generated DEFAPPLICATION runner."
  (let ((runner (%resolve-generated-runner app-spec)))
    (unless runner
      (error "RUN-APPLICATION: no generated runner found for app symbol ~S" app-spec))
    (funcall runner :platform backend-type :platform-options platform-options)))

(defmethod elmtui.runtime.protocol:run-application ((app-spec standard-object)
                                                     &key (backend-type :tty)
                                                     platform-options)
  "Dispatch app instances via their class name runner.
This keeps compatibility with older examples that pass app instances."
  (let ((app-name (class-name (class-of app-spec))))
    (unless (symbolp app-name)
      (error "RUN-APPLICATION: cannot resolve symbolic app name from class ~S"
             (class-of app-spec)))
    (elmtui.runtime.protocol:run-application app-name
                                             :backend-type backend-type
                                             :platform-options platform-options)))


;;; ---------------------------------------------------------------------------
;;; == Backend Initialization Utilities ==
;;; ---------------------------------------------------------------------------

(defun initialize-backend-with-publish-fn (BACKEND-TYPE TTY-PATH PUBLISH-FN &key (initial-clear t) (device nil))
  "Initialize the backend with a publish function.
  Arguments:
    BACKEND-TYPE (keyword): The backend type, e.g., :terminal.
    TTY-PATH (or string null): Path to the TTY device, or NIL.
    PUBLISH-FN (function): Function to publish events.
  Returns:
    (t): The initialized backend instance.
  Example:
    (initialize-backend-with-publish-fn :terminal \"/dev/tty\" #'my-publish)
  Type: (keyword, (or string null), function) => t
  Side-effects: May initialize hardware or OS resources."
  ;; Calls the platform API to initialize the backend with the given publish function.
  (declare (type keyword backend-type)
    (type (or string null) tty-path)
    (type function publish-fn))
  (elmtui.platform.api:initialize-backend backend-type :publish-fn publish-fn :tty-path tty-path :initial-clear initial-clear :device device))

;;; ---------------------------------------------------------------------------
;;; == Application State Bootstrap ==
;;; ---------------------------------------------------------------------------
(defvar *frame-render-lock* (bt:make-lock "elmtui frame rendering")
  "Serialize complete frames across startup and event-consumer threads.")

(defun %render-frame (ctx)
  (bt:with-lock-held (*frame-render-lock*)
    (full-view-pipeline ctx)))

(defun initialize-app-model (app-spec)
  (declare (type list app-spec))
  (let* (
          ;; Extract required functions and root viewport ID from app-spec
          (init-fn (getf app-spec :init-fn))
          (update-fn (getf app-spec :update-fn)) ; Keep for validation, though not directly used here
          (view-fn (getf app-spec :view-fn))     ; Keep for validation
          (root-viewport-id (getf app-spec :root-viewport-id)))
    ;; Validate that required functions are present and of correct type
    (unless (and (typep init-fn 'function)
              (typep update-fn 'function)
              (typep view-fn 'function))
      (error "App spec missing or has invalid types for required functions: :init-fn, :update-fn, :view-fn. Got init: ~S, update: ~S, view: ~S" init-fn update-fn view-fn))
    ;; Validate root viewport id
    (unless (keywordp root-viewport-id)
      (error "App spec missing or has invalid type for :root-viewport-id. Got: ~S" root-viewport-id))

    ;; Set global root viewport path
    (setf *root-viewport-id-path* (list :components root-viewport-id))
    (log:info "DRIVER: Initializing application model for ~A... Root Viewport ID: ~A"
      (getf app-spec :name) root-viewport-id)
    (log:info "Running init-fn ~S for app-spec ~S" init-fn app-spec)
    ;; Call the application's init function to get the initial model and commands
    (let ((cli-args (getf app-spec :cli-args)))
      (multiple-value-bind (initial-model initial-cmds)
          (if cli-args
              (funcall init-fn :cli-args cli-args)
              (funcall init-fn))
      ;; Store the initial model in global state
      (setf *current-app-model* initial-model
            elmtui.core.globals:*app-state* initial-model)
      ;; Set up the global app message processor lambda
      (setf elmtui.core.globals:*app-message-processor*
        (lambda (msg)
          (log:debug "DRIVER: *app-message-processor* received ~S" msg)
          ;; Ignore messages once shutdown has been requested to prevent double-appshutdown.
          (unless elmtui.core.loop:*shutdown-requested*
          ;; Handle quit request
          (if (and (listp msg) (eq (car msg) :app-quit-requested))
            (let ((update-fn (getf app-spec :update-fn)))
              (log:info "DRIVER: Quit requested. Running appshutdown cleanup.")
              (when update-fn
                (handler-case
                  (multiple-value-bind (next-model commands)
                    (funcall update-fn '(:appshutdown) *current-app-model*)
                    (setf *current-app-model* next-model
                          elmtui.core.globals:*app-state* next-model)
                    (run-commands-with-policy
                     commands
                     :render-command-fn (lambda (cmd)
                                          (handler-case
                                              (execute-render-command cmd *backend*)
                                            (error (condition)
                                              (log-warn "DRIVER: shutdown render cleanup failed: ~A"
                                                        condition))))))
                  (error (e)
                    (log-warn "DRIVER: appshutdown cleanup failed: ~A" e))))
              (log:info "DRIVER: Setting *shutdown-requested* flag.")
              (setf elmtui.core.loop:*shutdown-requested* t))
            ;; Otherwise, process the message with update-fn and command processor
            (let ((update-fn (getf app-spec :update-fn))
                   (cmd-proc-fn (getf app-spec :command-processor-fn))
                   (message-queue (getf app-spec :message-queue))
                   (app-cfg-for-cmd (gethash (getf app-spec :name) elmtui.core.globals:*applications*)))
              (multiple-value-bind (next-model commands)
                (funcall update-fn msg *current-app-model*)
                ;; Update global model
                (setf *current-app-model* next-model
                      elmtui.core.globals:*app-state* next-model)
                ;; Check for shutdown flag in model
                (when (get-path '(:should-quit) next-model)
                  (log:info "DRIVER: :should-quit flag is true in model. Setting *shutdown-requested*.")
                  ;; Run appshutdown cleanup on model-driven exit as well, so
                  ;; root-viewport and other components can restore terminal state.
                  (handler-case
                      (multiple-value-bind (shutdown-model shutdown-commands)
                          (funcall update-fn '(:appshutdown) next-model)
                        (setf *current-app-model* shutdown-model
                              elmtui.core.globals:*app-state* shutdown-model
                              next-model shutdown-model)
                        (run-commands-with-policy
                         shutdown-commands
                         :render-command-fn (lambda (cmd)
                                              (handler-case
                                                  (execute-render-command cmd *backend*)
                                                (error (condition)
                                                  (log-warn "DRIVER: model shutdown render cleanup failed: ~A"
                                                            condition))))))
                    (error (e)
                      (log-warn "DRIVER: model-driven appshutdown cleanup failed: ~A" e)))
                  (setf elmtui.core.loop:*shutdown-requested* t))
                ;; Runtime effect manager: command execution + subscription refresh.
                (handler-case
                    (apply-update-effects
                     :commands commands
                     :render-command-fn (lambda (cmd)
                                          (handler-case (execute-render-command cmd *backend*)
                                            (error (e) (log-warn "DRIVER: render command failed: ~A" e))))
                     :command-processor-fn cmd-proc-fn
                     :message-queue message-queue
                     :model next-model
                     :app-config app-cfg-for-cmd
                     :state-mutation-policy
                     (if (eq (getf app-spec :state-semantics) :strict-elm)
                         :forbid
                         :allow)
                     :subscriptions-reconciler (lambda (model)
                                               (%refresh-app-subscriptions app-spec model)))
                  (state-mutation-forbidden (condition)
                    (error condition))
                  (error (e)
                    (log-warn "DRIVER: apply-update-effects failed: ~A" e)))

                ;; During terminal bootstrap, wait for both geometry and cursor
                ;; before presenting; scroll reservation must precede the
                ;; first frame or its cells will be stranded in scrollback.
                (unless (or elmtui.core.loop:*shutdown-requested*
                            *startup-presentation-deferred*)
                  (let ((ctx (make-context-from-spec app-spec next-model *backend*)))
                    (handler-case
                      (progn
                        (let ((elmtui.pipeline::*preserve-underlay* *preserve-underlay*))
                          (setf *last-ctx* (%render-frame ctx)))
                        (setf *previous-frame-buffer* (elmtui.contracts:ctx-front-buffer *last-ctx*))
                        (setf *initial-render-done* t))
                      (elmtui.contracts:pipeline-contract-violation (e)
                        (log:error "DRIVER: Pipeline contract violation ~A; keeping previous ctx." e)
                        (setf *last-ctx* (or *last-ctx* ctx)))
                      (state-mutation-forbidden (condition)
                        (error condition))
                      (error (e)
                        (log:error "DRIVER: Pipeline error ~A; keeping previous ctx." e)
                        (setf *last-ctx* (or *last-ctx* ctx))))))))))))
        (log:info "DRIVER: Initial model: ~S, initial commands: ~S" initial-model initial-cmds)
        (values initial-model initial-cmds)))))

;;; Helper: execute :render commands synchronously prior to view
(defun execute-render-command (cmd backend)
  (bt:with-lock-held (*frame-render-lock*) (%execute-render-command cmd backend)))

(defun %execute-render-command (cmd backend)
  "Execute a :render command against BACKEND. Format examples:
   (:render :clear rect)
   (:render :blank-viewport rect)
   (:render :scroll n)
   (:render :scroll-down n)
   (:render :scroll-up n)
   (:render :clear-below-cursor)
   (:render :clear-above-cursor)
   (:render :set-cursor row col)"
  (handler-case
    (let ((op (second cmd))
           (arg1 (third cmd))
           (arg2 (fourth cmd)))
      (case op
        (:clear
          (elmtui.platform.api:clear-screen backend arg1))
        (:blank-viewport
          (let* ((rect arg1)
                  (w (elmtui.view.geo:w rect))
                  (h (elmtui.view.geo:h rect))
                  (ox (elmtui.view.geo:x rect))
                  (oy (elmtui.view.geo:y rect)))
            (when (and (numberp w) (numberp h) (> w 0) (> h 0))
              (cond
                ((typep backend 'elmtui.platform.backend.terminal:terminal-instance)
              (elmtui.platform.api:clear-screen backend rect)
              (elmtui.platform.api:flush-output backend))
                ((typep backend 'elmtui.backend.faketerm:faketerm-instance)
                  (let ((stream (elmtui.backend.faketerm::faketerm-instance-stream backend))
                         (buffer (elmtui.backend.faketerm::faketerm-instance-screen-buffer backend)))
                    (when stream
                      (format stream "; BLANK_VIEWPORT Row: ~D Col: ~D Height: ~D Width: ~D~%"
                        oy ox h w)
                      (finish-output stream))
                    (elmtui.platform.api:fill-rectangle backend buffer oy ox h w :char #\Space)))
                ((fboundp 'elmtui.platform.api:clear-area)
                  (elmtui.platform.api:clear-area backend nil oy ox h w))
                (t
                  (log-warn "blank-viewport not implemented for backend ~S" backend)))
              ;; Physical erasure invalidates any previously presented virtual
              ;; front frame. The next pass must repaint all visible cells.
              (setf *previous-frame-buffer* nil
                    *initial-render-done* nil))))
        (:scroll
          (elmtui.platform.api:scroll backend (or arg1 -1)))
        (:scroll-down
          (dotimes (row (max 0 (or arg1 1))) (elmtui.platform.api:scroll backend 1)))
        (:scroll-up
          (dotimes (row (max 0 (or arg1 1))) (elmtui.platform.api:scroll backend -1)))
        (:clear-below-cursor
          (if (fboundp 'elmtui.platform.api:clear-below-cursor)
            (elmtui.platform.api:clear-below-cursor backend)
            (log-warn "clear-below-cursor not implemented for backend ~S" backend)))
        (:clear-above-cursor
          ;; Clear above cursor by moving to top and clearing down to cursor
          (let ((current-pos (elmtui.platform.api:get-cursor-position backend)))
            (when current-pos
              (elmtui.platform.api:set-cursor-position backend 0 0)
              (if (fboundp 'elmtui.platform.api:clear-below-cursor)
                (elmtui.platform.api:clear-below-cursor backend)
                (elmtui.platform.api:clear-screen backend))
              (elmtui.platform.api:set-cursor-position backend (car current-pos) (cdr current-pos)))))
        (:set-cursor
          (elmtui.platform.api:set-cursor-position backend (or arg1 1) (or arg2 1)))
        (otherwise (log-warn "Unknown :render op ~S" op))))
    (error (e) (log-warn "Render command failed: ~A" e))))

(defun force-render-current-frame (app-spec)
  "Render the current app model immediately using APP-SPEC."
  (when (and *backend* *current-app-model*)
    (let ((ctx (make-context-from-spec app-spec *current-app-model* *backend*)))
      (handler-case
        (progn
          (let ((elmtui.pipeline::*preserve-underlay* *preserve-underlay*))
            (setf *last-ctx* (%render-frame ctx)))
          (setf *previous-frame-buffer* (elmtui.contracts:ctx-front-buffer *last-ctx*))
          (setf *initial-render-done* t))
        (elmtui.contracts:pipeline-contract-violation (e)
          (log:error "DRIVER: Pipeline contract violation during force render ~A; keeping previous ctx." e)
          (setf *last-ctx* (or *last-ctx* ctx)))
        (error (e)
          (log:error "DRIVER: Pipeline error during force render ~A; keeping previous ctx." e)
          (setf *last-ctx* (or *last-ctx* ctx)))))))
                                        ;(log:info "DRIVER: Initial model: ~S, initial commands: ~S" initial-model initial-cmds)
                                        ;(values initial-model initial-cmds))))

(defun %emit-startup-terminalresized (backend proc)
  "Emit one startup :terminalresized message through PROC. Always emits."
  (let ((width 80)
         (height 24))
    ;; Prefer cached terminal dimensions first; other backends use the explicit probe below.
    (when (typep backend 'elmtui.platform.backend.terminal:terminal-instance)
      (let ((cached-w (term-w backend))
            (cached-h (term-h backend)))
        (when (and (numberp cached-w) (numberp cached-h)
                   (> cached-w 0) (> cached-h 0))
          (setf width cached-w
                height cached-h))))
    (when (or (<= width 0) (<= height 0))
      (handler-case
          (multiple-value-bind (w h) (get-screen-dimensions backend)
            (when (and (numberp w) (numberp h) (> w 0) (> h 0))
              (setf width w
                    height h)))
        (error (e)
          (log-warn "DRIVER: Failed to read screen dimensions during startup: ~A" e))))
    (funcall proc `(:terminalresized :width ,width :height ,height))
    t))

(defun %emit-startup-cursorposition (backend proc)
  "Emit one startup :cursorposition message through PROC. Always emits."
  (let ((row 0)
         (col 0))
    ;; Reuse cached cursor from terminal backend when available.
    (when
      (typep backend 'elmtui.platform.backend.terminal:terminal-instance)
      (let
        ((cached-row (elmtui.platform.backend.terminal::terminal-instance-cursor-start-row backend))
          (cached-col
            (elmtui.platform.backend.terminal::terminal-instance-cursor-start-col backend)))
        (when (and (numberp cached-row) (>= cached-row 0)) (setf row cached-row))
        (when (and (numberp cached-col) (>= cached-col 0)) (setf col cached-col))))
    (setf *last-cursor-pos* (cons row col))
    (funcall proc `(:cursorposition :col ,(1+ col) :row ,(1+ row)))
    t))

(defun process-initial-commands (cmds app-spec)
  "Process a list of initial commands for an application, using an app-specific processor if available.
CMDs: list of commands to process.
PUBLISH-FN: function to publish messages (unused here, but may be used in future).
APP-SPEC: property list describing the app, must contain :command-processor-fn, :message-queue, and :name."
  (declare (type list cmds) (type list app-spec))
  (when (and cmds (listp cmds))
    (log:debug "DRIVER: Processing initial commands...")
    (destructuring-bind (&key command-processor-fn message-queue name &allow-other-keys) app-spec
      (let* ((cmd-proc-fn command-processor-fn)
              (msg-queue message-queue)
              (app-cfg-for-cmd (when name
                                 (gethash name elmtui.core.globals:*applications*))))
        (loop for cmd in cmds
          do (run-commands-with-policy
              (list cmd)
              :command-processor-fn cmd-proc-fn
              :message-queue msg-queue
              :model *current-app-model*
              :app-config app-cfg-for-cmd))))))

(defun %unwrap-quoted-form (form)
  "Recursively unwrap nested (quote ...) forms."
  (if (and (consp form)
        (eq (first form) 'quote)
        (consp (rest form))
        (null (cddr form)))
      (%unwrap-quoted-form (second form))
      form))

(defun %resolve-subscriptions-fn (app-spec)
  "Resolve the :subscriptions-fn designator from APP-SPEC into a function."
  (let ((raw (%unwrap-quoted-form (getf app-spec :subscriptions-fn))))
    (cond
      ((null raw)
        (lambda (model) (declare (ignore model)) nil))
      ((functionp raw) raw)
      ((and (symbolp raw) (fboundp raw))
        (symbol-function raw))
      ((and (consp raw) (eq (first raw) 'lambda))
        (coerce raw 'function))
      (t
        (log-warn "DRIVER: Invalid subscriptions function designator ~S, ignoring subscriptions." raw)
        (lambda (model) (declare (ignore model)) nil)))))

(defun %clear-app-subscriptions ()
  "Cancel and clear all active driver-managed subscriptions."
  (clear-subscription-registry *active-app-subscriptions*))

(defun %refresh-app-subscriptions (app-spec model)
  "Arm subscriptions only after initial terminal geometry and presentation."
  (unless *startup-presentation-deferred*
    (let ((subs-fn (%resolve-subscriptions-fn app-spec))
          (*state-mutation-policy*
            (if (eq (getf app-spec :state-semantics) :strict-elm)
                :forbid
                :allow)))
      (reconcile-model-subscriptions subs-fn model *active-app-subscriptions*))))
;;; ---------------------------------------------------------------------------
;;; == Context Construction ==
;;; ---------------------------------------------------------------------------

(defstruct driver-context
  backend
  device
  input-source
  publish-fn
  (input-thread nil)
  (stop-flag nil))

(defvar *driver-context* nil
  "Driver-level context that ties the backend to a cl-inputs device and publish function.")

(defun driver-context-input-loop (ctx)
  "Main loop that pulls tokens, converts them, and publishes the result.
   Input mode lifecycle is owned by cl-inputs input-source setup/teardown."
  (let* ((backend (driver-context-backend ctx))
          (device (or (driver-context-device ctx)
                    (and backend (backend-input-device backend))))
          (source (driver-context-input-source ctx)))
    (declare (ignore device))
    (unless source
      (error "DRIVER: Missing cl-inputs input-source in driver context."))
    (loop
      (when (or (driver-context-stop-flag ctx)
              elmtui.core.loop:*shutdown-requested*)
        (return))
      (let ((token (cl-inputs.loop:next-token source :timeout 0.1)))
        (when token
          (let ((event (cl-inputs-token->event token)))
            (when (and event (driver-context-publish-fn ctx))
              (funcall (driver-context-publish-fn ctx) event))))))))

(defun start-driver-input-loop (ctx)
  "Begin the driver input thread; returns the thread object."
  (unless (and ctx (driver-context-input-source ctx))
    (error "DRIVER: start-driver-input-loop requires a cl-inputs input-source."))
  (let ((thread (bt:make-thread (lambda ()
                                  (driver-context-input-loop ctx))
                  :name "elmtui.driver.input")))
    (setf (driver-context-input-thread ctx) thread)
    thread))

(defun stop-driver-input-loop (ctx)
  "Signal the driver input loop to stop and leave the stop flag set until teardown completes."
  (when ctx
    (setf (driver-context-stop-flag ctx) t)
    (let ((thread (driver-context-input-thread ctx)))
      (when (and thread (bt:thread-alive-p thread))
        (handler-case
            (bt:interrupt-thread thread (lambda () (log:info "Driver input thread interrupted.")))
          (error (condition)
            (log-warn "DRIVER: input-thread interrupt failed during teardown: ~A" condition)))
        ;; Do not hard-block on JOIN here: input thread may be in a device read path.
        ;; Shutdown will poll and force-destroy as a bounded fallback.
        ;; Keep the stop flag set so the loop can observe it on the next timeout wakeup.
        ))
    ctx))

(defun make-context-from-spec (app-spec state backend)
  "Creates an app-context struct from an app-spec, the current state, and the backend."
  (let ((w (elmtui.platform.api:term-w backend))
         (h (elmtui.platform.api:term-h backend)))
    ;; Ensure the previous frame buffer matches the current terminal size

    ;; Construct and return the app context struct for rendering and event handling
    (elmtui.contracts:make-app-context
      :state state
      :view-fn (getf app-spec :view-fn)
      :backend backend
      :stylesheet (compute-active-stylesheet state)
      :viewport-rect (elmtui.view.geo:make-rectangle
                       :pos (elmtui.view.geo:make-pos :x 0 :y 0) :size (elmtui.view.geo:make-size :w w :h h))
      :front-buffer *previous-frame-buffer*)))

;;; ---------------------------------------------------------------------------
;;; == Platform Shutdown Logic ==
;;; ---------------------------------------------------------------------------

(defun %restore-saved-tmux-capture-on-backend (backend)
  "Restore saved tmux capture onto BACKEND and present it."
  (when (and backend
          (elmtui.platform.tmux:has-saved-tmux-capture)
          (terminal-instance-front-buffer backend))
    (let* ((front (terminal-instance-front-buffer backend))
            (before (and front (copy-virtual-buffer front))))
      (when (and before front)
        (elmtui.platform.tmux:restore-to-tmux-capture front)
        (let ((diff (compute-buffer-diff before front)))
          (handler-case
              (apply-diff-to-backend diff backend 0 0)
            (error (condition)
              (log-warn "DRIVER: tmux capture restore presentation failed: ~A" condition))))
        (setf (terminal-instance-back-buffer backend) (copy-virtual-buffer front))))
    t))

(defun %set-alternate-screen-mode (backend enabled-p)
  "Enter or leave terminal alternate screen mode for a maintained terminal backend.
Failures are logged and returned as NIL so shutdown can remain best-effort."
  (when (typep backend 'elmtui.platform.backend.terminal:terminal-instance)
    (let* ((seq (if enabled-p
                    (format nil "~C[?1049h~C[H" #\Escape #\Escape)
                    (format nil "~C[?1049l~C[1G" #\Escape #\Escape)))
           (dev (backend-input-device backend))
           (stream (term-stream backend)))
      (handler-case
          (cond
            ((and dev (fboundp 'cl-inputs.device.api:device-write-bytes))
             (let ((bytes (make-array (length seq) :element-type '(unsigned-byte 8))))
               (loop for i from 0 below (length seq)
                     do (setf (aref bytes i) (char-code (char seq i))))
               (cl-inputs.device.api:device-write-bytes dev bytes 0 (length bytes))
               (flush-output backend)
               t))
            ((and (streamp stream) (output-stream-p stream))
             (write-string seq stream)
             (finish-output stream)
             t)
            (t nil))
        (error (condition)
          (log-warn "DRIVER: alternate-screen transition failed: ~A" condition)
          nil)))))

(defun shutdown-platform ()
  (log:info "DRIVER: Shutting down platform...")
  (%set-runtime-phase :shutting-down :reason "shutdown-platform called")
  (setf *startup-presentation-deferred* nil)
  (%clear-app-subscriptions)
  ;; Stop the input thread if a stop function is available
  (when *stop-input-fn*
    (log-info
      "Calling stop-input-thread function: ~A"
      (funcall *stop-input-fn*))
    (setf *stop-input-fn* nil)
    (setf *driver-context* nil)
    (log-info "Stop input function called, input thread should stop."))
  ;; Wait for the input thread to terminate, forcibly destroy if needed
  (when (and *input-thread* (bt:thread-alive-p *input-thread*))
    (log:info "DRIVER: Waiting for input thread to terminate...")
    ;; Bordeaux threads does not provide a portable join timeout. Delegate the
    ;; bounded liveness probe to the shared runtime poller.
    (let ((stopped-p
            (poll-until
             (lambda ()
               (not (and *input-thread*
                         (bt:thread-alive-p *input-thread*))))
             :timeout 0.2
             :interval 0.01)))
      (if stopped-p
          (log:info "DRIVER: Input thread terminated gracefully.")
          (progn
            (log:warn "DRIVER: Input thread did not terminate within 200ms. Forcing termination.")
            (when *input-thread*
              (handler-case
                  (bt:destroy-thread *input-thread*)
                (error (condition)
                  (log-warn "DRIVER: forced input-thread teardown failed: ~A" condition)))))))
    (setf *input-thread* nil))

  ;; Attempt to clean up the root viewport instance if present
  (when (and *root-viewport-id-path* *current-app-model* *backend*)
    (let* ((rv-instance (get-component-instance *root-viewport-id-path* *current-app-model*)))
      (when rv-instance
        (log:debug "DRIVER: Root viewport cleanup for instance: ~S" rv-instance)
        (let ((saved-row (car *last-cursor-pos*))
              (saved-col (cdr *last-cursor-pos*)))
          (when (and (integerp saved-row) (integerp saved-col))
            (handler-case
                (set-cursor-position *backend* saved-row saved-col)
              (error (condition)
                (log-warn "DRIVER: cursor restore failed during teardown: ~A" condition))))))))

  ;; Shutdown the backend and clear the backend global
  (when *backend*
    ;; Restore tmux capture before shutdown (seamless return to original state)
    ;; Skip this when alternate screen was enabled; terminal will restore main screen.
    (when (and (not *use-alternate-screen*)
               (elmtui.platform.tmux:has-saved-tmux-capture))
      (log-info "DRIVER: Restoring original tmux capture for seamless exit")
      (%restore-saved-tmux-capture-on-backend *backend*))

    (when *use-alternate-screen*
      (%set-alternate-screen-mode *backend* nil))

    (shutdown-backend *backend*)
    (setf *backend* nil)

    ;; Reset application and viewport; first-frame policy is inferred from context.
    (setf *current-app-model* nil
      elmtui.core.globals:*app-state* nil
      *root-viewport-id-path* nil)
    (log:info "DRIVER: Platform shutdown complete.")))

(defun run-app-platform (APP-SPEC
                          &key (BACKEND-TYPE :tty)
                          (TTY-PATH #+os-unix "/dev/tty" #-os-unix nil)
                          (PLATFORM-OPTIONS nil)
                          &allow-other-keys)
  "Main entry point for running an application on the platform.
  Arguments:
    APP-SPEC (list): Application specification plist.
    BACKEND-TYPE (keyword): Backend type, e.g., :terminal.
    TTY-PATH (or string null): Path to TTY device, or NIL.
    [Other platform options may be passed via &allow-other-keys.]
  Returns:
    NIL
  Example:
    (run-app-platform my-app-spec :backend-type :terminal)
  Type: (list, &key keyword (or string null)) => nil
  Side-effects: Initializes backend, starts input thread, runs app loop, cleans up on shutdown."
  (declare (type list app-spec)
    (type keyword backend-type)
    (type (or string null) tty-path))
  (log-info "Running RUN_APP_PLATFORM")
  ;; Reset all driver-level state variables at the start.
  (setf *app-spec* app-spec
    *backend* nil
    *input-thread* nil
    *stop-input-fn* nil
    *driver-initiated-shutdown-p* nil
    *previous-frame-buffer* nil
    *current-app-model* nil
    *root-viewport-id-path* nil
    *initial-render-done* nil
    *startup-presentation-deferred* t
    *focus-manager* nil
    *preserve-underlay* nil
    *use-alternate-screen* nil
    *runtime-phase* :booting
    elmtui.core.globals:*app-state* nil
    elmtui.core.globals:*app-message-processor* nil)
  (clrhash *active-app-subscriptions*)
  ;; Clear any tmux capture from a previous run so restore targets fresh content.
  (elmtui.platform.tmux:clear-saved-tmux-capture)
  (log-info "Globals reset for new application run.")

  (let ((initial-commands nil)
         (startup-buffer-state (make-startup-message-buffer-state))
         (prefill-from-tmux (getf platform-options :prefill-from-tmux))
         (tmux-prefill-mode (getf platform-options :tmux-prefill-mode :pane))
         (use-alternate-screen (getf platform-options :use-alternate-screen nil)))
    (setf *preserve-underlay* (and prefill-from-tmux (tmux-available-p)))
    (setf *use-alternate-screen* use-alternate-screen)
    (unwind-protect
      (progn
        ;; 1. Start the event loop. This sets up channels and the consumer thread.
        (start-loop)
        ;; Install a bootstrap processor so backend events emitted during startup are not lost.
        (setf elmtui.core.globals:*app-message-processor*
              (startup-message-buffer-processor startup-buffer-state))
        (log-info "Event loop and channels are active.")

        ;; 2. Now that channels exist, set up all event subscriptions.
        (elmtui.keymaps:initialise)
        (setf *focus-manager* (make-focus-manager))
        ;; (elmtui.core.loop:subscribe
        ;;  :key-event
        ;;  (lambda (evt)
        ;;    (unless (elmtui.keymaps:process-key-event
        ;;             evt *focus-manager*
        ;;             :app-state *current-app-model*
        ;;             :dispatch-fn #'publish)
        ;;      (publish (list :raw-key evt)))))
        ;; (elmtui.core.loop:subscribe
        ;;  :terminal-resized
        ;;  (lambda (evt)
        ;;    (log:info "DRIVER: Terminal resized event received: ~S" evt)
        ;;    (setf *got-initial-terminal-resized* t)
        ;;    (when (and *current-app-model* *backend* *app-spec* (not *initial-render-done*))
        ;;      (setf *initial-render-done* t)
        ;;      (setf *last-ctx* (full-view-pipeline (make-context-from-spec *app-spec* *current-app-model* *backend*)))
        ;;      (setf *previous-frame-buffer* (elmtui.contracts:ctx-front-buffer *last-ctx*)))))
        ;; (elmtui.core.loop:subscribe
        ;;  :cursorpositionchanged
        ;;  (lambda (evt)
        ;;    (log:debug "DRIVER: cursor position changed event received: ~S" evt)
        ;;    (setf *got-initial-cursor-position* t)
        ;;    (handler-case
        ;;        (let* ((row (getf evt :row 0)) (col (getf evt :col 0)))
        ;;          (setf *last-cursor-pos* (cons row col)))
        ;;      (error () (setf *last-cursor-pos* '(0 . 0))))))
        (log-info "System event subscriptions are set up.")
        ;; 3. Initialize the backend, passing the now-ready publish function.
        (log-info "DRIVER: Initializing ~A backend with TTY path: ~A" backend-type tty-path)
        (let ((device (cl-inputs:make-device :tty)))
          (handler-case
            (setf *backend* (initialize-backend-with-publish-fn
                              backend-type
                              tty-path
                              (lambda (ev) (publish ev))
                              :initial-clear nil
                              :device device))
            (error (e)
              (log-error "DRIVER: Backend initialization failed: ~A" e)
              (error "Failed to initialize backend ~A: ~A" backend-type e)))
          (unless *backend*
            (error "Backend initialization returned NIL for ~A" backend-type))

          (when *use-alternate-screen*
            (%set-alternate-screen-mode *backend* t))

          ;; Query initial terminal state in a device-independent manner
          (log-debug "DRIVER: Querying initial terminal state...")
          ;; (handler-case
          ;;   (multiple-value-bind (w h) (elmtui.platform.api:get-screen-dimensions *backend*)
          ;;     (log-debug "DRIVER: Screen dimensions: ~Ax~A" w h)
          ;;     (when (and w h (> w 0) (> h 0))
          ;;       (publish (make-terminalresized-systemevent :width w :height h))))
          ;;   (error (e)
          ;;     (log-warn "DRIVER: Failed to get screen dimensions, using defaults: ~A" e)
          ;;     ;; Fallback to default values
          ;;     (publish (make-terminalresized-systemevent :width 80 :height 24))))

          ;; (handler-case
          ;;   (multiple-value-bind (col row) (elmtui.platform.api:get-cursor-position *backend*)
          ;;     (log-debug "DRIVER: Cursor position: ~Ax~A" col row)
          ;;     (when (and col row (>= col 0) (>= row 0))
          ;;       (publish (make-cursorposition-systemevent :col col :row row))))
          ;;   (error (e)
          ;;     (log-warn "DRIVER: Failed to get cursor position, using defaults: ~A" e)
          ;;     ;; Fallback to default position
          ;;     (publish (make-cursorposition-systemevent :col 0 :row 0))))

          (when (and prefill-from-tmux
                  (tmux-available-p))
            (let ((snapshot (prefill-backend-from-tmux *backend* :mode tmux-prefill-mode)))
              (when snapshot
                ;; Save for restore on exit (seamless return to original state)
                (save-tmux-capture snapshot)
                ;; Prefill is a committed front frame for incremental diff.
                (setf *previous-frame-buffer* snapshot))))

          ;; 4. Initialize the application model. This sets *app-message-processor*.
          (multiple-value-bind (im ic) (initialize-app-model app-spec)
            (log:debug "DRIVER: Initial model: ~S, initial commands: ~S..binding" im ic)
            (setf *current-app-model* im)
            (setf initial-commands ic))
          (let ((proc elmtui.core.globals:*app-message-processor*))
            (when proc
              (let ((replayed (drain-startup-message-buffer startup-buffer-state proc)))
                (when (> replayed 0)
                  (log-info "DRIVER: Replayed ~D startup message(s)." replayed)))))
          (log-info "Application model and message processor are initialized.")
          (%refresh-app-subscriptions app-spec *current-app-model*)

          ;; Ensure startup terminal signals flow through the canonical app update path.
          (%set-runtime-phase :awaiting-terminal-info :reason "model initialized")
          (let ((proc elmtui.core.globals:*app-message-processor*))
            (when proc
              ;; Establish the anchor before assigning viewport geometry so the
              ;; first size update reserves the physical rows before painting.
              (%emit-startup-cursorposition *backend* proc)
              (%emit-startup-terminalresized *backend* proc))
            (%set-runtime-phase :running :reason "startup terminal signals delivered")
            (setf *startup-presentation-deferred* nil))

          ;; Always produce an initial frame even when startup messages do not trigger one.
          (unless *initial-render-done*
            (force-render-current-frame app-spec))
          ;; Do not start recurring timers while the initial viewport state
          ;; transaction or forced presentation is still in flight.
          (%refresh-app-subscriptions app-spec *current-app-model*)))

    ;; 5. Build the driver context and start the driver-managed input loop when the backend exposes cl-inputs handles.
    ;; Guarded by (when *backend* ...) so that a failed setup (nil backend) does not error here.
    (when *backend*
      (let ((device (backend-input-device *backend*))
             (input-source (backend-input-source *backend*))
             (event-handler (lambda (ev) (publish ev))))
        (log-info "DRIVER: Setting up input handling. Device: ~A, Input Source: ~A" device input-source)
        (unless input-source
          (error "DRIVER: Backend ~S must expose cl-inputs input-source for runtime loop." (type-of *backend*)))
        (let ((ctx (make-driver-context
                     :backend *backend*
                     :device device
                     :input-source input-source
                     :publish-fn event-handler)))
          (setf *driver-context* ctx
                *stop-input-fn* (lambda ()
                                  (handler-case
                                      (stop-driver-input-loop ctx)
                                    (error (condition)
                                      (log-warn "DRIVER: input-loop stop failed during teardown: ~A"
                                                condition)))

                                  t)
                *input-thread* (start-driver-input-loop ctx))
          (log-info "Driver input loop started: ~A" *input-thread*)))))

    ;; 6-7. Run application main loop with guaranteed terminal cleanup on any exit.
    (unwind-protect
      (progn
        (when initial-commands
          (process-initial-commands initial-commands app-spec))
        (log:info "Initial commands processed. Starting main wait loop.")
        ;; 7. Wait for shutdown signal through the shared runtime poller.
        (poll-until (lambda () elmtui.core.loop:*shutdown-requested*)
                    :interval 0.1)
        (log:info "DRIVER: Shutdown signal received, exiting loop."))
      ;; Cleanup: always executes even if an unhandled condition escapes the main loop.
      (shutdown-platform)
      (elm-stop-loop)
      (log:info "DRIVER: Application ~A has shut down." (getf app-spec :name)))))
