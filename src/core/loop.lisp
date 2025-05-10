;;;===============================================================
;;; File: src/core/loop.lisp
;;; Event Loop & Dispatcher (using clevelib)
(uiop:define-package :elmtui.core.loop
  (:use :cl)
  (:import-from :elmtui.core.globals
   :*event-loop* :*subscribers*)
  (:import-from :elmtui.core.conditions
   :subscriber-handler-error :event-loop-dispatch-error)
  (:import-from :clevelib.message
   :message-type)
  (:import-from :elmtui.core.input-events
                #:key-event #:key-event-key)
  (:import-from :clevelib.event-loop
   :event-loop :make-event-loop :run-loop :stop-loop :event-loop-active-p
                :enqueue-event :i-queue :o-queue)
  (:import-from :clevelib.channel
   :make-channel :channel-send :channel-receive :channel-close)
  (:export :start-loop
   :enqueue-event
           :stop-loop :unsubscribe
           :subscribe :publish
           :*event-loop* :*subscribers*
           :instrument-event-loop :event-loop-active-p))
(in-package :elmtui.core.loop)


(defun start-loop (&key (fps 60) (wait t))
  "Initialize and start the main event loop. Supports instrumentation."
  (unless *event-loop*
    (setf *event-loop*
          (make-instance 'clevelib.event-loop:event-loop
                         :wait wait
                         :fps fps
                         :loop-fun #'dispatch-event)))
  (run-loop *event-loop*))

(defun stop-loop ()
  "Gracefully stop the main event loop."
  (when *event-loop*
    (stop-loop *event-loop*)
    (setf *event-loop* nil)))

(defun subscribe (event-type handler)
  "Register HANDLER for EVENT-TYPE. Returns a token for unsubscription."
  (push handler (gethash event-type *subscribers*))
  ;; Token-based for future dynamic removal
  (list :event-type event-type :handler handler :token (gensym "SUB-")))

(defun unsubscribe (token)
  "Remove a subscriber using its token.
   TOKEN is a list like (:EVENT-TYPE type :HANDLER handler-fn :TOKEN unique-symbol).
   Returns T if a handler was removed, NIL otherwise."
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
                      ((typep event 'clevelib.message:message)
                       (clevelib.message:message-type event))
                      ((typep event 'key-event)
                       (key-event-key event))
                      ((listp event)
                       (first event))
                      (t
                       (warn "Publishing an event of unknown structure: ~S" event)
                       nil))) ; Fallback for unknown structures
         (handlers (when event-key (gethash event-key *subscribers*))))
    (when event-key ; Proceed only if a valid event key was determined
      (dolist (handler handlers)
        (elmtui.core.conditions:with-recovery (elmtui.core.conditions:subscriber-handler-error)
          (handler-case
              (funcall handler event) ; Pass the original event to the handler
            (error (e)
              (signal 'elmtui.core.conditions:subscriber-handler-error
                      :event event
                      :handler handler
                      :reason e))))))))

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

(defun event-loop-active-p ()
  "Return T if the event loop is active."
  (and *event-loop* (event-loop-active-p *event-loop*)))

;;; USAGE EXAMPLES:
;; (start-loop :fps 30)
;; (subscribe :my-event #'(lambda (e) (print e)))
;; (publish (make-instance 'clevelib.event:event :event-type :my-event :data 42))
;; (stop-loop)

;;; CONTRACTS:
;; - All events are dispatched to registered subscribers by event-type.
;; - Event loop supports graceful shutdown and instrumentation.
;; - Subscribers can be added/removed dynamically.
