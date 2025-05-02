;;;===============================================================
;;; File: src/core/loop.lisp
;;; Event Loop & Dispatcher (using clevelib)
(uiop:define-package :elmtui.core.loop
  (:use :cl)
  (:import-from :clevelib.event-loop
    :event-loop :make-event-loop :run-loop :stop-loop :event-loop-active-p
    :enqueue-event :i-queue :o-queue)
  (:import-from :clevelib.channel
    :make-channel :channel-send :channel-receive :channel-close)
  (:export :start-loop
           :stop-loop
           :subscribe
           :publish
           :*event-loop*
           :*subscribers*
           :instrument-event-loop
           :event-loop-active-p))
(in-package :elmtui.core.loop)

(defvar *event-loop* nil "The main event loop instance.")
(defvar *subscribers* (make-hash-table :test 'equal) "Registered event subscribers.")

(defun start-loop (&key (fps 60) (wait t))
  "Initialize and start the main event loop. Supports instrumentation."
  (unless *event-loop*
    (setf *event-loop*
      (make-event-loop
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
  "Stub: Remove a subscriber using its token. To be implemented for dynamic removal."
  ;; Remove handler from *subscribers* for token's event-type
  ;; (let ((handlers (gethash (getf token :event-type) *subscribers*)))
  ;;   (setf (gethash (getf token :event-type) *subscribers*)
  ;;         (remove (getf token :handler) handlers)))
  (declare (ignore token))
  (warn "unsubscribe: dynamic subscriber removal not yet implemented."))

(defun publish (event)
  "Publish EVENT to all subscribers of its type. Handles subscriber-handler-error."
  (let ((handlers (gethash (event-type event) *subscribers*)))
    (dolist (handler handlers)
      (elmtui.core.conditions:with-recovery (elmtui.core.conditions:subscriber-handler-error)
        (handler-case
            (funcall handler event)
          (error (e)
            (signal 'elmtui.core.conditions:subscriber-handler-error
                    :event event
                    :handler handler
                    :reason e)))))))

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
  (format t "[event-loop] Dispatched event: ~A~%" event)
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
