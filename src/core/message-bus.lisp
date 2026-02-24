;; src/core/message-bus.lisp
;; Central message dispatcher with priority support

(uiop:define-package :elmtui.core.message-bus
  (:nicknames :cleve-elm.core.message-bus)
  (:use :cl :log4cl)
  (:import-from :cl-events.channel
   :make-channel :-> :<- :select)
  (:import-from :cl-events.types
   :message :message-type)
  (:import-from :bordeaux-threads
   :make-thread)
  (:import-from :elmtui.core.event-channels
   :event-channel :send-event :receive-event)
  (:export :message-bus
   :make-message-bus
           :register-channel
   :unregister-channel
           :add-routing-rule
   :remove-routing-rule
           :get-channel-by-name
   :dispatch-message
           :start-message-bus
   :stop-message-bus
           :with-message-priority
   :routing-rule))

(in-package :elmtui.core.message-bus)

(defvar *current-message-priority* :normal
  "Dynamic variable to set the priority for messages sent within its scope")

(defclass routing-rule ()
  ((source-type :accessor source-type :initarg :source-type :documentation "Source message type")
   (target-channel :accessor target-channel :initarg :target-channel :documentation "Target channel name")
   (transform-fn :accessor transform-fn :initarg :transform :initform nil :documentation "Optional transformation function")
   (condition-fn :accessor condition-fn :initarg :condition :initform nil :documentation "Optional condition function"))
  (:documentation "Rule for routing messages from a source type to a target channel"))

(defclass message-bus ()
  ((input-channel :accessor input-channel :initform (make-channel) :documentation "Main input channel for the message bus")
   (channels :accessor channels :initform (make-hash-table :test 'eq) :documentation "Registry of named channels")
   (routing-rules :accessor routing-rules :initform nil :documentation "List of routing rules")
   (active :accessor active-p :initform nil :documentation "Whether the message bus is active")
   (thread :accessor thread :initform nil :documentation "Message processing thread"))
  (:documentation "Central dispatcher for messages between channels"))

(defun make-message-bus ()
  "Create a new message bus"
  (make-instance 'message-bus))

(defun register-channel (bus name channel)
  "Register a channel with the message bus"
  (setf (gethash name (channels bus)) channel)
  bus)

(defun unregister-channel (bus name)
  "Unregister a channel from the message bus"
  (remhash name (channels bus))
  bus)

(defun add-routing-rule (bus source-type target-channel &key transform condition)
  "Add a routing rule to the message bus"
  (let ((rule (make-instance 'routing-rule
                             :source-type source-type
                             :target-channel target-channel
                             :transform transform
                             :condition condition)))
    (push rule (routing-rules bus))
    rule))

(defun remove-routing-rule (bus source-type target-channel)
  "Remove a routing rule from the message bus"
  (setf (routing-rules bus)
        (remove-if (lambda (rule)
                     (and (eq (source-type rule) source-type)
                          (eq (target-channel rule) target-channel)))
                   (routing-rules bus)))
  bus)

(defun get-channel-by-name (bus name)
  "Get a channel by name from the message bus"
  (gethash name (channels bus)))

(defun message-type-of (message)
  "Extract a routing type from MESSAGE."
  (typecase message
    (message (message-type message))
    (keyword message)
    (symbol (intern (string-upcase (symbol-name message)) :keyword))
    (cons (or (getf message :type)
              (getf message :message-type)
              (first message)))
    (t (type-of message))))

(defun apply-routing-rules (bus message)
  "Apply routing rules to a message"
  (let ((message-type (message-type-of message)))
    (dolist (rule (routing-rules bus))
      (when (eq (source-type rule) message-type)
        (let ((target (get-channel-by-name bus (target-channel rule))))
          (when target
            (let ((should-route t))
              ;; Apply condition if present
              (when (condition-fn rule)
                (setf should-route (funcall (condition-fn rule) message)))
              
              ;; Route the message if condition passed
              (when should-route
                (let ((routed-message message))
                  ;; Apply transformation if present
                  (when (transform-fn rule)
                    (setf routed-message (funcall (transform-fn rule) message)))
                  
                  ;; Send to target channel
                  (send-event target routed-message)))))))))
  
  ;; Always return the message for further processing
  message)

(defun dispatch-message (bus message)
  "Dispatch a message through the message bus"
  (-> (input-channel bus) message)
  message)

(defun process-messages (bus)
  "Process messages from the input channel"
  (loop while (active-p bus) do
    (let ((message (<- (input-channel bus))))
      (log-debug "Processing message: ~A" message)
      (apply-routing-rules bus message))))

(defun start-message-bus (bus)
  "Start the message bus processing thread"
  (unless (active-p bus)
    (setf (active-p bus) t)
    (setf (thread bus)
          (make-thread (lambda () (process-messages bus))
                       :name "elmtui-message-bus"))
    t))

(defun stop-message-bus (bus)
  "Stop the message bus processing thread"
  (when (active-p bus)
    (setf (active-p bus) nil)
    ;; Additional cleanup would go here
    t))

(defmacro with-message-priority ((priority) &body body)
  "Execute body with the specified message priority"
  `(let ((*current-message-priority* ,priority))
     ,@body))
