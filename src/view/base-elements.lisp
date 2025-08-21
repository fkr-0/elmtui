;;;===============================================================
;;; File: src/view/dsl/base.lisp
;;; Enhanced Base DSL System with Validation and Expansion
;;;===============================================================
(uiop:define-package :elmtui.view.base-elements
  (:use :cl :alexandria :log4cl)

  (:import-from :sb-mop
                #:class-direct-slots #:slot-definition-name)
  ;; (:import-from #:elmtui.view.layout #:layout-node)
  (:import-from #:elmtui.view.geo #:h #:w #:x #:y #:rectangle #:make-size #:make-pos)
  (:import-from #:elmtui.view.api #:styled-ui-node #:ui-node-props)

  (:import-from :elmtui.view.api #:layout-node #:ui-node-children #:ui-node-type)
  (:export
   ;; Base class & common accessors
   #:base-element #:element-id #:element-children
   ;; Concrete element classes & their main readers
   #:base-dsl-error
   #:container-element
   #:element-layout-rect #:element-content-model
   #:element-children #:element-id #:element-style
   #:text-element      #:text-content   #:text-wrap #:text-align #:text-color
   #:separator-element #:separator-orientation #:separator-thickness
   #:spacer-element    #:spacer-width  #:spacer-height

   #:copy-element
   ;; Traversal helpers
   #:to-dsl #:dsl->objects #:map-elements #:find-elements-by-type
   #:base-dsl-p #:element-type-p #:valid-property-p #:validate-base-dsl
   #:validate-dsl-element #:validate-content-model #:validate-children
   #:property-exists-p #:expand-base-dsl #:expand-dsl-element
   #:normalize-base-dsl #:dsl-element-type #:dsl-properties #:dsl-children
   #:make-dsl-element #:update-dsl-element
   #:find-elements-by-type #:find-element-by-id #:map-dsl-elements
   #:describe-element-type #:validate-dsl-tree #:dsl-statistics
   #:element-class
   #:element-layout
   #:element-size
   #:set-element-layout
   #:rect=
   #:compute-layout
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
   (size :initarg :size
         :accessor element-size
         :initform nil
         :type (or null size)) ;; size is a size with width and height
   ;; (padding :initarg :padding :initform 0 :type fixnum)
   ;; (margin  :initarg :margin  :initform 0 :type fixnum)
   ;; (gap     :initarg :gap     :initform 0 :type fixnum)
   (layout-rect :initarg :layout-rect
                :accessor element-layout-rect
                :initform nil
                :type (or null rectangle))
   (children :initarg :children
             :accessor element-children
             :initform nil
             :type list)
   (classes :initarg :classes
            :accessor element-classes
            :initform nil
            :type (or null list)) ;; list of strings or keywords
   (style :initarg :style
          :accessor element-style
          :initform nil ;;(elmtui.style-lib.style-set::make-style-set)
          :type list) ;; elmtui.style-lib:style-set)
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
  t)

;; Weak-key hash to hold *computed* props (size/layout/dirty/prev-*)
(defparameter *computed* (trivial-garbage:make-weak-hash-table :weakness :key :test 'eq))

(defun %props (el)
  (or (gethash el *computed*)
      (setf (gethash el *computed*) nil)))

(defun (setf %props) (plist el)
  (setf (gethash el *computed*) plist))

(defun element-props (el) (%props el))
(defun (setf element-props) (plist el) (setf (%props el) plist))


;; (defun (setf element-size) (val el)
;;   (setf (getf (%props el) :size) val))

;; (defun (setf element-layout) (val el)
;;   (setf (getf (%props el) :layout) val))

(defun element-dirty-p (el) (getf (%props el) :dirty))
(defun (setf element-dirty-p) (flag el)
  (setf (getf (%props el) :dirty) (and flag t)))

(defun snapshot-props-for-diff (el)
  (let* ((p (%props el)))
    (setf (getf p :prev-size)   (getf p :size))
    (setf (getf p :prev-layout) (getf p :layout))
    p))

(defun element-changed-p (el)
  (let* ((p (%props el)))
    (or (not (equal (getf p :size)   (getf p :prev-size)))
        (not (equal (getf p :layout) (getf p :prev-layout))))))


;;;----------------------------------------------------------------
;;; 2. Concrete element classes
;;;----------------------------------------------------------------

;;; -- Container --------------------------------------------------
(defclass container-element (base-element)
  ;; ((layout :initarg :layout :accessor container-layout :initform :vertical
  ;;          :type keyword)
  ;; (style  :initarg :style  :accessor container-style  :initform nil)
  ;; (classes  :initarg :classes  :accessor container-classes  :initform nil)
  ()
  (:documentation "Generic layout container holding *children*.  All
  sizing / spacing attributes are purely declarative.") )
;; (defmethod element-style ((el container-element))
;;   (container-style el))
;; (defmethod (setf element-style) (val (el container-element))
;;   (setf (container-style el) val))

;; Shallow copy that preserves *all slot values* unless overridden.

(defun %slot-exists-p (class slot-name)
  (find slot-name (mapcar #'sb-mop:slot-definition-name
                          (sb-mop:class-slots class))
        :test #'eq))

;; (defun %copy-el (el &key children style props)
;;   (let* ((class (class-of el))
;;          (new-props (if props props (element-props el)))
;;          (new (make-instance class)))
;;     (dolist (slot (sb-mop:class-slots class))
;;       (let ((name (sb-mop:slot-definition-name slot)))
;;         (when (slot-boundp el name)
;;           (setf (slot-value new name) (slot-value el name)))))
;;     (when children (setf (element-children new) children))
;;     (when style (setf (element-style new) style))
;;     (setf (element-props new) new-props)
;;     new))

(defmethod element-type ((e container-element)) :container)
(%register-element-class :container 'container-element)
(%register-element-class :row 'container-element)
(%register-element-class :column 'container-element)

(defmethod validate-element ((c container-element) &optional context)
  (declare (ignore context))
  ;; Ensure GAP / PADDING / MARGIN are non-negative
  ;; (dolist (slot '(padding margin gap))
  ;;   (unless (>= (slot-value c slot) 0)
  ;;     (error "~A must be non-negative (got ~A)" slot (slot-value c slot))))
  )

(defmethod to-dsl ((c container-element))
  (list :container
        :id (element-id c)
        :layout (element-layout-rect c)
        :style (convert-style-plist-to-dsl (element-style c))
        :classes (element-classes c)
        :children (mapcar #'to-dsl (element-children c))))

;;; -- Text -------------------------------------------------------
(defclass text-element (base-element)
  ((content :initarg :content :accessor text-content :initform ""
            :type string)
   (wrap    :initarg :wrap    :accessor text-wrap    :initform t :type boolean)
   (align   :initarg :align   :accessor text-align   :initform :left :type keyword)
   (color   :initarg :color   :accessor text-color   :initform nil))
  (:default-initargs :content-model :text)
  (:documentation "Plain text node."))

(defmethod validate-element ((txt text-element) &optional context)
  (unless (slot-boundp txt 'content)
    (error 'base-dsl-error
           :element txt
           :reason "Missing required property :content"
           :context context))
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
        :color (to-dsl (text-color txt)))) ; Explicitly call to-dsl for color

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


(defmethod to-dsl ((s string)) s)
(defmethod to-dsl ((n number)) n)
(defmethod to-dsl ((o null)) o)
(defmethod to-dsl ((s symbol))
  (if (keywordp s)
      s (intern (string-upcase (symbol-name s)) :keyword)))
(defmethod to-dsl ((l list)) l)





;;; ---------------------------------------------------------------
;;; Label
;;; ---------------------------------------------------------------
(defclass label-element (base-element)
  ((content :initarg :content :type string  :reader label-content :documentation "Displayed label text.")
   (for   :initarg :for   :initform nil :reader label-for   :documentation "ID of the control this label describes.")
   (color :initarg :color :initform nil :reader label-color :documentation "Optional colour keyword."))
  (:default-initargs :content-model :text)
  (:documentation "Plain text label element."))
;;; ---------------------------------------------------------------
;;; Label
;;; ---------------------------------------------------------------
(defmethod to-dsl ((lbl label-element))
  (list :label
        :id (element-id lbl)
        :content (label-content lbl)
        :for (label-for lbl)
        :color (to-dsl (label-color lbl))))

(defmethod element-type ((e label-element)) :label)
(%register-element-class :label 'label-element)

(defmethod validate-element ((lbl label-element) &optional context)
  (unless (slot-boundp lbl 'content)
    (error 'base-dsl-error
           :element lbl
           :reason "Missing required property :content"
           :context context)))

;;; ---------------------------------------------------------------
;;; Button
;;; ---------------------------------------------------------------
(defclass button-element (base-element)
  ((content   :initarg :content   :type string  :reader button-content)
   (disabled  :initarg :disabled  :initform nil :type boolean :reader button-disabled-p)
   (on-click  :initarg :on-click  :initform nil :reader button-on-click)
   (focusable :initarg :focusable :initform t  :type boolean :reader button-focusable-p))
  (:default-initargs :content-model :interactive)
  (:documentation "Interactive push-button element."))

(defmethod element-type ((e button-element)) :button)
(%register-element-class :button 'button-element)

(defmethod validate-element ((btn button-element) &optional context)
  (unless (slot-boundp btn 'content)
    (error 'base-dsl-error
           :element btn
           :reason "Missing required property :content"
           :context context)))

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
   (content  :initarg :content  :type string :reader link-content)
   (target   :initarg :target   :initform :_self :reader link-target)
   (on-click :initarg :on-click :initform nil   :reader link-on-click))
  (:default-initargs :content-model :interactive)
  (:documentation "Hyperlink element."))

(defmethod element-type ((e link-element)) :link)
(%register-element-class :link 'link-element)

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
(%register-element-class :table 'table-element)

;;;----------------------------------------------------------------
;;; 3. Bidirectional conversion helpers
;;;----------------------------------------------------------------

(defun ensure-keyword-or-nil (v)
  (when (and v (not (keywordp v)))
    (error "Expected keyword or NIL, got ~A" v))
  v)

(defun convert-style-plist-to-dsl (style-plist)
  "Recursively converts a style plist to its DSL representation by applying TO-DSL to its values."
  (when style-plist
    (loop for (k v) on style-plist by #'cddr
          append (list k (to-dsl v)))))

(defun convert-style-dsl-to-plist (style-dsl)
  "Recursively converts a style DSL (plist) back to a plist of objects by applying DSL->OBJECTS to its values."
  (when style-dsl
    (loop for (k v) on style-dsl by #'cddr
          append (list k (dsl->objects v)))))

(defun dsl->objects (dsl)
  "Translate an Elm-TUI style DSL (a plist/tree of keywords) into
   concrete instances of BASE-ELEMENT subclasses.

   • strings / numbers are left untouched
   • a list that begins with a keyword denotes *one* element
   • a proper list whose first item is *not* a keyword is treated
     as a sequence of sibling elements"
  (labels (;; Ensure we always recurse on a *list* (or NIL) so that downstream
           ;; code never has to special-case atoms.
           (ensure-dsl-list (d)
             (cond ((null d) nil)
                   ((and (listp d) (keywordp (first d))) (list d))
                   ((listp d) d)
                   (t (list d))))
           (normalize-dsl-props (props)
             (let ((res nil))
               (loop while props
                     do (let ((key (pop props)))
                          (push key res)
                          (if (or (not props) (keywordp (car props)))
                              (push t res)
                              (push (pop props) res))))
               (nreverse res))))

    (cond
      ;; ------------------------------------------------------------------
      ;; 1. primitive leaf
      ((atom dsl)
       dsl)

      ;; ------------------------------------------------------------------
      ;; 2. sibling list (e.g.  ((:row ...) (:text ...)))
      ((and (listp dsl) (not (keywordp (first dsl))))
       (mapcar #'dsl->objects dsl))

      ;; ------------------------------------------------------------------
      ;; 3. single element  ( e.g. (:row :gap 2 :children …) )
      ((and (listp dsl) (keywordp (first dsl)))
       (destructuring-bind (type &rest props) dsl

         (let* ((props (normalize-dsl-props props)))
           (let* ((class (element-class type)))
             (unless class
               (error "Unknown DSL element type: ~A" type))

             ;; This helper returns a flattened list of allowed initargs.
             (flet ((valid-initargs (cls)
                      (alexandria:flatten
                       (slot-initargs cls)
                       ;; (mapcar #'sb-mop:slot-definition-initargs
                       ;;         (sb-mop:class-slots
                       ;;          (find-class cls)))
                       )))

               (let* ((allowed-keys (valid-initargs type))
                      (children-objects (dsl->objects
                                         (ensure-dsl-list (getf props :children))))
                      (filtered-props
                        (loop for (k v) on props by #'cddr
                              when (and (member k allowed-keys) (not (eq k :children)))
                                append (list k
                                             (cond
                                               ((eq k :style) (convert-style-dsl-to-plist v))
                                               ((eq k :item-style) (convert-style-dsl-to-plist v))
                                               ((eq k :color) (dsl->objects v)) ; Color might be a keyword or a complex object
                                               (t (dsl->objects v))))))) ; Recursively convert other values

                 ;; ------------------------------------------------------------------
                 ;; CRITICAL FIX #1 – splice keyword/arg list correctly
                 (apply #'make-instance class
                        (append (list :children children-objects)
                                filtered-props))))))))

      ;; ------------------------------------------------------------------
      ;; 4. anything else is malformed
      (t (error "Invalid DSL node: ~A" dsl)))))


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

(eval-when (:compile-toplevel :load-toplevel :execute)
  )
(defun slot-keywords (cls)
  "Return the list of initarg keywords for CLS."
  (mapcar #'slot-definition-name (class-direct-slots (class-of cls))))

(defun slot-initargs (type-kw)
  "Return the list of initargs for the class corresponding to TYPE-KW.

  This is a list of keywords that can be used to initialize an element.
  Arguments:
  - TYPE-KW: a keyword representing the element type (e.g. :container, :text).

  Returns:
  A list of keywords that can be used as initargs for the class.

  Example:
  (slot-initargs :container) =>
  (:id :children :style :class :layout :padding :margin :gap)"
  (mapcar
   (lambda (x) (car (sb-mop:slot-definition-initargs x)))
   (sb-mop::class-slots
    (find-class (element-class type-kw)))))

(defmethod base-element-has-initarg ((base-element-kw symbol) (property symbol))
  "Check if BASE-ELEMENT-KW has PROPERTY as an initarg."
  (member property (slot-initargs base-element-kw) :test #'equalp))

(defmethod base-element-has-initarg ((base-element-kw null) (property null))
  "Check if BASE-ELEMENT-KW has PROPERTY as an initarg."
  (values nil nil))

(defmethod base-element-has-initarg-p ((base-element-kw null) (property list))
  "Check if BASE-ELEMENT-KW has PROPERTY as an initarg."
  (values nil nil))

(defmethod base-element-has-initarg-p ((base-element-kw symbol) (property list))
  "Check if BASE-ELEMENT-KW has PROPERTY as an initarg."
  (let* ((args (slot-initargs base-element-kw))
         (res (remove-if (lambda (x) (member x args :test #'equalp)) property)))
    (if (< 0 (length res ))
        (values nil res)
        (values t nil))))

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
;; (element-class :container)
(defun valid-property-p (element-type property)
  "Checks if PROPERTY is a valid initarg for the class corresponding to ELEMENT-TYPE."
  (base-element-has-initarg element-type property))
;; (let ((element-type :container)
;;       (property :id))
;; (let ((class (element-class element-type)))
;;   (when class
;;     (let* (;; (all-slots (sb-mop:class-slots
;;            ;;             (sb-mop::class-of
;;            ;;              property)))
;;            (initargs (mapcar
;;                       (lambda (x) (sb-mop:slot-definition-initargs x))
;;                       (sb-mop::class-slots
;;                        (find-class class)))))
;;       (member (list property) initargs :test #'equalp))))
;; (valid-property-p :container :id)
                                        ;(mapcar (lambda (x) (sb-mop:slot-definition-initargs x));; (sb-mop::class-slots

;;                           class))
;; (sb-mop:effective-slot-definition-class (sb-mop::class-of (make-instance 'container-element :id :d)))
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
    (let (;; (valid-keys (slot-keywords (element-prototype element-type)))
          (keys (loop for (k v) on (rest element) by #'cddr
                      collect k)))
      (multiple-value-bind (has-p missing)
          (base-element-has-initarg-p element-type keys)
        (unless has-p
          (error 'base-dsl-error
                 :element element
                 :reason (format nil "Invalid properties ~A for element type ~A"
                                 missing element-type)
                 :context context)))
      ;; Delegate further validation to the object instance
      ;; (log-info "Validating element ~A in context ~A" (first element) (rest element))
      (let ((obj (apply #'make-instance (append (list cls) (rest element)))))
        (validate-element obj context)))))

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
             append (list (elmtui.utils:ensure-keyword slot) val)))
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
     (let* ((class (class-of element))
            (current-props
              (loop for slot-def in (sb-mop:class-direct-slots class)
                    for slot-name = (sb-mop:slot-definition-name slot-def)
                    when (slot-boundp element slot-name)
                      append (list (intern (symbol-name slot-name) :keyword)
                                   (slot-value element slot-name))))
            (new-props (copy-list property-updates)))
       (loop for (k v) on current-props by #'cddr
             unless (getf new-props k)
               do (setf (getf new-props k) v))
       (apply #'make-instance class new-props)))
    ((listp element)
     (let ((props (copy-list (rest element))))
       (loop for (k v) on property-updates by #'cddr
             do (setf (getf props k) v))
       (list* (first element) props)))))

;;; ----------------------------------------------------------------
;;;  Traversal helpers (work on mixed trees)
;;; ----------------------------------------------------------------

(defun %each-child (node fn)
  (cond
    ((typep node 'base-element)
     (let ((kids (element-children node)))
       (when kids (dolist (k kids) (funcall fn k)))))
    ((listp node)
     (if (keywordp (first node)) ; It's a legacy dsl element
         (let ((kids (getf (rest node) :children)))
           (when kids (dolist (k kids) (funcall fn k))))
         ;; It's a list of nodes
         (dolist (n node) (funcall fn n))))))

(defun map-dsl-elements (function dsl)
  "Recursively apply FUNCTION to each node in the DSL tree, transforming it.
   Returns a new, transformed tree."
  (let ((new-node (funcall function dsl)))
    (when (and (typep new-node 'base-element) (element-children new-node))
      (setf (element-children new-node)
            (mapcar (lambda (child) (map-dsl-elements function child))
                    (element-children new-node))))
    new-node))

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
       (typecase node
         (base-element
          (when (eql (element-id node) id)
            (return-from found node)))
         (list
          (when (eql (getf (rest node) :id) id)
            (return-from found node))))
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
;; (normalize-base-dsl '(:container :id :name ))
;; (apply #'make-instance (element-class :text)
;; (list
;; (normalize-base-dsl '( :text
;;                       :id :welcome-message
;;                       :CONTENT "Welcome to the application!"
;;                       :align :center
;;                       :color :blue))
;; ⇒ returns an INPUT-ELEMENT instance (plus default values)

;; (make-instance 'text-element :content "dud")

;; (validate-BASE-DSL '(:BUTTON :content "Click Me"))
;; (make-instance 'button-element :content "Click Me")



;;; ---------------------------------------------------------------
;;; Button
;;; ---------------------------------------------------------------
(defmethod to-dsl ((btn button-element))
  (list :button
        :id (element-id btn)
        :content (button-content btn)
        :disabled (button-disabled-p btn)
        :on-click (button-on-click btn)
        :focusable (button-focusable-p btn)))

;;; ---------------------------------------------------------------
;;; Input (single-line)
;;; ---------------------------------------------------------------
(defmethod to-dsl ((inp input-element))
  (list :input
        :id (element-id inp)
        :type (input-type inp)
        :value (input-value inp)
        :placeholder (input-placeholder inp)
        :disabled (input-disabled-p inp)
        :required (input-required-p inp)
        :focusable (input-focusable-p inp)
        :on-change (input-on-change inp)
        :on-focus (input-on-focus inp)
        :on-blur (input-on-blur inp)))

;;; ---------------------------------------------------------------
;;; Textarea
;;; ---------------------------------------------------------------
(defmethod to-dsl ((txta textarea-element))
  (list :textarea
        :id (element-id txta)
        :value (textarea-value txta)
        :placeholder (textarea-placeholder txta)
        :rows (textarea-rows txta)
        :cols (textarea-cols txta)
        :disabled (textarea-disabled-p txta)
        :required (textarea-required-p txta)
        :focusable (textarea-focusable-p txta)
        :on-change (textarea-on-change txta)
        :on-focus (textarea-on-focus txta)
        :on-blur (textarea-on-blur txta)))

;;; ---------------------------------------------------------------
;;; Select
;;; ---------------------------------------------------------------
(defmethod to-dsl ((sel select-element))
  (list :select
        :id (element-id sel)
        :value (select-value sel)
        :options (mapcar #'to-dsl (select-options sel))
        :multiple (select-multiple-p sel)
        :disabled (select-disabled-p sel)
        :focusable (select-focusable-p sel)
        :on-change (select-on-change sel)))

;;; ---------------------------------------------------------------
;;; Checkbox
;;; ---------------------------------------------------------------
(defmethod to-dsl ((chk checkbox-element))
  (list :checkbox
        :id (element-id chk)
        :checked (checkbox-checked-p chk)
        :label (checkbox-label chk)
        :disabled (checkbox-disabled-p chk)
        :focusable (checkbox-focusable-p chk)
        :on-change (checkbox-on-change chk)))

;;; ---------------------------------------------------------------
;;; Radio
;;; ---------------------------------------------------------------
(defmethod to-dsl ((rad radio-element))
  (list :radio
        :id (element-id rad)
        :name (radio-name rad)
        :value (radio-value rad)
        :checked (radio-checked-p rad)
        :label (radio-label rad)
        :disabled (radio-disabled-p rad)
        :focusable (radio-focusable-p rad)
        :on-change (radio-on-change rad)))

;;; ---------------------------------------------------------------
;;; Image
;;; ---------------------------------------------------------------
(defmethod to-dsl ((img image-element))
  (list :image
        :id (element-id img)
        :src (image-src img)
        :alt (image-alt img)
        :width (image-width img)
        :height (image-height img)))

;;; ---------------------------------------------------------------
;;; Link
;;; ---------------------------------------------------------------
(defmethod to-dsl ((lnk link-element))
  (list :link
        :id (element-id lnk)
        :href (link-href lnk)
        :content (link-content lnk)
        :target (link-target lnk)
        :on-click (link-on-click lnk)))

;;; ---------------------------------------------------------------
;;; List
;;; ---------------------------------------------------------------
(defmethod to-dsl ((lst list-element))
  (list :list
        :id (element-id lst)
        :items (mapcar #'to-dsl (list-items lst))
        :ordered (list-ordered-p lst)
        :item-style (convert-style-plist-to-dsl (list-item-style lst))))

;;; ---------------------------------------------------------------
;;; Table
;;; ---------------------------------------------------------------
(defmethod to-dsl ((tbl table-element))
  (list :table
        :id (element-id tbl)
        :headers (mapcar #'to-dsl (table-headers tbl))
        :rows (mapcar #'to-dsl (table-rows tbl))
        :border (table-border-p tbl)
        :cell-padding (table-cell-padding tbl)))
;;; == elmtui/view/layout/element-utils.lisp ==
;;; Utilities: element layout accessors, rect comparators, and layout wrappers.



(defparameter *layout-fallback-root-size*
  ;; sensible default for headless calls (e.g., tests / tree-transforms)
  (make-size :w 80 :h 24)
  "Used when no parent rectangle or styled width/height can be inferred.")

(defun rect= (a b &key (epsilon 0))
  (and (typep a 'rectangle) (typep b 'rectangle)
       (<= (abs (- (x a) (x b))) epsilon)
       (<= (abs (- (y a) (y b))) epsilon)
       (<= (abs (- (w a) (w b))) epsilon)
       (<= (abs (- (h a) (h b))) epsilon)))

(defun element-layout (node)
  (error "element-layout: not implemented for ~S" node)
  (element-layout-rect node))

(defun set-element-layout (node rect)
  (error "element-layout: not implemented for ~S ~S" node rect)
  ;; (setf (element-layout-rect node) rect)
  )

(defun %num-or-nil (v)
  (and (numberp v) (>= v 0) v))

(defun infer-parent-rect (node maybe-rect)
  "Best-effort: prefer MAYBE-RECT; else node’s current :layout-rect;
   else styled :width/:height; else *layout-fallback-root-size*."
  (cond
    ;; 1) explicit rect provided
    ((typep maybe-rect 'rectangle) maybe-rect)
    ;; 2) node already carries a rect (e.g., earlier pass)
    ((typep (element-layout-rect node) 'rectangle)
     (element-layout-rect node))
    ((typep (getf (ui-node-props node) :layout-rect) 'rectangle)
     (getf (ui-node-props node) :layout-rect))
    ;; 3) styled absolute width/height (numbers only) → make a parent rect at (0,0)
    (t
     (let* ((w* (%num-or-nil (getf (element-style node) :width nil)))
            (h* (%num-or-nil (getf (element-style node) :height nil)))
            (sz (cond
                  ((and w* h*) (make-size :w w* :h h*))
                  (t *layout-fallback-root-size*))))
       (elmtui.view.geo:make-rectangle :pos (make-pos :x 0 :y 0) :size sz)))))

;; (defun compute-layout (node &optional parent-rect parent-style-set)
;;   "Layout NODE inside PARENT-RECT if provided, otherwise infer a reasonable parent.
;; Returns the final layout rectangle."

;;   (let* ((parent (infer-parent-rect node parent-rect))
;;          (laid   (layout-node node parent parent-style-set))
;;          (rect   (element-layout-rect laid)))
;;     (unless (typep rect 'rectangle)
;;       (error "compute-layout: node did not produce a rectangle: ~S" laid))
;;     rect))

(defun compute-layout (node &optional parent-rect parent-style-set)
  "Idempotent layout: if the resulting rect matches, return NODE; else return LAID."

  (let* ((parent (infer-parent-rect node parent-rect))
         (before (element-layout-rect node))
         (laid   (layout-node node parent parent-style-set))
         (after  (element-layout-rect laid)))
    (if (and (typep before 'rectangle) (rect= before after))
        node
        laid)))

;; (defmethod ui-node-type ((node elmtui.view.base-elements:base-element))
;;   (class-name (class-of node)))

;; (defmethod ui-node-props ((node elmtui.view.base-elements:base-element))
;;   (list :id (elmtui.view.base-elements:element-id node)
;;         :style (elmtui.view.base-elements:element-style node)))

;; (defmethod ui-node-children ((node elmtui.view.base-elements:base-element))
;;   (elmtui.view.base-elements:element-children node))
(defmethod copy-element ((node base-element))
  "Create a shallow copy of NODE, preserving its type and properties."
  (let ((new-node (make-instance (class-of node))))
    (setf (element-id new-node) (element-id node))
    (setf (element-classes new-node) (element-classes node))
    (setf (element-style new-node) (copy-list (element-style node)))
    (setf (element-children new-node) (copy-list (element-children node)))
    (setf (element-layout-rect new-node) (when (element-layout-rect node)
                                           (elmtui.view.geo:make-rectangle
                                            :pos (make-pos :x (x (element-layout-rect node))
                                                           :y (y (element-layout-rect node)))
                                            :size (make-size :w (w (element-layout-rect node))
                                                             :h (h (element-layout-rect node))))))
    new-node))
