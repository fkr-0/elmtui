(uiop:define-package :cleve-elm.message
  (:use :cl :log4cl)
  (:import-from :cleve-elm.api
   :async-exec
                :propagation-stopped-p
   :broadcast-p
                :capture-p
   :bubble-p
                :target-messengers
   :set-target-messengers
                :event-type
   :respond)
  (:import-from :cleve-elm.event
   :emission-time
                :event-source
   :event-data
                :translate
   :event)
  (:export :message
   :message-data
           :message
   :event-message
           :make-message
   :new-message
           :message-signal-state
   :message-state
           :message-data
   :message-target
           :message-bubbles-p
   :message-captures-p
           :message-path
   :async-handler
           :async
   :message-process-condition
           :illegal-state-condition
   :message-state-condition
           :reenqueue-handle
   :message-type
           :message-at-target-p
   :stop-propagation
           :update-phase
   :exec-async
           :re-enqueue
   :has-slot-p
           :event-message-event
   :event-message
           :message
   :print-object
           :initialize-instance
   :message-priority
   :priority-message
   :urgent-message
   :standard-priority
   :high-priority
   :urgent-priority))

(in-package :cleve-elm.message)

;; Define message priority constants
(defconstant standard-priority 0 "Standard message priority")
(defconstant high-priority 1 "High priority for important messages")
(defconstant urgent-priority 2 "Urgent priority for critical messages")

(defparameter *message-states* '(:new
                                 :at-target
                                 :capture
                                 :broadcast
                                 :bubble
                                 :stopped
                                 :done
                                 :error)
  "List of states that a message can be in. Setting a message to a state not in
this list will signal ILLEGAL-STATE condition.
        :new - The message is created.
        :stopped - The propagation of the message is stopped.
        :capturing - The message is propagating to the target actor.
        :at-target - The message is processed by the target actor.
        :bubbling - The message is propagating back to the root actor.
        :done - The message is processed.
        :error - The message is processed and the target actor is done with it, but
          an error occurred during processing.")

;;; Define the Message Conditions
;; if illegal state is set, signal error
(define-condition message-state-condition (error)
  ((message :initarg :message :reader message :documentation "The message that caused the error.")
   (state :initarg :state :reader state :documentation "The state that caused the error."))
  (:documentation "Condition to signal about problematic message state. When setting the state of a message,
if the new state is in the messages signal-states member, this condition is signaled carrying the problematic STATE and MESSAGE as
condition slots."))

;; if processing a message fails, signal error
(define-condition message-process-condition (error)
  ((message :initarg :message :reader message :documentation "The message that caused the error.")))

(define-condition illegal-state-condition (error)
  ((message :initarg :message :reader message :documentation "The message that caused the error.")
   (state :initarg :state :reader state :documentation "The illegal state that caused the error."))
  (:documentation "Condition to signal error of illegal message state. When setf-ing the state of a message,
this condition is signaled if the new state is not in *message-states*. The
condition carries the signaling message and the illegal state as MESSAGE and
STATE slots, respectively."))

(defclass message ()
  ((id :initarg :id :accessor id :initform (gensym) :documentation "The unique identifier of the message.")
   (target :initform nil
           :accessor message-target
           :initarg :target :documentation "The target of the message.
Either a special keyword or an instance of component.")
   (signal-states :initarg :signal-states :initform (list :error)
                  :accessor message-signal-state
                  :documentation "List of states that should signal an error if set.")
   (bubbles-p :initform t
              :accessor message-bubbles-p
              :initarg :bubbles-p :documentation "Whether the message should bubble up to the parent.")
   (captures-p :initform nil
               :accessor message-captures-p
               :initarg :captures-p :documentation "Whether the message should be captured by the parent.")
   (sender :initarg :sender :accessor sender :initform nil)
   (state :initarg :state :initform :new :accessor message-state :documentation "The current state of the message.
     The message-state is used to inform of the processing/propagation of the
      message. The default message-phase is :new. Message states are defined in *message-states*.")
   (message-type :initarg :message-type :accessor message-type)
   (data :initarg :message-data :accessor message-data :initform nil
         :documentation "The data of the message. The data is used to carry information from the sender to the target actor.")
   (timestamp :initarg :timestamp
              :accessor timestamp)
   (priority :initarg :priority :accessor message-priority :initform standard-priority
            :documentation "The priority of the message. Higher priority messages are processed before lower priority ones.")
   (async-handle :initarg :async-handler
                 :accessor async-handle)
   (reenqueue-handle :initarg :reenqueue-handler :accessor reenqueue-handle))
  (:documentation "A message is a unit of communication between two actors."))

;; Create specialized message classes for different priority levels
(defclass priority-message (message)
  ()
  (:default-initargs :priority high-priority)
  (:documentation "A high priority message that should be processed before standard messages"))

(defclass urgent-message (message)
  ()
  (:default-initargs :priority urgent-priority)
  (:documentation "An urgent message that should be processed immediately"))

(defmethod message-type((m message) )
  (ecase (type-of (slot-value m 'message-type))
    ((null) (type-of m))
    (symbol (intern (string-upcase (symbol-name (slot-value m 'message-type))) 'keyword))
    (keyword (intern (string-upcase (symbol-name (slot-value m 'message-type))) 'keyword))
    (t (slot-value m 'message-type))))

(defmethod target-messengers ((m message) &rest args)
  (declare (ignorable args))
  (message-target m))

(defmethod set-target-messengers ((m message) new-targets &rest args)
  (declare (ignorable args))
  (setf (message-target m ) new-targets))

(defmethod message-at-target-p ((m message) current-target)
  "Check if the message M is at the target given CURRENT-TARGET.
  Arguments:
    m - The message to check.
    current-target - The target to check against.
  Returns:
    T if the message is at the target or one of them, NIL otherwise."
  (if (listp (message-target m))
      (not (null (member current-target (message-target m))))
      (eq (message-target m) current-target)))

(defmethod broadcast-p ((m message) &rest args)
  "Check if the message is a broadcast message."
  (declare (ignorable args))
  ;; (setf (message-phase m) :broadcast)
  (or (eq (message-target m) :broadcast)
      (null (message-target m))))

(defmethod stop-propagation ((m message))
  "Stop the propagation of the given message."
  (setf (message-state m) :stopped))



(defmethod print-object ((m message) stream)
  (print-unreadable-object (m stream :type t :identity t)
    (format stream "|~A>"   (message-type m))))

(defun has-slot-p (prop)
  (member (if (listp prop) (first prop) prop)
          (mapcar (lambda (v) (slot-value v  'sb-pcl::name))
                  (sb-mop:class-slots (find-class 'message ) ))))

(defmethod initialize-instance :after ((m message) &key (message-type nil) (message-data nil))
  "Initialize the message instance. If the message-type is not given, the type of the message
is set to the class of the message instance. The timestamp is set to the current time."
  (if message-type
      (setf (message-type m) message-type)
      (setf (message-type m) (type-of m)))

  (setf (timestamp m) (get-universal-time))
  (log-debug "Initializing message ~a with type ~a" m message-type)
  (when message-data
    (setf (message-data m) message-data)))

(defclass event-message (message)
  ((event :initarg :event :accessor event-message-event))
  (:documentation "A message that is sent as a result of an event."))
(defmethod print-object ((m event-message) stream)
  (print-unreadable-object (m stream :type t :identity t)
    (format stream "|~A>" (message-type m))))

(defmethod initialize-instance :after ((m event-message) &key event (bubbles-p nil) (captures-p nil) (target :focus))
  (log-debug "Initializing event message ~a with event ~a" m event)
  (setf (message-type m) (event-type event))
  (setf (message-bubbles-p m) bubbles-p)
  (setf (message-captures-p m) captures-p)
  (setf (message-data m) (event-data event))
  (setf (message-target m) target))
;;   (setf (event-message-event m) event)
;;   (setf (timestamp m) (emission-time event))
;;   (setf (message-type m) (event-type event))
;;   (setf (sender m) (event-source event))
;;   (setf (message-data m) (event-data event)))

(defmethod propagation-stopped-p ((m message) &rest args)
  (declare (ignorable args))
  (eq (message-state m) :stopped))
(defmethod capture-p ((m message) &rest args)
  "Check if the message is a capture message."
  (declare (ignorable args))
  (message-captures-p m))
(defmethod bubble-p ((m message) &rest args)
  "Check if the message is a bubble message."
  (declare (ignorable args))
  (message-bubbles-p m))
;; (defun make-message (message-type &rest args)
;;   "Create an event message instance, using either the base class or a subclass if
;; it exists."
;;   (let ((message-type (intern (string-upcase (symbol-name message-type)))))
;;     (log-debug "Creating message of type ~a with args ~a. find class: ~a" message-type args
;;       (find-class message-type nil))
;;     (if (find-class message-type nil)
;;       (apply #'make-instance message-type
;;         (append args
;;           (list :message-type message-type)))
;;       (apply #'make-instance 'message
;;         (append (list :message-type message-type
;;                   :time (get-universal-time))
;;           args)))))

(defmethod  (setf message-state) :before  (new-state (message message))
  "Set the state of the MESSAGE to NEW-STATE."
  (if (member new-state *message-states*)
      (when (and (member new-state (message-signal-state message)) ;; should signal error
                 (not (eq new-state (message-state message)))) ;; state is not the same
        (signal 'message-state-condition :message message :state new-state))
      (error 'illegal-state-condition :message message :state new-state)))

(defun make-message (message-type message-data &rest args)
  "Create an message instance, using either the base class or a subclass if it exists.
The message-type argument is a symbol naming the message class to create. The remaining
arguments are passed to the message class constructor.
If the message-type is not a valid class name, an instance of the base message class is
created.
  Arguments:
    message-type - The type of message to create.
    args - The arguments to pass to the message constructor.
  Returns:
    An instance of the message class or the specified subclass.
  Example:
    (make-message 'my-message :data \"Subclass message\" :extra-data \"Extra data\")
    (make-message 'message :data \"Base message\")"
  (let ((message-type (intern (string-upcase (symbol-name message-type)))))
    (log-debug "Creating message of type ~a with args ~a. find class: ~a"
               message-type args (find-class message-type nil))
    (if (find-class message-type nil)
        (apply #'make-instance message-type
               (append args (list :message-type message-type
                                  :message-data message-data
                                  :priority (getf args :priority standard-priority)
                                  :timestamp (get-universal-time))))
        (apply #'make-instance 'message
               (append (list :message-type message-type
                             :message-data message-data
                             :priority (getf args :priority standard-priority)
                             :timestamp (get-universal-time))
                       args)))))

;; (defmethod propagation-stopped ((event event))
;;   "Stop the propagation of the given event."
;;   (eq (event-phase event) :stopped))

;; (defmethod stop-propagation ((event event))
;;   "Stop the propagation of the given event."
;;   (set-phase event :stopped))

(defmethod re-enqueue ((message message) m)
  "Enqueue a message"
  (if (reenqueue-handle message)
      (let ((handle (reenqueue-handle message)))
        (when handle
          (log-debug "Re-enqueueing message ~a" message)
          (funcall handle m)))
      (progn
        (log-debug "No re-enqueue handle for message ~a" message)
        (error "No re-enqueue handle for message ~a" message))))

(defmethod respond ((message message) m &rest args)
  (declare (ignorable args))
  (re-enqueue message m))

;; (defmethod exec-async ((message message))
;;   "Execute the message asynchronously. To allow async
;; tasks to be enqueued a relay passes an according async
;; handler to the message. This handler is called here.
;;   Arguments:
;;     message - The message carrying a async handler
;;   Returns:
;;     nil"
;;   (if (async-handle message)
;;     (let ((handle (async-handle message)))
;;       (when handle
;;         (log-debug "Executing async message ~a" message)
;;         (funcall handle message)))
;;     (log-debug "No async handle for message ~a" message)))
(defmethod async ((m message) task &rest args)
  (declare (ignorable args))
  (if (async-handle m)
      (let ((handle (async-handle m)))
        (when handle
          (log-debug "Executing async message ~a" m)
          (funcall handle task)))
      (log-debug "No async handle for message ~a" m)))

(defun new-message (message-data &key
                                   (id nil)
                                   (target nil)
                                   (sender nil)
                                   (m-type :generic)
                                   (message-state :new)
                                   (timestamp (get-universal-time)))
  (unless id (setf id (gensym)))
  (unless m-type (setf m-type :unknown))
  (unless message-state (setf message-state :new))
  (unless timestamp (setf timestamp (get-universal-time)))
  (make-instance 'message
                 :id id
                 :target target
                 :sender sender
                 :message-type m-type
                 :message-data message-data
                 :timestamp timestamp
                 :message-state message-state))


(defmacro defevent (name &rest slots)
  "Macro for defining event subclasses."
  `(progn
     (defclass ,name (event)
       ,@slots
       (:documentation ,(format nil "A ~A event class" name)))
     (defmethod print-object ((event ,name) stream)
       (print-unreadable-object (event stream :type t :identity t)
         (format stream "<EvClass:~a->[~a]>" ',name
                 (emission-time event))))
     (defmethod initialize-instance :after ((e ,name) &key)
       (setf (event-type e) ',name)
       (setf (event-priority e) 0)
       (setf (emission-time e) (get-universal-time)))
     (defclass ,(intern (format nil "~a-MESSAGE" (symbol-name name)) :cleve-elm.message) (event-message)
       ,@slots (:documentation ,(format nil "A ~A message class" name)))
     (defmethod translate (e ,name)
       (let ((mapped (make-instance ',(intern (format nil "~a-MESSAGE" (symbol-name name)) :cleve-elm.message)
                                    :message-data (event-data e)
                                    :type (event-type e)
                                    :sender (source e)
                                    :emission-time (emission-time e))))
         (setf (event-priority mapped) (event-priority e))
         (setf (emission-time mapped) (emission-time e))
         mapped))
     (defmethod initialize-instance :after ((e ,(intern (format nil "~a-MESSAGE" (symbol-name name)))) &key)
       (setf (message-data e) (event-data e))
       (setf (message-type e) ',
             (intern (symbol-name name) 'keyword))
       (setf (event-priority e) 0))))

;; (defevent key
;;   ((key-sequence :accessor key-event-sequence :initarg :data)))
;; (defevent sigint
;;   ((key-sequence :accessor sigint-event-key-sequence :initarg :data)))
;; (defevent sigquit
;;   ((key-sequence :accessor sigquit-event-key-sequence :initarg :data)))
;; (defevent resize
;;   ((new-size :accessor resize-event-key-sequence :initarg :data)))
