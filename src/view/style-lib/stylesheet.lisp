;;; ──────────────────────── 6. Rules & Stylesheets ────────────────────────
(uiop:define-package :elmtui.style-lib.sheet
  (:use :cl :elmtui.style-lib.util
        :elmtui.style-lib.api
   :elmtui.style-lib.style-set :elmtui.style-lib.stylable)
  ;; Correct imports
  (:import-from :elmtui.style-lib.api
                #:style-set-styles #:value-raw #:selector #:selects
                #:rule-selector #:stylesheet-rules #:rule-styles #:styles
                #:stylesheet #:style-value :specificity)
  (:import-from :elmtui.style-lib.style-set
                #:set-style #:copy-set) ; Removed rule-styles (it's in API)
  ;; Removed incorrect imports from selector:
  (:export
   :defstylesheet
   :query-stylesheet))

(in-package :elmtui.style-lib.sheet)

;; Define classes locally if not imported/re-exported properly elsewhere
;; (defclass style-rule ()
;;   ((selector :initarg :selector :reader selector)
;;    (styles   :initarg :styles   :reader rule-styles)))

;; (defclass stylesheet () ((rules :initform nil :accessor rules))) ; Defined in API

(defun merge-rule! (sheet rule)
  (let ((old (find (rule-selector rule) (stylesheet-rules sheet) ; Use API accessors
                   :key #'rule-selector :test #'equalp))) ; Use equalp for selectors?
    (if old (merge-sets! (rule-styles old) (rule-styles rule)) ; merge-sets! from style-set, rule-styles from API
        ;; Use the correct accessor from API
        (push rule (stylesheet-rules sheet))))
  sheet)

(defun query-stylesheet (sheet stylable)
  (let ((out (copy-set (styles stylable))) ; styles is from API
        (spec (make-hash-table :test 'eq)))
    ;; base spec 0
    (maphash (lambda (k v) (declare (ignore v)) (setf (gethash k spec) 0)) ; Ignore v
             (style-set-styles out)) ; Imported from API
    (dolist (r (stylesheet-rules sheet)) ; Use API accessor
      (when (selects (rule-selector r) stylable) ; selects, rule-selector from API
        (let ((sp (specificity (rule-selector r)))) ; specificity from API
          (maphash (lambda (k v) ; k=prop keyword, v=style object
                     (when (> sp (gethash k spec -1))
                       (setf (gethash k spec) sp)
                       ;; Use value-raw (from API) and style-value (from Types)
                       (set-style out k (value-raw (style-value v)))))
                   (style-set-styles (rule-styles r)))))) ; style-set-styles from API
    out))

;;; sugar macros -----------------------------------------------------------
;; (defmacro defrule (sel &body kvs)
;;   `(make-instance 'style-rule
;;     :selector ,sel
;;     :styles   (let ((ss (make-style-set)))
;;                 ,@(loop for (k v) on kvs by #'cddr
;;                         collect `(set-style ss ,k ,v))
;;                 ss)))

(defmacro defstylesheet (&body ruleforms)
  `(let ((sh (make-instance 'stylesheet)))
     ,@(mapcar (lambda (rf) `(merge-rule! sh ,rf)) ruleforms)
     sh))
