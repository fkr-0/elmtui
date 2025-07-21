;;;===============================================================
;;; File: src/view/dsl/base.lisp
;;; Enhanced Base DSL System with Validation and Expansion
;;;===============================================================
(uiop:define-package :elmtui.view.base-elements
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.utils #:as)
  (:import-from :sb-mop
                class-direct-slots slot-definition-name)
  (:export
   ;; Base class & common accessors
   #:base-element #:element-id #:element-children
   ;; Concrete element classes & their main readers
   #:base-dsl-error
   #:container-element #:container-layout #:container-style #:container-class
   #:text-element      #:text-content   #:text-wrap #:text-align #:text-color
   #:separator-element #:separator-orientation #:separator-thickness
   #:spacer-element    #:spacer-width  #:spacer-height
   ;; Traversal helpers
   #:to-dsl #:dsl->objects #:map-elements #:find-elements-by-type
   #:base-dsl-p #:element-type-p #:valid-property-p #:validate-base-dsl
   #:validate-dsl-element #:validate-content-model #:validate-children
   #:property-exists-p #:expand-base-dsl #:expand-dsl-element
   #:normalize-base-dsl #:dsl-element-type #:dsl-properties #:dsl-children
   #:make-dsl-element #:update-dsl-element
   #:find-elements-by-type #:find-element-by-id #:map-dsl-elements
   #:describe-element-type #:validate-dsl-tree #:dsl-statistics

   ))

(in-package :elmtui.view.base-elements)

;;;--------------------------------------------------------------
;;; Base DSL Grammar and Element Registry
;;;--------------------------------------------------------------

;; Core element types with their specifications
;; (defparameter *base-element-types*
;;   `((:container
;;      :description "Generic container for other elements"
;;      :valid-properties (:id :children :style :class :layout :padding :margin :gap)
;;      :required-properties ()
;;      :default-properties (:layout :vertical)
;;      :content-model :children)

;;     (:text
;;      :description "Text content element"
;;      :valid-properties (:id :content :style :class :wrap :align :color)
;;      :required-properties (:content)
;;      :default-properties (:wrap t :align :left)
;;      :content-model :text)

;;     (:separator
;;      :description "Visual separator element"
;;      :valid-properties (:id :orientation :style :class :thickness)
;;      :required-properties ()
;;      :default-properties (:orientation :horizontal :thickness 1)
;;      :content-model :void)

;;     (:spacer
;;      :description "Empty space element for layout"
;;      :valid-properties (:id :width :height :style :class)
;;      :required-properties ()
;;      :default-properties (:width 0 :height 0)
;;      :content-model :void)

;;     (:label
;;      :description "Text label element"
;;      :valid-properties (:id :text :style :class :for :color)
;;      :required-properties (:text)
;;      :default-properties ()
;;      :content-model :text)

;;     (:button
;;      :description "Interactive button element"
;;      :valid-properties (:id :text :style :class :disabled :on-click :focusable)
;;      :required-properties (:text)
;;      :default-properties (:disabled nil :focusable t)
;;      :content-model :interactive)

;;     (:input
;;      :description "Text input element"
;;      :valid-properties (:id :type :value :placeholder :style :class :disabled
;;                             :on-change :on-focus :on-blur :focusable :required)
;;      :required-properties (:type)
;;      :default-properties (:type :text :disabled nil :focusable t :required nil)
;;      :content-model :form)

;;     (:textarea
;;      :description "Multi-line text input"
;;      :valid-properties (:id :value :placeholder :rows :cols :style :class
;;                             :disabled :on-change :on-focus :on-blur :focusable :required)
;;      :required-properties ()
;;      :default-properties (:rows 4 :cols 40 :disabled nil :focusable t :required nil)
;;      :content-model :form)

;;     (:select
;;      :description "Selection dropdown element"
;;      :valid-properties (:id :value :options :style :class :disabled
;;                         :on-change :focusable :multiple)
;;      :required-properties (:options)
;;      :default-properties (:disabled nil :focusable t :multiple nil)
;;      :content-model :form)

;;     (:checkbox
;;      :description "Checkbox input element"
;;      :valid-properties (:id :checked :label :style :class :disabled
;;                         :on-change :focusable)
;;      :required-properties ()
;;      :default-properties (:checked nil :disabled nil :focusable t)
;;      :content-model :form)

;;     (:radio
;;      :description "Radio button input element"
;;      :valid-properties (:id :checked :label :name :value :style :class
;;                             :disabled :on-change :focusable)
;;      :required-properties (:name)
;;      :default-properties (:checked nil :disabled nil :focusable t)
;;      :content-model :form)

;;     (:image
;;      :description "Image display element"
;;      :valid-properties (:id :src :alt :width :height :style :class)
;;      :required-properties (:src)
;;      :default-properties ()
;;      :content-model :media)

;;     (:link
;;      :description "Hyperlink element"
;;      :valid-properties (:id :href :text :target :style :class :on-click)
;;      :required-properties (:href :text)
;;      :default-properties (:target :_self)
;;      :content-model :interactive)

;;     (:list
;;      :description "List container element"
;;      :valid-properties (:id :items :style :class :ordered :item-style)
;;      :required-properties (:items)
;;      :default-properties (:ordered nil)
;;      :content-model :children)

;;     (:table
;;      :description "Table element with rows and columns"
;;      :valid-properties (:id :headers :rows :style :class :border :cell-padding)
;;      :required-properties (:rows)
;;      :default-properties (:border t :cell-padding 1)
;;      :content-model :tabular)))

;;;----------------------------------------------------------------
;;; 1. Abstract root --———————————————————————————————
;;;----------------------------------------------------------------
;;; ---------------------------------------------------------------
;;; Content-model enumeration
;;; ---------------------------------------------------------------
(defparameter +content-models+
  '(:void :text :children :interactive :form :media :tabular)
  "List of valid content models for elements. A content model
  describes what kind of content an element can have. Legal
  values are:
  - :void: no content, element is a leaf
  - :text: element contains plain text
  - :children: element contains other elements as children
  - :interactive: element is interactive (e.g. button, link
    or input
  - :form: element is a form control (input, textarea, select
    or checkbox
  - :media: element contains media (image, video, audio)
  - :tabular: element contains tabular data (table, grid")

(defparameter *element-type->class*
  '(;; (:container . container-element)
    ;; (:text      . text-element)
    ;; (:separator . separator-element)
    ;; (:spacer    . spacer-element))
    ))
;;; ---------------------------------------------------------------
;;; Helper
;;; ---------------------------------------------------------------
(defun %register-element-class (keyword class)
  "Add or replace the (keyword . class) pair in *element-type->class*."
  (setf *element-type->class*
        (acons keyword class
               (remove keyword *element-type->class* :key #'car))))
(defclass base-element ()
  ((id :initarg :id
       :accessor element-id
       :initform nil
       :type (or null keyword))
   (children :initarg :children
             :accessor element-children
             :initform nil
             :type list)
   (content-model :initarg :content-model
                  :accessor element-content-model
                  :initform :void
                  :type (lambda (x) (member x +content-models+))))
  (:documentation "Abstract *stateless* layout element.  Concrete
  subclasses add their own slots but never mutate them after
  initialisation.")
  (:metaclass standard-class))

(defgeneric to-dsl (element)
  (:documentation "Render ELEMENT back to the canonical DSL plist
  representation (keywords + properties). Useful for debugging or
  when external code still assumes the old representation."))

(defgeneric validate-element (element &optional context)
  (:documentation "Perform cross-slot checks that go beyond simple
  type declarations (e.g. required content not NIL).  Called at the
  end of INITIALIZE-INSTANCE."))

(defmethod print-object ((obj base-element) stream)
  (print-unreadable-object (obj stream :type t :identity t)
    (format stream "~@[id: ~A~]" (element-id obj))))

(defmethod initialize-instance :after ((obj base-element) &key)
  "Initialize a base element instance. This method is called
    automatically when creating a new instance of a base element."
  ;; (call-next-method obj)
  (validate-element obj))

(defmethod validate-element ((e base-element) &optional context)
  "Minimal validation for base elements. Subclasses should override
    this method to add their own checks."
  (declare (ignore context e))
  ;; Base rule: nothing special to validate here – subclasses add checks
  t
  )

;;;----------------------------------------------------------------
;;; 2. Concrete element classes
;;;----------------------------------------------------------------

;;; -- Container --------------------------------------------------
(defclass container-element (base-element)
  ((layout :initarg :layout :accessor container-layout :initform :vertical
           :type keyword)
   (style  :initarg :style  :accessor container-style  :initform nil)
   (class  :initarg :class  :accessor container-class  :initform nil)
   (padding :initarg :padding :initform 0 :type fixnum)
   (margin  :initarg :margin  :initform 0 :type fixnum)
   (gap     :initarg :gap     :initform 1 :type fixnum))
  (:documentation "Generic layout container holding *children*.  All
  sizing / spacing attributes are purely declarative.") )

(defmethod element-type ((e container-element)) :container)
(%register-element-class :container 'container-element)

(defmethod validate-element ((c container-element) &optional context)
  (declare (ignore context))
  ;; Ensure GAP / PADDING / MARGIN are non-negative
  (dolist (slot '(padding margin gap))
    (unless (>= (slot-value c slot) 0)
      (error "~A must be non-negative (got ~A)" slot (slot-value c slot)))))

(defmethod to-dsl ((c container-element))
  (list :container
        :id (element-id c)
        :layout (container-layout c)
        :style (container-style c)
        :class (container-class c)
        :padding (slot-value c 'padding)
        :margin  (slot-value c 'margin)
        :gap     (slot-value c 'gap)
        :children (mapcar #'to-dsl (element-children c))))

;;; -- Text -------------------------------------------------------
(defclass text-element (base-element)
  ((content :initarg :content :accessor text-content :initform ""
            :type string)
   (wrap    :initarg :wrap    :accessor text-wrap    :initform t :type boolean)
   (align   :initarg :align   :accessor text-align   :initform :left :type keyword)
   (color   :initarg :color   :accessor text-color   :initform nil))
  (:documentation "Plain text node."))

(defmethod validate-element ((txt text-element) &optional context)
  (declare (ignore context))
  (when (string= (text-content txt) "")
    (warn "Text element with empty CONTENT")))

(%register-element-class :text 'text-element)
(defmethod element-type ((e text-element)) :text)

(defmethod to-dsl ((txt text-element))
  (list :text
        :id (element-id txt)
        :content (text-content txt)
        :wrap (text-wrap txt)
        :align (text-align txt)
        :color (text-color txt)))

;;; -- Separator --------------------------------------------------
(defclass separator-element (base-element)
  ((orientation :initarg :orientation :accessor separator-orientation
                :initform :horizontal :type keyword)
   (thickness   :initarg :thickness   :accessor separator-thickness
                :initform 1 :type (integer 1)))
  (:documentation "Visual line used to divide regions."))

(%register-element-class :separator 'separator-element)
(defmethod to-dsl ((s separator-element))
  (list :separator
        :id (element-id s)
        :orientation (separator-orientation s)
        :thickness (separator-thickness s)))

;;; -- Spacer -----------------------------------------------------
(defclass spacer-element (base-element)
  ((width  :initarg :width  :accessor spacer-width  :initform 0 :type fixnum)
   (height :initarg :height :accessor spacer-height :initform 0 :type fixnum))
  (:documentation "Empty area for fine-grained layout control."))

(%register-element-class :spacer 'spacer-element)


(defmethod to-dsl ((s spacer-element))
  (list :spacer
        :id (element-id s)
        :width  (spacer-width s)
        :height (spacer-height s)))





;;; ---------------------------------------------------------------
;;; Label
;;; ---------------------------------------------------------------
(defclass label-element (base-element)
  ((text  :initarg :text  :type string  :reader label-text  :documentation "Displayed label text.")
   (for   :initarg :for   :initform nil :reader label-for   :documentation "ID of the control this label describes.")
   (color :initarg :color :initform nil :reader label-color :documentation "Optional colour keyword."))
  (:default-initargs :content-model :text)
  (:documentation "Plain text label element."))

(defmethod element-type ((e label-element)) :label)
(%register-element-class :label 'label-element)

;;; ---------------------------------------------------------------
;;; Button
;;; ---------------------------------------------------------------
(defclass button-element (base-element)
  ((text      :initarg :text      :type string  :reader button-text)
   (disabled  :initarg :disabled  :initform nil :type boolean :reader button-disabled-p)
   (on-click  :initarg :on-click  :initform nil :reader button-on-click)
   (focusable :initarg :focusable :initform t  :type boolean :reader button-focusable-p))
  (:default-initargs :content-model :interactive)
  (:documentation "Interactive push-button element."))

(defmethod element-type ((e button-element)) :button)
(%register-element-class :button 'button-element)

;;; ---------------------------------------------------------------
;;; Input (single-line)
;;; ---------------------------------------------------------------
(defclass input-element (base-element)
  ((type       :initarg :type       :initform :text :reader input-type)
   (value      :initarg :value      :initform ""    :reader input-value)
   (placeholder :initarg :placeholder :initform nil   :reader input-placeholder)
   (disabled   :initarg :disabled   :initform nil   :type boolean :reader input-disabled-p)
   (required   :initarg :required   :initform nil   :type boolean :reader input-required-p)
   (focusable  :initarg :focusable  :initform t     :type boolean :reader input-focusable-p)
   (on-change  :initarg :on-change  :initform nil   :reader input-on-change)
   (on-focus   :initarg :on-focus   :initform nil   :reader input-on-focus)
   (on-blur    :initarg :on-blur    :initform nil   :reader input-on-blur))
  (:default-initargs :content-model :form)
  (:documentation "Single-line text / password / email input field."))

(defmethod element-type ((e input-element)) :input)
(%register-element-class :input 'input-element)

;;; ---------------------------------------------------------------
;;; Textarea
;;; ---------------------------------------------------------------
(defclass textarea-element (base-element)
  ((value      :initarg :value      :initform ""  :reader textarea-value)
   (placeholder :initarg :placeholder :initform nil :reader textarea-placeholder)
   (rows       :initarg :rows       :initform 4  :type fixnum   :reader textarea-rows)
   (cols       :initarg :cols       :initform 40 :type fixnum   :reader textarea-cols)
   (disabled   :initarg :disabled   :initform nil :type boolean :reader textarea-disabled-p)
   (required   :initarg :required   :initform nil :type boolean :reader textarea-required-p)
   (focusable  :initarg :focusable  :initform t   :type boolean :reader textarea-focusable-p)
   (on-change  :initarg :on-change  :initform nil :reader textarea-on-change)
   (on-focus   :initarg :on-focus   :initform nil :reader textarea-on-focus)
   (on-blur    :initarg :on-blur    :initform nil :reader textarea-on-blur))
  (:default-initargs :content-model :form)
  (:documentation "Multi-line text input element."))

(defmethod element-type ((e textarea-element)) :textarea)
(%register-element-class :textarea 'textarea-element)

;;; ---------------------------------------------------------------
;;; Select
;;; ---------------------------------------------------------------
(defclass select-element (base-element)
  ((value      :initarg :value      :initform nil :reader select-value)
   (options    :initarg :options    :type list    :reader select-options)
   (multiple   :initarg :multiple   :initform nil :type boolean :reader select-multiple-p)
   (disabled   :initarg :disabled   :initform nil :type boolean :reader select-disabled-p)
   (focusable  :initarg :focusable  :initform t   :type boolean :reader select-focusable-p)
   (on-change  :initarg :on-change  :initform nil :reader select-on-change))
  (:default-initargs :content-model :form)
  (:documentation "Dropdown / multi-select element."))

(defmethod element-type ((e select-element)) :select)
(%register-element-class :select 'select-element)

;;; ---------------------------------------------------------------
;;; Checkbox
;;; ---------------------------------------------------------------
(defclass checkbox-element (base-element)
  ((checked    :initarg :checked    :initform nil :type boolean :reader checkbox-checked-p)
   (label      :initarg :label      :initform ""  :reader checkbox-label)
   (disabled   :initarg :disabled   :initform nil :type boolean :reader checkbox-disabled-p)
   (focusable  :initarg :focusable  :initform t   :type boolean :reader checkbox-focusable-p)
   (on-change  :initarg :on-change  :initform nil :reader checkbox-on-change))
  (:default-initargs :content-model :form)
  (:documentation "Single checkbox input element."))

(defmethod element-type ((e checkbox-element)) :checkbox)
(%register-element-class :checkbox 'checkbox-element)

;;; ---------------------------------------------------------------
;;; Radio
;;; ---------------------------------------------------------------
(defclass radio-element (base-element)
  ((name       :initarg :name       :reader radio-name)
   (value      :initarg :value      :initform ""  :reader radio-value)
   (checked    :initarg :checked    :initform nil :type boolean :reader radio-checked-p)
   (label      :initarg :label      :initform ""  :reader radio-label)
   (disabled   :initarg :disabled   :initform nil :type boolean :reader radio-disabled-p)
   (focusable  :initarg :focusable  :initform t   :type boolean :reader radio-focusable-p)
   (on-change  :initarg :on-change  :initform nil :reader radio-on-change))
  (:default-initargs :content-model :form)
  (:documentation "Radio-button option element."))

(defmethod element-type ((e radio-element)) :radio)
(%register-element-class :radio 'radio-element)

;;; ---------------------------------------------------------------
;;; Image
;;; ---------------------------------------------------------------
(defclass image-element (base-element)
  ((src    :initarg :src    :type string :reader image-src)
   (alt    :initarg :alt    :initform "" :reader image-alt)
   (width  :initarg :width  :initform nil :reader image-width)
   (height :initarg :height :initform nil :reader image-height))
  (:default-initargs :content-model :media)
  (:documentation "Static image element."))

(defmethod element-type ((e image-element)) :image)
(%register-element-class :image 'image-element)

;;; ---------------------------------------------------------------
;;; Link
;;; ---------------------------------------------------------------
(defclass link-element (base-element)
  ((href     :initarg :href     :type string :reader link-href)
   (text     :initarg :text     :type string :reader link-text)
   (target   :initarg :target   :initform :_self :reader link-target)
   (on-click :initarg :on-click :initform nil   :reader link-on-click))
  (:default-initargs :content-model :interactive)
  (:documentation "Hyperlink element."))

(defmethod element-type ((e link-element)) :link)
;; (%register-element-class :link 'link-element)

;;; ---------------------------------------------------------------
;;; List
;;; ---------------------------------------------------------------
(defclass list-element (base-element)
  ((items      :initarg :items      :type list :reader list-items)
   (ordered    :initarg :ordered    :initform nil :type boolean :reader list-ordered-p)
   (item-style :initarg :item-style :initform nil :reader list-item-style))
  (:default-initargs :content-model :children)
  (:documentation "Ordered / unordered list container."))

(defmethod element-type ((e list-element)) :list)
(%register-element-class :list 'list-element)

;;; ---------------------------------------------------------------
;;; Table
;;; ---------------------------------------------------------------
(defclass table-element (base-element)
  ((headers      :initarg :headers      :initform nil :type list :reader table-headers)
   (rows         :initarg :rows         :type list  :reader table-rows)
   (border       :initarg :border       :initform t   :type boolean :reader table-border-p)
   (cell-padding :initarg :cell-padding :initform 1   :type fixnum  :reader table-cell-padding))
  (:default-initargs :content-model :tabular)
  (:documentation "Tabular data element."))

(defmethod element-type ((e table-element)) :table)
;; (%register-element-class :table 'table-element)




;;;----------------------------------------------------------------
;;; 3. Bidirectional conversion helpers
;;;----------------------------------------------------------------

(defun ensure-keyword-or-nil (v)
  (when (and v (not (keywordp v)))
    (error "Expected keyword or NIL, got ~A" v))
  v)

(defun dsl->objects (dsl)
  "Convert the old plist representation into new BASE-ELEMENT instances."
  (cond
    ((null dsl) nil)
    ((or (stringp dsl) (numberp dsl)) dsl) ; raw leaf stays raw

    ;; list of elements → map individually
    ((and (listp dsl) (not (keywordp (first dsl))))
     (mapcar #'dsl->objects dsl))

    ;; single element
    ((and (listp dsl) (keywordp (first dsl)))
     (destructuring-bind (type &rest props) dsl
       (ecase type
         (:container
          (make-instance 'container-element
                         :id (ensure-keyword-or-nil (getf props :id))
                         :layout (getf props :layout :vertical)
                         :style (getf props :style)
                         :class (getf props :class)
                         :padding (getf props :padding 0)
                         :margin  (getf props :margin 0)
                         :gap     (getf props :gap 1)
                         :children (dsl->objects (getf props :children))) )
         (:text
          (make-instance 'text-element
                         :id (ensure-keyword-or-nil (getf props :id))
                         :content (getf props :content "")
                         :wrap (getf props :wrap t)
                         :align (getf props :align :left)
                         :color (getf props :color)))
         (:separator
          (make-instance 'separator-element
                         :id (ensure-keyword-or-nil (getf props :id))
                         :orientation (getf props :orientation :horizontal)
                         :thickness (getf props :thickness 1)))
         (:spacer
          (make-instance 'spacer-element
                         :id (ensure-keyword-or-nil (getf props :id))
                         :width (getf props :width 0)
                         :height (getf props :height 0))) )))

    (t (error "Invalid DSL node: ~A" dsl))))

;;;----------------------------------------------------------------
;;; 4. Traversal utilities (object side)
;;;----------------------------------------------------------------

(defun map-elements (fn element)
  "Apply FN to ELEMENT and recurse into CHILDREN (depth-first)."
  (let ((new (funcall fn element)))
    (etypecase new
      (base-element
       (let ((kids (element-children new)))
         (when kids
           (setf (element-children new)
                 (mapcar (lambda (c) (map-elements fn c)) kids)))
         new))
      ((or string number null) new))))

;; (defun find-elements-by-type (element class-designator)
;;   "Collect every descendant (inclusive) that is of CLASS-DESIGNATOR."
;;   (let ((accum nil))
;;     (labels ((walk (node)
;;                (when (typep node class-designator)
;;                  (push node accum))
;;                (when (and (typep node 'base-element)
;;                           (element-children node))
;;                  (mapc #'walk (element-children node)))) )
;;       (walk element))
;;     (nreverse accum)))

;; former api
;; (defun base-dsl-p (dsl)
;; (defun element-type-p (type)
;; (defun valid-property-p (element-type property)
;; (defun validate-base-dsl (dsl &optional (context "base DSL"))
;; (defun validate-dsl-element (element context)
;; (defun validate-content-model (element content-model context)
;; (defun validate-children (children element-type context)
;; (defun property-exists-p (plist property)
;; (defun expand-base-dsl (dsl &optional (context "expansion"))
;; (defun expand-dsl-element (element context)
;; (defun normalize-base-dsl (dsl)
;; (defun dsl-element-type (element)
;; (defun dsl-properties (element)
;; (defun dsl-children (element)
;; (defun make-dsl-element (type &rest properties)
;; (defun update-dsl-element (element &rest property-updates)
;; (defun find-elements-by-type (dsl element-type)
;; (defun find-element-by-id (dsl id)
;; (defun map-dsl-elements (function dsl)
;; (defun describe-element-type (element-type)
;; (defun validate-dsl-tree (dsl &key (output-stream t))
;; (defun dsl-statistics (dsl)
;;;===============================================================
;;; File: src/view/dsl/base-api.lisp
;;; CLOS-aware helpers for the Base DSL
;;;===============================================================
;; (uiop:define-package :elmtui.view.dsl.base-api

;;   (:export
;;    ;; unchanged public surface
;;    #:base-dsl-p #:element-type-p #:valid-property-p #:validate-base-dsl
;;    #:validate-dsl-element #:validate-content-model #:validate-children
;;    #:property-exists-p #:expand-base-dsl #:expand-dsl-element
;;    #:normalize-base-dsl #:dsl-element-type #:dsl-properties #:dsl-children
;;    #:make-dsl-element #:update-dsl-element
;;    #:find-elements-by-type #:find-element-by-id #:map-dsl-elements
;;    #:describe-element-type #:validate-dsl-tree #:dsl-statistics))

;; (in-package :elmtui.view.dsl.base-api)

;;; ----------------------------------------------------------------
;;;  Shared helpers
;;; ----------------------------------------------------------------



(defun element-class (type)
  "Return the concrete CLOS class that implements TYPE, or NIL."
  (cdr (assoc type *element-type->class*)))

(defun element-prototype (type)
  "Instantiate a *temporary* object of TYPE to introspect its slots."
  (let ((cls (element-class type)))
    (when cls
      (make-instance cls))))

(defun slot-keywords (cls)
  "Return the list of initarg keywords for CLS."
  (mapcar #'slot-definition-name (class-direct-slots (class-of cls))))

;;; ----------------------------------------------------------------
;;;  Predicates
;;; ----------------------------------------------------------------

(defun base-element-p (obj)
  (typep obj 'base-element))

(defun base-dsl-p (dsl)
  (handler-case
      (progn (validate-base-dsl dsl) t)
    (error () nil)))

(defun element-type-p (type)
  (and (keywordp type) (element-class type)))

(defun valid-property-p (element-type property)
  (let ((proto (element-prototype element-type))) ;(log-info "Checking property ~A in ~A ~A" (string-downcase (symbol-name property)) element-type (append '("id" "children")
    (if (member
         (string-downcase (symbol-name property))
         (append '("id" "children")
                 (mapcar (lambda (x) (string-downcase (symbol-name x)))
                         (slot-keywords proto)))
         :test #'string=)
        t
        nil)))

;;; ----------------------------------------------------------------
;;;  Validation
;;; ----------------------------------------------------------------

(defgeneric validate-element (element &optional context)
  (:documentation "Signal an error if ELEMENT is malformed."))

(defmethod validate-element ((e base-element) &optional context)
  "Minimal object validation – override in subclasses if needed."
  (declare (ignore context))
  t)

(defun validate-base-dsl (dsl &optional (context "base DSL"))
  "Accept either legacy plist DSL or objects."
  (cond
    ((base-element-p dsl)
     (validate-element dsl context))
    ((and (listp dsl) (keywordp (first dsl)))
     (validate-dsl-element dsl context))
    ((and (listp dsl))                    ; list of nodes
     (dolist (child dsl)
       (validate-base-dsl child (format nil "~A list item" context))))
    ((or (stringp dsl) (numberp dsl) (null dsl)))
    (t (error "Invalid DSL structure ~S in ~A" dsl context)))
  dsl)

(defun validate-dsl-element (element context)
  "Legacy plist element validation (kept for compatibility)."
  (let* ((element-type (first element))
         (cls (element-class element-type)))
    (unless cls
      (error 'base-dsl-error
             :element element
             :reason (format nil "Unknown element type ~A" element-type)
             :context context))
    ;; Ensure even-length plist for properties
    (unless (evenp (length (rest element)))
      (error 'base-dsl-error
             :element element
             :reason "Odd-length initializer list"
             :context context))
    ;; Check properties against the class's initargs
    (let ((valid-keys (slot-keywords (element-prototype element-type))))
      (loop for (k v) on (rest element) by #'cddr
            unless (member k valid-keys)
              do (warn "Unknown property ~S for element type ~S in ~A"
                       k element-type context)))
    ;; Delegate further validation to the object instance
    (let ((obj (apply #'make-instance cls (rest element))))
      (validate-element obj context))))

;; Object path

(defmethod validate-content-model ((e base-element) model context)
  (declare (ignore model context))
  t)

(defmethod validate-children ((children list) (e base-element) context)
  (dolist (child children)
    (validate-base-dsl child (format nil "~A > children" context))))

;; compatibility stubs for old plist path
(defmethod validate-content-model (element content-model context)
  (declare (ignore content-model))
  ;; recurse for :children if present
  (let ((children (getf (rest element) :children)))
    (when children
      (validate-children children element context)))
  t)

(defmethod validate-children (children element-type context)
  (declare (ignore element-type))
  (dolist (child children)
    (validate-base-dsl child (format nil "~A > children" context))))

;;; ----------------------------------------------------------------
;;;  Expansion / normalisation
;;; ----------------------------------------------------------------

(defun expand-base-dsl (dsl &optional (context "expansion"))
  ;; (log-info "Expanding DSL in ~A: ~A" context dsl)
  (typecase dsl
    (base-element       dsl)             ; objects already hold defaults
    (string             dsl)
    (number             dsl)
    (null               dsl)
    (list
     (if (keywordp (first dsl))
         (expand-dsl-element dsl context)
         (mapcar (lambda (el) (expand-base-dsl el context)) dsl)))
    (t dsl)))

(defun expand-dsl-element (element context)
  ;; (let ((ttt (apply #'make-instance (element-class (first element)) (rest element))))
  ;;   (log-info "Expanding element ~A in ~A to ~A with rest ~A" (first element)
  ;;             (element-class (first element))
  ;;             ttt
  ;;             (rest element))
  ;;   ttt)
  (let* ((cls (element-class (first element))))
    (if cls
        (let ((obj (apply #'make-instance cls (rest element))))
          ;; (log-info "Expanding ~A in ~A" (element-id obj) context)
          ;; recurse into children
          (let ((kids (slot-value obj 'children)))
            (when
                (setf (slot-value obj 'children)
                      (mapcar (lambda (k) (expand-base-dsl k (format nil "~A > children" context)))
                              kids))))
          obj)
        element)))                        ; unknown type, leave as is

(defun normalize-base-dsl (dsl)
  (let ((l
          (validate-base-dsl (expand-base-dsl dsl  "normalization") "normalization")))
    (format nil "~A~%" l)
    l))


;;; ----------------------------------------------------------------
;;;  Accessors (object-aware)
;;; ----------------------------------------------------------------

(defun dsl-element-type (element)
  (etypecase element
    (base-element (element-type element))
    (null nil)
    (list (first element))
    (string :text-node)
    (number :number-node)))

(defun dsl-properties (element)
  (cond
    ((base-element-p element)
     ;; turn slots into plist
     (loop for slot in (slot-keywords element)
           for val = (slot-value element slot)
           when val
             append (list slot val)))
    ((listp element) (rest element))))

(defun dsl-children (element)
  (cond
    ((base-element-p element) (slot-value element 'children))
    ((listp element) (getf (rest element) :children))))

;;; ----------------------------------------------------------------
;;;  Constructors / mutators
;;; ----------------------------------------------------------------

(defun make-dsl-element (type &rest properties)
  (let
      ((cls (element-class type)))
    (if cls
        (apply #'make-instance cls properties)
        ;; fall back to legacy
        (list* type properties))))

(defun update-dsl-element (element &rest property-updates)
  (cond
    ((base-element-p element)
     (loop for (k v) on property-updates by #'cddr
           do (setf (slot-value element k) v))
     element)
    ((listp element)
     (let ((props (copy-list (rest element))))
       (loop for (k v) on property-updates by #'cddr
             do (setf (getf props k) v))
       (list* (first element) props)))))

;;; ----------------------------------------------------------------
;;;  Traversal helpers (work on mixed trees)
;;; ----------------------------------------------------------------

(defun %each-child (node fn)
  (typecase node
    (base-element
     (let ((kids (dsl-children node)))
       (when kids (dolist (k kids) (funcall fn k)))))
    (list
     (dolist (n node) (funcall fn n)))))

(defun map-dsl-elements (function dsl)
  (labels ((recurse (node)
             (let ((new (funcall function node)))
               (%each-child new #'recurse)
               new)))
    (recurse dsl)))

(defun find-elements-by-type (dsl element-type)
  (let ((result '()))
    (map-dsl-elements
     (lambda (node)
       (when (eql (dsl-element-type node) element-type)
         (push node result))
       node)
     dsl)
    (nreverse result)))

(defun find-element-by-id (dsl id)
  (block found
    (map-dsl-elements
     (lambda (node)
       (when (eql (getf (dsl-properties node) :id) id)
         (return-from found node))
       node)
     dsl)
    nil))

;;; ----------------------------------------------------------------
;;;  Introspection / dev support
;;; ----------------------------------------------------------------

(defun describe-element-type (element-type)
  (let ((cls (element-class element-type)))
    (if cls
        (format t "~&~A (~A) slots: ~{~A~^, ~}~%"
                element-type cls (slot-keywords (make-instance cls)))
        (format t "~&Unknown element type ~A~%" element-type))))

(defun validate-dsl-tree (dsl &key (output-stream t))
  (handler-case
      (progn (validate-base-dsl dsl) (format output-stream "✓ DSL ok~%") t)
    (error (e) (format output-stream "✗ ~A~%" e) nil)))

(defun map-counts (hash key) (incf (gethash key hash 0)))

(defun dsl-statistics (dsl)
  (let ((counts (make-hash-table :test #'eq))
        (total-elements 0)
        (max-depth 0))
    (labels ((walk (node depth)
               (when node
                 (incf total-elements)
                 (setf max-depth (max max-depth depth))
                 (let ((type (dsl-element-type node)))
                   (when type (map-counts counts type)))
                 (%each-child node (lambda (n) (walk n (1+ depth)))))))
      (walk dsl 0))
    (list :total-elements total-elements
          :max-depth max-depth
          :element-types (hash-table-count counts)
          :element-counts (alexandria:hash-table-alist counts))))

(define-condition base-dsl-error (error)
  ((element :initarg :element :reader dsl-error-element)
   (reason :initarg :reason :reader dsl-error-reason)
   (context :initarg :context :reader dsl-error-context :initform nil))
  (:report (lambda (condition stream)
             (format stream "Base DSL Error in ~A: ~A~@[ (~A)~]"
                     (dsl-error-element condition)
                     (dsl-error-reason condition)
                     (dsl-error-context condition)))))
;;; ----------------------------------------------------------------
;;;  End of file
;;; ----------------------------------------------------------------
;; Direct construction
;; (make-instance 'button-element
;;                :id :save
;;                :text "Save"
;;                :on-click (lambda (msg) (format t "clicked!~%")))

;; Legacy DSL still works:
;; (normalize-base-dsl '(:input :id :name :type :text :placeholder "Your name"))
;; (apply #'make-instance (element-class :text)
;; (list
;; (normalize-base-dsl '( :text
;;                       :id :welcome-message
;;                       :content "Welcome to the application!"
;;                       :align :center
;;                       :color :blue))
;; ⇒ returns an INPUT-ELEMENT instance (plus default values)

;; (make-instance 'text-element :content "dud")
