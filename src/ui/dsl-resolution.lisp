;;;; DSL Resolution System
;;;; Defines the polymorphic DSL type resolution system using CLOS generic functions

(uiop:define-package :elmtui.ui.dsl-resolution
  (:use :cl)
  (:import-from :elmtui.api #:dsl-type)
  (:export #:dsl-type
    #:resolve-dsl-type
    #:*dsl-type-registry*
    #:register-dsl-type
    #:known-dsl-type-p))

(in-package :elmtui.ui.dsl-resolution)

;;; ---------------------------------------------------------------
;;; DSL Type Registry
;;; ---------------------------------------------------------------

(defvar *dsl-type-registry* (make-hash-table :test 'eq)
  "Registry mapping DSL type keywords to their component class names.
Consulted by KNOWN-DSL-TYPE-P to decide whether a keyword names a DSL
node type (as opposed to a property key) during argument splitting.
Entries are added at load time by REGISTER-DSL-TYPE, which is called
automatically by defcomponent and defcomponent-dsl expansions.")

(defun register-dsl-type (keyword &optional class)
  "Register KEYWORD as a known DSL node type, optionally mapping to CLASS.
Registration is idempotent: calling with the same KEYWORD and CLASS
has no additional effect."
  (setf (gethash keyword *dsl-type-registry*) (or class t))
  keyword)

(defun known-dsl-type-p (keyword)
  "Return non-NIL if KEYWORD is a registered DSL node type.
Returns the associated class (or T when no class was recorded), NIL otherwise."
  (values (gethash keyword *dsl-type-registry*)))

(define-condition invalid-dsl-form (error)
  ((form :initarg :form :reader invalid-dsl-form-form)
   (reason :initarg :reason :reader invalid-dsl-form-reason))
  (:report (lambda (condition stream)
             (format stream "Invalid DSL form (~A)" (invalid-dsl-form-reason condition)))))

(defun %dsl-proper-list-p (form)
  "Recognize a finite proper list without looping through circular CDRs."
  (loop with slow = form
        with fast = form
        do (cond ((null fast) (return t))
                 ((atom fast) (return nil)))
           (setf fast (cdr fast))
           (cond ((null fast) (return t))
                 ((atom fast) (return nil)))
           (setf fast (cdr fast) slow (cdr slow))
           (when (eq fast slow) (return nil))))

(defun %validate-dsl-list (form)
  (unless (and (consp form) (%dsl-proper-list-p form))
    (error 'invalid-dsl-form :form form :reason :empty-or-improper-list))
  form)

;;; ---------------------------------------------------------------
;;; Default Methods
;;; ---------------------------------------------------------------

(defmethod dsl-type ((type symbol) &optional props)
  "TYPE is a symbol - handle both keywords and non-keyword symbols.

This is the default termination method. When TYPE is:
- A keyword without a specific dsl-type method, return NIL to indicate
  it's a base element (not a component), e.g., :container, :column
- A non-keyword symbol, it's treated as a class name and returned directly"
  (if (keywordp type)
      ;; Keywords without specific methods are base elements, not components
      (values nil props)
      (values type props)))

(defmethod no-applicable-method ((gf (eql #'dsl-type)) &rest args)
  "Handle keywords and other types without specific dsl-type methods.

This method is called when no specific method matches the arguments.
For keywords (which are base elements), we return NIL to indicate
they are not components."
  (when args
    (let ((type (first args)))
      (when (keywordp type)
        ;; Keywords without specific methods are base elements, not components
        (return-from no-applicable-method (values nil (second args))))))
  ;; For other cases, use the default error behavior
  (call-next-method))

(defparameter *dsl-list-maximum-depth* 512
  "Maximum nesting accepted by built-in list DSL resolution.")

(defvar *dsl-list-active-types* nil
  "Dynamically scoped identity set shared by nested public DSL-TYPE calls.")

(defvar *dsl-list-depth* 0)

(defmethod dsl-type ((type list) &optional props)
  "TYPE is a list - first element is the real type, rest are extra props.

When DSL form is a list like (:my-widget :prop1 val1 :prop2 val2),
the first element is the type and the rest are additional properties
to be merged with defaults."
  (let ((*dsl-list-active-types* (or *dsl-list-active-types*
                                      (make-hash-table :test #'eq)))
        (*dsl-list-depth* (1+ *dsl-list-depth*)))
    (when (> *dsl-list-depth* *dsl-list-maximum-depth*)
      (error 'invalid-dsl-form :form type :reason :type-depth-exceeded))
    (%validate-dsl-list type)
    (when (gethash type *dsl-list-active-types*)
      (error 'invalid-dsl-form :form type :reason :cyclic-type-chain))
    (setf (gethash type *dsl-list-active-types*) t)
    (unwind-protect
         (dsl-type (first type) (append (rest type) props))
      (remhash type *dsl-list-active-types*))))

;;; ---------------------------------------------------------------
;;; Helper Functions
;;; ---------------------------------------------------------------

(defun resolve-dsl-type (item &optional props)
  "Resolve ITEM to a component class with accumulated PROPS.

Returns (values class final-props).

ITEM can be:
- a keyword  : look up via dsl-type generic (recurses)
- a list     : (car list) is the type, (cdr list) are extra props
- a symbol   : it's a class (terminates)

This is the main entry point for DSL resolution. It handles the
initial dispatch based on the type of ITEM.

Examples:
  (resolve-dsl-type 'my-widget)              => MY-WIDGET, NIL
  (resolve-dsl-type :my-variant)             => (via dsl-type method), props
  (resolve-dsl-type '(:my-variant :x 1))     => (via dsl-type method), (:x 1 . props)

When chaining, props are accumulated from right to left:
  (resolve-dsl-type '(:outer :inner)) calls
  (dsl-type :inner) then appends (:outer) to result"
  (let ((active (make-hash-table :test #'eq))
        (depth 0))
    (labels ((walk (form accumulated)
               (typecase form
                 (cons
                  (when (>= depth *dsl-list-maximum-depth*)
                    (error 'invalid-dsl-form :form form :reason :type-depth-exceeded))
                  (%validate-dsl-list form)
                  (when (gethash form active)
                    (error 'invalid-dsl-form :form form :reason :cyclic-type-chain))
                  (setf (gethash form active) t)
                  (incf depth)
                  (unwind-protect
                       (walk (car form) (append (cdr form) accumulated))
                    (decf depth)
                    (remhash form active)))
                 (keyword (dsl-type form accumulated))
                 (symbol (if (null form)
                             (error 'invalid-dsl-form :form form :reason :empty-type)
                             (values form accumulated)))
                 (t (error 'invalid-dsl-form :form form :reason :invalid-type)))))
      (walk item props))))
