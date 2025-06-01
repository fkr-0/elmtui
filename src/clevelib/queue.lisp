(uiop:define-package :cleve-elm.queue
  (:use :cl :bt)
  (:import-from :log4cl #:log-debug) ; Added log-debug import
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

;; Define priority constants
(defconstant standard-priority 0 "Standard queue priority")
(defconstant high-priority 1 "High priority for important items")
(defconstant urgent-priority 2 "Urgent priority for critical items")

(defclass priority-queue ()
  ((items :accessor items :initform (make-hash-table) :documentation "Hash table containing items organized by priority")
   (max-priority :accessor max-priority :initform 0 :documentation "Current maximum priority in the queue")
   (counter :reader %counter ; Internal reader
            :writer (setf %counter) ; Internal writer
            :initform 0)
   (lock :accessor queue-lock :initform (bt:make-lock))
   (item-added  :accessor item-added :initform (bt:make-condition-variable)))
  (:documentation "A priority queue with multiple priority levels."))

;; Thread-safe accessor for the counter
(defmethod counter ((queue priority-queue))
  (bt:with-lock-held ((queue-lock queue))
    (let ((c (%counter queue)))
      ;; Reduced verbosity: Log only if the counter is non-zero, as zero is the common case during polling.
      (when (> c 0)
        (log-debug :cleve.queue "COUNTER for ~A #<ID ~X>: lock held, %counter is ~D"
                   (class-name (class-of queue))
                   (sb-kernel:get-lisp-obj-address queue) ; Or sxhash, or similar for identity
                   c))
      c)))

(defmethod print-object ((queue priority-queue) stream)
  (print-unreadable-object (queue stream :type t :identity t)
    ;; Use the thread-safe accessor in print-object as well
    (format stream "Q[~A]" (counter queue))))

(defun make-queue ()
  "Create a new priority queue."
  (make-instance 'priority-queue))

;; Alias for backward compatibility
(defun make-priority-queue ()
  "Create a new priority queue."
  (make-queue))

(defmethod enqueue ((queue priority-queue) item &optional (priority standard-priority))
  "Add an item to the queue with the specified priority.
Higher priority items are dequeued before lower priority items."
  (bt:with-lock-held ((queue-lock queue))
    ;; Ensure we have a list for this priority level
    (unless (gethash priority (items queue))
      (setf (gethash priority (items queue)) nil))
    
    ;; Push the item to the appropriate priority list
    (push item (gethash priority (items queue)))
    
    ;; Update max priority if needed
    (when (> priority (max-priority queue))
      (setf (max-priority queue) priority))
    
    (incf (%counter queue)) ; Use internal reader for incf
    (bt:condition-notify (item-added queue))))

(defun enqueue-with-priority (queue item priority)
  "Add an item to the queue with the specified priority level.
Higher priority items are dequeued before lower priority items."
  (enqueue queue item priority))

(defun highest-priority-key (hash-table)
  "Find the highest numerical key in the hash table that has items."
  (let ((max-key nil))
    (maphash (lambda (k v)
               (when (and v (or (null max-key) (> k max-key)))
                 (setf max-key k)))
             hash-table)
    max-key))

(defmethod pop-highest-priority-item ((queue priority-queue))
  "Pop the item with the highest priority from the queue."
  (let* ((priority (highest-priority-key (items queue)))
         (items-list (when priority (gethash priority (items queue))))
         (item nil))
    
    (when items-list
      ;; Get the last item in the list (FIFO behavior)
      (setf item (car (last items-list)))
      ;; Remove the item from the list
      (setf (gethash priority (items queue)) 
            (subseq items-list 0 (1- (length items-list))))
      
      ;; If this priority level is now empty, remove it and update max-priority
      (when (null (gethash priority (items queue)))
        (remhash priority (items queue))
        (setf (max-priority queue) (or (highest-priority-key (items queue)) 0)))
      
      item)))

(defmethod dequeue-wait ((queue priority-queue))
  "Wait until an item is available and return the highest priority item."
  (bt:with-lock-held ((queue-lock queue))
    (loop
      while (zerop (%counter queue)) ; Use internal reader
      do (bt:condition-wait (item-added queue) (queue-lock queue)))
    
    (let ((item (pop-highest-priority-item queue)))
      (decf (%counter queue)) ; Use internal reader for decf
      item)))

(defmethod dequeue-no-wait ((queue priority-queue))
  "Return the highest priority item or nil if no item is available."
  (bt:with-lock-held ((queue-lock queue))
    (when (> (%counter queue) 0) ; Use internal reader
      (let ((item (pop-highest-priority-item queue)))
        (decf (%counter queue)) ; Use internal reader for decf
        item))))

(defmethod dequeue ((queue priority-queue) &optional (wait t))
  "Return the highest priority item from the queue."
  (if wait
      (dequeue-wait queue)
      (dequeue-no-wait queue)))

(defmethod queue-empty-p ((queue priority-queue))
  "Check if the queue is empty."
  ;; This will now use the thread-safe counter method
  (zerop (counter queue)))

(defmethod queue-length ((queue priority-queue))
  "Return the number of items in the queue."
  ;; This will now use the thread-safe counter method
  (counter queue))
