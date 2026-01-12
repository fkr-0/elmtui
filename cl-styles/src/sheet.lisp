(in-package :cl-styles.sheet)

(defclass stylesheet ()
  ((rules :initarg :rules :accessor stylesheet-rules
     :documentation "List of style rules.")
    (variables :initarg :variables :accessor stylesheet-variables
      :documentation "List of stylesheet variables.")
    (namespace :initarg :namespace :accessor stylesheet-namespace
      :documentation "Optional namespace for the stylesheet.")))



(defclass style-engine ()
  ((stylesheet :initarg :stylesheet :accessor style-engine-stylesheet
     :documentation "The current stylesheet instance.")
    (patches :initform nil :accessor style-engine-patches
      :documentation "List of patches to apply.")
    (dirty :initform t :accessor style-engine-dirty
      :documentation "Flag indicating if the engine needs recompilation."))
  (:documentation "Stateful styling engine for advanced use cases like caching and batch operations.
Currently unused - the functional API (apply-stylesheet, apply-stylesheet-to-tree) is preferred.
Reserved for future optimizations like selector compilation caching or computed style caching."))

(defun make-stylesheet (&key rules variables namespace)
  "Create a new stylesheet instance."
  (make-instance 'stylesheet
    :rules rules
    :variables variables
    :namespace namespace))

(defmacro defstylesheet (&body rules)
  "Define a stylesheet with the given rules."
  `(make-stylesheet :rules (list ,@rules)))


(defgeneric add-rule (stylesheet rule)
  (:documentation "Add a rule to the stylesheet."))

(defmethod add-rule ((stylesheet stylesheet) rule)
  (push rule (slot-value stylesheet 'rules))
  stylesheet)

(defun add-rule* (stylesheet rule)
  "Helper to add a rule to the stylesheet and return the updated instance."
  (add-rule stylesheet rule))

(defgeneric remove-rule (stylesheet rule)
  (:documentation "Remove a rule from the stylesheet."))

(defmethod remove-rule ((stylesheet stylesheet) rule)
  (setf (slot-value stylesheet 'rules)
    (remove rule (slot-value stylesheet 'rules) :test #'equal))
  stylesheet)

(defun remove-rule* (stylesheet rule)
  "Helper to remove a rule from the stylesheet and return the updated instance."
  (remove-rule stylesheet rule))

;; (let ((ss (make-stylesheet :rules '((:selector ".a")))))
;;   (add-rule* ss '(:selector ".b"))
;;   (remove-rule* ss '(:selector ".a")))
