;;; src/events/loop.lisp
(in-package :cl-events.loop)

(defparameter +default-poll-timeout-seconds+ 0.02
  "Default timeout (seconds) for poll-based event loops.")

(defparameter *default-runtime-error-action* :stop
  "Default action for runtime poll/consume errors. Allowed: :stop or :restart.")

(defun default-runtime-error-policy (error)
  "Default runtime error policy; currently always stops the loop."
  (declare (ignore error))
  *default-runtime-error-action*)

(defun resolve-runtime-error-action (policy error)
  "Resolve POLICY to a concrete runtime error action (:stop or :restart).
POLICY can be a keyword action or a function of ERROR."
  (let ((action (cond
                  ((functionp policy) (funcall policy error))
                  ((keywordp policy) policy)
                  (t *default-runtime-error-action*))))
    (if (member action '(:stop :restart))
        action
        *default-runtime-error-action*)))

(defun poll-runtime-event (channels wait-fn &key (timeout +default-poll-timeout-seconds+))
  "Delegate runtime event polling to WAIT-FN with a standard timeout contract.
Returns the same multiple values produced by WAIT-FN."
  (funcall wait-fn channels :timeout timeout))

(defun runtime-consume-once (&key stop-p poll-fn on-event on-empty on-error)
  "Execute one runtime consume iteration with policy hooks.
Returns one of :stop, :event, :idle, :continue, :restart, or :error."
  (when (and stop-p (funcall stop-p))
    (return-from runtime-consume-once :stop))
  (handler-case
      (multiple-value-bind (event source) (funcall poll-fn)
        (if event
            (progn
              (funcall on-event event source)
              :event)
            (progn
              (when on-empty
                (funcall on-empty))
              :idle)))
    (error (e)
      (if on-error
          (or (funcall on-error e) :error)
          :error))))

(defun run-consumer-loop-shell (&key stop-p channels-fn on-idle step-fn on-restart)
  "Reusable consumer lifecycle shell.
Loops until STOP-P is true or STEP-FN requests stop/restart.
When CHANNELS-FN returns NIL, ON-IDLE is called.
STEP-FN should return an action keyword; :stop and :restart are handled explicitly."
  (loop
    (when (and stop-p (funcall stop-p))
      (return :stop))
    (if (null (funcall channels-fn))
        (progn
          (when on-idle
            (funcall on-idle))
          nil)
        (restart-case
            (case (funcall step-fn)
              (:stop (return :stop))
              (:restart (invoke-restart 'restart-loop))
              (otherwise nil))
          (restart-loop ()
            :report "Restart runtime consumer loop."
            (when on-restart
              (funcall on-restart))
            (return :restart))))))

(defun select-primary-channel (channels desired-name name-fn &key (test #'eq))
  "Select channel from CHANNELS by DESIRED-NAME using NAME-FN, fallback to first."
  (or (find desired-name channels :key name-fn :test test)
      (first channels)))

(defun make-join-deadline (seconds &optional (now-fn #'get-internal-real-time))
  "Return an internal-time deadline SECONDS from NOW-FN."
  (+ (funcall now-fn)
     (round (* seconds internal-time-units-per-second))))

(defun deadline-expired-p (deadline &optional (now-fn #'get-internal-real-time))
  "Return true when NOW-FN has reached or passed DEADLINE."
  (>= (funcall now-fn) deadline))

(defstruct (app-context (:constructor %make-app-context))
  bus          ;; event-bus
  event-ch     ;; merged input channel
  stop-flag    ;; mailbox or flag
  render-lock) ;; optional if renderer isn't thread-safe

(defun make-app-context (&key bus event-ch)
  (%make-app-context :bus (or bus (cl-events.bus:make-event-bus))
                     :event-ch (or event-ch (cl-events.channel:make-channel))
                     :stop-flag (cl-events.channel:make-mailbox)
                     :render-lock (bt:make-lock "render")))

(defun run-app-loop (&key initial-state app-ctx)
  (let* ((ctx (or app-ctx (make-app-context)))
         (state initial-state)
         (bus (app-context-bus ctx))
         (ech (app-context-event-ch ctx)))
    (labels ((tick ()
               ;; 1) take next event
               (multiple-value-bind (ev status)
                   (cl-events.channel:chan-take ech)
                 (when (eq status :closed) (return-from tick))
                 ;; 2) dispatch event -> messages -> update
                 (multiple-value-bind (new-state cmds)
                     (cl-events.dispatcher:dispatch-event ev bus state)
                   (setf state new-state)
                   ;; 3) view + render (outside update, on main loop)
                   (let ((vm (cl-events.protocols:app-view state)))
                     (bt:with-lock-held ((app-context-render-lock ctx))
                       (cl-events.protocols:perform-render vm state)))
                   ;; 4) run side-effects
                   (cl-events.dispatcher:execute-commands cmds ctx))
                 (when (cl-events.channel:mb-take (app-context-stop-flag ctx))
                   (return-from tick))))
             (loop-body ()
               (loop do (tick))))
      (spawn-task #'loop-body :name "app-loop")
      ctx)))

(defun stop-app-loop (ctx)
  (cl-events.channel:mb-put (app-context-stop-flag ctx) t)
  (cl-events.channel:chan-close (app-context-event-ch ctx))
  t)
