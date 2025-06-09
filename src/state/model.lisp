;;;===============================================================
;;; File: src/state/model.lisp
;;; Model Definition Macro (Schema-based for Application State)
;;;===============================================================
(uiop:define-package :elmtui.state.model
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.state.api ; Import from the central API
   :application-state :state-ref :make-model :initialize-model-state :get-slot :with-model-access
   ;; Potentially :*-app-state* if needed directly, though usually passed as arg
   )
  (:import-from :elmtui.statelib.observe #:add-observer) ; Lower-level, not in main API
  (:import-from :elmtui.core.globals :*app-sender*)
  (:export ;; Symbols defined *in this file* that are part of the public API
   ;; These are already exported by elmtui.state.api, but good practice to list them here too.
   :defmodel
   ;; :make-model ; Now imported from API, which exports this one
   ;; :initialize-model-state ; Now imported from API
   ;; :get-slot ; Now imported from API
   ;; :with-model-access ; Now imported from API

   ;; Model schema introspection helpers (if they become part of the public API via elmtui.state.api)
   :model-slot-names :model-slot-definition :model-slot-type
   :model-slot-initform :model-slot-validator :model-slot-observe?
   :model-schema-info
   ;; Schema structs and accessors (if they become part of the public API)
   :model-schema :model-schema-name :model-schema-slots :model-schema-docstring
   :slot-definition :slot-definition-name :slot-definition-type
   :slot-definition-initform :slot-definition-initarg :slot-definition-validator
   :slot-definition-observe :slot-definition-accessor))
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
         (constructor     (symbolicate "MAKE-" name)) ; This is the plist constructor
         (initializer     (symbolicate "INITIALIZE-" name "-STATE")) ; This is for app-state
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

       ;; ───────────────── plist constructor (used by make-model) ───────────────────
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

       ;; ───────────────── state-initializer (used by initialize-model-state) ───────────────
       ;; This function is now primarily for setting up observers, as the actual
       ;; state setting (plist into app-state) will be handled by the caller of initialize-model-state
       ;; or by defupdate using merge-patches.
       ;; However, initialize-model-state in the API should still handle putting the initial model plist
       ;; into the application-state.
       (defun ,initializer (app-state model-key initial-plist)
         ,(format nil "Set initial state for ~S in APP-STATE at MODEL-KEY and register observers." name)
         (check-type app-state elmtui.state.api:application-state) ; Use API type
         ;; The API function `initialize-model-state` will handle the actual state setting.
         ;; This generated function focuses on observer registration.
         ;; (elmtui.state.api:set-state app-state model-key initial-plist) ; Done by the public API function

         ,@(loop for slot in slots
                 when (slot-definition-observe slot)
                   collect
                 `(progn
                    (log:info "Registering observer for ~S slot ~S on model ~S"
                              ',name ',(slot-definition-name slot) model-key)
                    (add-observer ; from elmtui.statelib.observe
                     app-state model-key ; Observe the top-level model key in app-state
                     (lambda (observed-key old-model-plist new-model-plist)
                       (declare (ignore observed-key)) ; We know it's model-key
                       (let* ((slot-initarg-key ,(slot-definition-initarg slot))
                              (ov (getf old-model-plist slot-initarg-key :%not-present%))
                              (nv (getf new-model-plist slot-initarg-key :%not-present%)))
                         (unless (equal ov nv)
                           (log:debug "Observed change in ~S model (~S), slot ~S: ~S -> ~S"
                                      model-key ',name slot-initarg-key ov nv)
                           (funcall elmtui.core.globals:*app-sender*
                                    (list :state-changed ; This should be a proper message constructor
                                          :model model-key ; or schema-name?
                                          :slot-name ',(slot-definition-name slot) ; actual slot name
                                          :slot-key slot-initarg-key      ; keyword for the slot
                                          :old-value ov
                                          :new-value nv))))))))
         initial-plist) ; Return the plist, though initialize-model-state (API) handles it.

       ;; ───────────────── accessors (used by get-slot) ───────────────────────────
       ;; These accessors expect an application-state object and the model's key within it.
       ,@(mapcar
          (lambda (slot)
            `(defun ,(slot-definition-accessor slot) (app-state model-key)
               ,(format nil "Accessor for ~S of ~S model stored under MODEL-KEY."
                        (slot-definition-name slot) name)
               (check-type app-state elmtui.state.api:application-state)
               (let ((model-plist (elmtui.state.api:get-state app-state model-key)))
                 (getf model-plist ,(slot-definition-initarg slot)))))
          slots)

       ;; expose the model symbol
       ',name)))

(defmacro with-model-access ((model-var-symbol) &body body)
  "Macro to enforce proper model access patterns.
   Warns when direct state-ref is used on the specified model variable.
   Usage: (with-model-access (my-model-instance) ... (state-ref my-model-instance :foo) ...)"
  `(locally
       (declare (notinline elmtui.state.api:state-ref)) ; Prevent inlining of the imported state-ref we are wrapping
     (macrolet ((elmtui.state.api:state-ref (object &rest args) ; This redefines the local meaning of 'state-ref'
                  (if (eq object ',model-var-symbol)
                      (progn
                        (warn "Direct state-ref usage on model object '~A' detected. Consider using model-specific accessors or get-slot/set-slot instead." ',model-var-symbol)
                        `(elmtui.state.api:state-ref ,object ,@args)) ; Call original from statelib
                      `(elmtui.state.api:state-ref ,object ,@args)))))
     ,@body))

;; Public API functions (make-model, initialize-model-state, get-slot)
;; These are now defined here and exported via elmtui.state.api.

(defun make-model (model-name &rest initargs)
  "Generic constructor function to create an initial model state plist for MODEL-NAME.
   MODEL-NAME must be a symbol previously defined with DEFMODEL.
   INITARGS are keyword arguments corresponding to the model's slots.
   This function calls the specific make-<model-name> plist constructor generated by DEFMODEL.
   It performs type checking and validation as defined in the model schema.
   Does NOT register observers or interact with application-state.
   Use INITIALIZE-MODEL-STATE to integrate the model into an application-state."
  (let* ((schema (gethash model-name *model-schemas*))
         (constructor-name (and schema (symbolicate "MAKE-" (string model-name))))) ; Constructor for plist
    (unless schema
      (error "Unknown model name: ~S. Ensure it's defined with defmodel." model-name))
    (unless (and constructor-name (fboundp constructor-name))
      (error "Internal error: Plist constructor ~S not found for model ~S." constructor-name model-name))
    (apply constructor-name initargs)))

(defun initialize-model-state (app-state model-key model-name &rest initargs)
  "Initializes a model of type MODEL-NAME within APP-STATE, stored under MODEL-KEY.
   1. Creates the initial model state plist using MAKE-MODEL with INITARGS.
   2. Stores this plist in APP-STATE at MODEL-KEY using SET-STATE.
   3. Calls the model-specific <initialize-MODEL-NAME-state> function (generated by DEFMODEL)
      to register any observers defined for the model's slots.
   Returns the initialized model plist.

   Args:
     app-state: The application-state instance.
     model-key: The key (symbol) under which this model instance will be stored in app-state.
     model-name: The symbol naming the model type (e.g., 'counter), defined via DEFMODEL.
     initargs: Keyword arguments for the model's slots, passed to MAKE-MODEL.

   Example:
     (initialize-model-state *app-state* :my-counter 'counter :count 10)"
  (check-type app-state elmtui.state.api:application-state)
  (check-type model-key symbol)
  (check-type model-name symbol)

  (let* ((schema (gethash model-name *model-schemas*))
         (initializer-helper-name (and schema (symbolicate "INITIALIZE-" (string model-name) "-STATE"))))

    (unless schema
      (error "Unknown model name: ~S. Ensure it's defined with defmodel." model-name))
    (unless (and initializer-helper-name (fboundp initializer-helper-name))
      (error "Internal error: Observer initializer ~S not found for model ~S." initializer-helper-name model-name))

    ;; 1. Create the initial model state plist
    (let ((initial-plist (apply #'make-model model-name initargs)))
      ;; 2. Store this plist in APP-STATE at MODEL-KEY
      ;;    This should ideally happen within a transaction if called outside an update cycle.
      ;;    For now, direct set-state. If called from defapplication, it's fine.
      (elmtui.state.api:set-state app-state model-key initial-plist)

      ;; 3. Call the generated helper to register observers
      ;;    This helper now expects app-state, the model-key, and the plist.
      (funcall initializer-helper-name app-state model-key initial-plist)

      initial-plist)))


(defun get-slot (model-object model-key-or-name slot-name)
  "Retrieves the value of SLOT-NAME from a model instance.
   If MODEL-OBJECT is an application-state, MODEL-KEY-OR-NAME is the key
   where the model plist is stored, and its type is inferred from the schema
   associated with that key (future improvement) or must be provided if ambiguous.
   For now, assumes MODEL-KEY-OR-NAME is the model's schema name if MODEL-OBJECT is a plist,
   or the key in app-state if MODEL-OBJECT is application-state.

   More robustly:
   - (get-slot app-state :my-counter 'count) -> app-state has a model under :my-counter, get its 'count slot.
     (Requires knowing the model *type* at :my-counter, or assuming it from schema if unique).
   - (get-slot counter-plist 'counter-schema 'count) -> counter-plist is of type 'counter-schema.

Args:
  model-object: An application-state instance or a direct model plist.
  model-key-or-name:
    - If model-object is application-state: The SYMBOL key where the model is stored.
      The function will try to find a model schema associated with this key or
      might require the schema name explicitly if ambiguous in the future.
      For now, it might need the schema name if the accessor isn't unique.
    - If model-object is a plist: The SYMBOL naming the model's schema (e.g., 'counter).
  slot-name: The SYMBOL naming the slot.

Returns:
  The value of the slot.

Example:
  (defmodel my-counter () (value :type integer))
  (initialize-model-state *app* :main-counter 'my-counter :value 10)
  (get-slot *app* :main-counter 'value) ; => 10

  (let ((p (make-model 'my-counter :value 5)))
    (get-slot p 'my-counter 'value)) ; => 5
"
  (etypecase model-object
    (elmtui.state.api:application-state
     (let* ((app-state model-object)
            (model-key model-key-or-name)
            ;; We need to determine the model schema/type from the model-key.
            ;; This is tricky if not explicitly stored. For now, assume accessors are unique enough
            ;; or that the schema can be inferred if we had a registry of (app-state-key -> model-schema-name).
            ;; Let's find an accessor that matches <slot-name>.
            ;; This is a simplification. A robust system would need to know the model *type* at model-key.
            (model-plist (elmtui.state.api:get-state app-state model-key)))
       (unless model-plist
         (warn "No model found at key ~S in application-state for get-slot." model-key)
         (return-from get-slot nil))
       ;; Try to find the schema for the model stored at model-key.
       ;; This is a placeholder for a more robust mechanism.
       ;; We'll iterate through all schemas and see if an accessor matches.
       (dolist (schema-name (alexandria:hash-table-keys *model-schemas*))
         (let* ((schema (gethash schema-name *model-schemas*))
                (slot-def (find slot-name (model-schema-slots schema) :key #'slot-definition-name)))
           (when slot-def
             (let ((accessor-fn (slot-definition-accessor slot-def)))
               (when (fboundp accessor-fn) ; Check if accessor is defined
                 ;; The generated accessors take (app-state model-key)
                 (return-from get-slot (funcall accessor-fn app-state model-key)))))))
       ;; If no accessor found this way, try direct getf as a fallback (less safe)
       (warn "Could not determine model type at key ~S to use specific accessor for slot ~S. Falling back to direct GETF." model-key slot-name)
       (getf model-plist (make-keyword slot-name)))) ; Fallback, less safe

    (list ; Assume it's a direct model plist
     (let* ((model-plist model-object)
            (model-schema-name model-key-or-name)
            (schema (gethash model-schema-name *model-schemas*))
            (slot-def (and schema (find slot-name (model-schema-slots schema) :key #'slot-definition-name))))
       (unless schema
         (error "Unknown model schema name: ~S for get-slot on a plist." model-schema-name))
       (unless slot-def
         (error "Unknown slot ~S for model schema ~S for get-slot on a plist." slot-name model-schema-name))
       (getf model-plist (slot-definition-initarg slot-def))))))


;;;===============================================================
;;; Model Metadata and Introspection Functions
;;;===============================================================

(defun model-slot-names (model-name)
  "Returns a list of slot names defined for the specified model."
  (let ((schema (gethash model-name *model-schemas*)))
    (unless schema
      (error "Unknown model name: ~S. Ensure it's defined with defmodel." model-name))
    (mapcar #'slot-definition-name (model-schema-slots schema))))

(defun model-slot-definition (model-name slot-name)
  "Returns the slot definition struct for a specific slot."
  (let* ((schema (gethash model-name *model-schemas*))
         (slot-def (and schema (find slot-name (model-schema-slots schema)
                                     :key #'slot-definition-name))))
    (unless schema
      (error "Unknown model name: ~S. Ensure it's defined with defmodel." model-name))
    (unless slot-def
      (error "Unknown slot ~S for model ~S. Check slot definition in defmodel." slot-name model-name))
    slot-def))

(defun model-slot-type (model-name slot-name)
  "Returns the type specifier for a model slot."
  (slot-definition-type (model-slot-definition model-name slot-name)))

(defun model-slot-initform (model-name slot-name)
  "Returns the default value expression for a model slot."
  (slot-definition-initform (model-slot-definition model-name slot-name)))

(defun model-slot-validator (model-name slot-name)
  "Returns the validator function or symbol for a model slot."
  (slot-definition-validator (model-slot-definition model-name slot-name)))

(defun model-slot-observe? (model-name slot-name)
  "Returns whether a model slot has the observe flag set."
  (slot-definition-observe (model-slot-definition model-name slot-name)))

(defun model-schema-info (model-name)
  "Returns a formatted string with information about a model's schema."
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
