;; (uiop:define-package :elmtui.style-lib.properties (:use :common-lisp)
;;                      (:nicknames :styles.styleprops :styles.properties)
;;                      (:import-from :str :split :upcase)
;;                      (:import-from :elmtui.style-lib.api :make-style :value
;;                       :apply-after :stylegroup-p :tuple-value)
;;
;;                      (:import-from :elmtui.style-lib.macros :defstyle :defstylegroup)
;;                      ;; (:import-from :lowterm :new-fg-color :new-bg-color)
;;                      (:import-from :elmtui.style-lib.stylable :stylable
;;                                    :style-sub-styles :style-group :stylable-id :classes)
;;                      (:import-from :elmtui.style-lib.util :*pad-fill-char*
;;                                    :*margin-fill-char*)
;;                      (:import-from :elmtui.style-lib.util :keyword-split))

;; (in-package :elmtui.style-lib.properties)
;; (defmacro defstyle2 (name type &rest options &key (category :decoration) (related-styles '()))
;;   "Define a style with category and related styles.
;;    NAME: The name of the style (keyword)
;;    TYPE: The type specification
;;    CATEGORY: One of :layout, :content, :decoration, or :behavior
;;    RELATED-STYLES: List of style names this style is related to
;;    OPTIONS: Additional options passed to defstyle"
;;   `(progn
;;      (defstyle ,name ,type ,@options)
;;      (setf (get ',name 'style-metadata)
;;            (make-instance 'style-metadata
;;                           :category ,category
;;                           :related-styles ',related-styles))))
;; ;; (defmacro defstyle2 (name type &key category related-styles &rest options)
;; ;;   "Define a style with category and related styles.
;; ;;    NAME: The name of the style (keyword)
;; ;;    TYPE: The type specification
;; ;;    CATEGORY: One of :layout, :content, :decoration, or :behavior
;; ;;    RELATED-STYLES: List of style names this style is related to
;; ;;    OPTIONS: Additional options passed to defstyle"
;; ;;   `(progn
;; ;;      (defstyle ,name ,type ,@options)
;; ;;      (setf (get ',name 'style-metadata)
;; ;;            (make-instance 'style-metadata
;; ;;                          :category ,(or category :decoration)
;; ;;                          :related-styles ',related-styles))))

;; (defun or-concat-lambda (&rest args)
;;   "Return a lambda that checks if the value is one of the given types.

;; The lambda will return the first type that matches the value. If no type matches, it will return nil.
;; ARGS:
;;   A list of types to check for. Each type can be a symbol, a list of symbols or a lambda.
;; Returns:
;;   A lambda that checks if the value is one of the given types.

;; Example:
;;   (or-concat-lambda 'integer 'string)
;;   => (lambda (x) (or (integerp x) (stringp x)))"
;;   (let ((testfn
;;           (lambda (x)
;;             (lambda (value)
;;               (typecase x
;;                 (list (member value x))
;;                 ;; (cons (member value x))
;;                 (symbol (typep value x))
;;                 (function (funcall x value))
;;                 (t (error "Invalid value specifier: ~A" x)))))))
;;     (lambda (x)
;;       (loop for arg in args
;;             thereis (funcall (funcall testfn arg) x)))))

;; (defstyle :box (list :none :single :double :ascii :full-block) :default :none
;;   :docstring "The box style to use for the element." :decorating-after
;;   :padding)

;; (defstyle :align (list :left :right :center))
;; (defstyle :valign (list :top :middle :bottom))

;; (defstyle :width (or-concat-lambda 'integer (list :min :max)))
;; (defstyle :height (or-concat-lambda 'integer (list :min :max)))

;; ;; (defstyle :content-width (or 'symbol 'integer) :default :arrange) ;; TODO maybe unnecessary, for now for children
;; ;; (defstyle :content-height (or 'symbol 'integer) :default :arrange) ;; TODO maybe unnecessary, for now for children
;; ;;; (defstyle :anchor (or 'symbol 'integer) :default :arrange) ;; TODO maybe unnecessary, maybe for screen

;; (defstyle :visible 'boolean :default t :docstring
;;   "Whether the element is visible or not.")

;; (defstyle :scrollbar-h (list t nil :auto) :default :auto :docstring
;;   "Whether to show horizontal scrollbar: t (always), nil (never), or :auto (when needed)")

;; (defstyle :scrollbar-v (list t nil :auto) :default :auto :docstring
;;   "Whether to show vertical scrollbar: t (always), nil (never), or :auto (when needed)")

;; (defstyle :layout (list :default :stack :row :column :flex))

;; (defstyle :flex-direction (list :row :row-reverse :column :column-reverse))
;; (defstyle :flex-wrap (list :nowrap :wrap :wrap-reverse))
;; (defstyle :flex-grow 'integer :default 0)
;; (defstyle :flex-shrink 'integer :default 1)
;; (defstyle :flex-basis (or-concat-lambda 'integer (list :auto)))



;; ;; (is-color '( 1 2 3))
;; ;; (defstyle :slurp #'is-color :default (list 1 2 3)
;; ;;   :docstring "Whether the element is visible or not.")

;; (defstyle :bold 'boolean)

;; (defstyle :italic 'boolean)

;; (defstyle :underline 'boolean)

;; (defstyle :faint 'boolean)

;; (defstyle :blink 'boolean)

;; (defstyle :inverse 'boolean)

;; (defstyle :strike 'boolean)

;; (defstyle :fg-color #'is-color)

;; (defstyle :bg-color #'is-color)

;; (defstyle :padding-top 'integer :default 0 :docstring
;;   "Padding above the element.")

;; (defstyle :padding-left 'integer :default 0 :docstring
;;   "Padding to the left of the element.")

;; (defstyle :padding-right 'integer :default 0 :docstring
;;   "Padding to the right of the element.")

;; (defstyle :padding-bottom 'integer :default 0 :docstring
;;   "Padding below the element.")

;; (defstyle :padding-bottom 'integer :default 0 :docstring
;;   "Padding below the element.")

;; (defstyle :padding-char 'character :default *pad-fill-char* :docstring
;;   "Padding below the element.")

;; (defstyle :padding-charstyle 'list :default 'nil :docstring
;;   "Padding below the element.")

;; (defstylegroup :padding
;;     '(:padding-top :padding-bottom :padding-left :padding-right :padding-char :padding-charstyle)
;;     (:decorating-after :top)
;;   (unless value
;;     (setf value 0))
;;   (when (integerp value)
;;     (setf value (list value)))
;;   (when (listp value)
;;     (let ((l nil))
;;       (case (length value)
;;         (1
;;          (progn
;;            (dolist
;;                (s '(:padding-top :padding-bottom :padding-left :padding-right))
;;              (push (make-style s (first value)) l))))
;;         (2
;;          (progn
;;            (dolist (s '(:padding-top :padding-bottom))
;;              (push (make-style s (first value)) l))
;;            (dolist (s '(:padding-left :padding-right))
;;              (push (make-style s (second value)) l))))
;;         (3
;;          (progn
;;            (push (make-style :padding-top (first value)) l)
;;            (push (make-style :padding-bottom (second value)) l)
;;            (dolist (s '(:padding-left :padding-right))
;;              (push (make-style s (second (cdr value))) l))))
;;         (4
;;          (progn
;;            (push (make-style :padding-top (first value)) l)
;;            (push (make-style :padding-bottom (second value)) l)
;;            (push (make-style :padding-left (cdr (second value))) l)
;;            (push (make-style :padding-right (cdr (cdr (second value)))) l))))
;;       l)))

;; (defstyle :margin-top 'integer :default 0 :docstring
;;   "Margin above the element.")

;; (defstyle :margin-left 'integer :default 0 :docstring
;;   "Margin to the left of the element.")

;; (defstyle :margin-right 'integer :default 0 :docstring
;;   "Margin to the right of the element.")

;; (defstyle :margin-bottom 'integer :default 0 :docstring
;;   "Margin below the element.")

;; (defstyle :margin-char 'character :default *margin-fill-char* :docstring
;;   "Padding below the element.")

;; (defstyle :margin-charstyle 'list :default 'nil :docstring
;;   "Padding below the element.")

;; (defstylegroup :padding
;;     '(:margin-top :margin-bottom :margin-left :margin-right
;;       :margin-char :margin-charstyle)
;;     (:decorating-after :box)
;;   (unless value
;;     (setf value 0))
;;   (when (integerp value)
;;     (setf value (list value)))
;;   (when (listp value)
;;     (let ((l nil))
;;       (case (length value)
;;         (1
;;          (progn
;;            (dolist (s '(:margin-top :margin-bottom :margin-left :margin-right))
;;              (push (make-style s (first value)) l))))
;;         (2
;;          (progn
;;            (dolist (s '(:margin-top :margin-bottom))
;;              (push (make-style s (first value)) l))
;;            (dolist (s '(:margin-left :margin-right))
;;              (push (make-style s (second value)) l))))
;;         (3
;;          (progn
;;            (push (make-style :margin-top (first value)) l)
;;            (push (make-style :margin-bottom (second value)) l)
;;            (dolist (s '(:margin-left :margin-right))
;;              (push (make-style s (second (cdr value))) l))))
;;         (4
;;          (progn
;;            (push (make-style :margin-top (first value)) l)
;;            (push (make-style :margin-bottom (second value)) l)
;;            (push (make-style :margin-left (cdr (second value))) l)
;;            (push (make-style :margin-right (cdr (cdr (second value)))) l))))
;;       l)))

;;; ─── elmtui.style-lib/properties.lisp ─────────────────────────────────────────
(uiop:define-package :elmtui.style-lib.properties (:use :common-lisp)
                     (:nicknames :styles.styleprops :styles.properties)
                     (:import-from :str :split :upcase)
                     (:import-from :elmtui.style-lib.api :make-style :value
                      :apply-after :stylegroup-p :tuple-value :stylable :style-sub-styles :style-group :stylable-id :classes)
                     (:import-from :elmtui.style-lib.macros :defstyle :defstylegroup)
                     ;; (:import-from :elmtui.style-lib.stylable
                     ;;   :style-sub-styles :style-group :stylable-id :classes)
                     (:import-from :elmtui.style-lib.util :*pad-fill-char*
                                   :*margin-fill-char*)
                     (:import-from :elmtui.style-lib.util :keyword-split)
                     (:export :is-color :defstyle2 :or-concat-lambda :defstyle :defstylegroup
                      :padding-top :padding-left :padding-right :padding-bottom :padding-char
                              :margin-top :margin-left :margin-right :margin-bottom :margin-char
                      :box :align :valign :width :height :visible :scrollbar-h :scrollbar-v
                      :flex-direction :flex-wrap :flex-grow :flex-shrink :flex-basis
                              :bold :italic :underline :faint :blink :inverse :strike :fg-color :bg-color
                      ;; Grid properties
                      :grid-template-columns :grid-template-rows :grid-template-areas
                      :grid-auto-columns :grid-auto-rows :grid-auto-flow
                      :grid-column-gap :grid-row-gap :grid-gap
                      :grid-column-start :grid-column-end :grid-row-start :grid-row-end
                      :grid-column :grid-row :grid-area
                      ))
(in-package :elmtui.style-lib.properties)

(defun is-color (&rest clrs)
  "Check if the given color is valid.

The color can be a symbol, a list of integers or a list of lists of integers. The symbol can be one
of :black, :red, :green, :yellow, :blue, :magenta, :cyan, :white, :default, :bright-black,
:bright-red, :bright-green, :bright-yellow, :bright-blue, :bright-magenta, :bright-cyan,
:bright-white. The list of integers can be a list of 1 (256-colors ansi code) or 3(rgb ansi code)
integers, each between 0 and 255.

Returns: nil if invalid color, else non-nil"
  (typecase (car clrs)
    (symbol
     (member (car clrs)
             (list :black :red
                   :green :yellow
                   :blue :magenta
                   :cyan :white
                   :default :bright-black
                   :bright-red :bright-green
                   :bright-yellow :bright-blue)))
    (list
     (if (listp (car (car clrs)))
         (is-color (car clrs))
         (and (every #'integerp (car clrs))
              (or (= 1 (length (car clrs))) (= 3 (length (car clrs)))))))
    (integer
     (and (every #'integerp clrs)
          (or (= 1 (length clrs)) (= 3 (length clrs)))))))
(defmacro defstyle2 (name type &rest options &key (category :decoration) (related-styles '()))
  "Define a style with category and related styles.
NAME: The style name.
TYPE: The type specification.
CATEGORY: One of :layout, :content, :decoration, or :behavior.
RELATED-STYLES: List of related style names.
OPTIONS: Additional options passed to defstyle."
  `(progn
     (defstyle ,name ,type ,@options)
     (setf (get ',name 'style-metadata)
           (make-instance 'style-metadata
                          :category ,category
                          :related-styles ',related-styles))))

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
(defstyle :width '(or integer (member :auto :min-content :max-content)) :default :auto ; Allow :auto, etc.
  :docstring "Specifies the width of an element.")
;; (defstyle :height (or-concat-lambda 'integer (list :min :max))) ; Original
(defstyle :height '(or integer (member :auto :min-content :max-content)) :default :auto ; Allow :auto, etc.
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
    (unless value (setf value 0))
  (if (integerp value)
      (setf value (list value)))

  (when (listp value)
    (let ((l nil))
      (case (length value)
        (1 (dolist (s '(:padding-top :padding-bottom :padding-left :padding-right))
             (push (make-style s (first value)) l)))
        (2 (progn
             (dolist (s '(:padding-top :padding-bottom))
               (push (make-style s (first value)) l))
             (dolist (s '(:padding-left :padding-right))
               (push (make-style s (second value)) l))))
        (3 (progn
             (push (make-style :padding-top (first value)) l)
             (push (make-style :padding-bottom (second value)) l)
             (dolist (s '(:padding-left :padding-right))
               (push (make-style s (third value)) l))))
        (4 (progn
             (push (make-style :padding-top (first value)) l)
             (push (make-style :padding-bottom (second value)) l)
             (push (make-style :padding-left (third value)) l)
             (push (make-style :padding-right (fourth value)) l))))
      l)))

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
    (unless value (setf value 0))
  (if (integerp value)
      (setf value (list value)))
  (when (listp value)
    (let ((l nil))
      (case (length value)
        (1 (dolist (s '(:margin-top :margin-bottom :margin-left :margin-right))
             (push (make-style s (first value)) l)))
        (2 (progn
             (dolist (s '(:margin-top :margin-bottom))
               (push (make-style s (first value)) l))
             (dolist (s '(:margin-left :margin-right))
               (push (make-style s (second value)) l))))
        (3 (progn
             (push (make-style :margin-top (first value)) l)
             (push (make-style :margin-bottom (second value)) l)
             (dolist (s '(:margin-left :margin-right))
               (push (make-style s (third value)) l))))
        (4 (progn
             (push (make-style :margin-top (first value)) l)
             (push (make-style :margin-bottom (second value)) l)
             (push (make-style :margin-left (third value)) l)
             (push (make-style :margin-right (fourth value)) l))))
      l)))

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
