;;;; Component Metaclass
;;;; Defines a metaclass for storing component metadata in class metaobjects

(uiop:define-package :elmtui.ui.component-metaclass
  (:use :cl)
  (:import-from :sb-mop
    #:standard-class
    #:class-direct-superclasses)
  (:export #:component-class
    #:class-metadata
    #:make-metadata))

(in-package :elmtui.ui.component-metaclass)

;;; ---------------------------------------------------------------
;;; Component Metaclass
;;; ---------------------------------------------------------------

(defclass component-class (standard-class)
  ((%metadata
     :initarg :metadata
     :accessor class-metadata
     :initform nil
     :documentation "Metadata associated with this component class.
                   Contains properties, documentation, and examples."))
  (:documentation "Metaclass for component classes that stores metadata
                   in the class metaobject itself instead of a static registry."))

;;; ---------------------------------------------------------------
;;; Initialize Instance Method
;;; ---------------------------------------------------------------

(defmethod initialize-instance :after ((class component-class) &rest initargs &key &allow-other-keys)
  "After initializing a component-class, extract and store the metadata if provided."
  ;; The :metadata option might be in the class options, not as a direct initarg
  ;; We need to handle both cases
  (let ((metadata (getf initargs :metadata)))
    (when metadata
      (setf (slot-value class '%metadata) metadata)))
  (values))

;;; ---------------------------------------------------------------
;;; Validate Superclass Method
;;; ---------------------------------------------------------------

(defmethod sb-mop:validate-superclass ((class component-class) (superclass sb-mop:standard-class))
  "Allow component-class to be used with standard-class superclasses."
  t)

(defmethod sb-mop:validate-superclass ((class sb-mop:standard-class) (superclass component-class))
  "Allow standard-class to be used with component-class superclasses."
  t)

;;; ---------------------------------------------------------------
;;; Metadata Helper Functions
;;; ---------------------------------------------------------------

(defun make-metadata (&key props documentation examples)
  "Create a metadata structure for component classes.

   Arguments:
     PROPS        -- A plist of component properties (e.g., '(:label \"Button\" :width 100))
     DOCUMENTATION -- A string describing the component
     EXAMPLES     -- A list of example DSL forms showing usage

   Returns:
     A plist containing the metadata fields.

   Example:
     (make-metadata
       :props '(:text \"Click me\"
                 :on-click handle-click)
       :documentation \"A clickable button component\"
       :examples '((:button :text \"Submit\"
                           :on-click submit-form)))
  "
  (let ((metadata '()))
    (when props
      (setf (getf metadata :props) props))
    (when documentation
      (setf (getf metadata :documentation) documentation))
    (when examples
      (setf (getf metadata :examples) examples))
    metadata))
