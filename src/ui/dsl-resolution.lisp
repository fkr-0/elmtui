;;;; DSL Resolution System
;;;; Defines the polymorphic DSL type resolution system using CLOS generic functions

(uiop:define-package :elmtui.ui.dsl-resolution
  (:use :cl)
  (:export #:dsl-type
    #:resolve-dsl-type))

(in-package :elmtui.ui.dsl-resolution)

;;; ---------------------------------------------------------------
;;; Core Generic Function for DSL Type Resolution
;;; ---------------------------------------------------------------

(defgeneric dsl-type (type &optional props)
  (:documentation "Resolve DSL TYPE to a component class.

Returns (values class props) where CLASS is the component class symbol
and PROPS are accumulated/default properties.

Methods can be defined for specific keywords to implement variants:
- A method for :my-variant can add default props
- Methods can chain by calling dsl-type recursively with modified props

Example:
  (defmethod dsl-type ((type (eql :primary-button)) &optional props)
    (values 'button (append props '(:color :blue))))"))

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

(defmethod dsl-type ((type list) &optional props)
  "TYPE is a list - first element is the real type, rest are extra props.

When DSL form is a list like (:my-widget :prop1 val1 :prop2 val2),
the first element is the type and the rest are additional properties
to be merged with defaults."
  (dsl-type (first type) (append (rest type) props)))

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
  (etypecase item
    ;; List: first element is type, rest are additional props
    (list (resolve-dsl-type (first item) (append (rest item) props)))
    ;; Keyword: look up via dsl-type generic (recurse)
    (keyword (dsl-type item props))
    ;; Symbol: terminate - it's a class
    (symbol (values item props))))
