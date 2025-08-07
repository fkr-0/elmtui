;;; == src/platform/driver.lisp ===============================================
;;; Platform Driver - Generic Application Runner
;;;============================================================================

(uiop:define-package :elmtui.platform.driver
  (:use #:cl)
  (:import-from :bt
                #:thread #:thread-alive-p #:join-thread #:destroy-thread)
  (:import-from :elmtui.platform.input
                #:start-reader)
  (:import-from :log4cl
                #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.app.system-events
                #:make-appshutdown-systemevent
                #:make-terminalresized-systemevent)
  (:import-from :elmtui.core.event-types
                #:key-event #:resize-event #:resize-event-width #:resize-event-height)
  (:import-from :elmtui.pipeline #:render-frame)
  (:import-from :elmtui.core.globals
                #:*app-sender* #:*app-message-processor*)
  (:import-from :elmtui.core.focus
                #:get-current-focus
                #:make-focus-manager)
  (:import-from :elmtui.keymaps
                #:initialise
                #:process-key-event)
  (:import-from :elmtui.tea-state #:get-path)
  (:import-from :elmtui.platform.api
                #:initialize-backend #:shutdown-backend #:render-and-present
                #:term-w #:term-h #:handle-backend-resize
                #:flush-output #:get-cursor-position #:set-cursor-position #:clear-lines #:scroll-up #:scroll-down)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer
                #:*compute-buffer-diff-first-call*)
  (:import-from :elmtui.app.api #:run-application
                #:get-component-instance #:app-config-message-queue)
  (:import-from :elmtui.core.loop
                #:publish #:start-loop #:elm-stop-loop #:event-loop)
  (:import-from :elmtui.core.async
                #:interpret-cmd)
  (:import-from :elmtui.ui.widgets.root-viewport
                #:root-viewport)
  (:import-from :elmtui.style-lib.api #:stylesheet)
  (:import-from :bordeaux-threads #:mailbox)
  (:import-from :cleve-elm.channel #:->)
  (:import-from :elmtui.core.event-channels #:channel-of)
  (:export #:run-app-platform))
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

;;; ---------------------------------------------------------------------------
;;; == Application Entry Point ==
;;; ---------------------------------------------------------------------------
;; Method for elmtui.app.api:run-application
(defmethod elmtui.app.api:run-application ((app-spec list)
                                           &key (backend-type :terminal)
                                             platform-options)
  "Entry point for running an application from an APP-SPEC plist."
  (declare (type list app-spec platform-options)
           (type keyword backend-type))
  (log:info "DRIVER: run-application called for ~S with backend ~A."
            (getf app-spec :name) backend-type)

  ;; Initialize keymap system
  (elmtui.keymaps:initialise)

  ;; Create a focus manager
  (setf *focus-manager* (make-focus-manager))

  ;; Subscribe keymap processor to key events
  (elmtui.core.loop:subscribe
   :key-event
   (lambda (evt)
     (unless (elmtui.keymaps:process-key-event
              evt
              *focus-manager*
              :app-state *current-app-model*
              :dispatch-fn #'publish)
       ;; Fallback for unhandled keys
       (publish (list :raw-key evt)))))

  (apply #'run-app-platform
         app-spec
         :backend-type backend-type
         platform-options))


;;; ---------------------------------------------------------------------------
;;; == Backend Initialization Utilities ==
;;; ---------------------------------------------------------------------------

(defun initialize-backend-with-publish-fn (BACKEND-TYPE TTY-PATH PUBLISH-FN)
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
  (elmtui.platform.api:initialize-backend backend-type :publish-fn publish-fn :tty-path tty-path))

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
              (log:debug "DRIVER: *app-message-processor* received ~S" msg)
              ;; Handle quit request
              (if (and (listp msg) (eq (car msg) :app-quit-requested))
                  (progn
                    (log:info "DRIVER: Quit requested. Setting *shutdown-requested* flag.")
                    (setf elmtui.core.loop::*shutdown-requested* t))
                  ;; Otherwise, process the message with update-fn and command processor
                  (let ((update-fn (getf app-spec :update-fn))
                        (cmd-proc-fn (getf app-spec :command-processor-fn))
                        (message-queue (getf app-spec :message-queue))
                        (app-cfg-for-cmd (gethash (getf app-spec :name) elmtui.core.globals:*applications*)))
                    (log-info "DRIVER: calling update")
                    (multiple-value-bind (next-model commands)
                        (funcall update-fn *current-app-model* msg)
                      ;; Update global model
                      (setf *current-app-model* next-model)
                      (log-info "DRIVER: update phase done")
                      ;; Check for shutdown flag in model
                      (when (elmtui.tea-state:get-path '(:should-quit) next-model)
                        (log:info "DRIVER: :should-quit flag is true in model. Setting *shutdown-requested*.")
                        (setf elmtui.core.loop::*shutdown-requested* t))
                      ;; Process commands if a command processor is present
                      (when cmd-proc-fn
                        (dolist (c commands)
                          (funcall cmd-proc-fn c message-queue next-model app-cfg-for-cmd)))
                      ;; If not shutting down, update rendering context and previous frame buffer
                      (unless elmtui.core.loop::*shutdown-requested*
                        (log-info "DRIVER: view next-model")
                        (let ((ctx (make-context-from-spec app-spec next-model *backend*)))
                          (setf *last-ctx* (elmtui.pipeline:full-view-pipeline ctx))
                          (setf *previous-frame-buffer* (elmtui.contracts:ctx-front-buffer *last-ctx*)))))))))
      (log:info "DRIVER: Initial model: ~S, initial commands: ~S" initial-model initial-cmds)
      (values initial-model initial-cmds))))

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
     :stylesheet (elmtui.tea-state:get-path '(:current-stylesheet) state)
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
                         &key (BACKEND-TYPE :terminal)
                           (TTY-PATH #+os-unix "/dev/tty" #-os-unix nil)
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
  (setf *app-spec* app-spec)
  (setf *backend* nil *input-thread* nil *stop-input-fn* nil
        *driver-initiated-shutdown-p* nil *previous-frame-buffer* nil
        *current-app-model* nil *root-viewport-id-path* nil
        elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t)
  (log-info "Globals set: *backend*, *input-thread*, *stop-input-fn*, *driver-initiated-shutdown-p*, *previous-frame-buffer*, *current-app-model*, *root-viewport-id-path*"
            *backend* *input-thread* *stop-input-fn* *driver-initiated-shutdown-p* *previous-frame-buffer* *current-app-model* *root-viewport-id-path*)
  (start-loop)
  (let (;(event-loop ) ; Start the main event loop
                                        ;(initial-model nil)
        ;; gets
        ;; initialized in initialize-app-model
        (initial-commands nil))
    ;; (declare (type list initial-commands))
    (unwind-protect
         (progn
           (setf *backend* (initialize-backend-with-publish-fn
                            backend-type
                            tty-path ; Use tty-path from keyword args (potentially from platform-options)
                            (lambda (ev) (publish ev))))
           (unless *backend*
             (error "Failed to initialize backend ~A" backend-type))

           (multiple-value-bind (thread stop-fn)
               (start-reader *backend*
                             :event-handler (lambda (ev) (publish ev)))
             (setf *input-thread* thread)
             (setf *stop-input-fn* stop-fn)
             (log-info "Input thread started: ~A, stop function: ~A" *input-thread* stop-fn))
                                        ;(multiple-value-setq (initial-model initial-commands)
           (multiple-value-bind (im ic)
               (initialize-app-model app-spec)
             (log:debug "DRIVER: Initial model: ~S, initial commands: ~S..binding" im ic)
             ;; (setf initial-model im)
             (setf initial-commands ic))
           (when initial-commands
             (process-initial-commands initial-commands app-spec))
           ;; (send-initial-resize-message *backend* (lambda (ev) (publish ev)))

           ;; Initial render is now handled by the first :terminal-resized event
           ;; (render-frame app-spec initial-model *backend*)
           ;; Wait for shutdown signal
           (log:info "DRIVER: Initial model and commands processed. Starting app loop.")
           (loop until elmtui.core.loop::*shutdown-requested* do (sleep 0.1))
           ;; (app-loop app-spec *backend*)
           (log:info "DRIVER: app-loop completed, shutdown."))
      ;; Cleanup
      (shutdown-platform)
      (elm-stop-loop) ; Fixed function call
      (log:info "DRIVER: Application ~A has shut down." (getf app-spec :name)))))
