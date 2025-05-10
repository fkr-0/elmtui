;; (uiop:define-package :elmtui.style-lib.api
;;   (:use :common-lisp)
;;   (:import-from :elmtui.style-lib.util :hash-table-keys)
;;   (:export
;;    ;; Classes
;;    :style :style-set :stylable :selector :style-rule :stylesheet

;;    ;; Generic functions
;;    :apply-style :get-style :set-style :merge-styles :selects :apply-stylesheet

;;    ;; Macros and functions
;;    ;; :defstyle :defrule
;;    ;; :make-style-set
;;    :make-selector))

;; (in-package :elmtui.style-lib.api)
;; (defgeneric make-style-set (&rest styles))
;; (defmethod make-style-set (&rest styles)
;;   (declare (ignore styles))
;;   (error "make-style-set not implemented"))


;; (defgeneric make-selector (type &rest args))
;; (defmethod make-selector (type &rest args)
;;   (declare (ignore type args))
;;   (error "make-selector not implemented"))
;; ;; Define base classes
;; (defclass style-component () ()
;;   (:documentation "Base class for style components."))

;; (deftype style-category ()
;;   '(member :layout :content :decoration :behavior))

;; (defclass style-metadata ()
;;   ((category :initarg :category
;;              :accessor style-category
;;              :type style-category
;;              :documentation "The category this style belongs to")
;;    (related-styles :initarg :related-styles
;;                    :accessor style-related-styles
;;                    :initform nil
;;                    :documentation "List of styles that are related to this one"))
;;   (:documentation "Metadata for a style including its category and relationships"))

;; (defclass property (style-component)
;;   ((name :initarg :name
;;          :accessor property-name
;;          :documentation "The name of the property."))
;;   (:documentation "A property represents a style property."))

;; (defclass value (style-component)
;;   ((value :initarg :value :accessor value-value)
;;    (type :initarg :type :accessor value-type)
;;    (possible-values :initarg :possible-values :accessor value-possible-values))
;;   (:documentation "A value represents the value of a style property."))

;; (defclass style ()
;;   ((property :initarg :property :accessor style-property)
;;    (value :initarg :value :accessor style-val)
;;    (default :initarg :default
;;             :accessor style-default
;;             :initform nil
;;             :documentation "The default value of the style.")
;;    (metadata :initarg :metadata
;;              :accessor style-metadata
;;              :initform nil
;;              :type (or null style-metadata)
;;              :documentation "Optional metadata about the style's category and relationships"))
;;   (:documentation "A style is a property-value pair with optional metadata."))


;; Define generic functions
;; (defgeneric apply-style (stylable style))

;; (defmethod select-styles ((selector selector) (styles list))
;;   "Select styles matching the given selector."
;;   (remove-if-not (lambda (style)
;;                    (string= (style-property style) (sel-name selector)))
;; styles))

;; (defmethod styles ((stylable stylable))
;;   "Return the styles associated with the given stylable."
;;   (slot-value stylable 'styles))


;; (defgeneric get-style (stylable style-property))
;; (defgeneric set-style (stylable style-property value))
;; (defgeneric merge-styles (style-set1 style-set2))
;; (defgeneric selects (selector stylable))
;; (defgeneric apply-stylesheet (stylesheet stylable))

;; For macros and functions, we'll use defgeneric and provide a default method
;; that signals an error. This allows for easy overriding in implementation packages.

;; (defgeneric defstyle-impl (name &rest options))
;; (defmethod defstyle-impl (name &rest options)
;;   (declare (ignore name options))
;;   (error "defstyle not implemented"))

;; (defmacro defstyle (name &rest options)
;;   `(defstyle-impl ',name ,@options))

;; (defgeneric defrule-impl (selector &rest styles))
;; (defmethod defrule-impl (selector &rest styles)
;;   (declare (ignore selector styles))
;;   (error "defrule not implemented"))

;; (defmacro defrule (selector &body styles)
;;   `(defrule-impl ',selector ,@styles))

;;; ─── elmtui.style-lib/api.lisp ───────────────────────────────────────────────
(uiop:define-package :elmtui.style-lib.api
  (:use :common-lisp)
  (:export
   ;; Classes
   :style :style-set :stylable :selector :style-rule :stylesheet :style-group
   :style-component :property :value :style-metadata :classes
   :stylable-id :parents-of

   ;; Generic functions
   :apply-style :get-style :set-style :merge-styles :selects :apply-stylesheet
   :styles :make-style :from-style-set :group-styles
   :ordered-styles
   :default-styling :make-style-set

   :property :value :style :style-group
   ;; Generics & Accessors
   :property-name :value-value :value-type ; Basic accessors
   :style-property :style-value :style-sub-styles ; Style accessors
   :stylegroup-p :group-key :group-styles ; Style group specifics
   :valid-value-p ; Validation generic
   :dirty :dirty-p ; Export dirty accessor and predicate
   ;; Macros and functions
   :make-selector))
(in-package :elmtui.style-lib.api)

(defclass property () ((name :initarg :name :accessor property-name)))
(defclass value ()
  ((raw  :initarg :value :accessor value-raw)
   (type :initarg :type  :accessor value-type)
   (choices :initarg :choices :initform nil :accessor value-choices)))
;; Removed duplicate/simpler style definition that was here.

(defclass style-group (style)
  ((sub-styles :initarg :sub-styles :initform nil :accessor sub-styles)))

(defgeneric style-sub-styles (style-group)
  (:method ((sg style-group)) (sub-styles sg))
  (:documentation "Return the sub-styles of a style group."))

;; (defclass stylable () ;; defined later – here for forward declaration
;;   ())

(defclass style-component () ()
  (:documentation "Base class for style components."))

(deftype style-category ()
  '(member :layout :content :decoration :behavior))

(defclass style-metadata ()
  ((category :initarg :category
             :accessor style-category
             :type style-category
             :documentation "The category this style belongs to")
   (related-styles :initarg :related-styles
                   :accessor style-related-styles
                   :initform nil
                   :documentation "List of styles that are related to this one"))
  (:documentation "Metadata for a style including its category and relationships"))

(defclass property (style-component)
  ((name :initarg :name
         :accessor property-name
         :documentation "The name of the property."))
  (:documentation "A property represents a style property."))

(defclass value (style-component)
  ((value :initarg :value :accessor value-value)
   (type :initarg :type :accessor value-type)
   (possible-values :initform nil
                    :initarg :possible-values :accessor value-possible-values))
  (:documentation "A value represents the value of a style property."))

(defclass style ()
  ((property :initarg :property :accessor style-property)
   (value :initarg :value :accessor style-value) ; Ensure accessor is style-value
   (default :initarg :default
            :accessor style-default
            :initform nil
            :documentation "The default value of the style.")
   (metadata :initarg :metadata
             :accessor style-metadata
             :initform nil
             :type (or null style-metadata)
             :documentation "Optional metadata about the style's category and relationships"))
  (:documentation "A style is a property-value pair with optional metadata."))

(defstruct (style-set (:constructor make-style-set))
  (styles (make-hash-table :test #'equal) :type hash-table ) ; :documentation "Hash table mapping property symbols to style instances.")
  (order nil :type list)) ; :documentation "Optional list specifying the order of styles application."))

(defclass stylable ()
  ((sid :initarg :id
        :initform nil
        :accessor stylable-id
        :documentation "The ID of the stylable object.")
   (classes :initform 'nil
            :accessor classes
            :documentation "The classes of the stylable object.")
   (styles :accessor styles
           :type style-set
           :documentation "The styles associated with the stylable object.")
   (dirty :initform t
          :accessor dirty
          :documentation "Indicates if the stylable needs to have styles reapplied."))
  (:documentation
   "A stylable is an entity that can have styles applied to it."))

;; Define the dirty-p predicate
(defmethod dirty-p (stylable-object)
  "Returns T if the stylable object is marked as dirty, NIL otherwise."
  (dirty stylable-object))

(defclass selector () () (:documentation "Base class for all selectors."))
(defgeneric selects (selector target)
  (:documentation
   "Return T if the given selector selects the given target, NIL otherwise."))
(defgeneric specificity (sel)
  (:documentation
   "Return the specificity of the selector as INT. The higher the number, the more specific the selector."))

(defclass style-rule ()
  ((selector :initarg :selector
             :accessor rule-selector
             :documentation "The selector of the rule.")
   (styles :initarg :styles
           :accessor rule-styles
           :type style-set
           :documentation "The styles associated with the rule.")
   (matched-objects :accessor matched-objects
                    :initform nil
                    :documentation "List of objects that match the selector."))
  (:documentation "A style rule consists of a selector and a set of styles."))

(defclass stylesheet ()
  ((name :initarg :name :accessor stylesheet-name :initform "" :type string)
   (rules :initarg :rules :accessor stylesheet-rules :initform nil :type list))
  (:documentation "A stylesheet is a collection of style rules.
it carries an optional NAME:string and RULES:list."))

(defmethod style-property-of ((obj style))
  (intern (property-name (style-property obj)) 'keyword))
(defmethod style-value-of ((s style))
  "Return the value of the style."
  (value-raw (style-value s))) ; Use style-value accessor now

(defgeneric valid-value-p (property v))
(defgeneric group-key (obj))
(defmethod stylegroup-p ((obj style-group)) t)
(defmethod stylegroup-p ((obj style)) nil)
(defmethod group-key ((obj style-group)) (style-property obj))
(defmethod group-key ((obj style)) (style-property obj))
(defgeneric group-styles (style-group-key))
(defgeneric from-style-set (stylegroup style-set)
  (:method ((stylegroup null) (style-set t)) nil)
  (:documentation
   "Return a style set that contains the styles from the given style set that belong to the given group."))
(defgeneric group-styles (style)
  (:method ((style t)) nil)
  (:documentation
   "Return the styles that belong to the group of the given style, or NIL if it doesn't belong to a group."))
(defgeneric parents-of (stylable)
  (:method ((stylable t)) "Return the parent elements of the given stylable."
    nil)
  (:documentation "Return the parent elements of the given stylable."))
(defgeneric selects (selector stylable)
  (:method ((selector t) (stylable null)) nil)
  (:documentation "Return T if the given selector selects the given stylable, NIL otherwise."))
;; Existing definitions remain unchanged...

(defgeneric style-set-valid (style-set)
  (:documentation "Check if the given style-set is valid."))
;; (defgeneric make-selector (type &rest args))
(defgeneric default-styling (prop)
  (:method ((stylable t)) nil)
  (:documentation "Return the default styling for the given property."))
(defmethod make-selector (type &rest args)
  (declare (ignore type args))
  (error "make-selector not implemented"))

(defgeneric make-default-styling ()
  (:method () nil)
  (:documentation "Create a default style set derived from all styles that define a default value."))
(defgeneric style-rule-valid (rule)
  (:method ((set t)) nil)
  (:documentation "Check if the style set is valid."))
(defmethod new ((class (eql 'style-rule)) &key selector styles)
  "Create a new style rule."
  (let ((rule (make-instance 'style-rule :selector selector :styles styles)))
    (when (style-rule-valid rule) rule)))

(defmethod new ((class (eql 'style-set)) &key styles)
  "Create a new style set."
  (let ((set (make-instance 'elmtui.style-lib.api:style-set)))
    (setf (style-set-styles set) (or styles (make-hash-table :test #'equal)))
    (when (style-set-valid set) set)))

(defgeneric implement-style (stylable style value)
  (:method ((stylable t) (style t) (value t))
    nil)
  (:documentation "Implement a style in the given style set."))
(defgeneric ordered-styles (style-key-list)
  ;; Default behavior: return the list as is
  )
;; (defmethod print-object ((rule style-rule) stream))

(defgeneric valid-value-p (property value)
  (:documentation "Checks if VALUE is valid for the given PROPERTY object.")
  ;; Default method allows any value if no specific validation is defined
  (:method ((p property) v) (declare (ignore p v)) t))

(defgeneric group-key (style-group)
  (:documentation "Returns the keyword identifier for a style group."))

(defgeneric group-styles (style-group)
  (:documentation "Returns the list of individual sub-styles within a style group.")
  (:method ((sg style-group)) (style-sub-styles sg)))

;; (defun stylegroup-p (obj)
;;   "Checks if OBJ is a style-group."
;;   (typep obj 'style-group))

;;; --- Printing ---

(defmethod print-object ((obj property) stream)
  (print-unreadable-object (obj stream :type t)
    (format stream ":~A" (property-name obj))))

(defmethod print-object ((obj value) stream)
  (print-unreadable-object (obj stream :type t)
    (format stream "~S~@[ (~A)~]" (value-value obj) (unless (eq t (value-type obj)) (value-type obj)))))

(defmethod print-object ((obj style) stream)
  (print-unreadable-object (obj stream :type t)
    (format stream "~A ~A" (style-property obj) (style-value obj))))

(defmethod print-object ((obj style-group) stream)
  (print-unreadable-object (obj stream :type t :identity nil)
    (format stream "~A (~D sub-styles)" (group-key obj) (length (style-sub-styles obj)))))
;; End of api.lisp
