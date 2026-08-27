;;;===============================================================
;;; File: src/core/events.lisp
;;; Advanced Event & Message Layer (using cl-events)
(uiop:define-package :elmtui.core.events
  (:use :cl :alexandria)
  (:import-from :elmtui.core.conditions :log-condition :with-recovery)
  (:import-from :cl-events.types
   :message :make-message :message-type :message-data)
  (:import-from :cl-events.protocols
   #:broadcast-p #:capture-p #:bubble-p
   #:stop-propagation #:message-state #:message-priority
)
  (:import-from :elmtui.core.conditions
   :message-validation-error
                :command-execution-error)
  (:import-from :elmtui.core.globals
   :*app-sender*)
  (:import-from :elmtui.cl-state.message-normalization
                #:validate-message-instance)
  (:import-from :elmtui.state.msg
   :*message-schemas*)

  (:import-from :elmtui.core.event-types
   ;; Standard event structures
   :key-event
                :make-key-event
   :key-event-type
                :key-event-key
   :key-event-code
                :key-event-modifiers
   :key-event-timestamp
                :key-event-consumed-p
   :key-event-p
                :mouse-event
   :make-mouse-event
                :mouse-event-type
   :mouse-event-x
                :mouse-event-y
   :mouse-event-button
                :mouse-event-modifiers
   :mouse-event-timestamp
                :mouse-event-consumed-p
   :mouse-event-p
                :focus-event
   :make-focus-event
                :focus-event-type
   :focus-event-target
                :focus-event-source
   :focus-event-timestamp
                :focus-event-consumed-p
   :focus-event-p

                :window-event
   :make-window-event
                :window-event-type
   :window-event-width
                :window-event-height
   :window-event-timestamp
                :window-event-consumed-p
   :window-event-p

                :system-event
   :make-system-event
                :system-event-type
   :system-event-data
                :system-event-timestamp
   :system-event-p

                :timer-event
   :make-timer-event
                :timer-event-id
   :timer-event-timestamp
                :timer-event-user-data
   :timer-event-p

                :command-event
   :make-command-event
                :command-event-name
   :command-event-args
                :command-event-source
   :command-event-timestamp
                :command-event-p
   :consume-event)
  (:export :message
   :make-message
           :message-p

           :message-type
   :message-data
           :message-state
   :broadcast-p
   :message-priority
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
           :register-message-contract
           ;; Serialization
   :serialize-message
           :deserialize-message
           ;; Lifecycle Hooks
   :*before-send-message-hooks*
           :*after-send-message-hooks*
   :add-before-send-message-hook
           :remove-before-send-message-hook
   :add-after-send-message-hook
           :remove-after-send-message-hook
           ))

(in-package :elmtui.core.events)

;; *app-sender* is now defined in elmtui.core.globals

(defgeneric on-message (target message &rest args &key &allow-other-keys)
  (:documentation "Dispatch MESSAGE to TARGET. Defaults to calling TARGET when it is a function."))

(defmethod on-message ((target function) message &rest args &key &allow-other-keys)
  (apply target message args))

(defmethod on-message ((target t) message &rest args &key &allow-other-keys)
  (declare (ignore args))
  (error "No on-message method for target ~S and message ~S" target message))

(defun %plist-set (plist key value)
  (let ((out (if (listp plist) (copy-list plist) nil)))
    (setf (getf out key) value)
    out))

(defmethod message-state ((msg cons))
  (getf msg :state))

(defun (setf message-state) (new-state msg)
  (typecase msg
    (message
     (setf (message-data msg)
           (%plist-set (message-data msg) :state new-state))
     new-state)
    (cons
     (setf (getf msg :state) new-state)
     new-state)
    (t new-state)))

(defmethod broadcast-p ((msg cons))
  (or (eq (getf msg :target) :broadcast)
      (null (getf msg :target))))

(defmethod capture-p ((msg cons))
  (getf msg :capture))

(defmethod bubble-p ((msg cons))
  (getf msg :bubble))

(defun propagation-stopped-p (msg &rest _args)
  (declare (ignore _args))
  (eq (message-state msg) :stopped))

(defmethod stop-propagation ((msg cons))
  (setf (message-state msg) :stopped)
  msg)

(defvar *message-contracts* (make-hash-table :test 'equal)
  "Registry of message contracts for validation and documentation.")

(defvar *before-send-message-hooks* nil
  "A list of functions to be called before a message is sent via SEND-MESSAGE.
Each hook function should accept the target and the message as arguments.")

(defvar *after-send-message-hooks* nil
  "A list of functions to be called after a message has been processed by SEND-MESSAGE.
Each hook function should accept the target and the message as arguments.")

(defun add-before-send-message-hook (hook-fN)
  "Adds HOOK-FN to the list of hooks executed before sending a message."
  (pushnew hook-fN *before-send-message-hooks* :test #'eq))

(defun remove-before-send-message-hook (hook-fN)
  "Removes HOOK-FN from the list of hooks executed before sending a message."
  (setf *before-send-message-hooks* (remove hook-fN *before-send-message-hooks* :test #'eq)))

(defun add-after-send-message-hook (hook-fN)
  "Adds HOOK-FN to the list of hooks executed after sending a message."
  (pushnew hook-fN *after-send-message-hooks* :test #'eq))

(defun remove-after-send-message-hook (hook-fN)
  "Removes HOOK-FN from the list of hooks executed after sending a message."
  (setf *after-send-message-hooks* (remove hook-fN *after-send-message-hooks* :test #'eq)))

(defmacro register-message-contract (type contract-fn &optional priority)
  "Register CONTRACT-FN as the explicit validation contract for TYPE.
PRIORITY is deprecated and ignored for source compatibility. Message priority is
owned exclusively by CL-EVENTS.PROTOCOLS:MESSAGE-PRIORITY on message values."
  (declare (ignore priority))
  `(setf (gethash ,type *message-contracts*) ,contract-fn))



(defun validate-message-via-schema (msg message-type-name schema)
  "Validates MSG data (a list) against the schema from DEFMSG."
  (declare (ignore schema))
  (multiple-value-bind (canonical reason)
      (validate-message-instance message-type-name (message-data msg))
    (unless canonical
      (signal 'elmtui.core.conditions:message-validation-error
              :message msg
              :reason reason)
      (return-from validate-message-via-schema nil))
    t))

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
                 :reason (format nil "Explicit contract validation failed for message type ~S." m-type-name)))
       t)
      ((gethash m-type-name *message-schemas*)
       (validate-message-via-schema msg m-type-name (gethash m-type-name *message-schemas*)))
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
  "Send MSG to TARGET using the on-message protocol.
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
            (setf result (on-message target msg))
            (setf successp t))
        (error (e)
          (signal 'elmtui.core.conditions:command-execution-error
                  :cmd msg
                  :reason e))))
    (dolist (hook *after-send-message-hooks*)
      (funcall hook target msg successp result)) ; Pass success status and result to after hooks
    result)) ; Return the result of on-message

;;; USAGE EXAMPLES:
;; (defparameter *relay* (make-instance 'cleve-elm.ems:ems))
;; (defparameter *msg* (make-message :custom-type '(:foo 42)))
;; (send-message *relay* *msg*)

;;; CONTRACTS:
;; - All messages must be instances of cl-events.types:message or subclasses.
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
  "Serializes a message object into a property list.
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
  "Deserializes a property list representation back into a message object.
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
