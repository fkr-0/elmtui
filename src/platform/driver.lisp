;;;===============================================================
;;; File: src/platform/driver.lisp
;;; Platform Driver with Canvas Integration (refactored)
;;;===============================================================

(uiop:define-package :elmtui.platform.driver
  (:use :cl :elmtui.core.loop
        :elmtui.platform.input :elmtui.platform.output)
  (:import-from :log4cl #:log-debug #:log-info #:log-error)
  (:import-from :elmtui.view.core #:ui-node-type)
  (:import-from :elmtui.view.styled #:apply-stylesheet-to-tree)
  (:import-from :elmtui.view.layout #:layout-tree)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.core.focus #:get-current-focus)
  (:import-from :elmtui.core.keymap
                #:key-event->normalized-key
                #:lookup-keymap)
  (:import-from :elmtui.state #:state-ref)
  (:import-from :elmtui.core.loop :start-loop :stop-loop)
  (:import-from :elmtui.view.geo
                #:make-rectangle #:make-pos #:make-size)
  (:import-from :elmtui.platform.api
                #:term-w #:term-h)
  (:import-from :elmtui.platform.canvas
                #:canvas-buffer
                #:initialize-canvas
                #:prepare-canvas-for-rendering
                #:finalize-canvas-after-rendering
                #:restore-terminal-state
                #:canvas-content-rectangle
                #:apply-canvas-to-buffer)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer
                #:clear-buffer
                #:with-virtual-buffer-lock
                #:buffer-width
                #:buffer-height)
  (:import-from :elmtui.platform.backend.terminal
                #:initialize-backend
                #:force-clear-terminal-and-reset-buffers
                #:resize-terminal-buffers
                #:terminal-instance-front-buffer
                #:terminal-instance-back-buffer
                #:with-terminal-lock)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer
                #:compute-buffer-diff
                #:apply-terminal-diff)
  (:export #:run-application))

(in-package :elmtui.platform.driver)

;; Define the backend and input control variables as specials
(defvar *backend* nil "The current terminal backend instance.")
(defvar *input-thread* nil "The thread handling input events.")
(defvar *stop-input-fn* nil "Function to stop the input thread.")

(defun setup-resize (resize-fun)
  "Sets up a handler for SIGWINCH that calls RESIZE-FUN.
  Argument: RESIZE-FUN - the function to call when SIGWINCH is signaled.
  Returns: NIL.

  Examples:
    (setup-resize #'handle-resize)
     => NIL
    (setup-resize #'handle-resize)
     => NIL"
  (sb-sys:enable-interrupt sb-unix:sigwinch
                           (lambda (signal code scp)
                             (declare (ignore signal code scp))
                             (funcall resize-fun))))

(defun setup-interrupt (interrupt-fun)
  "Sets up a handler for SIGINT that calls INTERRUPT-FUN.
  Argument: INTERRUPT-FUN - the function to call when SIGINT is signaled.
  Returns: NIL.

  Examples:
    (setup-interrupt #'handle-interrupt)
     => NIL
    (setup-interrupt #'handle-interrupt)
     => NIL"
  (sb-sys:enable-interrupt sb-unix:sigint
                           (lambda (signal code scp)
                             (declare (ignore signal code scp))
                             (funcall interrupt-fun))))

;;;;; Helper: initialize backend and clear buffers
(defun initialize-backend-and-reset (backend-type tty-path)
  (let ((be (elmtui.platform.backend.terminal:initialize-backend
             backend-type :tty-path tty-path)))
    (when be
      (elmtui.platform.backend.terminal:force-clear-terminal-and-reset-buffers be))
    be))

;;;;; Helper: setup signal handlers
(defun setup-signal-handlers ()
  (setup-resize
   (lambda ()
     (multiple-value-bind (w h)
         (elmtui.platform.api:get-screen-dimensions *backend*)
       (elmtui.core.loop:publish (list :terminal-resize-request :width w :height h)))))
  (setup-interrupt
   (lambda ()
     (elmtui.core.loop:publish '(:app-quit-requested (:source :sigint))))))

;;;;; Helper: start input reader
(defun start-input-reader (backend-instance)
  "Return two values: thread and stop-fn."
  (multiple-value-bind (thread stop-fn)
      (start-reader backend-instance)
    (values thread stop-fn)))

;;;;; Helper: initialize application state
(defun initialize-app-state (app-spec)
  "Returns: init-fn, update-fn, view-fn, subscriptions-fn, app-state-obj, initial-commands"
  (let* ((init-fn         (getf app-spec :init-fn))
         (update-fn       (getf app-spec :update-fn))
         (view-fn         (getf app-spec :view-fn))
         (subs-fn         (getf app-spec :subscriptions-fn)))
    (unless (and init-fn update-fn view-fn)
      (error "App spec missing required functions"))
    (log:info "Initializing application state for ~A..." (getf app-spec :name))
    (multiple-value-bind (model cmds) (funcall init-fn)
      (let ((st (elmtui.state:make-application-state)))
        (ut.state.state:merge-state st model)
        (setf elmtui.state:*app-state* st))
      (values init-fn update-fn view-fn subs-fn elmtui.state:*app-state* cmds))))

;;;;; Helper: process commands
(defun process-initial-commands (cmds)
  (dolist (cmd cmds)
    (elmtui.core.async:interpret-cmd cmd)))

;;;;; Helper: make update handler
(defun make-update-handler (update-fn view-fn app-state canvas use-canvas)
  "Creates a handler function for processing messages and updating the application state.
    UPDATE-FN: The update function for the application.
    VIEW-FN: The view function for rendering the application.
    APP-STATE: The current application state.
    CANVAS: The canvas object for rendering.
    USE-CANVAS: Boolean indicating if a canvas is used."

  (let ((shutdown-p nil))
    (lambda (message)
      ;; simplified: call update, view, render, diff, swap, canvas integration
      (when (not shutdown-p)
        (let ((cmds (funcall update-fn app-state message)))
          (dolist (c cmds) (elmtui.core.loop:publish c)))
        ;; view + layout + render with canvas-buffer rendering
        (let* ((tree (funcall view-fn app-state #'elmtui.core.loop:publish))
               (styled (apply-stylesheet-to-tree tree (state-ref app-state :current-stylesheet)))
               ;; Only get canvas rectangle if canvas is used and available
               (rect (if (and use-canvas canvas)
                         (canvas-content-rectangle canvas)
                         ;; Otherwise use full terminal dimensions
                         (make-rectangle :pos (make-pos :x 0 :y 0)
                                        :size (make-size :w (term-w *backend*)
                                                       :h (term-h *backend*)))))
               (laid (layout-tree styled rect)))
          (let ((orig-back (terminal-instance-back-buffer *backend*)))
            (when use-canvas
              ;; Fixed canvas buffer clear - correct macro usage
              (let ((canvas-buf (canvas-buffer canvas)))
                (when canvas-buf
                  (with-virtual-buffer-lock (canvas-buf)
                    (clear-buffer canvas-buf))))
              ;; Set terminal back buffer to canvas buffer
              (setf (terminal-instance-back-buffer *backend*)
                    (canvas-buffer canvas)))
            ;; Render to the current back buffer (could be canvas or original)
            (render-frame laid *backend*)
            (when use-canvas
              ;; Restore original back buffer and apply canvas changes
              (setf (terminal-instance-back-buffer *backend*) orig-back)
              (apply-canvas-to-buffer canvas orig-back))
            ;; Compute and apply diffs between front and back buffers
            (let ((f (terminal-instance-front-buffer *backend*))
                  (b (terminal-instance-back-buffer *backend*)))
              (when (and f b
                         (= (buffer-width f) (buffer-width b))
                         (= (buffer-height f) (buffer-height b)))
                (with-terminal-lock (*backend*)
                  (apply-terminal-diff *backend* (compute-buffer-diff f b)))
                (rotatef (terminal-instance-front-buffer *backend*)
                         (terminal-instance-back-buffer *backend*))))))
        ;; quit logic omitted for brevity
        ))))

;;;;; Helper: subscribe events
(defun subscribe-default-events (handler subs-fn)
  (when subs-fn
    (dolist (ev (funcall subs-fn elmtui.state:*app-state*))
      (elmtui.core.loop:subscribe ev handler)))
  (dolist (ev '(:app-quit-requested :terminal-resize-request :key-event :force-render))
    (elmtui.core.loop:subscribe ev handler)))

;;;;; Helper: cleanup
(defun cleanup-application (backend canvas use-canvas)
  (when (and backend use-canvas)
    (restore-terminal-state canvas))
  (when backend
    (elmtui.platform.api:shutdown-backend backend))
  (log:info "Driver: cleanup complete."))

;;;;; Refactored run-application
(defun run-application (app-spec &key
                                   (backend-type :terminal)
                                   (tty-path "/dev/tty")
                                   (use-canvas nil)
                                   (canvas-anchor :cursor)
                                   (canvas-growth :down)
                                   (canvas-initial-size nil)
                                   (canvas-max-size nil))
  "Entrypoint for running an elmtui application."
  (let* ((backend (initialize-backend-and-reset backend-type tty-path))
         (canvas (when use-canvas
                   (initialize-canvas
                    backend
                    :position-strategy canvas-growth
                    :anchor-point    canvas-anchor
                    :initial-size    canvas-initial-size
                    :max-size        canvas-max-size))))
    (handler-case
        (unwind-protect
             (progn
               ;; Set our special variables
               (setf *backend* backend)
               (setup-signal-handlers)
               ;; Set up input handling
               (multiple-value-bind (th stop-fn) (start-input-reader backend)
                 (setf *input-thread* th
                       *stop-input-fn* stop-fn))
               ;; Initialize application
               (multiple-value-bind (init-fn upd-fn view-fn subs-fn state cmds)
                   (initialize-app-state app-spec)
                 ;; process initial commands from init
                 (process-initial-commands cmds)
                 ;; Create update handler and set up subscriptions
                 (let ((handler (make-update-handler upd-fn view-fn state canvas use-canvas)))
                   (subscribe-default-events handler subs-fn)
                   ;; trigger first render
                   (elmtui.core.loop:publish '(:force-render))))
               ;; Start the main event loop
               (elmtui.core.loop:start-loop))
          ;; Always clean up on exit
          (cleanup-application backend canvas use-canvas)))
    (values)))
