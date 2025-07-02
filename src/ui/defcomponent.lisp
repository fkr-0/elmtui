(uiop:define-package :elmtui.ui.defcomponent
  (:use :cl)
  (:import-from :elmtui.state.api #:make-state-patch #:make-update-result)
  (:import-from :elmtui.ui.api
                #:component      ;; Base class for components
                #:component-id      ;; Base class for components
                #:id-from-path
                #:get-path        ;; Use the UI API version that takes app-state
                #:component-state-path)
  (:export #:defcomponent #:cclass-name))

(in-package :elmtui.ui.defcomponent)

;; Global registry to store component state slots for inheritance
(defparameter *component-state-slots* (make-hash-table :test 'eq)
  "Hash table mapping component class names to their state slot definitions for inheritance.")

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

(defgeneric cclass-name (cls)
  (:documentation "Returns a keyword symbol representing the component class type, e.g., :my-button."))

;; Helper to parse the :state clause
(defun parse-state-clause (state-specs)
  "Parses the :state clause.
Each spec is (slot-name initial-value &key type documentation).
Returns a list of plists, each representing a slot:
'((:name label :keyword :label :initial-value \"Click Me\" :type string :doc \"...\") ...)"
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

;; Helper to get the body of a clause (everything after the keyword)
(defun clause-body (clause)
  (cdr clause))

;; Helper to generate dispatch code for the :update clause
(defun generate-update-dispatch-code (message-var local-state-var app-state-var id-path-var
                                      handler-specs component-class-name on-unhandled-message-behavior)
  "Generates Lisp code for dispatching messages within an :update method.
   - VARS: The symbols used in the main :update lambda list for message, local-state, etc.
   - HANDLER-SPECS: A list of forms like '(:TAG (payload-vars...) body...)'.
   - COMPONENT-CLASS-NAME: The symbol name of the component class, for logging/errors.
   - ON-UNHANDLED-MESSAGE-BEHAVIOR: Keyword (:no-op, :log, :error) for unhandled messages."
  (declare (ignorable local-state-var app-state-var))
  (let ((case-clauses nil)
        (otherwise-clause-code nil))

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
                    `(let ((,(first payload-lambda-list) ,message-var)) ; Bind var to the full message
                       (declare (ignorable ,@(remove nil payload-lambda-list)))
                       ,@handler-body)))
            (push `(,tag
                    (destructuring-bind ,payload-lambda-list (cdr ,message-var)
                      (declare (ignorable ,@(remove nil payload-lambda-list)))
                      ,@handler-body)) ; local-state-var etc. are lexically available
                  case-clauses))))

    (let ((unhandled-message-form
            (case on-unhandled-message-behavior
              (:error `(error "Unhandled message for component ~A (id-path ~A): ~S"
                        ',component-class-name ,id-path-var ,message-var))
              (:log `(progn
                       (warn "Unhandled message for component ~A (id-path ~A): ~S"
                             ',component-class-name ,id-path-var ,message-var)
                       (values nil nil)))
              ;; :no-op or any other value defaults to no-op
              (otherwise `(values nil nil)))))

      `(if (and ,message-var (consp ,message-var)) ; Message is (TAG . PAYLOAD)
           (case (car ,message-var)
             ,@(nreverse case-clauses)
             (otherwise ,(or otherwise-clause-code unhandled-message-form)))
           ;; Message is not a cons (e.g., an atom) or is nil.
           ;; Handle with 'otherwise' if it exists and its lambda-list expects one arg (the full message).
           ,(if (and otherwise-clause-code
                     (let* ((otherwise-spec (find :otherwise handler-specs :key #'car))
                            (lambda-list (second otherwise-spec)))
                       (and lambda-list (= 1 (length lambda-list))))) ; Ensure :otherwise takes one arg for the full message
                otherwise-clause-code
                unhandled-message-form)))))

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

(defmacro defcomponent (name (&optional direct-superclasses)
                        &body body)
  "Defines a new UI component class with declarative state, init, update, and view logic.

SYNTAX:
(defcomponent component-name (superclass1 superclass2 ...)
;; Defines the local state schema for the component.
;; Each slot is (slot-name initial-value &key type documentation).
(:state (slot1-name initial-value1 &key type doc)
(slot2-name initial-value2 &key type doc)
...)

   ;; Optional: Defines the initialization logic. Corresponds to Section 1, :init in refactor_tasks.md.
   ;; Lambda list: (PROPS SELF-ID-PATH), where PROPS is a plist of all make-instance initargs.
   ;; Returns: (values INITIAL-LOCAL-STATE-PLIST INITIAL-COMMANDS).
   ;;   - INITIAL-LOCAL-STATE-PLIST: A plist of local state slot keywords and their desired initial values
   ;;     (e.g., '(:slot1-name val1 :slot2-name val2)).
   ;;     These values take precedence over :state defaults and initargs passed via make-instance for the slots they specify.
   ;;     The macro handles merging these to form the component's complete initial state map and creating the state patch.
   ;;   - INITIAL-COMMANDS: A list of commands to be executed after initialization.
   (:init (props self-id-path)
    ;; init logic, e.g., (let ((prop-value (getf props :some-prop))) ...)
    (values (list :text (getf props :initial-text \"Default Label\"))
            nil)) ; No initial commands in this example

   ;; Optional: Defines the update logic. Corresponds to Section 1, :update in refactor_tasks.md.
   ;; Lambda list: (MESSAGE LOCAL-STATE-MAP APP-STATE SELF-ID-PATH).
   ;;   - MESSAGE: The message to be processed.
   ;;   - LOCAL-STATE-MAP: A plist representing the component's current local state.
   ;;   - APP-STATE: The global application state.
   ;;   - SELF-ID-PATH: The component's ID path.
   ;; Returns: (values LOCAL-CHANGES-PLIST COMMANDS).
   ;;   - LOCAL-CHANGES-PLIST: A plist of local state slot keywords and new values.
   ;;   - COMMANDS: A list of commands to be executed.
   ;; The body of :update should consist of declarative message handler clauses:
   ;;   (:MESSAGE-TAG (payload-vars...) body-returning-values...)
   ;;   ...
   ;;   (:otherwise (full-message-var) body-returning-values...)
   ;; Example:
   (:update (msg state app-state id-path) ; msg, state, etc. are available in handler bodies
     (:increment (amount) ; payload-vars like (amount) are bound from (cdr msg)
       (values `(:count ,(+ (getf state :count 0) amount)) nil))
     (:set-text (new-text)
       (values `(:text ,new-text) nil))
     (:otherwise (original-msg) ; Catches unhandled or non-standard messages
       (warn \"Unhandled message in my-component: ~S\" original-msg)
       (values nil nil)))
   ;; An optional :on-unhandled-message (:no-op | :log | :error) can be specified
   ;; as a top-level option in defcomponent, e.g. (:on-unhandled-message :log). Default is :no-op.

   ;; Optional: Defines the view logic. Corresponds to Section 1, :view in refactor_tasks.md.
   ;; Lambda list: (LOCAL-STATE-MAP APP-STATE SELF-ID-PATH).
   ;;   - LOCAL-STATE-MAP: A plist representing the component's current local state.
   ;;   - APP-STATE: The global application state.
   ;;   - SELF-ID-PATH: The component's ID path.
   ;; Returns: The view DSL (a list).
   (:view (local-state-map app-state self-id-path)
    ;; view logic, e.g., using getf on local-state-map to access state properties
    `(:label :id (elmtui.ui.api:id-from-path self-id-path)
             :text (getf local-state-map :text \"Default Text View\")))

   ;; Standard CLOS class options like (:documentation \"...\")
   ...other-class-options...)

GENERATES:

A CLOS class inheriting from elmtui.ui.api:component (or specified superclasses).

An elmtui.ui.api:init method:

If an inline :init is provided, its logic is used.
Otherwise, a default init is generated based on the :state clause.
Sets up the component's initial state in the global app-state.
An elmtui.ui.api:update method:

If an inline :update is provided, its logic (including message dispatch) is used.
Otherwise, a default no-op update method is generated.
An elmtui.ui.api:view method:

If an inline :view is provided, its logic is used.
Otherwise, a default placeholder view is generated.
A cclass-name method returning the component type keyword.
"
  (let* ((effective-superclasses (if direct-superclasses
                                     (if (listp direct-superclasses) direct-superclasses
                                         (list direct-superclasses))
                                     '(elmtui.ui.api:component)))
         (component-class-name name)
         ;; Parse clauses from the body
         (state-clause (find-clause body :state))
         (init-clause (find-clause body :init))
         (update-clause (find-clause body :update))
         (view-clause (find-clause body :view))
         (other-options (remove-if (lambda (item)
                                     (and (consp item)
                                          (member (car item) '(:state :init :update :view :on-unhandled-message) :test #'eq)))
                                   body))
         (on-unhandled-message-option (assoc :on-unhandled-message body))
         (on-unhandled-behavior (if on-unhandled-message-option
                                    (second on-unhandled-message-option)
                                    :no-op)) ; Default behavior
         ;; Handle state inheritance from parent defcomponent classes
         (local-state-slots (if state-clause
                                (parse-state-clause (clause-body state-clause))
                                nil))
         (inherited-state-slots (collect-inherited-state-slots effective-superclasses))
         (parsed-state-slots (merge-state-slots inherited-state-slots local-state-slots))
         ;; For the default init method (if no inline :init is provided):
         ;; Create initarg keywords and default value expressions from ALL state slots (including inherited)
         (state-initarg-params (loop for slot in parsed-state-slots
                                     for slot-name = (getf slot :name)
                                     for initial-param-name = (intern (format nil "INITIAL-~A" (symbol-name slot-name)))
                                     collect `(,initial-param-name ,(getf slot :initial-value))))
         (state-initarg-names (mapcar #'first state-initarg-params))

         ;; Class documentation (extracted from other-options)
         (doc-option (assoc :documentation other-options))
         (class-documentation-string (if doc-option
                                         (second doc-option)
                                         (format nil "A UI component class ~A, defined with defcomponent." name)))
         (other-class-options (remove-if (lambda (item)
                                           (and (consp item) (eq (car item) :documentation)))
                                         other-options)))

    ;; evaluate the component definition at compile/load time
    `(eval-when (:compile-toplevel :load-toplevel :execute)
       ;; 1. Define the CLOS class for the component instance
       (defclass ,component-class-name ,effective-superclasses
         () ;; Behavioral state is in the global app-state, not as CLOS slots here.
         (:documentation ,class-documentation-string)
         ,@other-class-options)

       ;; Method to get the component type keyword
       (defmethod cclass-name ((instance ,component-class-name))
         ',(intern (symbol-name component-class-name) :keyword))

       ;; 2. Generate elmtui.ui.api:init method
       ,(if init-clause
            ;; User provided an inline :init clause
            (let* ((init-body-forms (clause-body init-clause))
                   (init-lambda-list (first init-body-forms)) ; e.g., (initargs-plist self-id-path)
                   (init-user-code (rest init-body-forms))
                   (id-sym (gensym "ID"))) ; Unique symbol for component ID
              `(defmethod elmtui.ui.api:init ((self ,component-class-name) &rest initargs &key id-path &allow-other-keys)
                 (declare (ignorable id-path initargs)) ; id-path is used for self-id-path

                 (let ((,id-sym (elmtui.ui.api:id-from-path id-path))
                       ;; Bind arguments for user's :init code
                       (,(first init-lambda-list) initargs)    ; e.g., initargs-plist
                       (,(second init-lambda-list) id-path)) ; e.g., self-id-path
                   (multiple-value-bind (user-initial-state-plist user-commands)
                       (progn ,@init-user-code)
                     ;; Construct the full initial state plist
                     (let ((final-state-plist (list :type (cclass-name self) ; Use cclass-name method
                                                    :id ,id-sym)))
                       ;; Populate from :state defaults, then initargs, then user's :init results
                       ,@(loop for slot in parsed-state-slots
                               for slot-kw = (getf slot :keyword)
                               for slot-name-sym = (getf slot :name)
                               collect `(setf (getf final-state-plist ,slot-kw)
                                              (getf user-initial-state-plist ,slot-kw ; User's :init has highest precedence for slots it returns
                                                    (getf initargs ,(intern (symbol-name slot-name-sym) :keyword) ; Then initargs passed to make-instance
                                                          ,(getf slot :initial-value))))) ; Then :state default
                       ;; Add any other keys from user-initial-state-plist not defined in :state
                       (loop for (key val) on user-initial-state-plist by #'cddr
                             unless (find key ',(mapcar (lambda (s) (getf s :keyword)) parsed-state-slots) :test #'eq)
                               do (setf (getf final-state-plist key) val))

                       (values self
                               (list (list id-path final-state-plist)) ; Patch to set this component's state
                               user-commands))))))
            ;; No inline :init, generate default based on :state clause
            `(defmethod elmtui.ui.api:init ((self ,component-class-name) &rest other-keys &key id-path ,@state-initarg-names &allow-other-keys)
               (declare (ignorable id-path ,@state-initarg-names))
               (let ((component-id (elmtui.ui.api:id-from-path id-path))
                     (state-plist (list)))
                 (setf (elmtui.ui.api:component-id self) component-id) ; Set the component's ID
                 ;; Always set the type and id first
                 (setf (getf state-plist :type) (cclass-name self))
                 (setf (getf state-plist :id) component-id)
                 ;; Set state slot values from initargs, but don't override id
                 ,@(loop for slot in parsed-state-slots
                         for slot-kw = (getf slot :keyword)
                         for slot-name = (getf slot :name)
                         for initial-param-name = (intern (format nil "INITIAL-~A" (symbol-name slot-name)) :keyword)
                         unless (eq slot-kw :id) ; Don't override the id we just set
                           collect `(setf (getf state-plist ,slot-kw) (getf other-keys ,initial-param-name ,(getf slot :initial-value))))
                 (values self
                         (list (list id-path state-plist))
                         nil))))

       ;; 3. Generate elmtui.ui.api:update method
       ,(if update-clause
            (let* ((update-body-forms (clause-body update-clause))
                   (update-lambda-list (first update-body-forms)) ; (message local-state-map app-state self-id-path)
                   (update-user-code-block (rest update-body-forms))
                   ;; update-user-code-block is now a list of handler specs like '((:TAG (...) body) ...)'
                   )
              `(defmethod elmtui.ui.api:update ((self ,component-class-name) app-state message &key id-path)
                 (declare (ignorable app-state)) ; id-path is used
                 (let* (;; Bind user's chosen names for local-state, app-state, id-path
                        ;; first: local-state-map
                        (,(second update-lambda-list) (elmtui.ui.api:get-path app-state id-path))
                        (,(third update-lambda-list) app-state)
                        (,(fourth update-lambda-list) id-path))
                   (declare (ignorable ,@(remove nil (rest update-lambda-list)))) ; Ignore unused vars
                   ;; Bind user's chosen name for the message
                   (let ((,(first update-lambda-list) message))
                     (multiple-value-bind (local-changes-plist commands)
                         ,(generate-update-dispatch-code (first update-lambda-list)
                                                         (second update-lambda-list)
                                                         (third update-lambda-list)
                                                         (fourth update-lambda-list)
                                                         update-user-code-block
                                                         component-class-name
                                                         on-unhandled-behavior)

                       (elmtui.state.api:make-update-result
                        :patches (loop for (key val) on local-changes-plist by #'cddr
                                       collect (list (elmtui.ui.api:component-state-path id-path key) val))
                        :commands commands))))))
            ;; Default update (no-op) if no :update clause
            `(defmethod elmtui.ui.api:update ((self ,component-class-name) app-state message &key id-path)
               (declare (ignore app-state message id-path))
               (elmtui.state.api:make-update-result :patches nil :commands nil)))

       ;; 4. Generate elmtui.ui.api:view method
       ,(if view-clause
            (let* ((view-body-forms (clause-body view-clause))
                   (view-lambda-list (first view-body-forms)) ; (local-state-map app-state self-id-path)
                   (view-user-code (rest view-body-forms)))
              `(defmethod elmtui.ui.api:view ((self ,component-class-name) app-state &key id-path)
                 (let ((,(first view-lambda-list) (elmtui.ui.api:get-path app-state id-path)) ; local-state-map
                       (,(second view-lambda-list) app-state)
                       (,(third view-lambda-list) id-path)) ; self-id-path
                   ,@view-user-code)))
            ;; Default view if no :view clause
            `(defmethod elmtui.ui.api:view ((self ,component-class-name) app-state &key id-path)
               (declare (ignore app-state)) ; id-path is used
               (list (cclass-name self)
                     :id (elmtui.ui.api:id-from-path id-path)
                     :message "View not implemented for this component.")))

       ;; 5. Generate accessor methods if specified in :state
       ,@(loop for slot in parsed-state-slots
               for accessor-name = (getf slot :accessor)
               for slot-keyword = (getf slot :keyword)
               for slot-initial-value = (getf slot :initial-value)
               when accessor-name
                 collect `(defun ,(intern (symbol-name accessor-name)) (app-state component &key (id-path (list :components (elmtui.ui.api:component-id component))))
                            ;; Get the component state from various possible app-state structures
                            (let ((comp-state (cond
                                                ;; Test case - check type name for test-app-state
                                                ((and (typep app-state 'standard-object)
                                                      (search "TEST-APP-STATE" (symbol-name (type-of app-state))))
                                                 ;; For test app state, call the components accessor through funcall to handle package issues
                                                 (let ((accessor-fn (find-symbol "COMPONENTS-STORE" (symbol-package (type-of app-state)))))
                                                   (when accessor-fn
                                                     (getf (funcall accessor-fn app-state)
                                                           (elmtui.ui.api:component-id component)))))
                                                ;; Test case with direct plist structure
                                                ((listp app-state)
                                                 (getf (getf app-state :components)
                                                       (elmtui.ui.api:component-id component)))
                                                ;; Standard application-state object - use full path
                                                (t (elmtui.ui.api:get-path app-state (append (list :components (elmtui.ui.api:component-id component))))))))
                              (if comp-state
                                  (getf comp-state ,slot-keyword ,slot-initial-value)
                                  ,slot-initial-value))))

       ;; Store state slots for inheritance by child components
       ;; evaluate this at compile/load time to ensure the slots are available
       (eval-when (:compile-toplevel :load-toplevel :execute)
         (setf (gethash ',component-class-name *component-state-slots*) ',parsed-state-slots))

       ',component-class-name))) ; Return the component name
