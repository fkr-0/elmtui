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
                #:*app-sender* #:*app-message-processor*)
  (:import-from :elmtui.core.focus
                #:get-current-focus
                #:make-focus-manager)
  (:import-from :elmtui.core.keymap
                #:key-event->normalized-key
                #:lookup-keymap)
  (:import-from :elmtui.state #:get-path)
  (:import-from :elmtui.tea-state.api #:state-ref)
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
(declaim (type t *current-app-model*)) ; Holds the application state object
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
(defvar *global-term-size* nil "Global terminal size, used for initial terminal dimensions.")
(defvar *app-spec* nil "Global terminal size, used for initial terminal dimensions.")
(defvar *last-ctx* nil "Global terminal size, used for initial terminal dimensions.")

;;; ---------------------------------------------------------------------------
;;; Helper utilities
;;; ---------------------------------------------------------------------------

(defun initialize-backend-with-publish-fn (backend-type tty-path publish-fn)
  (declare (type keyword backend-type)
           (type (or string null) tty-path)
           (type function publish-fn))
  (elmtui.platform.api:initialize-backend backend-type :publish-fn publish-fn :tty-path tty-path))
;; (start-input-reader-thread *backend*)
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
    (log:info "Running init-fn ~S for app-spec ~S" init-fn app-spec)
    (multiple-value-bind (initial-model initial-cmds) (funcall init-fn)
      ;; (declare (type t initial-model)
      ;;          (type list initial-cmds))
      (setf *current-app-model* initial-model)
      (setf elmtui.core.globals:*app-message-processor*
            (lambda (msg)
              ;; (declare (type list msg))
              (log:debug "DRIVER: Processing message in app-message-processor: ~S" msg)
              (funcall update-fn *current-app-model* msg)))
      (log:info "DRIVER: Initial model: ~S, initial commands: ~S" initial-model initial-cmds)
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
;;; Previous Buffer Initialization:
;;;
;;; ---------------------------------------------------------------------------
(defun setup-initial-previous-buffer (current-model)
  ;; (declare (type list current-model))
  (unless *root-viewport-id-path*
    (log-warn "Root viewport ID path not set before previous buffer initialization."))
  (let* ((rv-state-path (append *root-viewport-id-path* '(:state)))
         (root-viewport-behavioral-state (elmtui.state:get-path rv-state-path current-model)))
    (unless root-viewport-behavioral-state
      (log-warn (format nil "Root viewport behavioral state not found at ~S in model ~S" rv-state-path current-model)))
    (let ((buffer-width (gethash  :width root-viewport-behavioral-state))
          (buffer-height (gethash  :height root-viewport-behavioral-state)))
      (unless (and (numberp buffer-width) (plusp buffer-width)
                   (numberp buffer-height) (plusp buffer-height))
        (log-warn (format nil "Invalid root viewport dimensions for buffer: width=~S, height=~S. From state: ~S"
                          buffer-width buffer-height root-viewport-behavioral-state)))
      (when (not (or (< buffer-width 1) (< buffer-height 1)))
        (log:debug "DRIVER: Initializing previous frame buffer with dimensions ~Ax~A." buffer-width buffer-height)
        (setf *previous-frame-buffer* (make-virtual-buffer buffer-width buffer-height))
        (log:debug "DRIVER: Initialized previous frame buffer with dimensions ~Ax~A." buffer-width buffer-height)))))

;;; ---------------------------------------------------------------------------
;;; Rendering Frame Logic
;;; ---------------------------------------------------------------------------
(defun render-frame (app-spec current-model backend-instance)
  ;; (declare (type list app-spec current-model)
  ;;          (type t backend-instance))
  (log:debug "DRIVER: --- Starting Render Frame ---")
  (unless *root-viewport-id-path*
    (log:error "DRIVER: Root viewport ID path not set.")
    (return-from render-frame))

  (let* ((view-fn (getf app-spec :view-fn))
         (root-viewport-state (elmtui.state:get-path (append *root-viewport-id-path* '(:state)) current-model ))
         (viewport-width (state-ref root-viewport-state :width 1))
         (viewport-height (state-ref root-viewport-state :height 1))
         ;; (viewport-offset-x (state-ref root-viewport-state :offset-x 0))
         ;; (viewport-offset-y (state-ref root-viewport-state :offset-y 0))
         ;; (stylesheet (elmtui.state:get-path '(:current-stylesheet) current-model ))
         )

    (unless (and (typep view-fn 'function)
                 (numberp viewport-width) (plusp viewport-width)
                 (numberp viewport-height) (plusp viewport-height)
                 (> viewport-width 1) (> viewport-height 1))
      (log:error "DRIVER: Invalid parameters for render-frame. ~A ~A ~A"
                 (typep view-fn 'function) viewport-width viewport-height)
      (return-from render-frame))

    (let* ((initial-context
             (elmtui.contracts:make-app-context
              :state current-model
              :viewport-rect (make-rectangle :pos (make-pos :x 0 :y 0)
                                             :size (make-size :w viewport-width :h viewport-height))
              :backend backend-instance
              :front-buffer
              (if (and *previous-frame-buffer*
                       (= (elmtui.platform.backend.common.virtual-buffer:virtual-terminal-buffer-width *previous-frame-buffer*) viewport-width)
                       (= (elmtui.platform.backend.common.virtual-buffer:virtual-terminal-buffer-height *previous-frame-buffer*) viewport-height))
                  *previous-frame-buffer*
                  (make-virtual-buffer viewport-width viewport-height))
              :view-fn (getf app-spec :view-fn)
              :backend nil))
           (final-context (full-view-pipeline initial-context)))
      (setf *last-ctx* final-context) ;; Store last context for potential future use
      (setf *previous-frame-buffer* nil) ;; (elmtui.contracts:ctx-front-buffer final-context))
      (flush-output backend-instance)))


  (log:debug "DRIVER: --- Finished Render Frame ---"))


;;; ---------------------------------------------------------------------------
;;; Main Application Loop & Lifecycle
;;; ---------------------------------------------------------------------------
(defun app-loop (app-spec backend-instance)
  (declare (type list app-spec)
           (type t backend-instance))
  (log-info "APP-LOOP - " (elmtui.core.loop:get-event-loop-status))
  (let* ((message-queue (getf app-spec :message-queue))
         (update-fn (getf app-spec :update-fn))
         (cmd-proc-fn (getf app-spec :command-processor-fn))
         (app-name (getf app-spec :name))
         (app-cfg-for-cmd (gethash app-name elmtui.core.globals:*applications*)))
    (declare (type function update-fn)
             (type (or null function) cmd-proc-fn)
             (type symbol app-name)
             (type (or null elmtui.app.api:app-config) app-cfg-for-cmd)
             (type elmtui.core.event-channels:event-channel message-queue))

    (flet ((process-message (app-msg)
             (multiple-value-bind (next-model commands)
                 (funcall update-fn *current-app-model* app-msg)
               (declare (type t next-model)
                        (type list commands))
               (log:debug "DRIVER: After update-fn, next-model :should-quit = ~A" (elmtui.state:get-path '(:should-quit) next-model))
               (setf *current-app-model* next-model)
               (when cmd-proc-fn
                 (dolist (c commands)
                   (funcall cmd-proc-fn c message-queue next-model app-cfg-for-cmd)))
               (render-frame app-spec next-model backend-instance))))

      (setf *driver-initiated-shutdown-p* nil)
      (log:info "DRIVER: Starting application loop for ~A." app-name)
      (loop
        (let ((should-quit (elmtui.state:get-path '(:should-quit) *current-app-model*)))
          (log:debug "DRIVER: Loop check: *driver-initiated-shutdown-p* = ~A, :should-quit = ~A" *driver-initiated-shutdown-p* should-quit)
          (when (or *driver-initiated-shutdown-p* should-quit)
            (log:info "DRIVER: Shutdown condition met. Exiting app loop for ~A. (*driver-initiated-shutdown-p* = ~A, :should-quit = ~A)" app-name *driver-initiated-shutdown-p* should-quit)
            (return)))

        (log-info "Looping regularly")
        (let ((msg (elmtui.core.event-channels:receive-event message-queue))) ; Blocking receive
          (log:debug "DRIVER (~A): Dequeued message: ~S (Type: ~A)" app-name msg (type-of msg))
          (cond
            ((typep msg 'resize-event)
             (let ((new-width (resize-event-width msg))
                   (new-height (resize-event-height msg)))
               (handle-backend-resize backend-instance new-width new-height)
               (process-message `(:terminal-resized :new-dimensions (,new-width . ,new-height)))))
            ((and (listp msg) (eq (first msg) :app-quit-requested)) ; Generic quit message
             (setf *driver-initiated-shutdown-p* t)
             (log:info "DRIVER: :app-quit-requested received for ~A. Setting *driver-initiated-shutdown-p* to T." app-name))
            (t ; Process regular app message
             (process-message msg))))))
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
        (initial-model nil)
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
               (start-input-reader-thread *backend* (lambda (ev) (publish ev)))
             (setf *input-thread* thread)
             (setf *stop-input-fn* stop-fn))

                                        ;(multiple-value-setq (initial-model initial-commands)
           (multiple-value-bind (im ic)
               (initialize-app-model app-spec)
             (log:debug "DRIVER: Initial model: ~S, initial commands: ~S..binding" im ic)
             (setf initial-model im)
             (setf initial-commands ic))
           (when initial-commands
             (process-initial-commands initial-commands (lambda (ev) (publish ev)) app-spec))
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
