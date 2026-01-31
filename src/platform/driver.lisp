;;; == src/platform/driver.lisp ===============================================
;;; Platform Driver - Generic Application Runner
;;;============================================================================

(uiop:define-package :elmtui.platform.driver
  (:use #:cl)
  (:import-from :bt
    #:thread #:thread-alive-p #:join-thread #:destroy-thread)
  (:import-from :log4cl
    #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.app.system-events
    #:make-appshutdown-systemevent
    #:make-terminalresized-systemevent
    #:make-cursorposition-systemevent)
  (:import-from :elmtui.core.event-types
    #:key-event #:resize-event #:resize-event-width #:resize-event-height)
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
  (:import-from :elmtui.state.transactions #:apply-patches)
  (:import-from :elmtui.platform.api
    #:initialize-backend #:shutdown-backend #:render-and-present
    #:term-w #:term-h #:handle-backend-resize #:get-screen-dimensions
    #:flush-output #:get-cursor-position #:set-cursor-position #:clear-lines #:scroll-up #:scroll-down
    #:backend-input-device #:backend-input-source)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer
    #:*compute-buffer-diff-first-call*)
  (:import-from :elmtui.platform.tmux
    #:tmux-available-p
    #:prefill-backend-from-tmux)
  (:import-from :cl-inputs.device.api
    #:enable-raw-mode
    #:disable-raw-mode)
  (:import-from :elmtui.app.api #:run-application
    #:get-component-instance #:app-config-message-queue)
  (:import-from :elmtui.core.loop
    #:publish #:start-loop #:elm-stop-loop #:event-loop)
  (:import-from :elmtui.core.async
    #:interpret-cmd)
  (:import-from :elmtui.ui.widgets.root-viewport
    #:root-viewport)
  ;; (:import-from :elmtui.style-lib.api #:stylesheet) ; legacy
  (:import-from :elmtui.style.manager #:compute-active-stylesheet)
  (:import-from :elmtui.platform.input #:start-reader #:cl-inputs-token->event)
  (:import-from :bordeaux-threads #:mailbox)
  (:import-from :cl-events.channel #:->)
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

(defvar *initial-render-done* nil
  "Tracks if the initial render has been performed after terminal size and cursor position are known.")

(defvar *got-initial-terminal-resized* nil
  "Tracks if a :terminal-resized event has been received after startup.")

(defvar *got-initial-cursor-position* nil
  "Tracks if a :cursorpositionchanged event has been received after startup.")

(defvar *last-cursor-pos* '(0 . 0)
  "Last known cursor position as a cons (row . col). Used for anchoring.")

;; Bootstrap buffering for early system events before the real processor is ready
(defvar *real-app-message-processor* nil)
(defvar *bootstrap-event-queue* nil)

(defun %driver-bootstrap-processor (msg)
  "Temporary app-message processor used during bootstrap. Buffers events until
  the real processor is installed and both initial terminal-resized and
  cursor-position events have been observed."
  (log-info "Bootstrap processor received message: ~A" msg)
  (handler-case
    (progn
      ;; Track readiness flags from system messages
      (when (and (listp msg))
        (let ((tag (first msg)))
          (cond
            ((member tag '(:terminalresized :terminal-resized :TERMINALRESIZED :TERMINAL-RESIZED))
              (progn
                (setf *got-initial-terminal-resized* t)
                (log-info "Init term set") ))
            ((member tag '(:cursorpositionchanged :cursorposition :cursor-position :cursor-position-changed
                            :CURSORPOSITIONCHANGED :CURSORPOSITION :CURSOR-POSITION :CURSOR-POSITION-CHANGED))

              (progn
                (setf *got-initial-cursor-position* t)
                (log-info "Init term set") )))))

      ;; Buffer the message
      (push msg *bootstrap-event-queue*)

      ;; If the real processor is installed and both signals observed, flush
      (when (and *real-app-message-processor*
              *got-initial-terminal-resized*
              *got-initial-cursor-position*)
        (let ((events (nreverse *bootstrap-event-queue*)))
          (setf *bootstrap-event-queue* nil)
          (dolist (e events)
            (funcall *real-app-message-processor* e)))))
    (error (e)
      (log-error "Bootstrap processor error: ~A" e))))

;;; ---------------------------------------------------------------------------
;;; == Application Entry Point ==
;;; ---------------------------------------------------------------------------
;; Method for elmtui.app.api:run-application
(defmethod elmtui.app.api:run-application ((app-spec list)
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
    (multiple-value-bind (initial-model initial-cmds) (funcall init-fn)
      ;; Store the initial model in global state
      (setf *current-app-model* initial-model)
      ;; Set up the global app message processor lambda
      (setf elmtui.core.globals:*app-message-processor*
        (lambda (msg)
          (log:info "DRIVER: *app-message-processor* received ~S" msg)
          ;; Handle quit request
          (if (and (listp msg) (eq (car msg) :app-quit-requested))
            (let ((update-fn (getf app-spec :update-fn)))
              (log:info "DRIVER: Quit requested. Running appshutdown cleanup.")
              (when update-fn
                (handler-case
                  (multiple-value-bind (next-model commands)
                    (funcall update-fn '(:appshutdown) *current-app-model*)
                    (setf *current-app-model* next-model)
                    (let ((render-cmds (remove-if-not (lambda (c) (and (consp c) (eq (car c) :render))) commands)))
                      (dolist (rc render-cmds)
                        (ignore-errors (execute-render-command rc *backend*)))))
                  (error (e)
                    (log-warn "DRIVER: appshutdown cleanup failed: ~A" e))))
              (log:info "DRIVER: Setting *shutdown-requested* flag.")
              (setf elmtui.core.loop::*shutdown-requested* t))
            ;; Otherwise, process the message with update-fn and command processor
            (let ((update-fn (getf app-spec :update-fn))
                   (cmd-proc-fn (getf app-spec :command-processor-fn))
                   (message-queue (getf app-spec :message-queue))
                   (app-cfg-for-cmd (gethash (getf app-spec :name) elmtui.core.globals:*applications*)))
              (log-info "DRIVER: calling update")
              (multiple-value-bind (next-model commands)
                (funcall update-fn msg *current-app-model*)
                ;; Update global model
                (setf *current-app-model* next-model)
                (log-info "DRIVER: update phase done")
                ;; Check for shutdown flag in model
                (when (get-path '(:should-quit) next-model)
                  (log:info "DRIVER: :should-quit flag is true in model. Setting *shutdown-requested*.")
                  (setf elmtui.core.loop::*shutdown-requested* t))
                ;; Process commands if a command processor is present
                ;; Execute :render commands synchronously before view
                (let ((render-cmds (remove-if-not (lambda (c) (and (consp c) (eq (car c) :render))) commands))
                       (other-cmds  (remove-if (lambda (c) (and (consp c) (eq (car c) :render))) commands)))
                  (dolist (rc render-cmds)
                    (ignore-errors (execute-render-command rc *backend*)))
                  ;; Process remaining commands via app's command processor
                  (when cmd-proc-fn
                    (dolist (c other-cmds)
                      (funcall cmd-proc-fn c message-queue next-model app-cfg-for-cmd))))

                ;; Render the current frame unless we're shutting down.
                (unless elmtui.core.loop::*shutdown-requested*
                  (log-info "DRIVER: Rendering frame.")
                  (let ((ctx (make-context-from-spec app-spec next-model *backend*)))
                    (handler-case
                      (progn
                        (setf *last-ctx* (full-view-pipeline ctx))
                        (setf *previous-frame-buffer* (elmtui.contracts:ctx-front-buffer *last-ctx*))
                        (setf *initial-render-done* t))
                      (elmtui.contracts:pipeline-contract-violation (e)
                        (log:error "DRIVER: Pipeline contract violation ~A; keeping previous ctx." e)
                        (setf *last-ctx* (or *last-ctx* ctx)))
                      (error (e)
                        (log:error "DRIVER: Pipeline error ~A; keeping previous ctx." e)
                        (setf *last-ctx* (or *last-ctx* ctx)))))))))))
      (log:info "DRIVER: Initial model: ~S, initial commands: ~S" initial-model initial-cmds)
      (values initial-model initial-cmds))))

;;; Helper: execute :render commands synchronously prior to view
(defun execute-render-command (cmd backend)
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
                 (let ((elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t))
                   (let* ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer w h))
                          (back (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer w h))
                          (diff (elmtui.platform.backend.terminal.diff-renderer:compute-buffer-diff front back)))
                     (elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend diff backend oy ox)
                     (elmtui.platform.api:flush-output backend))))
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
                  (log-warn "blank-viewport not implemented for backend ~S" backend))))))
        (:scroll
          (elmtui.platform.api:scroll backend (or arg1 -1)))
        (:scroll-down
          (elmtui.platform.api:scroll backend (or arg1 1)))
        (:scroll-up
          (elmtui.platform.api:scroll backend (- (or arg1 1))))
        (:clear-below-cursor
          (if (fboundp 'elmtui.platform.api:clear-below-cursor)
            (elmtui.platform.api:clear-below-cursor backend)
            (log-warn "clear-below-cursor not implemented for backend ~S" backend)))
        (:clear-above-cursor
          ;; Clear above cursor by moving to top and clearing down to cursor
          (let ((current-pos (ignore-errors (elmtui.platform.api:get-cursor-position backend))))
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
          (setf *last-ctx* (full-view-pipeline ctx))
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

(defun synchronous-root-message (msg root-id)
  "Deliver MSG to the root component synchronously and apply resulting patches.
Returns T if rendering-related state changed enough to warrant a re-render."
  (when (and root-id *current-app-model*)
    (multiple-value-bind (patches commands)
      (elmtui.app::dispatch-to-root msg *current-app-model* root-id)
      (let ((changed (not (null patches))))
        (when patches
          (apply-patches *current-app-model* patches))
        (dolist (cmd commands)
          (when (and (consp cmd) (eq (first cmd) :render))
            (execute-render-command cmd *backend*)
            (setf changed t)))
        changed))))

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
          do (cond
               (cmd-proc-fn
                 (funcall cmd-proc-fn cmd msg-queue *current-app-model* app-cfg-for-cmd))
               (t
                 (interpret-cmd cmd))))))))
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
   This function ensures raw mode is properly enabled during input reading
   and disabled on cleanup, even if errors occur."
  (let* ((backend (driver-context-backend ctx))
          (device (or (driver-context-device ctx)
                    (and backend (backend-input-device backend))))
          (source (driver-context-input-source ctx)))
    (unless source
      (log-warn "DRIVER: No input source available for driver context; input loop exiting.")
      (return-from driver-context-input-loop nil))

    (when device
      ;; Enable raw mode before starting the input loop
      (enable-raw-mode device)
      (log-info "DRIVER: Raw mode enabled for input target: ~A" (type-of device)))

    (unwind-protect
      (loop
        (when (or (driver-context-stop-flag ctx)
                elmtui.core.loop::*shutdown-requested*)
          (return))
        (let ((token (cl-inputs.loop:next-token source :timeout 0.1)))
          (when token
            (let ((event (cl-inputs-token->event token)))
              (when (and event (driver-context-publish-fn ctx))
                (funcall (driver-context-publish-fn ctx) event)))))
        (sleep 0.01))
      ;; Cleanup: Always disable raw mode, even on error
      (when device
        (ignore-errors (disable-raw-mode device))
        (log-info "DRIVER: Raw mode disabled for input target")))))

(defun start-driver-input-loop (ctx)
  "Begin the driver input thread; returns the thread object."
  (let ((thread (bt:make-thread (lambda ()
                                  (driver-context-input-loop ctx))
                  :name "elmtui.driver.input")))
    (setf (driver-context-input-thread ctx) thread)
    thread))

(defun stop-driver-input-loop (ctx)
  "Signal the driver input loop to stop and wait for the thread."
  (when ctx
    (setf (driver-context-stop-flag ctx) t)
    (let ((thread (driver-context-input-thread ctx)))
      (when thread
        (bt:interrupt-thread thread (lambda () (log:info "Driver input thread interrupted.")))
        (bt:join-thread thread)
        (setf (driver-context-input-thread ctx) nil)))
    (setf (driver-context-stop-flag ctx) nil)
    ctx))

(defun make-context-from-spec (app-spec state backend)
  "Creates an app-context struct from an app-spec, the current state, and the backend."
  (let ((w (elmtui.platform.api:term-w backend))
         (h (elmtui.platform.api:term-h backend)))
    ;; Ensure the previous frame buffer matches the current terminal size
    (unless (and *previous-frame-buffer*
              (eql w (elmtui.platform.backend.common.virtual-buffer:buffer-width *previous-frame-buffer*))
              (eql h (elmtui.platform.backend.common.virtual-buffer:buffer-height *previous-frame-buffer*)))
      ;; If not, allocate a new buffer of the correct size
      (setf *previous-frame-buffer* (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer w h)))
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

(defun shutdown-platform ()
  (log:info "DRIVER: Shutting down platform...")
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
    (if (bt:join-thread *input-thread*) ; :timeout 0.5
      (log:info "DRIVER: Input thread terminated gracefully.")
      (progn
        (log:warn "DRIVER: Input thread failed to terminate in time. Forcing termination.")
        (when (bt:thread-alive-p *input-thread*)
          (bt:destroy-thread *input-thread*))))
    (setf *input-thread* nil))

  ;; Attempt to clean up the root viewport instance if present
  (when (and *root-viewport-id-path* *current-app-model* *backend*)
    (let* ((rv-instance (get-component-instance *root-viewport-id-path* *current-app-model*)))
      (when rv-instance
        ;; (Potential cleanup logic for root viewport could go here)
        (log:debug "DRIVER: Root viewport cleanup for instance: ~S" rv-instance)
        ;; Example: (set-cursor-position *backend* (getf cleanup-info :initial-cursor-row 0) 0)
        )))

  ;; Shutdown the backend and clear the backend global
  (when *backend*
    (shutdown-backend *backend*)
    (setf *backend* nil))

  ;; Reset global state for app model, viewport, and buffer diff flag
  (setf *current-app-model* nil
    *root-viewport-id-path* nil ; Reset root viewport path
    elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t)
  (log:info "DRIVER: Platform shutdown complete."))

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
    elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t
    *initial-render-done* nil
    *got-initial-terminal-resized* nil
    *got-initial-cursor-position* nil
    *focus-manager* nil)
  (log-info "Globals reset for new application run.")

  (let ((initial-commands nil)
         (prefill-from-tmux (getf platform-options :prefill-from-tmux))
         (tmux-prefill-mode (getf platform-options :tmux-prefill-mode :pane)))
    (unwind-protect
      (progn
        ;; 1. Start the event loop. This sets up channels and the consumer thread.
        (start-loop)
        (log-info "Event loop and channels are active.")
        ;; 1a. Install bootstrap app-message processor to buffer early events
        (setf elmtui.core.globals:*app-message-processor* #'%driver-bootstrap-processor)
        (setf *real-app-message-processor* nil
          *bootstrap-event-queue* nil
          *got-initial-terminal-resized* nil
          *got-initial-cursor-position* nil)

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
                (setf *previous-frame-buffer* snapshot))))

          ;; 4. Initialize the application model. This sets *app-message-processor*.
          (multiple-value-bind (im ic) (initialize-app-model app-spec)
            (log:debug "DRIVER: Initial model: ~S, initial commands: ~S..binding" im ic)
            (setf *current-app-model* im)
            (setf initial-commands ic))
          (log-info "Application model and message processor are initialized.")

          ;; 4a. Install the real app-message processor by wrapping the one set in initialize-app-model
          ;;     We capture it and leave the bootstrap shim in place to drain the queue safely.
          (let ((real-proc elmtui.core.globals:*app-message-processor*))
            ;; Install real processor now
            (setf elmtui.core.globals:*app-message-processor* real-proc)
            ;; Replay buffered events in order, then clear the bootstrap queue
            (let ((events (nreverse *bootstrap-event-queue*)))

              (dolist (e events) (ignore-errors (funcall real-proc e)))
              (setf *bootstrap-event-queue* nil)))

          ;; Ensure the application receives the current terminal geometry now that
          ;; the real processor and component tree are configured.
          (let ((root-id (getf app-spec :root-viewport-id)))
            (let ((re-render-needed nil))
              (ignore-errors
                (multiple-value-bind (w h) (get-screen-dimensions *backend*)
                  (when (and w h (> w 0) (> h 0))
                    (setf *got-initial-terminal-resized* t)
                    (setf re-render-needed
                      (or re-render-needed
                        (synchronous-root-message
                          `(:terminalresized :width ,w :height ,h)
                          root-id))))))
              (ignore-errors
                (multiple-value-bind (row col) (get-cursor-position *backend*)
                  (when (and col row (>= col 0) (>= row 0))
                    (setf *got-initial-cursor-position* t)
                    (setf re-render-needed
                      (or re-render-needed
                        (synchronous-root-message
                          `(:cursorposition :col ,col :row ,row)
                          root-id))))))
              (when re-render-needed
                (force-render-current-frame app-spec)
                (setf *initial-render-done* t)))))))

    ;; 5. Build the driver context and start the driver-managed input loop when the backend exposes cl-inputs handles.
    (let ((device (backend-input-device *backend*))
           (input-source (backend-input-source *backend*))
           (event-handler (lambda (ev) (publish ev))))
      (log-info "DRIVER: Setting up input handling. Device: ~A, Input Source: ~A" device input-source)
      (if (and device input-source)
        (let ((ctx (make-driver-context
                     :backend *backend*
                     :device device
                     :input-source input-source
                     :publish-fn event-handler)))
          (setf *driver-context* ctx
            *stop-input-fn* (lambda ()
                              (ignore-errors (stop-driver-input-loop ctx))
                              (setf *input-thread* nil)
                              t)
            *input-thread* (start-driver-input-loop ctx)))
        (multiple-value-bind (thread stop-fn)
          (start-reader *backend* :event-handler event-handler)
          (setf *input-thread* thread
            *stop-input-fn* stop-fn
            *driver-context* nil)
          (log-info "Fallback input reader started: ~A" *input-thread*)))
      (when (and device input-source)
        (log-info "Driver input loop started: ~A" *input-thread*)))

    ;; 6. Process any initial commands from the app's init function.
    (when initial-commands
      (process-initial-commands initial-commands app-spec))
    (log:info "Initial commands processed. Starting main wait loop.")

    ;; 7. Wait for shutdown signal.
    (loop until elmtui.core.loop::*shutdown-requested* do (sleep 0.1))
    (log:info "DRIVER: Shutdown signal received, exiting loop.")
    ;; Cleanup
    (shutdown-platform)
    (elm-stop-loop)
    (log:info "DRIVER: Application ~A has shut down." (getf app-spec :name))))
