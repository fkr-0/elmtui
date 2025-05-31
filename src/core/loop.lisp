;;;===============================================================
;;; File: src/core/loop.lisp
;;; Event Loop & Dispatcher (Channel-Based System)
;;;===============================================================
(uiop:define-package :elmtui.core.loop
  (:use :cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-warn #:log-info)
  (:import-from :elmtui.core.globals
   :*event-loop* :*app-state* :*app-message-processor* :*app-sender*) ; Removed *subscribers*, *main-event-channel*
  (:import-from :elmtui.core.conditions
                ;; Removed :signal-subscriber-error, :subscriber-handler-error
                :event-loop-dispatch-error :async-task-error)
  ;; Removed :cleve-elm.message import as message-type not directly used here after legacy removal
  ;; Removed :elmtui.core.keymap.event-integration #:subscribe (legacy)
  ;; Removed :elmtui.core.event-types import (legacy publish-sync-internal used it)
  (:import-from :cleve-elm.event-loop ; For legacy event loop structure (still used for *event-loop* instance)
   :event-loop :make-event-loop :run-loop :stop-loop :event-loop-active-p)
  (:import-from :cleve-elm.channel
                #:make-channel #:channel-close #:channel-closed
                #:-> #:<- #:channel-queue) ; Added channel-queue for get-event-queue-length
  (:import-from :cleve-elm.queue #:queue-length) ; Added for get-event-queue-length
  (:import-from :elmtui.core.event-channels
                #:event-channel #:handlers #:name #:channel-of
                #:select-from-channels #:standard-event-channels)
  (:import-from :elmtui.state.update #:handle-async-command)
  (:export :start-loop
           :elm-stop-loop
           :publish
           ;; Removed :enqueue-event, :dispatch-event, :subscribe-with-priority, :unsubscribe, :subscribe, :publish-sync-internal
           ;; Removed :*lifecycle-hooks*, :*subscribers*, :*main-event-channel*
           :*event-loop* ; *event-loop* is the cleve-elm.event-loop:event-loop instance, might still be relevant
           :get-event-loop-status :get-event-queue-length
           :instrument-event-loop)) ; Removed :elm-event-loop-active-p (use get-event-loop-status)
(in-package :elmtui.core.loop)

;; Event processing variables
(defvar *consumer-thread* nil "Thread for consuming events from *active-event-channels*")
(defvar *shutdown-requested* nil "Flag to signal the consumer thread to shutdown")
(defvar *event-loop-metrics* (make-hash-table :test 'eq) "Metrics for event processing")
(defvar *event-processing-time-history* (make-array 100 :initial-element 0 :fill-pointer 0 :adjustable t)
  "History of event processing times in milliseconds")

(defvar *active-event-channels* nil "List of active event-channel objects from event-channels.lisp")

(defun start-loop (&key (fps 60) (wait t))
  "Initialize and start the main event loop using the channel-based system."
  (declare (ignore fps))

  (unless *active-event-channels*
    (setf *active-event-channels* (elmtui.core.event-channels:standard-event-channels))
    (log-info "LOOP: Initialized with event-channel objects: ~S"
              (mapcar #'elmtui.core.event-channels:name *active-event-channels*)))
  (log-info "LOOP: Channel-based event system activated.")
  
  ;; Set the global *app-sender* to this system's publish function
  (setf elmtui.core.globals:*app-sender* #'publish)
  (log-info "LOOP: *app-sender* set to #'elmtui.core.loop:publish (channel system)")

  (unless *event-loop*
    ;; This *event-loop* is the cleve-elm.event-loop:event-loop instance.
    ;; If it's purely legacy and not used by any part of the new system, it could be removed.
    ;; For now, keeping its initialization as it might be used for other purposes by cleve-elm.
    (setf *event-loop* (make-instance 'cleve-elm.event-loop:event-loop))
    (log-info "LOOP: Legacy cleve-elm.event-loop:event-loop structure initialized (if still used)."))

  (when (and (null *consumer-thread*) (not *shutdown-requested*))
    (setf *shutdown-requested* nil)
    (setf *consumer-thread*
          (bt:make-thread #'event-consumer-loop
                          :name "elmtui-event-consumer"))
    (log-info "LOOP: Started event consumer thread for channel system."))

  ;; This part relates to cleve-elm.event-loop:run-loop.
  ;; If *event-loop* is truly unused, this can also be removed.
  (if wait
      (when (and *event-loop* (not (cleve-elm.event-loop:event-loop-active-p *event-loop*)))
        (cleve-elm.event-loop:run-loop *event-loop*))
      (when (and *event-loop* (not (cleve-elm.event-loop:event-loop-active-p *event-loop*)))
        (bt:make-thread (lambda () (cleve-elm.event-loop:run-loop *event-loop*))
                        :name "elmtui-aux-event-loop")))
  t)

(defun event-consumer-loop ()
  "Consumer loop for processing events from *active-event-channels*."
  (log-info "EVENT-CONSUMER: Starting loop for ~D active event-channel(s)." (length *active-event-channels*))
  (loop
    (when *shutdown-requested*
      (log-info "EVENT-CONSUMER: Shutdown requested, exiting loop.")
      (return))
    (handler-case
        (if (null *active-event-channels*)
            (progn
              (log-warn "EVENT-CONSUMER: No active event channels. Sleeping briefly.")
              (sleep 0.1)
              nil)
            (multiple-value-bind (event source-clevelib-channel)
                (let ((clevelib-channels (mapcar #'elmtui.core.event-channels:channel-of *active-event-channels*)))
                  (elmtui.core.event-channels:select-from-channels clevelib-channels :timeout 1.0))
              (when event
                (let ((wrapper-channel-object
                       (find source-clevelib-channel *active-event-channels* :key #'elmtui.core.event-channels:channel-of :test #'eq)))
                  (cond
                    ((eq event :shutdown-loop) ; Special signal to break loop, sent by elm-stop-loop
                     (log-info "EVENT-CONSUMER: Received :shutdown-loop signal on channel ~A."
                               (if wrapper-channel-object (elmtui.core.event-channels:name wrapper-channel-object) "unknown"))
                     (setf *shutdown-requested* t)
                     (return))
                    (wrapper-channel-object
                     (process-channel-event event wrapper-channel-object))
                    (t
                     (log-warn "EVENT-CONSUMER: Received event ~S from an unknown clevelib channel ~S." event source-clevelib-channel)))))))
      (error (e)
        (log-error "EVENT-CONSUMER: Error in event consumer loop: ~A~%Backtrace: ~A"
                   e (with-output-to-string (s) (uiop:print-backtrace :stream s :count 10 :condition e)))
        (setf *shutdown-requested* t)
        (return))))
  (log-info "EVENT-CONSUMER: Event consumer loop terminated"))

(defun process-channel-event (event source-event-channel-object)
  "Process an event received from an event-channel.
   Invokes handlers registered on the source-event-channel-object, then processes the event further."
  (let ((start-time (get-internal-real-time))
        (event-to-process event))

    (log-debug "EVENT-CONSUMER: Processing event ~S from channel ~S"
               event-to-process (elmtui.core.event-channels:name source-event-channel-object))

    (dolist (handler (elmtui.core.event-channels:handlers source-event-channel-object))
      (handler-case
          (funcall handler event-to-process)
        (error (e)
          (log-error "EVENT-CONSUMER: Error in channel-specific handler for ~S on channel ~S: ~A"
                     event-to-process (elmtui.core.event-channels:name source-event-channel-object) e))))

    (setf (gethash :last-event *event-loop-metrics*) event-to-process)
    (setf (gethash :last-event-time *event-loop-metrics*) (get-universal-time))

    (typecase event-to-process
      (:shutdown-command ;; Special command to stop the application
       (log-info "PROCESS-CHANNEL-EVENT: Received :shutdown-command. Initiating application shutdown via elm-stop-loop.")
       (elm-stop-loop))
      ((cons (eql :app-message) *)
       (let ((actual-message (second event-to-process)))
         (log-debug "EVENT-CONSUMER: Calling *app-message-processor* for: ~S" actual-message)
         (if elmtui.core.globals:*app-message-processor*
             (funcall elmtui.core.globals:*app-message-processor* actual-message elmtui.core.globals:*app-state*)
             (log-error "EVENT-CONSUMER: *app-message-processor* is not set! Cannot process message: ~S" actual-message))))
      ((cons (member :async :async-task :cmd-async :recurring-task) *)
       (log-debug "EVENT-CONSUMER: Handling async command: ~S" event-to-process)
       (elmtui.state.update:handle-async-command event-to-process elmtui.core.globals:*app-state*))
      (t
       (log-warn "EVENT-CONSUMER: Event ~S from channel ~S is not an :app-message, :shutdown-command, or known async command. It might be dropped or require specific handling by channel handlers."
                 event-to-process (elmtui.core.event-channels:name source-event-channel-object))))

    (let* ((processing-time-ms (/ (* (- (get-internal-real-time) start-time) 1000.0)
                                  internal-time-units-per-second)))
      (log-debug "EVENT-CONSUMER: Event processed. Processing time: ~,2Fms." processing-time-ms)
      (vector-push-extend processing-time-ms *event-processing-time-history*)
      (when (> (fill-pointer *event-processing-time-history*) 1000)
        (setf *event-processing-time-history*
              (subseq *event-processing-time-history* (- (length *event-processing-time-history*) 100))))
      (incf (gethash :processed-event-count *event-loop-metrics* 0))
      (incf (gethash :total-processing-time *event-loop-metrics* 0.0) processing-time-ms))))

(defun elm-stop-loop ()
  "Gracefully stop the event loop and consumer thread."
  (unless *shutdown-requested* ; Prevent multiple shutdown attempts
    (log-info "LOOP: elm-stop-loop called. Initiating shutdown sequence.")
    (setf *shutdown-requested* t)

    (log-info "LOOP: Sending :shutdown-loop signal to an active event channel (if any).")
    (when-let* ((ch-obj (first *active-event-channels*))
                (clevelib-ch (elmtui.core.event-channels:channel-of ch-obj)))
      (unless (cleve-elm.channel:channel-closed clevelib-ch)
        (ignore-errors (cleve-elm.channel:-> clevelib-ch :shutdown-loop))))

    (when *consumer-thread*
      (log-info "LOOP: Waiting for consumer thread to join...")
      (ignore-errors (bt:join-thread *consumer-thread*))
      (if (bt:thread-alive-p *consumer-thread*)
          (log-warn "LOOP: Consumer thread did not join in time.")
          (progn
            (log-info "LOOP: Consumer thread joined.")
            (setf *consumer-thread* nil))))

    (log-info "LOOP: Closing event channels.")
    (dolist (ch-obj *active-event-channels*)
      (ignore-errors (cleve-elm.channel:channel-close (elmtui.core.event-channels:channel-of ch-obj))))
    (setf *active-event-channels* nil)

    (when *event-loop* ; If cleve-elm.event-loop is still used
      (log-info "LOOP: Stopping legacy cleve-elm.event-loop instance.")
      (cleve-elm.event-loop:stop-loop *event-loop*)
      (setf *event-loop* nil))
    (log-info "LOOP: Event system shutdown sequence complete."))
  (log-info "LOOP: elm-stop-loop call finished (shutdown already in progress or completed)."))


(defun publish (event &key target-channel-name)
  "Publish an event to a specified or default event channel."
  (let ((channel-obj nil))
    (if target-channel-name
        (setf channel-obj (find target-channel-name *active-event-channels*
                                :key #'elmtui.core.event-channels:name
                                :test #'eq))
        (setf channel-obj (or (find :message *active-event-channels* :key #'elmtui.core.event-channels:name)
                              (find :system *active-event-channels* :key #'elmtui.core.event-channels:name) ; Try system channel
                              (first *active-event-channels*))))

    (if (and channel-obj (elmtui.core.event-channels:channel-of channel-obj)
             (not (cleve-elm.channel:channel-closed (elmtui.core.event-channels:channel-of channel-obj))))
        (let ((event-to-send event))
          (unless (or (eq event-to-send :shutdown-command) ; Don't wrap :shutdown-command
                      (and (listp event-to-send) (eq (first event-to-send) :app-message))
                      (and (listp event-to-send) (member (first event-to-send)
                                                         '(:async :async-task :cmd-async :recurring-task))))
            (setf event-to-send (list :app-message event-to-send)))

          (log-debug "LOOP: Enqueuing to channel ~S: ~S"
                     (elmtui.core.event-channels:name channel-obj) event-to-send)
          (handler-case
              (cleve-elm.channel:-> (elmtui.core.event-channels:channel-of channel-obj) event-to-send)
            (error (e)
              (log-error "LOOP: Failed to enqueue to channel ~S: ~A. Event: ~S"
                         (elmtui.core.event-channels:name channel-obj) e event-to-send))))
        (log-warn "LOOP: Target channel ~S not found, not active, or closed. Dropping event: ~S"
                  (or target-channel-name :default) event))))

;; Status and metrics functions
(defun get-event-loop-status ()
  "Get the current status of the event loop."
  (list :consumer-thread-active (and *consumer-thread* (bt:thread-alive-p *consumer-thread*))
        :active-channels (mapcar #'elmtui.core.event-channels:name *active-event-channels*)
        :shutdown-requested *shutdown-requested*
        :last-event-time (gethash :last-event-time *event-loop-metrics* 0)
        :last-event (gethash :last-event *event-loop-metrics* nil)
        :processed-event-count (gethash :processed-event-count *event-loop-metrics* 0)
        :average-processing-time-ms (if (> (gethash :processed-event-count *event-loop-metrics* 0) 0)
                                        (/ (gethash :total-processing-time *event-loop-metrics* 0.0)
                                           (gethash :processed-event-count *event-loop-metrics* 0))
                                        0.0)))

(defun get-event-queue-length ()
  "Get the sum of approximate queue lengths of all active event channels."
  (if *active-event-channels*
      (loop for channel-obj in *active-event-channels*
            sum (let ((clevelib-channel (elmtui.core.event-channels:channel-of channel-obj)))
                  (if (and clevelib-channel (not (cleve-elm.channel:channel-closed clevelib-channel)))
                      (let ((queue-obj (ignore-errors (cleve-elm.channel:channel-queue clevelib-channel))))
                        (if (and queue-obj (fboundp 'cleve-elm.queue:queue-length))
                            (or (ignore-errors (cleve-elm.queue:queue-length queue-obj)) 0)
                            0)) ; Cannot determine length for this channel's queue
                      0))) ; Channel not available or closed
      0)) ; No active channels

(defvar *event-loop-instrumentation-hooks* nil
  "List of instrumentation hook functions for event loop metrics/tracing.")

(defun instrument-event-loop (event)
  "Instrumentation hook for debugging/profiling."
  (dolist (hook *event-loop-instrumentation-hooks*)
    (funcall hook event)))
