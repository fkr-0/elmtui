;;;===============================================================
;;; File: src/core/events.lisp
;;; Advanced Event & Message Layer (using clevelib)
(uiop:define-package :elmtui.core.events
  (:use :cl)
  (:import-from :clevelib.message
    :message :make-message :message-type :message-data :message-state
    :broadcast-p :capture-p :bubble-p :propagation-stopped-p
    :stop-propagation)
  (:import-from :clevelib.api
    :on-message :relay-message)
  (:export :message
           :cmd
           :make-cmd
           :send-message
           :validate-message
           :log-message
           :*message-contracts*))
(in-package :elmtui.core.events)

(defvar *message-contracts* (make-hash-table :test 'equal)
  "Registry of message contracts for validation and documentation.")

(defvar *message-priorities* (make-hash-table :test 'equal)
  "Stub: Registry for message priorities. Extend for advanced priority handling.")

(defmacro register-message-contract (type contract-fn &optional (priority 0))
  "Register a message contract and optional priority for TYPE.
Stub for richer contract registration and enforcement."
  `(progn
     (setf (gethash ,type *message-contracts*) ,contract-fn)
     (setf (gethash ,type *message-priorities*) ,priority)))

(defun validate-message (msg)
  "Validate MSG against its contract. Signal message-validation-error if invalid."
  (let ((type (message-type msg)))
    (when-let ((contract (gethash type *message-contracts*)))
      (unless (funcall contract msg)
        (signal 'elmtui.core.conditions:message-validation-error
                :message msg
                :reason "Contract validation failed")))))

(defun log-message (msg &optional (phase :info))
  "Log MSG with tracing for message flows."
  (format t "[~A] Message: ~A Type: ~A Data: ~A State: ~A~%"
          phase msg (message-type msg) (message-data msg) (message-state msg)))

(defstruct cmd
  "A command for side-effects: (:async FUNCTION ARGS...) or (:batch [CMDS]).
   Contract: type ∈ :async|:batch|…; args ∈ list."
  type
  args)

(defun make-cmd (type &rest args)
  "Construct a CMD struct."
  (make-cmd :type type :args args))

(defun send-message (target msg)
  "Send MSG to TARGET using clevelib's on-message/relay-message.
   Validates and logs the message. Handles validation and dispatch errors."
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:message-validation-error)
    (validate-message msg))
  (log-message msg :send)
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:command-execution-error)
    (handler-case
        (on-message target msg)
      (error (e)
        (signal 'elmtui.core.conditions:command-execution-error
                :cmd msg
                :reason e)))))

;;; USAGE EXAMPLES:
;; (defparameter *relay* (make-instance 'clevelib.ems:ems))
;; (defparameter *msg* (make-message :custom-type '(:foo 42)))
;; (send-message *relay* *msg*)

;;; CONTRACTS:
;; - All messages must be instances of clevelib.message:message or subclasses.
;; - Message types must be registered in *message-contracts* for validation.
;; - Message flows are logged and traced.
;; - Commands are constructed with make-cmd and dispatched via the event loop.
