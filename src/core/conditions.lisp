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
   :async-task-error
   :with-message-restarts
   :signal-subscriber-error
   :with-render-restarts
   :state-update-error
   :subscriber-handler-error
   :message-serialization-error   ; New
   :message-deserialization-error ; New
   :log-condition
   :with-recovery
   ;; New validation error types
   :elmtui-validation-error
   :type-validation-error
   :property-validation-error
   :constraint-validation-error
   :validation-error-path
   :validation-error-value
   :type-validation-error-expected-type
   :property-validation-error-property
   :constraint-validation-error-constraint
   ;; Prefixed condition readers; legacy generic readers remain internal.
   :message-validation-error-message
   :message-validation-error-reason
   :command-execution-error-command
   :command-execution-error-reason
   :event-loop-dispatch-error-event
   :event-loop-dispatch-error-reason
   :async-task-error-task
   :async-task-error-reason
   :state-update-error-state
   :state-update-error-reason
   :subscriber-handler-error-event
   :subscriber-handler-error-handler
   :subscriber-handler-error-reason
   :render-error-message
   :render-error-reason
   :signal-subscriber-error-signal
   :signal-subscriber-error-reason
   :message-serialization-error-data
   :message-serialization-error-underlying-condition
   :message-deserialization-error-data
   :message-deserialization-error-underlying-condition
   :validation-error-message
   ;; Event validation
   :event-validation-error))
(in-package :elmtui.core.conditions)
(defun log-condition (condition &optional (level :error))
  "Log CONDITION with the given LEVEL."
  (format *error-output* "[~A] Condition: ~A~%" level condition))



(define-condition message-validation-error (elmtui.core.errors:elmtui-error)
  ((message :initarg :message :reader message :reader message-validation-error-message)
   (reason :initarg :reason :reader reason :reader message-validation-error-reason))
  (:report (lambda (c s)
             (format s "Message validation failed: ~A~%Reason: ~A"
                     (message c) (reason c)))))

(define-condition command-execution-error (elmtui.core.errors:elmtui-error)
  ((cmd :initarg :cmd :reader cmd :reader command-execution-error-command)
   (reason :initarg :reason :reader reason :reader command-execution-error-reason))
  (:report (lambda (c s)
             (format s "Command execution failed: ~A~%Reason: ~A"
                     (cmd c) (reason c)))))

(define-condition event-loop-dispatch-error (elmtui.core.errors:elmtui-error)
  ((event :initarg :event :reader event :reader event-loop-dispatch-error-event)
   (reason :initarg :reason :reader reason :reader event-loop-dispatch-error-reason))
  (:report (lambda (c s)
             (format s "Event loop dispatch failed: ~A~%Reason: ~A"
                     (event c) (reason c)))))

(define-condition async-task-error (elmtui.core.errors:elmtui-error)
  ((task :initarg :task :reader task :reader async-task-error-task)
   (reason :initarg :reason :reader reason :reader async-task-error-reason))
  (:report (lambda (c s)
             (format s "Async task failed: ~A~%Reason: ~A"
                     (task c) (reason c)))))

(define-condition state-update-error (elmtui.core.errors:elmtui-error)
  ((state :initarg :state :reader state :reader state-update-error-state)
   (reason :initarg :reason :reader reason :reader state-update-error-reason))
  (:report (lambda (c s)
             (format s "State update failed: ~A~%Reason: ~A"
                     (state c) (reason c)))))

(define-condition subscriber-handler-error (elmtui.core.errors:elmtui-error)
  ((event :initarg :event :reader event :reader subscriber-handler-error-event)
   (handler :initarg :handler :reader handler :reader subscriber-handler-error-handler)
   (reason :initarg :reason :reader reason :reader subscriber-handler-error-reason))
  (:report (lambda (c s)
             (format s "Subscriber handler failed: ~A~%Handler: ~A~%Reason: ~A"
                     (event c) (handler c) (reason c)))))

(define-condition render-error (elmtui.core.errors:elmtui-error)
  ((message :initarg :message :reader message :reader render-error-message)
   (reason :initarg :reason :reader reason :reader render-error-reason))
  (:report (lambda (c s)
             (format s "Render error: ~A~%Reason: ~A"
                     (message c) (reason c)))))

(define-condition signal-subscriber-error (elmtui.core.errors:elmtui-error)
  ((signal :initarg :signal :reader subscriber-signal :reader signal-subscriber-error-signal)
   (reason :initarg :reason :reader reason :reader signal-subscriber-error-reason))
  (:report (lambda (c s)
             (format s "Signal subscriber error: ~A~%Reason: ~A"
                     (signal c) (reason c)))))

(defvar *log-condition* (lambda (c) (log-condition c)))

;;; == elmtui/src/core/conditions.lisp ==
(defmacro with-recovery ((condition-type
                          &key
                            (on-error '*log-condition*)
                            (restarts '(:retry :skip :abort)))
                         &body body)
  "Execute BODY with inspectable CONDITION-TYPE recovery restarts.

ON-ERROR is called whenever CONDITION-TYPE is signaled. RESTARTS is a literal
or quoted list containing any of :RETRY, :SKIP, :IGNORE-TASK, :USE-VALUE, and
:ABORT. The selected restarts surround BODY, so handlers and the debugger can
inspect the original condition and invoke recovery without re-signaling it.

:RETRY re-executes BODY, :SKIP and :IGNORE-TASK return NIL, :USE-VALUE returns a
replacement supplied to the restart, and :ABORT propagates the original
condition as an error.

Mutation: the macro itself only records the most recently signaled condition;
BODY controls application mutation. Retrying BODY can repeat its side effects,
so callers should use :RETRY only around idempotent or transactional work.
Conditions: unhandled conditions propagate normally; nothing is swallowed.

Example:
  (handler-bind
      ((message-validation-error
         (lambda (condition)
           (declare (ignore condition))
           (invoke-restart 'use-value :replacement))))
    (with-recovery (message-validation-error :restarts '(:use-value :abort))
      (validate-message message)))"
  (let* ((restart-names
           (cond
             ((and (consp restarts) (eq (first restarts) 'quote))
              (second restarts))
             ((listp restarts) restarts)
             (t
              (error "WITH-RECOVERY :RESTARTS must be a literal or quoted list, got ~S"
                     restarts))))
         (known '(:retry :skip :ignore-task :use-value :abort))
         (unknown (set-difference restart-names known))
         (attempt (gensym "ATTEMPT"))
         (last-condition (gensym "LAST-CONDITION")))
    (when unknown
      (error "WITH-RECOVERY does not recognize restart names ~S" unknown))
    `(let ((,last-condition nil))
       (declare (ignorable ,last-condition))
       (labels ((,attempt ()
                  (restart-case
                      (handler-bind
                          ((,condition-type
                             (lambda (condition)
                               (setf ,last-condition condition)
                               (funcall ,on-error condition))))
                        ,@body)
                    ,@(when (member :retry restart-names)
                        `((retry ()
                            :report "Retry the operation."
                            (,attempt))))
                    ,@(when (member :skip restart-names)
                        `((skip ()
                            :report "Skip the operation."
                            nil)))
                    ,@(when (member :ignore-task restart-names)
                        `((ignore-task ()
                            :report "Ignore this task and continue."
                            nil)))
                    ,@(when (member :use-value restart-names)
                        `((use-value (value)
                            :report "Supply a replacement value."
                            value)))
                    ,@(when (member :abort restart-names)
                        `((abort ()
                            :report "Abort and propagate the original condition."
                            (if ,last-condition
                                (error ,last-condition)
                                (error "WITH-RECOVERY aborted without a condition."))))))))
         (,attempt)))))
;;; == end/conditions.lisp ==


(defmacro with-message-restarts ((condition-var) &body forms)
  "Execute FORMS with message-specific restarts around validation failures.

While MESSAGE-VALIDATION-ERROR is active, SKIP-MESSAGE returns NIL,
REPLACE-MESSAGE returns a caller-supplied replacement, and RETRY re-executes
FORMS. CONDITION-VAR names the original condition for logging and inspection.

Mutation: only FORMS may mutate state; RETRY can repeat those effects.
Conditions: the original condition is logged but not re-signaled or swallowed;
handlers or the debugger may invoke the active restarts."
  (let ((attempt (gensym "ATTEMPT")))
    `(labels ((,attempt ()
                (restart-case
                    (handler-bind
                        ((elmtui.core.conditions:message-validation-error
                           (lambda (,condition-var)
                             (log-condition ,condition-var))))
                      ,@forms)
                  (skip-message ()
                    :report "Skip this message."
                    nil)
                  (replace-message (new-message)
                    :report "Replace the message interactively or programmatically."
                    new-message)
                  (retry ()
                    :report "Retry with the same message."
                    (,attempt)))))
       (,attempt))))


(defmacro with-render-restarts ((condition-var) &body forms)
  "Execute FORMS with render-specific recovery restarts.

While RENDER-ERROR is active, SKIP-FRAME returns NIL, FALLBACK-VIEW returns a
caller-supplied fallback value, and RETRY re-executes FORMS. CONDITION-VAR names
the original condition for logging and inspection.

Mutation: only FORMS may mutate state; RETRY can repeat those effects.
Conditions: the original condition is logged but remains available to handlers,
the debugger, and active restarts."
  (let ((attempt (gensym "ATTEMPT")))
    `(labels ((,attempt ()
                (restart-case
                    (handler-bind
                        ((elmtui.core.conditions:render-error
                           (lambda (,condition-var)
                             (log-condition ,condition-var))))
                      ,@forms)
                  (skip-frame ()
                    :report "Skip this render frame."
                    nil)
                  (fallback-view (fallback)
                    :report "Provide a fallback view."
                    fallback)
                  (retry ()
                    :report "Retry rendering."
                    (,attempt)))))
       (,attempt))))

;;;-----------------------------------------------------------------------------
;;; Serialization Conditions
;;;-----------------------------------------------------------------------------

(define-condition message-serialization-error (elmtui.core.errors:elmtui-error)
  ((data :initarg :data :reader data-being-serialized :reader message-serialization-error-data)
   (original-error :initarg :original-error :reader original-error :reader message-serialization-error-underlying-condition))
  (:report (lambda (c s)
             (format s "Failed to serialize message data: ~S~%Original Error: ~A"
                     (data-being-serialized c) (original-error c)))))

(define-condition message-deserialization-error (elmtui.core.errors:elmtui-error)
  ((serialized-data :initarg :serialized-data :reader serialized-data :reader message-deserialization-error-data)
   (original-error :initarg :original-error :reader original-error :reader message-deserialization-error-underlying-condition))
  (:report (lambda (c s)
             (format s "Failed to deserialize message data: ~S~%Original Error: ~A"
                     (serialized-data c) (original-error c)))))


(define-condition elmtui-validation-error (elmtui.core.errors:elmtui-error)
  ((path :initarg :path :initform nil :reader validation-error-path)
   (value :initarg :value :initform nil :reader validation-error-value)
   (message :initarg :message :reader error-message :reader validation-error-message))
  (:report (lambda (condition stream)
             (format stream "Validation error~@[ at ~a~]: ~a" 
                     (validation-error-path condition)
                     (error-message condition)))))

(define-condition type-validation-error (elmtui-validation-error)
  ((expected-type :initarg :expected-type :reader type-validation-error-expected-type))
  (:report (lambda (condition stream)
             (format stream "Type validation error~@[ at ~a~]: Expected ~a, got ~s" 
                     (validation-error-path condition)
                     (type-validation-error-expected-type condition)
                     (validation-error-value condition)))))

(define-condition property-validation-error (elmtui-validation-error)
  ((property :initarg :property :reader property-validation-error-property))
  (:report (lambda (condition stream)
             (format stream "Property validation error for ~a~@[ at ~a~]: ~a" 
                     (property-validation-error-property condition)
                     (validation-error-path condition)
                     (error-message condition)))))

(define-condition constraint-validation-error (elmtui-validation-error)
  ((constraint :initarg :constraint :reader constraint-validation-error-constraint))
  (:report (lambda (condition stream)
             (format stream "Constraint validation error~@[ at ~a~]: ~a violated" 
                     (validation-error-path condition)
                     (constraint-validation-error-constraint condition)))))

;; Duplicate removed — the canonical elmtui-validation-error is defined above at line 183

;; Event validation error
(define-condition event-validation-error (elmtui-validation-error)
  ((event-type :initarg :event-type :reader event-validation-error-type))
  (:report (lambda (condition stream)
             (format stream "Event validation error: Invalid event of type ~A: ~S"
                     (event-validation-error-type condition)
                     (validation-error-value condition)))))

;;; USAGE EXAMPLES:
;; (with-recovery (message-validation-error)
;;   (validate-message some-msg))
;; (with-recovery (async-task-error :on-error #'log-condition :restarts '(:retry :abort))
;;   (interpret-cmd some-cmd))

;;; CONTRACTS:
;; - All critical operations should signal these conditions on failure.
;; - Recovery is possible via dynamic restarts, rollbacks, or logging.
