(defpackage :elmtui.view.props
  (:use :cl)
  (:export :define-prop-types
           :validate-props
           :prop-type
           :required-prop
           :optional-prop
           :with-prop-validation
           :define-component
           :props
           :children))

(in-package :elmtui.view.props)

;; Import from other modules
(defvar *validation-enabled* t "Control whether prop validation is enabled")

;; Prop type registry
(defvar *component-prop-types* (make-hash-table :test #'eq)
  "Registry of component prop types")

;; Prop type definition
(defstruct prop-type
  (name nil :type symbol)
  (required nil :type boolean)
  (type-spec nil)
  (validator nil :type (or null function))
  (default-value nil)
  (documentation nil :type (or null string)))

;; Helper to create a required prop
(defun required-prop (type &key validator documentation)
  "Define a required prop with type TYPE"
  (make-prop-type :name nil
                  :required t
                  :type-spec type
                  :validator validator
                  :documentation documentation))

;; Helper to create an optional prop
(defun optional-prop (type &key validator default documentation)
  "Define an optional prop with type TYPE and optional DEFAULT"
  (make-prop-type :name nil
                  :required nil
                  :type-spec type
                  :default-value default
                  :validator validator
                  :documentation documentation))

;; Register prop types for a component
(defun define-prop-types (component-type prop-specs)
  "Define prop types for COMPONENT-TYPE"
  (let ((prop-types (make-hash-table :test #'eq)))
    (loop for (prop-name . spec) in prop-specs
          for prop-type = (if (prop-type-p spec)
                              spec
                              (error "Invalid prop spec for ~a: ~a" prop-name spec))
          do (setf (prop-type-name prop-type) prop-name
                   (gethash prop-name prop-types) prop-type))
    (setf (gethash component-type *component-prop-types*) prop-types)
    component-type))

;; Type checking for props
(defun check-prop-type (value type-spec)
  "Check if VALUE matches TYPE-SPEC"
  (cond
    ;; Simple type symbol
    ((symbolp type-spec)
     (case type-spec
       (:string (stringp value))
       (:number (numberp value))
       (:integer (integerp value))
       (:list (listp value))
       (:function (functionp value))
       (:boolean (or (eq value t) (eq value nil)))
       (:keyword (keywordp value))
       (:symbol (symbolp value))
       (t (or (typep value type-spec)
              (and (fboundp 'elmtui.state.schema:validate-type)
                   (handler-case 
                       (funcall (symbol-function 'elmtui.state.schema:validate-type) 
                                value type-spec)
                     (error () nil)))))))
    
    ;; List of allowed values
    ((and (listp type-spec) (eq (car type-spec) 'member))
     (member value (cdr type-spec)))
    
    ;; Union type (or type1 type2...)
    ((and (listp type-spec) (eq (car type-spec) 'or))
     (some (lambda (sub-type) (check-prop-type value sub-type))
           (cdr type-spec)))
    
    ;; Intersection type (and type1 type2...)
    ((and (listp type-spec) (eq (car type-spec) 'and))
     (every (lambda (sub-type) (check-prop-type value sub-type))
            (cdr type-spec)))
    
    ;; List type (list element-type)
    ((and (listp type-spec) (eq (car type-spec) 'list))
     (and (listp value)
          (let ((elem-type (cadr type-spec)))
            (every (lambda (item) (check-prop-type item elem-type))
                   value))))
    
    ;; Function parameter types (function param-types return-type)
    ((and (listp type-spec) (eq (car type-spec) 'function))
     (functionp value))
    
    ;; Other compound types
    (t (or (typep value type-spec)
           (error "Unsupported type spec: ~S" type-spec)))))

;; Validate props against component type
(defun validate-props (component-type props)
  "Validate PROPS against the prop types defined for COMPONENT-TYPE"
  (when *validation-enabled*
    (let ((prop-types (gethash component-type *component-prop-types*)))
      (when prop-types
        ;; Check that all required props are provided
        (maphash (lambda (name prop-type)
                   (when (prop-type-required prop-type)
                     (unless (or (assoc name props)
                                 (cdr (assoc (intern (symbol-name name) :keyword) props)))
                       (error 'elmtui.core.conditions:property-validation-error
                              :property name
                              :message (format nil "Required prop ~a is missing" name)))))
                 prop-types)
        
        ;; Check that all provided props have correct type
        (loop for (name . value) in props
              for prop-name = (if (keywordp name) 
                                  (intern (symbol-name name))
                                  name)
              for prop-type = (gethash prop-name prop-types)
              when prop-type
              do (let ((type-spec (prop-type-type-spec prop-type))
                       (validator (prop-type-validator prop-type)))
                   (unless (check-prop-type value type-spec)
                     (error 'elmtui.core.conditions:type-validation-error
                            :property prop-name
                            :value value
                            :expected-type type-spec
                            :message (format nil "Prop ~a has invalid type" prop-name)))
                   
                   ;; Run custom validator if provided
                   (when validator
                     (let ((validation-result (funcall validator value)))
                       (unless (eq validation-result t)
                         (error 'elmtui.core.conditions:constraint-validation-error
                                :property prop-name
                                :value value
                                :constraint (or validation-result "custom validator")
                                :message (format nil "Prop ~a failed validation: ~a" 
                                                prop-name validation-result))))))))))
  props)

;; Macro for defining components with prop validation
(defmacro with-prop-validation ((component-type props) &body body)
  "Execute BODY with prop validation"
  `(progn
     (validate-props ,component-type ,props)
     ,@body))

;; Helper to define a component with prop types
(defmacro define-component (name prop-types &body body)
  "Define a component with prop types"
  `(progn
     (define-prop-types ,(intern (symbol-name name) :keyword) ,prop-types)
     (defun ,name (&rest all-args)
       (let* ((props (loop for (k v) on all-args by #'cddr collect (cons k v)))
              (children (cdr (assoc :children props))))
         (with-prop-validation (,(intern (symbol-name name) :keyword) props)
           ,@body)))))

;; Helpers to extract props and children
(defun props (props-plist)
  "Convert a property plist to an alist"
  (loop for (k v) on props-plist by #'cddr
        collect (cons k v)))

(defun children (props-plist)
  "Get children from props"
  (getf props-plist :children))

;; Example usage:
#|
(define-prop-types :button
  '((:label . ,(required-prop :string :documentation "Button text"))
    (:on-click . ,(required-prop :function :documentation "Click handler"))
    (:disabled . ,(optional-prop :boolean :default nil :documentation "Whether button is disabled"))
    (:style . ,(optional-prop :list :documentation "Additional styles"))))

(define-component button
  ((:label . ,(required-prop :string :documentation "Button text"))
   (:on-click . ,(required-prop :function :documentation "Click handler"))
   (:disabled . ,(optional-prop :boolean :default nil)))
  (render-button label on-click disabled))
|#
