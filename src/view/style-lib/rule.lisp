(uiop:define-package ::elmtui.style-lib.rule (:nicknames :styles.rule)
                     (:use :common-lisp)
                     (:import-from :elmtui.style-lib.api :style-rule :rule-selector
                      :rule-styles)
                     (:import-from :elmtui.style-lib.util :hash-table-keys)
                     (:import-from :elmtui.style-lib.style-set :style-set :styles-list
                      :new :style-set-styles :style-of :merge-styles!)
                     (:import-from :elmtui.style-lib.selector :selector)
                     (:import-from :elmtui.style-lib.api :tuple-prop :style-p
                      :style-property :value-value :style :style-val
                      :group-styles :make-default-styling :valid-style-value-p
                                   :apply-after :ordered-styles :make-style)
                     (:export :new :defrule))

(in-package :elmtui.style-lib.rule)



(defmethod print-object ((rule style-rule) stream)
  (format stream "#<StyleRule ~a: ~a>" (rule-selector rule)
          (styles-list (rule-styles rule))))

(defmethod style-rule-valid ((s style-rule))
  "Return T if the style rule is valid, NIL otherwise."
  (and (rule-selector s)
       (> (hash-table-count (style-set-styles (rule-styles s))) 0)))

(defmethod new ((class (eql 'style-rule)) &key selector styles)
  "Create a new style rule."
  (let ((rule (make-instance 'style-rule :selector selector :styles styles)))
    (when (style-rule-valid rule)
      rule)))

(defmacro defrule (selector &body styles)
  "Macro to define a style rule.

Arguments:
  selector: The selector for the rule (instance of a selector subclass).
  styles: The styles to apply (as property-value pairs).

Example:
  (defrule (cls> \"button\") (:bg-color :red))"
  `(make-instance 'style-rule
    :selector ,selector
    :styles (new 'style-set :styles ',styles)))
