;;;===============================================================
;;; File: src/core/events.lisp
;;; Advanced Event & Message Layer (using clevelib)
(uiop:define-package :elmtui.core.events
  (:use :cl :alexandria) ; Added alexandria for once-only
  (:import-from :elmtui.core.conditions :log-condition :with-recovery)
  (:import-from :clevelib.message
    :message :make-message :message-type :message-data :message-state
                 :broadcast-p :capture-p :bubble-p :propagation-stopped-p
                 :stop-propagation)
  (:import-from :clevelib.api
    :on-message :relay-message)
  (:import-from :elmtui.state.msg
                :message-schema #:message-schema-name #:message-schema-variants #:message-schema-docstring
                :variant-definition #:variant-definition-name #:variant-definition-args #:variant-definition-arg-spec #:variant-definition-constructor-name
                :arg-def #:arg-def-type #:arg-def-keyword
                :*message-schemas*)
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
            :deserialize-message
            ;; Lifecycle Hooks
            :*before-send-message-hooks*
            :*after-send-message-hooks*
            :add-before-send-message-hook
            :remove-before-send-message-hook
            :add-after-send-message-hook
            :remove-after-send-message-hook))
            ; Removed export of *app-sender*
(in-package :elmtui.core.events)

;; *app-sender* is now defined in elmtui.core.globals

(defvar *message-contracts* (make-hash-table :test 'equal)
 "Registry of message contracts for validation and documentation.")

(defvar *message-priorities* (make-hash-table :test 'equal)
 "Stub: Registry for message priorities. Extend for advanced priority handling.")

(defvar *before-send-message-hooks* nil
 "A list of functions to be called before a message is sent via SEND-MESSAGE.
Each hook function should accept the target and the message as arguments.")

(defvar *after-send-message-hooks* nil
 "A list of functions to be called after a message has been processed by SEND-MESSAGE.
Each hook function should accept the target and the message as arguments.")

(defun add-before-send-message-hook (hook-fn)
 "Adds HOOK-FN to the list of hooks executed before sending a message."
 (pushnew hook-fn *before-send-message-hooks* :test #'eq))

(defun remove-before-send-message-hook (hook-fn)
 "Removes HOOK-FN from the list of hooks executed before sending a message."
 (setf *before-send-message-hooks* (remove hook-fn *before-send-message-hooks* :test #'eq)))

(defun add-after-send-message-hook (hook-fn)
 "Adds HOOK-FN to the list of hooks executed after sending a message."
 (pushnew hook-fn *after-send-message-hooks* :test #'eq))

(defun remove-after-send-message-hook (hook-fn)
 "Removes HOOK-FN from the list of hooks executed after sending a message."
 (setf *after-send-message-hooks* (remove hook-fn *after-send-message-hooks* :test #'eq)))

(defmacro register-message-contract (type contract-fn &optional (priority 0))
  "Register a message contract and optional priority for TYPE.
Stub for richer contract registration and enforcement."
  `(progn
     (setf (gethash ,type *message-contracts*) ,contract-fn)
     (setf (gethash ,type *message-priorities*) ,priority)))


(defun validate-message-via-schema (msg message-type-name schema)
  "Validates MSG data (a list) against the schema from DEFMSG."
  (unless (listp (message-data msg))
    (signal 'elmtui.core.conditions:message-validation-error
            :message msg
            :reason (format nil "Message data for ~S is not a list: ~S" message-type-name (message-data msg)))
    (return-from validate-message-via-schema nil))

  (let* ((msg-data-list (message-data msg))
         (variant-key (first msg-data-list))
         (variant-def (find variant-key (message-schema-variants schema) :key #'variant-definition-name)))

    (unless variant-def
      (signal 'elmtui.core.conditions:message-validation-error
              :message msg
              :reason (format nil "Unknown variant ~S for message type ~S." variant-key message-type-name))
      (return-from validate-message-via-schema nil))

    (let ((expected-args (variant-definition-args variant-def))
          (provided-args-plist (rest msg-data-list)))

      ;; Check for correct number of arguments (keyword pairs)
      (unless (= (length provided-args-plist) (* 2 (length expected-args)))
        (signal 'elmtui.core.conditions:message-validation-error
                :message msg
                :reason (format nil "Incorrect number of arguments for variant ~S of ~S. Expected ~A, got ~A."
                                variant-key message-type-name (* 2 (length expected-args)) (length provided-args-plist)))
        (return-from validate-message-via-schema nil))


      ;; Check keywords and types
      (loop for arg-def in expected-args
            for expected-keyword = (arg-def-keyword arg-def)
            for expected-type = (arg-def-type arg-def)
            for value = (getf provided-args-plist expected-keyword :not-found)
            do
         (when (eq value :not-found)
           (signal 'elmtui.core.conditions:message-validation-error
                   :message msg
                   :reason (format nil "Missing keyword argument ~S for variant ~S of ~S."
                                   expected-keyword variant-key message-type-name))
           (return-from validate-message-via-schema nil))
         (unless (typep value expected-type)
           (signal 'elmtui.core.conditions:message-validation-error
                   :message msg
                   :reason (format nil "Type error for argument ~S in variant ~S of ~S. Expected ~S, got ~S (value: ~S)."
                                   expected-keyword variant-key message-type-name expected-type (type-of value) value))
           (return-from validate-message-via-schema nil))))
    t)) ; Validation passed

(defun validate-message (msg)
  "Validate MSG against its explicit contract or its schema from DEFMSG.
   Signals message-validation-error if invalid."
  (let* ((m-type-name (message-type msg)) ; This is the message type symbol, e.g., 'AppMsg
         (explicit-contract (gethash m-type-name *message-contracts*)))
    (cond
      (explicit-contract
       (unless (funcall explicit-contract msg)
         (signal 'elmtui.core.conditions:message-validation-error
                 :message msg
                 :reason (format nil "Explicit contract validation failed for message type ~S." m-type-name))))
      ((gethash m-type-name elmtui.state.msg:*message-schemas*)
       (validate-message-via-schema msg m-type-name (gethash m-type-name elmtui.state.msg:*message-schemas*)))
      (t
       ;; No explicit contract and no schema found, consider it valid or warn.
       ;; For now, let's assume it's valid if no contract/schema is defined.
       ;; Alternatively, could warn: (warn "No contract or schema found for message type ~S" m-type-name)
       t))))

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
   Validates, logs the message, and calls lifecycle hooks. Handles validation and dispatch errors."
  (dolist (hook *before-send-message-hooks*)
    (funcall hook target msg))
  (with-recovery (elmtui.core.conditions:message-validation-error)
    (validate-message msg))
  (log-message msg :send)
  (let ((result nil) (successp nil))
    (with-recovery (elmtui.core.conditions:command-execution-error)
      (handler-case
          (progn
            (setf result (on-message target msg)) ; This is clevelib.api:on-message
            (setf successp t))
        (error (e)
          (signal 'elmtui.core.conditions:command-execution-error
                  :cmd msg
                  :reason e))))
    (dolist (hook *after-send-message-hooks*)
      (funcall hook target msg successp result)) ; Pass success status and result to after hooks
    result)) ; Return the result of on-message

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
