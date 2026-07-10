(uiop:define-package :elmtui.contracts
  (:use :cl)
  (:import-from :elmtui.cl-state.message-normalization
                #:message-variant-p
                #:validate-message-instance)
  (:import-from :elmtui.state.msg
    #:*message-schemas*
    #:message-schema)
  (:export
    ;; transform macros
    #:deftransform
    #:deftransformer

    ;; Structs constructors and accessors
    #:make-app-context #:app-context
    #:ctx-state #:ctx-viewport-rect
    #:ctx-view-fn
    #:ctx-stylesheet
    #:ctx-dsl-tree #:ctx-raw-tree
    #:ctx-styled-tree #:ctx-atomic-tree
    #:ctx-laid-out-tree #:ctx-front-buffer
    #:ctx-backend #:ctx-back-buffer
    ;; trees
    #:dsl-tree #:raw-tree #:styled-tree
    #:atomic-tree #:laid-out-tree
    ;; tree constructors
    #:make-dsl-tree #:make-raw-tree
    #:make-styled-tree #:make-atomic-tree
    #:make-laid-out-tree

    ;; Tree root accessors
    #:root
    ;; Core contract macros
    #:defupdate-ctr #:defview #:defsubscriptions
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
;;; Typed Tree Structs and Transform Macro for Pipeline
;;;--------------------------------------------------------------

(defstruct (app-context
             (:conc-name ctx-)
             (:constructor make-app-context (&key state viewport-rect
                                              dsl-tree raw-tree styled-tree
                                              view-fn stylesheet
                                              atomic-tree laid-out-tree
                                              front-buffer backend)))
  "Global application context for the pipeline.

   Arguments:
     STATE          -- (plist) Application model.
     VIEWPORT-RECT  -- (object) Geometry rectangle.
     DSL-TREE       -- (dsl-tree) DSL tree struct.
     RAW-TREE       -- (raw-tree) Raw tree struct.
     STYLED-TREE    -- (styled-tree) Styled tree struct.
     VIEW-FN        -- (function) View function.
     ATOMIC-TREE    -- (atomic-tree) Atomic tree struct.
     LAID-OUT-TREE  -- (laid-out-tree) Laid-out tree struct.
     FRONT-BUFFER   -- (object) Front buffer.
     BACKEND        -- (object) Backend instance.

   Returns:
     An APP-CONTEXT struct holding all pipeline stages and frame state.

   Example:
     (make-app-context :state '(:foo 1) :dsl-tree (make-dsl-tree :root ...))

   (plist, ...) => app-context (pure, no side-effects)
  "
  view-fn
  state            ; original :app-model plist
  stylesheet
  viewport-rect    ; et.geo:rectangle
  dsl-tree         ; dsl-tree struct
  raw-tree         ; raw-tree struct
  styled-tree      ; styled-tree struct
  atomic-tree      ; atomic-tree struct
  laid-out-tree    ; laid-out-tree struct
  front-buffer
  back-buffer
  backend)
;; (:NAME
;;   ELMTUI.EXAMPLES.RAINBOW-APP::RAINBOW-EXAMPLE-APP
;;   :INIT-FN
;;   #<FUNCTION ELMTUI.EXAMPLES.RAINBOW-APP:INITIALIZE-APP-STATE-RAINBOW-EXAMPLE-APP>
;;   :UPDATE-FN
;;   #<FUNCTION ELMTUI.EXAMPLES.RAINBOW-APP::PROCESS-MESSAGE-RAINBOW-EXAMPLE-APP>
;;   :VIEW-FN
;;   #<FUNCTION ELMTUI.EXAMPLES.RAINBOW-APP:RAINBOW-CONTENT-VIEW>
;;   :SUBSCRIPTIONS-FN NIL
;;   :COMMAND-PROCESSOR-FN NIL
;;   :MESSAGE-QUEUE
;;   #<CLEVE-ELM.CORE.EVENT-CHANNELS:MESSAGE-CHANNEL {1200EC1FC3}>
;;   :ROOT-VIEWPORT-ID
;;   :RAINBOW-ROOT-VP)
;; is a typical app-spec


(defstruct (dsl-tree (:conc-name dsl-))
  "DSL tree: holds the nested DSL list.

   Arguments:
     ROOT -- (list) The nested DSL list.

   Returns:
     A DSL-TREE struct.

   Example:
     (make-dsl-tree :root '(:container ...))

   (list) => dsl-tree (pure, no side-effects)
  "
  root)

(defstruct (raw-tree (:conc-name raw-))
  "Raw tree: UI-node tree before styling.

   Arguments:
     ROOT -- (object) The root UI-node.

   Returns:
     A RAW-TREE struct.

   Example:
     (make-raw-tree :root ...)

   (object) => raw-tree (pure, no side-effects)
  "
  root)

(defstruct (styled-tree (:conc-name sty-))
  "Styled tree: after stylesheet application."
  root)

(defstruct (atomic-tree (:conc-name at-))
  "Atomic tree: visibility/overflow resolved."
  root)

(defstruct (laid-out-tree (:conc-name lay-))
  "Laid-out tree: geometry resolved."
  root)


(defgeneric root (tree)
  (:documentation "Returns the root node of a tree structure."))
(defmethod root ((tree dsl-tree))
  "Returns the root node of a DSL tree."
  (dsl-root tree))
(defmethod root ((tree raw-tree))
  "Returns the root node of a raw tree."
  (raw-root tree))
(defmethod root ((tree styled-tree))
  "Returns the root node of a styled tree."
  (sty-root tree))
(defmethod root ((tree atomic-tree))
  "Returns the root node of an atomic tree."
  (at-root tree))
(defmethod root ((tree laid-out-tree))
  "Returns the root node of a laid-out tree."
  (lay-root tree))

(defgeneric tree-from-root (root)
  (:documentation "Creates a tree structure from a root node."))


(defmacro deftransform (name (in-type) (out-type) (arg) &body body)
  "Define a pure transformer and an App-Context plumbing stage."
  (let* ((fun-name   name)
          ;; 1.  AUTO-GENERATED STAGE NAME  -------------------------------
          (stage-name (intern (format nil "~A-STAGE" (string-upcase (symbol-name name)))
                        *package*))
          ;; 2.  SYMBOLS FOR ACCESSORS (CTX-DSL-TREE, CTX-RAW-TREE, …) ---
          (in-acc  (intern (format nil "CTX-~A" (string-upcase (symbol-name in-type)))
                     *package*))
          (out-acc (intern (format nil "CTX-~A" (string-upcase (symbol-name out-type)))
                     *package*))
          ;; 3.  GENSYM’D CTX VARIABLE ------------------------------------
          (ctx-var  (gensym "CTX")))
    `(progn
       ;; ---------- PURE FUNCTION ---------------------------------------
       (defun ,fun-name (,arg)
         (check-type ,arg ,in-type)
         (block ,fun-name ,@body))

       ;; ---------- PIPELINE STAGE --------------------------------------
       (define-stage ,stage-name (app-context app-context) (,ctx-var)
         ;; Bind *CTX* so transforms can peek if they really need to
         (let ((*ctx* ,ctx-var))
           (let* ((,arg (,in-acc ,ctx-var))
                   (result (,fun-name ,arg)))
             ;; setf via the accessor, not SLOT-VALUE
             (setf (,out-acc ,ctx-var) result)
             ,ctx-var))))))

;; (defmacro deftransform (name (in-type) (out-type) (arg) &body body)
;;   "Define a pure transformer and auto-generate a pipeline wrapper.
;; Signature: (in-tree) -> out-tree, plus a context-plumbing wrapper.
;; Generates:
;;   - (defun name (arg) ...) ; pure, type-checked
;;   - (define-stage name-STAGE (in-type out-type) (ctx) ...)"
;;   (let* ((trans-name  name)
;;          (stage-name  (intern (format nil "~a-STAGE" name) *package*))
;;          (ctx-var     (gensym "CTX"))
;;          (in-slot     (intern (format nil "~:@(~a~)" in-type) :keyword))
;;          (out-slot    (intern (format nil "~:@(~a~)" out-type) :keyword)))
;;     `(progn
;;        (defun ,trans-name (,arg)
;;          (check-type ,arg ,in-type)
;;          (block ,trans-name ,@body))
;;        (define-stage ,stage-name (,in-type ,out-type) (,ctx-var)
;;          (let* ((,arg (slot-value ,ctx-var (quote ,in-slot)))
;;                 (result (,trans-name ,arg)))
;;            (setf (slot-value ,ctx-var (quote ,out-slot)) result)
;;            ,ctx-var)))))

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

(defun %symbol-name-contains-p (symbol token)
  (and (symbolp symbol)
       (search token (string-downcase (symbol-name symbol)))))

(defun %looks-like-model-symbol-p (symbol)
  (%symbol-name-contains-p symbol "model"))

(defun %looks-like-message-symbol-p (symbol)
  (or (%symbol-name-contains-p symbol "message")
      (%symbol-name-contains-p symbol "msg")))

(defun %validate-update-parameter-order (macro-name message-param model-param)
  "Guardrail for canonical update signature order: (message model)."
  (unless (symbolp message-param)
    (error "~A: first parameter must be a symbol naming MESSAGE, got ~S"
           macro-name message-param))
  (unless (symbolp model-param)
    (error "~A: second parameter must be a symbol naming MODEL, got ~S"
           macro-name model-param))
  (when (eq message-param model-param)
    (error "~A: message and model parameters must be distinct symbols (got ~S)"
           macro-name message-param))
  (when (and (%looks-like-model-symbol-p message-param)
             (%looks-like-message-symbol-p model-param))
    (error "~A: signature appears swapped; expected (message model), got (~S ~S)"
           macro-name message-param model-param))
  t)
(define-condition pipeline-contract-violation (error)
  ((stage         :initarg :stage :reader violation-stage)
    (expected-type :initarg :expected-type :reader violation-expected)
    (got-object    :initarg :got-object :reader violation-got)
    (stack-trace :initarg :stack-trace :reader violation-stack-trace :initform nil))
  (:report (lambda (c s)
             (with-slots (stage expected-type got-object stack-trace) c
               (format s "~a expected ~s but got ~s (~s).(~s)"
                 stage expected-type got-object (type-of got-object)
                 stack-trace)))))

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
  (multiple-value-bind (canonical-message reason)
      (validate-message-instance message-type message)
    (unless canonical-message
      (error 'message-contract-violation
        :function-name 'validate-typed-message
        :expected-type (format nil "valid ~A message (variant + args)" message-type)
        :actual-value message
        :context (if reason
                     (format nil "~A (~A)" context reason)
                     context)))
    canonical-message))

(defun validate-hybrid-message (message message-type &optional (context "hybrid message validation"))
  "Validates message in hybrid mode - accepts both typed and flexible messages"
  (cond
    ;; If message-type is specified, prefer typed validation
    ((and message-type (message-variant-p message-type message))
      (validate-typed-message message message-type context))

    ;; If message-type specified but doesn't match, check if it's any valid message type
    (message-type
      (if (some (lambda (schema-name)
                  (nth-value 0 (validate-message-instance schema-name message)))
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

(defmacro defupdate-ctr (name (message-param model-param) &body body)
  "Defines an update function with flexible message validation (backward compatible).
   This is equivalent to defupdate-flexible."
  `(defupdate-flexible ,name (,message-param ,model-param) ,@body))

(defmacro defupdate-flexible (name (message-param model-param) &body body)
  "Defines an update function with flexible message validation.
   Accepts any message format - useful for prototyping and migration.

   Contract: update(message, model) => (values new-model commands)
   - model: Current application state (immutable, property list)
   - message: Any message format (flexible validation)
   - new-model: Updated state or nil (no change)
   - commands: List of side-effects to execute or nil"

  (%validate-update-parameter-order 'defupdate-flexible message-param model-param)
  (let ((doc-string (when (stringp (first body)) (first body)))
         (actual-body (if (stringp (first body)) (rest body) body)))
    `(defun ,name (,message-param ,model-param)
       ,@(when doc-string (list doc-string))

       ;; Input validation
       (handler-case (validate-model ,model-param "update function input")
         (contract-violation (c)
           (error 'update-contract-violation
             :function-name ',name
             :expected-type (cv-expected-type c)
             :actual-value (cv-actual-value c)
             :context (cv-context c))))
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

(defmacro defupdate-typed (name (message-param model-param) message-type &body body)
  "Defines an update function with strict message type validation.
   Only accepts messages that conform to the specified defmsg schema.

   Contract: update(typed-message, model) => (values new-model commands)
   - model: Current application state (immutable, property list)
   - message: Must be valid variant of message-type (strict validation)
   - message-type: Symbol naming the defmsg schema (e.g., 'AppMsg)
   - new-model: Updated state or nil (no change)
   - commands: List of side-effects to execute or nil

   Example:
   (defupdate-typed counter-update (message model) AppMsg
     (case (first message)
       (:increment (values (list :count (1+ (getf model :count 0))) nil))
       (:decrement (values (list :count (1- (getf model :count 0))) nil))
       (t (values nil nil))))"

  (%validate-update-parameter-order 'defupdate-typed message-param model-param)
  (let ((doc-string (when (stringp (first body)) (first body)))
         (actual-body (if (stringp (first body)) (rest body) body)))
    `(defun ,name (,message-param ,model-param)
       ,@(when doc-string (list doc-string))

       ;; Input validation
       (handler-case (validate-model ,model-param "update function input")
         (contract-violation (c)
           (error 'update-contract-violation
             :function-name ',name
             :expected-type (cv-expected-type c)
             :actual-value (cv-actual-value c)
             :context (cv-context c))))
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

(defmacro defupdate-hybrid (name (message-param model-param) &rest args)
  "Define an UPDATE function that works with *either* typed or flexible
   messages.

   Usage
   -----
     (defupdate-hybrid <function-name> (message model)
       [:MESSAGE-TYPE <symbol>]   ;; preferred defmsg schema
       [:PREFER-TYPED  <boolean>] ;; warn on untyped msg when non-NIL
       [doc-string]               ;; optional
       body-forms…)

   Contract: (update message model) -> (values new-model commands)"
  ;; ── 1.  Split keyword options from body-forms ─────────────────────────────
  (%validate-update-parameter-order 'defupdate-hybrid message-param model-param)
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
      `(defun ,name (,message-param ,model-param)
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
                 :expected-type "successful update execution"
                 :actual-value  e
                 :context (format nil "processing message ~S"
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

;;    Contract: update(message, model) => (values new-model commands)
;;    - model: Current application state (immutable, property list)
;;    - message: Typed message (if matches schema) or flexible message
;;    - message-type: Optional symbol naming the preferred defmsg schema
;;    - prefer-typed: If t, warns when non-typed messages are used
;;    - new-model: Updated state or nil (no change)
;;    - commands: List of side-effects to execute or nil

;;    Example:
;;    (defupdate-hybrid counter-update (message model) :message-type AppMsg :prefer-typed t
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

   Arguments:
     NAME        -- (symbol) Name of the view function.
     MODEL-PARAM -- (symbol) Model parameter name.
     BODY        -- (forms) Body of the view function.

   Returns:
     Defines a function that validates input, executes BODY, and validates output as a DSL tree.

   Example:
     (defview my-view (model)
       (list :container :children ...))

   (symbol, symbol, forms) => macro-expansion (side-effect: defines function)

   Side-effects:
     - Defines a function.
     - Signals errors on contract violation.
     - May log execution if debugging enabled.

   Purity: impure (macro, global definition, error signaling)
  "
  (let ((doc-string (when (stringp (first body)) (first body)))
         (actual-body (if (stringp (first body)) (rest body) body)))
    `(defun ,name (,model-param)
       ,@(when doc-string (list doc-string))

       ;; Input validation: ensure model is valid before rendering
       (handler-case (validate-model ,model-param "view function input")
         (contract-violation (c)
           (error 'view-contract-violation
             :function-name ',name
             :expected-type (cv-expected-type c)
             :actual-value (cv-actual-value c)
             :context (cv-context c))))

       ;; Execute view logic with contract enforcement
       (let ((result (handler-case (progn ,@actual-body)
                       (error (e)
                         (error 'view-contract-violation
                           :function-name ',name
                           :expected-type "successful view generation"
                           :actual-value e
                           :context (format nil "rendering model ~S" ,model-param))))))

         ;; Output validation: ensure result is a valid DSL tree
         (validate-dsl result ',name ,model-param)

         ;; Contract debugging if enabled
         (when *contract-debugging*
           (log-view-execution ',name ,model-param result))

         result))))

(defun validate-dsl (dsl function-name model)
  "Validates that DSL is a valid DSL structure.

   Arguments:
     DSL           -- (any) The DSL value to validate.
     FUNCTION-NAME -- (symbol) Name of the calling function.
     MODEL         -- (any) The model used for rendering.

   Returns:
     DSL if valid, otherwise signals a view-contract-violation error.

   Example:
     (validate-dsl '(:container :children ...) 'my-view '(:foo 1))

   (any, symbol, any) => any (side-effect: error signaling)

   Side-effects:
     - Signals error if DSL is invalid.

   Purity: impure (error signaling)
  "
  (unless (valid-dsl-p dsl)
    (error 'view-contract-violation
      :function-name function-name
      :expected-type "valid DSL structure"
      :actual-value dsl
      :context (format nil "rendering model ~S" model)))
  dsl)

(defun valid-dsl-p (dsl)
  "Checks if DSL is a valid DSL structure.

   Arguments:
     DSL -- (any) The DSL value to check.

   Returns:
     T if DSL is a valid DSL structure, NIL otherwise.

   Example:
     (valid-dsl-p '(:container :children ...)) ; => T
     (valid-dsl-p 42)                         ; => T
     (valid-dsl-p '(:foo :bar :baz))          ; => NIL

   (any) => boolean (pure, no side-effects)
  "
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
       (handler-case (validate-model ,model-param "subscriptions function input")
         (contract-violation (c)
           (error 'subscription-contract-violation
             :function-name ',name
             :expected-type (cv-expected-type c)
             :actual-value (cv-actual-value c)
             :context (cv-context c))))

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

(defun trace-contracts (&key update view subscriptions messages stream)
  "Return tracing status text for selected contract types.

When STREAM is supplied, also write the generated text there. This keeps
non-interactive callers silent by default while preserving an explicit
interactive diagnostic path."
  (let ((text
          (with-output-to-string (out)
            (when update
              (format out "~&Tracing UPDATE contracts...~%"))
            (when view
              (format out "~&Tracing VIEW contracts...~%"))
            (when subscriptions
              (format out "~&Tracing SUBSCRIPTION contracts...~%"))
            (when messages
              (format out "~&Tracing MESSAGE validation...~%")))))
    (when stream
      (write-string text stream))
    text))

;;;--------------------------------------------------------------
;;; Contract Validation Utilities (enhanced)
;;;--------------------------------------------------------------

(defun validate-elm-application (update-fn view-fn subscriptions-fn &optional init-model)
  "Validates that an Elm application's functions conform to contracts"
  (let ((test-model (or init-model '(:test t))))

    ;; Test update function
    (multiple-value-bind (new-model commands)
      (funcall update-fn :test-message test-model)
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

    (with-output-to-string (out)
      (format out "~&Suggested defmsg schema for ~A:~%" update-function-name)
      (format out "(defmsg ~AMsg (:docstring \"Messages for ~A\")~%"
        (string-capitalize update-function-name) update-function-name)
      (maphash (lambda (msg-type patterns)
                 (if (every #'null patterns)
                   (format out "  ~A~%" msg-type)
                   (format out "  (~A ~{~A~^ ~})~%" msg-type (first patterns))))
        message-patterns)
      (format out ")~%"))))
;; == elmtui/pipeline/contracts.lisp ==

(defmacro define-stage (name (in-type out-type) arglist &body body)
  "Define a pipeline stage NAME with input/OUTPUT type contracts.

IN-TYPE and OUT-TYPE are type designators used for:
  - A CHECK-TYPE precondition on the input.
  - A TYPEP-based postcondition on the result.

Any non-Elmtui ERROR signaled inside BODY is wrapped in a
PIPELINE-CONTRACT-VIOLATION. Errors that already belong to the
Elmtui error hierarchy (ELMTUI-ERROR and subclasses like DSL-ERROR)
are allowed to propagate unchanged, preserving their rich context."
  (unless (and (listp arglist)
            (symbolp (first arglist)))
    (error "define-stage: arglist must be a list whose FIRST element is the input symbol"))
  (let* ((input-sym  (first arglist))
          (result-sym (gensym "RES")))
    `(progn
       ;; Record declared types for tooling/pipeline linkage
       (setf (get ',name :pipeline/in-type)  ',in-type
         (get ',name :pipeline/out-type) ',out-type)

       (defun ,name ,arglist
         ;; Mark all non-&key/&optional args as ignorable so stages can ignore
         ;; extra context fields without warnings.
         (declare (ignorable ,@(remove-if
                                 (lambda (x) (or (eql x '&key)
                                               (eql x '&optional)))
                                 arglist)))

         ;; --- pre-condition -------------------------------------------------
         ;; This will be a no-op if IN-TYPE is T, but that’s fine and clear.
         (check-type ,input-sym ,in-type
           ,(format nil "~a input violated contract (expected ~a)."
              name in-type))

         ;; --- execution with error handling --------------------------------
         (handler-bind
           ((error
              (lambda (e)
                ;; Let Elmtui errors (including DSL-ERROR) propagate as-is.
                ;; For everything else, wrap as a pipeline-contract-violation.
                (unless (typep e 'elmtui.core.errors:elmtui-error)
                  (error 'pipeline-contract-violation
                    :stage ',name
                    :expected-type ',in-type
                    :got-object e
                    :stack-trace (with-output-to-string (dud)
                                   (sb-debug:backtrace sb-debug:*backtrace-frame-count* dud)))))))

           (let ((,result-sym (progn ,@body)))
             ;; --- post-condition -------------------------------------------
             (unless (typep ,result-sym ',out-type)
               (restart-case
                 (error 'pipeline-contract-violation
                   :stage ',name
                   :expected-type ',out-type
                   :got-object ,result-sym
                   :stack-trace (with-output-to-string (dud)
                                  (sb-debug:backtrace sb-debug:*backtrace-frame-count* dud)))
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
  "Compose STAGE-FNS into a single function that threads a context through them.

Each stage must be a function of one argument (the context), and will be
called in the order provided. The declared :pipeline/in-type and
:pipeline/out-type metadata from DEFINE-STAGE can be used by tooling or
validation code, but are not enforced here directly."
  (let ((context (gensym "CONTEXT")))
    `(defun ,name (,context)
       (reduce (lambda (ctx fn)
                 (funcall fn ctx))
         ',stage-fns
         :initial-value ,context))))

;; == end/contracts.lisp ==

;; (defmacro define-stage (name (in-type out-type) arglist &body body)
;;   "Wrap BODY in run-time CHECK-TYPE and restartable contract checks."
;;   (unless (and (listp arglist)
;;                (symbolp (first arglist)))
;;     (error "define-stage: arglist must be a list whose FIRST element is the input symbol"))
;;   (let* ((input-sym  (first arglist))
;;          (result-sym (gensym "RES")))
;;     `(progn
;;        ;; record the declared types for pipeline-linkage
;;        (setf (get ',name :pipeline/in-type)  ',in-type
;;              (get ',name :pipeline/out-type) ',out-type)
;;        ;; (defun ,name ,arglist
;;        ;; --- pre-condition -------------------------------------------------
;;        ;; (when ,in-type (check-type ,input-sym ,in-type
;;        ;;                            ,(format nil "~a input violated contract (expected ~a)."
;;        ;;                                     name in-type)))
;;        (defun ,name ,arglist
;;          ;; (declare (ignorable ,arglist))
;;          ;; --- pre-condition -------------------------------------------------
;;          (declare (ignorable ,@(remove-if
;;                                 (lambda (x) (or (eql x '&key)
;;                                                 (eql x '&optional))) arglist)))
;;          (check-type ,input-sym ,in-type
;;                      ,(format nil "~a input violated contract (expected ~a)."
;;                               name in-type))
;;          (handler-bind
;;              ((error (lambda (e)
;;                        ;; (error e)
;;                        (error 'pipeline-contract-violation
;;                               :stage ',name
;;                               :expected-type ',in-type
;;                               :got-object e
;;                               :stack-trace (with-output-to-string
;;                                                (dud)
;;                                              (sb-debug:backtrace sb-debug:*backtrace-frame-count* dud))))))

;;            (let ((,result-sym (progn ,@body)))
;;              ;; --- post-condition -------------------------------------------
;;              (unless (typep ,result-sym ',out-type)
;;                (restart-case
;;                    (error 'pipeline-contract-violation
;;                           :stage ',name
;;                           :expected-type ',out-type
;;                           :got-object ,result-sym
;;                           :stack-trace (with-output-to-string
;;                                            (dud)
;;                                          (sb-debug:backtrace sb-debug:*backtrace-frame-count* dud)))
;;                  (coerce-result (new)
;;                    :report "Provide replacement value and continue."
;;                    :interactive (lambda ()
;;                                   (format t "~%New value? ")
;;                                   (list (eval (read))))
;;                    (setq ,result-sym new))
;;                  (skip-stage ()
;;                    :report "Skip this stage and propagate input forward."
;;                    (setq ,result-sym ,input-sym))))
;;              ,result-sym))))))

;; (deftransformer generate-dsl (dsl-tree) (dsl-tree)
;;                 (abc &key state view-fn)
;;   (make-dsl-tree :root (funcall view-fn state)))
;; (defmacro define-pipeline (name &rest stage-fns)
;;   "Compose STAGE-FNS into a single function that threads a context through them."
;;   (let ((context (gensym "CONTEXT")))
;;     `(defun ,name (,context)
;;        (reduce (lambda (ctx fn)
;;                  (funcall fn ctx))
;;                ',stage-fns
;;                :initial-value ,context))))
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
(defmacro deftransformer (name (in-type) (out-type) lambda-list &body body)
  "Define a pure (tree &key …) → tree function and an APP-CONTEXT stage.

   Example:

     (deftransformer raw→styled (raw-tree) (styled-tree)
       (raw-tree &key stylesheet theme)
       ...)

   The wrapper extracts :STYLESHEET and :THEME from CTX via CTX-STYLESHEET,
   CTX-THEME accessors and calls RAW→STYLED with them."
  ;; 0) Split lambda-list into positional TREE and &KEY specs -------------
  (let* ((tree-var  (first lambda-list))
          (key-tail  (member '&key lambda-list))
          (key-specs (if key-tail (rest key-tail) '()))
          ;; 1) Canonical keyword names  ------------------------------------
          (keyword-syms
            (mapcar (lambda (spec)
                      (etypecase spec
                        (symbol spec)          ;  stylesheet
                        (cons   (first spec)))) ;  (stylesheet default)
              key-specs))
          ;; 2) Generate CTX-<FOO> accessors for each keyword --------------
          (accessor-syms
            (mapcar (lambda (k)
                      (intern (format nil "CTX-~:@(~A~)" k) *package*))
              keyword-syms))
          ;; 3) Helper symbols ---------------------------------------------
          (fn-name    name)
          (stage-name (intern (format nil "~A-STAGE" (string-upcase name))
                        *package*))
          (ctx-var   (gensym "CTX"))
          ;; Accessor for the incoming and outgoing tree slots -------------
          (in-acc
            (intern (format nil "CTX-~:@(~A~)" in-type) *package*))
          (out-acc
            (intern (format nil "CTX-~:@(~A~)" out-type) *package*)))
    `(progn
       ;; ---------- transformer FUNCTION ---------------------------------
       (defun ,fn-name ,lambda-list
         ;; (when (class-name
         ;;        ',in-type)
         (check-type ,tree-var ,in-type)
         ,@body)
       ;; ---------- pipeline STAGE ---------------------------------------
       (define-stage ,stage-name (app-context app-context) (,ctx-var)
         ;; Snapshot all needed values from CTX once
         (let* ((,tree-var (,in-acc ,ctx-var))
                 ,@(mapcar (lambda (key acc)
                             `(,key (,acc ,ctx-var)))
                     keyword-syms accessor-syms)
                 (result (funcall #',fn-name ,tree-var
                           ,@(apply #'append
                               (mapcar (lambda (k)
                                         (list (intern (string k) :keyword)
                                           k))
                                 keyword-syms)))))
           (setf (,out-acc ,ctx-var) result)
           ,ctx-var)))))
