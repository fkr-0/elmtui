;;; == src/platform/driver.lisp ===============================================
;;; Platform Driver - Generic Application Runner
;;;============================================================================

(uiop:define-package :elmtui.platform.driver
  (:use :cl :bt
        :elmtui.platform.input) ; For start-reader
  (:import-from :log4cl
                #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.pipeline
                #:full-view-pipeline)
  (:import-from :elmtui.core.event-types
                #:key-event #:resize-event #:resize-event-width #:resize-event-height)
  (:import-from :elmtui.core.globals
                #:*app-sender*)
  (:import-from :elmtui.core.focus
                #:get-current-focus
                #:make-focus-manager)
  (:import-from :elmtui.core.keymap
                #:key-event->normalized-key
                #:lookup-keymap)
  (:import-from :elmtui.state #:get-path #:state-ref)
  (:import-from :elmtui.view.geo
                #:make-instance
                #:make-rectangle #:make-pos #:make-size)
  (:import-from :elmtui.platform.api
                #:initialize-backend #:shutdown-backend
                #:term-w #:term-h #:handle-backend-resize
                #:flush-output #:get-cursor-position #:set-cursor-position #:clear-lines #:scroll-up #:scroll-down)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer
                #:*compute-buffer-diff-first-call*)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-buffer #:copy-virtual-buffer #:make-virtual-buffer
                #:buffer-width #:buffer-height)
  (:import-from :elmtui.app.api #:run-application #:get-component-instance #:app-config-message-queue)
  (:import-from :elmtui.core.loop
                #:publish #:start-loop #:elm-stop-loop #:event-loop)
  (:import-from :elmtui.core.async
                #:interpret-cmd)
  (:import-from :elmtui.ui.widgets.root-viewport
                #:root-viewport)
  (:import-from :elmtui.style-lib.api #:stylesheet)
  (:import-from :bordeaux-threads #:mailbox)
  (:export #:run-app-platform)) ; Ensure this is exported if called directly elsewhere

(in-package #:elmtui.platform.driver)

;;; ---------------------------------------------------------------------------
;;; Global state (driver-level) Type Declarations
;;; ---------------------------------------------------------------------------
(declaim (type t *backend*))
(declaim (type (or null bt:thread) *input-thread*))
(declaim (type (or null function) *stop-input-fn*))
(declaim (type boolean *driver-initiated-shutdown-p*))
(declaim (type (or null elmtui.platform.backend.common.virtual-buffer:virtual-terminal-buffer) *previous-frame-buffer*))
(declaim (type list *current-app-model*)) ; Plist-based state
(declaim (type list *root-viewport-id-path*)) ; e.g., '(:components :my-root-vp)

;; In src/platform/driver.lisp

;;; ---------------------------------------------------------------------------
;;; Method for elmtui.app.api:run-application
;;; ---------------------------------------------------------------------------
(defmethod elmtui.app.api:run-application ((app-spec list)
                                           &key (backend-type :terminal)
                                             platform-options)
  "Method for `elmtui.app.api:run-application` that handles an `app-spec` plist.
This is the primary entry point called by applications defined with `defapplication`.
It bridges the generic application specification to the platform-specific driver.

Args:
  app-spec (list): A plist containing application configuration details like
                   :name, :init-fn, :update-fn, :view-fn, :subscriptions-fn,
                   :message-queue, and :root-viewport-id.
  backend-type (keyword): The type of backend to use (e.g., :terminal, :faketerm).
                          Defaults to :terminal.
  platform-options (list): A plist of options. Options relevant to the backend (e.g. :tty-path)
                           will be used by run-app-platform. Other options
                           (e.g. :initial-terminal-dimensions) are primarily for
                           the application's init-fn and will be ignored by run-app-platform
                           if it uses &allow-other-keys."
  (declare (type list app-spec platform-options)
           (type keyword backend-type))
  (log:info "DRIVER: elmtui.app.api:run-application method called for app-spec (list).~%  App Name: ~S~%  Backend: ~A~%  Platform Options: ~S"
            (getf app-spec :name) backend-type platform-options)
  ;; Apply platform-options as keyword arguments to run-app-platform.
  ;; run-app-platform should have &allow-other-keys to ignore options it doesn't explicitly handle.
  (apply #'run-app-platform
         app-spec ; Pass the app_spec plist as the first argument to run-app-platform
         :backend-type backend-type
         platform-options))

;;; ---------------------------------------------------------------------------
;;; Global state (driver-level)
;;; ---------------------------------------------------------------------------

(defvar *backend* nil "Current platform backend instance.")
(defvar *input-thread* nil "Thread handling input events.")
(defvar *stop-input-fn* nil "Function to stop the input thread.")
(defvar *driver-initiated-shutdown-p* nil "T if driver requested shutdown.")
(defvar *previous-frame-buffer* nil "Buffer from the previous frame for diffing, matches root viewport dimensions.")
(defvar *current-app-model* nil "Holds the current application model (state).")
(defvar *root-viewport-id-path* nil "ID path of the root-viewport component.")

;;; ---------------------------------------------------------------------------
;;; Helper utilities
;;; ---------------------------------------------------------------------------

(defun initialize-backend-with-publish-fn (backend-type tty-path publish-fn)
  (declare (type keyword backend-type)
           (type (or string null) tty-path)
           (type function publish-fn))
  (elmtui.platform.api:initialize-backend backend-type :publish-fn publish-fn :tty-path tty-path))

(defun start-input-reader-thread (backend-instance publish-fn)
  (declare (type t backend-instance)
           (type function publish-fn))
  (multiple-value-bind (thread stop-fn)
      (start-reader backend-instance :event-handler publish-fn)
    (values thread stop-fn)))

;;; ---------------------------------------------------------------------------
;;; Application-state bootstrap
;;; ---------------------------------------------------------------------------

(defun initialize-app-model (app-spec)
  (declare (type list app-spec))
  (let* ((init-fn (getf app-spec :init-fn))
         (update-fn (getf app-spec :update-fn)) ; Keep for validation, though not directly used here
         (view-fn (getf app-spec :view-fn))     ; Keep for validation
         (root-viewport-id (getf app-spec :root-viewport-id)))
    (unless (and (typep init-fn 'function)
                 (typep update-fn 'function)
                 (typep view-fn 'function))
      (error "App spec missing or has invalid types for required functions: :init-fn, :update-fn, :view-fn. Got init: ~S, update: ~S, view: ~S" init-fn update-fn view-fn))
    (unless (keywordp root-viewport-id)
      (error "App spec missing or has invalid type for :root-viewport-id. Got: ~S" root-viewport-id))

    (setf *root-viewport-id-path* (list :components root-viewport-id))
    (log:info "DRIVER: Initializing application model for ~A... Root Viewport ID: ~A"
              (getf app-spec :name) root-viewport-id)
    (multiple-value-bind (initial-model initial-cmds) (funcall init-fn)
      (declare (type list initial-model initial-cmds))
      (setf *current-app-model* initial-model)
      (values initial-model initial-cmds))))

(defun process-initial-commands (cmds publish-fn app-spec)
  (declare (type list cmds) (type function publish-fn) (type list app-spec))
  ;; TODO publish-fn?
  (when cmds
    (log:debug "DRIVER: Processing initial commands...")
    (let ((cmd-proc-fn (getf app-spec :command-processor-fn))
          (msg-queue (getf app-spec :message-queue))
          (app-cfg-for-cmd (gethash (getf app-spec :name) elmtui.core.globals:*applications*))) ; For passing app-config
      (dolist (cmd cmds)
        (if cmd-proc-fn
            (funcall cmd-proc-fn cmd msg-queue *current-app-model* app-cfg-for-cmd)
            (interpret-cmd cmd)))))) ; Fallback if no app-specific processor

;;; ---------------------------------------------------------------------------
;;; Previous Buffer Initialization
;;; ---------------------------------------------------------------------------
(defun setup-initial-previous-buffer (current-model)
  (declare (type list current-model))
  (unless *root-viewport-id-path*
    (error "Root viewport ID path not set before previous buffer initialization."))
  (let* ((rv-state-path (append *root-viewport-id-path* '(:state)))
         (root-viewport-behavioral-state (elmtui.state:get-path current-model rv-state-path)))
    (unless root-viewport-behavioral-state
      (error (format nil "Root viewport behavioral state not found at ~S in model ~S" rv-state-path current-model)))
    (let ((buffer-width (getf root-viewport-behavioral-state :width))
          (buffer-height (getf root-viewport-behavioral-state :height)))
      (unless (and (numberp buffer-width) (plusp buffer-width)
                   (numberp buffer-height) (plusp buffer-height))
        (error (format nil "Invalid root viewport dimensions for buffer: width=~S, height=~S. From state: ~S"
                       buffer-width buffer-height root-viewport-behavioral-state)))
      (setf *previous-frame-buffer* (make-virtual-buffer buffer-width buffer-height))
      (log:debug "DRIVER: Initialized previous frame buffer with dimensions ~Ax~A." buffer-width buffer-height))))

;;; ---------------------------------------------------------------------------
;;; Rendering Frame Logic
;;; ---------------------------------------------------------------------------
(defun render-frame (app-spec current-model backend-instance)
  (declare (type list app-spec current-model)
           (type t backend-instance))
  (log:debug "DRIVER: --- Starting Render Frame ---")
  (unless *root-viewport-id-path*
    (log:error "DRIVER: Root viewport ID path not set.")
    (return-from render-frame))

  (let* ((view-fn (getf app-spec :view-fn))
         (root-viewport-state (elmtui.state:get-path current-model (append *root-viewport-id-path* '(:state))))
         (viewport-width (getf root-viewport-state :width))
         (viewport-height (getf root-viewport-state :height))
         (viewport-offset-x (getf root-viewport-state :offset-x 0))
         (viewport-offset-y (getf root-viewport-state :offset-y 0))
         (stylesheet (elmtui.state:get-path current-model '(:current-stylesheet))))

    (unless (and (typep view-fn 'function)
                 (numberp viewport-width) (plusp viewport-width)
                 (numberp viewport-height) (plusp viewport-height))
      (log:error "DRIVER: Invalid parameters for render-frame.")
      (return-from render-frame))

    (let ((initial-context
            (list :app-model current-model
                  :view-fn view-fn
                  :stylesheet (or stylesheet (make-instance 'elmtui.style-lib.api:stylesheet))
                  :viewport-rect (make-rectangle :pos (make-pos :x 0 :y 0)
                                                 :size (make-size :w viewport-width :h viewport-height))
                  :front-buffer *previous-frame-buffer*
                  :backend backend-instance
                  :origin-x viewport-offset-x
                  :origin-y viewport-offset-y)))

      (let ((final-context (full-view-pipeline initial-context)))
        (setf *previous-frame-buffer* (getf final-context :front-buffer))
        (flush-output backend-instance)))

    (log:debug "DRIVER: --- Finished Render Frame ---")))

;;; ---------------------------------------------------------------------------
;;; Main Application Loop & Lifecycle
;;; ---------------------------------------------------------------------------
(defun app-loop (app-spec backend-instance)
  (declare (type list app-spec)
           (type t backend-instance))
  (let* ((publish-fn (lambda (event) (publish event))) ; TODO publish is from elmtui.core.loop
         (message-queue (getf app-spec :message-queue))
         (update-fn (getf app-spec :update-fn))
         (raw-subs-fn (getf app-spec :subscriptions-fn))
         (subscriptions-fn
           (cond
             ((functionp raw-subs-fn) raw-subs-fn)
             ((and (consp raw-subs-fn) (eq (car raw-subs-fn) 'lambda)) (eval raw-subs-fn))
             ((symbolp raw-subs-fn) (symbol-function raw-subs-fn))
             (t (error "Invalid :subscriptions-fn")))) ;; TODO
         (cmd-proc-fn (getf app-spec :command-processor-fn))
         (app-name (getf app-spec :name))
         (app-cfg-for-cmd (gethash app-name elmtui.core.globals:*applications*)))
    (declare (type function publish-fn update-fn subscriptions-fn)
             (type (or null function) cmd-proc-fn)
             (type symbol app-name)
             (type (or null elmtui.app.api:app-config) app-cfg-for-cmd)
             (type elmtui.core.event-channels:event-channel message-queue))

    (setf *driver-initiated-shutdown-p* nil)
    (log:info "DRIVER: Starting application loop for ~A." app-name)
    (loop
      (let ((should-quit (elmtui.state:get-path *current-app-model* '(:should-quit))))
        (log:debug "DRIVER: Loop check: *driver-initiated-shutdown-p* = ~A, :should-quit = ~A" *driver-initiated-shutdown-p* should-quit)
        (when (or *driver-initiated-shutdown-p* should-quit)
          (log:info "DRIVER: Shutdown condition met. Exiting app loop for ~A. (*driver-initiated-shutdown-p* = ~A, :should-quit = ~A)" app-name *driver-initiated-shutdown-p* should-quit)
          (return)))

      (let ((msg (elmtui.core.event-channels:receive-event message-queue))) ; Blocking receive
        (log:debug "DRIVER (~A): Dequeued message: ~S (Type: ~A)" app-name msg (type-of msg))
        (cond
          ((typep msg 'resize-event)
           (let ((new-width (resize-event-width msg))
                 (new-height (resize-event-height msg)))
             (handle-backend-resize backend-instance new-width new-height))
           ;; Re-render after resize
           (render-frame app-spec *current-app-model* backend-instance))
          ((and (listp msg) (eq (first msg) :app-quit-requested)) ; Generic quit message
           (setf *driver-initiated-shutdown-p* t)
           (log:info "DRIVER: :app-quit-requested received for ~A. Setting *driver-initiated-shutdown-p* to T." app-name))
          (t ; Process regular app message
           (multiple-value-bind (next-model commands)
               (funcall update-fn *current-app-model* msg)
             (declare (type list next-model commands))
             (log:debug "DRIVER: After update-fn, next-model :should-quit = ~A" (elmtui.state:get-path next-model '(:should-quit)))
             (setf *current-app-model* next-model)
             (when cmd-proc-fn
               (dolist (c commands)
                 (funcall cmd-proc-fn c message-queue next-model app-cfg-for-cmd)))
             ;; TODO: Handle subscriptions if they can generate commands or messages
             ;; (let ((subs (funcall subscriptions-fn next-model))) ...)
             (render-frame app-spec next-model backend-instance))))))
    (log:info "DRIVER: Application loop for ~A finished." app-name)))




(defun shutdown-platform ()
  (log:info "DRIVER: Shutting down platform...")
  (when *stop-input-fn*
    (funcall *stop-input-fn*)
    (setf *stop-input-fn* nil))
  (when (and *input-thread* (bt:thread-alive-p *input-thread*))
    ;; (bt:join-thread *input-thread*) ; Consider timeout or if join is always safe
    (setf *input-thread* nil))

  (when (and *root-viewport-id-path* *current-app-model* *backend*)
    (let* ((rv-instance (get-component-instance *root-viewport-id-path* *current-app-model*)))
      (when rv-instance
        ;; cleanup-info (when rv-instance
        ;;   (get-cleanup-info rv-instance *root-viewport-id-path* *current-app-model*))))
        ;; (when cleanup-info
        (log:debug "DRIVER: Root viewport cleanup for instance: ~S" rv-instance)
        ;; Example: (set-cursor-position *backend* (getf cleanup-info :initial-cursor-row 0) 0)
        )))

  (when *backend*
    (shutdown-backend *backend*)
    (setf *backend* nil))

  (setf *current-app-model* nil
        *root-viewport-id-path* nil ; Reset root viewport path
        elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t)
  (log:info "DRIVER: Platform shutdown complete."))

(defun run-app-platform (app-spec ; This is the app-spec-for-driver plist
                         &key (backend-type :terminal)
                           (tty-path #+os-unix "/dev/tty" #-os-unix nil)
                           ;; Add other platform options run-app-platform directly uses here
                         &allow-other-keys) ; Allows platform-options like :initial-terminal-dimensions
  (declare (type list app-spec)
           (type keyword backend-type)
           (type (or string null) tty-path))
  (setf *backend* nil *input-thread* nil *stop-input-fn* nil
        *driver-initiated-shutdown-p* nil *previous-frame-buffer* nil
        *current-app-model* nil *root-viewport-id-path* nil
        elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t)
  (start-loop)
  (let (;(event-loop ) ; Start the main event loop
        (initial-model nil)
        (initial-commands nil))
    (declare (type list initial-model initial-commands))
    (unwind-protect
         (progn
           (setf *backend* (initialize-backend-with-publish-fn
                            backend-type
                            tty-path ; Use tty-path from keyword args (potentially from platform-options)
                            (lambda (ev) (publish ev))))
           (unless *backend*
             (error "Failed to initialize backend ~A" backend-type))

           (multiple-value-bind (thread stop-fn)
               (start-input-reader-thread *backend* (lambda (ev) (publish ev)))
             (setf *input-thread* thread)
             (setf *stop-input-fn* stop-fn))

           (multiple-value-setq (initial-model initial-commands) (initialize-app-model app-spec))
           (process-initial-commands initial-commands (lambda (ev) (publish ev)) app-spec)
           (setup-initial-previous-buffer initial-model)

           ;; Initial render
           (render-frame app-spec initial-model *backend*)
           ;; Start the application message processing loop
           (app-loop app-spec *backend*))
      ;; Cleanup
      (shutdown-platform)
      (elm-stop-loop) ; Fixed function call
      (log:info "DRIVER: Application ~A has shut down." (getf app-spec :name)))))
;; (defun run-app-platform (app-spec ; This is the app-spec-for-driver plist
;;                          &key (backend-type :terminal)
;;                            (tty-path #+os-unix "/dev/tty" #-os-unix nil)
;;                            ;; Add other platform options run-app-platform directly uses here
;;                          &allow-other-keys) ; Allows platform-options like :initial-terminal-dimensions
;;   (declare (type list app-spec)
;;            (type (or keyword t) backend-type) ; allow t for type check
;;            (type (or string null) tty-path))
;;   (when (and (not (keywordp backend-type))
;;              (not (null backend-type)))
;;     (log4cl:log-error "run-app-platform: backend-type is not a keyword! Type: ~A, Value: ~S" (type-of backend-type) backend-type)
;;     (when (typep backend-type 'elmtui.view.core:ui-node)
;;       (log4cl:log-error "run-app-platform: backend-type is a UI-NODE! This is a bug. Node: ~S" backend-type))
;;     (error "run-app-platform: backend-type must be a keyword, got: ~S (type: ~A)" backend-type (type-of backend-type)))
;;   (setf *backend* nil *input-thread* nil *stop-input-fn* nil
;;         *driver-initiated-shutdown-p* nil *previous-frame-buffer* nil
;;         *current-app-model* nil *root-viewport-id-path* nil
;;         elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t)

;;   (let ((event-loop (start-loop)) ; Start the main event loop
;;         (initial-model nil)
;;         (initial-commands nil))
;;     (declare (type list initial-model initial-commands))
;;     (unwind-protect
;;          (progn
;;            (setf *backend* (initialize-backend-with-publish-fn
;;                             backend-type
;;                             tty-path ; Use tty-path from keyword args (potentially from platform-options)
;;                             (lambda (ev) (publish ev))))
;;            (unless *backend*
;;              (error "Failed to initialize backend ~A" backend-type))

;;            (multiple-value-bind (thread stop-fn)
;;                (start-input-reader-thread *backend* (lambda (ev) (publish ev)))
;;              (setf *input-thread* thread)
;;              (setf *stop-input-fn* stop-fn))

;;            (multiple-value-setq (initial-model initial-commands) (initialize-app-model app-spec))
;;            (process-initial-commands initial-commands (lambda (ev) (publish ev)) app-spec)
;;            (setup-initial-previous-buffer initial-model)

;;            ;; Initial render
;;            (render-frame app-spec initial-model *backend*)
;;            ;; Start the application message processing loop
;;            (app-loop app-spec *backend*))
;;       ;; Cleanup
;;       (shutdown-platform)
;;       (elm-stop-loop) ; Fixed function call
;;       (log:info "DRIVER: Application ~A has shut down." (getf app-spec :name)))))
