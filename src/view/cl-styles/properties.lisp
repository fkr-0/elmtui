;; (uiop:define-package :cl-styles.properties (:use :common-lisp)
;;                      (:nicknames :styles.styleprops :styles.properties)
;;                      (:import-from :str :split :upcase)
;;                      (:import-from :cl-styles.api :make-style :value
;;                       :apply-after :stylegroup-p :tuple-value)

;;                      (:import-from :cl-styles.macros :defstyle :defstylegroup)
;;                      ;; (:import-from :lowterm :new-fg-color :new-bg-color)
;;                      (:import-from :cl-styles.stylable :stylable
;;                                    :style-sub-styles :style-group :stylable-id :classes)
;;                      (:import-from :cl-styles.util :*pad-fill-char*
;;                                    :*margin-fill-char*)
;;                      (:import-from :cl-styles.util :keyword-split))

;; (in-package :cl-styles.properties)
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

;;; ─── cl-styles/properties.lisp ─────────────────────────────────────────
(uiop:define-package :cl-styles.properties (:use :common-lisp)
  (:nicknames :styles.styleprops :styles.properties)
  (:import-from :str :split :upcase)
  (:import-from :cl-styles.api :make-style :value
    :apply-after :stylegroup-p :tuple-value)
  (:import-from :cl-styles.macros :defstyle :defstylegroup)
  (:import-from :cl-styles.stylable :stylable
    :style-sub-styles :style-group :stylable-id :classes)
  (:import-from :cl-styles.util :*pad-fill-char*
    :*margin-fill-char*)
  (:import-from :cl-styles.util :keyword-split)
  (:export :is-color :defstyle2 :or-concat-lambda :defstyle :defstylegroup
    :padding-top :padding-left :padding-right :padding-bottom :padding-char
    :margin-top :margin-left :margin-right :margin-bottom :margin-char
    :box :align :valign :width :height :visible :scrollbar-h :scrollbar-v
    :flex-direction :flex-wrap :flex-grow :flex-shrink :flex-basis
    :bold :italic :underline :faint :blink :inverse :strike :fg-color :bg-color))
(in-package :cl-styles.properties)

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
;; End of properties.lisp
