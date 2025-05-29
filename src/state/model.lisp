;;;===============================================================
;;; File: src/state/model.lisp
;;; Model Definition Macro (Schema-based for Application State)
;;;===============================================================
(uiop:define-package :elmtui.state.model
  (:use :cl :alexandria :log4cl) ; Added log4cl
  (:import-from :elmtui.statelib.state #:application-state #:state-ref)
  (:import-from :elmtui.statelib.observe #:add-observer) ; Import add-observer from main state package
  (:import-from :elmtui.core.globals :*app-sender*) ; Import *app-sender* from globals
  (:export :defmodel :make-model :model-slot-value :initialize-model-state

           :get-slot
           ;; Model schema introspection helpers
           :model-slot-names :model-slot-definition :model-slot-type
           :model-slot-initform :model-slot-validator :model-slot-observe?
           :model-schema-info
           :with-model-access ; Added export
           ;; Schema structs and accessors
           :model-schema :model-schema-name :model-schema-slots :model-schema-docstring
           :slot-definition :slot-definition-name :slot-definition-type
           :slot-definition-initform :slot-definition-initarg :slot-definition-validator
           :slot-definition-observe :slot-definition-accessor)) ; Export schema utilities
(in-package :elmtui.state.model)

(defvar *model-schemas* (make-hash-table :test 'eq)
  "Global registry for model schemas defined by defmodel.")

(defstruct model-schema
  "Represents the schema for a model defined by defmodel."
  (name nil :type symbol)
  (slots (list) :type list) ; List of slot-definition structs
  (docstring "" :type string))

(defstruct slot-definition
  "Represents a single slot definition within a model schema."
  (name nil :type symbol)
  (type t ) ; Type specifier for check-type
  (initform nil :type T) ; Default value expression
  (initarg nil :type symbol) ; Keyword argument for constructor
  (validator nil :type (or null function symbol)) ; Validation function/lambda
  (observe nil :type boolean) ; Flag to auto-generate observer
  (accessor nil :type symbol)) ; Generated accessor function name
(defun %canonicalise-validator (designator)
  "Return either a symbol or a function object, or NIL."
  (cond
    ;; Caller used bare symbol – fine.
    ((symbolp designator) designator)

    ;; Caller wrote #'symbol  →  (FUNCTION symbol)
    ((and (consp designator)
          (eq (car designator) 'function)
          (symbolp (cadr designator)))
     (cadr designator))                       ; keep just the symbol

    ;; Caller wrote 'symbol  →  (QUOTE symbol)
    ((and (consp designator)
          (eq (car designator) 'quote)
          (symbolp (cadr designator)))
     (cadr designator))                       ; ditto

    ;; Caller gave a literal LAMBDA form – compile it **now**
    ((and (consp designator)
          (eq (car designator) 'lambda))
     (compile nil designator))

    ;; Anything else is a programmer error
    (t (error "Unsupported :validate designator: ~S" designator))))
(defun %parse-slot (slot-spec)
  "Parses a defmodel slot specification into a slot-definition struct."
  (let* ((name (if (listp slot-spec) (first slot-spec) slot-spec))
         (options (when (listp slot-spec) (rest slot-spec)))
         (type (getf options :type t))
         (initform (getf options :initform nil))
         (validator (getf options :validate nil))
         (observe (getf options :observe nil))) ; Parse :observe flag
    (unless (symbolp name)
      (error "Slot name must be a symbol: ~S" name))
    (make-slot-definition
     :name name
     :type type
     :initform initform
     :initarg (make-keyword name)
     :validator (%canonicalise-validator validator)
     :observe observe ; Store observe flag
     :accessor (symbolicate name)))) ; Simple accessor name for now

(defmacro defmodel (name (&key docstring
                            (observe-changes-default-callback
                             'default-model-observer-callback))
                    &rest slot-specs)
  "Define a model schema and all helper functions; see README."
  (let* ((schema-name     name)
         (constructor     (symbolicate "MAKE-" name))
         (initializer     (symbolicate "INITIALIZE-" name "-STATE"))
         (slots           (mapcar #'%parse-slot slot-specs))
         (schema          (make-model-schema :name schema-name
                                             :slots slots
                                             :docstring (or docstring ""))))
    ;; register schema now for dev tooling
    (setf (gethash schema-name *model-schemas*) schema)

    `(progn
       ;; ───────────────── default observer stub ────────────────
       (unless (fboundp ',observe-changes-default-callback)
         (defun ,observe-changes-default-callback (key old new)
           (log:info "Default Observer: Key=~S changed from ~S to ~S"
                     key old new)))

       ;; ───────────────── constructor ─────────────────────────
       (defun ,constructor
           (&key
              ,@(mapcar (lambda (s)
                          `(,(slot-definition-name s)
                            ,(slot-definition-initform s)))
                        slots))
         ,(format nil "Create a plist representing a ~S model." name)
         (let ((plist '()))
           ,@(mapcar
              (lambda (slot)
                (let* ((vname (gensym (symbol-name (slot-definition-name slot))))
                       (vfun  (slot-definition-validator slot))
                       (call-designator
                         (etypecase vfun
                           (null      nil)
                           (symbol    `(quote ,vfun))     ; 'plusp
                           (function  vfun))))            ; literal lambda / compiled fn
                  `(let ((,vname ,(slot-definition-name slot)))
                     (check-type ,vname ,(slot-definition-type slot))
                     ,(when vfun
                        `(unless (funcall ,call-designator ,vname)
                           (error "Validation failed for ~S (value ~S) in ~S"
                                  ',(slot-definition-name slot) ,vname ',name)))
                     (setf plist
                           (list* ,(slot-definition-initarg slot)
                                  ,vname
                                  plist)))))
              slots)
           (nreverse (nreverse plist))))

       ;; ───────────────── state-initializer ────────────────────
       (defun ,initializer (app-state initial-plist)
         ,(format nil "Insert ~S into APP-STATE and register observers." name)
         (check-type app-state application-state)
         (ut.state.state::set-state app-state ',schema-name initial-plist)

         ,@(loop for slot in slots
                 when (slot-definition-observe slot)
                   collect
                 `(progn
                    (log:info "Registering observer for ~S slot ~S"
                              ',name ',(slot-definition-name slot))
                    (add-observer
                     app-state ',schema-name
                     (lambda (model-key old new)
                       (declare (ignore model-key))
                       (let* ((slot-key ,(slot-definition-initarg slot))
                              (ov (getf old slot-key :%not-present%))
                              (nv (getf new slot-key :%not-present%)))
                         (unless (equal ov nv)
                           (log:debug "Observed change in ~S -> ~S"
                                      ',name slot-key)
                           (funcall *app-sender*
                                    (list :state-changed
                                          :model ',name
                                          :slot  slot-key
                                          :value nv))))))))
         initial-plist)

       ;; ───────────────── accessors ───────────────────────────
       ,@(mapcar
          (lambda (slot)
            `(defun ,(slot-definition-accessor slot) (app-state)
               ,(format nil "Accessor for ~S of ~S."
                        (slot-definition-name slot) name)
               (let ((model (state-ref app-state ',name)))
                 (getf model ,(slot-definition-initarg slot)))))
          slots)

       ;; expose the model symbol
       ',name)))

(defmacro with-model-access ((model-var-symbol) &body body)
  "Macro to enforce proper model access patterns.
   Warns when direct state-ref is used on the specified model variable.
   Usage: (with-model-access (my-model-instance) ... (state-ref my-model-instance :foo) ...)"
  `(locally
     (declare (notinline state-ref)) ; Prevent inlining of the imported state-ref we are wrapping
     (macrolet ((state-ref (object &rest args) ; This redefines the local meaning of 'state-ref'
                  ;; 'object' is the first form passed to state-ref in the body.
                  ;; 'model-var-symbol' is the symbol passed to with-model-access.
                  (if (eq object ',model-var-symbol) ; Check if the form 'object' is literally the symbol 'model-var-symbol'
                      (progn
                        (warn "Direct state-ref usage on model object '~A' detected. Consider using model-specific accessors or get-slot/set-slot instead." ',model-var-symbol)
                        ;; Call the original state-ref from its package
                        `(elmtui.statelib.state:state-ref ,object ,@args))
                      ;; If 'object' is not the model symbol we are watching, call original state-ref
                      `(elmtui.statelib.state:state-ref ,object ,@args))))
       ,@body)))

;; (defmacro defmodel (name (&key docstring (observe-changes-default-callback 'default-model-observer-callback))
;;                     &rest slot-specs)
;;   "Defines a model schema and associated functions for use with application-state.

;;    Models defined with `defmodel` represent partitions or structures within the
;;    central `application-state` hash table. This macro does NOT define a CLOS class
;;    or a defstruct. Instead, it:

;;    1. Registers a schema for the model, including slot names, types,
;;       default initial values (:initform), validation predicates (:validate),
;;       and an optional flag to automatically register an observer (:observe t).
;;    2. Defines a constructor function `make-<model-name>` which takes keyword
;;       arguments for slots, applies defaults, performs validation, and returns
;;       a property list (plist) representing the initial state of the model.
;;       This plist is intended to be stored in the `application-state`, typically
;;       using the model's `name` symbol as the key.
;;    3. Defines accessor functions `<slot-name>` to read slot values from the
;;       model's plist stored in the `application-state`.
;;    4. If `:observe t` is specified for a slot, the constructor will attempt to
;;       register an observer using `ut.state:add-observer` when the model state
;;       is first created and added to an `application-state`. This requires the
;;       `application-state` instance to be available. A default callback function
;;       `default-model-observer-callback` (or the one specified by the
;;       `:observe-changes-default-callback` key in `defmodel`) will be used.
;;    5. Intentionally DOES NOT define setter functions (`setf <accessor>`). All state
;;       modifications MUST be performed within a `defupdate` form using its
;;       local `set-state!` macro to ensure transactional integrity.

;;    Slot Specification:
;;      Each slot can be a symbol `slot-name` or a list
;;      `(slot-name &key :type :initform :validate :observe)`.
;;      - `:type`: A type specifier for `check-type`. Defaults to `T`.
;;      - `:initform`: An expression evaluated *at construction time* to provide a
;;                    default value if the slot is not supplied. Defaults to `NIL`.
;;      - `:validate`: A function designator (symbol or lambda) that takes the
;;                     proposed slot value and returns true if valid, false otherwise.
;;                     Validation occurs *after* defaulting and type checking.
;;      - `:observe`: If `t`, automatically register an observer for this slot's key
;;                    when the model is initialized within an application state.

;;    Usage with Application State:
;;      ;; Define a default observer callback (optional)
;;      (defun my-model-observer (key old-value new-value)
;;        (log:info \"Model Change: Key=~S, Old=~S, New=~S\" key old-value new-value))

;;      ;; Define the model schema
;;      (defmodel counter (:docstring \"A simple counter model\"
;;                         :observe-changes-default-callback 'my-model-observer)
;;        (count :type integer :initform 0 :validate #'plusp :observe t) ; Observe count
;;        (label :type string :initform \"Clicks\")) ; Don't observe label

;;      ;; In application initialization:
;;      (let* ((app-state (ut.state:make-application-state)) ; Need app-state for observers
;;             (initial-counter-state (make-counter :count 1)))
;;        ;; Store the plist in the application-state under the model name key
;;        ;; AND register observers if specified
;;        (initialize-model-state app-state 'counter initial-counter-state))

;;      ;; In a view or other read-only context:
;;      (let ((current-count (count app-state))) ; Use the generated accessor
;;        (format t \"Current count: ~d\" current-count))

;;      ;; In a defupdate function:
;;      (defupdate increment-counter (app-state msg)
;;        (declare (ignore msg))
;;        (let* ((model-key 'counter)
;;               (current-state (state-ref app-state model-key)))
;;          (set-state! model-key ; Update the whole plist in the app-state
;;                      (list* :count (1+ (getf current-state :count))
;;                             :label (getf current-state :label)))) ; Preserve other slots
;;        nil)

;;    Args:
;;      NAME: The symbol naming the model.
;;      DOCSTRING: An optional documentation string for the model.
;;      OBSERVE-CHANGES-DEFAULT-CALLBACK: Symbol naming the function to use for
;;                                        auto-registered observers. Defaults to
;;                                        `default-model-observer-callback`.
;;      SLOT-SPECS: A list of slot specifications.

;;    Returns:
;;      The symbol `NAME`."
;;   (let* ((schema-name name)
;;          (constructor-name (symbolicate "MAKE-" name))
;;          (initializer-name (symbolicate "INITIALIZE-" name "-STATE")) ; Helper for state init + observers
;;          (slots (mapcar #'%parse-slot slot-specs))
;;          (schema (make-model-schema :name schema-name :slots slots :docstring (or docstring ""))))

;;     ;; Store the schema globally
;;     (setf (gethash schema-name *model-schemas*) schema)

;;     `(progn
;;        ;; Define Default Observer Callback (if not already defined)
;;        (unless (fboundp ',observe-changes-default-callback)
;;          (defun ,observe-changes-default-callback (key old-value new-value)
;;            (log:info "Default Observer: Key=~S changed from ~S to ~S" key old-value new-value)))

;;        ;; Define Constructor (creates the initial plist)
;;        (defun ,constructor-name (&key ,@(mapcar (lambda (s) `(,(slot-definition-name s) ',(slot-definition-initform s))) slots))
;;          ,(format nil "Creates the initial state plist for a ~S model. Applies defaults and validation." name)
;;          ;; Collect provided args, apply defaults, validate
;;          (let ((plist (list)))
;;            ,@(mapcar (lambda (slot)
;;                        (let ((slot-name (slot-definition-name slot))
;;                              (var (gensym (symbol-name (slot-definition-name slot)))))
;;                          `(let ((,var ,slot-name)) ; Bind the keyword arg/default
;;                             ;; 1. Type Check
;;                             (check-type ,var ,(slot-definition-type slot))
;;                             ;; 2. Validation Check
;;                             ,(when (slot-definition-validator slot)
;;                                `(unless (funcall ,(%canonicalise-validator (slot-definition-validator slot)) ,var)
;;                                   (error "Validation failed for slot ~S with value ~S in ~S" ',slot-name ,var ',name)))
;;                             ;; Add to plist
;;                             (setf plist (list* ',slot-name ,var plist))))) ; Use keyword for key
;;                      slots)
;;            ;; Return the final plist (reversed for correct order)
;;            (nreverse plist)))

;;        ;; Define State Initializer (sets state and registers observers)
;;        (defun ,initializer-name (app-state initial-plist)
;;          ,(format nil "Initializes the state for ~S in APP-STATE using INITIAL-PLIST and registers observers." name)
;;          (check-type app-state application-state)
;;          ;; Set the initial state in the application-state hash table
;;          ;; Use internal set-state to avoid triggering transactions/observers during init
;;          (ut.state.state::set-state app-state ',schema-name initial-plist)

;;          ;; Register observers for slots marked with :observe t
;;          ,@(loop for slot in slots
;;                  when (slot-definition-observe slot)
;;                    collect `(progn
;;                               (log:info "Registering observer for ~S slot ~S" ',name ',(slot-definition-name slot))
;;                               (add-observer app-state
;;                                             ;; The key observed is the main model key
;;                                             ',schema-name
;;                                             ;; The callback needs to handle plist changes
;;                                             ;; Elm-style Observer: Dispatch a message instead of calling a direct callback.
;;                                             (lambda (model-key old-plist new-plist)
;;                                               (declare (ignore model-key)) ; Key observed is the top-level model symbol
;;                                               (let ((slot-key ,(slot-definition-initarg slot)) ; Keyword for the specific slot
;;                                                     (old-slot-val (getf old-plist slot-key :%not-present%))
;;                                                     (new-slot-val (getf new-plist slot-key :%not-present%)))
;;                                                 ;; If the specific slot value changed, dispatch a message
;;                                                 (unless (equal old-slot-val new-slot-val)
;;                                                   (log:debug "Observed change in ~S -> ~S. Dispatching message." ',name slot-key)
;;                                                   ;; Assumes a message like (:state-changed :model <model-name> :slot <slot-key> :value <new-val>)
;;                                                   ;; and *app-sender* is dynamically bound.
;;                                                   (funcall *app-sender*
;;                                                            `(:state-changed
;;                                                              :model ',schema-name
;;                                                              :slot ,slot-key
;;                                                              :value ,new-slot-val))))))))
;;          initial-plist) ; Return the initial plist

;;        ;; Define Accessors
;;        ,@(mapcar (lambda (slot)
;;                    (let ((accessor-name (slot-definition-accessor slot)) ; Using just slot name for now
;;                          (slot-key (slot-definition-initarg slot))) ; Use keyword
;;                      `(defun ,accessor-name (app-state)
;;                         ,(format nil "Accessor for the ~S slot of the ~S model. Reads from application-state."
;;                                  (slot-definition-name slot) name)
;;                         (let ((model-data (state-ref app-state ',name)))
;;                           ;; Don't warn here, might be legitimately nil initially
;;                           ;; (unless model-data
;;                           ;;   (warn "Model data for '~A' not found in application-state." ',name))
;;                           (getf model-data ,slot-key)))))
;;                  slots)

;;        ;; Return the model name symbol
;;        ',name)))

;; Helper functions (potentially useful outside the macro)
(defun make-model (model-name &rest initargs)
  "Generic constructor function to create initial model state plist.
   Does NOT register observers. Use initialize-<model-name>-state for that."
  (let* ((schema (gethash model-name *model-schemas*))
         (constructor-name (and schema (symbolicate "MAKE-" model-name))))
    (unless schema
      (error "Unknown model name: ~S" model-name))
    (apply constructor-name initargs)))

(defun initialize-model-state (app-state model-name initial-plist)
  "Generic helper to initialize model state and register observers."
  (let* ((schema (gethash model-name *model-schemas*))
         (initializer-name (and schema (symbolicate "INITIALIZE-" model-name "-STATE"))))
    (unless schema
      (error "Unknown model name: ~S" model-name))
    (unless (fboundp initializer-name)
      (error "Initializer function ~S not found for model ~S." initializer-name model-name))
    (funcall initializer-name app-state initial-plist)))


(defun model-slot-value (app-state model-name slot-name)
  "Generic accessor to get a slot value from a model in application-state."
  (let* ((schema (gethash model-name *model-schemas*))
         (slot (and schema (find slot-name (model-schema-slots schema) :key #'slot-definition-name))))
    (unless schema
      (error "Unknown model name: ~S" model-name))
    (unless slot
      (error "Unknown slot ~S for model ~S" slot-name model-name))
    (let ((accessor-fn (slot-definition-accessor slot)))
      (funcall accessor-fn app-state))))

;;;===============================================================
;;; Model Interface Functions
;;;===============================================================

(defun get-slot (model-object model-name slot-name)
  "Retrieves the value of SLOT-NAME from MODEL-OBJECT of type MODEL-NAME.
   MODEL-OBJECT can be an application-state instance or a direct model plist.
   Uses the schema defined by 'defmodel' for lookup.
   
   Args:
     model-object: Either an application-state instance or a model plist.
     model-name: The symbol naming the model type (e.g., 'counter-model).
     slot-name: The symbol naming the model slot (e.g., 'count).
     
   Returns:
     The value of the specified slot.
     
   Signals:
     ERROR: If model-name is not registered in *model-schemas*.
     ERROR: If slot-name is not defined in the model schema.
     
   Examples:
     (get-slot app-state 'counter-model 'count)     ; From application-state
     (get-slot counter-plist 'counter-model 'count) ; From standalone model plist"
  (let* ((schema (gethash model-name *model-schemas*))
         (slot-def (and schema (find slot-name (model-schema-slots schema)
                                     :key #'slot-definition-name))))
    (unless schema
      (error "Unknown model name: ~S. Ensure it's defined with defmodel." model-name))
    (unless slot-def
      (error "Unknown slot ~S for model ~S. Check slot definition in defmodel." slot-name model-name))

    (if (typep model-object 'application-state)
        ;; If model-object is application-state, use the generated accessor
        ;; which reads from the state.
        (funcall (slot-definition-accessor slot-def) model-object)
        ;; Otherwise, assume model-object is a direct plist instance of the model.
        (getf model-object (slot-definition-initarg slot-def)))))

;;;===============================================================
;;; Model Metadata and Introspection Functions
;;;===============================================================

(defun model-slot-names (model-name)
  "Returns a list of slot names defined for the specified model.
   
   Args:
     model-name: The symbol naming the model type (e.g., 'counter-model).
     
   Returns:
     A list of symbols representing the model's slot names.
     
   Signals:
     ERROR: If model-name is not registered in *model-schemas*."
  (let ((schema (gethash model-name *model-schemas*)))
    (unless schema
      (error "Unknown model name: ~S. Ensure it's defined with defmodel." model-name))
    (mapcar #'slot-definition-name (model-schema-slots schema))))

(defun model-slot-definition (model-name slot-name)
  "Returns the slot definition struct for a specific slot.
   
   Args:
     model-name: The symbol naming the model type (e.g., 'counter-model).
     slot-name: The symbol naming the model slot (e.g., 'count).
     
   Returns:
     The slot-definition struct for the specified slot.
     
   Signals:
     ERROR: If model-name is not registered in *model-schemas*.
     ERROR: If slot-name is not defined in the model schema."
  (let* ((schema (gethash model-name *model-schemas*))
         (slot-def (and schema (find slot-name (model-schema-slots schema)
                                     :key #'slot-definition-name))))
    (unless schema
      (error "Unknown model name: ~S. Ensure it's defined with defmodel." model-name))
    (unless slot-def
      (error "Unknown slot ~S for model ~S. Check slot definition in defmodel." slot-name model-name))
    slot-def))

(defun model-slot-type (model-name slot-name)
  "Returns the type specifier for a model slot.
   
   Args:
     model-name: The symbol naming the model type (e.g., 'counter-model).
     slot-name: The symbol naming the model slot (e.g., 'count).
     
   Returns:
     The type specifier for the specified slot."
  (slot-definition-type (model-slot-definition model-name slot-name)))

(defun model-slot-initform (model-name slot-name)
  "Returns the default value expression for a model slot.
   
   Args:
     model-name: The symbol naming the model type (e.g., 'counter-model).
     slot-name: The symbol naming the model slot (e.g., 'count).
     
   Returns:
     The initform expression for the specified slot."
  (slot-definition-initform (model-slot-definition model-name slot-name)))

(defun model-slot-validator (model-name slot-name)
  "Returns the validator function or symbol for a model slot.
   
   Args:
     model-name: The symbol naming the model type (e.g., 'counter-model).
     slot-name: The symbol naming the model slot (e.g., 'count).
     
   Returns:
     The validator function or symbol for the specified slot, or NIL if none."
  (slot-definition-validator (model-slot-definition model-name slot-name)))

(defun model-slot-observe? (model-name slot-name)
  "Returns whether a model slot has the observe flag set.
   
   Args:
     model-name: The symbol naming the model type (e.g., 'counter-model).
     slot-name: The symbol naming the model slot (e.g., 'count).
     
   Returns:
     T if the slot is observed, NIL otherwise."
  (slot-definition-observe (model-slot-definition model-name slot-name)))

(defun model-schema-info (model-name)
  "Returns a formatted string with information about a model's schema.
   Useful for debugging and introspection.
   
   Args:
     model-name: The symbol naming the model type (e.g., 'counter-model).
     
   Returns:
     A formatted string with model details."
  (let ((schema (gethash model-name *model-schemas*)))
    (unless schema
      (error "Unknown model name: ~S. Ensure it's defined with defmodel." model-name))
    (with-output-to-string (s)
      (format s "Model: ~S~%" model-name)
      (format s "Docstring: ~A~%" (model-schema-docstring schema))
      (format s "Slots:~%")
      (dolist (slot (model-schema-slots schema))
        (format s "  ~A:~%" (slot-definition-name slot))
        (format s "    Type: ~S~%" (slot-definition-type slot))
        (format s "    Initform: ~S~%" (slot-definition-initform slot))
        (format s "    Validator: ~S~%" (slot-definition-validator slot))
        (format s "    Observe: ~A~%" (slot-definition-observe slot))))))
