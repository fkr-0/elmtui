;;;===============================================================
;;; File: src/core/conditions.lisp
;;; Advanced Condition System for ElmTUI (dynamic restarts, rollbacks, logging)
(uiop:define-package :elmtui.core.conditions
  (:use :cl) ; Removed :elmtui.state
  (:export
   :message-validation-error
   :command-execution-error
   :render-error
   :event-loop-dispatch-error
   :async-task-error
   :with-message-restarts
   :with-async-restarts
   :with-render-restarts
   :state-update-error
   :subscriber-handler-error
   :message-serialization-error   ; New
   :message-deserialization-error ; New
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

(define-condition render-error (error)
  ((message :initarg :message :reader message)
   (reason :initarg :reason :reader reason))
  (:report (lambda (c s)
             (format s "Render error: ~A~%Reason: ~A"
                     (message c) (reason c)))))


(defvar *log-condition* (lambda (c) (log-condition c)))

;;; == elmtui/src/core/conditions.lisp ==
(defmacro with-recovery ((condition-type &key (on-error '*log-condition*) (restarts '(:retry :skip :abort))) &body body)
  "Wrap BODY with recovery for CONDITION-TYPE, supporting restarts and logging."
  `(handler-bind
       ((,condition-type
          (lambda (c)
            (funcall ,on-error c)
            (restart-case
                ;; Re-evaluate body in each restart; no compiled-function returned
                (progn ,@body)
              ,@(when (member :retry restarts)
                  `((retry () :report "Retry the operation."
                     (progn ,@body))))
              ,@(when (member :skip restarts)
                  '((skip () :report "Skip the operation."
                     nil)))
              ,@(when (member :abort restarts)
                  '((abort () :report "Abort and propagate the error."
                     (signal c))))))))
     ,@body))
;;; == end/conditions.lisp ==


(defmacro with-message-restarts ((condition-var) &body forms) ; Renamed body to forms
  "Handle message failures with DRY restarts: skip, replace, retry."
  `(block with-message-restarts
     (handler-bind
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
                  (return-from with-message-restarts new-message))
                (retry ()
                  :report "Retry with the same message."
                  (return-from with-message-restarts (progn ,@forms))))))) ; Use forms
       ,@forms))) ; Use forms

(defmacro with-async-restarts ((condition-var) &body forms) ; Renamed body to forms
  "Handle async task failures with DRY restarts: ignore, rollback, replace, provide result."
  `(block with-async-restarts
     (handler-bind
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
                  ;; Use fully qualified name as state is loaded first now
                  (when (fboundp 'elmtui.state:rollback-state) (funcall 'elmtui.state:rollback-state))
                  (return-from with-async-restarts nil))
                (replace-task (new-task)
                  :report "Replace the async task interactively or programmatically."
                  ;; Return the new task value, don't funcall body
                  (return-from with-async-restarts new-task))
                (provide-result (result)
                  :report "Provide a custom result for this task."
                  (return-from with-async-restarts result))
                (retry ()
                  :report "Retry the async task."
                  (return-from with-async-restarts (progn ,@forms))))))) ; Use forms
       ,@forms))) ; Use forms

(defmacro with-render-restarts ((condition-var) &body forms) ; Renamed body to forms
  "Handle render/view failures with DRY restarts: skip, fallback, retry."
  `(block with-render-restarts
     (handler-bind
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
                  (return-from with-render-restarts (progn ,@forms))))))) ; Use forms
       ,@forms))) ; Use forms

;;;-----------------------------------------------------------------------------
;;; Serialization Conditions
;;;-----------------------------------------------------------------------------

(define-condition message-serialization-error (error)
  ((data :initarg :data :reader data-being-serialized)
   (original-error :initarg :original-error :reader original-error))
  (:report (lambda (c s)
             (format s "Failed to serialize message data: ~S~%Original Error: ~A"
                     (data-being-serialized c) (original-error c)))))

(define-condition message-deserialization-error (error)
  ((serialized-data :initarg :serialized-data :reader serialized-data)
   (original-error :initarg :original-error :reader original-error))
  (:report (lambda (c s)
             (format s "Failed to deserialize message data: ~S~%Original Error: ~A"
                     (serialized-data c) (original-error c)))))


;;; USAGE EXAMPLES:
;; (with-recovery (message-validation-error)
;;   (validate-message some-msg))
;; (with-recovery (async-task-error :on-error #'log-condition :restarts '(:retry :abort))
;;   (interpret-cmd some-cmd))

;;; CONTRACTS:
;; - All critical operations should signal these conditions on failure.
;; - Recovery is possible via dynamic restarts, rollbacks, or logging.
