(uiop:define-package :elmtui.contracts
  (:use :cl)
  (:import-from :elmtui.state.msg
                #:message-variant-p #:*message-schemas* #:message-schema)
  (:export
   ;; Core contract macros
   #:defupdate #:defview #:defsubscriptions
   ;; Enhanced update macros with message type support
   #:defupdate-typed #:defupdate-flexible #:defupdate-hybrid
   ;; Contract validation
   #:validate-update-result #:validate-model #:validate-commands
   #:validate-dsl #:validate-subscriptions #:validate-message
   ;; Message validation
   #:validate-typed-message #:validate-flexible-message
   #:validate-hybrid-message #:validate-strict-message
   #:message-contract-violation
   ;; Error conditions
   #:contract-violation #:update-contract-violation
   #:view-contract-violation #:subscription-contract-violation
   #:pipeline-contract-violation
   ;; Error conditions readers
   #:cv-function-name #:cv-expected-type #:cv-actual-value
   #:cv-context
   #:violation-stage #:violation-expected #:violation-got
   ;; Development utilities
   #:enable-contract-debugging #:trace-contracts
   #:contract-summary #:analyze-message-usage #:suggest-message-schema
   #:validate-elm-application
   ;; Stage pipeline contracts
   #:define-stage #:define-pipeline
   ;; Subscription utilities
   #:subscription #:make-subscription #:subscription-p))

(in-package #:elmtui.contracts)

;;;--------------------------------------------------------------
;;; Contract Violation Conditions
;;;--------------------------------------------------------------

(define-condition contract-violation (error)
  ((function-name :initarg :function-name :reader cv-function-name)
   (expected-type :initarg :expected-type :reader cv-expected-type)
   (actual-value :initarg :actual-value :reader cv-actual-value)
   (context :initarg :context :reader cv-context :initform nil))
  (:report (lambda (condition stream)
             (format stream "Contract violation in ~A: expected ~A, got ~A~@[ in ~A~]"
                     (cv-function-name condition)
                     (cv-expected-type condition)
                     (cv-actual-value condition)
                     (cv-context condition)))))

(define-condition update-contract-violation (contract-violation) ())
(define-condition view-contract-violation (contract-violation) ())
(define-condition subscription-contract-violation (contract-violation) ())
(define-condition message-contract-violation (contract-violation) ())
(define-condition pipeline-contract-violation (error)
  ((stage         :initarg :stage :reader violation-stage)
   (expected-type :initarg :expected-type :reader violation-expected)
   (got-object    :initarg :got-object :reader violation-got))
  (:report (lambda (c s)
             (with-slots (stage expected-type got-object) c
               (format s "~a expected ~s but got ~s (~s)."
                       stage expected-type got-object (type-of got-object))))))

(define-condition undefined-layout (pipeline-contract-violation) ())


;;;--------------------------------------------------------------
;;; Message Validation System
;;;--------------------------------------------------------------

(defun validate-message (message validation-mode &optional message-type context)
  "Validates message according to specified validation mode.

   Validation modes:
   - :flexible  - Accept any message (current behavior)
   - :typed     - Enforce specific message type schema
   - :hybrid    - Accept both typed and flexible messages
   - :strict    - Only typed messages, no ad-hoc allowed"

  (ecase validation-mode
    (:flexible
     (validate-flexible-message message context))
    (:typed
     (validate-typed-message message message-type context))
    (:hybrid
     (validate-hybrid-message message message-type context))
    (:strict
     (validate-strict-message message message-type context))))

(defun validate-flexible-message (message &optional (context "flexible message validation"))
  "Validates message in flexible mode - accepts any message format"
  (declare (ignore context))
  ;; For flexible mode, we accept any value but can optionally validate common patterns
  (when (and (listp message)
             (not (keywordp (first message)))
             (> (length message) 0))
    (warn "Message ~S looks like it might be malformed (first element should be keyword)" message))
  message)

(defun validate-typed-message (message message-type &optional (context "typed message validation"))
  "Validates message against a specific defmsg schema"
  (unless message-type
    (error 'message-contract-violation
           :function-name 'validate-typed-message
           :expected-type "message type specification"
           :actual-value nil
           :context context))

  (unless (message-variant-p message-type message)
    (error 'message-contract-violation
           :function-name 'validate-typed-message
           :expected-type (format nil "valid ~A message variant" message-type)
           :actual-value message
           :context context))

  message)

(defun validate-hybrid-message (message message-type &optional (context "hybrid message validation"))
  "Validates message in hybrid mode - accepts both typed and flexible messages"
  (cond
    ;; If message-type is specified, prefer typed validation
    ((and message-type (message-variant-p message-type message))
     (validate-typed-message message message-type context))

    ;; If message-type specified but doesn't match, check if it's any valid message type
    (message-type
     (if (some (lambda (schema-name)
                 (message-variant-p schema-name message))
               (alexandria:hash-table-keys *message-schemas*))
         message  ; Valid message for some schema
         (validate-flexible-message message context)))

    ;; No message-type specified, use flexible validation
    (t (validate-flexible-message message context))))

(defun validate-strict-message (message message-type &optional (context "strict message validation"))
  "Validates message in strict mode - only typed messages allowed"
  (unless message-type
    (error 'message-contract-violation
           :function-name 'validate-strict-message
           :expected-type "message type specification required in strict mode"
           :actual-value message
           :context context))

  (validate-typed-message message message-type context))

;;;--------------------------------------------------------------
;;; Model Validation (unchanged)
;;;--------------------------------------------------------------

(defun validate-model (model &optional (context "model validation"))
  "Validates that model follows proper structure"
  (unless (or (null model)
              (and (listp model)
                   (evenp (length model))
                   (loop for (key value) on model by #'cddr
                         always (keywordp key))))
    (error 'contract-violation
           :function-name 'validate-model
           :expected-type "property list with keyword keys"
           :actual-value model
           :context context))
  model)

(defun validate-commands (commands &optional (context "command validation"))
  "Validates that commands list is properly structured"
  (unless (or (null commands)
              (and (listp commands)
                   (every #'validate-command commands)))
    (error 'contract-violation
           :function-name 'validate-commands
           :expected-type "list of valid commands"
           :actual-value commands
           :context context))
  commands)

(defun validate-command (command)
  "Validates individual command structure"
  (and (listp command)
       (keywordp (first command))
       (evenp (length (rest command)))))

;;;--------------------------------------------------------------
;;; Enhanced Update Function Contracts with Message Type Support
;;;--------------------------------------------------------------

(defmacro defupdate (name (model-param message-param) &body body)
  "Defines an update function with flexible message validation (backward compatible).
   This is equivalent to defupdate-flexible."
  `(defupdate-flexible ,name (,model-param ,message-param) ,@body))

(defmacro defupdate-flexible (name (model-param message-param) &body body)
  "Defines an update function with flexible message validation.
   Accepts any message format - useful for prototyping and migration.

   Contract: update(model, message) => (values new-model commands)
   - model: Current application state (immutable, property list)
   - message: Any message format (flexible validation)
   - new-model: Updated state or nil (no change)
   - commands: List of side-effects to execute or nil"

  (let ((doc-string (when (stringp (first body)) (first body)))
        (actual-body (if (stringp (first body)) (rest body) body)))
    `(defun ,name (,model-param ,message-param)
       ,@(when doc-string (list doc-string))

       ;; Input validation
       (validate-model ,model-param "update function input")
       (validate-message ,message-param :flexible nil "flexible update message")

       ;; Execute update logic with contract enforcement
       (multiple-value-bind (new-model commands)
           (handler-case (progn ,@actual-body)
             (error (e)
               (error 'update-contract-violation
                      :function-name ',name
                      :expected-type "successful update execution"
                      :actual-value e
                      :context (format nil "processing message ~S" ,message-param))))

         ;; Output validation
         (validate-update-result new-model commands ',name ,model-param ,message-param)

         ;; Contract debugging if enabled
         (when *contract-debugging*
           (log-update-execution ',name ,model-param ,message-param new-model commands))

         (values new-model commands)))))

(defmacro defupdate-typed (name (model-param message-param) message-type &body body)
  "Defines an update function with strict message type validation.
   Only accepts messages that conform to the specified defmsg schema.

   Contract: update(model, typed-message) => (values new-model commands)
   - model: Current application state (immutable, property list)
   - message: Must be valid variant of message-type (strict validation)
   - message-type: Symbol naming the defmsg schema (e.g., 'AppMsg)
   - new-model: Updated state or nil (no change)
   - commands: List of side-effects to execute or nil

   Example:
   (defupdate-typed counter-update (model message) AppMsg
     (case (first message)
       (:increment (values (list :count (1+ (getf model :count 0))) nil))
       (:decrement (values (list :count (1- (getf model :count 0))) nil))
       (t (values nil nil))))"

  (let ((doc-string (when (stringp (first body)) (first body)))
        (actual-body (if (stringp (first body)) (rest body) body)))
    `(defun ,name (,model-param ,message-param)
       ,@(when doc-string (list doc-string))

       ;; Input validation
       (validate-model ,model-param "update function input")
       (validate-message ,message-param :typed ',message-type "typed update message")

       ;; Execute update logic with contract enforcement
       (multiple-value-bind (new-model commands)
           (handler-case (progn ,@actual-body)
             (error (e)
               (error 'update-contract-violation
                      :function-name ',name
                      :expected-type "successful update execution"
                      :actual-value e
                      :context (format nil "processing ~A message ~S" ',message-type ,message-param))))

         ;; Output validation
         (validate-update-result new-model commands ',name ,model-param ,message-param)

         ;; Contract debugging if enabled
         (when *contract-debugging*
           (log-update-execution ',name ,model-param ,message-param new-model commands))

         (values new-model commands)))))

(defmacro defupdate-hybrid (name (model-param message-param) &rest args)
  "Define an UPDATE function that works with *either* typed or flexible
   messages.

   Usage
   -----
     (defupdate-hybrid <function-name> (model message)
       [:MESSAGE-TYPE <symbol>]   ;; preferred defmsg schema
       [:PREFER-TYPED  <boolean>] ;; warn on untyped msg when non-NIL
       [doc-string]               ;; optional
       body-forms…)

   Contract: (update model message) -> (values new-model commands)"
  ;; ── 1.  Split keyword options from body-forms ─────────────────────────────
  (let ((kw-plist '())
        (body     args))
    ;; pull leading keyword/value pairs into KW-PLIST
    (loop while (and body (keywordp (first body)))
          do (push (pop body) kw-plist)     ; the keyword
             (push (pop body) kw-plist))    ; its value
    (setq kw-plist (nreverse kw-plist))     ; restore order

    (let* ((message-type (getf kw-plist :message-type))
           (prefer-typed (getf kw-plist :prefer-typed))
           ;; ── 2.  Optional doc-string detection ────────────────────────────
           (doc-string  (when (and body (stringp (first body)))
                          (pop body)))
           (actual-body body))
      ;; ── 3.  Generate the real DEFUN ───────────────────────────────────────
      `(defun ,name (,model-param ,message-param)
         ,@(when doc-string (list doc-string))

         ;; Input validation
         (validate-model   ,model-param "update function input")
         (validate-message ,message-param :hybrid ',message-type
                           "hybrid update message")

         ;; Optional warning for untyped messages
         ,@(when prefer-typed
             `((when (and ',message-type
                          (not (message-variant-p ',message-type
                                                  ,message-param)))
                 (warn "Non-typed message ~S used in ~A (prefers ~A messages)"
                       ,message-param ',name ',message-type))))

         ;; Execute update logic under contract enforcement
         (multiple-value-bind (new-model commands)
             (handler-case (progn ,@actual-body)
               (error (e)
                 (error 'update-contract-violation
                        :function-name ',name
                        :expected-type \"successful update execution\"
                        :actual-value  e
                        :context (format nil \"processing message ~S\"
                                         ,message-param))))
           ;; Output validation + optional debugging
           (validate-update-result new-model commands ',name
                                   ,model-param ,message-param)
           (when *contract-debugging*
             (log-update-execution ',name ,model-param ,message-param
                                   new-model commands))
           (values new-model commands))))))



;; (defmacro defupdate-hybrid (name (model-param message-param) &key message-type prefer-typed &body body)
;;   "Defines an update function with hybrid message validation.
;;    Accepts both typed messages (if message-type specified) and flexible messages.

;;    Contract: update(model, message) => (values new-model commands)
;;    - model: Current application state (immutable, property list)
;;    - message: Typed message (if matches schema) or flexible message
;;    - message-type: Optional symbol naming the preferred defmsg schema
;;    - prefer-typed: If t, warns when non-typed messages are used
;;    - new-model: Updated state or nil (no change)
;;    - commands: List of side-effects to execute or nil

;;    Example:
;;    (defupdate-hybrid counter-update (model message) :message-type AppMsg :prefer-typed t
;;      ;; Can handle both (:increment) and :increment
;;      (let ((msg-type (if (listp message) (first message) message)))
;;        (case msg-type
;;          (:increment (values (list :count (1+ (getf model :count 0))) nil))
;;          (t (values nil nil)))))"

;;   (let ((doc-string (when (stringp (first body)) (first body)))
;;         (actual-body (if (stringp (first body)) (rest body) body)))
;;     `(defun ,name (,model-param ,message-param)
;;        ,@(when doc-string (list doc-string))

;;        ;; Input validation
;;        (validate-model ,model-param "update function input")
;;        (validate-message ,message-param :hybrid ',message-type "hybrid update message")

;;        ;; Optional warning for non-typed messages when prefer-typed is enabled
;;        ,@(when prefer-typed
;;            `((when (and ',message-type
;;                         (not (message-variant-p ',message-type ,message-param)))
;;                (warn "Non-typed message ~S used in ~A (prefers ~A messages)"
;;                      ,message-param ',name ',message-type))))

;;        ;; Execute update logic with contract enforcement
;;        (multiple-value-bind (new-model commands)
;;            (handler-case (progn ,@actual-body)
;;              (error (e)
;;                (error 'update-contract-violation
;;                       :function-name ',name
;;                       :expected-type "successful update execution"
;;                       :actual-value e
;;                       :context (format nil "processing message ~S" ,message-param))))

;;          ;; Output validation
;;          (validate-update-result new-model commands ',name ,model-param ,message-param)

;;          ;; Contract debugging if enabled
;;          (when *contract-debugging*
;;            (log-update-execution ',name ,model-param ,message-param new-model commands))

;;          (values new-model commands)))))

(defun validate-update-result (new-model commands function-name model message)
  (declare (ignore message function-name model))
  "Validates the result of an update function"
  (when new-model
    (validate-model new-model "update result model"))

  (when commands
    (validate-commands commands "update result commands")))

;;;--------------------------------------------------------------
;;; View Function Contract (unchanged)
;;;--------------------------------------------------------------

(defmacro defview (name (model-param) &body body)
  "Defines a view function with strict contract enforcement.

   Contract: view(model) => dsl-tree
   - model: Current application state (read-only)
   - Returns: Valid DSL tree structure"

  (let ((doc-string (when (stringp (first body)) (first body)))
        (actual-body (if (stringp (first body)) (rest body) body)))
    `(defun ,name (,model-param)
       ,@(when doc-string (list doc-string))

       ;; Input validation
       (validate-model ,model-param "view function input")

       ;; Execute view logic with contract enforcement
       (let ((result (handler-case (progn ,@actual-body)
                       (error (e)
                         (error 'view-contract-violation
                                :function-name ',name
                                :expected-type "successful view generation"
                                :actual-value e
                                :context (format nil "rendering model ~S" ,model-param))))))

         ;; Output validation
         (validate-dsl result ',name ,model-param)

         ;; Contract debugging if enabled
         (when *contract-debugging*
           (log-view-execution ',name ,model-param result))

         result))))

(defun validate-dsl (dsl function-name model)
  "Validates DSL structure"
  (unless (valid-dsl-p dsl)
    (error 'view-contract-violation
           :function-name function-name
           :expected-type "valid DSL structure"
           :actual-value dsl
           :context (format nil "rendering model ~S" model)))
  dsl)

(defun valid-dsl-p (dsl)
  "Checks if DSL structure is valid"
  (or (stringp dsl)
      (numberp dsl)
      (and (listp dsl)
           (keywordp (first dsl))
           (evenp (length (rest dsl))))))

;;;--------------------------------------------------------------
;;; Subscription Contract (unchanged)
;;;--------------------------------------------------------------

(defstruct subscription
  "Subscription descriptor for Elm Architecture"
  type        ; :keyboard, :timer, :http, etc.
  config      ; Configuration parameters (plist)
  message-fn) ; Function: event-data -> message

(defmacro defsubscriptions (name (model-param) &body body)
  "Defines a subscriptions function with contract enforcement."

  (let ((doc-string (when (stringp (first body)) (first body)))
        (actual-body (if (stringp (first body)) (rest body) body)))
    `(defun ,name (,model-param)
       ,@(when doc-string (list doc-string))

       ;; Input validation
       (validate-model ,model-param "subscriptions function input")

       ;; Execute subscriptions logic
       (let ((result (handler-case (progn ,@actual-body)
                       (error (e)
                         (error 'subscription-contract-violation
                                :function-name ',name
                                :expected-type "successful subscriptions generation"
                                :actual-value e
                                :context (format nil "generating subscriptions for model ~S" ,model-param))))))

         ;; Output validation
         (validate-subscriptions result ',name ,model-param)

         ;; Contract debugging if enabled
         (when *contract-debugging*
           (log-subscriptions-execution ',name ,model-param result))

         result))))

(defun validate-subscriptions (subscriptions function-name model)
  "Validates subscriptions list structure"
  (unless (or (null subscriptions)
              (and (listp subscriptions)
                   (every #'subscription-p subscriptions)))
    (error 'subscription-contract-violation
           :function-name function-name
           :expected-type "list of subscription structures"
           :actual-value subscriptions
           :context (format nil "generating subscriptions for model ~S" model)))
  subscriptions)

;;;--------------------------------------------------------------
;;; Pipeline Stage Contracts (unchanged)
;;;--------------------------------------------------------------

;; (define-condition pipeline-contract-violation (error)
;;   ((stage         :initarg :stage :reader violation-stage)
;;    (expected-type :initarg :expected-type :reader violation-expected)
;;    (got-object    :initarg :got-object :reader violation-got))
;;   (:report (lambda (c s)
;;              (with-slots (stage expected-type got-object) c
;;                (format s "~a expected ~s but got ~s (~s)."
;;                        stage expected-type got-object (type-of got-object))))))

;; (defmacro define-stage (name (in-type out-type) arglist &body body)
;;   "Wrap BODY in run-time CHECK-TYPE and restartable contract checks."
;;   (let ((result (gensym "RES")))
;;     `(defun ,name ,arglist
;;        (check-type (first ,arglist) ,in-type
;;                    ,(format nil "~a input violated contract (expected ~a)." name in-type))
;;        (handler-bind
;;            ((error (lambda (e)
;;                      (error 'pipeline-contract-violation
;;                             :stage ',name
;;                             :expected-type ',in-type
;;                             :got-object e))))
;;          (let ((,result (progn ,@body)))
;;            (unless (typep ,result ',out-type)
;;              (restart-case
;;                  (error 'pipeline-contract-violation
;;                         :stage ',name
;;                         :expected-type ',out-type
;;                         :got-object ,result)
;;                (coerce-result (new)
;;                  :report "Provide replacement value and continue."
;;                  :interactive (lambda ()
;;                                 (format t "~%New value? ")
;;                                 (list (eval (read))))
;;                  (setq ,result new))
;;                (skip-stage ()
;;                  :report "Skip this stage and propagate input forward."
;;                  (setq ,result (first ,arglist)))))
;;            ,result)))))



;;;--------------------------------------------------------------
;;; Contract Debugging & Development Support (enhanced)
;;;--------------------------------------------------------------

(defvar *contract-debugging* nil
  "Enable contract debugging and tracing")

(defvar *update-log* nil
  "Log of update function executions")

(defvar *view-log* nil
  "Log of view function executions")

(defvar *subscriptions-log* nil
  "Log of subscription function executions")

(defvar *message-validation-log* nil
  "Log of message validation events")

(defun enable-contract-debugging (&optional (enabled t))
  "Enable/disable contract debugging"
  (setf *contract-debugging* enabled)
  (when enabled
    (setf *update-log* nil
          *view-log* nil
          *subscriptions-log* nil
          *message-validation-log* nil)))

(defun log-update-execution (function-name model message new-model commands)
  "Log update function execution for debugging"
  (push (list :timestamp (get-universal-time)
              :function function-name
              :input-model model
              :message message
              :message-type (when (listp message) (first message))
              :message-typed-p (some (lambda (schema-name)
                                       (message-variant-p schema-name message))
                                     (alexandria:hash-table-keys *message-schemas*))
              :output-model new-model
              :commands commands)
        *update-log*))

(defun log-view-execution (function-name model dsl)
  "Log view function execution for debugging"
  (push (list :timestamp (get-universal-time)
              :function function-name
              :model model
              :dsl-size (if (listp dsl) (length dsl) 1))
        *view-log*))

(defun log-subscriptions-execution (function-name model subscriptions)
  "Log subscriptions function execution for debugging"
  (push (list :timestamp (get-universal-time)
              :function function-name
              :model model
              :subscription-count (length subscriptions))
        *subscriptions-log*))

(defun trace-contracts (&key update view subscriptions messages)
  "Enable tracing for specific contract types"
  (when update
    (format t "~&Tracing UPDATE contracts...~%"))
  (when view
    (format t "~&Tracing VIEW contracts...~%"))
  (when subscriptions
    (format t "~&Tracing SUBSCRIPTION contracts...~%"))
  (when messages
    (format t "~&Tracing MESSAGE validation...~%")))

;;;--------------------------------------------------------------
;;; Contract Validation Utilities (enhanced)
;;;--------------------------------------------------------------

(defun validate-elm-application (update-fn view-fn subscriptions-fn &optional init-model)
  "Validates that an Elm application's functions conform to contracts"
  (let ((test-model (or init-model '(:test t))))

    ;; Test update function
    (multiple-value-bind (new-model commands)
        (funcall update-fn test-model :test-message)
      (when new-model (validate-model new-model "update function result"))
      (when commands (validate-commands commands "update function commands")))

    ;; Test view function
    (let ((dsl (funcall view-fn test-model)))
      (validate-dsl dsl 'validate-elm-application test-model))

    ;; Test subscriptions function
    (let ((subs (funcall subscriptions-fn test-model)))
      (validate-subscriptions subs 'validate-elm-application test-model))

    t))

(defun contract-summary ()
  "Returns summary of contract executions for debugging"
  (list :update-executions (length *update-log*)
        :view-executions (length *view-log*)
        :subscription-executions (length *subscriptions-log*)
        :message-validations (length *message-validation-log*)
        :debugging-enabled *contract-debugging*
        :available-message-schemas (alexandria:hash-table-keys *message-schemas*)))

;;;--------------------------------------------------------------
;;; Message Analysis Utilities
;;;--------------------------------------------------------------

(defun analyze-message-usage (&optional update-log)
  "Analyzes message usage patterns from update execution log"
  (let ((log-data (or update-log *update-log*))
        (typed-count 0)
        (untyped-count 0)
        (message-types (make-hash-table :test 'equal)))

    (dolist (entry log-data)
      (let ((message (getf entry :message))
            (typed-p (getf entry :message-typed-p)))
        (if typed-p
            (incf typed-count)
            (incf untyped-count))

        (let ((msg-type (if (listp message) (first message) message)))
          (incf (gethash msg-type message-types 0)))))

    (list :total-messages (+ typed-count untyped-count)
          :typed-messages typed-count
          :untyped-messages untyped-count
          :message-frequency (alexandria:hash-table-alist message-types))))

(defun suggest-message-schema (update-function-name &optional update-log)
  "Suggests a defmsg schema based on observed message patterns"
  (let* ((log-data (or update-log *update-log*))
         (function-messages (remove-if-not
                             (lambda (entry)
                               (eq (getf entry :function) update-function-name))
                             log-data))
         (message-patterns (make-hash-table :test 'equal)))

    (dolist (entry function-messages)
      (let* ((message (getf entry :message))
             (msg-type (if (listp message) (first message) message))
             (msg-args (when (listp message) (rest message))))
        (setf (gethash msg-type message-patterns)
              (union (gethash msg-type message-patterns)
                     (list msg-args) :test 'equal))))

    (format t "~&Suggested defmsg schema for ~A:~%" update-function-name)
    (format t "(defmsg ~AMsg (:docstring \"Messages for ~A\")~%"
            (string-capitalize update-function-name) update-function-name)
    (maphash (lambda (msg-type patterns)
               (if (every #'null patterns)
                   (format t "  ~A~%" msg-type)
                   (format t "  (~A ~{~A~^ ~})~%" msg-type (first patterns))))
             message-patterns)
    (format t ")~%")))

(defmacro define-stage (name (in-type out-type) arglist &body body)
  "Wrap BODY in run-time CHECK-TYPE and restartable contract checks."
  (unless (and (listp arglist)
               (symbolp (first arglist)))
    (error "define-stage: arglist must be a list whose FIRST element is the input symbol"))
  (let* ((input-sym  (first arglist))
         (result-sym (gensym "RES")))
    `(progn
       ;; record the declared types for pipeline-linkage
       (setf (get ',name :pipeline/in-type)  ',in-type
             (get ',name :pipeline/out-type) ',out-type)
       (defun ,name ,arglist
         ;; --- pre-condition -------------------------------------------------
         (check-type ,input-sym ,in-type
                     ,(format nil "~a input violated contract (expected ~a)."
                              name in-type))
         (handler-bind
             ((error (lambda (e)
                       (error 'pipeline-contract-violation
                              :stage ',name
                              :expected-type ',in-type
                              :got-object e))))
           (let ((,result-sym (progn ,@body)))
             ;; --- post-condition -------------------------------------------
             (unless (typep ,result-sym ',out-type)
               (restart-case
                   (error 'pipeline-contract-violation
                          :stage ',name
                          :expected-type ',out-type
                          :got-object ,result-sym)
                 (coerce-result (new)
                   :report "Provide replacement value and continue."
                   :interactive (lambda ()
                                  (format t "~%New value? ")
                                  (list (eval (read))))
                   (setq ,result-sym new))
                 (skip-stage ()
                   :report "Skip this stage and propagate input forward."
                   (setq ,result-sym ,input-sym))))
             ,result-sym))))))

(defmacro define-pipeline (name &rest stage-fns)
  "Compose STAGE-FNS into a single function that threads a context plist through them."
  (let ((context (gensym "CONTEXT")))
    `(defun ,name (,context)
       (let ((current-context ,context))
         (dolist (stage-fn ',stage-fns current-context)
           (setf current-context (funcall stage-fn current-context)))))))
;; (defmacro define-pipeline (name &rest stage-fns)
;;   "Compose STAGE-FNS into a single function that threads a context plist through them."
;;   (let ((context (gensym "CONTEXT")))
;;     `(defun ,name (,context)
;;        (reduce (lambda (ctx fn) (funcall fn ctx))
;;                ',stage-fns
;;                :initial-value ,context))))
;; (defmacro define-stage (name (in-type out-type) arglist &body body)
;;   "Wrap BODY in run-time CHECK-TYPE and restartable contract checks."
;;   (let ((result (gensym "RES")))
;;     `(defun ,name ,arglist
;;        (check-type (first ,arglist) ,in-type
;;          ,(format nil "~a input violated contract (expected ~a)." name in-type))
;;        (handler-bind
;;            ((error (lambda (e)
;;                      (error 'pipeline-contract-violation
;;                             :stage ',name
;;                             :expected-type ',in-type
;;                             :got-object e))))
;;          (let ((,result (progn ,@body)))
;;            (unless (typep ,result ',out-type)
;;              (restart-case
;;                  (error 'pipeline-contract-violation
;;                         :stage ',name
;;                         :expected-type ',out-type
;;                         :got-object ,result)
;;                (coerce-result (new)
;;                  :report "Provide replacement value and continue."
;;                  :interactive (lambda ()
;;                                 (format t "~%New value? ")
;;                                 (list (eval (read))))
;;                  (setq ,result new))
;;                (skip-stage ()
;;                  :report "Skip this stage and propagate input forward."
;;                  (setq ,result (first ,arglist)))))
;;            ,result)))))
