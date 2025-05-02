(uiop:define-package :clevelib.event
  (:use :cl :log4cl)
  (:import-from :clevelib.api :event-type)
  (:export :event
    :emission-time
    :make-event
    :key
    :sigint
    :sigquit
    :event-source
    :event-data
    :event-priority
    :name
    :event
    :resize)
  ;; (:import-from :clevelib.message
  ;;   :event-message
  ;;   :message-type
  ;;   :payload :sender
  ;;   :message
  ;;   :make-message :defmessage)
  )

(in-package :clevelib.event)

(defclass event ()
  ((name :initarg :name :accessor name)
    (event-type :initarg :event-type :accessor event-type :initform nil)
    (data :initarg :data :accessor event-data :initform nil)
    (priority :initarg :priority :accessor event-priority)
    (emission-time :initarg :time :accessor emission-time)
    (source :initarg :source :accessor event-source))
  (:documentation "An event is a message that is sent to a node.
 It contains a name, a type, a data field, a priority, a time, and a source."))



(defmethod print-object ((event event) stream)
  (print-unreadable-object (event stream :type t :identity t)
    (format stream "Event[~a|~a]>"
      (if (slot-boundp event 'event-type)(event-type event)
        "Unknown")
      (if (slot-boundp event 'emission-time)(emission-time event)
        "Unknown"))))


;; A macro to generate subclasses of the event class


(defun make-event (event-type &rest args)
  "Create an event instance, using either the base class or a subclass if it exists.
The event-type argument is a symbol naming the event class to create. The remaining
arguments are passed to the event class constructor.
If the event-type is not a valid class name, an instance of the base event class is
created.
  Arguments:
    event-type - The type of event to create.
    args - The arguments to pass to the event constructor.
  Returns:
    An instance of the event class or the specified subclass.
  Example:
    (make-event 'my-event :data \"Subclass event\" :extra-data \"Extra data\")
    (make-event 'event :data \"Base event\")"
  (let ((event-type (intern (string-upcase (symbol-name event-type)) 'keyword)))
    ;; (log-debug "Creating event of type ~a with args ~a. find class: ~a" event-type args
    ;;   (find-class event-type nil))
    (if (find-class event-type nil)
      (apply #'make-instance event-type
        (append args (list :event-type event-type)))
      (apply #'make-instance 'event
        (append (list :event-type event-type :time
                  (get-universal-time))
          args)))))



;; (make-event 'event :data "Base event")
;; (make-event 'key-event :data "Base event")
;; ;; Example usage
;; (defevent my-event ((extra-data :accessor my-event-extra-data :initarg :extra-data)))

;; ;; Create an instance of the base event class
;; (let ((e1 (make-event 'event :data "Base event")))
;;   (format t "Event Data: ~A~%" (event-data e1)))

;; ;; Create an instance of the my-event subclass
;; (let ((e2 (make-event 'my-event :data "Subclass event" :extra-data "Extra data")))
;;   (format t "Event Data: ~A, Extra Data: ~A~%" (event-data e2) (my-event-extra-data e2)))

;; (make-event 'dud :data "dud")
;; (defevent key
;;   ((key-sequence :accessor key-event-sequence :initarg :data)))
;; (defevent sigint
;;   ((key-sequence :accessor sigint-event-key-sequence :initarg :data)))
;; (defevent sigquit
;;   ((key-sequence :accessor sigquit-event-key-sequence :initarg :data)))
;; (defevent resize
;;   ((new-size :accessor resize-event-key-sequence :initarg :data)))

;; (defvar z (make-instance 'key-event :key-sequence "C-x C-c"))
;; (defvar aa (make-event 'key-event :key-sequence "C-x C-c" :target nil :data nil))
;; (defvar zzzz (make-event 'wurst-event :target nil :data nil))
;; (defvar ab (make-event 'wurst-event :target nil :data nil))
