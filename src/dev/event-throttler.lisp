;;;===============================================================
;;; File: src/dev/event-throttler.lisp
;;; Event Throttling and Debouncing Utilities
;;;===============================================================
(uiop:define-package :elmtui.dev.event-throttler
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :elmtui.core.event-types
                #:ui-event
                #:ui-event-type
                #:ui-event-timestamp)
  (:export 
   ;; General function throttling and debouncing
   #:throttle
   #:debounce
   #:rate-limit
   #:cancel-throttle
   #:cancel-debounce
   
   ;; Event-specific throttling and debouncing
   #:throttle-events
   #:debounce-events
   #:make-throttled-handler
   #:make-debounced-handler
   
   ;; Utilities and helpers
   #:throttle-event-predicate
   #:combine-throttled-handlers))

(in-package :elmtui.dev.event-throttler)

;;;-----------------------------------------------------------------------------
;;; Internal Utilities
;;;-----------------------------------------------------------------------------

(defvar *timers* (make-hash-table :test 'eq)
  "Registry of active timers for throttled and debounced functions.")

(defvar *timer-lock* (bt:make-lock "throttle-timer-lock")
  "Lock to protect the timers hash table.")

(defun get-current-time-ms ()
  "Get the current time in milliseconds."
  (let ((now (local-time:now)))
    (+ (* 1000 (local-time:timestamp-to-unix now))
       (floor (local-time:timestamp-millisecond now)))))

(defun set-timer (key function delay)
  "Set a timer to execute the function after the specified delay (in milliseconds)."
  (bt:with-lock-held (*timer-lock*)
    (let ((existing-timer (gethash key *timers*)))
      (when existing-timer
        (bt:destroy-thread (car existing-timer))))
    
    (let* ((thread-name (format nil "Timer-~A-~A" key (random 1000000)))
           (timer-thread 
            (bt:make-thread
             (lambda ()
               (handler-case
                   (progn
                     (sleep (/ delay 1000.0))
                     (bt:with-lock-held (*timer-lock*)
                       (remhash key *timers*))
                     (funcall function))
                 (error (c)
                   (log:error "Error in timer function (~A): ~A" key c))))
             :name thread-name)))
      
      (setf (gethash key *timers*)
            (cons timer-thread (get-current-time-ms)))
      timer-thread)))

(defun cancel-timer (key)
  "Cancel a timer identified by key."
  (bt:with-lock-held (*timer-lock*)
    (let ((timer-data (gethash key *timers*)))
      (when timer-data
        (let ((thread (car timer-data)))
          (when (bt:thread-alive-p thread)
            (bt:destroy-thread thread))
          (remhash key *timers*)
          t)))))

(defun make-key (function label)
  "Create a unique key for a function and optional label."
  (if label
      (cons function label)
      function))

;;;-----------------------------------------------------------------------------
;;; General Function Throttling and Debouncing
;;;-----------------------------------------------------------------------------

(defun throttle (function timeout &key (label nil))
  "Create a throttled version of FUNCTION that executes at most once every TIMEOUT milliseconds.
   Returns a function that accepts the same arguments as FUNCTION.
   
   Example:
   (setf window-resize-handler (throttle #'handle-resize 100))
   
   Each call to window-resize-handler will call handle-resize at most once
   every 100ms, even if window-resize-handler is called more frequently."
  
  (let ((key (make-key function label))
        (last-called nil))
    (lambda (&rest args)
      (let ((now (get-current-time-ms)))
        (cond
          ;; First call or enough time has passed since last call
          ((or (null last-called)
               (>= (- now last-called) timeout))
           (setf last-called now)
           (apply function args))
          
          ;; Skip this call, it's within the timeout period
          (t nil))))))

(defun debounce (function wait &key (leading nil) (trailing t) (max-wait nil) (label nil))
  "Create a debounced version of FUNCTION that delays execution until after WAIT milliseconds
   have elapsed since the last time it was invoked.
   
   Parameters:
   - FUNCTION: The function to debounce
   - WAIT: The number of milliseconds to delay
   - LEADING: If T, call the function on the leading edge of the timeout
   - TRAILING: If T, call the function on the trailing edge of the timeout
   - MAX-WAIT: Maximum time FUNCTION is allowed to be delayed before it's invoked
   - LABEL: Optional label to distinguish different debounced versions of the same function
   
   Returns a function that accepts the same arguments as FUNCTION.
   
   Example:
   (setf search-handler (debounce #'perform-search 300 :trailing t))
   
   The search will only be performed 300ms after the last call to search-handler."
  
  (let ((key (make-key function label))
        (last-args nil)
        (last-called nil)
        (max-timer-key (when max-wait (cons key :max-wait))))
    
    (lambda (&rest args)
      (let ((now (get-current-time-ms)))
        ;; Store the arguments for later use by the trailing function
        (setf last-args args)
        
        ;; Set up max-wait timer if needed
        (when (and max-wait (null last-called))
          (set-timer max-timer-key
                     (lambda ()
                       (setf last-called now)
                       (apply function last-args))
                     max-wait))
        
        ;; Update the last called time
        (setf last-called now)
        
        ;; Call immediately if leading edge
        (when leading
          (when (not (gethash key *timers*))
            (apply function args)))
        
        ;; Set or reset trailing timer
        (when trailing
          (set-timer key
                     (lambda () (apply function last-args))
                     wait))))))

(defun cancel-throttle (function &optional label)
  "Cancel any pending throttled executions of FUNCTION."
  (cancel-timer (make-key function label)))

(defun cancel-debounce (function &optional label)
  "Cancel any pending debounced executions of FUNCTION.
   Also cancels any max-wait timer associated with this function."
  (let ((key (make-key function label)))
    (cancel-timer key)
    (when label
      (cancel-timer (cons key :max-wait)))))

(defun rate-limit (function rate period &key (label nil))
  "Limit FUNCTION to executing at most RATE times per PERIOD seconds.
   Returns a function that accepts the same arguments as FUNCTION.
   
   Example:
   (setf log-handler (rate-limit #'log-event 5 1.0))
   
   The log-handler will log at most 5 events per second."
  
  (let ((key (make-key function label))
        (calls-in-period 0)
        (period-start (get-current-time-ms))
        (period-ms (* period 1000)))
    
    (lambda (&rest args)
      (let ((now (get-current-time-ms)))
        ;; Check if we're in a new period
        (when (>= (- now period-start) period-ms)
          (setf period-start now
                calls-in-period 0))
        
        ;; Check if we've reached the rate limit
        (if (< calls-in-period rate)
            (progn
              (incf calls-in-period)
              (apply function args))
            nil)))))

;;;-----------------------------------------------------------------------------
;;; General Function Throttling and Debouncing
;;;-----------------------------------------------------------------------------

(defun throttle (function timeout &key (label nil) (leading t) (trailing nil))
  "Create a throttled version of FUNCTION that executes at most once every TIMEOUT milliseconds.
   
   Parameters:
   - FUNCTION: The function to throttle
   - TIMEOUT: Minimum time (in ms) between function executions
   - LABEL: Optional label to distinguish different throttled versions of the same function
   - LEADING: If T, call on the leading edge of the timeout (first call executes immediately)
   - TRAILING: If T, call on the trailing edge of the timeout (after timeout has elapsed)
   
   Returns a function that accepts the same arguments as FUNCTION.
   
   Example:
   (setf window-resize-handler (throttle #'handle-resize 100))
   
   Each call to window-resize-handler will call handle-resize at most once
   every 100ms, even if window-resize-handler is called more frequently."
  
  (let ((key (make-key function label))
        (last-called nil)
        (last-args nil)
        (result nil)
        (timer nil))
    (lambda (&rest args)
      (let ((now (get-current-time-ms)))
        ;; Store the arguments for potential trailing execution
        (setf last-args args)
        
        (cond
          ;; First call or enough time has passed since last call - execute immediately if leading
          ((or (null last-called)
               (>= (- now last-called) timeout))
           (when leading
             (setf last-called now)
             (setf result (apply function args)))
           
           ;; Set up trailing execution if needed
           (when trailing
             (cancel-timer key)
             (set-timer key
                       (lambda () 
                         (setf result (apply function last-args)))
                       timeout)))
          
          ;; Call within throttle period - schedule trailing execution if needed
          (t 
           (when trailing
             (cancel-timer key)
             (set-timer key
                       (lambda () 
                         (setf result (apply function last-args)))
                       (- timeout (- now last-called))))))
        
        ;; Return the result (may be from a previous execution)
        result))))

(defun debounce (function wait &key (leading nil) (trailing t) (max-wait nil) (label nil))
  "Create a debounced version of FUNCTION that delays execution until after WAIT milliseconds
   have elapsed since the last time it was invoked.
   
   Parameters:
   - FUNCTION: The function to debounce
   - WAIT: The number of milliseconds to delay
   - LEADING: If T, call the function on the leading edge of the timeout
   - TRAILING: If T, call the function on the trailing edge of the timeout
   - MAX-WAIT: Maximum time FUNCTION is allowed to be delayed before it's invoked
   - LABEL: Optional label to distinguish different debounced versions of the same function
   
   Returns a function that accepts the same arguments as FUNCTION.
   
   Example:
   (setf search-handler (debounce #'perform-search 300 :trailing t))
   
   The search will only be performed 300ms after the last call to search-handler."
  
  (let ((key (make-key function label))
        (last-args nil)
        (last-called nil)
        (result nil)
        (max-timer-key (when max-wait (cons key :max-wait))))
    
    (lambda (&rest args)
      (let ((now (get-current-time-ms)))
        ;; Store the arguments for later use by the trailing function
        (setf last-args args)
        
        ;; Set up max-wait timer if needed
        (when (and max-wait (null last-called))
          (set-timer max-timer-key
                   (lambda ()
                     (setf last-called now)
                     (setf result (apply function last-args)))
                   max-wait))
        
        ;; Update the last called time
        (setf last-called now)
        
        ;; Call immediately if leading edge and no existing timer
        (when leading
          (when (not (gethash key *timers*))
            (setf result (apply function args))))
        
        ;; Set or reset trailing timer
        (when trailing
          (cancel-timer key)
          (set-timer key
                   (lambda () 
                     (setf result (apply function last-args)))
                   wait))
        
        ;; Return the result (may be from a previous execution)
        result))))

(defun rate-limit (function rate period &key (label nil))
  "Limit FUNCTION to executing at most RATE times per PERIOD milliseconds.
   
   Parameters:
   - FUNCTION: The function to rate-limit
   - RATE: Maximum number of calls allowed per period
   - PERIOD: The time window in milliseconds
   - LABEL: Optional label to distinguish different rate-limited versions of the same function
   
   Returns a function that accepts the same arguments as FUNCTION.
   
   Example:
   (setf log-handler (rate-limit #'log-event 5 1000))
   
   The log-handler will log at most 5 events per second."
  
  (let ((key (make-key function label))
        (calls-in-period 0)
        (period-start (get-current-time-ms))
        (period-ms period)
        (call-times (make-array rate :initial-element 0))
        (call-index 0)
        (result nil))
    
    (lambda (&rest args)
      (let ((now (get-current-time-ms)))
        ;; Check if we're in a new period
        (when (>= (- now period-start) period-ms)
          (setf period-start now
                calls-in-period 0))
        
        ;; Check if we've reached the rate limit
        (if (< calls-in-period rate)
            (progn
              ;; Record this call time
              (setf (aref call-times call-index) now)
              (setf call-index (mod (1+ call-index) rate))
              
              ;; Increment counter and execute
              (incf calls-in-period)
              (setf result (apply function args)))
            
            ;; Rate limit exceeded
            nil)
        
        ;; Return the result (may be from a previous execution)
        result)))))

;;;-----------------------------------------------------------------------------
;;; Event-Specific Throttling and Debouncing
;;;-----------------------------------------------------------------------------

(defun throttle-event-predicate (event1 event2)
  "Default predicate to determine if two events are of the same type.
   Used for event throttling and debouncing to group related events."
  (cond
    ;; For UI events, compare by type
    ((and (typep event1 'ui-event) (typep event2 'ui-event))
     (eq (ui-event-type event1) (ui-event-type event2)))
    
    ;; For list events that start with keywords (common format), compare the first element
    ((and (listp event1) (listp event2) 
          (> (length event1) 0) (> (length event2) 0)
          (keywordp (first event1)) (keywordp (first event2)))
     (eq (first event1) (first event2)))
    
    ;; For other types, just use equal
    (t (equal (type-of event1) (type-of event2)))))

(defun make-throttled-handler (handler timeout &key (predicate #'throttle-event-predicate) 
                                                  leading trailing)
  "Create a throttled event handler that executes at most once every TIMEOUT milliseconds
   for each distinct event type (as determined by PREDICATE).
   
   Parameters:
   - HANDLER: The event handler function taking an event as its argument
   - TIMEOUT: The throttle interval in milliseconds
   - PREDICATE: A function taking two events that returns T if they should be considered the same type
   - LEADING: If T, call on the leading edge of the timeout (first event processed immediately)
   - TRAILING: If T, call on the trailing edge of the timeout
   
   Returns a function that can be used as an event handler."
  
  (let ((last-events (make-hash-table :test 'eq))
        (last-times (make-hash-table :test 'eq))
        (timers (make-hash-table :test 'eq)))
    
    (lambda (event)
      (let* ((event-type (if (typep event 'ui-event)
                           (ui-event-type event)
                           (type-of event)))
             (last-time (gethash event-type last-times))
             (last-event (gethash event-type last-events))
             (timer (gethash event-type timers))
             (now (get-current-time-ms)))
        
        ;; Update the last event of this type
        (setf (gethash event-type last-events) event)
        
        (cond
          ;; First event of this type or enough time has passed
          ((or (null last-time)
               (>= (- now last-time) timeout))
           
           ;; Leading edge - process immediately
           (when leading
             (setf (gethash event-type last-times) now)
             (funcall handler event))
           
           ;; Set up trailing edge if needed
           (when trailing
             (when timer
               (cancel-timer (cons event-type :throttle)))
             (setf (gethash event-type timers)
                   (set-timer (cons event-type :throttle)
                             (lambda ()
                               (let ((latest-event (gethash event-type last-events)))
                                 (when latest-event
                                   (funcall handler latest-event))
                                 (remhash event-type timers)))
                             timeout))))
          
          ;; Within throttle interval - update timer for trailing edge if needed
          (t 
           (when trailing
             (when timer
               (cancel-timer (cons event-type :throttle)))
             (setf (gethash event-type timers)
                   (set-timer (cons event-type :throttle)
                             (lambda ()
                               (let ((latest-event (gethash event-type last-events)))
                                 (when latest-event
                                   (funcall handler latest-event))
                                 (remhash event-type timers)))
                             (- timeout (- now last-time)))))))))))

(defun make-debounced-handler (handler wait &key (leading nil) (trailing t) (max-wait nil)
                                             (predicate #'throttle-event-predicate))
  "Create a debounced event handler that delays execution until after WAIT milliseconds
   have elapsed since the last event of the same type (as determined by PREDICATE).
   
   Parameters:
   - HANDLER: The event handler function taking an event as its argument
   - WAIT: The debounce interval in milliseconds
   - LEADING: If T, call the handler on the leading edge of the timeout
   - TRAILING: If T, call the handler on the trailing edge of the timeout
   - MAX-WAIT: Maximum time the handler is allowed to be delayed before it's invoked
   - PREDICATE: A function taking two events that returns T if they should be considered the same type
   
   Returns a function that can be used as an event handler."
  
  (let ((timers (make-hash-table :test 'eq))
        (last-events (make-hash-table :test 'eq))
        (max-timers (when max-wait (make-hash-table :test 'eq))))
    
    (lambda (event)
      (let* ((event-type (if (typep event 'ui-event)
                           (ui-event-type event)
                           (type-of event)))
             (timer (gethash event-type timers))
             (max-timer (when max-wait (gethash event-type max-timers))))
        
        ;; Store the latest event of this type
        (setf (gethash event-type last-events) event)
        
        ;; Set up max-wait timer if needed
        (when (and max-wait (null max-timer))
          (setf (gethash event-type max-timers)
                (set-timer (cons event-type :max-wait)
                         (lambda ()
                           (let ((last-event (gethash event-type last-events)))
                             (funcall handler last-event)
                             (remhash event-type max-timers)))
                         max-wait)))
        
        ;; Call immediately if leading edge and first call
        (when (and leading (null timer))
          (funcall handler event))
        
        ;; Cancel existing timer if any
        (when timer
          (cancel-timer (cons event-type :debounce)))
        
        ;; Set new timer for trailing edge
        (when trailing
          (setf (gethash event-type timers)
                (set-timer (cons event-type :debounce)
                         (lambda ()
                           (let ((last-event (gethash event-type last-events)))
                             (funcall handler last-event))
                           (remhash event-type timers))
                         wait)))))))

(defun throttle-events (event-stream timeout handler &key leading trailing)
  "Create a throttled event processor for an event stream.
   
   Parameters:
   - EVENT-STREAM: A function that yields events (typically via closure)
   - TIMEOUT: The throttle interval in milliseconds
   - HANDLER: A function to call with throttled events
   - LEADING, TRAILING: See make-throttled-handler
   
   Returns a function that, when called, processes the event stream with throttling."
  
  (let ((throttled-handler (make-throttled-handler handler timeout 
                                                 :leading (or leading t) 
                                                 :trailing trailing)))
    (lambda ()
      (let ((event (funcall event-stream)))
        (when event
          (funcall throttled-handler event))))))

(defun debounce-events (event-stream wait handler &key leading trailing max-wait)
  "Create a debounced event processor for an event stream.
   
   Parameters:
   - EVENT-STREAM: A function that yields events (typically via closure)
   - WAIT: The debounce interval in milliseconds
   - HANDLER: A function to call with debounced events
   - LEADING, TRAILING, MAX-WAIT: See make-debounced-handler
   
   Returns a function that, when called, processes the event stream with debouncing."
  
  (let ((debounced-handler (make-debounced-handler handler wait 
                                                  :leading leading
                                                  :trailing (or trailing t) 
                                                  :max-wait max-wait)))
    (lambda ()
      (let ((event (funcall event-stream)))
        (when event
          (funcall debounced-handler event))))))

(defun combine-throttled-handlers (&rest handler-specs)
  "Combine multiple throttled event handlers into a single handler.
   
   Each element of HANDLER-SPECS is a list of the form:
   (event-type handler timeout &key leading trailing)
   
   Returns a function that dispatches events to the appropriate throttled handler
   based on the event type."
  
  (let ((handlers (make-hash-table :test 'eq)))
    ;; Create throttled handlers for each spec
    (loop for spec in handler-specs
          for event-type = (first spec)
          for handler = (second spec)
          for timeout = (third spec)
          for options = (cdddr spec)
          for leading = (getf options :leading t)
          for trailing = (getf options :trailing nil)
          do (setf (gethash event-type handlers)
                   (make-throttled-handler handler timeout 
                                         :leading leading 
                                         :trailing trailing)))
    
    ;; Return a dispatcher function
    (lambda (event)
      (let* ((type (if (typep event 'ui-event)
                     (ui-event-type event)
                     (type-of event)))
             (handler (gethash type handlers)))
        (when handler
          (funcall handler event))))))
