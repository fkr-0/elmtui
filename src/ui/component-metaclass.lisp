;;;; Component Metaclass
;;;; Defines a metaclass for storing component metadata in class metaobjects

(uiop:define-package :elmtui.ui.component-metaclass
  (:use :cl)
  (:import-from :sb-mop
    #:standard-class)
  (:export #:component-class
    #:class-metadata
    #:make-metadata))

(in-package :elmtui.ui.component-metaclass)

;;; ---------------------------------------------------------------
;;; Component Metaclass
;;; ---------------------------------------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defclass component-class (standard-class)
  ((%metadata
     :initarg :metadata
     :accessor class-metadata
     :initform nil
     :documentation "Metadata associated with this component class.
                   Contains properties, documentation, and examples."))
  (:documentation "Metaclass for component classes that stores metadata
                   in the class metaobject itself instead of a static registry.")))

(defun normalize-metadata (metadata)
  "Normalize metadata shape so callers consistently get a plist."
  (if (and (consp metadata)
           (null (cdr metadata))
           (consp (car metadata))
           (keywordp (caar metadata)))
      (car metadata)
      metadata))

(defmethod class-metadata :around ((class component-class))
  (normalize-metadata (call-next-method)))

(defmethod (setf class-metadata) :around (metadata (class component-class))
  (call-next-method (normalize-metadata metadata) class))

;;; ---------------------------------------------------------------
;;; Initialize Instance Method
;;; ---------------------------------------------------------------

(defmethod initialize-instance :after ((class component-class) &key metadata &allow-other-keys)
  "After initializing a component-class, store the metadata if provided."
  (when metadata
    ;; DEFCLASS class options pass option values as argument lists.
    (setf (class-metadata class) metadata))
  (values))

;;; ---------------------------------------------------------------
;;; Validate Superclass Method
;;; ---------------------------------------------------------------

(defmethod sb-mop:validate-superclass ((class component-class) (superclass standard-class))
  "Allow component-class to have standard-class as a superclass."
  (declare (ignore class superclass))
  t)

(defmethod sb-mop:validate-superclass ((class standard-class) (superclass component-class))
  "Allow standard-class to inherit from component-class."
  (declare (ignore class superclass))
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
                           :on-click submit-form)))"
  (let ((metadata '()))
    (when props
      (setf (getf metadata :props) props))
    (when documentation
      (setf (getf metadata :documentation) documentation))
    (when examples
      (setf (getf metadata :examples) examples))
    metadata))
