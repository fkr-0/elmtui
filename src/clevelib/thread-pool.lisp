(uiop:define-package :cleve-elm.thread-pool
  (:use :cl )
  (:import-from :bordeaux-threads
   :join-thread
                :thread-alive-p)
  (:import-from :cleve-elm.queue
   :make-queue
                :queue-length
   :enqueue
                :dequeue
   :queue-empty-p)
  (:import-from :cleve-elm.mutex
   :with-mutex
                :make-mutex)
  (:import-from :cleve-elm.thread
   :destroy
                :create-thread)
  (:import-from :cleve-elm.condition-variable
   :make-condition-variable
                :wait-on-condition
   :signal-condition
                :broadcast-condition)
  (:import-from :cleve-elm.async
   :make-async-task
                :sync-run
   :async-run
                :new-task
   :async-task
                :spawn-task
   :make-promise)
  (:export
   :active-threads
   :done
   :finish-task
   :in-pool
   :join-pool-threads
   :make-thread-pool
   :add-task
   :broadcast-pool-condition
   :create-pool-thread
   :destroy-thread
   :get-task
   :signal-pool-condition
   :wait-on-pool-ondition
   :query-next
   :resize-pool
   :spawn-task
   :spawn-task-worker
   :start-thread
   :stop-all-task-workers
   :stop-task-worker
   :stop-thread
   :task-queue
   :task-worker
   :task-worker-error
   :thread-count
   :destroy-all-threads
   :join-pool-threads
   :resize-pool
   :make-worker-pool
   :threads
   :thread-limit
   :thread-pool
   :worker-pool
   :thread-running-p
   :waiting-task-workers
   :worker-on-finish
   :worker-state
   :worker-thread
   :worker-task
   :worker-description
   :worker-pool
   :worker-queue
   :worker-err-message
   :worker-condition
   :worker-p
   :worker-task-count))

(in-package :cleve-elm.thread-pool)

;;; Thread Pool Class

(defclass thread-pool ()
  ((threads :initarg :threads
            :accessor threads
            :initform (make-hash-table)
            :documentation "A hash table of threads in the pool.")
   (mutex :initarg :mutex
          :accessor mutex
          :initform (make-mutex)
          :documentation "The mutex for the thread pool. This is used to synchronize access to the thread pool.")
   (conditionv :initarg :condition
               :accessor conditionv
               :initform (make-condition-variable)
               :documentation "The condition variable for the thread pool. This is used to signal when a thread is available.")
   (task-queue :initarg :task-queue
               :accessor task-queue
               :initform (cleve-elm.queue:make-queue)
               :documentation "The queue of tasks to be executed by the thread pool. This is used to synchronize access to the thread pool and to signal when a thread is available.")
   (thread-limit :initarg :thread-limit :accessor thread-limit :initform 0
                 :documentation "The maximum number of threads allowed in the pool. 0 means no limit."))
  (:documentation "A thread pool that manages thread creation, synchronization, and cleanup."))

;;; Worker Pool Class

(defclass worker-pool (thread-pool)
  ((worker-queue :initarg :worker-queue
                 :accessor worker-queue
                 :initform (cleve-elm.queue:make-queue)
                 :documentation "The queue of workers managed by the pool.")
   (worker-condition :initarg :worker-condition
                     :accessor worker-condition
                     :initform (make-condition-variable)
                     :documentation "Condition variable for worker-specific signaling."))
  (:documentation "A worker pool that extends the thread pool to manage task workers specifically, including lifecycle management and error handling for workers."))

;;; Task Worker Structure

(defstruct (task-worker (:conc-name worker-))
  (thread nil :type (or null bt:thread))
  (task nil :type (or null async-task))
  (pool nil :type worker-pool)
  (description nil :type string)
  (task-count 0 :type fixnum)
  (state :init :type (member :init :waiting :running :done :error))
  (err-state nil :type (or null condition))
  (err-message "" :type string)
  (on-finish :wait :type (member :wait :query :finish)))

(defmethod print-object ((pool thread-pool) stream)
  (print-unreadable-object (pool stream :type t :identity t)
    (format stream "[Thrds:~A;Limit:~A;TQ:~A]"
            (thread-count pool) (thread-limit pool)
            (cleve-elm.queue:queue-length (task-queue pool)))))

;;; Initialization

(defmethod initialize-instance :after ((pool thread-pool) &key)
  "Initialize a thread pool.
   This method is called after the thread pool is initialized.
   It initializes the thread pool's mutex and condition variable."
  (setf (threads pool) (make-hash-table)
        (mutex pool) (make-mutex)
        (conditionv pool) (make-condition-variable)))

(defmethod initialize-instance :after ((pool worker-pool) &key)
  "Initialize a worker pool.
   This method is called after the worker pool is initialized.
   It initializes the worker pool's specific variables."
  (setf (worker-queue pool) (cleve-elm.queue:make-queue)
        (worker-condition pool) (make-condition-variable)))

;;; Thread Management

(defmethod create-pool-thread ((pool thread-pool) function &rest args)
  "Create and start a new thread, executing FUNCTION with ARGS.
   Return the thread object."
  (with-mutex (mutex pool)
    (let ((thread (create-thread function (threads pool) args)))
      (setf (gethash (bt:thread-name thread) (threads pool)) thread)
      thread)))

(defmethod destroy-thread ((pool thread-pool) thread)
  "Destroy a thread and remove it from the active threads hash table.
   Return the thread object."
  (with-mutex (mutex pool)
    (destroy thread)
    (remhash (bt:thread-name thread) (threads pool))
    (signal-condition (conditionv pool))))

(defmethod thread-count ((pool thread-pool))
  "Return the number of threads in the pool."
  (hash-table-count (threads pool)))

(defmethod active-threads ((pool thread-pool))
  "Return a list of active threads."
  (maphash #'(lambda (key value)
               (declare (ignore value))
               key)
           (threads pool)))

(defmethod thread-running-p ((pool thread-pool) thread)
  "Return T if THREAD is running."
  (with-mutex (mutex pool)
    (bt:thread-alive-p thread)))

;;; Task Management

(defmethod add-task ((pool thread-pool) task)
  "Add a TASK to the task queue."
  (with-mutex (mutex pool)
    (cleve-elm.queue:enqueue (task-queue pool) task )
    (signal-condition (conditionv pool))))

(defmethod get-task ((pool thread-pool))
  "Get a task from the task queue."
  (with-mutex (mutex pool)
    (cleve-elm.queue:dequeue (task-queue pool))))

(defmethod done ((pool thread-pool) thread-name)
  "Signal that a thread is done and remove it from the pool."
  (with-mutex (mutex pool)
    (remhash thread-name (threads pool)))
  (signal-condition (conditionv pool)))

(defmethod done ((pool worker-pool) (worker task-worker))
  "Signal that a task worker is done."
  (with-mutex (mutex pool)
    (incf (worker-task-count worker))
    (setf (worker-state worker) :done)
    (signal-condition (worker-condition (worker-pool worker)))
    (if (eq :finish (worker-on-finish worker))
        (stop-task-worker (worker-pool worker) worker)
        (when (or (eq :wait (worker-on-finish worker))
                  (and (eq :query (worker-on-finish worker)) (query-next (worker-pool worker) worker)))
          (setf (worker-state worker) :waiting)))))

(defmethod query-next ((pool worker-pool) (worker task-worker))
  "Query if the worker should continue running or exit gracefully."
  nil)

;;; Condition Handling

(defmethod wait-on-pool-condition ((pool thread-pool) condition &optional timeout)
  "Wait for the CONDITION variable while releasing the MUTEX.
   Optionally, provide a TIMEOUT in seconds."
  (with-mutex (mutex pool)
    (wait-on-condition condition (mutex pool) timeout)))

(defmethod signal-pool-condition ((pool thread-pool) condition)
  "Signal the CONDITION variable."
  (with-mutex (mutex pool)
    (signal-condition condition)))

(defmethod broadcast-pool-condition ((pool thread-pool) condition)
  "Broadcast the CONDITION variable."
  (with-mutex (mutex pool)
    (broadcast-condition condition)))



;;; API

(defun make-thread-pool (&key (thread-limit 0))
  "Create a new thread pool with THREAD-LIMIT threads."
  (make-instance 'thread-pool :thread-limit thread-limit))

(defun make-worker-pool (&key (thread-limit 0))
  "Create a new worker pool with THREAD-LIMIT threads."
  (make-instance 'worker-pool :thread-limit thread-limit))

(defmethod start-thread ((pool thread-pool) function &key (description t))
  "Start a new thread in the pool executing FUNCTION.
   Return the thread object."
  (when (and (< 0 (thread-limit pool)) (= (thread-count pool) (thread-limit pool)))
    (error "Thread pool is at max size"))
  (let* ((t-name (format nil "[P~d|~d]<~a>" (thread-count pool) (thread-limit pool)
                         (if (not (eq t description)) description "")))
         (thread (bt:make-thread
                  (lambda ()
                    (funcall function)
                    (done pool t-name))
                  :name t-name)))
    (setf (gethash t-name (threads pool)) thread)
    thread))

(defmethod resize-pool ((pool thread-pool) new-size)
  "Resize the thread pool to NEW-SIZE threads."
  (with-mutex (mutex pool)
    (when (< new-size (thread-count pool))
      (error "New size is less than current thread count"))
    (setf (thread-limit pool) new-size)))

(defmethod join-pool-threads ((pool thread-pool))
  "Wait for all threads in the pool to finish."
  (with-mutex (mutex pool)
    (loop while (plusp (thread-count pool))
          do (wait-on-condition (conditionv pool) (mutex pool)))))

(defmethod stop-thread ((pool thread-pool) thread)
  "Stop a thread and remove it from the pool."
  (with-mutex (mutex pool)
    (bt:destroy-thread thread)
    (remhash thread (threads pool))))

(defmethod stop-all-task-workers ((pool worker-pool))
  "Stop all task workers and remove them from the pool."
  (with-mutex (mutex pool)
    (maphash #'(lambda (key value)
                 (declare (ignore key))
                 (when (bt:thread-alive-p value)
                   (bt:destroy-thread value)))
             (threads pool))
    (clrhash (threads pool))))

(defmethod worker-p ((pool worker-pool) thread)
  "Return T if THREAD is a worker in the pool."
  (with-mutex (mutex pool)
    (and (typep thread 'task-worker)
         (eq pool (worker-pool thread)))))

(defmethod waiting-task-workers ((pool worker-pool))
  "Return a list of waiting task workers."
  (with-mutex (mutex pool)
    (loop for thread being the hash-values of (threads pool)
          when (and (bt:thread-alive-p thread)
                    (not (cleve-elm.queue:queue-empty-p (task-queue pool))))
            collect thread)))

;;; Task Worker Management

(defmethod spawn-task ((pool thread-pool) (task t))
  "Spawn a task in the thread pool."
  (spawn-task pool
              (new-task (lambda () (funcall task)))))

(defmethod spawn-task ((pool thread-pool) (task async-task))
  "Spawn a task in the thread pool."
  (with-mutex (mutex pool)
    (cleve-elm.queue:enqueue (task-queue pool) task)
    (signal-condition (conditionv pool))))

(defmethod finish-task ((worker task-worker))
  "Finish a task and signal the condition.

   If the worker is set to :finish, the worker will be stopped.
   If the worker is set to :wait, the worker will wait for the next task.
   If the worker is set to :query, the worker will query if it should continue running."
  (with-mutex (mutex (worker-pool worker))
    (setf (worker-state worker) :done)
    (signal-condition (worker-condition (worker-pool worker)))
    (if (eq :finish (worker-on-finish worker))
        (stop-task-worker (worker-pool worker) worker)
        (when (or (eq :wait (worker-on-finish worker))
                  (and (eq :query (worker-on-finish worker)) (query-next (worker-pool worker) worker)))
          (setf (worker-state worker) :waiting)))))

(defmethod spawn-task-worker ((pool worker-pool) &key (description nil))
  "Make a task worker in the worker pool. This thread will wait for new tasks to be
added to the queue and not terminate on completion but dequeue the next task.
This is useful for long running tasks that need to be executed in the thread pool."
  (let* ((description (if description description (prin1-to-string (gensym "TaskWorker"))))
         (t-name (format nil "QueueWorker[P~d|~d]<~a>" (thread-count pool) (thread-limit pool)
                         description))
         (worker (make-task-worker :thread nil :task nil :pool pool :description description :state :waiting :err-state nil :err-message "" :on-finish :wait))
         (thread (bt:make-thread
                  (lambda ()
                    (unwind-protect
                         (handler-case
                             (loop while (plusp (thread-count pool))
                                   do (let ((task (cleve-elm.queue::dequeue (task-queue pool) t)))
                                        (when task
                                          (setf (worker-task worker) task)
                                          (setf (worker-state worker) :running)
                                          (sync-run task)
                                          (setf (worker-state worker) :waiting)
                                          (done pool worker))))

                           (error (e)
                             (setf (worker-state worker) :error)
                             (setf (worker-err-message worker) (princ-to-string e))
                             (done pool worker)))

                      (when (eq (worker-state worker) :done)
                        (setf (worker-state worker) :waiting)
                        (signal-condition (worker-condition (worker-pool worker))
                                          ))))
                  :name t-name)))
    (setf (worker-thread worker) thread)
    (setf (gethash t-name (threads pool)) thread)
    worker))

(defmethod stop-task-worker ((pool worker-pool) (worker task-worker))
  "Stop a task worker and remove it from the pool."
  (when (bt:thread-alive-p (worker-thread worker))
    (bt:destroy-thread (worker-thread worker)))
  (remhash (bt:thread-name (worker-thread worker)) (threads pool)))

;;; Error Handling

(define-condition task-worker-error (error)
  ((task-worker :initarg :task-worker :reader task-worker)
   (task :initarg :task :reader task)

   (description :initarg :description :reader description)
   (state :initarg :state :reader state)))

(defmethod print-object ((worker task-worker) stream)
  (print-unreadable-object (worker stream :type t :identity t)
    (format stream "~a[State:~A;Jobs:~A]" (worker-description worker) (worker-state worker) (worker-task-count worker))))

