(uiop:define-package :elmtui.ui.defcomponent
  (:use :cl)
  (:import-from :alexandria #:plist-hash-table)
  (:import-from :elmtui.tea-state #:make-update-result
                #:get-path)
  (:import-from :elmtui.ui.api
                #:view
                #:component      ;; Base class for components
                #:component-id      ;; Base class for components
                #:id-from-path
                )        ;; Use the UI API version that takes app-state
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
                  (when (and type (null initial-value)
                             (not (and (consp type)
                                       (member 'null type))))
                    (error "defcomponent: Slot ~A declares type ~A but has NIL as initial value. Provide a valid default or use (or null <type>)." name type))
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
  (let* ((effective-superclasses (if direct-superclasses
                                     direct-superclasses
                                     '(elmtui.ui.api:component)))
         (component-class-name name)
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
                                    :no-op))
         (local-state-slots (if state-clause
                                (parse-state-clause (clause-body state-clause))
                                nil))
         (inherited-state-slots (collect-inherited-state-slots effective-superclasses))
         (parsed-state-slots (merge-state-slots inherited-state-slots local-state-slots))
         (state-initarg-params (loop for slot in parsed-state-slots
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
         (doc-option (assoc :documentation other-options))
         (class-documentation-string (if doc-option
                                         (second doc-option)
                                         (format nil "A UI component class ~A, defined with defcomponent." name)))
         (other-class-options (remove-if (lambda (item)
                                           (and (consp item) (eq (car item) :documentation)))
                                         other-options)))

    `(eval-when (:compile-toplevel :load-toplevel :execute)
       (defclass ,component-class-name ,effective-superclasses
         ()
         (:documentation ,class-documentation-string)
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
              `(defmethod elmtui.ui.api:update ((self ,component-class-name) app-state message &key id-path)
                 (declare (ignorable app-state id-path))
                 (let* ((,(second update-lambda-list) (elmtui.utils:get-path id-path app-state))
                        (,(third update-lambda-list) app-state)
                        (,(fourth update-lambda-list) id-path))
                   ;; (declare (ignorable ,@(remove nil (rest update-lambda-list))))
                   (declare (ignorable ,@(remove nil (rest update-lambda-list))))
                   (let ((,(first update-lambda-list) message))
                     (declare (ignorable ,(first update-lambda-list)))
                     (multiple-value-bind (default-patches default-commands)
                         (if (fboundp 'call-next-method)
                             (call-next-method)
                             (values nil nil))
                       (declare (ignorable default-patches default-commands))
                       (destructuring-bind (local-changes-plist commands)
                           (multiple-value-list
                            (multiple-value-call #'values
                              ,(generate-update-dispatch-code (first update-lambda-list)
                                                              (second update-lambda-list)
                                                              (third update-lambda-list)
                                                              (fourth update-lambda-list)
                                                              update-user-code-block
                                                              component-class-name
                                                              on-unhandled-behavior)))
                         (let* ((local-changes-ht (when local-changes-plist
                                                    (plist-hash-table local-changes-plist :test 'eq)))
                                (custom-patches
                                  (when local-changes-ht
                                    (loop for key being the hash-keys of local-changes-ht
                                            using (hash-value val)
                                          collect (list (elmtui.ui.api:component-state-path id-path key) val)))))
                           (elmtui.tea-state:make-update-result
                            :patches (append default-patches custom-patches)
                            :commands (append default-commands commands)))))))))
            `(defmethod elmtui.ui.api:update ((self ,component-class-name) app-state message &key id-path)
               (declare (ignore app-state message id-path))
               (elmtui.tea-state:make-update-result :patches nil :commands nil)))

       ,(if view-clause
            (let* ((view-body-forms (clause-body view-clause))
                   (view-lambda-list (first view-body-forms))
                   (view-user-code (rest view-body-forms)))
              `(defmethod elmtui.ui.api:view ((self ,component-class-name) app-state &key id-path children)
                 (declare (ignorable ;; ,@(remove nil view-lambda-list)
                           id-path children
                           ))
                 (let ((,(first view-lambda-list) (elmtui.utils:get-path id-path app-state)))
                   (if ,(first view-lambda-list)
                       (let ((,(second view-lambda-list) app-state)
                             (,(third view-lambda-list) id-path)
                             (,(nth 3 view-lambda-list) children))
                         (declare (ignorable ,@(list (third view-lambda-list) (second view-lambda-list) (nth 3 view-lambda-list))));remove nil view-lambda-list)))
                         ,@view-user-code)
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
                                   (comp-state (get-path full-path (elmtui.tea-state.state::application-state-data app-state))))
                              (cond ((hash-table-p comp-state)
                                     (gethash ,slot-keyword comp-state ,slot-initial-value))
                                    ((listp comp-state)
                                     (getf comp-state ,slot-keyword ,slot-initial-value))
                                    (t ,slot-initial-value)))))

       (eval-when (:compile-toplevel :load-toplevel :execute)
         (setf (gethash ',component-class-name *component-state-slots*) ',parsed-state-slots))

       ',component-class-name)))
