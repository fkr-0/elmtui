(defpackage :elmtui.state.validation
  (:use :cl)
  (:export :validate-nested
           :validate-field
           :with-validation
           :define-validator
           :register-type-validator
           :validate-model
           :make-validator
           :type-predicate))

(in-package :elmtui.state.validation)

;; Type predicates registry
(defvar *type-validators* (make-hash-table :test #'equal)
  "Registry of type validators")

(defun register-type-validator (type-name predicate &optional description)
  "Register a validation predicate for a given type"
  (setf (gethash type-name *type-validators*)
        (list :predicate predicate :description (or description ""))))

(defun type-predicate (type-name)
  "Retrieve predicate for a type"
  (let ((entry (gethash type-name *type-validators*)))
    (when entry
      (getf entry :predicate))))

;; Core validation utilities
(define-condition validation-error (error)
  ((message :initarg :message :reader validation-error-message)
   (path :initarg :path :initform nil :reader validation-error-path)
   (value :initarg :value :initform nil :reader validation-error-value))
  (:report (lambda (condition stream)
             (format stream "Validation error at ~a: ~a"
                     (or (validation-error-path condition) "root")
                     (validation-error-message condition)))))

(defun make-validator (predicate error-message)
  "Creates a validator function from a predicate"
  (lambda (value &key path)
    (unless (funcall predicate value)
      (error 'validation-error
             :message error-message
             :path path
             :value value))
    t))

(defmacro define-validator (name args &body body)
  "Define a named validator function"
  `(defun ,name ,args
     (let ((result (progn ,@body)))
       (if (eq result t)
           t
           (error 'validation-error
                  :message (or result "Validation failed")
                  :path ,(cadr args)
                  :value ,(car args))))))

(defun validate-field (value type &key path)
  "Validate a single value against a type specification"
  (cond
    ;; Handle simple type predicates
    ((symbolp type)
     (let ((predicate (type-predicate type)))
       (if predicate
           (funcall predicate value path)
           (error "No validator defined for type ~a" type))))
    
    ;; Handle compound types like (or ...)
    ((and (listp type) (eq (first type) 'or))
     (let ((valid nil))
       (dolist (sub-type (rest type))
         (handler-case
             (progn
               (validate-field value sub-type :path path)
               (setf valid t)
               (return))
           (validation-error () nil)))
       (unless valid
         (error 'validation-error
                :message (format nil "Value ~S doesn't match any type in ~S" value type)
                :path path
                :value value))))
    
    ;; Handle compound types like (and ...)
    ((and (listp type) (eq (first type) 'and))
     (dolist (sub-type (rest type))
       (validate-field value sub-type :path path)))
    
    ;; Handle lists like (list type)
    ((and (listp type) (eq (first type) 'list))
     (unless (listp value)
       (error 'validation-error
              :message "Expected a list"
              :path path
              :value value))
     (let ((elem-type (second type)))
       (loop for item in value
             for i from 0
             do (validate-field item elem-type 
                                :path (if path
                                          (format nil "~a[~a]" path i)
                                          (format nil "[~a]" i))))))
    
    ;; Handle vectors like (vector type)
    ((and (listp type) (eq (first type) 'vector))
     (unless (vectorp value)
       (error 'validation-error
              :message "Expected a vector"
              :path path
              :value value))
     (let ((elem-type (second type)))
       (loop for item across value
             for i from 0
             do (validate-field item elem-type
                                :path (if path
                                          (format nil "~a[~a]" path i)
                                          (format nil "[~a]" i))))))
    
    ;; Other compound types
    (t (error "Unsupported type specification: ~S" type))))

(defun validate-nested (object schema &optional (path ""))
  "Validate a nested object structure against a schema"
  (loop for (field-name field-type) in schema
        for field-path = (if (string= path "")
                             (string field-name)
                             (format nil "~a.~a" path field-name))
        for field-value = (if (symbolp field-name)
                             (slot-value object field-name)
                             (error "Field name must be a symbol: ~S" field-name))
        do (validate-field field-value field-type :path field-path))
  t)

(defmacro with-validation (&body body)
  "Execute forms with validation error handling"
  `(handler-bind
       ((validation-error
         (lambda (c)
           (format *error-output* "~&Validation error: ~a~%" c)
           (invoke-debugger c))))
     ,@body))

;; Register common type validators
(register-type-validator 'string #'stringp "Must be a string")
(register-type-validator 'integer #'integerp "Must be an integer")
(register-type-validator 'keyword #'keywordp "Must be a keyword")
(register-type-validator 'boolean #'(lambda (x) (or (eq x t) (eq x nil))) "Must be a boolean")
(register-type-validator 'function #'functionp "Must be a function")
(register-type-validator 'symbol #'symbolp "Must be a symbol")
(register-type-validator 'list #'listp "Must be a list")
(register-type-validator 'hash-table #'hash-table-p "Must be a hash-table")

(defun validate-model (model &optional (schema nil))
  "Validate a model against its schema"
  (if schema
      (validate-nested model schema)
      (if (slot-exists-p model 'schema)
          (validate-nested model (slot-value model 'schema))
          (error "No schema provided for validation")))
  t)
