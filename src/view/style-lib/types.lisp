;;; ────────────────────────── 1. Core Types ──────────────────────────────
(uiop:define-package :elmtui.style-lib.types
  (:use :cl)
  (:export
   ;; Classes
   ;; :property :value :style :style-group
   ;; ;; Generics & Accessors
   ;; :property-name :value-value :value-type ; Basic accessors
   ;; :style-property :style-value :style-sub-styles ; Style accessors
   ;; :stylegroup-p :group-key :group-styles ; Style group specifics
   ;; :valid-value-p ; Validation generic
   ;; Potentially :stylable if needed later
   ))
(in-package :elmtui.style-lib.types)

;; Ensure classes are defined at compile time for macros using them
;; (eval-when (:compile-toplevel :load-toplevel :execute)
;;   ;;; --- Base Classes ---

;;   (defclass property ()
;;   ((name :initarg :name :reader property-name :type string))
;;   (:documentation "Represents a style property (e.g., :color, :padding)."))

;; (defclass value ()
;;   ((value :initarg :value :reader value-value)
;;    (type :initarg :type :reader value-type :initform t)) ; Store original type spec
;;   (:documentation "Represents the value associated with a style property."))

;; ;;; --- Style Class ---

;; (defclass style ()
;;   ((property :initarg :property :reader style-property :type property)
;;    (value :initarg :value :reader style-value :type value))
;;   (:documentation "Represents a single style rule (property + value)."))

;;   ;;; --- Style Group Class ---

;;   (defclass style-group (style)
;;     ((sub-styles :initarg :sub-styles :reader style-sub-styles :initform nil :type list))
;;     (:documentation "Represents a group of related styles (e.g., padding, margin) often set together.")))
;; End eval-when

;;; --- Generic Functions ---

;; (defgeneric valid-value-p (property value)
;;   (:documentation "Checks if VALUE is valid for the given PROPERTY object.")
;;   ;; Default method allows any value if no specific validation is defined
;;   (:method ((p property) v) (declare (ignore p v)) t))

;; (defgeneric group-key (style-group)
;;   (:documentation "Returns the keyword identifier for a style group."))

;; (defgeneric group-styles (style-group)
;;   (:documentation "Returns the list of individual sub-styles within a style group.")
;;   (:method ((sg style-group)) (style-sub-styles sg)))

;; (defun stylegroup-p (obj)
;;   "Checks if OBJ is a style-group."
;;   (typep obj 'style-group))

;; ;;; --- Printing ---

;; (defmethod print-object ((obj property) stream)
;;   (print-unreadable-object (obj stream :type t)
;;     (format stream ":~A" (property-name obj))))

;; (defmethod print-object ((obj value) stream)
;;   (print-unreadable-object (obj stream :type t)
;;     (format stream "~S~@[ (~A)~]" (value-value obj) (unless (eq t (value-type obj)) (value-type obj)))))

;; (defmethod print-object ((obj style) stream)
;;   (print-unreadable-object (obj stream :type t)
;;     (format stream "~A ~A" (style-property obj) (style-value obj))))

;; (defmethod print-object ((obj style-group) stream)
;;   (print-unreadable-object (obj stream :type t :identity nil)
;;     (format stream "~A (~D sub-styles)" (group-key obj) (length (style-sub-styles obj)))))
