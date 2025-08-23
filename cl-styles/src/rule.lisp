(in-package :cl-styles.rule)

(defstruct rule selector declarations specificity)

(defmacro defrule (selector &body declarations)
  "Create a rule. Declarations are a plist of property/value forms.
If a value is a list literal starting with a number or keyword (e.g., (1 1 0)
for :flex or (0 1) for :padding), wrap it in (list ...) so it becomes data,
not a function call. Values starting with a symbol (e.g., (rgb ...)) are left
as-is so they evaluate."
  (let ((norm-decls
          (loop with out = '()
                for (k v) on declarations by #'cddr do
                  (let* ((vk v)
                         (wrapp (and (consp v)
                                     (or (numberp (car v)) (keywordp (car v))))))
                    (when wrapp
                      (setf vk (cons 'list v)))
                    (setf out (list* k vk out)))
                finally (return (nreverse out)))))
    `(make-rule :selector (cl-styles.selector:compile-selector ,selector)
                :declarations (list ,@norm-decls)
                :specificity (cl-styles.selector:selector-specificity ,selector))))

(defun %maybe (plist key)
  (when (and (listp plist) (member key plist :test #'eql)) (getf plist key)))

(defun expand-shorthands (plist)
  "Expand common CSS-like shorthands into longhands.
Supports: :padding, :margin, :gap → (:row-gap :column-gap). Longhands win."
  (let ((out (copy-list (or plist nil))))
    (flet ((setf-when-absent (k v)
             (unless (member k out :test #'eql)
               (setf out (list* k v out)))))
      (labels ((expand-box (val top right bottom left)
                 (cond
                   ((numberp val)
                    (setf-when-absent top val)
                    (setf-when-absent right val)
                    (setf-when-absent bottom val)
                    (setf-when-absent left val))
                   ((and (listp val) (= (length val) 2))
                    (setf-when-absent top (first val))
                    (setf-when-absent bottom (first val))
                    (setf-when-absent right (second val))
                    (setf-when-absent left (second val)))
                   ((and (listp val) (= (length val) 3))
                    (setf-when-absent top (first val))
                    (setf-when-absent right (second val))
                    (setf-when-absent left (second val))
                    (setf-when-absent bottom (third val)))
                   ((and (listp val) (= (length val) 4))
                    (setf-when-absent top (first val))
                    (setf-when-absent right (second val))
                    (setf-when-absent bottom (third val))
                    (setf-when-absent left (fourth val))))))
        ;; padding shorthand (1-4 values)
        ;; padding shorthand (single number)
        (let ((p (%maybe out :padding)))
          (when p
            (expand-box p :padding-top :padding-right :padding-bottom :padding-left)))
        ;; margin shorthand (single number)
        (let ((m (%maybe out :margin)))
          (when m
            (expand-box m :margin-top :margin-right :margin-bottom :margin-left)))
        ;; gap → row/column gap
        (let ((g (%maybe out :gap)))
          (when g
            (cond
              ((numberp g)
               (setf-when-absent :row-gap g)
               (setf-when-absent :column-gap g))
              ((and (listp g) (= (length g) 2))
               (setf-when-absent :row-gap (first g))
               (setf-when-absent :column-gap (second g))))))
        ;; border shorthand: number or list (width [style] [color])
        (let ((b (%maybe out :border)))
          (cond
            ((numberp b)
             (dolist (k '(:border-top-width :border-right-width :border-bottom-width :border-left-width))
               (setf-when-absent k b)))
            ((and (listp b) (<= 1 (length b)))
             (let ((width nil) (style nil) (color nil))
               (dolist (part b)
                 (cond
                   ((numberp part) (setf width part))
                   ((and (symbolp part) (member (cl-styles.properties::%ensure-keyword part)
                                                '(:none :solid :dashed :dotted :double)
                                                :test #'eql))
                    (setf style (cl-styles.properties::%ensure-keyword part)))
                   ((cl-styles.tokens:color-p part) (setf color part))))
               (when width (dolist (k '(:border-top-width :border-right-width :border-bottom-width :border-left-width))
                             (setf-when-absent k width)))
               (when style (dolist (k '(:border-top-style :border-right-style :border-bottom-style :border-left-style))
                             (setf-when-absent k style)))
               (when color (dolist (k '(:border-top-color :border-right-color :border-bottom-color :border-left-color))
                             (setf-when-absent k color))))))
          ;; flex shorthand
          (let ((fx (%maybe out :flex)))
            (when fx
              (cond
                ((numberp fx)
                 (setf-when-absent :flex-grow fx)
                 (setf-when-absent :flex-shrink 1)
                 (setf-when-absent :flex-basis 0))
                ((and (listp fx) (>= (length fx) 2))
                 (destructuring-bind (grow shrink &optional (basis 0)) fx
                   (when (numberp grow)   (setf-when-absent :flex-grow grow))
                   (when (numberp shrink) (setf-when-absent :flex-shrink shrink))
                   (when (numberp basis)  (setf-when-absent :flex-basis basis))))))
            ;; flex-flow shorthand
            (let ((ff (%maybe out :flex-flow)))
              (when (and (listp ff) (= (length ff) 2))
                (destructuring-bind (dir wrap) ff
                  (setf-when-absent :flex-direction dir)
                  (setf-when-absent :flex-wrap wrap))))
            out))))))
