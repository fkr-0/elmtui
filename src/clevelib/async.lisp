;;;; clevelib/async.lisp
;;;;
;;;; This module handles asynchronous execution, including running tasks
;;;; asynchronously and managing their state.

(uiop:define-package :cleve-elm.async
  (:use :cl :log4cl)
  (:import-from :cleve-elm.mutex
   :make-mutex
                :with-mutex)
  (:import-from :cleve-elm.cv
   :make-condition-variable
                :wait-on-condition
   :signal-condition)
  (:import-from :cleve-elm.thread
   :destroy
                :start-thread
   :thread-alive-p
                :create-thread
   :set-thread-name)
  (:export
   :async-task
   :new-task
   :spawn-task
   :make-async-task
   :async-exec
   :cancel-async-task
   :async-run
   :async-task-finished-p
   :async-task-result
   :async-task-status
   :async-task-error
   :async-task-failed-error
   :async-task-promise
   :async-task-thread
   :async-task-condition-variable
   :async-task-lock
   :async-task-finished
   :async-task-function
   :async-task-args
   :sync-run
   :async-exec
   :poll-result
   :cancel-async-task
   :async-task-finished-p
   :promise
   :resolve-promise
   :reject-promise
   :promise-value
   :promise-error
   :promise-resolved
   :promise-condition
   :promise-cancelled-condition
   :promise-lock
   :promise-cancel
   :promise-cancelled-p
   :with-promise
   :then
   :await))
(in-package :cleve-elm.async)

(defstruct (promise (:conc-name promise-))
  value ;; The value of the promise when resolved
  error ;; The error if the promise is rejected,
  resolved ;; Boolean indicating if the promise is resolved
  condition ;; Condition variable to signal resolution
  ;; lock ;; Mutex for synchronizing access to the promise
  lock)

(defmethod initialize-instance :after ((p promise) &key)
  (setf (promise-lock p) (make-mutex))
  (setf (promise-condition p) (make-condition-variable))
  ;; (log-info "Initialized promise with condition variable and lock")
  )

(defstruct (async-task (:conc-name async-task-))
  function
  args
  thread
  status
  condition-variable
  lock
  result
  error
  promise
  finished)

(defmethod initialize-instance :after ((task async-task) &key
                                                           (function nil)
                                                           (args nil)
                                                           (promise nil))
  (setf (async-task-promise task) (or promise (make-instance 'promise)))
  (when function
    (setf (async-task-function task) function))
  (when args
    (setf (async-task-args task) args))
  (setf (async-task-status task) :pending)
  (setf (async-task-lock task) (make-mutex))
  (setf (async-task-condition-variable task) (make-condition-variable))
  (setf (async-task-finished task) nil)
  (setf (async-task-result task) nil)
  (setf (async-task-error task) nil)
  (log-info "Initialized async-task with status :pending"))

(defun new-task (function &rest args)
  "Create a new async task with the given function and arguments."
  (log-info "Creating new task")
  (make-instance 'async-task :function function :args args))

(defmethod sync-run ((task async-task))
  "Run the given function synchronously, with the given arguments.
   Returns the result of the function. If the function throws an error, the
   error will be returned instead."
  (log-info "Running task synchronously")
  (handler-case
      (progn
        (setf (async-task-status task) :running)
        (log-info "Task status set to :running")
        (setf (async-task-result task) (apply (async-task-function task) (async-task-args task)))
        (setf (async-task-status task) :completed)
        (log-info "Task completed with result: ~A" (async-task-result task))
        (setf (async-task-finished task) t)
        (resolve-promise (async-task-promise task) (async-task-result task))
        (signal-condition (async-task-condition-variable task)))
    (error (err)
      (setf (async-task-status task) :error)
      (setf (async-task-error task) err)
      (setf (async-task-finished task) t)
      (log-error "Task failed with error: ~A" err)
      (reject-promise (async-task-promise task) err)
      (signal-condition (async-task-condition-variable task))
      (error err))))

(defgeneric spawn-task (pool task)
  (:documentation "Spawn the given task in the given thread pool.
   This function should be implemented by the user to run the given task in the
   given thread pool. The task should be executed asynchronously, and the result
   should be stored in the task."))

(defmethod async-exec ((task async-task) &optional (pool nil))
  "Execute the given async task. Returns the task itself.
   The task will be executed in a new thread, and the result will be stored in
   the task. If the task is already finished, this function does nothing.

   Args:
     task(async-task): The task to execute.
     pool(thread-pool): The thread pool to execute the task in. If nil, the task
       will be executed in a new thread."
  (unless (async-task-finished task)
    (log-info "Executing task asynchronously")
    (if pool
        (spawn-task pool task)
        (setf (async-task-thread task)
              (cleve-elm.thread:create-thread
               (lambda ()
                 (sync-run task)))))
    task))

(defun poll-result (task &key (timeout 0))
  "Get the result of the given async task, waiting for up to `timeout` seconds.
   Returns multiple values: the result, error (if any), and a boolean indicating
   if the task is finished. If the task is not finished, the result and error
   will be nil.
   If the task is finished with an error, this function will throw an error.
  Args:
    task(async-task): The async task to get the result of.
    timeout(number): The maximum time to wait for the task to finish."
  (log-info "Polling result for task")
  (with-mutex (async-task-lock task)
    (when (not (async-task-finished task))
      (wait-on-condition (async-task-condition-variable task) (async-task-lock task) timeout))
    (cond ((eq (async-task-status task) :error)
           (log-error "Task finished with error: ~A" (async-task-error task))
           (error (format nil "Task finished with error: ~A" (async-task-error task))))
          (t (values (async-task-result task) (async-task-error task) (async-task-finished task))))))

(defun cancel-async-task (task)
  "Cancel the given async task, if possible."
  (unless (async-task-finished task)
    (log-info "Cancelling task")
    (when (cleve-elm.thread:thread-alive-p (async-task-thread task))
      (cleve-elm.thread:destroy (async-task-thread task)))
    (with-mutex (async-task-lock task)
      (setf (async-task-finished task) t))))

(defun async-task-finished-p (task)
  "Return true if the given async task has finished.
   This function does not block."
  (with-mutex (async-task-lock task)
    (async-task-finished task)))

(defun resolve-promise (p value)
  (log-info "Resolving promise with value: ~A" value)
  (with-mutex (promise-lock p)
    (setf (promise-value p) value)
    (setf (promise-resolved p) t)
    (signal-condition (promise-condition p))))

(defun reject-promise (p error)
  (log-error "Rejecting promise with error: ~A" error)
  (with-mutex (promise-lock p)
    (setf (promise-error p) error)
    (setf (promise-resolved p) t)
    (signal-condition (promise-condition p))))

(defmethod await ((p promise) &optional (timeout 0))
  (log-info "Awaiting promise")
  (with-mutex (promise-lock p)
    (loop until (promise-resolved p)
          do (wait-on-condition (promise-condition p) (promise-lock p) timeout))
    (if (promise-error p)
        (error (promise-error p))
        (promise-value p))))

(defmethod await ((task async-task) &optional (timeout 0))
  (await (async-task-promise task) timeout))

(defmethod then ((p promise) callback &optional error-callback)
  "Chain a callback to a promise, executing it when the promise resolves.
   If the promise is rejected, the error-callback will be called."
  (log-info "Chaining callback to promise")
  (let ((result (make-instance 'promise)))
    (with-mutex (promise-lock p)
      (when (promise-resolved p)
        (if (promise-error p)
            (when error-callback
              (funcall error-callback (promise-error p)))
            (funcall callback (promise-value p))))
      ;; Set up the new promise
      (setf (promise-value result) nil)
      (setf (promise-error result) nil)
      (setf (promise-resolved result) nil)
      (setf (promise-condition result) (make-condition-variable))
      (setf (promise-lock result) (make-mutex)))
    result))

;; (defmethod async-task-status ((task async-task))
;;   "Return the current status of the async task."
;;   (with-mutex (async-task-lock task)
;;     (async-task-status task)))

(define-condition async-task-failed-error
    (error)
  ((task :initarg :task :reader async-task-failed-function)
   (error :initarg :error :reader async-task-failed-error))
  (:report (lambda (c s)
             (format s "Async task ~A failed with error: ~A"
                     (async-task-function (slot-value c 'task)) (slot-value c 'error)))))

(defmacro with-promise ((promise &optional (task-name-for-error ''anonymous-promise-task)) &body body)
  "Execute BODY with a new promise, binding it to PROMISE.
   The promise can be resolved or rejected within BODY.
   If the body exits and the promise is neither resolved nor rejected,
   it will be automatically rejected.

Example usage:
  (with-promise (my-promise 'my-actual-task-symbol)
    (resolve-promise my-promise 'result)
    ;; or
    (reject-promise my-promise 'error)) => Returns a promise that can be awaited later.

  (with-promise (another-promise) ; task-name-for-error defaults to 'anonymous-promise-task
    (resolve-promise another-promise 42))
"
  `(let ((,promise (make-instance 'promise)))
     (unwind-protect
          (progn ,@body)
       ;; If the body finishes and the promise hasn't been explicitly resolved or rejected,
       ;; reject it automatically.
       (unless (promise-resolved ,promise)
         (reject-promise ,promise
                         (make-condition 'async-task-failed-error
                                         :task ,task-name-for-error
                                         :error "Promise was not resolved or rejected before exiting body"))))
     ,promise))
(define-condition promise-cancelled-condition
    (error)
  ((promise :initarg :promise :reader promise-cancelled-promise))
  (:report (lambda (c s)
             (format s "Promise ~A was cancelled." (slot-value c 'promise)))))
(defmethod promise-cancel ((p promise))
  "Cancel the promise, if it is not already resolved or rejected.
   This will not affect the promise's resolution state, but can be used to
   signal that the promise is no longer needed."
  (log-info "Cancelling promise")
  (with-mutex (promise-lock p)
    (setf (promise-resolved p) t)
    (setf (promise-value p) nil)
    (setf (promise-error p) nil)
    (signal-condition (promise-condition p))))

(defmethod promise-cancelled-p ((p promise))
  "Check if the promise has been cancelled.
   Returns true if the promise is resolved, false otherwise."
  (with-mutex (promise-lock p)
    (promise-resolved p)))
