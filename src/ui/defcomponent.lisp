(uiop:define-package :elmtui.ui.defcomponent
  (:use :cl)
  (:import-from :elmtui.state.api #:make-state-patch #:make-update-result #:get-path)
  (:import-from :elmtui.ui.api
                #:component      ;; Base class for components
                #:id-from-path
                #:component-state-path)
  (:export #:defcomponent))

(in-package :elmtui.ui.defcomponent)

(defgeneric cclass-name (cls)
  (:documentation "Returns a keyword symbol representing the component class type, e.g., :my-button."))

;; Helper to parse the :state clause
(defun parse-state-clause (state-specs)
  "Parses the :state clause.
Each spec is (slot-name initial-value &key type documentation).
Returns a list of plists, each representing a slot:
'((:name label :keyword :label :initial-value \"Click Me\" :type string :doc \"...\") ...)"
  (loop for spec in state-specs
        collect (destructuring-bind (name initial-value &key type documentation) spec
                  (list :name name
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

(defmacro defcomponent (name (direct-superclasses)
                        &body body)
  "Defines a new UI component class with declarative state, init, update, and view logic.

SYNTAX:
(defcomponent component-name (superclass1 superclass2 ...)
;; Defines the local state schema for the component.
;; Each slot is (slot-name initial-value &key type documentation).
(:state (slot1-name initial-value1 &key type doc)
(slot2-name initial-value2 &key type doc)
...)

   ;; Optional: Defines the initialization logic.
   ;; Receives all make-instance initargs as a plist, and the component's id-path.
   ;; Returns (values initial-local-state-plist initial-commands).
   ;; `initial-local-state-plist` is a plist of slot keywords and their values.
   (:init (initargs-plist self-id-path)
    ;; init logic...
    (values '(:slot1-name val1) '(command1 command2)))

   ;; Optional: Defines the update logic.
   ;; Receives the incoming message, current local-state-map (a plist),
   ;; the global app-state, and the component's id-path.
   ;; Can contain sub-clauses for specific message types:
   ;;   ((:message-tag (msg local-state app-state id-path)) ...)
   ;; Returns (values local-changes-plist commands).
   ;; `local-changes-plist` is a plist of slot keywords and new values.
   (:update (message local-state-map app-state self-id-path)
    (case (car message)
      (:increment (values '(:count (1+ (getf local-state-map :count))) nil))
      (otherwise (values nil nil))))

   ;; Optional: Defines the view logic.
   ;; Receives current local-state-map, global app-state, and component's id-path.
   ;; Returns the view DSL (a list).
   (:view (local-state-map app-state self-id-path)
    `(:label :id ,(elmtui.ui.api:id-from-path self-id-path)
             :text ,(getf local-state-map :text)))

   ;; Standard CLOS class options like (:documentation \"...\")
   ...other-class-options...)

txt



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
                                     direct-superclasses
                                     '(elmtui.ui.api:component)))
         (component-class-name name)
         ;; Parse clauses from the body
         (state-clause (find-clause body :state))
         (init-clause (find-clause body :init))
         (update-clause (find-clause body :update))
         (view-clause (find-clause body :view))
         (other-options (remove-if (lambda (item)
                                     (and (consp item)
                                          (member (car item) '(:state :init :update :view) :test #'eq)))
                                   body))

         (parsed-state-slots (if state-clause
                                 (parse-state-clause (clause-body state-clause))
                                 nil))
         ;; For the default init method (if no inline :init is provided):
         ;; Create initarg keywords and default value expressions from :state
         (state-initarg-params (loop for slot in parsed-state-slots
                                     collect `(,(intern (symbol-name (getf slot :name))) ; var name for initarg
                                               ,(getf slot :initial-value)))) ; default value
         (state-initarg-names (mapcar #'first state-initarg-params))

         ;; Class documentation (extracted from other-options)
         (doc-option (assoc :documentation other-options))
         (class-documentation-string (if doc-option
                                         (second doc-option)
                                         (format nil "A UI component class ~A, defined with defcomponent." name)))
         (other-class-options (if doc-option (remove doc-option other-options :test #'equal) other-options)))

    `(progn
       ;; 1. Define the CLOS class for the component instance
       (defclass ,component-class-name ,effective-superclasses
         () ;; Behavioral state is in the global app-state, not as CLOS slots here.
         (:documentation ,class-documentation-string)
         ,@other-class-options)

       ;; Method to get the component type keyword
       (defmethod cclass-name ((cls (eql ',component-class-name)))
         (declare (ignore cls))
         ',(intern (symbol-name component-class-name) :keyword))

       ;; 2. Generate elmtui.ui.api:init method
       ,(if init-clause
            ;; User provided an inline :init clause
            (let* ((init-body-forms (clause-body init-clause))
                   (init-lambda-list (first init-body-forms)) ; e.g., (initargs-plist self-id-path)
                   (init-user-code (rest init-body-forms)))
              `(defmethod elmtui.ui.api:init ((self ,component-class-name) &rest initargs &key id-path &allow-other-keys)
                 (declare (ignorable id-path initargs)) ; id-path is used for self-id-path
                 (let ((component-id (elmtui.ui.api:id-from-path id-path))
                       ;; Bind arguments for user's :init code
                       (,(first init-lambda-list) initargs)    ; e.g., initargs-plist
                       (,(second init-lambda-list) id-path)) ; e.g., self-id-path
                   (multiple-value-bind (user-initial-state-plist user-commands)
                       (progn ,@init-user-code)
                     ;; Construct the full initial state plist
                     (let ((final-state-plist (list :type (cclass-name self) ; Use cclass-name method
                                                    :id component-id)))
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
                               user-commands)))))
              ;; No inline :init, generate default based on :state clause
              `(defmethod elmtui.ui.api:init ((self ,component-class-name) &key id-path ,@state-initarg-params &allow-other-keys)
                 (declare (ignorable id-path ,@state-initarg-names))
                 (let ((component-id (elmtui.ui.api:id-from-path id-path))
                       (state-plist (list :type (cclass-name self)
                                          :id component-id)))
                   ,@(loop for slot in parsed-state-slots
                           for slot-kw = (getf slot :keyword)
                           ;; Use the corresponding initarg variable from state-initarg-params
                           for initarg-var = (intern (symbol-name (getf slot :name)))
                           collect `(setf (getf state-plist ,slot-kw) ,initarg-var))
                   (values self
                           (list (list id-path state-plist))
                           nil)))))

       ;; 3. Generate elmtui.ui.api:update method
       ,(if update-clause
            (let* ((update-body-forms (clause-body update-clause))
                   (update-lambda-list (first update-body-forms)) ; (message local-state-map app-state self-id-path)
                   (update-user-code-block (rest update-body-forms))
                   ;; Detect if the user code block is a list of message handlers or general code
                   (message-handlers (if (and update-user-code-block (consp (first update-user-code-block)) (keywordp (caar update-user-code-block)))
                                         update-user-code-block ;; Assumes ((:msg1 ...) ...) or (case ...)
                                         nil)))
              `(defmethod elmtui.ui.api:update ((self ,component-class-name) app-state message &key id-path)
                 (let* ((,(first update-lambda-list) message)
                        (,(second update-lambda-list) (elmtui.state.api:get-path app-state id-path)) ; local-state-map
                        (,(third update-lambda-list) app-state)
                        (,(fourth update-lambda-list) id-path)) ; self-id-path
                   (multiple-value-bind (local-changes-plist commands)
                       ,(cond
                          (message-handlers
                           ;; User provided message handlers like ((:tag (m l s i)) ...)
                           ;; We assume the user code block itself is the dispatch (e.g. a CASE or COND)
                           `(progn ,@update-user-code-block))
                          (t
                           ;; User provided a single block of code
                           `(progn ,@update-user-code-block)))
                     (let ((patches (loop for (key val) on local-changes-plist by #'cddr
                                          collect (list (elmtui.ui.api:component-state-path id-path key) val)))))
                     (elmtui.state.api:make-update-result :patches patches :commands commands)))))
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
                 (let ((,(first view-lambda-list) (elmtui.state.api:get-path app-state id-path)) ; local-state-map
                       (,(second view-lambda-list) app-state)
                       (,(third view-lambda-list) id-path)) ; self-id-path
                   ,@view-user-code)))
            ;; Default view if no :view clause
            `(defmethod elmtui.ui.api:view ((self ,component-class-name) app-state &key id-path)
               (declare (ignore app-state)) ; id-path is used
               (list (cclass-name self) :id (elmtui.ui.api:id-from-path id-path)
                                        :message "View not implemented for this component.")))

       ;; Accessor generation is omitted for now and will be revisited.

       ',component-class-name))) ; Return the component name
