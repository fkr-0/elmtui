;;;===============================================================
;;; File: src/core/loop.lisp
;;; Event Loop & Dispatcher (Channel-Based System)
;;;===============================================================

(uiop:define-package :elmtui.core.loop
  (:use :cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-warn #:log-info)
  (:import-from :elmtui.core.globals
                #:*event-loop* #:*app-state* #:*app-message-processor* #:*app-sender*)
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
  (:import-from :elmtui.state.update
                #:handle-async-command)
  (:export :start-loop :elm-stop-loop :publish :*event-loop*
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
  "History of event processing times in milliseconds")

;; *active-event-channels* will now be a flat list of event-channel objects
(defvar *active-event-channels* nil
  "Flat list of active event-channel objects.")

(defun start-loop (&key (fps 60) (wait t))
  "Initialize and start the main event loop using the channel-based system."
  (declare (ignore fps wait))
  (log-info "START-LOOP: Called. *active-event-channels* is currently ~:[NIL~;non-NIL (ID: #x~X)~]."
            *active-event-channels* (if *active-event-channels* (sb-kernel:get-lisp-obj-address *active-event-channels*) 0))
  (unless *active-event-channels*
    (log-info "START-LOOP: *active-event-channels* is NIL, initializing.")
    ;; standard-event-channels returns an alist ((key . channel-obj) ...).
    ;; We want *active-event-channels* to be a flat list of channel objects.
    (setf *active-event-channels*
          (mapcar #'cdr (elmtui.core.event-channels:standard-event-channels)))
    (log-info "START-LOOP: Initialized *active-event-channels* (ID: #x~X). Channel names: ~S"
              (sb-kernel:get-lisp-obj-address *active-event-channels*)
              (mapcar #'elmtui.core.event-channels:name *active-event-channels*))
    (when *active-event-channels*
      (log-info "START-LOOP: First channel object ID in new list: #x~X"
                (sb-kernel:get-lisp-obj-address (first *active-event-channels*)))))
  (log-info "START-LOOP: *active-event-channels* is now (ID: #x~X). Channel-based event system activated."
            (if *active-event-channels* (sb-kernel:get-lisp-obj-address *active-event-channels*) 0))

  ;; Set the global *app-sender* to this system's publish function
  (setf elmtui.core.globals:*app-sender* #'publish)
  (log-info "LOOP: *app-sender* set to #'elmtui.core.loop:publish (channel system)")
  (when (and (null *consumer-thread*) (not *shutdown-requested*))
    (setf *shutdown-requested* nil)
    (setf *consumer-thread*
          (bt:make-thread #'event-consumer-loop :name "elmtui-event-consumer"))
    (log-info "LOOP: Started event consumer thread for channel system."))
  t)

(defun event-consumer-loop ()
  "Consumer loop for processing events from *active-event-channels*."
  (log-info "EVENT-CONSUMER: Starting loop. *active-event-channels* ID: #x~X, Length: ~D."
            (if *active-event-channels* (sb-kernel:get-lisp-obj-address *active-event-channels*) 0)
            (length *active-event-channels*))
  (when (and *active-event-channels* (> (length *active-event-channels*) 0))
    (log-info "EVENT-CONSUMER: First channel object in list for consumer: #x~X (Name: ~A)"
              (sb-kernel:get-lisp-obj-address (first *active-event-channels*))
              (elmtui.core.event-channels:name (first *active-event-channels*))))
  (loop
    (log-debug "EVENT-CONSUMER: Top of main loop. *shutdown-requested* = ~A" *shutdown-requested*)
    (when *shutdown-requested*
      (log-info "EVENT-CONSUMER: Shutdown requested IS TRUE, exiting loop NOW.")
      (return))
    (log-debug "EVENT-CONSUMER: *shutdown-requested* was false, continuing loop.")
    (handler-case
        (if
         (null *active-event-channels*)
         (progn
           ;; (log-warn "EVENT-CONSUMER: No active event channels. Sleeping briefly.")
           (sleep 0.1)
           nil)
         (progn
           ;; (log-debug "EVENT-CONSUMER: Waiting for event on *active-event-channels* (ID: #x~X). Channels: ~S. Timeout: 1.0s"
           ;;            (if *active-event-channels* (sb-kernel:get-lisp-obj-address *active-event-channels*) 0)
           ;;            (mapcar #'elmtui.core.event-channels:name *active-event-channels*))
           (multiple-value-bind (event originating-event-channel-object)
               (elmtui.core.event-channels:wait-for-event *active-event-channels* :timeout 1.0)
             ;; (log-debug "EVENT-CONSUMER: wait-for-event returned. Event: ~A. Originating channel object: ~A (Name: ~A, ID: #x~X)" ; Changed ~S to ~A for event and object
             ;;            event
             ;;            originating-event-channel-object
             ;;            (if originating-event-channel-object (elmtui.core.event-channels:name originating-event-channel-object) "NIL")
             ;;            (if originating-event-channel-object (sb-kernel:get-lisp-obj-address originating-event-channel-object) 0))
             ;; (log-debug "EVENT-CONSUMER: Immediately before (if event) check. Event is: ~A. Is (not (null event))? ~A" ; Changed ~S to ~A for event
             ;;            event (not (null event)))
             (if event
                 (progn
                   (log-debug "EVENT-CONSUMER: Dequeued event ~A from channel ~S." ; Changed ~S to ~A for event
                              event
                              (if originating-event-channel-object
                                  (elmtui.core.event-channels:name originating-event-channel-object)
                                  "unknown (event but no channel object)"))
                   ;; originating-event-channel-object is already the wrapper object we need.
                   (cond
                     ((eq event :shutdown-loop)
                      (log-info "EVENT-CONSUMER: Received :shutdown-loop signal on channel ~A."
                                (if originating-event-channel-object
                                    (elmtui.core.event-channels:name originating-event-channel-object)
                                    "unknown"))
                      (setf *shutdown-requested* t)
                      ;; Removed (return) here; exit is handled by the check at the top of the loop.
                      )
                     (originating-event-channel-object
                      (process-channel-event event originating-event-channel-object)) ; Pass the wrapper object
                     (t ; Should not happen if wait-for-event returns a valid channel object with an event
                      (log-warn "EVENT-CONSUMER: Received event ~S but no originating channel object." event))))
                 (log-debug "EVENT-CONSUMER: wait-for-event timed out or returned nil event.")))))
      ;; (multiple-value-bind (event source-clevelib-channel)
      ;;     ;; *active-event-channels* is now a list of event-channel objects.
      ;;     ;; channel-of expects an event-channel object.
      ;;     (let ((clevelib-channels
      ;;             (mapcar #'elmtui.core.event-channels:channel-of *active-event-channels*)))
      ;;       (elmtui.core.event-channels:wait-for-event clevelib-channels :timeout 1.0))
      ;;   (when event
      ;;     ;; Find the wrapper event-channel object whose underlying clevelib-channel matches.
      ;;     (let ((wrapper-channel-object
      ;;             (find source-clevelib-channel *active-event-channels*
      ;;                   :key #'elmtui.core.event-channels:channel-of :test #'eq)))
      ;;       (cond
      ;;         ((eq event :shutdown-loop)
      ;;          (log-info "EVENT-CONSUMER: Received :shutdown-loop signal on channel ~A."
      ;;                    (if wrapper-channel-object
      ;;                        (elmtui.core.event-channels:name wrapper-channel-object)
      ;;                        "unknown"))
      ;;          (setf *shutdown-requested* t)
      ;;          (return))
      ;;         (wrapper-channel-object
      ;;          (process-channel-event event wrapper-channel-object))
      ;;         (t
      ;;          (log-warn "EVENT-CONSUMER: Received event ~S from an unknown clevelib channel ~S."
      ;;                    event source-clevelib-channel))))))
      (error (err) ; Changed 'e' to 'err'
        (log-error "EVENT-CONSUMER: Error in event consumer loop: ~A~%Backtrace: ~A"
                   err (with-output-to-string (s)
                         (uiop:print-backtrace :stream s :count 10 :condition err)))
        (setf *shutdown-requested* t) ; Ensure loop terminates on error
        (return))))
  (log-info "EVENT-CONSUMER: Event consumer loop terminated"))

(defun process-channel-event (event source-event-channel-object)
  "Process an event received from an event-channel. Invokes handlers registered on the
source-event-channel-object, then processes the event further."
  (let ((start-time (get-internal-real-time))
        (event-to-process event)
        (channel-name (elmtui.core.event-channels:name source-event-channel-object)))
    (log-debug "EVENT-CONSUMER: Processing event ~S from channel ~S"
               event-to-process channel-name)


    (dolist (handler (elmtui.core.event-channels:handlers source-event-channel-object))
      (handler-case
          (funcall handler event-to-process)
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
              ;; MODIFIED LOGGING:
              (log-debug "PROCESS-CHANNEL-EVENT: Dispatching :app-message ~S to *app-message-processor* (~A)"
                         msg elmtui.core.globals:*app-message-processor*)
              (if elmtui.core.globals:*app-message-processor*
                  (funcall elmtui.core.globals:*app-message-processor*
                           msg
                           elmtui.core.globals:*app-state*)
                  (log-error "PROCESS-CHANNEL-EVENT: *app-message-processor* is not set—cannot process: ~S" ; MODIFIED for consistency
                             msg))))
           ((:async :async-task :cmd-async :recurring-task)
            (log-debug "Handling async command ~S" event)
            (elmtui.state.update:handle-async-command event
                                                      elmtui.core.globals:*app-state*))
           (otherwise
            (log-warn "Unknown event tag ~S on channel ~S" tag channel-name))))))

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
  (log-info "ELM-STOP-LOOP: Function called. Current *shutdown-requested*: ~A" *shutdown-requested*)
  (unless *shutdown-requested*
    (log-info "LOOP: elm-stop-loop called. Initiating shutdown sequence.")
    (setf *shutdown-requested* t)
    (log-info "LOOP: Sending :shutdown-loop signal to an active event channel (if any).")
    (when *active-event-channels*
      ;; *active-event-channels* is a list of channel objects
      (let* ((ch-obj (first *active-event-channels*))) ; Get first channel object
        (when ch-obj
          (let ((clevelib-ch (elmtui.core.event-channels:channel-of ch-obj)))
            (unless (cleve-elm.channel:channel-closed clevelib-ch)
              (ignore-errors (cleve-elm.channel:-> clevelib-ch :shutdown-loop))))))
    ;; The responsibility of joining *consumer-thread* lies with the code that spawned it (e.g., driver.lisp).
    ;; This function's role is to signal shutdown and clean up loop-specific resources like channels.
    ;; The *consumer-thread* variable itself will be nulled by the spawning thread after it confirms termination.

    (log-info "LOOP: Closing event channels. Current *active-event-channels* ID: #x~X"
              (if *active-event-channels* (sb-kernel:get-lisp-obj-address *active-event-channels*) 0))
    (dolist (ch-obj *active-event-channels*) ; ch-obj is a channel object
        (ignore-errors (cleve-elm.channel:channel-close (elmtui.core.event-channels:channel-of ch-obj))))
      (setf *active-event-channels* nil)
      (log-info "LOOP: *active-event-channels* set to NIL.")

      (when *event-loop*
        (log-info "LOOP: Stopping legacy cleve-elm.event-loop instance.")
        (cleve-elm.event-loop:stop-loop *event-loop*)
        (setf *event-loop* nil))
      (log-info "LOOP: Event system shutdown sequence complete."))
    (log-info "LOOP: elm-stop-loop call finished (shutdown already in progress or completed).")))

(defun publish (event \&key target-channel-name)
  "Publish an event to a specified or default event channel."
  (log-debug "PUBLISH: Called for event ~S. Target: ~A. Current *active-event-channels* ID: #x~X"
             event target-channel-name (if *active-event-channels* (sb-kernel:get-lisp-obj-address *active-event-channels*) 0))
  (when (and *active-event-channels* (> (length *active-event-channels*) 0))
    (log-debug "PUBLISH: First channel object in *active-event-channels* for publish: #x~X (Name: ~A)"
               (sb-kernel:get-lisp-obj-address (first *active-event-channels*))
               (elmtui.core.event-channels:name (first *active-event-channels*))))

  (let ((channel-obj nil) ;; *active-event-channels* is a flat list of channel objects.
        (effective-target-name
          (if (and target-channel-name (symbolp target-channel-name) (not (keywordp target-channel-name)))
              (intern (symbol-name target-channel-name) :keyword)
              target-channel-name)))
;; Find expects the item itself if :key is not used, or the result of :key.
(when effective-target-name
(log-debug "PUBLISH: Pre-find check. Effective target: ~S. *active-event-channels* (len ~D): ~S"
effective-target-name
(if *active-event-channels* (length *active-event-channels*) 0)
(if *active-event-channels*
(mapcar (lambda (ch) (list (elmtui.core.event-channels:name ch)
                         (type-of ch)
                         (sb-kernel:get-lisp-obj-address ch)))
      *active-event-channels*)
"NIL_LIST")))
(if effective-target-name
(setf channel-obj
(find effective-target-name *active-event-channels*
:key #'elmtui.core.event-channels:name
:test #'eq)) ; EQ is fine for keywords
;; If no target-channel-name, fallback to :message, then :system-channel, then first available
(setf channel-obj (or (find :message *active-event-channels* :key #'elmtui.core.event-channels:name :test #'eq)
         (find :system-channel *active-event-channels* :key #'elmtui.core.event-channels:name :test #'eq) ; Corrected here
         (first *active-event-channels*))))

    (if channel-obj
        (log-debug "PUBLISH: Found target channel-obj: ~A (ID: #x~X), underlying clevelib channel ID: #x~X. Original target: ~S, Effective target: ~S"
                   (elmtui.core.event-channels:name channel-obj)
                   (sb-kernel:get-lisp-obj-address channel-obj)
                   (sb-kernel:get-lisp-obj-address (elmtui.core.event-channels:channel-of channel-obj))
                   target-channel-name
                   effective-target-name)
        (log-warn "PUBLISH: Could not find channel-obj. Original target: ~S, Effective target: ~S."
                  target-channel-name effective-target-name))

    (if (and channel-obj
             (elmtui.core.event-channels:channel-of channel-obj) ; Ensure it's a valid channel obj
             (not (cleve-elm.channel:channel-closed (elmtui.core.event-channels:channel-of channel-obj))))
        (let ((event-to-send event)
              (ch-name (elmtui.core.event-channels:name channel-obj)))
          (unless (or (eq event-to-send :shutdown-command)
                      (and (listp event-to-send) (eq (first event-to-send) :app-message))
                      (and (listp event-to-send) (member (first event-to-send)
                                                         '(:async :async-task :cmd-async :recurring-task))))
            (setf event-to-send (list :app-message event-to-send)))

          (log-debug "PUBLISH: Enqueuing to channel ~S (clevelib ID: #x~X): ~S"
                     ch-name
                     (sb-kernel:get-lisp-obj-address (elmtui.core.event-channels:channel-of channel-obj))
                     event-to-send)
          (handler-case
              (cleve-elm.channel:-> (elmtui.core.event-channels:channel-of channel-obj) event-to-send)
            (error (e)
              (log-error "PUBLISH: Failed to enqueue to channel ~S: ~A. Event: ~S"
                         ch-name e event-to-send))))
       (log-warn "PUBLISH: Target channel (Original: ~S, Effective: ~S) not found, not active, or closed. Dropping event: ~S"
                 target-channel-name
                 (if (and target-channel-name (symbolp target-channel-name) (not (keywordp target-channel-name)))
                     (intern (symbol-name target-channel-name) :keyword)
                     target-channel-name)
                 event))))

;; Status and metrics functions
(defun get-event-loop-status ()
  "Get the current status of the event loop."
  (list :consumer-thread-active
        (and *consumer-thread*
             (bt:thread-alive-p *consumer-thread*)) :active-channels
        (if *active-event-channels*
            (mapcar #'elmtui.core.event-channels:name *active-event-channels*) nil)
        :shutdown-requested *shutdown-requested*
        :last-event-time
        (gethash :last-event-time *event-loop-metrics* 0) :last-event
        (gethash :last-event *event-loop-metrics* nil) :processed-event-count
        (gethash :processed-event-count *event-loop-metrics* 0) :average-processing-time-ms
        (if (>
             (gethash :processed-event-count *event-loop-metrics* 0)
             0)
            (/ (gethash :total-processing-time *event-loop-metrics* 0.0)
               (gethash :processed-event-count *event-loop-metrics* 0))
            0.0)))

(defun get-event-queue-length ()
  "Get the sum of approximate queue lengths of all active event channels."
  (if *active-event-channels*
      (loop for channel-obj in
            *active-event-channels* do
                                        ; channel-obj is an event-channel object sum
              (let ((clevelib-channel (elmtui.core.event-channels:channel-of channel-obj)))
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
