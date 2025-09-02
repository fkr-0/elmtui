(uiop:define-package :cleve-elm.queue
  (:use :cl :bt)
  (:import-from :log4cl #:log-debug)
  (:export
   :priority-queue
   :typed-queue
   :expected-type
   :actual-type
   :queue-empty-p
   :enqueue
   :queue
   :queue-length
   :dequeue-wait
   :make-queue
   :queue-lock
   :item-added
   :counter
   :wrong-type-condition
   :dequeue
   :dequeue-no-wait
   :queue-length
   :make-priority-queue
   :enqueue-with-priority
   :standard-priority
   :high-priority
   :urgent-priority))

(in-package :cleve-elm.queue)

(declaim (type fixnum standard-priority high-priority urgent-priority))
(defconstant standard-priority 0 "Standard queue priority")
(defconstant high-priority 1 "High priority for important items")
(defconstant urgent-priority 2 "Urgent priority for critical items")

(defclass priority-queue ()
  ((items :accessor items :initform (make-hash-table) :type hash-table :documentation "Hash table containing items organized by priority")
   (max-priority :accessor max-priority :initform 0 :type fixnum :documentation "Current maximum priority in the queue")
   (counter :reader %counter
            :writer (setf %counter)
            :initform 0
            :type fixnum)
   (lock :accessor queue-lock :initform (bt:make-lock) :type bt:lock)
   (item-added  :accessor item-added :initform (bt:make-condition-variable) :type sb-thread:waitqueue))
  (:documentation "A priority queue with multiple priority levels."))

;; This is a generic function with a specific method for priority-queue
;; Removed FTYPE declaration to avoid clobbering warning
(defgeneric counter (queue)
  (:documentation "Get the counter value of a queue.
The counter indicates the number of items in the queue.")
  (:method ((queue priority-queue))
    (bt:with-lock-held ((queue-lock queue))
      (let ((c (%counter queue)))
        (declare (type fixnum c))
        (when (> c 0)
          (log-debug :cleve.queue "COUNTER for ~A #<ID ~X>: lock held, %counter is ~D"
                     (class-name (class-of queue))
                     (sb-kernel:get-lisp-obj-address queue)
                     c))
        c))))

(defmethod print-object ((queue priority-queue) stream)
  (declare (type priority-queue queue)
           (type stream stream))
  (print-unreadable-object (queue stream :type t :identity t)
    (format stream "Q[~A]" (counter queue))))

                                        ;(declaim (ftype (function () priority-queue) make-queue make-priority-queue))
(defun make-queue ()
  "Create a new priority queue."
  (make-instance 'priority-queue))

(defun make-priority-queue ()
  "Create a new priority queue."
  (make-queue))

;; Removed FTYPE declaration to avoid clobbering warning
(defgeneric enqueue (queue item &optional priority)
  (:documentation "Add an item to the queue with the specified priority.")
  (:method ((queue priority-queue) item &optional (priority standard-priority))
    "Add an item to the queue with the specified priority.
Higher priority items are dequeued before lower priority items."
    (declare (type priority-queue queue)
             (type t item)
             (type fixnum priority))
    (check-type priority fixnum)
    (bt:with-lock-held ((queue-lock queue))
      (unless (gethash priority (items queue))
        (setf (gethash priority (items queue)) nil))

      (push item (gethash priority (items queue)))

      (when (> priority (max-priority queue))
        (setf (max-priority queue) priority))

      (incf (%counter queue))
      (bt:condition-notify (item-added queue)))))

(fmakunbound 'enqueue-with-priority)
;; Removed FTYPE declaration to avoid clobbering warning
(defgeneric enqueue-with-priority (queue item priority)
  (:documentation "Add an item to the queue with the specified priority level.")
  (:method ((queue priority-queue) item priority)
    "Add an item to the queue with the specified priority level.
Higher priority items are dequeued before lower priority items."
    (declare (type priority-queue queue)
             (type t item)
             (type fixnum priority))
    (check-type priority fixnum)
    (enqueue queue item priority)))

(declaim (ftype (function (hash-table) (or null fixnum)) highest-priority-key))
(defun highest-priority-key (hash-table)
  "Find the highest numerical key in the hash table that has items."
  (declare (type hash-table hash-table))
  (let ((max-key nil))
    (declare (type (or null fixnum) max-key))
    (maphash (lambda (k v)
               (declare (type fixnum k)
                        (type list v))
               (when (and v (or (null max-key) (> k max-key)))
                 (setf max-key k)))
             hash-table)
    max-key))

;; Removed FTYPE declaration to avoid clobbering warning
(defgeneric pop-highest-priority-item (queue)
  (:documentation "Pop the item with the highest priority from the queue.")
  (:method ((queue priority-queue))
    "Pop the item with the highest priority from the queue."
    (declare (type priority-queue queue))
    (let* ((priority (highest-priority-key (items queue)))
           (items-list (when priority (gethash priority (items queue))))
           (item nil))
      (declare (type (or null fixnum) priority)
               (type list items-list)
               (type t item))

      (when items-list
        (setf item (car (last items-list)))
        (setf (gethash priority (items queue))
              (subseq items-list 0 (1- (length items-list))))

        (when (null (gethash priority (items queue)))
          (remhash priority (items queue))
          (setf (max-priority queue) (or (highest-priority-key (items queue)) 0)))

        item))))

;; Removed FTYPE declaration to avoid clobbering warning
(defgeneric dequeue-wait (queue)
  (:documentation "Wait until an item is available and return the highest priority item.")
  (:method ((queue priority-queue))
    "Wait until an item is available and return the highest priority item."
    (declare (type priority-queue queue))
    (bt:with-lock-held ((queue-lock queue))
      (loop
        while (zerop (%counter queue))
        do (bt:condition-wait (item-added queue) (queue-lock queue)))

      (let ((item (pop-highest-priority-item queue)))
        (decf (%counter queue))
        item))))

;; Removed FTYPE declaration to avoid clobbering warning
(defgeneric dequeue-no-wait (queue)
  (:documentation "Return the highest priority item or nil if no item is available.")
  (:method ((queue priority-queue))
    "Return the highest priority item or nil if no item is available."
    (declare (type priority-queue queue))
    (bt:with-lock-held ((queue-lock queue))
      (when (> (%counter queue) 0)
        (let ((item (pop-highest-priority-item queue)))
          (decf (%counter queue))
          item)))))

;; Removed FTYPE declaration to avoid clobbering warning
(defgeneric dequeue (queue &optional wait)
  (:documentation "Return the highest priority item from the queue, optionally waiting.")
  (:method ((queue priority-queue) &optional (wait t))
    "Return the highest priority item from the queue."
    (declare (type priority-queue queue)
             (type boolean wait))
    (if wait
        (dequeue-wait queue)
        (dequeue-no-wait queue))))

;; (declaim (ftype (function (priority-queue) (values &optional boolean &rest t)) queue-empty-p))
(defgeneric queue-empty-p (queue)
  (:documentation "Check if the queue is empty.")
  (:method ((queue priority-queue))
    "Check if the queue is empty."
    (declare (type priority-queue queue))
    (zerop (counter queue))))

;; (declaim (ftype (function (priority-queue) (values fixnum &rest t)) queue-length))
(defgeneric queue-length (queue)
  (:documentation "Return the number of items in the queue.")
  (:method ((queue priority-queue))
    "Return the number of items in the queue."
    (declare (type priority-queue queue))
    (counter queue)))
