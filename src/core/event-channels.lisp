;; src/core/event-channels.lisp
;; Enhanced definition of standard event channel types with filtering and priority support

(uiop:define-package :cleve-elm.core.event-channels
  (:nicknames :elmtui.core.event-channels)
  (:use :cl :log4cl)
  (:import-from :cleve-elm.channel
   :make-channel :make-filtered-channel :channel-add-filter :-> :<- :select)
  (:import-from :cleve-elm.queue
   :make-priority-queue)
  (:export :make-keyboard-channel
   :make-mouse-channel
           :make-system-channel
   :make-ui-channel
           :make-focus-channel
   :make-command-channel
           :make-message-channel
   :standard-event-channels
           :event-channel
   :keyboard-channel
           :mouse-channel
   :system-channel
           :ui-channel
   :command-channel
           :focus-channel
   :message-channel
           :register-event-handler
   :unregister-event-handler
           :send-event
   :receive-event
           :event-type-p
           ;; New exports for enhanced system
   :channel-priority
           :set-channel-priority
   :add-event-filter
           :remove-event-filter
   :select-from-channels
           :wait-for-event
   :try-receive-event))

(in-package :cleve-elm.core.event-channels)

;; Define event channel types with priority support
(defclass event-channel ()
  ((channel :accessor channel-of :initform (make-channel) :documentation "The underlying channel")
   (priority :accessor priority :initarg :priority :initform :normal 
             :type (member :high :normal :low) :documentation "Channel priority")
   (filters :accessor filters :initform nil :type list :documentation "List of event filters")
   (handlers :accessor handlers :initform nil :type list :documentation "List of event handlers")
   (name :accessor name :initarg :name :initform nil :type symbol :documentation "Name of the channel"))
  (:documentation "Base class for event channels with priority support"))

;; Implement channel sub-types with priority support
(defclass keyboard-channel (event-channel)
  ()
  (:default-initargs :name :keyboard :priority :high)
  (:documentation "Channel for keyboard events"))

(defclass mouse-channel (event-channel)
  ()
  (:default-initargs :name :mouse :priority :normal)
  (:documentation "Channel for mouse events"))

(defclass system-channel (event-channel)
  ()
  (:default-initargs :name :system :priority :high)
  (:documentation "Channel for system events"))

(defclass ui-channel (event-channel)
  ()
  (:default-initargs :name :ui :priority :normal)
  (:documentation "Channel for UI events"))

(defclass command-channel (event-channel)
  ()
  (:default-initargs :name :command :priority :high)
  (:documentation "Channel for command events"))

(defclass focus-channel (event-channel)
  ()
  (:default-initargs :name :focus :priority :high)
  (:documentation "Channel for focus events"))

(defclass message-channel (event-channel)
  ()
  (:default-initargs :name :message :priority :normal)
  (:documentation "Channel for general messages"))

;; Enhanced factory functions with priority and filtering support
(defun make-keyboard-channel (&key (priority :high) (filters nil))
  "Create a new keyboard event channel with specified priority and filters"
  (let ((channel (make-instance 'keyboard-channel :priority priority)))
    (when filters
      (setf (filters channel) filters)
      (setf (channel-of channel) (make-filtered-channel :filters filters)))
    channel))

(defun make-mouse-channel (&key (priority :normal) (filters nil))
  "Create a new mouse event channel with specified priority and filters"
  (let ((channel (make-instance 'mouse-channel :priority priority)))
    (when filters
      (setf (filters channel) filters)
      (setf (channel-of channel) (make-filtered-channel :filters filters)))
    channel))

(defun make-system-channel (&key (priority :high) (filters nil))
  "Create a new system event channel with specified priority and filters"
  (let ((channel (make-instance 'system-channel :priority priority)))
    (when filters
      (setf (filters channel) filters)
      (setf (channel-of channel) (make-filtered-channel :filters filters)))
    channel))

(defun make-ui-channel (&key (priority :normal) (filters nil))
  "Create a new UI event channel with specified priority and filters"
  (let ((channel (make-instance 'ui-channel :priority priority)))
    (when filters
      (setf (filters channel) filters)
      (setf (channel-of channel) (make-filtered-channel :filters filters)))
    channel))

(defun make-focus-channel (&key (priority :high) (filters nil))
  "Create a new focus event channel with specified priority and filters"
  (let ((channel (make-instance 'focus-channel :priority priority)))
    (when filters
      (setf (filters channel) filters)
      (setf (channel-of channel) (make-filtered-channel :filters filters)))
    channel))

(defun make-command-channel (&key (priority :high) (filters nil))
  "Create a new command event channel with specified priority and filters"
  (let ((channel (make-instance 'command-channel :priority priority)))
    (when filters
      (setf (filters channel) filters)
      (setf (channel-of channel) (make-filtered-channel :filters filters)))
    channel))

(defun make-message-channel (&key (priority :normal) (filters nil))
  "Create a new general message channel with specified priority and filters"
  (let ((channel (make-instance 'message-channel :priority priority)))
    (when filters
      (setf (filters channel) filters)
      (setf (channel-of channel) (make-filtered-channel :filters filters)))
    channel))

;; Priority management
(defun channel-priority (event-channel)
  "Get the priority of an event channel"
  (priority event-channel))

(defun set-channel-priority (event-channel priority)
  "Set the priority of an event channel"
  (setf (priority event-channel) priority))

;; Filter management
(defun add-event-filter (event-channel filter-fn)
  "Add a filter function to an event channel"
  (push filter-fn (filters event-channel))
  (let ((current-channel (channel-of event-channel)))
    (setf (channel-of event-channel)
          (channel-add-filter current-channel filter-fn)))
  event-channel)

(defun remove-event-filter (event-channel filter-fn)
  "Remove a filter function from an event channel"
  (setf (filters event-channel) 
        (remove filter-fn (filters event-channel)))
  ;; Recreate the filtered channel with updated filters
  (setf (channel-of event-channel)
        (if (filters event-channel)
            (make-filtered-channel :filters (filters event-channel))
            (make-channel)))
  event-channel)

;; Event type checking
(defun event-type-p (event type)
  "Check if an event is of a specific type"
  (and (typep event 'cleve-elm.message:message)
       (eq (cleve-elm.message:message-type event) type)))

;; Handler management
(defun register-event-handler (event-channel handler-fn)
  "Register an event handler function with the channel"
  (push handler-fn (handlers event-channel))
  event-channel)

(defun unregister-event-handler (event-channel handler-fn)
  "Remove an event handler function from the channel"
  (setf (handlers event-channel) 
        (remove handler-fn (handlers event-channel)))
  event-channel)

;; Event sending/receiving
(defun send-event (event-channel event)
  "Send an event to the channel"
  (-> (channel-of event-channel) event))

(defun receive-event (event-channel)
  "Receive an event from the channel (blocking)"
  (<- (channel-of event-channel)))

(defun try-receive-event (event-channel &optional timeout)
  "Try to receive an event from the channel (non-blocking or with timeout)"
  ;; Implementation would depend on clevelib features
  (let ((result
          (select :timeout timeout
                  (receive-event event-channel)))) ; kj:timeout timeout
    (when result
      (second (first result)))))

;; Multi-channel selection
(defun select-from-channels (event-channels &key timeout)
  "Select an event from multiple channels based on priority"
  (let* (
         (result (select :timeout timeout
                         ;; The mapcar here might still be an issue for how 'select'
                         ;; expects individual operations, but this change fixes
                         ;; the :timeout parsing.
                         (mapcar #'receive-event
                                 event-channels) ;kjall-channels ;; :timeout timeout
                         )))
    (when result
      (destructuring-bind (channel value) (first result)
        ;; Find which event-channel this belongs to
        (let ((source-channel (find channel event-channels 
                                    :key #'channel-of :test #'eq)))
          (values value source-channel))))))

;; Wait for event with priority handling
(defun wait-for-event (event-channels)
  "Wait for an event from any channel, respecting priorities"
  ;; Sort channels by priority
  (let* ((sorted-channels 
           (sort (copy-seq event-channels)
                 (lambda (a b)
                   (let ((prio-a (priority a))
                         (prio-b (priority b)))
                     (cond
                       ((eq prio-a :high) t)
                       ((eq prio-b :high) nil)
                       ((eq prio-a :normal) t)
                       (t nil))))))
         (result (select-from-channels sorted-channels)))
    result))

(defun standard-event-channels ()
  "Create a standard set of event channels with proper priorities"
  (list (cons :keyboard (make-keyboard-channel :priority :high))
        (cons :mouse (make-mouse-channel :priority :normal))
        (cons :system (make-system-channel :priority :high))
        (cons :ui (make-ui-channel :priority :normal))
        (cons :command (make-command-channel :priority :high))
        (cons :focus (make-focus-channel :priority :high))
        (cons :message (make-message-channel :priority :normal))))
