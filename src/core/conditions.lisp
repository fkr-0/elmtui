;;;===============================================================
;;; File: src/core/conditions.lisp
;;; Advanced Condition System for ElmTUI (dynamic restarts, rollbacks, logging)
(uiop:define-package :elmtui.core.conditions
  (:use :cl)
  (:export
    :message-validation-error
    :command-execution-error
    :event-loop-dispatch-error
    :async-task-error
    :state-update-error
    :subscriber-handler-error
    :log-condition
    :with-recovery))
(in-package :elmtui.core.conditions)

(defun log-condition (condition &optional (level :error))
  "Log CONDITION with the given LEVEL."
  (format *error-output* "[~A] Condition: ~A~%" level condition))

(define-condition message-validation-error (error)
  ((message :initarg :message :reader message)
   (reason :initarg :reason :reader reason))
  (:report (lambda (c s)
             (format s "Message validation failed: ~A~%Reason: ~A"
                     (message c) (reason c)))))

(define-condition command-execution-error (error)
  ((cmd :initarg :cmd :reader cmd)
   (reason :initarg :reason :reader reason))
  (:report (lambda (c s)
             (format s "Command execution failed: ~A~%Reason: ~A"
                     (cmd c) (reason c)))))

(define-condition event-loop-dispatch-error (error)
  ((event :initarg :event :reader event)
   (reason :initarg :reason :reader reason))
  (:report (lambda (c s)
             (format s "Event loop dispatch failed: ~A~%Reason: ~A"
                     (event c) (reason c)))))

(define-condition async-task-error (error)
  ((task :initarg :task :reader task)
   (reason :initarg :reason :reader reason))
  (:report (lambda (c s)
             (format s "Async task failed: ~A~%Reason: ~A"
                     (task c) (reason c)))))

(define-condition state-update-error (error)
  ((state :initarg :state :reader state)
   (reason :initarg :reason :reader reason))
  (:report (lambda (c s)
             (format s "State update failed: ~A~%Reason: ~A"
                     (state c) (reason c)))))

(define-condition subscriber-handler-error (error)
  ((event :initarg :event :reader event)
   (handler :initarg :handler :reader handler)
   (reason :initarg :reason :reader reason))
  (:report (lambda (c s)
             (format s "Subscriber handler failed: ~A~%Handler: ~A~%Reason: ~A"
                     (event c) (handler c) (reason c)))))

(defmacro with-recovery ((condition-type &key (on-error 'log-condition) (restarts '(:retry :skip :abort))) &body body)
  "Wrap BODY with recovery for CONDITION-TYPE, supporting restarts and logging."
  `(handler-bind
       ((,condition-type
         (lambda (c)
           (funcall ,on-error c)
           (restart-case
               (signal c)
             ,@(when (member :retry restarts)
                 '((retry () :report "Retry the operation." (return-from with-recovery (progn ,@body)))))
             ,@(when (member :skip restarts)
                 '((skip () :report "Skip the operation." (return-from with-recovery nil))))
             ,@(when (member :abort restarts)
                 '((abort () :report "Abort and propagate error." (error c))))))))
     ,@body))

(defmacro with-message-restarts ((condition-var) &body body)
  "Handle message failures with DRY restarts: skip, replace, retry."
  `(handler-bind
       ((elmtui.core.conditions:message-validation-error
         (lambda (,condition-var)
           (log-condition ,condition-var)
           (restart-case
               (signal ,condition-var)
             (skip-message ()
               :report "Skip this message."
               (return-from with-message-restarts nil))
             (replace-message (new-message)
               :report "Replace the message interactively or programmatically."
               (return-from with-message-restarts (funcall body new-message)))
             (retry ()
               :report "Retry with the same message."
               (return-from with-message-restarts (progn ,@body)))))))
     ,@body))

(defmacro with-async-restarts ((condition-var) &body body)
  "Handle async task failures with DRY restarts: ignore, rollback, replace, provide result."
  `(handler-bind
       ((elmtui.core.conditions:async-task-error
         (lambda (,condition-var)
           (log-condition ,condition-var)
           (restart-case
               (signal ,condition-var)
             (ignore-task ()
               :report "Ignore/discard this async task."
               (return-from with-async-restarts nil))
             (rollback-state ()
               :report "Rollback state to previous checkpoint."
               (when (fboundp 'rollback-state) (rollback-state))
               (return-from with-async-restarts nil))
             (replace-task (new-task)
               :report "Replace the async task interactively or programmatically."
               (return-from with-async-restarts (funcall body new-task)))
             (provide-result (result)
               :report "Provide a custom result for this task."
               (return-from with-async-restarts result))
             (retry ()
               :report "Retry the async task."
               (return-from with-async-restarts (progn ,@body)))))))
     ,@body))

(defmacro with-render-restarts ((condition-var) &body body)
  "Handle render/view failures with DRY restarts: skip, fallback, retry."
  `(handler-bind
       ((elmtui.core.conditions:render-error
         (lambda (,condition-var)
           (log-condition ,condition-var)
           (restart-case
               (signal ,condition-var)
             (skip-frame ()
               :report "Skip this render frame."
               (return-from with-render-restarts nil))
             (fallback-view (fallback)
               :report "Provide a fallback view."
               (return-from with-render-restarts fallback))
             (retry ()
               :report "Retry rendering."
               (return-from with-render-restarts (progn ,@body)))))))
     ,@body))

;;; USAGE EXAMPLES:
;; (with-recovery (message-validation-error)
;;   (validate-message some-msg))
;; (with-recovery (async-task-error :on-error #'log-condition :restarts '(:retry :abort))
;;   (interpret-cmd some-cmd))

;;; CONTRACTS:
;; - All critical operations should signal these conditions on failure.
;; - Recovery is possible via dynamic restarts, rollbacks, or logging.
