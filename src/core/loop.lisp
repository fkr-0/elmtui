;;;===============================================================
;;; File: src/core/loop.lisp
;;; Event Loop & Dispatcher (using clevelib)
(uiop:define-package :elmtui.core.loop
  (:use :cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-warn) ; Added log4cl
  (:import-from :elmtui.core.globals
   :*event-loop* :*subscribers*)
  (:import-from :elmtui.core.conditions
   :subscriber-handler-error :event-loop-dispatch-error)
  (:import-from :cleve-elm.message
   :message-type)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key)
  (:import-from :cleve-elm.event-loop
   :event-loop :make-event-loop :run-loop :stop-loop :event-loop-active-p
                :enqueue-event :i-queue :o-queue)
  (:import-from :cleve-elm.channel
   :make-channel :channel-send :channel-receive :channel-close)
  (:export :start-loop
   :enqueue-event
           :dispatch-event
   :subscribe-with-priority
           :elm-stop-loop :unsubscribe
           :subscribe :publish
           :*lifecycle-hooks*
   :*event-loop* :*subscribers*
   :instrument-event-loop :elm-event-loop-active-p))
(in-package :elmtui.core.loop)


(defun start-loop (&key (fps 60) (wait t))
  "Initialize and start the main event loop. Supports instrumentation."
  (unless *event-loop*
    (setf *event-loop*
          (make-instance 'cleve-elm.event-loop:event-loop
                         :wait wait ; Pass the wait hint to clevelib's make-instance
                         :fps fps
                         :loop-fun #'dispatch-event))
    ;; Set the global app sender to this package's publish function
    ;; This should only happen once when the loop is first created.
    (setf elmtui.core.globals:*app-sender* #'publish)
    (log:info "LOOP: *app-sender* set to #'elmtui.core.loop:publish"))
  (if wait
      (run-loop *event-loop*) ; Blocking call
      (progn
        (log:info "LOOP: Starting event loop in a new thread (wait=NIL).")
        (bt:make-thread (lambda () (run-loop *event-loop*))
                        :name "elmtui-event-loop")))) ; Non-blocking call

(defun elm-stop-loop ()
  "Gracefully stop the main event loop."
  (when *event-loop*
    (cleve-elm.event-loop:stop-loop *event-loop*) ; Call the correct stop-loop
    (setf *event-loop* nil)))

(defun subscribe (event-type handler-fn)
  "Subscribe HANDLER-FN to events of type EVENT-TYPE.
   Returns a token that can be used to unsubscribe later.
   If handler-fn is NIL, signals an error."
  (unless handler-fn
    (error "Handler function cannot be NIL when subscribing to event-type ~S" event-type))
  
  ;; Get existing handlers for this event type
  (let ((handlers (gethash event-type *subscribers*)))
    ;; Add the new handler
    (push handler-fn handlers)
    ;; Update the subscribers hash
    (setf (gethash event-type *subscribers*) handlers)
    ;; Return a token for unsubscribe
    (list :event-type event-type :handler handler-fn :token (gensym "SUB-"))))

(defun unsubscribe (token)
  "Unsubscribe a handler using TOKEN returned from subscribe.
   Returns T if successfully unsubscribed, NIL otherwise."
  (when (and (listp token)
             (getf token :event-type)
             (getf token :handler))
    (let* ((event-type (getf token :event-type))
           (handler-to-remove (getf token :handler))
           (current-handlers (gethash event-type *subscribers*)))
      (when (member handler-to-remove current-handlers :test #'eq) ; Ensure handler is present
        (setf (gethash event-type *subscribers*)
              (remove handler-to-remove current-handlers :test #'eq :count 1)) ; Remove only one instance
        t)))) ; Return T indicating successful removal

(defun publish (event)
  "Publish EVENT to all subscribers of its type. Handles subscriber-handler-error."
  ;; Determine event type based on event structure
  (let* ((event-key (cond
                      ((typep event 'cleve-elm.message:message)
                       (cleve-elm.message:message-type event))
                      ((typep event 'key-event)
                       (key-event-key event))
                      ((listp event)
                       (first event))
                      (t
                       (warn "Publishing an event of unknown structure: ~S" event)
                       nil))) ; Fallback for unknown structures
         (handlers (when event-key (gethash event-key *subscribers*)))
         (generic-key-event-handlers (when (typep event 'key-event)
                                       (gethash :key-event *subscribers*)))
         (all-handlers (remove-duplicates (append handlers generic-key-event-handlers) :test #'eq)))
    (when event-key ; Proceed only if a valid event key was determined
      (if all-handlers
          (dolist (handler all-handlers)
            (log:debug "LOOP: Publishing to handler ~S event ~S (Event Key(s): ~A~@[, :KEY-EVENT~])"
                       handler event event-key (typep event 'key-event))
            ;; (elmtui.core.conditions:with-recovery (elmtui.core.conditions:subscriber-handler-error)
            ;;   (handler-case
            (funcall handler event)) ; Pass the original event to the handler
          ;; (error (e)
          ;;   (log:error "LOOP: Error in handler ~S for event ~S. Reason: ~A" handler event e)
          ;;   (signal 'elmtui.core.conditions:subscriber-handler-error
          ;;           :event event
          ;;           :handler handler
          ;;           :reason e)))))
          (log:debug "LOOP: No handlers found for event key ~S (and not a generic key-event or no generic handlers) (Event: ~S)" event-key event)))))

(defun dispatch-event (event)
  "Dispatch EVENT to subscribers and perform instrumentation. Handles event-loop-dispatch-error."
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:event-loop-dispatch-error)
    (handler-case
        (progn
          (publish event)
          (instrument-event-loop event))
      (error (e)
        (signal 'elmtui.core.conditions:event-loop-dispatch-error
                :event event
                :reason e)))))

(defvar *event-loop-instrumentation-hooks* nil
  "Stub: List of instrumentation hook functions for event loop metrics/tracing.")

(defun instrument-event-loop (event)
  "Instrumentation hook for debugging/profiling. Extend with hooks for timing/metrics."
  ;; (format t "[event-loop] Dispatched event: ~A~%" event)
  (dolist (hook *event-loop-instrumentation-hooks*)
    (funcall hook event)))

(defvar *subscribers* (make-hash-table :test 'equal)
  "Hash table mapping event types to lists of subscriber handlers.
   Each handler is a function that takes an event as its argument.")

(defvar *lifecycle-hooks* nil
  "List of lifecycle hooks for the event loop. These are functions that will be called
   at various points in the event loop's lifecycle, such as startup and shutdown.")

(defun elm-event-loop-active-p ()
  "Return T if the event loop is active."
  (and *event-loop* (cleve-elm.event-loop:event-loop-active-p *event-loop*)))

(defun subscribe-with-priority (event-type handler priority)
  "Subscribe to EVENT-TYPE with HANDLER, setting its PRIORITY.
Higher priority handlers run before lower priority ones.
Returns a token that can be used to unsubscribe."
  (let ((token (list :event-type event-type :handler handler)))
    (push (list handler priority token) (gethash event-type *subscribers* nil))
    ;; Sort handlers by priority (high to low)
    (setf (gethash event-type *subscribers*)
          (sort (gethash event-type *subscribers*) #'> :key #'second))
    token))

;;; USAGE EXAMPLES:
;; (start-loop :fps 30)
;; (subscribe :my-event #'(lambda (e) (print e)))
;; (publish (make-instance 'cleve-elm.event:event :event-type :my-event :data 42))
;; (stop-loop)

;;; CONTRACTS:
;; - All events are dispatched to registered subscribers by event-type.
;; - Event loop supports graceful shutdown and instrumentation.
;; - Subscribers can be added/removed dynamically.
