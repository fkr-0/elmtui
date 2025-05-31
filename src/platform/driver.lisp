;;; == src/platform/driver.lisp ===============================================
;;; Platform Driver with Canvas Integration and Channel-Based Events
;;;============================================================================

(uiop:define-package :elmtui.platform.driver
  (:use :cl
   :elmtui.platform.input
        :elmtui.platform.output)
  (:import-from :log4cl
                #:log-debug   #:log-info   #:log-warn   #:log-error)
  (:import-from :elmtui.view.core
                #:ui-node-type #:ui-node-props)
  (:import-from :elmtui.view.styled
                #:apply-stylesheet-to-tree)
  (:import-from :elmtui.view.layout
                #:layout-tree)
  (:import-from :elmtui.core.event-types
                #:key-event)
  (:import-from :elmtui.core.globals
                ;; Removed *main-event-channel*
                #:*app-state* #:*app-message-processor*
                #:*app-sender*)
  (:import-from :elmtui.core.focus
                #:get-current-focus)
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
                #:term-w #:term-h #:get-screen-dimensions
                #:shutdown-backend #:with-terminal-output #:term-stream)
  (:import-from :elmtui.platform.canvas
                #:canvas-buffer #:initialize-canvas #:prepare-canvas-for-rendering
                #:finalize-canvas-after-rendering #:restore-terminal-state
                #:canvas-content-rectangle #:apply-canvas-to-buffer)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer #:clear-buffer #:with-virtual-buffer-lock
                #:buffer-width #:buffer-height)
  (:import-from :elmtui.platform.backend.terminal
                #:initialize-backend #:force-clear-terminal-and-reset-buffers
                #:resize-terminal-buffers #:terminal-instance-front-buffer
                #:terminal-instance-back-buffer #:with-terminal-lock)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer
                #:compute-buffer-diff #:apply-terminal-diff)
  (:import-from :elmtui.core.loop
                #:publish #:start-loop #:elm-stop-loop) ; Removed subscribe, unsubscribe
  (:import-from :elmtui.core.async
                #:interpret-cmd)
  (:export #:run-application))

(in-package :elmtui.platform.driver)

;;; ---------------------------------------------------------------------------
;;; Global state
;;; ---------------------------------------------------------------------------

(defvar *backend*                       nil "Current terminal backend instance.")
(defvar *input-thread*                  nil "Thread handling input events.")
(defvar *stop-input-fn*                 nil "Function to stop the input thread.")
(defvar *driver-initiated-shutdown-p*   nil "T if driver requested shutdown.")

;;; ---------------------------------------------------------------------------
;;; Helper utilities
;;; ---------------------------------------------------------------------------

;; publish-to-channel is now a local let binding in run-application, pointing to elmtui.core.loop:publish

(defun setup-resize (resize-fn publish-fn)
  (sb-sys:enable-interrupt sb-unix:sigwinch
                           (lambda (signal code scp)
                             (declare (ignore signal code scp))
                             (funcall resize-fn publish-fn))))

(defun setup-interrupt (interrupt-fn publish-fn)
  (sb-sys:enable-interrupt sb-unix:sigint
                           (lambda (signal code scp)
                             (declare (ignore signal code scp))
                             (funcall interrupt-fn publish-fn))))

(defun initialize-backend-and-reset (backend-type tty-path)
  (let ((be (initialize-backend backend-type :tty-path tty-path)))
    (when be
      (log:info "DRIVER: Forcing initial clear of terminal and reset of buffers.")
      (force-clear-terminal-and-reset-buffers be))
    be))

(defun setup-signal-handlers (backend-instance publish-fn)
  (setup-resize
   (lambda (publish-handler)
     (multiple-value-bind (w h)
         (get-screen-dimensions backend-instance)
       (log:info "DRIVER: SIGWINCH detected. Publishing :terminal-resize-request W:~A H:~A" w h)
       ;; This will be wrapped as (:app-message (:terminal-resize-request ...)) by publish
       (funcall publish-handler (list :terminal-resize-request :width w :height h))))
   publish-fn)
  (setup-interrupt
   (lambda (publish-handler)
     ;; This will be wrapped as (:app-message (:app-quit-requested ...)) by publish
     (funcall publish-handler '(:app-quit-requested (:source :sigint))))
   publish-fn))

(defun start-input-reader-channel (backend-instance publish-fn)
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
    (log:info "Initializing application state for ~A..." (getf app-spec :name))
    (multiple-value-bind (initial-model cmds) (funcall init-fn)
      (let ((st (make-application-state)))
        (merge-state st initial-model)
        (setf *app-state* st)
        (setf elmtui.core.globals:*app-sender* publish-fn)) ; Set *app-sender*
      (values init-fn update-fn view-fn subs-fn *app-state* cmds))))

(defun process-initial-commands (cmds publish-fn)
  (when cmds
    (log:debug "Processing initial commands...")
    (dolist (cmd cmds)
      (if (and (consp cmd) (eq (first cmd) :command)) ; Check if it looks like a command for interpret-cmd
          (interpret-cmd cmd)
          (funcall publish-fn cmd))))) ; publish will wrap as :app-message

;;; ---------------------------------------------------------------------------
;;; Main event handler (becomes *app-message-processor*)
;;; ---------------------------------------------------------------------------

(defun process-event-from-driver
    (event app-state backend canvas use-canvas view-fn update-fn publish-fn)
  "Core dispatcher for every EVENT coming from the async channel, now as *app-message-processor*."
  (block handler-block
    (log:info "DRIVER: EVENT (via *app-message-processor*): ~S" event)

    (when (state-ref app-state :driver-shutdown-initiated)
      (log:warn "DRIVER: Shutdown in progress – ignoring ~S" event)
      (return-from handler-block nil))

    (let ((effective-message event)
          (event-handled-by-widget-keymap nil))
      (when (typep event 'key-event)
        (let ((wid (get-current-focus app-state)))
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
                        (let ((bt (getf binding :type))
                              (tg (getf binding :target)))
                          (ecase bt
                            (:message
                             (setf effective-message
                                   (list :dispatch-to-widget wid tg binding)
                                   event-handled-by-widget-keymap :message-dispatched))
                            (:action
                             (setf effective-message
                                   (list :dispatch-action-to-widget wid tg binding)
                                   event-handled-by-widget-keymap :action-dispatched))))))))))))

      (cond
        ((equal effective-message '(:force-render))
         (log:info "DRIVER: :FORCE-RENDER received – skipping UPDATE-FN."))

        ((and (listp effective-message)
              (eq (first effective-message) :terminal-resize-request))
         (destructuring-bind (&key width height) (rest effective-message)
           (log:info "DRIVER: Resizing terminal to ~Ax~A" width height)
           (resize-terminal-buffers backend width height)
           (force-clear-terminal-and-reset-buffers backend)
           (funcall publish-fn (list :terminal-resized :width width :height height))
           (funcall publish-fn '(:force-render))
           (return-from handler-block nil)))

        ((and (listp effective-message) (eq (first effective-message) :app-quit-requested))
         (log:info "DRIVER: :APP-QUIT-REQUESTED received: ~S" effective-message)
         (let ((cmds (funcall update-fn app-state effective-message)))
           (dolist (cmd cmds) (funcall publish-fn cmd))))
        (t
         (let ((cmds (funcall update-fn app-state effective-message)))
           (dolist (cmd cmds) (funcall publish-fn cmd))))))

      (let ((quitp (or (and (listp event) (eq (first event) :app-quit-requested))
                       (state-ref app-state :should-quit))))
        (if quitp
            (progn
              (unless (state-ref app-state :driver-shutdown-initiated)
                (setf *driver-initiated-shutdown-p* t)
                (log:info "DRIVER: Initiating shutdown due to quit condition.")
                ;; Publish a specific command that process-channel-event in loop.lisp will handle
                (funcall publish-fn :shutdown-command :target-channel-name :system))) ; Or :command
            (when (not (state-ref app-state :driver-shutdown-initiated))
              (let* ((tree      (funcall view-fn app-state publish-fn))
                     (styled    (apply-stylesheet-to-tree
                                 tree (state-ref app-state :current-stylesheet)))
                     (rect      (if (and use-canvas canvas)
                                    (canvas-content-rectangle canvas)
                                    (make-rectangle :pos (make-pos :x 0 :y 0)
                                                    :size (make-size :w (term-w backend)
                                                                     :h (term-h backend)))))
                     (laid      (layout-tree styled rect)))
                (when laid
                  (let ((orig-back (terminal-instance-back-buffer backend)))
                    (when use-canvas
                      (let ((cb (canvas-buffer canvas)))
                        (with-virtual-buffer-lock (cb) (clear-buffer cb))
                        (setf (terminal-instance-back-buffer backend) cb)))
                    (render-frame laid backend)
                    (when use-canvas
                      (setf (terminal-instance-back-buffer backend) orig-back)
                      (apply-canvas-to-buffer canvas orig-back)))
                  (let ((f (terminal-instance-front-buffer backend))
                        (b (terminal-instance-back-buffer  backend)))
                    (if (and f b
                             (= (buffer-width  f) (buffer-width  b))
                             (= (buffer-height f) (buffer-height b)))
                        (progn
                          (let ((ops (compute-buffer-diff f b)))
                            (when ops
                              (with-terminal-lock (backend)
                                (apply-terminal-diff backend ops))))
                          (rotatef (terminal-instance-front-buffer backend)
                                   (terminal-instance-back-buffer  backend)))
                        (log:error "DRIVER: Buffer mismatch – skipping diff/swap.")))))))))))

;;; ---------------------------------------------------------------------------
;;; Cleanup helpers
;;; ---------------------------------------------------------------------------

(defun cleanup-application (backend canvas use-canvas)
  (log:info "Starting cleanup...")
  (let ((terminal-restored nil))
    ;; Stop input reader
    (when *stop-input-fn*
      (ignore-errors (funcall *stop-input-fn*))
      (setf *input-thread* nil *stop-input-fn* nil))
    ;; Try canvas restore
    (when (and backend use-canvas canvas)
      (handler-case
          (progn (restore-terminal-state canvas) (setf terminal-restored t))
        (error (e) (log:error "Canvas restore failed: ~A" e))))
    ;; Fallback: escape sequences
    (unless terminal-restored
      (when backend
        (handler-case
            (with-terminal-output (backend stream)
              (format stream "~c[?25h~c[0m~c[J~c[H" #\Escape #\Escape #\Escape #\Escape)
              (finish-output stream)
              (setf terminal-restored t))
          (error () (log:warn "with-terminal-output failed, trying raw stream.")
            (handler-case
                (let ((s (term-stream backend)))
                  (when s
                    (format s "~c[?25h~c[0m~c[J~c[H" #\Escape #\Escape #\Escape #\Escape)
                    (finish-output s) (setf terminal-restored t)))
              (error (e2) (log:error "Raw stream restore failed: ~A" e2)))))))
    ;; Backend shutdown
    (when backend
      (handler-case (shutdown-backend backend)
        (error (e) (log:error "Backend shutdown error: ~A" e))))
    (setf *backend* nil)
    ;; Last-ditch stty sane
    (unless terminal-restored
      (handler-case (sb-ext:run-program "/bin/stty" '("sane") :search t)
        (error (e) (log:error "stty sane failed: ~A" e))))
    (log:info "Cleanup complete (terminal restored: ~A)" terminal-restored)))

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
         (backend (initialize-backend-and-reset backend-type tty-path))
         (canvas  (when use-canvas
                    (initialize-canvas backend
                                       :position-strategy canvas-growth
                                       :anchor-point      canvas-anchor
                                       :initial-size      canvas-initial-size
                                       :max-size          canvas-max-size)))
         init-fn update-fn view-fn subs-fn app-state initial-cmds)
    (setf *driver-initiated-shutdown-p* nil)
    (handler-case
        (unwind-protect
             (progn
               (setf *backend* backend)
               (setup-signal-handlers backend publish-fn)
               (multiple-value-setq (init-fn update-fn view-fn subs-fn app-state initial-cmds)
                 (initialize-app-state app-spec publish-fn))
               (funcall publish-fn (list :set-app-name (getf app-spec :name :unknown)))
               (funcall publish-fn (list :set-driver-shutdown-initiated nil))
               (multiple-value-bind (th stop-fn) (start-input-reader-channel backend publish-fn)
                 (setf *input-thread* th *stop-input-fn* stop-fn))
               (process-initial-commands initial-cmds publish-fn)
               (setf elmtui.core.globals:*app-message-processor*
                     (lambda (msg current-app-state)
                       (process-event-from-driver msg current-app-state
                                                  backend canvas use-canvas
                                                  view-fn update-fn publish-fn)))
               (when subs-fn
                 (let ((app-subscriptions (funcall subs-fn app-state)))
                   (log:info "DRIVER: Application subscriptions declared: ~S (Note: Legacy subscribe removed, ensure events are published to channels)" app-subscriptions)))
               
               ;; Removed legacy (elmtui.core.loop:subscribe :command ...) for shutdown.
               ;; Shutdown is now handled by publishing :shutdown-command to a channel (see process-event-from-driver).

               (funcall publish-fn '(:force-render))
               (elmtui.core.loop:start-loop :wait t) ; Call start-loop without :use-new-event-channels
               )
          (progn
            (unless (or *driver-initiated-shutdown-p*
                        (and *app-state* (state-ref *app-state* :should-quit)))
              (log:info "DRIVER: Unwinding, ensuring event loop is stopped.")
              (ignore-errors (elmtui.core.loop:elm-stop-loop)))
            (cleanup-application backend canvas use-canvas)))
      (error (e)
        (log:error "Unhandled error: ~A" e)
        (ignore-errors (elmtui.core.loop:elm-stop-loop))
        (cleanup-application backend canvas use-canvas)
        (uiop:quit 1 e)))
    (when (or *driver-initiated-shutdown-p*
              (and *app-state* (state-ref *app-state* :should-quit)))
      (log:info "DRIVER: Exiting cleanly.")
      (uiop:quit 0))
    (values)))

;;; == end/src/platform/driver.lisp ============================================
