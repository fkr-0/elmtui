;;;===============================================================
;;; File: src/core/event-async.lisp
;;; Enhanced Async Infrastructure Integration for Events
;;;===============================================================
(uiop:define-package :elmtui.core.event-async
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.core.event-types
                #:ui-event
                #:ui-event-p
                #:ui-event-type
                #:ui-event-target
                #:key-event
                #:key-event-p
                #:mouse-event
                #:mouse-event-p)
  (:import-from :elmtui.core.event-propagation
                #:dispatch-event)
  (:import-from :elmtui.core.event-channels
                #:wait-for-event
                #:register-event-handler)
  (:import-from :cl-events.channel
   #:make-channel
   #:make-filtered-channel
   #:->
   #:<-
   #:select)
  (:import-from :cl-events.async
   #:make-promise
   #:promise
   #:resolve-promise
   #:reject-promise
   #:await)
  (:import-from :bordeaux-threads
   #:make-thread)
  (:export
   ;; Event channels
   #:*main-event-channel*
   #:*key-event-channel*
   #:*mouse-event-channel*
   #:*ui-event-channel*
   #:*delayed-event-channel*
   #:*focus-event-channel*
   #:*command-event-channel*

   ;; Event handling functions
   #:initialize-event-channels
   #:start-event-processing
   #:stop-event-processing
   #:process-event
   #:event-processing-loop

   ;; Event dispatching functions
   #:dispatch-event-async
   #:schedule-event
   #:schedule-repeating-event

   ;; Promise-based event utilities
   #:event-promise
   #:wait-for-event-async
   #:async-dispatch
   #:chain-events

   ;; Utility functions
   #:debounce
   #:throttle
   #:delay-event

   ;; Timer management
   #:schedule-timer
   #:cancel-timer))

(in-package :elmtui.core.event-async)

;;;-----------------------------------------------------------------------------
;;; Enhanced Event Channels
;;;-----------------------------------------------------------------------------

(defvar *main-event-channel* nil
  "Main channel for all events.")

(defvar *key-event-channel* nil
  "Channel specifically for keyboard events.")

(defvar *mouse-event-channel* nil
  "Channel specifically for mouse events.")

(defvar *ui-event-channel* nil
  "Channel specifically for UI events (e.g., widget events).")

(defvar *delayed-event-channel* nil
  "Channel for delayed events.")

(defvar *focus-event-channel* nil
  "Channel specifically for focus-related events.")

(defvar *command-event-channel* nil
  "Channel for command execution and results.")

(defvar *event-worker* nil
  "Worker thread for event processing.")

(defvar *event-processing-active* nil
  "Flag indicating whether event processing is active.")

(defvar *timer-registry* (make-hash-table :test 'eq)
  "Registry of active timers.")

(defvar *next-timer-id* 0
  "Counter for generating unique timer IDs.")

(defun initialize-event-channels ()
  "Creates and initializes all event channels with appropriate filters."
  (log-info "Initializing enhanced event channels")

  ;; Create channels with appropriate buffer sizes
  (setf *main-event-channel* (make-channel))

  ;; Create filtered channels for specific event types
  (setf *key-event-channel* (make-filtered-channel
                             :filters (list (lambda (event)
                                              (typep event 'key-event)))))

  (setf *mouse-event-channel* (make-filtered-channel
                               :filters (list (lambda (event)
                                                (typep event 'mouse-event)))))

  (setf *ui-event-channel* (make-channel))
  (setf *delayed-event-channel* (make-channel))
  (setf *focus-event-channel* (make-channel))
  (setf *command-event-channel* (make-channel))

  (log-debug "Event channels initialized successfully"))

;;;-----------------------------------------------------------------------------
;;; Event Processing System
;;;-----------------------------------------------------------------------------

(defun start-event-processing (ui-tree-fn app-state-fn)
  "Start the event processing system.
   UI-TREE-FN: Function to get the current UI tree.
   APP-STATE-FN: Function to get the current application state."
  (unless *main-event-channel*
    (initialize-event-channels))

  ;; Don't start if already running
  (when *event-processing-active*
    (log-warn "Event processing system is already active")
    (return-from start-event-processing nil))

  (setf *event-processing-active* t)

  ;; Start the main event processing thread
  (setf *event-worker*
        (make-thread
         (lambda ()
           (event-processing-loop ui-tree-fn app-state-fn))
         :name "ELMTUI Event Worker"))

  (log-info "Event processing system started")
  t)

(defun stop-event-processing ()
  "Stop the event processing system and clean up resources."
  (unless *event-processing-active*
    (log-warn "Event processing system is not active")
    (return-from stop-event-processing nil))

  (log-info "Stopping event processing system")

  ;; Signal the worker thread to stop
  (setf *event-processing-active* nil)

  ;; Cancel all active timers
  (maphash (lambda (id timer)
             (declare (ignore id))
             (bt:destroy-thread timer))
           *timer-registry*)
  (clrhash *timer-registry*)

  ;; Wait for worker thread to finish if it exists
  (when (and *event-worker* (bt:thread-alive-p *event-worker*))
    (bt:join-thread *event-worker*))

  (log-info "Event processing system stopped")
  t)

(defun event-processing-loop (ui-tree-fn app-state-fn
                              &key (idle-sleep 0.1))
  "Main dispatcher.
   • *ui-tree-fn*   — thunk returning the current UI tree
   • *app-state-fn* — thunk returning the current application state
   The loop polls all standard event channels in priority order.
   When no event is ready within IDLE-SLEEP seconds we simply iterate
   again; this prevents busy-spinning when the application is idle."
  (log:debug "Starting event-processing loop")

  ;; Gather the channels just once; they are stable for the lifetime
  ;; of the application.  (If your app can *add* channels on the fly,
  ;; move this binding inside the LOOP and refresh as needed.)
  (let ((channels (list *main-event-channel*
                        *key-event-channel*
                        *mouse-event-channel*
                        *ui-event-channel*
                        *delayed-event-channel*
                        *focus-event-channel*
                        *command-event-channel*)))

    (loop while *event-processing-active*
          for result = (wait-for-event channels
                                       :timeout idle-sleep)
          do (when result
               ;; WAIT-FOR-EVENT returns two values: EVENT  and  CHANNEL
               (multiple-value-bind (event src) result
                 (process-event src event ui-tree-fn app-state-fn))))))

(defun process-event (channel event ui-tree-fn app-state-fn)
  "Process an event received from a channel.
   CHANNEL: The channel from which the event was received.
   EVENT: The event to process.
   UI-TREE-FN: Function to get the current UI tree.
   APP-STATE-FN: Function to get the current application state."
  (log-debug "Processing event from channel ~A: ~A" channel event)

  ;; Get the current UI tree and app state
  (let ((ui-tree (funcall ui-tree-fn))
        (app-state (funcall app-state-fn)))
    (declare (ignore app-state)) ; app-state might be needed for more complex processing

    ;; Process based on event type
    (typecase event
      ;; Standard UI events
      ((or ui-event key-event mouse-event)
       ;; Dispatch through standard event propagation
       (dispatch-event ui-tree event))

      ;; Handle command results
      ((cons (eql :command-result))
       (log-debug "Processing command result: ~A" (second event))
       ;; Handle command result
       (let ((result (second event))
             (promise (third event)))
         (when promise
           (resolve-promise promise result))))

      ;; Handle delayed events
      ((cons (eql :delayed))
       ;; Handle delayed event
       (let ((real-event (second event))
             (timestamp (third event)))
         (log-debug "Processing delayed event from ~A: ~A" timestamp real-event)
         (process-event channel real-event ui-tree-fn app-state-fn)))

      ;; Handle focus events
      ((cons (eql :focus))
       (log-debug "Processing focus event: ~A" (rest event))
       ;; Focus event handling logic here
       )

      ;; Unknown event type
      (t
       (log-warn "Unknown event type: ~A" event)))))

;;;-----------------------------------------------------------------------------
;;; Enhanced Event Dispatching with Promise Support
;;;-----------------------------------------------------------------------------

(defun dispatch-event-async (event &optional (priority :normal))
  "Dispatches an event asynchronously to the appropriate channel.
   EVENT: The event to dispatch.
   PRIORITY: Priority of the event (:high, :normal, :low).
   Returns a promise that resolves when the event is processed."
  (unless *main-event-channel*
    (initialize-event-channels))

  ;; Create a promise for this event
  (let ((result-promise (make-promise)))

    ;; Determine which channel to use based on event type and priority
    (let ((target-channel
            (cond
              ((eq priority :high) *main-event-channel*)
              ((key-event-p event) *key-event-channel*)
              ((mouse-event-p event) *mouse-event-channel*)
              (t *ui-event-channel*))))

      ;; Send the event to the appropriate channel
      (-> target-channel event)

      ;; Return the promise
      result-promise)))

(defun schedule-event (event delay-ms &optional (priority :normal))
  "Schedule an event to be dispatched after a specified delay.
   EVENT: The event to dispatch.
   DELAY-MS: Delay in milliseconds.
   PRIORITY: Priority of the event (:high, :normal, :low).
   Returns a timer-id that can be used to cancel the scheduled event."
  (unless *delayed-event-channel*
    (initialize-event-channels))

  (let ((timer-id (gensym "TIMER"))
        (timestamp (get-internal-real-time)))

    ;; Create a timer thread that will wait and then dispatch the event
    (setf (gethash timer-id *timer-registry*)
          (bt:make-thread
           (lambda ()
             (sleep (/ delay-ms 1000.0))
             (-> *delayed-event-channel* (list :delayed event timestamp priority))
             (remhash timer-id *timer-registry*))
           :name (format nil "Event Timer ~A" timer-id)))

    ;; Return the timer ID
    timer-id))

(defun schedule-repeating-event (event interval-ms count &optional (priority :normal))
  "Schedule an event to be dispatched repeatedly at specified intervals.
   EVENT: The event to dispatch.
   INTERVAL-MS: Interval in milliseconds between event dispatches.
   COUNT: Number of times to repeat (-1 for infinite).
   PRIORITY: Priority of the event (:high, :normal, :low).
   Returns a timer-id that can be used to cancel the repeating event."
  (unless *delayed-event-channel*
    (initialize-event-channels))

  (let ((timer-id (gensym "REPEATING-TIMER"))
        (timestamp (get-internal-real-time)))

    ;; Create a timer thread that will wait and then dispatch events repeatedly
    (setf (gethash timer-id *timer-registry*)
          (bt:make-thread
           (lambda ()
             (loop with remaining = count
                   while (and (or (= remaining -1) (> remaining 0))
                              (gethash timer-id *timer-registry*))
                   do (progn
                        (sleep (/ interval-ms 1000.0))
                        (-> *delayed-event-channel* (list :delayed event timestamp priority))
                        (when (/= remaining -1)
                          (decf remaining)))
                   finally (remhash timer-id *timer-registry*)))
           :name (format nil "Repeating Event Timer ~A" timer-id)))

    ;; Return the timer ID
    timer-id))

(defun schedule-timer (callback delay-ms &key (repeat nil))
  "Schedule a timer to execute a callback after DELAY-MS milliseconds.
   Returns a timer ID that can be used to cancel the timer.
   If REPEAT is non-nil, the timer will repeat every DELAY-MS milliseconds."
  (let* ((timer-id (incf *next-timer-id*))
         (start-time (get-internal-real-time))
         (delay-internal (round (* delay-ms internal-time-units-per-second) 1000))
         (timer-thread
           (create-thread
            (lambda ()
              (loop
                ;; Calculate time to sleep
                (let ((elapsed (- (get-internal-real-time) start-time))
                      (next-time (+ start-time delay-internal)))
                  (if (< elapsed delay-internal)
                      ;; Sleep until it's time
                      (sleep (/ (- next-time (get-internal-real-time))
                                internal-time-units-per-second))
                      ;; No sleep needed, already elapsed
                      nil))

                ;; Execute callback
                (handler-case
                    (funcall callback)
                  (error (e)
                    (log-error "Error in timer callback: ~A" e)))

                ;; Update start time for next iteration if repeating
                (if repeat
                    (setf start-time (get-internal-real-time))
                    (return))))
            :name (format nil "Timer-~D" timer-id))))

    ;; Register the timer
    (setf (gethash timer-id *timer-registry*)
          (list :thread timer-thread
                :callback callback
                :delay delay-ms
                :repeat repeat
                :start-time start-time))

    ;; Return the timer ID
    timer-id))

(defun cancel-timer (timer-id)
  "Cancel a timer by its ID."
  (let ((timer (gethash timer-id *timer-registry*)))
    (when timer
      ;; Stop the thread
      (when (getf timer :thread)
        (bt:destroy-thread (getf timer :thread)))

      ;; Remove from registry
      (remhash timer-id *timer-registry*)

      ;; Return success
      t)))

;;;-----------------------------------------------------------------------------
;;; Promise-Based Event Utilities
;;;-----------------------------------------------------------------------------

(defun event-promise (event-type &key target timeout (channel *ui-event-channel*))
  "Creates a promise that resolves when an event of the specified type is received.
   EVENT-TYPE: Type of event to wait for.
   TARGET: Optional target to filter events.
   TIMEOUT: Optional timeout in milliseconds.
   CHANNEL: The channel to listen for events on (default is *ui-event-channel*)
   Returns a promise that resolves with the event when received, or rejects on timeout."
  (let ((result-promise (make-promise))
        (timer-id nil))

    ;; Set up timeout if specified
    (when timeout
      (setf timer-id
            (schedule-timer
             (lambda ()
               (reject-promise result-promise :timeout))
             timeout)))

    ;; Create a handler for the event
    (let ((handler-fn
            (lambda (event)
              (when (and (eq (ui-event-type event) event-type)
                         (or (null target) (eq (ui-event-target event) target)))
                ;; Cancel the timeout timer if it exists
                (when timer-id
                  (cancel-timer timer-id))

                ;; Resolve the promise with the event
                (resolve-promise result-promise event)))))

      ;; Register the handler
      (register-event-handler channel handler-fn )


      ;; Return the promise
      result-promise)))

(defun wait-for-event-async (event-type &key target timeout)
  "Asynchronously wait for an event of the specified type.
   EVENT-TYPE: Type of event to wait for.
   TARGET: Optional target to filter events.
   TIMEOUT: Optional timeout in milliseconds.
   Returns the event when received, or signals an error on timeout."
  (await (event-promise event-type :target target :timeout timeout)))

(defun async-dispatch (event-chain)
  "Dispatch a chain of events asynchronously, with each subsequent event
   dispatched after the previous one is processed.
   EVENT-CHAIN: List of events to dispatch in sequence.
   Returns a promise that resolves when all events are processed."
  (let ((chain-promise (make-promise)))
    (labels ((dispatch-next (events)
               (if events
                   (chain
                    (dispatch-event-async (first events))
                    (lambda (_)
                      (declare (ignore _))
                      (dispatch-next (rest events))))
                   (resolve-promise chain-promise t))))
      (dispatch-next event-chain))
    chain-promise))

(defun chain (event-promise &optional (callback nil))
  "Chain a single event promise with an optional callback.
   EVENT-PROMISE: The promise to chain.
   CALLBACK: Optional callback function to execute after the event is processed.
   Returns a new promise that resolves when the event is processed."
  (let ((result-promise (make-promise)))
    (chain
     event-promise
     (lambda (result)
       (when callback
         (funcall callback result))
       (resolve-promise result-promise result)))
    result-promise))

(defun chain-events (&rest event-functions)
  "Chain multiple event-generating functions together, executing each one
   after the previous one completes.
   EVENT-FUNCTIONS: Functions that generate and dispatch events.
   Returns a promise that resolves when all functions have completed."
  (let ((chain-promise (make-promise)))
    (labels ((execute-next (functions)
               (if functions
                   (chain
                    (funcall (first functions))
                    (lambda (result)
                      (list result
                            (execute-next (rest functions)))))
                   (resolve-promise chain-promise t))))
      (execute-next event-functions))
    chain-promise))

;;;-----------------------------------------------------------------------------
;;; Utility Functions
;;;-----------------------------------------------------------------------------

(defun debounce (function delay)
  "Creates a debounced version of the function.
   FUNCTION: The function to debounce.
   DELAY: Delay in milliseconds.
   Returns a new function that will only execute after the specified delay
   has passed without any new calls."
  (let ((timer-id nil))
    (lambda (&rest args)
      ;; Cancel any existing timer
      (when timer-id
        (cancel-timer timer-id))

      ;; Create a new timer
      (let ((result-promise (make-promise)))
        (setf timer-id
              (schedule-event
               (lambda ()
                 (let ((result (apply function args)))
                   (resolve-promise result-promise result)))
               delay))
        result-promise))))

(defun throttle (function interval)
  "Creates a throttled version of the function.
   FUNCTION: The function to throttle.
   INTERVAL: Minimum interval in milliseconds between function calls.
   Returns a new function that will execute at most once per interval."
  (let ((last-execution 0)
        (queued nil)
        (result-promise nil))
    (lambda (&rest args)
      (let ((now (get-internal-real-time))
            (ms-per-internal-time-unit (/ 1000 internal-time-units-per-second)))

        ;; Calculate time since last execution in milliseconds
        (let ((time-since-last (* (- now last-execution) ms-per-internal-time-unit)))

          ;; If we're beyond the interval, execute immediately
          (if (>= time-since-last interval)
              (progn
                (setf last-execution now)
                (let ((result (apply function args)))
                  (when result-promise
                    (resolve-promise result-promise result))
                  (setf result-promise (make-promise))
                  (resolve-promise result-promise result)
                  result-promise))

              ;; Otherwise, queue for later execution
              (progn
                (setf queued args)
                (unless result-promise
                  (setf result-promise (make-promise))

                  ;; Schedule execution at the next interval
                  (let ((wait-time (- interval time-since-last)))
                    (schedule-event
                     (lambda ()
                       (when queued
                         (setf last-execution (get-internal-real-time))
                         (let ((result (apply function queued)))
                           (resolve-promise result-promise result)
                           (setf queued nil)
                           (setf result-promise nil))))
                     wait-time)))
                result-promise)))))))

(defun delay-event (event delay-ms)
  "Create a delayed version of an event.
   EVENT: The event to delay.
   DELAY-MS: Delay in milliseconds.
   Returns the original event for chaining."
  (schedule-event event delay-ms)
  event)

;; (defun schedule-timer ())
