(uiop:define-package :clevelib.translator
  (:use :cl :log4cl)
  (:import-from :clevelib.event
    :event
    :event-message)
  (:export :translate
    :no-translate-method
    :no-translate-method-event))

(in-package :clevelib.translator)


;; (defclass translator () ())

(defgeneric translate (event event-type)
  (:method ((event event) e)
    (log-debug "Default Event-Translator ~A" event)
    (let ((m (make-instance 'event-message :event event)))
      ;; (when (slot-boundp event 'event-type)
      ;;   (setf (message-type m) (slot-value event 'event-type)))
      ;; (when (slot-boundp event 'source)
      ;;   (setf (sender m) (slot-value event 'source)))
      m))
  (:documentation "Translate an event into a higher-level event."))

(define-condition no-translate-method (error)
  ((event :initarg :event :reader no-translate-method-event))
  (:report (lambda (c s)
             (format s "No translate method defined for event ~S"
               (no-translate-method-event c)))))

(defmethod translate ((event t) (event-type t))
  (error 'no-translate-method :event event))

;; (defmethod translate ((event event) (event-type (eql :key)))
;;   (log-debug "Translating key event ~A" event)
;;   (new-message event ;; :key
;;     ;; (list 'state 2)
;;     ))

;; (defmethod translate ((event event) (event-type (eql :resize)))
;;   (log-debug "Translating key event ~A" event)
;;   (new-message event))

;; (defmethod translate ((event event) (event-type (eql :resize)))
;;   (log-debug "Translating key event ~A" event)
;;   (new-message event))
