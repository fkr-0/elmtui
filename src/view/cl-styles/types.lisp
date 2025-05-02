;;; ────────────────────────── 1. Core Types ──────────────────────────────
(uiop:define-package :cl-styles.types
  (:use :cl)
  (:export
   :property :value :style :style-group
   :stylable :stylegroup-p :group-styles
   :valid-value-p :group-key))

(in-package :cl-styles.types)

(defclass property () ((name :initarg :name :accessor property-name)))
(defclass value ()
  ((raw  :initarg :value :accessor value-raw)
   (type :initarg :type  :accessor value-type)
   (choices :initarg :choices :initform nil :accessor value-choices)))
(defclass style ()
  ((property :initarg :property :accessor style-property :type property)
   (value    :initarg :value    :accessor style-value    :type value)))

(defmethod style-property-of ((obj style))
  (intern (property-name (style-property obj)) 'keyword))
(defmethod style-value-of ((s style))
  "Return the value of the style."
  (value-raw (style-value s)))
(defclass style-group (style)
  ((sub-styles :initarg :sub-styles :initform nil :accessor sub-styles)))

(defclass stylable () ;; defined later – here for forward declaration
  ())

(defgeneric valid-value-p (property v))
(defgeneric group-key (obj))
(defmethod stylegroup-p ((obj style-group)) t)
(defmethod stylegroup-p ((obj style)) nil)
(defmethod group-key ((obj style-group)) (style-property obj))
(defmethod group-key ((obj style)) (style-property obj))
(defgeneric group-styles (style-group-key))
