(uiop:define-package :clevelib.target
  (:use :cl)
  (:export :message-handler
    :handle-message
    :handler-id))

(in-package :clevelib.target)

(defclass message-handler ()
  ((id :accessor handler-id :initform (gensym) :documentation "A unique identifier for this target."))
  (:documentation "An event target is an object that can receive events. It may handle evens
          (of specific types) and may be connected to dispatching mechanisms, typically an
          event-event-translator. It is capable of managing its own listeners but will notify
          connected event-translators on registration to allow the event-translators carrying the information
          about the targets themselves."))

(defmethod handle-message ((target message-handler) message)
  "Handle MESSAGE. This method is called by the event-event-translator when a message is received.
          Arguments:
          TARGET - the event target
          MESSAGE - the message
          Return value: nil
          Side effects: the message is handled"
  (declare (ignore  message))
  (error "handle-message not implemented for ~a" target))



;; (defmethod add-handler ( event-target event-type  handler)
;;   "Add a handler for EVENT-TYPE. If event-translators are connected they are notified using their
;; stored registry function. The handler is stored in the target's handlers hash table
;; under the event type.
;;   Arguments:
;;     EVENT-TARGET - the event target
;;     EVENT-TYPE - the event type
;;     HANDLER - the handler function
;;   Return value: nil
;;   Side effects: the handler is added to the target and the event-translators are notified
;;   Examples:
;;     (add-handler trget 'my-event
;;       (lambda (event)
;;         (format t \"i, target ~a, do something clever with ~a %\"
;;           (event-target event)
;;           (event-data event))))"
;;   (let* ((handlers (or (target-handlers event-target)
;;                      (make-hash-table :test #'equal)))
;;           (handler-list (unless (and (gethash event-type handlers) (member handler (gethash event-type handlers)))
;;                           (concatenate 'list (gethash event-type handlers) ;; add
;;                             (list handler)))))
;;     (setf (gethash event-type handlers) handler-list)
;;     (dolist (modfun (target-event-translators event-target))
;;       (funcall modfun event-type handler))))

;; (defmethod connect-target (translator event-target )
;;   "Register EVENT-TARGET as potential handler and targets for events. Passes a handle
;;           to EVENT-TARGET that allows registering handlers on specific (type
;;           priority) pairs. The EVENT-TARGET will register itself with the
;;           EVENT-SINK. The EVENT-SINK will then be able to call the EVENT-TARGET
;;           with the correct arguments. The EVENT-SINK is added to the
;;           EVENT-TARGET's list of event-translators SINKS.
;;           Arguments:
;;           SINK - the event event-translator
;;           EVENT-TARGET - the event target
;;           Return value: nil
;;           Side effects: the EVENT-TARGET is added to the EVENT-SINK's list of
;;           targets and the EVENT-SINK is added to the EVENT-TARGET's list of
;;           event-translators"
;;   (let ((mod-fun
;;           (lambda (event-type handler)
;;             (let* ((handlers (or (gethash
;;                                    (target-id event-target) (event-translator-handlers event-translator) )
;;                                (make-hash-table :test #'equal)))
;;                     (handler-list
;;                       (if (and (gethash event-type handlers)
;;                             (member handler (gethash event-type handlers)))
;;                         (remove handler (gethash event-type handlers)) ;; remove
;;                         (concatenate 'list (gethash event-type handlers) ;; add
;;                           (list handler)))))
;;               (setf (gethash event-type handlers) handler-list)))))
;;     (setf (gethash (target-id event-target)
;;             (event-translator-handlers event-translator))
;;       (target-handlers event-target))
;;     (push mod-fun (target-event-translators event-target))))
