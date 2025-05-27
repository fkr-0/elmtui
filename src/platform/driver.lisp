;;;===============================================================
;;; File: src/platform/driver.lisp
;;; Platform Driver with Canvas Integration (refactored)
;;;===============================================================

(uiop:define-package :elmtui.platform.driver
  (:use :cl :elmtui.core.loop
        :elmtui.platform.input :elmtui.platform.output)
  (:import-from :log4cl #:log-debug #:log-info #:log-error #:log-warn)
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
      ;; Enhance logging for message diagnosis
      (log:debug "Handler received message: ~S, type: ~A" message (type-of message))

      ;; Process message only if we're not already shutting down
      (when (not shutdown-p)
        ;; Check for quitting conditions
        (log:debug "Checking message: ~S, should-quit flag: ~S" message (elmtui.state:state-ref app-state :should-quit))
        (when (check-and-handle-quit app-state message)
          (log:info "Application termination requested. Initiating shutdown...")
          (setf shutdown-p t)
          ;; Dispatch-event-async to the command-event-channel
          (when (and (find-package :elmtui.core.event-async)
                     (fboundp (find-symbol "DISPATCH-EVENT-ASYNC" :elmtui.core.event-async)))
            (log:debug "Dispatching :shutdown command via channel")
            (funcall (find-symbol "DISPATCH-EVENT-ASYNC" :elmtui.core.event-async)
                     '(:command :shutdown)))
          (return-from make-update-handler nil))

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
                         (terminal-instance-back-buffer *backend*))))))))))
;;;;; Helper: check-and-handle-quit
(defun check-and-handle-quit (app-state message)
  "Check if the application should quit based on message or state.
   Returns T if quitting, NIL otherwise."
  ;; Check explicit quit message
  (when (and (listp message) (eq (first message) :app-quit-requested))
    (log:info "Application quit requested via message: ~A" message)
    (elmtui.core.loop:elm-stop-loop)
    (return-from check-and-handle-quit t))

  ;; Check application state
  (when (elmtui.state:state-ref app-state :should-quit)
    (log:info "Application quit requested via state flag")
    (elmtui.core.loop:elm-stop-loop)
    (return-from check-and-handle-quit t))
    
  ;; Check for key events in the rainbow-app example that should trigger quit
  (when (or 
         ;; Check for key-event list format
         (and (listp message) (eq (first message) :key-event))
         ;; Check for key-event structure format
         (typep message 'elmtui.core.event-types:key-event))
    (when (eql (elmtui.state:state-ref app-state :app-name) :rainbow-example-app)
      (log:info "Rainbow app - key press detected, quitting: ~A" message)
      (elmtui.state:update-state app-state (list :should-quit t))
      (elmtui.core.loop:elm-stop-loop)
      (return-from check-and-handle-quit t)))

  ;; Not quitting
  nil)

(defun subscribe-default-events (handler subscriptions-fn)
  "Subscribes the handler to events specified by subscriptions-fn.
   HANDLER: The function to call when a subscribed event occurs.
   SUBSCRIPTIONS-FN: A function that returns a list of event types/topics to subscribe to."
  (when subscriptions-fn
    (let ((subscriptions (funcall subscriptions-fn elmtui.state:*app-state*))) ; Assuming subs-fn might need app-state
      (if (listp subscriptions)
          (dolist (event-type subscriptions)
            (log-debug "Subscribing to event type: ~A" event-type)
            (elmtui.core.loop:subscribe event-type handler))
          (log-warn "Subscriptions function did not return a list: ~S" subscriptions)))))

;;;;; Helper: cleanup
(defun cleanup-application (backend canvas use-canvas)
  "Perform comprehensive cleanup of the terminal environment and application resources.
   Ensures terminal state is properly restored and all resources are released."
  (log:info "Starting application cleanup...")
  
  ;; Track cleanup success
  (let ((terminal-restored nil))

    ;; Stop input thread if it exists
    (when *stop-input-fn*
      (log:debug "Stopping input thread...")
      (ignore-errors
       (funcall *stop-input-fn*))
      (setf *input-thread* nil
            *stop-input-fn* nil))

    ;; Reset terminal state using canvas if available
    ;; This is a critical step for restoring proper terminal state
    (when (and backend use-canvas canvas)
      (log:debug "Restoring terminal state from canvas...")
      (handler-case
          (progn
            (restore-terminal-state canvas)
            (setf terminal-restored t)
            (log:info "Terminal state restored successfully via canvas"))
        (error (e)
          (log:error "Failed to restore terminal state via canvas: ~A" e))))

  ;; Force terminal cursor to be visible and reset terminal attributes
  (unless terminal-restored
    (when backend
      (log:debug "Terminal not restored by canvas, performing manual terminal cleanup...")
      (handler-case
          (progn
            ;; Try using the with-terminal-output macro
            (elmtui.platform.api:with-terminal-output (backend stream)
              (let ((*standard-output* stream))
                ;; ANSI escape sequences to ensure terminal reset
                (format t "~c[?25h" #\Escape)  ; Show cursor
                (format t "~c[0m" #\Escape)    ; Reset all attributes
                (format t "~c[J" #\Escape)     ; Clear screen (optional)
                (format t "~c[H" #\Escape)     ; Return cursor home
                (format t "~%") ; Add a newline at the end
                (finish-output t)))
            (setf terminal-restored t))
        (error (e)
          ;; Fallback method if with-terminal-output fails
          (log:warn "Could not use with-terminal-output: ~A, using direct methods" e)
          (handler-case
              (let ((stream (elmtui.platform.api:term-stream backend)))
                (when stream
                  (format stream "~c[?25h~c[0m~c[J~c[H~%" #\Escape #\Escape #\Escape #\Escape)
                  (finish-output stream)
                  (setf terminal-restored t)))
            (error (e2)
              (log:error "Failed to restore terminal via direct stream: ~A" e2)))))))

  ;; Shutdown the backend properly
  (when backend
    (handler-case
        (elmtui.platform.api:shutdown-backend backend)
      (error (e)
        (log:error "Error during backend shutdown: ~A" e))))

  ;; Clear the special variables
  (setf *backend* nil)

  ;; Reset terminal using stty commands as a last resort
  (unless terminal-restored
    (log:warn "Attempting terminal restoration via stty sane as last resort...")
    (handler-case
        (progn
          (sb-ext:run-program "/bin/stty" '("sane") :input nil :output nil :error nil :search t)
          (log:info "Terminal reset with stty sane"))
      (error (e)
        (log:error "Failed to reset terminal with stty: ~A" e))))

  ;; Final report
  (if terminal-restored
      (log:info "Driver: cleanup complete with terminal state restored")
      (log:error "Driver: cleanup complete but terminal state restoration may have failed")))

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

                 ;; Store application name in state for identification
                 (elmtui.state:update-state state (list :app-name (if (symbolp app-spec) app-spec :unknown-app)))
                 
                 ;; Set up channel-based event processing if available
                 (when (and (find-package :elmtui.core.event-async)
                            (fboundp (find-symbol "INITIALIZE-EVENT-CHANNELS" :elmtui.core.event-async))
                            (fboundp (find-symbol "START-EVENT-PROCESSING" :elmtui.core.event-async)))
                   (log:info "Using channel-based event processing")
                   (handler-case
                       (progn
                         (funcall (find-symbol "INITIALIZE-EVENT-CHANNELS" :elmtui.core.event-async))
                         (funcall (find-symbol "START-EVENT-PROCESSING" :elmtui.core.event-async)
                                  ;; Lambda to provide UI tree
                                  (lambda () (funcall view-fn state #'elmtui.core.loop:publish))))
                     (error (e)
                       (log:error "Failed to initialize channel-based event processing: ~A" e))))

                 ;; Create update handler and set up subscriptions
                 (let ((handler (make-update-handler upd-fn view-fn state canvas use-canvas)))
                   (subscribe-default-events handler subs-fn)
                   ;; trigger first render
                   (elmtui.core.loop:publish '(:force-render))))
               ;; Start the main event loop and ensure it terminates properly
               (elmtui.core.loop:start-loop)
               (log:info "Event loop terminated. Starting cleanup..."))
          ;; Always clean up on exit
          (progn
            ;; Stop channel-based event processing if active
            (when (and (find-package :elmtui.core.event-async)
                       (fboundp (find-symbol "STOP-EVENT-PROCESSING" :elmtui.core.event-async)))
              (funcall (find-symbol "STOP-EVENT-PROCESSING" :elmtui.core.event-async)))
            ;; Clean up application resources
            (cleanup-application backend canvas use-canvas)))
      ;; Handle any errors during execution
      (error (condition)
        (log:error "Error in application: ~A" condition)
        ;; Stop channel-based event processing if active
        (when (and (find-package :elmtui.core.event-async)
                   (fboundp (find-symbol "STOP-EVENT-PROCESSING" :elmtui.core.event-async)))
          (funcall (find-symbol "STOP-EVENT-PROCESSING" :elmtui.core.event-async)))
        ;; Clean up application resources
        (cleanup-application backend canvas use-canvas)))
    (values)))

;;; Driver code for testing the application
(defun driver-test ()
  (run-application
   '(:name test-app
     :init-fn (lambda () (values nil nil))
     :update-fn (lambda (state msg) (list msg))
     :view-fn (lambda (state publish) (publish '(:render-request)))
     :subscriptions-fn (lambda (state) (list :app-quit-requested))))
  (format t "Driver test completed.~%"))
