;;;===============================================================
;;; File: src/core/loop.lisp
;;; Event Loop & Dispatcher (Channel-Based System)
;;;===============================================================

(uiop:define-package :elmtui.core.loop
  (:use :cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-warn #:log-info)
  (:import-from :elmtui.core.globals
    #:*event-loop* #:*app-state* #:*app-message-processor* #:*app-sender*)
  (:import-from :elmtui.style-lib.api
    #:style-set #:styles-list)
  (:import-from :elmtui.core.conditions
    #:event-loop-dispatch-error #:async-task-error)
  (:import-from :cleve-elm.event-loop
    #:event-loop #:make-event-loop #:run-loop #:stop-loop #:event-loop-active-p)
  (:import-from :cleve-elm.channel
    #:make-channel #:channel-close #:channel-closed #:-> #:<- #:channel-queue)
  (:import-from :cleve-elm.queue
    #:queue-length)
  (:import-from :elmtui.core.event-channels
    #:event-channel #:handlers #:name #:channel-of #:wait-for-event
    #:standard-event-channels)
  (:import-from :elmtui.state.update ; Assuming this is the correct package for handle-async-command
    #:handle-async-command)
  (:export :start-loop :elm-stop-loop :publish :*event-loop* #:as-plist
    :get-event-loop-status :get-event-queue-length :instrument-event-loop
    ;; Make *consumer-thread* accessible for joining in driver.lisp
    :*consumer-thread*))

(in-package :elmtui.core.loop)

;; Event processing variables
(defvar *consumer-thread* nil
  "Thread for consuming events from *active-event-channels*")

(defvar *shutdown-requested* nil
  "Flag to signal the consumer thread to shutdown")

(defvar *event-loop-metrics* (make-hash-table :test 'eq)
  "Metrics for event processing")

(defvar *event-processing-time-history*
  (make-array 100 :initial-element 0 :fill-pointer 0 :adjustable t)
  "History of event processing times in milliseconds (keeps last 100 entries).")

;; *active-event-channels* will now be a flat list of event-channel objects
(defvar *active-event-channels* nil
  "Flat list of active event-channel objects.")

(defun start-loop (&key (fps 60) (wait t))
  "Initialize and start the main event loop using the channel-based system."
  (declare (ignore fps wait)) ; These arguments seem to be unused currently.
  (log-info "START-LOOP: Called. *active-event-channels* is currently ~:[NIL~;non-NIL~]."
    *active-event-channels*)
  (unless *active-event-channels*
    (log-info "START-LOOP: *active-event-channels* is NIL, initializing.")
    ;; standard-event-channels returns an alist ((key . channel-obj) ...).
    ;; We want *active-event-channels* to be a flat list of channel objects.
    (setf *active-event-channels*
      (mapcar #'cdr (elmtui.core.event-channels:standard-event-channels)))
    (log-info "START-LOOP: Initialized *active-event-channels*. Channel names: ~S"
      (mapcar #'elmtui.core.event-channels:name *active-event-channels*)))
  (log-info "START-LOOP: *active-event-channels* is now active. Channel-based event system activated.")

  ;; Set the global *app-sender* to this system's publish function
  (setf elmtui.core.globals:*app-sender* #'publish)
  (log-info "LOOP: *app-sender* set to #'elmtui.core.loop:publish (channel system)")
  (when (or (and (null *consumer-thread*) (not *shutdown-requested*))
          (not (sb-thread:thread-alive-p *consumer-thread*)))
    (setf *shutdown-requested* nil)
    (setf *consumer-thread*
      (bt:make-thread #'event-consumer-loop :name "elmtui-event-consumer"))
    (log-info "LOOP: Started event consumer thread for channel system."))
  t)


;; (defun force-restart-loop )

(defun event-consumer-loop ()
  "Consumer loop for processing events from *active-event-channels*."
  (log-info "EVENT-CONSUMER: Starting loop. Active channels count: ~D."
    (length *active-event-channels*))
  (when (and *active-event-channels* (> (length *active-event-channels*) 0))
    (log-info "EVENT-CONSUMER: First channel object name for consumer: ~A"
      (elmtui.core.event-channels:name (first *active-event-channels*))))
  (loop
    (log-debug "EVENT-CONSUMER: Top of main loop. *shutdown-requested* = ~A" *shutdown-requested*)
    (when *shutdown-requested*
      (log-info "EVENT-CONSUMER: Shutdown requested, exiting loop.")
      (return))
    (log-debug "EVENT-CONSUMER: *shutdown-requested* was false, continuing loop.")
    (handler-case
      (if (null *active-event-channels*)
        (progn
          (log-warn "EVENT-CONSUMER: No active event channels. Sleeping briefly.")
          (sleep 0.1)
          nil)
        (multiple-value-bind (event originating-event-channel-object)
          (elmtui.core.event-channels:wait-for-event *active-event-channels* :timeout 0.0)
          (if event
            (progn
              (log-debug "EVENT-CONSUMER: Dequeued event ~A from channel ~S."
                event
                (if originating-event-channel-object
                  (elmtui.core.event-channels:name originating-event-channel-object)
                  "unknown (event but no channel object)"))
              (cond
                ((eq event :shutdown-loop)
                  (log-info "EVENT-CONSUMER: Received :shutdown-loop signal on channel ~A."
                    (if originating-event-channel-object
                      (elmtui.core.event-channels:name originating-event-channel-object)
                      "unknown"))
                  (setf *shutdown-requested* t))
                ((not (null originating-event-channel-object))
                  (process-channel-event event originating-event-channel-object))
                (t ; Should not happen if wait-for-event returns a valid channel object with an event
                  (log-warn "EVENT-CONSUMER: Received event ~S but no originating channel object." event))))
            (log-debug "EVENT-CONSUMER: wait-for-event timed out or returned nil event."))))
      (error (err)
        (let ((bt (with-output-to-string (s)
                    (uiop:print-backtrace :stream s :count 50 :condition err))))
          (log-error "EVENT-CONSUMER: Error in event consumer loop: ~A~%Backtrace:~%~A"
            err bt)
          (format *error-output* "~%EVENT-CONSUMER: Error in background thread: ~A~%Backtrace:~%~A~%" err bt)
          (finish-output *error-output*)
          ;; For development, break. For production, this might be removed or made conditional.
          (break "EVENT-CONSUMER: Unhandled error in background thread. See log and *error-output* for details.")
          )
        ;; (setf *shutdown-requested* t)
                                        ; Ensure loop terminates on error
        (return))))
  (log-info "EVENT-CONSUMER: Event consumer loop terminated"))

(defgeneric as-plist (style)
  (:method ((styles list))
    "Convert a style object to a property list. This method should be overridden by specific style objects."
    styles)
  (:documentation "Convert a style object to a property list."))

(defun process-channel-event (event source-event-channel-object)
  "Process an event received from an event-channel. Invokes handlers registered on the
source-event-channel-object, then processes the event further."
  (log-info "PROCESS-CHANNEL-EVENT: Called with event ~S from channel ~S"
    event (elmtui.core.event-channels:name source-event-channel-object))
  (let ((start-time (get-internal-real-time))
         (event-to-process event)
         (channel-name (elmtui.core.event-channels:name source-event-channel-object)))
    (log-info "EVENT-CONSUMER: Processing event ~S from channel ~S"
      event-to-process channel-name)

    (dolist (handler (elmtui.core.event-channels:handlers source-event-channel-object))
      (handler-case
        ;; Pass potentially modified event first, then original event.
        ;; Consider if handlers truly need both or just the (potentially modified) event.
        (funcall handler
          (if (and (consp event-to-process)
                (find :style event-to-process)
                (let ((style-val (getf event-to-process :style)))
                  (and style-val (not (listp style-val)))))
            (let* ((style-val (getf event-to-process :style))
                    (style-plist (as-plist style-val))
                    (copy (copy-list event-to-process)))
              (setf (getf copy :style) style-plist)
              copy)
            event-to-process)
          event-to-process)
        (error (e)
          (log-error "EVENT-CONSUMER: Error in channel-specific handler for ~S on channel ~S: ~A"
            event-to-process channel-name e))))

    (setf (gethash :last-event *event-loop-metrics*) event-to-process)
    (setf (gethash :last-event-time *event-loop-metrics*) (get-universal-time))

    (etypecase event
      ((eql :shutdown-command)
        (log-info "Received :shutdown-command. Stopping application loop.")
        (elm-stop-loop))
      (cons
        (destructuring-bind (tag &rest payload) event
          (case tag
            (:app-message
              (let ((msg (first payload)))
                (log-info "PROCESS-CHANNEL-EVENT: Dispatching :app-message ~S to *app-message-processor* (~A)"
                  msg elmtui.core.globals:*app-message-processor*)
                (if elmtui.core.globals:*app-message-processor*
                  (funcall elmtui.core.globals:*app-message-processor*
                    msg)
                  (log-error "PROCESS-CHANNEL-EVENT: *app-message-processor* is not set—cannot process: ~S"
                    msg))))
            ((:async :async-task :cmd-async :recurring-task)
              (log-debug "Handling async command ~S" event)
              (handle-async-command event elmtui.core.globals:*app-state*))
            (otherwise
              (log-warn "Unknown event tag ~S on channel ~S" tag channel-name))))))

    (let* ((processing-time-ms (/ (* (- (get-internal-real-time) start-time) 1000.0)
                                 internal-time-units-per-second)))
      (log-debug "EVENT-CONSUMER: Event processed. Processing time: ~,2Fms." processing-time-ms)
      (vector-push-extend processing-time-ms *event-processing-time-history*)
      ;; Keep only the last 100 entries
      (when (> (fill-pointer *event-processing-time-history*) 100)
        (setf *event-processing-time-history*
          (make-array 100 :initial-contents (subseq *event-processing-time-history*
                                              (- (fill-pointer *event-processing-time-history*) 100))
            :fill-pointer 100 :adjustable t)))
      (incf (gethash :processed-event-count *event-loop-metrics* 0))
      (incf (gethash :total-processing-time *event-loop-metrics* 0.0) processing-time-ms))))

(defun elm-stop-loop ()
  "Gracefully stop the event loop and consumer thread."
  (log-info "ELM-STOP-LOOP: Function called. Current *shutdown-requested*: ~A" *shutdown-requested*)
  (unless *shutdown-requested*
    (log-info "LOOP: elm-stop-loop called. Initiating shutdown sequence.")
    (setf *shutdown-requested* t)
    (log-info "LOOP: Sending :shutdown-loop signal to an active event channel (if any).")
    (when *active-event-channels*
      (let* ((ch-obj (first *active-event-channels*)))
        (when ch-obj
          (let ((clevelib-ch (elmtui.core.event-channels:channel-of ch-obj)))
            (unless (cleve-elm.channel:channel-closed clevelib-ch)
              (ignore-errors (cleve-elm.channel:-> clevelib-ch :shutdown-loop))))))

      (log-info "LOOP: Closing event channels.")
      (dolist (ch-obj *active-event-channels*)
        (ignore-errors (cleve-elm.channel:channel-close (elmtui.core.event-channels:channel-of ch-obj))))
      (setf *active-event-channels* nil)
      (log-info "LOOP: *active-event-channels* set to NIL.")

      (when *event-loop* ; Legacy event loop
        (log-info "LOOP: Stopping legacy cleve-elm.event-loop instance.")
        (cleve-elm.event-loop:stop-loop *event-loop*)
        (setf *event-loop* nil))
      (log-info "LOOP: Event system shutdown sequence complete.")))
  (log-info "LOOP: elm-stop-loop call finished (shutdown already in progress or completed)."))

(defun publish (event &key target-channel-name)
  "Publish an event to a specified or default event channel."
  (log-info "PUBLISH: Called for event ~S. Target: ~A." event target-channel-name)

  (let ((channel-obj nil)
         (effective-target-name
           (if (and target-channel-name (symbolp target-channel-name) (not (keywordp target-channel-name)))
             (intern (symbol-name target-channel-name) :keyword)
             target-channel-name)))
    (if effective-target-name
      (setf channel-obj
        (find effective-target-name *active-event-channels*
          :key #'elmtui.core.event-channels:name
          :test #'eq))
      ;; If no target-channel-name, fallback to :message, then :system-channel, then first available
      (setf channel-obj (or (find :message *active-event-channels* :key #'elmtui.core.event-channels:name :test #'eql)
                          (find :system-channel *active-event-channels* :key #'elmtui.core.event-channels:name :test #'eql)
                          (first *active-event-channels*))))

    (log-info "PUBLISH: Effective target channel name: ~S ~A ~A Closed? ~A" effective-target-name channel-obj (elmtui.core.event-channels:channel-of channel-obj)
      (cleve-elm.channel:channel-closed (elmtui.core.event-channels:channel-of channel-obj)))
    (if channel-obj
      (log-info "PUBLISH: Found target channel-obj: ~A. Original target: ~S, Effective target: ~S"
        (elmtui.core.event-channels:name channel-obj)
        target-channel-name
        effective-target-name)
      (log-warn "PUBLISH: Could not find channel-obj. Original target: ~S, Effective target: ~S."
        target-channel-name effective-target-name))

    (if (and channel-obj
          (elmtui.core.event-channels:channel-of channel-obj)
          (not (cleve-elm.channel:channel-closed (elmtui.core.event-channels:channel-of channel-obj))))
      (let ((event-to-send event)
             (ch-name (elmtui.core.event-channels:name channel-obj)))
        ;; Wrap event as :app-message if it's not a known system/command type
        (log-info "PUBLISH: Preparing to enqueue event ~S to channel ~S" event-to-send ch-name)
        (unless (or (eq event-to-send :shutdown-command)
                  (and (listp event-to-send) (eq (first event-to-send) :app-message))
                  (and (listp event-to-send) (member (first event-to-send)
                                               '(:async :async-task :cmd-async :recurring-task))))
          (setf event-to-send (list :app-message event-to-send)))

        (log-info "PUBLISH: Enqueuing to channel ~S: ~S" ch-name event-to-send)
        (log-info "Channel-States: ~S"
          (get-event-loop-status))
        (handler-case
          (progn (cleve-elm.channel:-> (elmtui.core.event-channels:channel-of channel-obj) event-to-send)
            (log-info "PUBLISH: Successfully enqueued event ~S to channel ~S"
              event-to-send ch-name))
          (error (e)
            (log-error "PUBLISH: Failed to enqueue to channel ~S: ~A. Event: ~S"
              ch-name e event-to-send))))
      (log-warn "PUBLISH: Target channel (Original: ~S, Effective: ~S) not found, not active, or closed. Dropping event: ~S"
        target-channel-name
        effective-target-name
        event))))
;; (setf *SHUTDOWN-REQUESTED* nil)
                                        ; Reset shutdown flag on publish
;; Status and metrics functions
(defun get-event-loop-status ()
  "Get the current status of the event loop."
  (list :consumer-thread-active
    (and *consumer-thread*
      (bt:thread-alive-p *consumer-thread*))
    :active-channels
    (if *active-event-channels*
      (mapcar #'elmtui.core.event-channels:name *active-event-channels*)
      nil)
    :channels
    (if *active-event-channels*
      (mapcar
        (lambda (x)
          ;; get enqueued, dequeued, closed, name, and queue length
          (let ((clevelib-channel (elmtui.core.event-channels:channel-of x)))
            (list :name (elmtui.core.event-channels:name x)
              :enqueued (cleve-elm.channel:channel-length clevelib-channel)
              :closed (cleve-elm.channel:channel-closed clevelib-channel)
              :queue-length
              (if (fboundp 'cleve-elm.queue:queue-length)
                (ignore-errors
                  (cleve-elm.queue:queue-length
                    (cleve-elm.channel:channel-queue clevelib-channel)))
                0) ; If queue-length function is not available, return 0
              )))
        *active-event-channels*)
      nil)
    :shutdown-requested *shutdown-requested*
    :last-event-time (gethash :last-event-time *event-loop-metrics* 0)
    :last-event (gethash :last-event *event-loop-metrics* nil)
    :processed-event-count (gethash :processed-event-count *event-loop-metrics* 0)
    :average-processing-time-ms
    (if (> (gethash :processed-event-count *event-loop-metrics* 0) 0)
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
                  0))
              0)))
    0))

(defvar *event-loop-instrumentation-hooks* nil
  "List of instrumentation hook functions for event loop metrics/tracing.")

(defun instrument-event-loop (event)
  "Instrumentation hook for debugging/profiling."
  (dolist (hook *event-loop-instrumentation-hooks*)
    (funcall hook event)))

(defmethod as-plist ((style style-set))
  "Convert a style-set to a property list."
  (styles-list style))
