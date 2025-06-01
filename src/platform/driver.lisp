;;; == src/platform/driver.lisp ===============================================
;;; Platform Driver - Generic Application Runner
;;;============================================================================

(uiop:define-package :elmtui.platform.driver
  (:use :cl :bt
        :elmtui.platform.input) ; For start-reader
  ;; Removed :elmtui.platform.output
  (:import-from :log4cl
                #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.view.styled
                #:apply-stylesheet-to-tree)
  (:import-from :elmtui.view.layout
                #:layout-tree)
  (:import-from :elmtui.core.event-types
                #:key-event) ; For typep check
  (:import-from :elmtui.core.globals
                #:*app-state* #:*app-message-processor*
                #:*app-sender*)
  (:import-from :elmtui.core.focus
                #:get-current-focus
                #:make-focus-manager) ; Added make-focus-manager
  (:import-from :elmtui.core.keymap
                #:key-event->normalized-key
                #:lookup-keymap)
  (:import-from :elmtui.state
                #:state-ref #:make-application-state)
  (:import-from :ut.state.state
                #:merge-state)
  (:import-from :elmtui.view.geo
                #:make-rectangle #:make-pos #:make-size)
  (:import-from :elmtui.platform.api
                ;; Backend lifecycle & info
                #:initialize-backend #:shutdown-backend
                ;; Screen & Dimensions
                #:term-w #:term-h #:handle-backend-resize
                ;; Rendering
                #:render-and-present)
  (:import-from :elmtui.platform.canvas ; For canvas object type and specific canvas functions
                #:canvas #:initialize-canvas #:restore-terminal-state
                #:canvas-content-rectangle)
  ;; Removed direct backend imports (e.g., elmtui.platform.backend.terminal)
  (:import-from :elmtui.core.loop
                #:publish #:start-loop #:elm-stop-loop)
  (:import-from :elmtui.core.async
                #:interpret-cmd)
  (:export #:run-application))

(in-package :elmtui.platform.driver)

;;; ---------------------------------------------------------------------------
;;; Global state (driver-level)
;;; ---------------------------------------------------------------------------

(defvar *backend*                       nil "Current platform backend instance.")
(defvar *input-thread*                  nil "Thread handling input events.")
(defvar *stop-input-fn*                 nil "Function to stop the input thread.")
(defvar *driver-initiated-shutdown-p*   nil "T if driver requested shutdown.")

;;; ---------------------------------------------------------------------------
;;; Helper utilities
;;; ---------------------------------------------------------------------------

;; Signal handling (setup-resize, setup-interrupt) is now managed by the backend.

(defun initialize-backend-with-publish-fn (backend-type tty-path publish-fn)
  ;; The backend's initialize-backend method is responsible for its own setup,
  ;; including signal handlers if it uses the publish-fn.
  (elmtui.platform.api:initialize-backend backend-type :publish-fn publish-fn :tty-path tty-path))

(defun start-input-reader-thread (backend-instance publish-fn)
  ;; start-reader is from elmtui.platform.input and uses backend's poll-input-event
  (multiple-value-bind (thread stop-fn)
      (start-reader backend-instance :event-handler publish-fn)
    (values thread stop-fn)))

;;; ---------------------------------------------------------------------------
;;; Application-state bootstrap
;;; ---------------------------------------------------------------------------

(defun initialize-app-state (app-spec publish-fn)
  (let* ((init-fn   (getf app-spec :init-fn))
         (update-fn (getf app-spec :update-fn))
         (view-fn   (getf app-spec :view-fn))
         (subs-fn   (getf app-spec :subscriptions-fn)))
    (unless (and init-fn update-fn view-fn)
      (error "App spec missing required functions: :init-fn, :update-fn, :view-fn"))
    (log:info "DRIVER: Initializing application state for ~A..." ;; (getf app-spec :name)
              app-spec)
    (multiple-value-bind (initial-model cmds) (funcall init-fn)
      (let ((st (make-application-state)))
        (merge-state st initial-model)
        (setf *app-state* st)
        (setf elmtui.core.globals:*app-sender* publish-fn)) ; Set global sender
      (values init-fn update-fn view-fn subs-fn *app-state* cmds))))

(defun process-initial-commands (cmds publish-fn)
  (when cmds
    (log:debug "DRIVER: Processing initial commands...")
    (dolist (cmd cmds)
      (if (and (consp cmd) (eq (first cmd) :command)) ; Check if it's an async command
          (interpret-cmd cmd)
          (funcall publish-fn cmd))))) ; publish will auto-wrap as :app-message

;;; ---------------------------------------------------------------------------
;;; Main event handler (becomes *app-message-processor*)
;;; ---------------------------------------------------------------------------

(defun process-event-from-driver
    (event app-state backend canvas use-canvas view-fn update-fn publish-fn)
  "Core dispatcher for every EVENT, now as *app-message-processor*."
  (block handler-block
    (log:info "DRIVER: EVENT (via *app-message-processor*): ~S" event)

    (when (state-ref app-state :driver-shutdown-initiated)
      (log:warn "DRIVER: Shutdown in progress – ignoring ~S" event)
      (return-from handler-block nil))

    (let ((effective-message event)
          (event-handled-by-widget-keymap nil))
      ;; 1. Key-event routing to focused widget
      (when (typep event 'key-event)
        (let ((wid (get-current-focus elmtui.core.globals:*focus-manager*)))
          (when wid
            (let* ((widget-model-path (list :widgets wid))
                   (widget-model      (state-ref app-state widget-model-path)))
              (when widget-model
                (let ((widget-keymap (getf widget-model :active-keymap)))
                  (when widget-keymap
                    (let* ((norm-key (key-event->normalized-key event))
                           (binding  (lookup-keymap widget-keymap norm-key)))
                      (when binding
                        (log:debug "DRIVER: Key ~A handled by widget ~S" norm-key wid)
                        (let ((bt (getf binding :type)) (tg (getf binding :target)))
                          (ecase bt
                            (:message (setf effective-message (list :dispatch-to-widget wid tg binding)
                                            event-handled-by-widget-keymap :message-dispatched))
                            (:action (setf effective-message (list :dispatch-action-to-widget wid tg binding)
                                           event-handled-by-widget-keymap :action-dispatched))))))))))))

        ;; 2. Handle driver/backend-specific messages or pass to application's update-fn
        (cond
          ((equal effective-message '(:force-render))
           (log:info "DRIVER: :FORCE-RENDER received – skipping UPDATE-FN."))

          ;; Backend resize event (published by the backend itself via its publish-fn)
          ((and (listp effective-message) (eq (first effective-message) :backend-resize-request))
           (destructuring-bind (&key width height) (rest effective-message)
             (log:info "DRIVER: Backend resize request to ~Ax~A" width height)
             (elmtui.platform.api:handle-backend-resize backend width height) ; Notify backend via API
             (funcall publish-fn (list :terminal-resized :width width :height height)) ; Notify app
             (funcall publish-fn '(:force-render)) ; Trigger full redraw
             (return-from handler-block nil)))

          ((and (listp effective-message) (eq (first effective-message) :app-quit-requested))
           (log:info "DRIVER: :APP-QUIT-REQUESTED received: ~S" effective-message)
           (let ((cmds (funcall update-fn app-state effective-message)))
             (dolist (cmd cmds) (funcall publish-fn cmd))))
          (t
           ;; Pass other messages to the application's update function
           (let ((cmds (funcall update-fn app-state effective-message)))
             (dolist (cmd cmds) (funcall publish-fn cmd))))))

      ;; 3. Post-update housekeeping & Rendering
      (let ((quitp (or (and (listp event) (eq (first event) :app-quit-requested)) ; Check original event
                       (state-ref app-state :should-quit))))
        (if quitp
            (progn
              (unless (state-ref app-state :driver-shutdown-initiated)
                (setf (state-ref app-state :driver-shutdown-initiated) t)
                (setf *driver-initiated-shutdown-p* t)
                (log:info "DRIVER: Initiating shutdown due to quit condition.")
                ;; Publish the standard shutdown command for the loop
                (funcall publish-fn :shutdown-command :target-channel-name :system-channel))) ; Corrected target
            ;; Normal render cycle
            (when (not (state-ref app-state :driver-shutdown-initiated))
              (let* ((tree      (funcall view-fn app-state publish-fn))
                     (styled    (apply-stylesheet-to-tree tree (state-ref app-state :current-stylesheet)))
                     (rect      (if (and use-canvas canvas)
                                    (canvas-content-rectangle canvas)
                                    (make-rectangle :pos (make-pos :x 0 :y 0)
                                                    :size (make-size :w (elmtui.platform.api:term-w backend)
                                                                     :h (elmtui.platform.api:term-h backend)))))
                     (laid      (layout-tree styled rect)))
                (when laid
                  ;; Backend handles rendering, diffing, and canvas integration
                  (elmtui.platform.api:render-and-present backend laid (when use-canvas canvas))))))))))

;;; ---------------------------------------------------------------------------
;;; Cleanup helpers
;;; ---------------------------------------------------------------------------

(defun cleanup-application (backend canvas use-canvas)
  (log:info "DRIVER: Starting cleanup...")
  ;; Stop input reader
  (when *stop-input-fn*
    (ignore-errors (funcall *stop-input-fn*))
    (setf *input-thread* nil *stop-input-fn* nil))

  ;; Canvas restore (if used) - this might involve terminal operations via canvas API
  (when (and backend use-canvas canvas)
    (handler-case (elmtui.platform.canvas:restore-terminal-state canvas)
      (error (e) (log:error "DRIVER: Canvas restore failed: ~A" e))))

  ;; Backend shutdown - backend is responsible for its own terminal restoration via API
  (when backend
    (handler-case (elmtui.platform.api:shutdown-backend backend)
      (error (e) (log:error "DRIVER: Backend shutdown error: ~A" e))))
  (setf *backend* nil)
  (log:info "DRIVER: Cleanup complete."))

;;; ---------------------------------------------------------------------------
;;; Public entry point
;;; ---------------------------------------------------------------------------

(defun run-application (app-spec &key
                                   (backend-type         :terminal)
                                   (tty-path             "/dev/tty")
                                   (use-canvas           nil)
                                   (canvas-anchor        :cursor)
                                   (canvas-growth        :down)
                                   (canvas-initial-size  nil)
                                   (canvas-max-size      nil))
  (let* ((publish-fn #'elmtui.core.loop:publish)
         ;; Initialize backend using the API, passing publish-fn for backend-initiated events (e.g., signals)
         (backend (initialize-backend-with-publish-fn backend-type tty-path publish-fn))
         (canvas  (when (and backend use-canvas) ; Ensure backend initialized before canvas
                    (elmtui.platform.canvas:initialize-canvas backend
                                                              :position-strategy canvas-growth
                                                              :anchor-point      canvas-anchor
                                                              :initial-size      canvas-initial-size
                                                              :max-size          canvas-max-size)))
         init-fn update-fn view-fn subs-fn app-state initial-cmds)

    (unless backend
      (log:error "DRIVER: Failed to initialize backend ~A. Aborting." backend-type)
      (return-from run-application (values nil "Backend initialization failed.")))

    (setf *driver-initiated-shutdown-p* nil)
    (handler-case
        (unwind-protect
             (progn
               (setf *backend* backend)
               ;; Signal handlers are now set up by the backend during its initialization.

               (multiple-value-setq (init-fn update-fn view-fn subs-fn app-state initial-cmds)
                 (initialize-app-state app-spec publish-fn))

               ;; Initialize the focus manager
               (setf elmtui.core.globals:*focus-manager* (make-focus-manager))

               (elmtui.core.loop:start-loop :wait t) ; Start the channel-based loop
               (funcall publish-fn (list :set-app-name (getf app-spec :name :unknown)))
               (funcall publish-fn (list :set-driver-shutdown-initiated nil)) ;;

               (multiple-value-bind (th stop-fn) (start-input-reader-thread backend publish-fn)
                 (setf *input-thread* th *stop-input-fn* stop-fn))

               (process-initial-commands initial-cmds publish-fn)

               (setf elmtui.core.globals:*app-message-processor*
                     (lambda (msg current-app-state)
                       (process-event-from-driver msg current-app-state
                                                  backend canvas use-canvas
                                                  view-fn update-fn publish-fn)))
               (when subs-fn
                 (let ((app-subscriptions (funcall subs-fn app-state)))
                   (log:info "DRIVER: Application subscriptions declared: ~A (Note: Ensure events are published to channels)" app-subscriptions)))

               ;; No explicit subscribe for shutdown needed here;
               ;; :shutdown-command published by process-event-from-driver
               ;; will be handled by loop.lisp's process-channel-event.

               (funcall publish-fn '(:force-render)) ; Initial render

               ;; Wait for the event consumer loop to terminate.
               ;; The event consumer loop terminates when *shutdown-requested* (in core.loop) is true.
               (log:info "DRIVER: Main thread now waiting for event consumer loop to terminate...")
               (loop while (and elmtui.core.loop:*consumer-thread* ; Ensure thread object exists
                                (bt:thread-alive-p elmtui.core.loop:*consumer-thread*))
                     do (sleep 0.05)) ; Poll periodically
               (log:info "DRIVER: Event consumer loop has terminated or was not active. Proceeding to cleanup.")
               )
          ;; Unwind clause
          (progn
            (log:info "DRIVER: Entering unwind-protect cleanup clause.")
            ;; 1. Stop the input reader thread first.
            (when *stop-input-fn*
              (log:info "DRIVER: Stopping input reader thread...")
              (ignore-errors (funcall *stop-input-fn*))
              (when (and *input-thread* (bt:thread-alive-p *input-thread*))
                (log:info "DRIVER: Waiting for input thread to join...")
                (let ((joined-p (bt:join-thread *input-thread*))) ; Add a timeout
                  (if joined-p
                      (log:info "DRIVER: Input thread joined.")
                      (log:warn "DRIVER: Input thread did not join in time."))))
              (setf *input-thread* nil *stop-input-fn* nil))

            ;; 2. Ensure the core event loop is stopped (this also joins the consumer thread).
            (log:info "DRIVER: Ensuring core event loop is stopped...")
            (ignore-errors (elmtui.core.loop:elm-stop-loop))
            (log:info "DRIVER: Core event loop stop requested/confirmed.")

            ;; 3. Perform final platform cleanup.
            (cleanup-application backend canvas use-canvas)
            (log:info "DRIVER: Unwind-protect cleanup finished.")))
      ;; Fatal error
      (error (e)
        (log:error "DRIVER: Unhandled error in run-application: ~A~%Backtrace: ~A"
                   e
                   (if (member :sbcl *features*)
                       (with-output-to-string (s) (sb-debug:print-backtrace :stream s :count 10)) ; Removed :condition e
                       "Backtrace not available for this Lisp implementation in this context."))
        (ignore-errors (elmtui.core.loop:elm-stop-loop))
        (cleanup-application backend canvas use-canvas)
        (uiop:quit 1 e)))

    (when (or *driver-initiated-shutdown-p*
              (and *app-state* (state-ref *app-state* :should-quit)))
      (log:info "DRIVER: Exiting cleanly.")
      (uiop:quit 0))
    (values)))

;;; == end/src/platform/driver.lisp ============================================
