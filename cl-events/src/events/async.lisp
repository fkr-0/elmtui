;;; src/events/async.lisp
(in-package :cl-events.async)

(defun spawn-task (fn &key name)
  (bt:make-thread fn :name (or name "task")))

(defun future (fn)
  (let ((mb (cl-events.channel:make-mailbox)))
    (spawn-task (lambda () (cl-events.channel:mb-put mb (funcall fn))))
    mb))

(defun await (mb) (cl-events.channel:mb-take mb))
(defun cancel (task)
  (when (and task (bt:threadp task))
    (ignore-errors (bt:destroy-thread task))
    t))

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
