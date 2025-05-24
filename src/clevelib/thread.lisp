;;;; cleve-elm.thread.lisp
;;;;
;;;; This module provides utilities and functions for working with threads
;;;; in the event system. It manages thread creation, synchronization, and
;;;; cleanup. It also implements mutexes and condition variables for
;;;; thread-safe access to shared resources and efficient signaling between
;;;; threads.
;;; Primitives

(uiop:define-package :cleve-elm.mutex
  (:use :cl :bordeaux-threads)
  (:export
   :make-mutex
   :with-mutex
   :mutex-error))

(in-package :cleve-elm.mutex)

(defun make-mutex (&optional name)
  "Create a new mutex with the optional NAME."
  (bt:make-lock name))
(defmacro with-mutex (mutex &body body)
  "Execute BODY while holding the MUTEX."
  `(bt:with-lock-held (,mutex)
     (progn
       ,@body)))
(define-condition mutex-error (error)
  ((mutex :initarg :mutex
          :reader mutex))
  (:report (lambda (condition stream)
             (format stream "Mutex error: ~A" condition)))
  (:documentation "A condition that is signaled when a mutex error occurs."))

(uiop:define-package :cleve-elm.condition-variable
  (:nicknames :cleve-elm.cv)
  (:use :cl :bordeaux-threads)
  (:export
   :make-condition-variable
   :wait-on-condition
   :signal-condition
   :broadcast-condition))

(in-package :cleve-elm.condition-variable)

(defun make-condition-variable ()
  "Create a new condition variable."
  (sb-thread:make-waitqueue))
(defun wait-on-condition (condition mutex &optional timeout)
  "Wait for the CONDITION variable while releasing the MUTEX.
   Optionally, provide a TIMEOUT in seconds."
  (if timeout
      (bt:with-timeout (timeout)
        (bt:condition-wait condition mutex))
      (bt:condition-wait condition mutex)))

(defun signal-condition (condition)
  "Signal the CONDITION variable to wake up a single waiting thread."
  (bt:condition-notify condition))

(defun broadcast-condition (condition)
  "Signal the CONDITION variable to wake up all waiting threads."
  (sb-thread:condition-broadcast condition))

(uiop:define-package :cleve-elm.thread
  (:use :cl :bordeaux-threads :cleve-elm.queue :log4cl)
  (:documentation "This package provides utilities and functions for working with threads in the event system.")
  (:nicknames :cl.t)
  (:shadow :make-thread :thread-alive-p :make-mutex :with-mutex :make-condition-variable :wait-on-condition :broadcast-condition :destroy :create-thread :set-thread-name)
  (:export
   :destroy
   :thread-alive-p
   :create-thread
   :set-thread-name))

(in-package :cleve-elm.thread)

(defun thread-alive-p ( thread)
  "Return T if THREAD is alive, NIL otherwise."
  (bt:thread-alive-p thread))

(defun set-thread-name (thread name)
  "Set the name of THREAD to NAME."
  (setf (slot-value thread 'sb-thread::name ) name))

(defun create-thread (function  &rest args)
  "Create and start a new thread, executing FUNCTION with ARGS."
  (let ((thread (bt:make-thread (lambda () (apply function args))))) thread))

(defun destroy (thread )
  "Destroy a thread and remove it from the active threads hash table."
  (bordeaux-threads:interrupt-thread thread (lambda () (sb-thread:join-thread (sb-thread:main-thread)))))

(defun hash-table-values (hash-table)
  "Return a list of the values in HASH-TABLE."
  (loop for key being the hash-keys of hash-table
        collect (gethash key hash-table)))

;;;; Mutexes and condition variables
;; ((condition-variable :initarg :condition-variable
;;    :reader condition-variable))
;; (:report (lambda (condition stream)
;;            (format stream "Condition variable error: ~A" condition))))

;; (defun with-mutex (mutex &rest body)
;;   "Execute BODY while holding the MUTEX."
;;   (bt:with-lock-held (mutex)
;;     (progn
;;       (apply body))))

;; (defmethod destroy ((pool thread-pool))
;;   "Destroy a thread and remove it from the active threads hash table."
;;   (with-mutex (mutex pool)
;;     (destroy-all-threads (threads pool))))
