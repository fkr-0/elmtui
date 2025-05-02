;;;===============================================================
;;; File: src/core/async.lisp
;;; Async Command Interpreter (using clevelib)
(uiop:define-package :elmtui.core.async
  (:use :cl)
  (:import-from :clevelib.async
    :async-task :new-task :async-exec :cancel-async-task
    :async-task-finished-p :async-task-result :async-task-status
    :promise :resolve-promise :reject-promise :await)
  (:export :cmd-async
           :cmd-batch
           :interpret-cmd
           :*async-tasks*
           :*async-errors*
           :await-cmd
           :cancel-cmd))
(in-package :elmtui.core.async)

(defvar *async-tasks* (make-hash-table :test 'equal) "Active async tasks.")
(defvar *async-errors* (make-hash-table :test 'equal) "Async task errors.")

(defun cmd-async (function &rest args)
  "Construct a CMD that will run FUNCTION with ARGS asynchronously."
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:async-task-error)
    (let ((task (apply #'new-task function args)))
      (setf (gethash (gensym) *async-tasks*) task)
      (list :async task))))

(defun cmd-batch (&rest cmds)
  "Construct a CMD grouping multiple CMDS."
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:command-execution-error)
    (list :batch cmds)))

(defun interpret-cmd (cmd)
  "Execute CMD: spawn async-task(s) or sequence. Handles errors with restarts and async-task-error."
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:async-task-error)
    (handler-case
        (ecase (car cmd)
          (:async
           (let ((task (cadr cmd)))
             (async-exec task)
             task))
          (:batch
           (mapcar #'interpret-cmd (cadr cmd))))
      (error (e)
        (setf (gethash (gensym) *async-errors*) e)
        (signal 'elmtui.core.conditions:async-task-error
                :task cmd
                :reason e)))))

(defun await-cmd (cmd)
  "Wait for CMD (async-task) to finish and return result. Handles async-task-error."
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:async-task-error)
    (etypecase (car cmd)
      (:async (handler-case
                  (await (cadr cmd))
                (error (e)
                  (signal 'elmtui.core.conditions:async-task-error
                          :task cmd
                          :reason e))))
      (:batch (mapcar #'await-cmd (cadr cmd))))))

(defun cancel-cmd (cmd)
  "Cancel CMD (async-task). Handles async-task-error."
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:async-task-error)
    (etypecase (car cmd)
      (:async (handler-case
                  (cancel-async-task (cadr cmd))
                (error (e)
                  (signal 'elmtui.core.conditions:async-task-error
                          :task cmd
                          :reason e))))
      (:batch (mapcar #'cancel-cmd (cadr cmd))))))

;;; USAGE EXAMPLES:
;; (let ((cmd (cmd-async #'sleep 1)))
;;   (interpret-cmd cmd)
;;   (await-cmd cmd))

;;; CONTRACTS:
;; - All async commands are executed as clevelib.async tasks.
;; - Errors are handled with CL conditions and restarts.
;; - Supports batching and cancellation of commands.
