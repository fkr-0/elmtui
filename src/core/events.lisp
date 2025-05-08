;;;===============================================================
;;; File: src/core/events.lisp
;;; Advanced Event & Message Layer (using clevelib)
(uiop:define-package :elmtui.core.events
  (:use :cl)
  (:import-from :elmtui.core.conditions :log-condition :with-recovery)
  (:import-from :clevelib.message
   :message :make-message :message-type :message-data :message-state
                :broadcast-p :capture-p :bubble-p :propagation-stopped-p
                :stop-propagation)
  (:import-from :clevelib.api
   :on-message :relay-message)
  (:export :message
   :make-message
           :message-p
   :message-type
           :message-data
   :message-state
           :broadcast-p
   :capture-p
           :bubble-p
   :propagation-stopped-p
           :stop-propagation
   :cmd
           :make-cmd
   :send-message
           :validate-message
   :log-message
           :*message-contracts*
           ;; Serialization
           :serialize-message
            :deserialize-message))
            ; Removed export of *app-sender*
(in-package :elmtui.core.events)

;; *app-sender* is now defined in elmtui.core.globals

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
  (let* ((m-type (message-type msg))
         (contract (gethash m-type *message-contracts*)))
    (when contract
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

;; (defun make-cmd (type &rest args)
;;   "Construct a CMD struct."
;;   (make-cmd :type type :args args))

(defun send-message (target msg)
  "Send MSG to TARGET using clevelib's on-message/relay-message.
   Validates and logs the message. Handles validation and dispatch errors."
  (with-recovery (elmtui.core.conditions:message-validation-error)
    (validate-message msg))
  (log-message msg :send)
  (with-recovery (elmtui.core.conditions:command-execution-error)
    (handler-case
        (on-message target msg) ; This is clevelib.api:on-message
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

;;;-----------------------------------------------------------------------------
;;; Message Serialization / Deserialization
;;;-----------------------------------------------------------------------------
;;; Basic S-expression based serialization. Assumes message-data is serializable
;;; using standard Lisp WRITE/READ. Complex objects or closures in message-data
;;; will not work with this simple approach.

(defun serialize-message-data (data)
  "Serializes message data to a string using WRITE-TO-STRING."
  ;; Use print-readably to ensure symbols are package-qualified etc.
  (handler-case
      (write-to-string data :pretty nil :readably t :escape t)
    (error (original-error)
      (restart-case
                  (error 'elmtui.core.conditions:message-serialization-error
                         :data data
                          :original-error original-error)
         (use-default-value (&optional (default-value "\":error\"")) ; Default to readable :error symbol string
           ;; Quote the symbol in the report format string
           :report (lambda (s) (format s "Return a default string value instead (defaults to ~S)." 'default-value))
           default-value)
         (use-value (value)
          :report "Interactively specify a string value to use instead."
          :interactive (lambda () (format *query-io* "Enter string value to use: ") (read *query-io*))
          value)
        (return-nil ()
          :report "Return NIL instead of serialized data (may cause issues downstream)."
          nil)))))

(defun deserialize-message-data (serialized-data-string)
  "Deserializes message data from a string using READ-FROM-STRING."
  (when serialized-data-string
    (handler-case
        (read-from-string serialized-data-string)
      (error (original-error)
        (restart-case
            (error 'elmtui.core.conditions:message-deserialization-error
                   :serialized-data serialized-data-string
                    :original-error original-error)
           (use-default-value (&optional (default-value nil))
             ;; Quote the symbol in the report format string
             :report (lambda (s) (format s "Return a default Lisp value instead (defaults to ~S)." 'default-value))
             default-value)
           (use-value (value)
            :report "Interactively specify a Lisp value to use instead."
            :interactive (lambda () (format *query-io* "Enter Lisp form to evaluate for value: ") (eval (read *query-io*)))
            value)
          (return-nil ()
            :report "Return NIL instead of deserialized data (may cause issues downstream)."
            nil))))))

(defun serialize-message (msg)
  "Serializes a clevelib message object into a property list.
   Focuses on :type and :data. Other slots (state, handles) are lost.
   Returns a plist like '(:type <type> :data \"<serialized-data-string>\") or NIL if serialization fails and is not recovered."
  (when (typep msg 'message)
    (let ((msg-type (message-type msg))
          (msg-data (message-data msg)))
      ;; serialize-message-data now handles errors and restarts
      (let ((serialized-data (serialize-message-data msg-data)))
        (when serialized-data ; Only return plist if serialization succeeded or was recovered with a value
          `(:type ,msg-type :data ,serialized-data))))))

(defun deserialize-message (representation)
  "Deserializes a property list representation back into a clevelib message object.
   Expects a plist like '(:type <type> :data \"<serialized-data-string>\").
   Returns a new message object or NIL if deserialization fails and is not recovered."
  (when (and (listp representation) (getf representation :type) (getf representation :data))
    (let ((msg-type (getf representation :type))
          (serialized-data-string (getf representation :data)))
      ;; deserialize-message-data now handles errors and restarts
      (let ((msg-data (deserialize-message-data serialized-data-string)))
        ;; If deserialization returned nil (e.g., via return-nil restart),
        ;; we still create the message but with nil data.
        ;; A different restart could provide alternative data.
        (make-message :type msg-type :data msg-data)))))
