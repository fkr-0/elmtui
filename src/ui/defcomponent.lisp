(uiop:define-package :elmtui.ui.defcomponent
  (:use :cl)
  (:import-from :alexandria #:make-keyword)
  (:import-from :elmtui.state.api
    #:make-update-result
    #:ur-patches
    #:ur-commands
    #:update-result
    #:get-path
    #:application-state-data)
  (:import-from :elmtui.ui.api
    #:view
    #:component      ;; Base class for components
    #:component-id      ;; Base class for components
    #:id-from-path
    )        ;; Use the UI API version that takes app-state
  (:import-from :elmtui.core.errors
    #:defcomponent-error
    #:suggest-fixes
    #:with-error-context)
  (:import-from :elmtui.api #:dsl-type)
  (:import-from :elmtui.ui.component-metaclass
    #:component-class
    #:make-metadata)
  (:export #:defcomponent #:cclass-name))

(in-package :elmtui.ui.defcomponent)

;; Global registry to store component state slots for inheritance
(defparameter *component-state-slots* (make-hash-table :test 'eq)
  "Hash table mapping component class names to their state slot definitions for inheritance.")
(defun %plist-hash-table (plist &key (test 'equal))
  "Convert PLIST to a hash-table."
  (let ((ht (make-hash-table :test test)))
    (loop for (k v) on plist by #'cddr
      do (setf (gethash k ht) v))
    ht))
;; Hybrid state accessor that works with both hash tables and plists
(defun get-state-value (key state &optional default)
  "Get value from state that can be either a hash table or plist.
   Returns DEFAULT if KEY is not found or STATE is nil."
  (cond
    ((null state) default)
    ((hash-table-p state) (gethash key state default))
    ((listp state) (getf state key default))
    (t default)))

(defun (setf get-state-value) (value state key)
  "Set value in state that can be either a hash table or plist.
   For hash tables, modifies in place. For plists, returns new plist."
  (cond
    ((hash-table-p state) (setf (gethash key state) value) value)
    ((listp state) (setf (getf state key) value))
    (t (error "Cannot set state value: state is neither hash table nor list"))))

;; Helper function to convert plist to hash-table (replaces alexandria:plist-hash-table)
(defun plist-hash-table (plist &key (test 'eql))
  "Convert a plist to a hash table."
  (let ((hash-table (make-hash-table :test test)))
    (loop for (key value) on plist by #'cddr
      do (setf (gethash key hash-table) value)
      finally (return hash-table))))

;; Function to collect inherited state slots from superclasses
(defun collect-inherited-state-slots (superclass-names)
  "Collects state slots from superclass components that were defined with defcomponent.
   Returns a list of state slot plists merged from all superclasses."
  (let ((inherited-slots nil))
    (dolist (superclass-name superclass-names)
      (when (symbolp superclass-name)
        (let ((parent-slots (gethash superclass-name *component-state-slots*)))
          (when parent-slots
            ;; Merge parent slots, with earlier superclasses taking precedence
            (dolist (slot parent-slots)
              (unless (find (getf slot :name) inherited-slots 
                        :key (lambda (s) (getf s :name)))
                (push slot inherited-slots)))))))
    (nreverse inherited-slots)))

;;===================================================================
;; DSL Type Inference Helper
;;===================================================================

(defun infer-dsl-type-from-class-name (class-name)
  "Infer DSL keyword from class name.
- my-button => :my-button
- ui.widgets:label => :label (strips package)
- my-component => :my-component"
  (let ((name (symbol-name class-name)))
    ;; Find the last colon if present (package qualifier)
    (let ((colon-pos (position #\: name :from-end t)))
      (if colon-pos
          ;; Strip package prefix
          (make-keyword (subseq name (1+ colon-pos)))
          ;; No package, just keyword-ize
          (make-keyword name)))))

(defgeneric cclass-name (cls)
  (:documentation "Returns a keyword symbol representing the component class type, e.g., :my-button."))

;;===================================================================
;; Compile-time Validation Functions
;;===================================================================

(defun validate-component-name (name)
  "Validate component name at compile time."
  (with-error-context (:operation "validate-component-name" :module "defcomponent")
    (unless (symbolp name)
      (error 'defcomponent-error
        :validation-type "invalid-component-name"
        :macro-arg name
        :context "Component name must be a symbol"
        :suggestions (suggest-fixes
                       (format nil "Use a symbol like '~A instead of ~A"
                         (if (stringp name) (intern name :keyword) 'my-component) name))))

    (when (keywordp name)
      (error 'defcomponent-error
        :validation-type "keyword-component-name"
        :macro-arg name
        :context "Component name should not be a keyword"
        :suggestions (suggest-fixes
                       (format nil "Use a symbol like '~A instead of keyword :~A"
                         (intern (subseq (symbol-name name) 1)) name))))))

(defun validate-state-specs (state-specs)
  "Validate state specifications at compile time."
  (dolist (spec state-specs)
    (with-error-context (:operation "validate-state-specs" :macro-arg spec)
      (unless (listp spec)
        (error 'defcomponent-error
          :validation-type "malformed-state-spec"
          :macro-arg spec
          :context "Each state spec must be a list"
          :suggestions (suggest-fixes
                         "State specs should look like: (slot-name initial-value &key type doc)"
                         "Example: (counter 0 :type integer :doc \"Counter value\")")))

      (unless (>= (length spec) 2)
        (error 'defcomponent-error
          :validation-type "incomplete-state-spec"
          :macro-arg spec
          :context "State spec must have at least name and initial value"
          :suggestions (suggest-fixes
                         "State spec format: (slot-name initial-value &key type documentation accessor initarg)")))

      (let ((name (first spec))
             (initial-value (second spec))
             (options (cddr spec)))
        (unless (symbolp name)
          (error 'defcomponent-error
            :validation-type "invalid-slot-name"
            :macro-arg name
            :context "Slot name must be a symbol"
            :suggestions (suggest-fixes
                           "Use a symbol like 'counter instead of strings or other types")))

        (when (keywordp name)
          (error 'defcomponent-error
            :validation-type "keyword-slot-name"
            :macro-arg name
            :context "Slot names should be symbols, not keywords"
            :suggestions (suggest-fixes
                           (format nil "Use '~A instead of ~A"
                             (intern (subseq (symbol-name name) 1)) name))))

        ;; Validate type and initial-value consistency
        (let ((type (getf options :type)))
          (when (and type (null initial-value)
                  (not (and (consp type)
                         (member 'null type))))
            (error 'defcomponent-error
              :validation-type "type-mismatch"
              :macro-arg spec
              :context (format nil "Slot ~A declares type ~A but has NIL as initial value" name type)
              :suggestions (suggest-fixes
                             (format nil "Provide a valid default value for ~A" name)
                             (format nil "Or use (or null ~A) to allow null values" type)
                             (format nil "Example: (~A nil :type (or null ~A) :doc \"Optional ~A\")"
                               name type name)))))))))

(defun validate-clause-structure (clauses component-name)
  "Validate the overall structure of defcomponent clauses."
  (declare (ignorable component-name))
  (let ((valid-clauses '(:state :init :update :view :on-unhandled-message :documentation :metadata)))
    (dolist (clause clauses)
      ;; Skip nil clauses (can happen with empty lists)
      (when clause
        (with-error-context (:operation "validate-clause-structure"
                              :component-id component-name
                              :macro-arg clause)
          (unless (and (consp clause) (keywordp (car clause)))
            (error 'defcomponent-error
              :validation-type "invalid-clause-format"
              :macro-arg clause
              :context "Each clause must start with a keyword"
              :suggestions (suggest-fixes
                             (format nil "Valid clauses are: ~{~A~^, ~}" valid-clauses)
                             "Example: (:state ((counter 0)))")))

          (unless (member (car clause) valid-clauses)
            (error 'defcomponent-error
              :validation-type "unknown-clause"
              :macro-arg (car clause)
              :context (format nil "Unknown clause: ~A" (car clause))
              :suggestions (suggest-fixes
                             (format nil "Valid clauses are: ~{~A~^, ~}" valid-clauses)))))))))

(defun validate-handler-specs (handler-specs component-name)
  "Validate message handler specifications in the update clause."
  (declare (ignorable component-name))
  (when handler-specs  ; Only validate if handler-specs is provided
    (dolist (spec handler-specs)
      (with-error-context (:operation "validate-handler-specs"
                            :component-id component-name
                            :macro-arg spec)
        (unless (and (consp spec) (keywordp (car spec)))
          (error 'defcomponent-error
            :validation-type "invalid-handler-spec"
            :macro-arg spec
            :context "Handler specs must start with a keyword"
            :suggestions (suggest-fixes
                           "Handler format: (:TAG (params...) body...)"
                           "Example: (:increment (amount) ...)")))

        (when (eq (car spec) :otherwise)
          (when (cdr spec)
            (let ((params (cadr spec)))
              (unless (and (listp params) (every #'symbolp params))
                (error 'defcomponent-error
                  :validation-type "invalid-otherwise-params"
                  :macro-arg params
                  :context ":otherwise clause parameters must be a list of symbols"
                  :suggestions (suggest-fixes
                                 "Use: (:otherwise (msg) ...)"
                                 "Or: (:otherwise () ...) for no parameters"))))))))))

;; Helper to parse the :state clause
(defun parse-state-clause (state-specs)
  "Parses the :state clause with enhanced validation.
Each spec is (slot-name initial-value &key type documentation).
Returns a list of plists, each representing a slot:
'((:name label :keyword :label :initial-value \"Click Me\" :type string :doc \"...\") ...)"
  (validate-state-specs state-specs)
  (loop for spec in state-specs
    collect (destructuring-bind (name initial-value &key type documentation
                                  accessor initarg) spec
              (list :name name
                :accessor (when accessor (intern (symbol-name accessor) :keyword))
                :initarg (when initarg (intern (symbol-name initarg) :keyword))
                :keyword (intern (symbol-name name) :keyword)
                :initial-value initial-value
                :type type
                :documentation documentation))))

;; Helper to find a specific clause in the defcomponent body
(defun find-clause (clauses keyword)
  (find keyword clauses :key #'car))

;; Helper to parse the :metadata clause
(defun parse-metadata-clause (metadata-clause)
  "Parses the :metadata clause and returns a make-metadata form.

   The :metadata clause has the format:
   (:metadata
     (:props ((:prop1 type1 required1 :doc \"doc1\")
              (:prop2 type2 required2 :default default2 :doc \"doc2\")))
     (:documentation \"Component description\")
     (:examples '((:my-component :prop1 val1) (:my-component :prop2 val2))))

   Returns a form that evaluates to a metadata plist."
  (let ((body (cdr metadata-clause)))
    (let (props documentation examples)
      (dolist (item body)
        (unless (and (consp item) (keywordp (car item)))
          (error 'defcomponent-error
            :validation-type "invalid-metadata-item"
            :macro-arg item
            :context "Metadata items must be keyword-value pairs"
            :suggestions "Use :props, :documentation, or :examples"))
        (case (car item)
          (:props
           (setf props (cadr item)))
          (:documentation
           (unless (stringp (cadr item))
             (error 'defcomponent-error
               :validation-type "invalid-documentation"
               :macro-arg item
               :context ":documentation must be a string"
               :suggestions "Example: (:documentation \"A button component\")"))
           (setf documentation (cadr item)))
          (:examples
           (unless (and (listp (cadr item))
                        (every #'listp (cadr item)))
             (error 'defcomponent-error
               :validation-type "invalid-examples"
               :macro-arg item
               :context ":examples must be a list of list forms"
               :suggestions "Example: (:examples '((:button :text \"Click\")))"))
           (setf examples (cadr item)))
          (otherwise
           (error 'defcomponent-error
             :validation-type "unknown-metadata-item"
             :macro-arg (car item)
             :context (format nil "Unknown metadata item: ~A" (car item))
             :suggestions "Valid items are :props, :documentation, and :examples"))))
      (make-metadata
       :props props
       :documentation documentation
       :examples examples))))

;; Helper to get the body of a clause (everything after the keyword)
(defun clause-body (clause)
  (cdr clause))
(defun ensure-state-slots-strict (slot-spec state)
  "Ensures all declared slots are present and of the correct type in STATE.
Signals an error if any slot is missing or of the wrong type."
  (loop for slot in slot-spec
    for key = (getf slot :keyword)
    for type = (getf slot :type)
    do (unless (getf state key)
         (error "Missing required slot ~A in state: ~S" key state))
    do (when (and type (not (typep (getf state key) type)))
         (error "Slot ~A has wrong type: ~S (expected ~A)" key (getf state key) type))
    finally (return state)))
;; Helper to generate dispatch code for the :update clause
(defun generate-update-dispatch-code (message-var local-state-var app-state-var id-path-var
                                       handler-specs component-class-name on-unhandled-message-behavior)
  "Generates Lisp code for dispatching messages within an :update method.
   - VARS: The symbols used in the main :update lambda list for message, local-state, etc.
   - HANDLER-SPECS: A list of forms like '(:TAG (payload-vars...) body...)'.
   - COMPONENT-CLASS-NAME: The symbol name of the component class, for logging/errors.
   - ON-UNHANDLED-MESSAGE-BEHAVIOR: Keyword (:no-op, :log, :error) for unhandled messages.

  Example HANDLER-SPECS:
    '((:increment (amount)
        (values `(:count ,(+ (getf local-state :count 0) amount)) nil))
      (:decrement (amount)
        (values `(:count ,(- (getf local-state :count 0) amount)) nil))
      (:otherwise ()
        (values nil nil"
  (declare (ignorable local-state-var app-state-var))
  (let ((case-clauses nil)
         (otherwise-clause-code nil)
         (otherwise-lambda-list nil))

    ;; Parse handler-specs into case clauses and an otherwise clause
    (dolist (spec handler-specs)
      (unless (and (consp spec) (keywordp (first spec)) (consp (cdr spec)) (listp (second spec)))
        (error "Malformed handler spec in :update for ~A: ~S. Expected (:TAG (payload-vars...) body...)"
          component-class-name spec))
      (let ((tag (first spec))
             (payload-lambda-list (second spec))
             (handler-body (cddr spec)))
        (if (eq tag :otherwise)
          (progn
            (when otherwise-clause-code
              (error "Multiple :otherwise clauses in :update handler for ~A." component-class-name))
            (setf otherwise-clause-code
              `(let ,(if payload-lambda-list
                       ;; Bind the first var to the full message, ignore the rest
                       `((,(first payload-lambda-list) ,message-var))
                       nil)
                 (declare (ignorable ,@(remove nil payload-lambda-list)))
                 ,@(mapcar (lambda (form) (transform-update-code form local-state-var)) handler-body)))
            (setf otherwise-lambda-list payload-lambda-list))
          (push
            `(,tag
               ,(if payload-lambda-list
                  `(destructuring-bind ,payload-lambda-list (cdr ,message-var)
                     (declare (ignorable ,@(remove nil payload-lambda-list)))
                     ,@(mapcar (lambda (form) (transform-update-code form local-state-var)) handler-body))
                  `(progn ,@(mapcar (lambda (form) (transform-update-code form local-state-var)) handler-body))))
            case-clauses))))

    (let ((unhandled-message-form
            (case on-unhandled-message-behavior
              (:error `(error "Unhandled message for component ~A (id-path ~A): ~S"
                         ',component-class-name ,id-path-var ,message-var))
              (:log `(progn
                       (warn "Unhandled message for component ~A (id-path ~A): ~S"
                         ',component-class-name ,id-path-var ,message-var)
                       (values nil nil)))
              (otherwise `(values nil nil)))))

      `(if (and ,message-var (consp ,message-var)) ; Message is (TAG . PAYLOAD)
         (case (car ,message-var)
           ,@(nreverse case-clauses)
           (otherwise ,(or otherwise-clause-code unhandled-message-form)))
         ;; Message is not a cons (e.g., an atom) or is nil.
         ;; Handle with 'otherwise' if it exists and its lambda-list expects one arg (the full message).
         ,(if (and otherwise-clause-code
                otherwise-lambda-list
                (= 1 (length otherwise-lambda-list)))
            otherwise-clause-code
            unhandled-message-form)))))

;; Transform user update code to use hybrid state accessors
(defun transform-update-code (code-form local-state-var)
  "Transform CODE-FORM to replace getf calls with get-state-value calls for local-state access.
   This allows user code to work with both hash table and plist storage formats."
  (typecase code-form
    (cons
      (if (and (eq (first code-form) 'getf)
            (eq (second code-form) local-state-var)
            (>= (length code-form) 3))
        ;; Replace (getf local-state :key default) with (get-state-value :key local-state default)
        (let ((key (third code-form))
               (default (when (>= (length code-form) 4) (fourth code-form))))
          (if default
            `(get-state-value ,key ,local-state-var ,default)
            `(get-state-value ,key ,local-state-var)))
        ;; Recursively transform sub-expressions
        (mapcar (lambda (sub-form) (transform-update-code sub-form local-state-var))
          code-form)))
    (otherwise code-form)))

(defun merge-state-slots (inherited-slots local-slots)
  "Merges inherited state slots with local state slots. Local slots take precedence."
  (let ((merged-slots (copy-list inherited-slots)))
    (dolist (local-slot local-slots)
      (let ((local-name (getf local-slot :name)))
        ;; Remove any inherited slot with the same name (local takes precedence)
        (setf merged-slots (remove-if (lambda (slot) 
                                        (eq (getf slot :name) local-name))
                             merged-slots))
        ;; Add the local slot
        (push local-slot merged-slots)))
    (nreverse merged-slots)))

(defmacro defcomponent (name (&rest direct-superclasses)
                         &body body)
  "Defines a new UI component class with declarative state, init, update, and view logic.

SYNTAX:
(defcomponent component-name (superclass1 superclass2 ...)
  (:state (slot1-name initial-value1 &key type doc)
          (slot2-name initial-value2 &key type doc)
          ...)

  (:init (props self-id-path)
    (values '(:slot1-name val1) nil))

  (:update (msg state app-state id-path)
    (:increment (amount)
      (values `(:count ,(+ (getf state :count 0) amount)) nil)))

  (:view (local-state-map app-state self-id-path)
    `(:label :id (elmtui.ui.api:id-from-path self-id-path)
             :text (getf local-state-map :text \"Default Text View\")))

  ...other-class-options...)
"
  ;; Perform compile-time validation
  (validate-component-name name)
  (validate-clause-structure body name)

  (let* ((effective-superclasses (if direct-superclasses
                                   direct-superclasses
                                   '(elmtui.ui.api:component)))
          (component-class-name name)
          (state-clause (find-clause body :state))
          (init-clause (find-clause body :init))
          (update-clause (find-clause body :update))
          (view-clause (find-clause body :view))
          (metadata-clause (find-clause body :metadata))
          (documentation-clause (find-clause body :documentation))
          (other-options (remove-if (lambda (item)
                                      (and (consp item)
                                        (member (car item) '(:state :init :update :view :on-unhandled-message :documentation :metadata) :test #'eq)))
                           body))
          (on-unhandled-message-option (assoc :on-unhandled-message body))
          (on-unhandled-behavior (if on-unhandled-message-option
                                   (second on-unhandled-message-option)
                                   :no-op))
          (local-state-slots (if state-clause
                               (parse-state-clause (clause-body state-clause))
                               nil))
          (inherited-state-slots (collect-inherited-state-slots effective-superclasses))
          (parsed-state-slots (merge-state-slots inherited-state-slots local-state-slots))
          (has-metadata-p (not (null metadata-clause)))
          (use-metaclass-p (or has-metadata-p
                                (loop for super in effective-superclasses
                                      thereis (and (symbolp super)
                                                   (find-class super nil)
                                                   (typep (find-class super nil) 'component-class)))))
          (effective-metaclass (if use-metaclass-p 'component-class 'standard-class)))

    ;; Validate update clause if present
    (when update-clause
      (let ((update-body-forms (clause-body update-clause)))
        (when (cdr update-body-forms)  ; Skip lambda list, validate only handler specs
          (validate-handler-specs (cdr update-body-forms) name))))

    (let* ((state-initarg-params (loop for slot in parsed-state-slots
                                   for slot-name = (getf slot :name)
                                   for custom-initarg = (getf slot :initarg)
                                   for generated-initarg = (intern (format nil "INITIAL-~A" (symbol-name slot-name)) :keyword)
                                   ;; Support both custom initarg and generated INITIAL- form
                                   append (if custom-initarg
                                            `((,custom-initarg ,(getf slot :initial-value))
                                               (,generated-initarg ,(getf slot :initial-value)))
                                            `((,generated-initarg ,(getf slot :initial-value))))))
            (state-initarg-names (mapcar (lambda (param)
                                           (let ((name (first param)))
                                             (if (keywordp name)
                                               ;; Convert keyword to symbol for lambda list
                                               (intern (symbol-name name))
                                               name)))
                                   state-initarg-params))
            (class-documentation-string (if documentation-clause
                                          (second documentation-clause)
                                          (format nil "A UI component class ~A, defined with defcomponent." name)))
            (other-class-options (remove-if (lambda (item)
                                              (or (null item)
                                                (and (consp item) (eq (car item) :documentation))))
                                   other-options)))

      `(eval-when (:compile-toplevel :load-toplevel :execute)
         (defclass ,component-class-name ,effective-superclasses
           ()
           (:metaclass ,effective-metaclass)
           (:documentation ,class-documentation-string)
           ,@(when has-metadata-p
               `((:metadata ,(parse-metadata-clause metadata-clause))))
           ,@other-class-options)

         (defmethod cclass-name ((instance ,component-class-name))
           ',(intern (symbol-name component-class-name) :keyword))

         ,(if init-clause
            (let* ((init-body-forms (clause-body init-clause))
                    (init-lambda-list (first init-body-forms))
                    (init-user-code (rest init-body-forms))
                    (id-sym (gensym "ID")))

              `(defmethod elmtui.ui.api:init ((self ,component-class-name) &rest initargs &key id-path &allow-other-keys)
                 (declare (ignorable id-path initargs))
                 (let ((,id-sym (elmtui.ui.api:id-from-path id-path))
                        (,(first init-lambda-list) initargs)
                        (,(second init-lambda-list) id-path))
                   ;; (declare (ignorable ,@(remove nil (rest init-lambda-list))))
                   (declare (ignorable ,@(remove nil init-lambda-list)))
                   (destructuring-bind (user-initial-state-plist &rest other-values)
                     (multiple-value-list (progn ,@init-user-code))
                     (let* ((user-patches (first other-values))
                             (user-commands (second other-values))
                             (final-state-ht (make-hash-table :test 'eq)))
                       (setf (gethash :type final-state-ht) (cclass-name self))
                       (setf (gethash :id final-state-ht) ,id-sym)
                       ,@(loop for slot in parsed-state-slots
                           for slot-kw = (getf slot :keyword)
                           for slot-name-sym = (getf slot :name)
                           for custom-initarg = (getf slot :initarg)
                           for generated-initarg = (intern (format nil "INITIAL-~A" (symbol-name slot-name-sym)) :keyword)
                           collect `(setf (gethash ,slot-kw final-state-ht)
                                      (getf user-initial-state-plist ,slot-kw
                                        ,(if custom-initarg
                                           `(or (getf initargs ,custom-initarg)
                                              (getf initargs ,generated-initarg)
                                              ,(getf slot :initial-value))
                                           `(getf initargs ,generated-initarg
                                              ,(getf slot :initial-value))))))
                       (loop for (key val) on user-initial-state-plist by #'cddr
                         unless (find key ',(mapcar (lambda (s) (getf s :keyword)) parsed-state-slots) :test #'eq)
                         do (setf (gethash key final-state-ht) val))
                       (values self
                         (append (list (list id-path final-state-ht)) user-patches)
                         user-commands))))))
            `(defmethod elmtui.ui.api:init ((self ,component-class-name) &rest other-keys &key id-path ,@state-initarg-names &allow-other-keys)
               (declare (ignorable id-path ,@state-initarg-names other-keys))
               (let ((component-id (elmtui.ui.api:id-from-path id-path))
                      (state-ht (make-hash-table :test 'eq)))
                 (setf (elmtui.ui.api:component-id self) component-id)
                 (setf (gethash :type state-ht) (cclass-name self))
                 (setf (gethash :id state-ht) component-id)
                 ,@(loop for slot in parsed-state-slots
                     for slot-kw = (getf slot :keyword)
                     for slot-name = (getf slot :name)
                     for custom-initarg = (getf slot :initarg)
                     for generated-initarg = (intern (format nil "INITIAL-~A" (symbol-name slot-name)) :keyword)
                     unless (eq slot-kw :id)
                     collect `(setf (gethash ,slot-kw state-ht)
                                ,(if custom-initarg
                                   `(or (getf other-keys ,custom-initarg)
                                      (getf other-keys ,generated-initarg)
                                      ,(getf slot :initial-value))
                                   `(getf other-keys ,generated-initarg ,(getf slot :initial-value)))))
                 ;; ensure-state-slots-strict needs to be adapted for hash-tables if used
                 (values self
                   (list (list id-path state-ht))
                   nil))))
         ;; `(defmethod elmtui.ui.api:init ((self ,component-class-name) &rest other-keys &key id-path ,@state-initarg-names &allow-other-keys)
         ;;    (declare (ignorable id-path ,@state-initarg-names other-keys))
         ;;    (let ((component-id (elmtui.ui.api:id-from-path id-path))
         ;;          (state-plist (list)))
         ;;      (setf (elmtui.ui.api:component-id self) component-id)
         ;;      (setf (getf state-plist :type) (cclass-name self))
         ;;      (setf (getf state-plist :id) component-id)
         ;;      ,@(loop for slot in parsed-state-slots
         ;;              for slot-kw = (getf slot :keyword)
         ;;              for slot-name = (getf slot :name)
         ;;              for custom-initarg = (getf slot :initarg)
         ;;              for generated-initarg = (intern (format nil "INITIAL-~A" (symbol-name slot-name)) :keyword)
         ;;              unless (eq slot-kw :id)
         ;;                collect `(setf (getf state-plist ,slot-kw)
         ;;                               ;; Try custom initarg first, then generated initarg, then default
         ;;                               ,(if custom-initarg
         ;;                                    `(or (getf other-keys ,custom-initarg)
         ;;                                         (getf other-keys ,generated-initarg)
         ;;                                         ,(getf slot :initial-value))
         ;;                                    `(getf other-keys ,generated-initarg ,(getf slot :initial-value)))))
         ;;      (values self
         ;;              (list (list id-path state-plist))
         ;;              nil))))

         ,(if update-clause
            (let* ((update-body-forms (clause-body update-clause))
                    (update-lambda-list (first update-body-forms))
                    (update-user-code-block (rest update-body-forms)))
              (destructuring-bind
                (message-var &optional path-var app-state-var id-path-var ctx-var)
                update-lambda-list
                `(defmethod elmtui.ui.api:update ((self ,component-class-name) message app-state &key id-path)
                   (declare (ignorable message app-state id-path))
                   (multiple-value-bind (message* app-state*)
                     (elmtui.ui.api:normalize-update-args message app-state)
                     (let* ((,path-var (let ((raw (get-path id-path app-state*)))
                                         (if (hash-table-p raw)
                                           (cl-state.utils:hash-table->plist raw)
                                           raw)))
                             (,app-state-var app-state*)
                             (,id-path-var id-path)
                             (ctx# (elmtui.state.update:make-update-context
                                     app-state*
                                     :base-path (elmtui.ui.api:component-state-map-path id-path)))
                             ,@(when ctx-var `((,ctx-var ctx#))))
                       (declare (ignorable ,@(remove nil (list path-var app-state-var id-path-var ctx-var))))
                       (let ((,message-var message*))
                         (declare (ignorable ,message-var))
                         (multiple-value-bind (default-patches default-commands)
                           (if (fboundp 'call-next-method)
                             (call-next-method)
                             (values nil nil))
                           (declare (ignorable default-patches default-commands))
                           (let* ((returned-values
                                    (multiple-value-list
                                      (multiple-value-call #'values
                                        ,(generate-update-dispatch-code
                                           message-var path-var app-state-var id-path-var
                                           update-user-code-block
                                           component-class-name
                                           on-unhandled-behavior))))
                                   (ctx-patches (elmtui.state.update:context-patches ctx#))
                                   (ctx-commands (elmtui.state.update:context-commands ctx#))
                                   (local-changes nil)
                                   (extra-patches nil)
                                   (extra-commands nil))
                             (cond
                               ((and (= (length returned-values) 1)
                                  (typep (first returned-values) 'update-result))
                                 (let ((ur (first returned-values)))
                                   (setf extra-patches (ur-patches ur)
                                     extra-commands (ur-commands ur))))
                               ((= (length returned-values) 2)
                                 (setf local-changes (first returned-values)
                                   extra-commands (second returned-values)))
                               ((or (null returned-values) (equal returned-values '(nil)))
                                 (setf local-changes nil
                                   extra-commands nil))
                               (t
                                 (error "Malformed component update return: ~S" returned-values)))
                             (when local-changes
                               (if (and (listp local-changes)
                                     (consp (first local-changes))
                                     (listp (first local-changes)))
                                 (setf extra-patches local-changes)
                                 (let* ((local-changes-ht (when local-changes
                                                            (%plist-hash-table local-changes :test 'eq)))
                                         (custom-patches
                                           (when local-changes-ht
                                             (loop for key being the hash-keys of local-changes-ht
                                               using (hash-value val)
                                               collect (list (elmtui.ui.api:component-state-path id-path key) val)))))
                                   (setf extra-patches custom-patches))))
                             (make-update-result
                               :patches (append default-patches ctx-patches extra-patches)
                               :commands (append default-commands ctx-commands extra-commands))))))))))
            `(defmethod elmtui.ui.api:update ((self ,component-class-name) message app-state &key id-path)
               (declare (ignore message app-state id-path))
               (make-update-result :patches nil :commands nil)))

         ,(if view-clause
            (let* ((view-body-forms (clause-body view-clause))
                    (view-lambda-list (first view-body-forms))
                    (view-user-code (rest view-body-forms)))
              `(defmethod elmtui.ui.api:view ((self ,component-class-name) app-state &key id-path children)
                 (declare (ignorable ;; ,@(remove nil view-lambda-list)
                            id-path children
                            ))
                 (let ((,(first view-lambda-list) (let ((raw (get-path id-path app-state)))
                                                    (if (hash-table-p raw)
                                                      (cl-state.utils:hash-table->plist raw)
                                                      raw))))
                   (if ,(first view-lambda-list)
                     (let ((,(second view-lambda-list) app-state)
                            (,(third view-lambda-list) id-path)
                            (,(nth 3 view-lambda-list) children))
                       (declare (ignorable ,@(list (third view-lambda-list) (second view-lambda-list) (nth 3 view-lambda-list))));remove nil view-lambda-list)))
                       ,@(mapcar (lambda (form) (transform-update-code form (first view-lambda-list))) view-user-code))
                     (call-next-method)))))
            `(defmethod elmtui.ui.api:view ((self ,component-class-name) app-state &key id-path children)
               (declare (ignore children app-state))
               (list (cclass-name self)
                 :id (elmtui.ui.api:id-from-path id-path)
                 :message "View not implemented for this component.")))

         ,@(loop for slot in parsed-state-slots
             for accessor-name = (getf slot :accessor)
             for slot-keyword = (getf slot :keyword)
             for slot-initial-value = (getf slot :initial-value)
             when accessor-name
             collect `(defmethod ,(intern (symbol-name accessor-name)) (app-state component &key (id-path (list :components (elmtui.ui.api:component-id component))))
                        (declare (ignore id-path))
                        (let* ((full-path (append '(:components) (list (component-id component))))
                                (comp-state (get-path full-path (application-state-data app-state))))
                          (cond ((hash-table-p comp-state)
                                  (gethash ,slot-keyword comp-state ,slot-initial-value))
                            ((listp comp-state)
                              (getf comp-state ,slot-keyword ,slot-initial-value))
                            (t ,slot-initial-value)))))

         ;; Auto-generate dsl-type method for this component
         (defmethod dsl-type ((type (eql ,(infer-dsl-type-from-class-name component-class-name))) &optional props)
           (values ',component-class-name props))

         (eval-when (:compile-toplevel :load-toplevel :execute)
           (setf (gethash ',component-class-name *component-state-slots*) ',parsed-state-slots))

         ',component-class-name))))
;; == elmtui/src/ui/defcomponent.lisp ==
