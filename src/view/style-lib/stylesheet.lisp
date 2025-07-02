;;; ──────────────────────── 6. Rules & Stylesheets ────────────────────────
(uiop:define-package :elmtui.style-lib.sheet
  (:use :cl :elmtui.style-lib.util
        :elmtui.style-lib.api
   :elmtui.style-lib.style-set :elmtui.style-lib.stylable)
  ;; Correct imports
  (:import-from :elmtui.style-lib.api
                #:style-set-styles #:selector #:selects #:value-value #:parents-of
                #:rule-selector #:stylesheet-rules #:rule-styles #:styles
                #:selects
                #:style-rule
                #:stylesheet #:style-value :specificity #:make-style-set) ; Added make-style-set
  (:import-from :elmtui.style-lib.style-set
                #:set-style #:copy-set #:style-of #:value-of) ; Added style-of, value-of
  (:import-from :elmtui.style-lib.properties #:*inheritable-style-properties*) ; Import inheritable props list
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

(defmethod merge-rule! ((sheet stylesheet) (rule style-rule))
  (let ((old (find (rule-selector rule) (stylesheet-rules sheet) ; Use API accessors
                   :key #'rule-selector :test #'equalp))) ; Use equalp for selectors?
    (if old 
        ;; Call merge-sets! from style-set package
        (elmtui.style-lib.style-set:merge-sets! (rule-styles old) (rule-styles rule))
        ;; Use the correct accessor from API
        (push rule (stylesheet-rules sheet))))
  sheet)

(defmethod merge-rule! ((sheet stylesheet) (rule list))
  (mapcar (lambda (r) (merge-rule! sheet r)) rule))

(defun query-stylesheet (sheet stylable)
  (log:debug "QUERY-STYLESHEET: Entered for stylable ID ~S. Initial (styles stylable) is: ~S"
             (if (slot-boundp stylable 'elmtui.style-lib.api:sid) (stylable-id stylable) "UNBOUND-ID")
             (if (slot-boundp stylable 'elmtui.style-lib.api:styles) (styles stylable) "UNBOUND-STYLES"))
  (let ((initial-node-styles (if (slot-boundp stylable 'elmtui.style-lib.api:styles) (styles stylable) nil)))
    (unless (typep initial-node-styles 'style-set)
      (log:error "QUERY-STYLESHEET: (styles stylable) for ID ~S is NOT a style-set! Value: ~S"
                 (if (slot-boundp stylable 'elmtui.style-lib.api:sid) (stylable-id stylable) "UNBOUND-ID") initial-node-styles)))
  (let ((out (copy-set (if (slot-boundp stylable 'elmtui.style-lib.api:styles) (styles stylable) (make-style-set))))) ; Ensure copy-set gets a style-set
    (unless (typep out 'style-set)
      (log:error "QUERY-STYLESHEET: copy-set result for ID ~S is NOT a style-set! Value: ~S. (styles stylable) was: ~S"
                 (if (slot-boundp stylable 'elmtui.style-lib.api:sid) (stylable-id stylable) "UNBOUND-ID") out
                 (if (slot-boundp stylable 'elmtui.style-lib.api:styles) (styles stylable) "UNBOUND-STYLES")))
    (log:debug "QUERY-STYLESHEET: Initial 'out' for ID ~S is: ~S"
               (if (slot-boundp stylable 'elmtui.style-lib.api:sid) (stylable-id stylable) "UNBOUND-ID") out)
    (let ((spec (make-hash-table :test 'eq)))
      ;; base spec 0
      (if (typep out 'style-set)
          (maphash (lambda (k v) (declare (ignore v)) (setf (gethash k spec) 0))
                   (style-set-styles out))
          (log:error "QUERY-STYLESHEET: 'out' is NIL or not a style-set for ID ~S before maphash. Value: ~S"
                     (if (slot-boundp stylable 'elmtui.style-lib.api:sid) (stylable-id stylable) "UNBOUND-ID") out))
      (dolist (r (stylesheet-rules sheet))
        (let ((selector (rule-selector r)))
          (when (cond
                  ((keywordp selector) ; Type selector (e.g., :button)
                   (and (typep stylable 'elmtui.view.api:ui-node) ; Ensure stylable is a node
                        (eq selector (elmtui.view.api:ui-node-type stylable))))
                  ((stringp selector) ; Raw string selector - workaround
                   (log:warn "QUERY-STYLESHEET: Encountered raw string selector \"~A\" in rule. Treating as class selector. Rule: ~S" selector r)
                   (selects (elmtui.style-lib.selector:cls> selector) stylable))
                  ((typep selector 'elmtui.style-lib.api:selector) ; Proper selector object
                   (selects selector stylable))
                  (t ; Unknown selector type
                   (log:warn "QUERY-STYLESHEET: Unknown selector type ~S for rule ~S" (type-of selector) r)
                   nil))
            (let ((sp (cond
                        ((keywordp selector) 1) ; Specificity for type selector
                        ((stringp selector) 10) ; Specificity for (implicit) class selector
                        ((typep selector 'elmtui.style-lib.api:selector) (specificity selector))
                        (t 0))))
              (if (typep out 'style-set)
                  (maphash (lambda (k v)
                             (when (> sp (gethash k spec -1))
                               (setf (gethash k spec) sp)
                               ;; Pass the unwrapped, raw style value to set-style
                               (set-style out k (value-value (style-value v)))))
                           (style-set-styles (rule-styles r)))
                  (log:error "QUERY-STYLESHEET: 'out' is NIL or not a style-set for ID ~S during rule application. Value: ~S"
                             (if (slot-boundp stylable 'elmtui.style-lib.api:sid) (stylable-id stylable) "UNBOUND-ID") out))))))

      ;; --- Style Inheritance ---
      (let ((parent (first (parents-of stylable))))
        (when (and parent (typep parent 'stylable) (styles parent)) ; Check if parent has styles
          (dolist (prop *inheritable-style-properties*)
            ;; If the current node's 'out' style-set does NOT have this property directly set
            (unless (style-of out prop)
              (let ((parent-style-obj (style-of (styles parent) prop)))
                (when parent-style-obj
                  (log:debug "QUERY-STYLESHEET: Inheriting property ~S from parent ~S for node ~S"
                             prop (stylable-id parent) (stylable-id stylable))
                  ;; Directly set the style object from parent into child's 'out' set
                  (setf (gethash prop (style-set-styles out)) parent-style-obj)))))))

      (log:debug "QUERY-STYLESHEET: Returning 'out' (after inheritance) for ID ~S: ~S"
                 (if (slot-boundp stylable 'elmtui.style-lib.api:sid) (stylable-id stylable) "UNBOUND-ID") out)
      out)))

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
