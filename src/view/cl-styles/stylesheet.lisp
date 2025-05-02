;;; ──────────────────────── 6. Rules & Stylesheets ────────────────────────
(uiop:define-package :cl-styles.sheet
  (:use :cl :cl-styles.util
        :cl-styles.selector :cl-styles.types
        :cl-styles.style-set :cl-styles.stylable)
  (:import-from :cl-styles.selector
   :style-set-styles :set-style :value-raw)
  (:export
   :style-rule :stylesheet
   :defrule :defstylesheet
   :query-stylesheet))

(in-package :cl-styles.sheet)

(defclass style-rule ()
  ((selector :initarg :selector :reader selector)
   (styles   :initarg :styles   :reader rule-styles)))

(defclass stylesheet () ((rules :initform nil :accessor rules)))

(defun merge-rule! (sheet rule)
  (let ((old (find (selector rule) (rules sheet)
                   :key #'selector :test #'=?)))
    (if old (merge-sets! (rule-styles old) (rule-styles rule))
        (push rule (rules sheet))))
  sheet)

(defun query-stylesheet (sheet stylable)
  (let ((out (copy-set (styles stylable)))
        (spec (make-hash-table :test 'eq)))
    ;; base spec 0
    (maphash (lambda (k v) (setf (gethash k spec) 0))
             (style-set-styles out))
    (dolist (r (rules sheet))
      (when (selects (selector r) stylable)
        (let ((sp (specificity (selector r))))
          (maphash (lambda (k v)
                     (when (> sp (gethash k spec -1))
                       (setf (gethash k spec) sp)
                       (set-style out k (value-raw (style-value v)))))
                   (style-set-styles (rule-styles r))))))
    out))

;;; sugar macros -----------------------------------------------------------
(defmacro defrule (sel &body kvs)
  `(make-instance 'style-rule
    :selector ,sel
    :styles   (let ((ss (make-style-set)))
                ,@(loop for (k v) on kvs by #'cddr
                        collect `(set-style ss ,k ,v))
                ss)))

(defmacro defstylesheet (&body ruleforms)
  `(let ((sh (make-instance 'stylesheet)))
     ,@(mapcar (lambda (rf) `(merge-rule! sh ,rf)) ruleforms)
     sh))
