;;; ─── elmtui.style-lib/properties.lisp ─────────────────────────────────────────
(uiop:define-package :elmtui.style-lib.properties (:use :common-lisp)
                     (:nicknames :styles.styleprops :styles.properties)
                     (:import-from :str :split :upcase)
                     (:import-from :elmtui.style-lib.api :make-style :value
                      :property :property-value :property-name :valid-value-p
                      :style-property-value
                                   :apply-after :stylegroup-p :tuple-value :stylable :style-sub-styles :style-group :stylable-id :classes
                                   :style-property-value :style-property-definition-default-value
                                   ;; elmtui.style-lib.properties::parse-property-value
                                   :style-property-value-raw-value)
                     (:import-from :elmtui.style-lib.macros :defstyle :defstylegroup)
                     ;; (:import-from :elmtui.style-lib.stylable
                     ;;   :style-sub-styles :style-group :stylable-id :classes)
                     (:import-from :elmtui.style-lib.util :*pad-fill-char*
                                   :*margin-fill-char*)
                     (:import-from :elmtui.style-lib.util :keyword-split)
                     (:import-from :elmtui.utils :hex-str-to-rgb)
                     (:import-from :elmtui.style-lib.selector :type> :cls> :id> :and> :cl-cls)
                     (:export :is-color :defstyle2 :or-concat-lambda :defstyle :defstylegroup
                      :padding-top :padding-left :padding-right :padding-bottom :padding-char
                              :margin-top :margin-left :margin-right :margin-bottom :margin-char
                      :box :align :valign :width :height :visible :scrollbar-h :scrollbar-v
                      :flex-direction :flex-wrap :flex-grow :flex-shrink :flex-basis
                              :bold :italic :underline :faint :blink :inverse :strike :fg-color :bg-color
                              ;; Border properties
                      :border-style :border-color
                      :border-top-width :border-right-width :border-bottom-width :border-left-width
                      :border-width ;; Shorthand
                      ;; Grid properties
                              :grid-template-columns :grid-template-rows :grid-template-areas
                      :grid-auto-columns :grid-auto-rows :grid-auto-flow
                              :grid-column-gap :grid-row-gap :grid-gap
                      :grid-column-start :grid-column-end :grid-row-start :grid-row-end
                      :grid-column :grid-row :grid-area
                              :*inheritable-style-properties* ; Export the new global
                              ))
(in-package :elmtui.style-lib.properties)

(defun valid-color-value-p (v)
  "Checks if v is a valid color representation: keyword, 256-int, or list like (:simple :red) or (:rgb r g b)."
  (or (keywordp v)
      (integerp v) ; Assuming 256 color index
      (and (consp v)
           (keywordp (first v))
           (case (first v)
             (:simple (keywordp (second v)))
             (:rgb (and (= (length (rest v)) 3) (every #'integerp (rest v))))
             (:color-256 (integerp (second v)))
             (t nil)))
      (and (stringp v) ;; match #abcdef or abcdef
           (or (and (char= (char v 0) #\#) (= (length v) 7)) ; Hex color))))
               (and (= (length v) 6)))
           (hex-str-to-rgb v)))) ; Named color or simple string

(defparameter *inheritable-style-properties*
  '(:fg-color :attributes :font-family :font-size :text-align) ; Add more as they become relevant
  "A list of style property keywords that are inheritable by default.")

(defmethod style-default ((style t) (property-name t))
  "Return the default value for a style property."
  (let ((default-value (style-property-definition-default-value property-name)))
    (if (null default-value)
        (error "No default value defined for property: ~A" property-name)
        default-value)))





(defmethod parse-property-value ((definition property) value)
  "Parse and validate a value according to a property definition."
  (if (valid-value-p definition value)
      (make-instance 'value :value value)
      (error "Invalid value ~S for property ~A" value (property-name definition))))

(defmethod parse-property-value ((definition null) value)
  "Handle case where definition is nil."
  value)

(defun is-color (color-spec)
  "Check if the given color-spec is a valid color representation.
   Can be:
   - a keyword (e.g., :red, :bright-blue)
   - an integer (0-255 for XTerm 256 colors)
   - a list of 3 integers (R G B), each 0-255."
  (typecase color-spec
    (keyword
     (member color-spec
             '(:black :red :green :yellow :blue :magenta :cyan :white :default
               :bright-black :bright-red :bright-green :bright-yellow
               :bright-blue :bright-magenta :bright-cyan :bright-white)))
    (integer
     (and (>= color-spec 0) (<= color-spec 255)))
    (list
     (and (consp color-spec) ; Ensure it's a proper list, not nil
          (= 3 (length color-spec))
          (every (lambda (x) (and (integerp x) (>= x 0) (<= x 255))) color-spec)))
    (t nil))) ; Not a valid color spec type
;; (defmacro defstyle2 (name type &rest options &key (category :decoration) (related-styles '()))
;;   "Define a style with category and related styles.
;; NAME: The style name.
;; TYPE: The type specification.
;; CATEGORY: One of :layout, :content, :decoration, or :behavior.
;; RELATED-STYLES: List of related style names.
;; OPTIONS: Additional options passed to defstyle."
;;   `(progn
;;      (defstyle ,name ,type ,@options)
;;      (setf (get ',name 'style-metadata)
;;            (make-instance 'style-metadata
;;                           :category ,category
;;                           :related-styles ',related-styles))))

(defun or-concat-lambda (&rest args)
  "Return a lambda that checks if the value is one of the given types.
ARGS: A list of types.
Returns a lambda that tests the value."
  (let ((testfn
          (lambda (x)
            (lambda (value)
              (typecase x
                (list (member value x))
                (symbol (typep value x))
                (function (funcall x value))
                (t (error "Invalid value specifier: ~A" x)))))))
    (lambda (x)
      (loop for arg in args
            thereis (funcall (funcall testfn arg) x)))))

;;;-----------------------------------------------------------------------------
;;; Grid Property Validation Helpers
;;;-----------------------------------------------------------------------------

(defun is-track-size (value)
  "Validate a single grid track size.
Can be an integer (fixed), keyword (:auto, :min-content, :max-content),
cons (:fr <number>), or list (:minmax <min-track-size> <max-track-size>)."
  (or (integerp value)
      (member value '(:auto :min-content :max-content) :test #'eq)
      (and (consp value)
           (eq (car value) :fr)
           (consp (cdr value))
           (integerp (cadr value))
           (null (cddr value)))
      (and (listp value)
           (eq (car value) :minmax)
           (consp (cdr value))
           (is-track-size (cadr value)) ; min
           (consp (cddr value))
           (is-track-size (caddr value)) ; max
           (null (cdddr value)))))

(defun is-track-size-list (value)
  "Validate a list of grid track sizes."
  (and (listp value)
       (every #'is-track-size value)))

(defun is-grid-line-value (value)
  "Validate a grid line position (integer, :auto, string for named line, or :span <n>)."
  (or (integerp value)
      (eq value :auto)
      (stringp value) ; named line
      (and (consp value)
           (eq (car value) :span)
           (consp (cdr value))
           (integerp (cadr value))
           (null (cddr value)))))

(defun is-grid-template-areas-value (value)
  "Validate grid-template-areas value (list of strings or nil)."
  (or (null value)
      (and (listp value)
           (every #'stringp value))))

(defun is-grid-gap-value (value)
  "Validate grid-gap value (integer or list of one or two integers)."
  (or (and (integerp value) (>= value 0))
      (and (listp value)
           (<= 1 (length value) 2)
           (every #'(lambda (x) (and (integerp x) (>= x 0))) value))))

(defun is-grid-area-value (value)
  "Validate grid-area value (string for named area, or list of 1 to 4 grid-line-values)."
  (or (stringp value)
      (and (listp value)
           (<= 1 (length value) 4)
           (every #'is-grid-line-value value))))

(defstyle :box (list :none :single :double :ascii :full-block) :default :none
  :docstring "The box style to use for the element." :decorating-after :padding)

(defstyle :align (list :left :right :center))
(defstyle :valign (list :top :middle :bottom))

;; (defstyle :width (or-concat-lambda 'integer (list :min :max))) ; Original
(defstyle :width '(or integer (member :auto :min-content :max-content :fill)) :default :auto ; Added :fill
  :docstring "Specifies the width of an element.")
;; (defstyle :height (or-concat-lambda 'integer (list :min :max))) ; Original
(defstyle :height '(or integer (member :auto :min-content :max-content :fill)) :default :auto ; Added :fill
  :docstring "Specifies the height of an element.")

;; Add missing constraint properties
(defstyle :min-width '(or integer (eql :auto)) :default :auto ; Allow :auto or integer
  :docstring "Minimum width constraint.")
(defstyle :max-width '(or integer (eql :none)) :default :none ; Allow :none or integer
  :docstring "Maximum width constraint.")
(defstyle :min-height '(or integer (eql :auto)) :default :auto
  :docstring "Minimum height constraint.")
(defstyle :max-height '(or integer (eql :none)) :default :none
  :docstring "Maximum height constraint.")


(defstyle :visible 'boolean :default t :docstring "Whether the element is visible or not.")

(defstyle :scrollbar-h (list t nil :auto) :default :auto :docstring
  "Show horizontal scrollbar: t (always), nil (never), or :auto (when needed)")

(defstyle :scrollbar-v (list t nil :auto) :default :auto :docstring
  "Show vertical scrollbar: t (always), nil (never), or :auto (when needed)")

;; Add :display property
(defstyle :display (list :block :inline :flex :grid :none) :default :block
  :docstring "Specifies the display behavior (layout model) of an element.")

;; Remove or comment out :layout if :display is preferred
;; (defstyle :layout (list :default :stack :row :column :flex)) ; Deprecated?
(defstyle :flex-direction (list :row :row-reverse :column :column-reverse))
(defstyle :flex-wrap (list :nowrap :wrap :wrap-reverse))
(defstyle :flex-grow 'integer :default 0) ; Should allow real numbers? CSS allows floats. Let's keep integer for TUI simplicity for now.
(defstyle :flex-shrink 'integer :default 1) ; Should allow real numbers? CSS allows floats. Let's keep integer for TUI simplicity for now.
;; (defstyle :flex-basis (or-concat-lambda 'integer (list :auto))) ; Original
(defstyle :flex-basis '(or integer (member :auto :content :min-content :max-content)) :default :auto ; Allow keywords
  :docstring "Specifies the initial main size of a flex item.")

;; Add missing flex container properties
(defstyle :justify-content (list :flex-start :flex-end :center :space-between :space-around :space-evenly) :default :flex-start
  :docstring "Aligns flex items along the main axis.")
(defstyle :align-items (list :stretch :flex-start :flex-end :center :baseline) :default :stretch ; Removed :auto, handled internally
  :docstring "Default alignment for items along the cross axis.")
(defstyle :align-content (list :stretch :flex-start :flex-end :center :space-between :space-around :space-evenly) :default :stretch
  :docstring "Aligns flex lines when there is extra space in the cross axis.")

;; Add missing flex item properties
(defstyle :order 'integer :default 0
  :docstring "Specifies the order of a flex item relative to the rest.")
(defstyle :align-self (list :auto :stretch :flex-start :flex-end :center :baseline) :default :auto
  :docstring "Overrides the default alignment (align-items) for a single flex item.")


(defstyle :bold 'boolean)
(defstyle :italic 'boolean)
(defstyle :underline 'boolean)
(defstyle :faint 'boolean)
(defstyle :blink 'boolean)
(defstyle :inverse 'boolean)
(defstyle :strike 'boolean)
(defstyle :fg-color #'is-color)
(defstyle :bg-color #'is-color)

;; Border Styles
(defstyle :border-style '(member :none :single :double :ascii) :default :none
  :docstring "The style of the border (e.g., :none, :single, :double, :ascii).")
(defstyle :border-color #'is-color :default nil ; Default to nil (transparent or use fg-color)
  :docstring "The color of the border. Defaults to the element's foreground color if not set.")

(defstyle :border-top-width 'integer :default 0 :docstring "Width of the top border.")
(defstyle :border-right-width 'integer :default 0 :docstring "Width of the right border.")
(defstyle :border-bottom-width 'integer :default 0 :docstring "Width of the bottom border.")
(defstyle :border-left-width 'integer :default 0 :docstring "Width of the left border.")

;; Shorthand for border-width (can be a single integer or a list of 1-4 integers)
;; For now, we'll just define it. The style system or layout engine would need to expand this.
;; We'll primarily use the individual side widths in layout/rendering for now.
(defstyle :border-width '(or integer list) :default 0
  :docstring "Shorthand for border widths. Integer for all sides, or list for TRBL.")
;; TODO: Implement defstylegroup for :border if complex shorthand parsing is needed,
;; similar to :padding or :margin, or handle expansion in style application/querying.

(defstyle :padding-top 'integer :default 0 :docstring "Padding above the element.")
(defstyle :padding-left 'integer :default 0 :docstring "Padding to the left of the element.")
(defstyle :padding-right 'integer :default 0 :docstring "Padding to the right of the element.")
(defstyle :padding-bottom 'integer :default 0 :docstring "Padding below the element.")
(defstyle :padding-char 'character :default *pad-fill-char* :docstring "Padding fill character.")
(defstyle :padding-charstyle 'list :default nil :docstring "Padding character style.")

(defstylegroup (:groups
                (:padding-top :padding-bottom :padding-left :padding-right :padding-char :padding-charstyle)
                :decorating-after :top
                :docstring "Group for padding styles.")
  ;; The `value` here is the shorthand value passed to (make-style :padding <value>)
  (let ((processed-value value)
        (sub-styles-list '()))

    ;; 1. Normalize input `value`
    (when (null processed-value) (setf processed-value 0))

    (if (integerp processed-value)
        (setf processed-value (list processed-value)))

    ;; Handle potential single-element list nesting e.g. :padding '((1 2)) -> '(1 2)
    ;; This applies only if the inner list is entirely numeric.
    (when (and (listp processed-value)
               (= 1 (length processed-value))
               (listp (first processed-value))
               (every #'integerp (first processed-value)))
      (setf processed-value (first processed-value)))

    ;; 2. Process if `processed-value` is a list of solely integers (valid numeric shorthand)
    (if (and (listp processed-value) (every #'integerp processed-value))
        (progn
          (case (length processed-value)
            (1 (let ((val (first processed-value)))
                 (push (make-style :padding-top val) sub-styles-list)
                 (push (make-style :padding-bottom val) sub-styles-list)
                 (push (make-style :padding-left val) sub-styles-list)
                 (push (make-style :padding-right val) sub-styles-list)))
            (2 (let ((v-val (first processed-value))
                     (h-val (second processed-value)))
                 (push (make-style :padding-top v-val) sub-styles-list)
                 (push (make-style :padding-bottom v-val) sub-styles-list)
                 (push (make-style :padding-left h-val) sub-styles-list)
                 (push (make-style :padding-right h-val) sub-styles-list)))
            (3 (let ((top (first processed-value))
                     (h-val (second processed-value))
                     (bottom (third processed-value)))
                 (push (make-style :padding-top top) sub-styles-list)
                 (push (make-style :padding-left h-val) sub-styles-list)
                 (push (make-style :padding-right h-val) sub-styles-list)
                 (push (make-style :padding-bottom bottom) sub-styles-list)))
            (4 (let ((top (first processed-value))
                     (right (second processed-value))
                     (bottom (third processed-value))
                     (left (fourth processed-value)))
                 (push (make-style :padding-top top) sub-styles-list)
                 (push (make-style :padding-right right) sub-styles-list)
                 (push (make-style :padding-bottom bottom) sub-styles-list)
                 (push (make-style :padding-left left) sub-styles-list)))
            (t
             ;; Not a valid number of arguments (0 or >4 integers) for numeric shorthand.
             ;; Return nil, which causes defstylegroup to signal illegal-group-value.
             nil))

          ;; Add default char and charstyle for numeric shorthand
          (push (make-style :padding-char *pad-fill-char*) sub-styles-list)
          (push (make-style :padding-charstyle nil) sub-styles-list)
          (nreverse sub-styles-list)) ; Return the list of created style objects
        ;; Not a list of solely integers, so not a valid numeric shorthand.
        ;; Return nil to signal illegal-group-value.
        nil)))

(defstyle :margin-top 'integer
  :default 0 :docstring "Margin above the element.")
(defstyle :margin-left 'integer
  :default 0 :docstring "Margin to the left of the element.")
(defstyle :margin-right 'integer
  :default 0 :docstring "Margin to the right of the element.")
(defstyle :margin-bottom 'integer
  :default 0 :docstring "Margin below the element.")
(defstyle :margin-char 'character
  :default *margin-fill-char* :docstring "Margin fill character.")
(defstyle :margin-charstyle 'list
  :default nil :docstring "Margin character style.")

(defstylegroup (:groups
                (:margin-top :margin-bottom :margin-left :margin-right :margin-char :margin-charstyle)
                :decorating-after :box
                :docstring "Group for margin styles.")
  ;; The `value` here is the shorthand value passed to (make-style :margin <value>)
  (let ((processed-value value)
        (sub-styles-list '()))

    ;; 1. Normalize input `value`
    (when (null processed-value) (setf processed-value 0))

    (if (integerp processed-value)
        (setf processed-value (list processed-value)))

    ;; Handle potential single-element list nesting e.g. :margin '((1 2)) -> '(1 2)
    (when (and (listp processed-value)
               (= 1 (length processed-value))
               (listp (first processed-value))
               (every #'integerp (first processed-value)))
      (setf processed-value (first processed-value)))

    ;; 2. Process if `processed-value` is a list of solely integers (valid numeric shorthand)
    (if (and (listp processed-value) (every #'integerp processed-value))
        (progn
          (case (length processed-value)
            (1 (let ((val (first processed-value)))
                 (push (make-style :margin-top val) sub-styles-list)
                 (push (make-style :margin-bottom val) sub-styles-list)
                 (push (make-style :margin-left val) sub-styles-list)
                 (push (make-style :margin-right val) sub-styles-list)))
            (2 (let ((v-val (first processed-value))
                     (h-val (second processed-value)))
                 (push (make-style :margin-top v-val) sub-styles-list)
                 (push (make-style :margin-bottom v-val) sub-styles-list)
                 (push (make-style :margin-left h-val) sub-styles-list)
                 (push (make-style :margin-right h-val) sub-styles-list)))
            (3 (let ((top (first processed-value))
                     (h-val (second processed-value))
                     (bottom (third processed-value)))
                 (push (make-style :margin-top top) sub-styles-list)
                 (push (make-style :margin-left h-val) sub-styles-list)
                 (push (make-style :margin-right h-val) sub-styles-list)
                 (push (make-style :margin-bottom bottom) sub-styles-list)))
            (4 (let ((top (first processed-value))
                     (right (second processed-value))
                     (bottom (third processed-value))
                     (left (fourth processed-value)))
                 (push (make-style :margin-top top) sub-styles-list)
                 (push (make-style :margin-right right) sub-styles-list)
                 (push (make-style :margin-bottom bottom) sub-styles-list)
                 (push (make-style :margin-left left) sub-styles-list)))
            (t
             nil)) ; Signal illegal-group-value

          ;; Add default char and charstyle for numeric shorthand
          (push (make-style :margin-char *margin-fill-char*) sub-styles-list)
          (push (make-style :margin-charstyle nil) sub-styles-list)
          (nreverse sub-styles-list))
        nil)))

;;;-----------------------------------------------------------------------------
;;; Grid Style Properties
;;;-----------------------------------------------------------------------------

;; Grid Container Properties
(defstyle :grid-template-columns #'is-track-size-list :default '(:auto)
  :docstring "Defines the track sizing functions and line names of the grid columns.")

(defstyle :grid-template-rows #'is-track-size-list :default '(:auto)
  :docstring "Defines the track sizing functions and line names of the grid rows.")

(defstyle :grid-template-areas #'is-grid-template-areas-value :default nil
  :docstring "Specifies named grid areas. E.g., '(\"header header\" \"main sidebar\" \"footer footer\")'.")

(defstyle :grid-auto-columns #'is-track-size :default :auto
  :docstring "Specifies the size of implicitly created grid columns.")

(defstyle :grid-auto-rows #'is-track-size :default :auto
  :docstring "Specifies the size of implicitly created grid rows.")

(defstyle :grid-auto-flow (list :row :column :row-dense :column-dense) :default :row
  :docstring "Controls how auto-placed items get flowed into the grid.")

(defstyle :grid-column-gap '(integer 0 *) :default 0
  :docstring "Specifies the size of the gap between grid columns.")

(defstyle :grid-row-gap '(integer 0 *) :default 0
  :docstring "Specifies the size of the gap between grid rows.")

(defstylegroup (:groups (:grid-row-gap :grid-column-gap)
                :docstring "Shorthand for grid-row-gap and grid-column-gap.")
  ;; Value can be a single integer (applies to both row and column gaps)
  ;; or a list of two integers (row-gap column-gap).
  (let ((row-gap-val value)
        (col-gap-val value))
    (when (listp value)
      (setf row-gap-val (first value))
      (setf col-gap-val (if (second value) (second value) (first value))))
    (list (make-style :grid-row-gap row-gap-val)
          (make-style :grid-column-gap col-gap-val))))


;; Grid Item Properties
(defstyle :grid-column-start #'is-grid-line-value :default :auto
  :docstring "Specifies the starting grid line for a grid item's column.")

(defstyle :grid-column-end #'is-grid-line-value :default :auto
  :docstring "Specifies the ending grid line for a grid item's column.")

(defstyle :grid-row-start #'is-grid-line-value :default :auto
  :docstring "Specifies the starting grid line for a grid item's row.")

(defstyle :grid-row-end #'is-grid-line-value :default :auto
  :docstring "Specifies the ending grid line for a grid item's row.")

(defstylegroup (:groups (:grid-column-start :grid-column-end)
                :docstring "Shorthand for grid-column-start and grid-column-end.")
  ;; Value can be a single grid-line-value (start, end is auto or span 1)
  ;; or a list of two grid-line-values (start end).
  (let ((start-val value)
        (end-val :auto))
    (when (listp value)
      (setf start-val (first value))
      (setf end-val (if (second value) (second value) :auto)))
    (list (make-style :grid-column-start start-val)
          (make-style :grid-column-end end-val))))

(defstylegroup (:groups (:grid-row-start :grid-row-end)
                :docstring "Shorthand for grid-row-start and grid-row-end.")
  (let ((start-val value)
        (end-val :auto))
    (when (listp value)
      (setf start-val (first value))
      (setf end-val (if (second value) (second value) :auto)))
    (list (make-style :grid-row-start start-val)
          (make-style :grid-row-end end-val))))

(defstyle :grid-area #'is-grid-area-value :default nil
  :docstring "Shorthand for grid-row-start, grid-column-start, grid-row-end, and grid-column-end. Can also be a string to assign to a named grid area.")

;; End of properties.lisp

;;; This file is for defining style sets and their properties. ;;; It uses macros and property types defined in macros.lisp and properties.lisp.
(defmacro def-style-property (name type &optional default-value docstring)
  "Define a style property with NAME, TYPE, and optional DEFAULT-VALUE and DOCSTRING."
  `(progn
     (defstyle ,name ,type :default ,default-value :docstring ,docstring)
     (setf (get ',name 'style-property-metadata)
           (make-instance 'style-property-metadata
                          :type ',type
                          :default-value ',default-value
                          :docstring ,docstring))))
(defvar *known-properties*
  '(:align-content :align-items :align-self :all
    ;; TODO: Implement 'all' property correctly
    :background-color :border
    ;; TODO: Shorthand, needs parsing and expansion :border-bottom-color
    :border-bottom-left-radius :border-bottom-right-radius :border-bottom-style :border-bottom-width :border-collapse
    ;; TODO
    :border-color ;; Shorthand :border-left-color :border-left-style :border-left-width :border-radius
    ;; Shorthand :border-right-color :border-right-style :border-right-width :border-style :border-top-color
    ;; :border-top-left-radius :border-top-right-radius :border-top-style :border-top-width :border-width
    ;; ;; Shorthand :bottom :box-shadow ;; TODO: Complex property :box-sizing :clear
    ;; ;; TODO :color :cursor
    ;; ;; TODO :display :flex :flex-basis :flex-direction :flex-flow
    ;; ;; Shorthand :flex-grow :flex-shrink :flex-wrap :float
    ;; ;; TODO :font-family :font-size :font-style :font-variant
    ;; ;; TODO :font-weight :gap
    ;; ;; Shorthand for row-gap and column-gap :column-gap :row-gap :grid
    ;; ;; TODO: Shorthand :grid-area
    ;; ;; TODO: Shorthand :grid-auto-columns
    ;; ;; TODO :grid-auto-flow
    ;; ;; TODO :grid-auto-rows
    ;; ;; TODO :grid-column
    ;; ;; TODO: Shorthand :grid-column-end
    ;; ;; TODO :grid-column-gap
    ;; ;; TODO - deprecated, use column-gap :grid-column-start
    ;; ;; TODO :grid-gap
    ;; ;; TODO - deprecated, use gap :grid-row
    ;; ;; TODO: Shorthand :grid-row-end
    ;; ;; TODO :grid-row-gap
    ;; ;; TODO - deprecated, use row-gap :grid-row-start
    ;; ;; TODO :grid-template
    ;; ;; TODO: Shorthand :grid-template-areas
    ;; ;; TODO :grid-template-columns
    ;; ;; TODO :grid-template-rows
    ;; ;; TODO :height :justify-content :justify-items
    ;; ;; TODO :justify-self
    ;; ;; TODO :left :letter-spacing
    ;; ;; TODO :line-height
    ;; ;; TODO :list-style
    ;; ;; TODO: Shorthand :list-style-image
    ;; ;; TODO :list-style-position
    ;; ;; TODO :list-style-type
    ;; ;; TODO :margin ;; Shorthand :margin-bottom :margin-left :margin-right :margin-top :max-height :max-width :min-height :min-width :object-fit
    ;; ;; TODO :object-position
    ;; ;; TODO :opacity :order :outline
    ;; ;; TODO: Shorthand :outline-color
    ;; ;; TODO :outline-offset
    ;; ;; TODO :outline-style
    ;; ;; TODO :outline-width
    ;; ;; TODO :overflow :overflow-wrap
    ;; ;; TODO :overflow-x :overflow-y :padding
    ;; ;; Shorthand :padding-bottom :padding-left :padding-right :padding-top :pointer-events
    ;; ;; TODO :position :resize
    ;; ;; TODO :right :text-align :text-decoration
    ;; ;; TODO: Shorthand (text-decoration-line, text-decoration-color, text-decoration-style) :text-decoration-color
    ;; ;; TODO :text-decoration-line
    ;; ;; TODO :text-decoration-style
    ;; ;; TODO :text-overflow
    ;; ;; TODO :text-shadow
    ;; ;; TODO :text-transform
    ;; ;; TODO :top :transform
    ;; ;; TODO: Complex property (functions like translate(), rotate(), scale()) :transform-origin
    ;; ;; TODO :transition
    ;; ;; TODO: Shorthand :transition-delay
    ;; ;; TODO :transition-duration
    ;; ;; TODO :transition-property
    ;; ;; TODO :transition-timing-function
    ;; ;; TODO :user-select
    ;; ;; TODO :vertical-align
    ;; ;; TODO :visibility :white-space
    ;; ;; TODO :width :word-break
    ;; ;; TODO :word-spacing
    ;; ;; TODO :word-wrap
    ;; ;; TODO (alias for overflow-wrap) :writing-mode
    ;; ;; TODO :z-index) "A list of all known style properties. Used for validation and introspection.")

    ;; Define default values and types for each property
    ;; ;; Order roughly follows common CSS property orderings (Box Model, Typography, Visual, etc.)

    ;; Display and Position
    (def-style-property :display (keyword-choice :flex :grid :block :inline :inline-block :none) :block "Specifies the display behavior of an element.")
    (def-style-property :position (keyword-choice :static :relative :absolute :fixed :sticky) :static "Specifies the type of positioning method used for an element.")
    (def-style-property :top 'length-percentage-auto nil "Specifies the top position of a positioned element.")
    (def-style-property :right 'length-percentage-auto nil "Specifies the right position of a positioned element.")
    (def-style-property :bottom 'length-percentage-auto nil "Specifies the bottom position of a positioned element.")
    (def-style-property :left 'length-percentage-auto nil "Specifies the left position of a positioned element.")
    (def-style-property :z-index 'integer-auto :auto "Specifies the stack order of a positioned element.")
    (def-style-property :overflow (keyword-choice :visible :hidden :scroll :auto) :visible "Specifies how content that overflows the element's box is handled.")
    (def-style-property :overflow-x (keyword-choice :visible :hidden :scroll :auto) :visible "Specifies how content that overflows the element's box horizontally is handled.")
    (def-style-property :overflow-y (keyword-choice :visible :hidden :scroll :auto) :visible "Specifies how content that overflows the element's box vertically is handled.")

    ;; Box Model - Dimensions
    (def-style-property :width 'length-percentage-auto :auto "Specifies the width of an element.")
    (def-style-property :height 'length-percentage-auto :auto "Specifies the height of an element.")
    (def-style-property :min-width 'length-percentage-auto :auto "Specifies the minimum width of an element.")
    (def-style-property :min-height 'length-percentage-auto :auto "Specifies the minimum height of an element.")
    (def-style-property :max-width 'length-percentage-none :none "Specifies the maximum width of an element.")
    (def-style-property :max-height 'length-percentage-none :none "Specifies the maximum height of an element.")

    ;; Box Model - Margin (shorthand and individual)
    (def-style-property :margin 'margin-shorthand nil "Shorthand for setting all margin properties. If nil, individual margin properties are used.")
    (def-style-property :margin-top 'length-percentage-auto :auto "Specifies the top margin of an element.")
    (def-style-property :margin-right 'length-percentage-auto :auto "Specifies the right margin of an element.")
    (def-style-property :margin-bottom 'length-percentage-auto :auto "Specifies the bottom margin of an element.")
    (def-style-property :margin-left 'length-percentage-auto :auto "Specifies the left margin of an element.")

    ;; Box Model - Padding (shorthand and individual)
    (def-style-property :padding 'padding-shorthand nil "Shorthand for setting all padding properties. If nil, individual padding properties are used.")
    (def-style-property :padding-top 'length-percentage :0px "Specifies the top padding of an element.")
    (def-style-property :padding-right 'length-percentage :0px "Specifies the right padding of an element.")
    (def-style-property :padding-bottom 'length-percentage :0px "Specifies the bottom padding of an element.")
    (def-style-property :padding-left 'length-percentage :0px "Specifies the left padding of an element.")

    ;; Box Model - Border ;; TODO: :border shorthand property
    (def-style-property :border-color 'color nil "Shorthand for setting all border colors. If nil, individual border colors are used.")
    (def-style-property :border-top-color 'color nil "Specifies the color of the top border.")
    (def-style-property :border-right-color 'color nil "Specifies the color of the right border.")
    (def-style-property :border-bottom-color 'color nil "Specifies the color of the bottom border.")
    (def-style-property :border-left-color 'color nil "Specifies the color of the left border.")

    (def-style-property :border-width 'length nil "Shorthand for setting all border widths. If nil, individual border widths are used.")
    (def-style-property :border-top-width 'length :0px "Specifies the width of the top border.")
    (def-style-property :border-right-width 'length :0px "Specifies the width of the right border.")
    (def-style-property :border-bottom-width 'length :0px "Specifies the width of the bottom border.")
    (def-style-property :border-left-width 'length :0px "Specifies the width of the left border.")

    (def-style-property :border-style (keyword-choice :none :solid :dashed :dotted) :none "Specifies the style of all four borders.
Possible values are :none, :solid, :dashed, :dotted.")
    (def-style-property :border-top-style (keyword-choice :none :solid :dashed :dotted) :none "Specifies the style of the top border.")
    (def-style-property :border-right-style (keyword-choice :none :solid :dashed :dotted) :none "Specifies the style of the right border.")
    (def-style-property :border-bottom-style (keyword-choice :none :solid :dashed :dotted) :none "Specifies the style of the bottom border.")
    (def-style-property :border-left-style (keyword-choice :none :solid :dashed :dotted) :none "Specifies the style of the left border.")

    ;; TODO: border-radius shorthand and individual corners
    (def-style-property :border-radius 'length-percentage nil "Shorthand for setting all border radius properties. If nil, individual corner radii are used.")
    (def-style-property :border-top-left-radius 'length-percentage :0px "Specifies the radius of the top-left corner.")
    (def-style-property :border-top-right-radius 'length-percentage :0px "Specifies the radius of the top-right corner.")
    (def-style-property :border-bottom-left-radius 'length-percentage :0px "Specifies the radius of the bottom-left corner.")
    (def-style-property :border-bottom-right-radius 'length-percentage :0px "Specifies the radius of the bottom-right corner.")

    (def-style-property :box-sizing (keyword-choice :content-box :border-box) :content-box "Specifies how the width and height of an element are calculated: whether they include padding and borders, or not.")

    ;; Background
    (def-style-property :background-color 'color :transparent "Specifies the background color of an element.")

    ;; Typography
    (def-style-property :color 'color :black "Specifies the color of text.")
    (def-style-property :font-family 'string "Arial, sans-serif" "Specifies the font family for text.")
    (def-style-property :font-size 'length-percentage :16px "Specifies the size of the font.")
    (def-style-property :font-style (keyword-choice :normal :italic :oblique) :normal "Specifies the font style for text.")
    (def-style-property :font-weight (keyword-choice :normal :bold :bolder :lighter :100 :200 :300 :400 :500 :600 :700 :800 :900) :normal "Specifies the weight of a font.")
    (def-style-property :line-height 'normal-number-length-percentage :normal "Specifies the height of a line of text.")
    (def-style-property :text-align (keyword-choice :left :right :center :justify :start :end) :start "Specifies the horizontal alignment of text in an element.")
    (def-style-property :text-decoration 'string :none "Specifies the decoration added to text (e.g., underline, overline, line-through).")
    ;; TODO: text-decoration should be a more complex property (shorthand for line, color, style)
    (def-style-property :letter-spacing 'normal-length :normal "Specifies the spacing between characters in text.")
    (def-style-property :white-space (keyword-choice :normal :nowrap :pre :pre-wrap :pre-line :break-spaces) :normal "Specifies how white space inside an element is handled.")
    (def-style-property :word-spacing 'normal-length :normal "Specifies the spacing between words in text.")

    ;; Flexbox Layout
    (def-style-property :flex-direction (keyword-choice :row :row-reverse :column :column-reverse) :row "Specifies the direction of the main axis in a flex container.")
    (def-style-property :flex-wrap (keyword-choice :nowrap :wrap :wrap-reverse) :nowrap "Specifies whether flex items are forced onto one line or can wrap onto multiple lines.")
    (def-style-property :flex-flow 'flex-flow-shorthand nil "Shorthand for :flex-direction and :flex-wrap.")
    (def-style-property :justify-content (keyword-choice :flex-start :flex-end :center :space-between :space-around :space-evenly) :flex-start "Aligns flex items along the main axis of the current line of the flex container.")
    (def-style-property :align-items (keyword-choice :stretch :flex-start :flex-end :center :baseline) :stretch "Aligns flex items along the cross axis of the current line of the flex container.")
    (def-style-property :align-content (keyword-choice :stretch :flex-start :flex-end :center :space-between :space-around :space-evenly) :stretch "Aligns the lines of a flex container when there is extra space on the cross-axis.")
    (def-style-property :order 'integer 0 "Specifies the order of a flex item relative to the rest of the flex items inside the same container.")
    (def-style-property :flex-grow 'number 0 "Specifies how much a flex item will grow relative to the rest of the flex items.")
    (def-style-property :flex-shrink 'number 1 "Specifies how much a flex item will shrink relative to the rest of the flex items.")
    (def-style-property :flex-basis 'length-percentage-auto-content :auto "Specifies the initial main size of a flex item.")
    (def-style-property :flex 'flex-shorthand nil "Shorthand for :flex-grow, :flex-shrink, and :flex-basis.")
    (def-style-property :align-self (keyword-choice :auto :stretch :flex-start :flex-end :center :baseline) :auto "Overrides the :align-items value for individual flex items.")

    ;; Grid Layout ;; TODO: Grid properties
    (def-style-property :gap 'gap-shorthand nil "Shorthand for :row-gap and :column-gap.")
    (def-style-property :row-gap 'length-percentage :normal "Specifies the gap between grid rows.")
    (def-style-property :column-gap 'length-percentage :normal "Specifies the gap between grid columns.")

    ;; Visibility and Opacity
    (def-style-property :visibility (keyword-choice :visible :hidden :collapse) :visible "Specifies whether an element is visible or hidden.")
    (def-style-property :opacity 'number-percentage 1.0 "Specifies the opacity level for an element.")
    ))
;; Other ;; TODO: Add more properties as needed, e.g. cursor, user-select, transitions, transforms

;;; Style Set Definition
(defstruct style-set "Represents a collection of style properties and their values."
           (properties (make-hash-table :test 'eq) :type hash-table)
           (parent nil :type (or null style-set)))

;; (defun make-style-set (&key parent)
;;   "Creates a new style-set, optionally inheriting from a parent style-set."
;;   (make-style-set :properties (make-hash-table :test 'eq) :parent parent))

(defun %get-style-definition (property-name) (get property-name 'style-property-definition))

(defun get-style-property (style-set property-name &key (inherit t))
  "Retrieves the value of a style property from a style-set.
If the property is not found in the current style-set and 'inherit'
is true, it will look up the property in parent style-sets.
If not found anywhere, returns the default value for the property."
  (check-type property-name keyword)
  (unless (member property-name *known-properties*) (warn "Accessing unknown style property: ~S" property-name)) ;; Or
  ;; (error "Unknown style property: ~S" property-name) ;; Uncomment for stricter checking
  (let ((value (gethash property-name (style-set-properties style-set)))) ;; Check if the property is set locally
    (if (and (null value) inherit) ;; If not set locally, check parent style-set)
        (let ((parent (style-set-parent style-set))) ;; Check if parent exists)
          ;; If parent exists, recursively check parent style-set
          (if parent
              (get-style-property parent property-name :inherit t)
              nil) ;; If no parent, return nil)
          ;; If property is set locally, return its value
          ;; (if value
          ;;     (style-property-value value) ;; Extract actual value from property-value struct
          ;;     ;; If property is not set locally and no parent, return default value
          ;;     (let ((definition (%get-style-definition property-name))) ;; Check if property has a definition)
          ;;       (if definition
          ;;           (style-property-definition-default-value definition) ;; Return default value)
          ;;           ;; If no definition, return nil
          ;;           nil)))
          )))) ;; Should not happen for known properties((((

;; (let ((value (gethash property-name (style-set-properties style-set))))
;;   (if (and (null value)
;;            ;; Assuming nil means not set locally inherit
;;            (style-set-parent style-set))
;;       (get-style-property
;;        (style-set-parent style-set) property-name :inherit t)
;;       (if value (style-property-value value) ;; Extract actual value from property-value struct
;;           (let ((definition (%get-style-definition property-name)))
;;             (if definition (style-property-definition-default-value definition) nil)))))) ;; Should not happen for known properties


(defun set-style-property
    (style-set property-name value)
  "Sets the value of a style property in a style-set. The value is parsed and validated
against the property's type definition."
  (check-type property-name keyword)
  (let ((definition (%get-style-definition property-name)))
    (unless definition
      (error "Cannot set unknown style property: ~S"
             property-name))
    (let ((parsed-value (parse-property-value definition value)))
      (setf (gethash property-name (style-set-properties style-set)) parsed-value)
      parsed-value)))

;; (defmacro defstyle (name &body properties)
;;   "Defines a named style-set. Properties are specified as a list of
;; (property-name value) pairs."
;;   `(defvar ,name (make-style-set))
;;   `(progn
;;      ,@(loop for (prop-name prop-value) on properties by #'cddr collect
;;              `(set-style-property ,name ,prop-name ,prop-value))
;;      ,name))

(defun merge-style-sets
    (&rest style-sets) "Merges multiple style-sets into a new style-set. Properties from later style-sets in the argument list override earlier ones. The parent of the new style-set is nil."
  (let
      ((merged-set (make-style-set)))
    (dolist (ss style-sets)
      (when ss
        (loop for key being the hash-keys
                of
                (style-set-properties ss) using
                (hash-value value) do
                  (setf (gethash key (style-set-properties merged-set)) value))))
    merged-set))

(defun inherit-style-set (parent-style-set) "Creates a new style-set that inherits from a parent style-set."
  (make-style-set :parent parent-style-set))

(defun style-set-to-string
    (style-set &key (indent 0))
  "Returns a string representation of the style-set, primarily for debugging."
  (let ((indent-str
          (make-string indent :initial-element #\Space)))
    (with-output-to-string (s)
      (format s "~AStyleSet:~%" indent-str)
      (when (style-set-parent style-set)
        (format s "~A Parent: ~A~%" indent-str
                (if (style-set-parent style-set) "Yes" "No")))
      (loop for key being the hash-keys of
                                        (style-set-properties style-set) using
                                        (hash-value value) do
                                          (format s "~A ~A: ~A~%" indent-str key
                                                  (style-property-value-raw-value value))))))

(defun find-style-property-definition
    (property-name) "Finds the definition for a style property."
  (%get-style-definition property-name))

(defun all-style-property-names
    () "Returns a list of all known style property names." *known-properties*)

(defun get-property-default-value
    (property-name) "Returns the default value for a given style property."
  (let ((defn (find-style-property-definition property-name)))
    (when defn (style-property-definition-default-value defn))))

(defstyle :color #'(lambda (v) (valid-color-value-p v))
  :docstring "Foreground color of text or other elements.")

(defstyle :background-color #'(lambda (v) (valid-color-value-p v))
  :docstring "Background color of an element.")

(defstyle :border-color #'(lambda (v) (valid-color-value-p v))
  :docstring "Color of an element's border.")

(defstyle :border-style (list :solid :double :ascii :dashed :dotted :none) ; Added :dashed, :dotted, expanded from tests
  :default :none
  :docstring "Style of an element's border.")

(defstyle :border-width 'integer
  :default 0
  :docstring "Width of an element's border (applies to all sides if not specified individually).")

;; For individual border widths, if they are treated as separate style properties:
(defstyle :border-top-width 'integer :default 0
  :docstring "Width of the top border of an element.")
(defstyle :border-right-width 'integer :default 0
  :docstring "Width of the right border of an element.")
(defstyle :border-bottom-width 'integer :default 0
  :docstring "Width of the bottom border of an element.")
(defstyle :border-left-width 'integer :default 0
  :docstring "Width of the left border of an element.")


(defstyle :padding 'integer ; Could be a list for (top right bottom left) or (vert horiz) or single value
  :default 0
  :docstring "Padding within an element.")
;; For individual paddings:
(defstyle :padding-top 'integer :default 0
  :docstring "Padding on the top side of an element.")
(defstyle :padding-right 'integer :default 0
  :docstring "Padding on the right side of an element.")
(defstyle :padding-bottom 'integer :default 0
  :docstring "Padding on the bottom side of an element.")
(defstyle :padding-left 'integer :default 0
  :docstring "Padding on the left side of an element.")

(defstyle :visibility (list :visible :hidden :collapse)
  :default :visible
  :docstring "Controls the visibility of an element.")

(defstyle :display (list :block :inline :flex :grid :none) ; Added more common display types
  :default :block
  :docstring "Controls the display behavior of an element (layout model).")

;; Add other common styles as needed, e.g., for flexbox, grid, text alignment, etc.
;; (defstyle :width '(or integer keyword list) :default :auto) ; :fill, :auto, (percent 50)
;; (defstyle :height '(or integer keyword list) :default :auto)
