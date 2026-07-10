;;; src/events/async.lisp
(in-package :cl-events.async)

;; ---------------------------------------------------------------------------
;; Promise
;; ---------------------------------------------------------------------------

(defgeneric await (obj &optional timeout))

(defstruct (promise (:constructor %make-promise))
  value
  error
  (resolved nil :type boolean)
  (cancelled nil :type boolean)
  lock
  condition)

(defun make-promise ()
  (%make-promise :lock (bt:make-lock "promise-lock")
                 :condition (bt:make-condition-variable :name "promise-cv")))

(defun resolve-promise (p value)
  (bt:with-lock-held ((promise-lock p))
    (unless (promise-resolved p)
      (setf (promise-value p) value
            (promise-error p) nil
            (promise-cancelled p) nil
            (promise-resolved p) t)
      (bt:condition-notify (promise-condition p))))
  value)

(defun reject-promise (p error)
  (bt:with-lock-held ((promise-lock p))
    (unless (promise-resolved p)
      (setf (promise-error p) error
            (promise-value p) nil
            (promise-cancelled p) nil
            (promise-resolved p) t)
      (bt:condition-notify (promise-condition p))))
  nil)

(defmethod promise-cancel ((p promise))
  (bt:with-lock-held ((promise-lock p))
    (unless (promise-resolved p)
      (setf (promise-resolved p) t
            (promise-cancelled p) t
            (promise-value p) nil
            (promise-error p) nil)
      (bt:condition-notify (promise-condition p))))
  t)

(defmethod promise-cancelled-p ((p promise))
  (bt:with-lock-held ((promise-lock p))
    (promise-cancelled p)))

(defmethod await ((p promise) &optional (timeout nil))
  (bt:with-lock-held ((promise-lock p))
    (unless (promise-resolved p)
      (cond
        ((and timeout (zerop timeout))
         ;; timeout=0: return immediately without waiting
         nil)
        (timeout
         ;; timeout>0: wait up to timeout seconds
         (loop until (promise-resolved p)
               do (bt:condition-wait (promise-condition p) (promise-lock p) :timeout timeout)))
        (t
         ;; timeout=nil: wait indefinitely
         (loop until (promise-resolved p)
               do (bt:condition-wait (promise-condition p) (promise-lock p))))))
    (if (promise-error p)
        (error (promise-error p))
        (promise-value p))))

;; ---------------------------------------------------------------------------
;; Async task
;; ---------------------------------------------------------------------------

(defstruct (async-task (:constructor %make-async-task))
  function
  args
  thread
  (status :pending)
  lock
  condition
  result
  error
  promise
  (finished nil :type boolean))

(defun new-task (function &rest args)
  (%make-async-task
   :function function
   :args args
   :lock (bt:make-lock "async-task-lock")
   :condition (bt:make-condition-variable :name "async-task-cv")
   :promise (make-promise)))

(defun async-run (task)
  (handler-case
      (progn
        (setf (async-task-status task) :running)
        (setf (async-task-result task)
              (apply (async-task-function task) (async-task-args task)))
        (setf (async-task-status task) :completed)
        (setf (async-task-finished task) t)
        (resolve-promise (async-task-promise task) (async-task-result task))
        (bt:condition-notify (async-task-condition task)))
    (error (err)
      (setf (async-task-status task) :error)
      (setf (async-task-error task) err)
      (setf (async-task-finished task) t)
      (reject-promise (async-task-promise task) err)
      (bt:condition-notify (async-task-condition task)))))

(defun async-exec (task &optional name)
  (unless (async-task-finished task)
    (setf (async-task-thread task)
          (bt:make-thread (lambda () (async-run task))
                          :name (or name "async-task"))))
  task)

(defun async-task-finished-p (task)
  (bt:with-lock-held ((async-task-lock task))
    (async-task-finished task)))

(defmethod await ((task async-task) &optional (timeout nil))
  (await (async-task-promise task) timeout))

;; ---------------------------------------------------------------------------
;; Promise combinators
;; ---------------------------------------------------------------------------

(defun %ensure-promise (obj)
  (cond
    ((typep obj 'promise) obj)
    ((typep obj 'async-task) (async-task-promise obj))
    (t (error "Expected promise or async-task, got ~S" obj))))

(defun chain (promise-or-task callback)
  (let* ((p (make-promise))
         (src (%ensure-promise promise-or-task)))
    (bt:make-thread
     (lambda ()
       (handler-case
           (resolve-promise p (funcall callback (await src)))
         (error (e) (reject-promise p e))))
     :name "promise-chain")
    p))

(defun all (promises-or-tasks)
  (let ((p (make-promise)))
    (bt:make-thread
     (lambda ()
       (handler-case
           (resolve-promise p (mapcar (lambda (obj)
                                        (await (%ensure-promise obj)))
                                      promises-or-tasks))
         (error (e) (reject-promise p e))))
     :name "promise-all")
    p))

(defun race (promises-or-tasks)
  (let ((p (make-promise))
        (done nil)
        (lock (bt:make-lock "promise-race-lock")))
    (dolist (obj promises-or-tasks)
      (let ((src (%ensure-promise obj)))
        (bt:make-thread
         (lambda ()
           (handler-case
               (let ((val (await src)))
                 (bt:with-lock-held (lock)
                   (unless done
                     (setf done t)
                     (resolve-promise p val))))
             (error (e)
               (bt:with-lock-held (lock)
                 (unless done
                   (setf done t)
                   (reject-promise p e))))))
         :name "promise-race-worker")))
    p))

;; ---------------------------------------------------------------------------
;; Existing API (compat with current cl-events)
;; ---------------------------------------------------------------------------

(defun spawn-task (fn &key name)
  (bt:make-thread fn :name (or name "task")))

(defun future (fn)
  (let ((mb (cl-events.channel:make-mailbox)))
    (spawn-task (lambda () (cl-events.channel:mb-put mb (funcall fn))))
    mb))

(defmethod await ((mb cl-events.channel:mailbox) &optional (timeout nil))
  (declare (ignore timeout))
  (cl-events.channel:mb-take mb))

(defun cancel (task)
  (cond
    ((and task (bt:threadp task))
     (ignore-errors (bt:destroy-thread task))
     t)
    ((typep task 'async-task)
     (ignore-errors (bt:destroy-thread (async-task-thread task)))
     (bt:with-lock-held ((async-task-lock task))
       (setf (async-task-finished task) t)
       (setf (async-task-status task) :cancelled)
       (bt:condition-notify (async-task-condition task)))
     t)
    (t nil)))

(defun schedule-after (seconds fn)
  (bt:make-thread
   (lambda ()
     (sleep seconds)
     (handler-case
         (funcall fn)
       (error (e)
         (format *error-output* "[cl-events.async] Error in schedule-after: ~A~%" e))))
   :name (format nil "schedule-after-~A" seconds)))

(defun schedule-every (seconds fn)
  (bt:make-thread
   (lambda ()
     (loop
       (sleep seconds)
       (handler-case
           (funcall fn)
         (error (e)
           (format *error-output* "[cl-events.async] Error in schedule-every: ~A~%" e)))))
   :name (format nil "schedule-every-~A" seconds)))
