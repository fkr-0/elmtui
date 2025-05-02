(uiop:define-package :clevelib.messaging
  (:use :cl :log4cl)
  (:import-from
    :clevelib.api
    :get-children
    :get-parent
    :broadcast-p
    :capture-p
    :bubble-p
    )
  (:import-from
    :clevelib.message
    :message
    )
  (:import-from
    :clevelib.ems
    :messenger
    :ems)
  (:export #:message
    #:propagation-entity
    #:add-child
    #:remove-children
    #:path-to
    #:propagate
    #:stop-propagation
    #:process
    #:illegal-state
    #:message-state
    #:message-process
    #:*message-states*))

;;;; Full Propagation Facility for Propagation-Supporting Types

(defparameter *message-states* '(:new
                                  :at-target
                                  :capturing
                                  :bubbling
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
(define-condition message-state (error)
  ((message :initarg :message :reader message :documentation "The message that caused the error.")
    (state :initarg :state :reader state :documentation "The state that caused the error."))
  (:documentation "Condition to signal about problematic message state. When setting the state of a message,
if the new state is in the messages signal-states member, this condition is signaled carrying the problematic STATE and MESSAGE as
condition slots."))

;; if processing a message fails, signal error
(define-condition message-process (error)
  ((message :initarg :message :reader message :documentation "The message that caused the error.")))

(define-condition illegal-state (error)
  ((message :initarg :message :reader message :documentation "The message that caused the error.")
    (state :initarg :state :reader state :documentation "The illegal state that caused the error."))
  (:documentation "Condition to signal error of illegal message state. When setf-ing the state of a message,
this condition is signaled if the new state is not in *message-states*. The
condition carries the signaling message and the illegal state as MESSAGE and
STATE slots, respectively."))

;;; Define the Message Class
(defclass message ()
  ((message-type :initarg :type :accessor message-type :documentation "The type of the message.")
    (target :initarg :target :accessor message-target :documentation "The target of the message.")
    (data :initarg :data :initform (list) :accessor message-data :documentation "The data carried by the message.")
    (state :initarg :state :initform :new :accessor message-state :documentation "The current state of the message.
     The message-state is used to inform of the processing/propagation of the
      message. The default message-phase is :new. Message states are defined in *message-states*.")
    (capturing-p :initarg :capturing-p :initform nil :accessor message-capturing-p :documentation "Flag indicating if the message should capture.")
    (signal-states :initarg :signal-states :initform (list :error) :accessor message-signal-state :documentation "List of states that should signal an error if set.")
    (bubbling-p :initarg :bubbling-p :initform nil :accessor message-bubbling-p :documentation "Flag indicating if the message should bubble."))
  (:documentation "A message that can be handled by entities."))

;;; Define the Propagation-Supporting Interface
(defgeneric add-child (parent child)
  (:documentation "Add CHILD as a child of PARENT."))

(defmethod broadcast-p ((message message))
  "Check if the message is a broadcast message."
  (eq (message-target message) :broadcast))

(defmethod  (setf message-state) :before  (new-state (message message))
  "Set the state of the MESSAGE to NEW-STATE."
  (if (member new-state *message-states*)
    (when (and (member new-state (message-signal-state message)) ;; should signal error
            (not (eq new-state (message-state message)))) ;; state is not the same
      (signal 'message-state :message message :state new-state))
    (error 'illegal-state :message message :state new-state)))

(defgeneric remove-children (parent child)
  (:documentation "Remove CHILD from the list of children of PARENT."))

(defgeneric path-to (parent target)
  (:method ((parent t) (target t))
    ;; base-implementation uses recursion + get-children to find path
    (let ((path (list parent)))
      (labels ((find-path (current target path)
                 (cond ((eq current target) (reverse path))
                   (t (loop for child in (get-children current)
                        for result = (find-path child target (cons child path))
                        when result return result)))))
        (find-path parent target path))))
  (:documentation "If TARGET is below PARENT in the hierarchy, return the path to TARGET as a list of nodes."))

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


(defclass messenger ()
  ((children :initform nil :accessor messenger-children
     :documentation "The list of child entities."))
  (:documentation "An entity that supports propagation in a hierarchical structure."))

;;; Define the Propagation Entity Class
(defclass propagation-entity (messenger)
  ((name :initarg :name :accessor entity-name :documentation "The name of the entity.")
    (parent :initform nil :accessor entity-parent :documentation "The parent entity.")
    (handlers :initform (make-hash-table :test #'equal) :accessor entity-handlers :documentation "A hash table of message handlers."))
  (:documentation "An entity that supports propagation in a hierarchical structure."))

(defmethod print-object ((entity propagation-entity) stream)
  "Print the PROPAGATION-ENTITY to STREAM."
  (print-unreadable-object (entity stream :type t :identity t)
    (format stream "~a|Parent:~a|Children:~a"
      (entity-name entity)
      (and (entity-parent entity) (entity-name (entity-parent entity)))
      (length (messenger-children entity)))))
#|
(let ((c (make-instance 'propagation-entity :name "Root")))
(print c))
|#

(defmethod root-path ((entity propagation-entity) &optional (root nil)
                       &key (exclude-start nil) (exclude-end nil))
  "Return the path from root to entity as a list of nodes.

If ROOT is not provided, the path is returned from the entity to its root,
else the path is returned from the entity to the provided root."
  (if (eq entity root)
    (list entity)
    (let ((path (list entity)))
      (labels ((find-path (current target path)
                 (cond ((eq current target)
                         (if current
                           (reverse path)
                           (butlast (reverse path))))
                   (t (find-path
                        (entity-parent current) target
                        (cons (entity-parent current) path))))))
        (setf path (find-path entity root path)))
      (if (and exclude-start exclude-end)
        (cdr (butlast path))
        (if exclude-start
          (cdr path)
          (if exclude-end
            (butlast path)
            path))))))

;;; Implement the Propagation-Supporting Interface for Propagation Entity
(defun find-path (current target path)
  "Helper function to find the path from CURRENT to TARGET."
  (cond ((eq current target) (reverse path))
    (t (loop for child in (get-children current)
         for result = (find-path child target (cons child path))
         when result return result))))

(defmethod path-to ((parent propagation-entity) (target propagation-entity))
  "If TARGET is below PARENT in the hierarchy, return the path to TARGET as a list of nodes."
  (find-path parent target (list parent)))

;;; Helper Function to Append Values to Hash Table
(defun append-hash (h-map val hashkey)
  "Append VAL to the list of values stored in H-MAP under HASHKEY.
If no value is stored under HASHKEY, create a new list with VAL as its only element.

Return the updated hash table."
  (setf (gethash hashkey h-map) (reverse (cons val (reverse (gethash hashkey h-map)))))
  h-map)


;;; Propagation Methods
(defgeneric stop-propagation (message)
  (:documentation "Stop the propagation of the MESSAGE."))

(defmethod stop-propagation ((message message))
  "Stop the propagation of the MESSAGE."
  (setf (message-state message) :stopped))

(defgeneric process (entity message)
  (:documentation "Process MESSAGE if a handler is found."))

(defmethod process ((entity propagation-entity) (message message))
  "Process MESSAGE if a handler is found."
  (let ((handlers (gethash (message-type message) (entity-handlers entity))))
    (when handlers
      (dolist (handler handlers)
        (funcall handler entity message)))))

;;; Example Usage
;; (let* ((root (make-instance 'propagation-entity :name "Root"))
;;         (child1 (make-instance 'propagation-entity :name "Child1"))
;;         (child2 (make-instance 'propagation-entity :name "Child2"))
;;         (grandchild (make-instance 'propagation-entity :name "Grandchild")))
;;         ;; (msg (make-instance 'message :type :custom-message :target child1 :capturing-p t :bubbling-p t)))
;;   ;; (add-child root child1)
;;   ;; (add-child root child2)
;;   ;; (add-child child1 grandchild)
;;   (path-to root root))


;;   (append-hash (entity-handlers root)
;;     (lambda (entity message)
;;       (format t "Root handled ~a~%" (message-type message)))
;;     :custom-message)

;;   (append-hash (entity-handlers child1)
;;     (lambda (entity message)
;;       (format t "Child1 handled ~a~%" (message-type message)))
;;     :custom-message)

;;   (append-hash (entity-handlers grandchild)
;;     (lambda (entity message)
;;       (format t "Grandchild handled ~a~%" (message-type message)))
;;     :custom-message)

;;   ;; Emit and propagate message
;;   (propagate root msg))


;;; Implement the Propagation-Supporting Interface for Propagation Entity

(defmethod add-child ((parent propagation-entity) (child propagation-entity))
  "Add CHILD as a child of PARENT."
  (push child (messenger-children parent))
  (setf (entity-parent child) parent))

(defmethod get-children ((parent propagation-entity) &rest args &key &allow-other-keys)
  "Return the list of children of PARENT."
  (messenger-children parent))

(defmethod remove-children ((parent propagation-entity) (child propagation-entity))
  "Remove CHILD from the list of children of PARENT."
  (setf (messenger-children parent) (remove child (messenger-children parent)))
  (setf (entity-parent child) nil))





;;; Propagation Methods

(defgeneric propagate (entity message)
  (:documentation "Handle application of MESSAGE if target or on capturing/bubbling path, else propagate to target/all children if broadcast."))

(defmethod propagate ((entity propagation-entity) (message message))
  "Handle application of MESSAGE if target or on capturing/bubbling path, else propagate to target/all children if broadcast."
  ;; stopped message handling
  (when (and (eq (message-target message) :broadcast)
          (or (eq (message-bubbling-p message) t)
            (eq (message-capturing-p message) t)))
    (error "Broadcast message cannot bubble or capture."))

  (when (or (eq (message-state message) :stopped)
          (eq (message-state message) :done)
          (eq (message-state message) :error))
    (return-from propagate))
  ;; targeted message handling with target != entity
  (when (and
          (not (null (message-target message)))
          (not (eq (message-target message) entity))
          (not (message-capturing-p message))
          (eq (message-state message) :new)
          (not (eq (message-target message) :broadcast)))
    (let* ((trgts (if (listp (message-target message))
                    (message-target message)
                    (list (message-target message)))))
      (loop for trg in trgts
        do (progn
             (setf (message-target message) trg)
             (setf (message-state message) :at-target)
             (propagate trg message)))
      (return-from propagate)))
  ;; entity is entitled to handle the message
  (process entity message)
  (cond
    ((eq (message-target message) :broadcast)
      ;; broadcast -> propagate to all children
      (progn
        (dolist (child (get-children entity))
          (propagate child message))))
    ((and (message-capturing-p message) (eq (message-state message) :new))
      (setf (message-state message) :capturing)
      ;; capturing -> propagate to all children on path to target
      (let* ((trgts (if (listp (message-target message))
                      (message-target message)
                      (list (message-target message)))))
        (loop for trg in trgts
          do (progn
               (setf (message-target message) trg)
               (let ((path-to-target (cdr (path-to entity trg))))
                 (format t "Path to target: ~a~%" path-to-target)
                 (when path-to-target
                   (dolist (node path-to-target)
                     (when (= 1 (length (member node path-to-target)))
                       (setf (message-target message) node)
                       (setf (message-state message) :at-target))
                     (propagate node message)))))))))
  (when (and (entity-parent entity) (message-bubbling-p message)
          (or (eq (message-state message) :bubbling)
            (and (eq (message-state message) :at-target)
              (eq (message-target message) entity)))
          (setf (message-state message) :bubbling)
          (propagate (entity-parent entity) message))))
;;   ;; (when (message-propagate message)
;;   ;;   (dolist (child (get-children entity))
;;   ;;     (propagate child message)))
;;   ;; (setf (message-state message) :captured)
;;   ;; (process entity message)
;;   ))
;; ((and (message-bubbling-p message) (eq (message-state message) :captured))
;;   (process entity message)
;;   (when (entity-parent entity)
;;     (propagate (entity-parent entity) message)))
;; ((eq (message-target message) entity)
;;   (process entity message))
;; ((not (null (message-target message)))
;;   (let ((path (path-to entity (message-target message))))
;;     (when path
;;       (dolist (node path)
;;         (process node message)))))))



