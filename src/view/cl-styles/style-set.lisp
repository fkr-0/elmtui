;;; ───────────────────────── 4. Style-Set  ────────────────────────────────
(uiop:define-package :cl-styles.style-set
  (:use :cl :cl-styles.util :cl-styles.types :cl-styles.styles)
  (:import-from :cl-styles.types
   :valid-style-value-p :style-group-key
   :style-value :stylegroup-p :sub-styles :tuple-prop)
  (:import-from :cl-styles.api
   :group-styles)
  (:import-from :cl-styles.styles
   :make-style :value-raw)
  (:import-from :cl-styles.util
   :apply-after)
  (:import-from :cl-styles.style-set
   :style-set-styles)
  (:export
   :style-set :make-style-set
   :style-of :value-of :set-style
   :merge-sets! :copy-set
   :parse-styles :styles-list
   :around-styles :ordered-around-styles))

(in-package :cl-styles.style-set)

(defstruct (style-set (:constructor make-style-set))
  (styles (make-hash-table :test 'eq))
  (order  nil))

(defun style-of (set prop)
  (gethash prop (style-set-styles set)))
;; (defun value-of (set prop)
;;   (when-let ((s (style-of set prop))) (value-raw (style-value s))))
(defun set-style (set prop val)
  (setf (gethash prop (style-set-styles set)) (make-style prop val)))

(defun merge-sets! (into from)
  (maphash (lambda (k v) (setf (gethash k (style-set-styles into)) v))
           (style-set-styles from))
  into)
(defun copy-set (set) (merge-sets! (make-style-set) set))

(defun parse-styles (&rest raw)
  (loop for (k v) on raw by #'cddr collect (make-style k v)))

(defun styles-list (set)
  (loop for k in (sort (hash-table-keys (style-set-styles set))
                       (lambda (a b) (string< (symbol-name a) (symbol-name b))))
        collect k and collect (value-of set k)))

;; (defun around-styles (set) (hash-table-keys (style-set-styles set)))
;; (defun ordered-around-styles (set) (or (style-set-order set)
;;                                        (setf (style-set-order set) (around-styles set))))

;;; defaults ---------------------------------------------------------------
(defparameter *default-style-set* (make-style-set))

(defun default-style-set ()
  "Create a default style set derived from all styles that define a default value."
  (new 'style-set :styles (make-default-styling)))

(defvar *default-styles*
  (default-style-set)
  "Default style set containing all default styles.")

(defmethod print-object ((set style-set) stream)
  "Print a representation of the style-set to the given stream."
  (format stream "#<STYLE-SET ~A>" (styles-list set)))

(defmethod around-styles ((set style-set))
  "Return the list of decorator styles in the given style set."
  (let ((decorator-styles nil))
    (maphash
     (lambda (k v)
       (declare (ignore v))
       (if (and (style-group-key k)
                (not (member (style-group-key k) decorator-styles))
                (not (eql (apply-after (style-group-key k) 'nil)
                          :non-decorating)))
           (push (style-group-key k) decorator-styles)
           (if (not (eql (apply-after k 'nil) :non-decorating))
               (push k decorator-styles))))
     (style-set-styles set))
    decorator-styles))

(defmethod ordered-around-styles ((set style-set))
  "Return the decorator styles of the given style set in order."
  (let ((order (or (style-set-order set) (ordered-styles (around-styles set)))))
    (setf (style-set-order set) order)
    order))

(defmethod (setf value-of) (value (set style-set) property)
  "Set the value of the given property in the given style set.

Example:
  (setf (value-of my-style-set 'bg-color) :red)"
  (if (null value)
      (when (style-of set property) (remhash property (style-set-styles set)))
      (let ((s (style-of set property)))
        (when s
          (unless (valid-style-value-p (style-property s) value)
            (error "Invalid value: ~a for ~a" value s)))
        (if s
            (setf (value-value (style-value s)) value)
            (setf (gethash property (style-set-styles set))
                  (make-style property value)))))
  value)

(defmethod (setf style-of)
    (value (set style-set) (property symbol) &optional args)
  "Set the style instance for the given property in the given style set.
Value: The style instance to set.
Set (style-set): The style set to set the style in.
Property (symbol): The property to set the style for.

Example:
  (setf (style-of my-style-set 'bg-color) (make-style :bg-color :red
    :fg-color :white
    :bold t))"
  (declare (ignore args))
  (if (group-styles property)
      (let*
          ((inst
             (if (stylegroup-p value) value (make-style property value)))
           (subs (sub-styles inst)))
        (dolist (s subs)
          (setf (style-of set (tuple-prop s)) s)))
      (setf (gethash property (style-set-styles set)) value)))

(defmethod (setf style-of)
    (values (set style-set) (properties list) &optional args)
  "Set multiple styles in the given style set."
  (declare (ignore args))
  (loop for property in properties
        for value in values
        do (setf (style-of set property) value)))

(defmethod merge-styles! ((set style-set) (other style-set))
  "Merge the styles from another style set into this one."
  (maphash (lambda (k v) (setf (style-of set k) v)) (style-set-styles other))
  set)

(defgeneric copy (set)
  (:method ((set null))
    (make-style-set))
  (:method ((set t))
    (make-style-set))
  (:documentation "Return a copy of the given style set."))

(defmethod copy ((set style-set))
  "Return a copy of the given style set."
  (let ((copy (make-style-set)))
    (merge-styles! copy set)
    copy))

(defmethod invert-colors! ((set style-set))
  "Mutate the given style set by inverting the foreground and background colors."
  (let ((fg (value-of set :fg-color)) (bg (value-of set :bg-color)))
    (setf (value-of set :fg-color) bg)
    (setf (value-of set :bg-color) fg)
    set))

(defmethod invert-colors ((set style-set))
  "Return a new style set with the foreground and background colors inverted."
  (invert-colors! (copy set)))

;; End of style-set.lisp
