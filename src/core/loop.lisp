;;;===============================================================
;;; File: src/core/loop.lisp
;;; Event Loop & Dispatcher (using clevelib)
(uiop:define-package :elmtui.core.loop
  (:use :cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-warn #:log-info)
  (:import-from :elmtui.core.globals
   :*event-loop* :*subscribers* :*main-event-channel* :*app-state*) ; Added *app-state* for clarity
  (:import-from :elmtui.core.conditions
   :subscriber-handler-error :event-loop-dispatch-error :async-task-error)
  (:import-from :cleve-elm.message
   :message-type)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:ui-event #:ui-event-type) ; Added ui-event-type
  (:import-from :cleve-elm.event-loop ; For legacy event loop structure
   :event-loop :make-event-loop :run-loop :stop-loop :event-loop-active-p)
  ;; Imports for the new channel system
  (:import-from :cleve-elm.channel
                #:make-channel #:channel-close #:channel-closed ; Changed from channel-closed-p
                #:-> #:<-) ; Removed channel-closed-error as it's not defined
  (:import-from :elmtui.platform.driver #:app-update-handler)
  (:import-from :elmtui.state.update #:handle-async-command)
  (:export :start-loop
   :enqueue-event
           :dispatch-event 
   :subscribe-with-priority 
           :elm-stop-loop :unsubscribe 
           :subscribe :publish :publish-sync-internal 
   :*lifecycle-hooks*
           :*event-loop* :*subscribers*
           :*main-event-channel*
   :get-event-loop-status :get-event-queue-length
   :instrument-event-loop :elm-event-loop-active-p))
(in-package :elmtui.core.loop)

;; Event processing variables
(defvar *consumer-thread* nil "Thread for consuming events from *main-event-channel*")
(defvar *shutdown-requested* nil "Flag to signal the consumer thread to shutdown")
(defvar *event-loop-metrics* (make-hash-table :test 'eq) "Metrics for event processing")
(defvar *event-processing-time-history* (make-array 100 :initial-element 0 :fill-pointer 0 :adjustable t)
  "History of event processing times in milliseconds")

(defun start-loop (&key (fps 60) (wait t))
  "Initialize and start the main event loop with channel-based event processing.
   This creates a dedicated consumer thread that processes events from *main-event-channel*."
  (declare (ignore fps)) ; fps not used with channel model directly here
  ;; Create the main event channel if not already exists
  (unless *main-event-channel*
    (setf *main-event-channel* (cleve-elm.channel:make-channel))
    (log-info "LOOP: Created main event channel using cleve-elm.channel:make-channel"))

  ;; Initialize the legacy event loop for backward compatibility if needed by other parts
  (unless *event-loop*
    (setf *event-loop* (cleve-elm.event-loop:make-event-loop))
    (log-info "LOOP: Legacy event-loop structure initialized."))

  ;; Set the global app sender to this package's publish function
  ;; Note: publish now uses enqueue-event which sends to *main-event-channel*
  (setf elmtui.core.globals:*app-sender* #'publish)
  (log-info "LOOP: *app-sender* set to #'elmtui.core.loop:publish")

  ;; Start the consumer thread if not already running
  (when (and (null *consumer-thread*) (not *shutdown-requested*))
    (setf *shutdown-requested* nil)
    (setf *consumer-thread*
          (bt:make-thread #'event-consumer-loop :name "elmtui-event-consumer"))
    (log-info "LOOP: Started event consumer thread for *main-event-channel*"))

  ;; Run the traditional event loop (for backward compatibility if it has its own sources)
  ;; This part might need re-evaluation depending on how legacy parts interact.
  ;; If all events are meant to go via *main-event-channel*, this might not be needed.
  (if wait
      (when (and *event-loop* (not (cleve-elm.event-loop:event-loop-active-p *event-loop*)))
        (log-info "LOOP: Starting legacy run-loop (blocking).")
        (cleve-elm.event-loop:run-loop *event-loop*)) ; Blocking call
      (progn
        (when (and *event-loop* (not (cleve-elm.event-loop:event-loop-active-p *event-loop*)))
          (log-info "LOOP: Starting legacy run-loop (non-blocking).")
          (bt:make-thread (lambda () (cleve-elm.event-loop:run-loop *event-loop*))
                          :name "elmtui-legacy-event-loop"))))
  t)

(defun event-consumer-loop ()
  "Main consumer loop for processing events from *main-event-channel*.
   This is the core of the channel-based event processing system."
  (log-info "EVENT-CONSUMER: Starting event consumer loop for *main-event-channel*")
  (loop
    (when *shutdown-requested*
      (log-info "EVENT-CONSUMER: Shutdown requested, exiting loop.")
      (return))
    (handler-case
        (let ((event (cleve-elm.channel:<- *main-event-channel*))) ; Blocking receive
          (when event 
            (cond
              ((eq event :shutdown-loop)
               (log-info "EVENT-CONSUMER: Received :shutdown-loop signal.")
               (setf *shutdown-requested* t)
               (return))
              (t
               (process-event event)))))
      ;; Removed specific cleve-elm.channel:channel-closed-Error handler
      ;; The generic 'error' handler below will catch errors from a closed channel.
      ;; If cleve-elm.channel:<- signals a specific condition for closed channels in the future,
      ;; that condition can be handled here. For now, it signals a simple-error.
      (error (e) 
        (if (and *main-event-channel* (cleve-elm.channel:channel-closed *main-event-channel*))
            (log-warn "EVENT-CONSUMER: *main-event-channel* is closed or operation failed on closed channel. Error: ~A. Exiting loop." e)
            (log-error "EVENT-CONSUMER: Error in event consumer loop: ~A~%Backtrace: ~A"
                       e (with-output-to-string (s) (uiop:print-backtrace :stream s :count 10 :condition e))))
        (setf *shutdown-requested* t) ; Exit loop on any error during receive or if channel is found closed
        (return))))
  (log-info "EVENT-CONSUMER: Event consumer loop terminated"))

(defun process-event (event-wrapper)
  "Process an event in the consumer thread.
   EVENT-WRAPPER is the raw item from the channel, which might be a timestamped event or a command."
  (let ((start-time (get-internal-real-time))
        (event (if (and (consp event-wrapper) (eq (car event-wrapper) :timestamped-event))
                   (cdr event-wrapper)
                   event-wrapper)) ; Assume it's the event itself if not timestamped
        (received-at (if (and (consp event-wrapper) (eq (car event-wrapper) :timestamped-event))
                         (getf event :received-at)
                         (get-internal-real-time))))

    (log-debug "EVENT-CONSUMER: Processing event: ~S" event)
    (setf (gethash :last-event *event-loop-metrics*) event)
    (setf (gethash :last-event-time *event-loop-metrics*) (get-universal-time))

    (typecase event
      ;; Handle TEA messages for app-update-handler
      ((cons (eql :app-message) *) ; Matches (:app-message <actual-message>)
       (let ((actual-message (second event)))
         (log-debug "EVENT-CONSUMER: Calling app-update-handler for: ~S" actual-message)
         (elmtui.platform.driver:app-update-handler actual-message elmtui.core.globals:*app-state*)))
      ;; Handle async commands
      ((cons (member :async :async-task :cmd-async :recurring-task) *)
       (log-debug "EVENT-CONSUMER: Handling async command: ~S" event)
       (elmtui.state.update:handle-async-command event elmtui.core.globals:*app-state*))
      ;; Handle other events via legacy publish system (if subscribers exist)
      (t
       (log-debug "EVENT-CONSUMER: Processing as generic event for legacy subscribers: ~S" event)
       (publish-sync-internal event))) ; Legacy synchronous publish

    (let* ((processing-time-ms (/ (* (- (get-internal-real-time) start-time) 1000.0)
                                  internal-time-units-per-second))
           (queue-time-ms (if received-at
                              (/ (* (- start-time received-at) 1000.0)
                                 internal-time-units-per-second)
                              0.0)))
      (log-debug "EVENT-CONSUMER: Event processed. Queue time: ~,2Fms, Processing time: ~,2Fms." queue-time-ms processing-time-ms)
      (vector-push-extend processing-time-ms *event-processing-time-history*)
      (when (> (fill-pointer *event-processing-time-history*) 1000) ; Trim history
        (setf *event-processing-time-history*
              (subseq *event-processing-time-history* (- (length *event-processing-time-history*) 100))))
      (incf (gethash :processed-event-count *event-loop-metrics* 0))
      (incf (gethash :total-processing-time *event-loop-metrics* 0.0) processing-time-ms))))

(defun elm-stop-loop ()
  "Gracefully stop the event loop and consumer thread."
  (log-info "LOOP: elm-stop-loop called.")
  (setf *shutdown-requested* t)

  (when (and *main-event-channel* (not (cleve-elm.channel:channel-closed *main-event-channel*)))
    (log-info "LOOP: Sending :shutdown-loop signal to *main-event-channel*.")
    (cleve-elm.channel:-> *main-event-channel* :shutdown-loop))

  (when *consumer-thread*
    (log-info "LOOP: Waiting for consumer thread to join...")
    (ignore-errors
     (bt:join-thread *consumer-thread* :timeout 5))
    (if (bt:thread-alive-p *consumer-thread*)
        (log-warn "LOOP: Consumer thread did not join in time.")
        (progn
          (log-info "LOOP: Consumer thread joined.")
          (setf *consumer-thread* nil))))

  (when (and *main-event-channel* (not (cleve-elm.channel:channel-closed *main-event-channel*)))
    (log-info "LOOP: Closing *main-event-channel*.")
    (cleve-elm.channel:channel-close *main-event-channel*))
  (setf *main-event-channel* nil) 

  (when *event-loop*
    (log-info "LOOP: Stopping legacy event loop.")
    (cleve-elm.event-loop:stop-loop *event-loop*)
    (setf *event-loop* nil)))

;; (defun subscribe (event-type handler-fn)
;;   "Subscribe HANDLER-FN to events of type EVENT-TYPE.
;;    Returns a token that can be used to unsubscribe later.
;;    If handler-fn is NIL, signals an error."
;;   (unless handler-fn
;;     (error "Handler function cannot be NIL when subscribing to event-type ~S" event-type))

;;   ;; Get existing handlers for this event type
;;   (let ((handlers (gethash event-type *subscribers*)))
;;     ;; Add the new handler
;;     (push handler-fn handlers)
;;     ;; Update the subscribers hash
;;     (setf (gethash event-type *subscribers*) handlers)
;;     ;; Return a token for unsubscribe
;;     (list :event-type event-type :handler handler-fn :token (gensym "SUB-"))))

;; (defun unsubscribe (token)
;;   "Unsubscribe a handler using TOKEN returned from subscribe.
;;    Returns T if successfully unsubscribed, NIL otherwise."
;;   (when (and (listp token)
;;              (getf token :event-type)
;;              (getf token :handler))
;;     (let* ((event-type (getf token :event-type))
;;            (handler-to-remove (getf token :handler))
;;            (current-handlers (gethash event-type *subscribers*)))
;;       (when (member handler-to-remove current-handlers :test #'eq) ; Ensure handler is present
;;         (setf (gethash event-type *subscribers*)
;;               (remove handler-to-remove current-handlers :test #'eq :count 1)) ; Remove only one instance
;;         t)))) ; Return T indicating successful removal
;;   (log-info "LOOP: Event system shutdown sequence complete."))

(defun enqueue-event (event)
  "Enqueue an event to the main event channel.
   The event is wrapped with a timestamp for metrics."
  (if (and *main-event-channel* (not (cleve-elm.channel:channel-closed *main-event-channel*)))
      (let ((timestamped-event `(:timestamped-event :received-at ,(get-internal-real-time) . ,event)))
        (log-debug "LOOP: Enqueuing to *main-event-channel*: ~S" event)
        (handler-case
            (cleve-elm.channel:-> *main-event-channel* timestamped-event)
          (error (e)
            (log-error "LOOP: Failed to enqueue event to *main-event-channel*: ~A. Event: ~S" e event))))
      (log-warn "LOOP: *main-event-channel* is nil or closed. Dropping event: ~S" event)))

(defun publish (event)
  "Publish an event to all subscribers via the main event channel.
   This version ensures all events go through the central channel for proper TEA sequencing.
   Events are wrapped in an :app-message structure unless they are already structured as such
   or are specific command types."
  (cond
    ((and (listp event) (eq (first event) :app-message))
     (enqueue-event event)) ; Already in :app-message format
    ((and (listp event) (member (first event) '(:async :async-task :cmd-async :recurring-task)))
     (enqueue-event event)) ; Pass async commands directly
    (t
     (enqueue-event (list :app-message event))))) ; Wrap other events

(defun publish-sync-internal (event)
  "Internal synchronous publish function for legacy subscribers.
   WARNING: This bypasses the central channel and should only be used for non-TEA side effects
   or by the consumer thread itself for dispatching to legacy subscribers."
  (let* ((event-key (etypecase event
                      (cleve-elm.message:message (cleve-elm.message:message-type event))
                      (elmtui.core.event-types:key-event (elmtui.core.event-types:key-event-key event))
                      (elmtui.core.event-types:ui-event (elmtui.core.event-types:ui-event-type event))
                      (cons (first event)) ; Assuming (event-type ...) for lists
                      (symbol event)      ; Assuming symbol is the event type
                      (t (progn (log-warn "LOOP: Unknown event type for publish-sync-internal: ~S" event) nil))))
         (handlers (when event-key (gethash event-key *subscribers*)))
         (generic-key-event-handlers (when (typep event 'elmtui.core.event-types:key-event)
                                       (gethash :key-event *subscribers*)))
         (all-handlers (remove-duplicates (append handlers generic-key-event-handlers) :test #'eq)))

    (when event-key
      (log-debug "LOOP: publish-sync-internal for ~S, ~D handlers." event-key (length all-handlers))
      (dolist (handler all-handlers)
        (handler-case (funcall handler event)
          (elmtui.core.conditions:subscriber-handler-error (c)
            (log-error "LOOP: Error in legacy subscriber (already caught): ~A" c))
          (error (e)
            (log-error "LOOP: Unhandled error in legacy subscriber for event ~S: ~A" event-key e)
            (elmtui.core.conditions:signal-subscriber-error e handler event)))))))

;; Status and metrics functions
(defun get-event-loop-status ()
  "Get the current status of the event loop."
  (list :consumer-thread-active (and *consumer-thread* (bt:thread-alive-p *consumer-thread*))
        :main-event-channel-exists (not (null *main-event-channel*))
        :main-event-channel-closed (if *main-event-channel*
                                       (cleve-elm.channel:channel-closed *main-event-channel*)
                                       :not-exists)
        :shutdown-requested *shutdown-requested*
        :last-event-time (gethash :last-event-time *event-loop-metrics* 0)
        :last-event (gethash :last-event *event-loop-metrics* nil)
        :processed-event-count (gethash :processed-event-count *event-loop-metrics* 0)
        :average-processing-time-ms (if (> (gethash :processed-event-count *event-loop-metrics* 0) 0)
                                        (/ (gethash :total-processing-time *event-loop-metrics* 0.0)
                                           (gethash :processed-event-count *event-loop-metrics* 0))
                                        0.0)))

(defun get-event-queue-length ()
  "Get the approximate length of the event queue.
   This depends on the underlying cleve-elm.channel implementation."
  (if (and *main-event-channel* (not (cleve-elm.channel:channel-closed *main-event-channel*)))
      (let ((queue-obj (ignore-errors (cleve-elm.channel:channel-queue *main-event-channel*)))) ; Use accessor
        (if (and queue-obj (fboundp 'cleve-elm.queue:queue-length)) ; cleve-elm.queue is used by cleve-elm.channel
            (ignore-errors (cleve-elm.queue:queue-length queue-obj))
            :unknown-queue-impl-or-no-length-fn))
      :channel-not-available-or-closed))

;; Legacy functions (subscribe, unsubscribe, etc.) are kept for now for compatibility.
;; They interact with *subscribers* hash table used by publish-sync-internal.

(defun subscribe (event-type handler-fn)
  "Subscribe HANDLER-FN to EVENT-TYPE. (Legacy)"
  (log-debug "LOOP: Legacy subscribe for ~S" event-type)
  (push handler-fn (gethash event-type *subscribers*)))

(defun subscribe-with-priority (event-type handler-fn priority)
  "Subscribe HANDLER-FN to EVENT-TYPE with PRIORITY. (Legacy - priority ignored)"
  (declare (ignore priority))
  (subscribe event-type handler-fn))

(defun unsubscribe (event-type handler-fn)
  "Unsubscribe HANDLER-FN from EVENT-TYPE. (Legacy)"
  (log-debug "LOOP: Legacy unsubscribe for ~S" event-type)
  (setf (gethash event-type *subscribers*)
        (remove handler-fn (gethash event-type *subscribers*))))

(defun dispatch-event (event)
  "Legacy dispatch function for backward compatibility.
   This will now effectively call publish-sync-internal."
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:event-loop-dispatch-error)
    (handler-case
        (publish-sync-internal event)
      (error (e)
        (log-error "LOOP: Error in legacy dispatch-event: ~A" e)
        (error 'elmtui.core.conditions:event-loop-dispatch-error :event event :reason e)))))

(defvar *event-loop-instrumentation-hooks* nil
  "Stub: List of instrumentation hook functions for event loop metrics/tracing.")

(defun instrument-event-loop (event)
  "Instrumentation hook for debugging/profiling. Extend with hooks for timing/metrics."
  ;; (format t "[event-loop] Dispatched event: ~A~%" event)
  (dolist (hook *event-loop-instrumentation-hooks*)
    (funcall hook event)))
(defun elm-event-loop-active-p ()
  "Check if the main event consumer loop is active. (Legacy compatibility)"
  (and *consumer-thread* (bt:thread-alive-p *consumer-thread*)))

(defvar *lifecycle-hooks* (make-hash-table :test 'equal) "Legacy lifecycle hooks.")

(defun instrument-event-loop ()
  "Placeholder for event loop instrumentation. (Legacy)"
  (log-info "LOOP:
