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

(declaim (ftype (function (&optional (or null string)) bt:lock) make-mutex))
(defun make-mutex (&optional name)
  "Create a new mutex with the optional NAME."
  (declare (type (or null string) name))
  (bt:make-lock name))

(defmacro with-mutex (mutex &body body)
  "Execute BODY while holding the MUTEX."
  `(bt:with-lock-held (,mutex)
     (progn
       ,@body)))

(define-condition mutex-error (error)
  ((mutex :initarg :mutex
          :reader mutex
          :type bt:lock))
  (:report (lambda (condition stream)
             (declare (type mutex-error condition)
                      (type stream stream))
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

(declaim (ftype (function () sb-thread:waitqueue) make-condition-variable))
(defun make-condition-variable ()
  "Create a new condition variable."
  (sb-thread:make-waitqueue))

(declaim (ftype (function (sb-thread:waitqueue bt:lock &optional (or null number)) t) wait-on-condition))
(defun wait-on-condition (condition mutex &optional timeout)
  "Wait for the CONDITION variable while releasing the MUTEX.
   Optionally, provide a TIMEOUT in seconds."
  (declare (type sb-thread:waitqueue condition)
           (type bt:lock mutex)
           (type (or null number) timeout))
  (if timeout
      (bt:with-timeout (timeout)
        (bt:condition-wait condition mutex))
      (bt:condition-wait condition mutex)))

(declaim (ftype (function (sb-thread:waitqueue) t) signal-condition))
(defun signal-condition (condition)
  "Signal the CONDITION variable to wake up a single waiting thread."
  (declare (type sb-thread:waitqueue condition))
  (bt:condition-notify condition))

(declaim (ftype (function (sb-thread:waitqueue) t) broadcast-condition))
(defun broadcast-condition (condition)
  "Signal the CONDITION variable to wake up all waiting threads."
  (declare (type sb-thread:waitqueue condition))
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

(declaim (ftype (function (bt:thread) boolean) thread-alive-p))
(defun thread-alive-p (thread)
  "Return T if THREAD is alive, NIL otherwise."
  (declare (type bt:thread thread))
  (bt:thread-alive-p thread))

(declaim (ftype (function (bt:thread string) t) set-thread-name))
(defun set-thread-name (thread name)
  "Set the name of THREAD to NAME."
  (declare (type bt:thread thread)
           (type string name))
  (setf (slot-value thread 'sb-thread::name ) name))

(declaim (ftype (function (function &rest t) bt:thread) create-thread))
(defun create-thread (function  &rest args)
  "Create and start a new thread, executing FUNCTION with ARGS."
  (declare (type function function))
  (let ((thread (bt:make-thread (lambda () (apply function args))))) 
    (declare (type bt:thread thread))
    thread))

(declaim (ftype (function (bt:thread) t) destroy))
(defun destroy (thread)
  "Destroy a thread and remove it from the active threads hash table."
  (declare (type bt:thread thread))
  (bordeaux-threads:interrupt-thread thread (lambda () (sb-thread:join-thread (sb-thread:main-thread)))))

(declaim (ftype (function (hash-table) list) hash-table-values))
(defun hash-table-values (hash-table)
  "Return a list of the values in HASH-TABLE."
  (declare (type hash-table hash-table))
  (loop for key being the hash-keys of hash-table
        collect (gethash key hash-table)))
