(in-package :cl-user)

(uiop:define-package :cl-styles.protocols
  (:use :cl :alexandria)
  (:export
   #:stylable-id #:stylable-classes #:stylable-type #:stylable-inline-style
   #:stylable-attributes #:stylable-state
   #:stylable-parent #:stylable-children #:stylable-index
   #:set-computed-style #:get-computed-style
   #:stylable-namespace #:stylable-theme #:stylable-key))

(uiop:define-package :cl-styles.tokens
  (:use :cl :alexandria)
  (:export
   #:rgb #:rgba #:hsl #:resolve-variables
   #:px #:percent #:em #:root-em #:ch #:len
   #:var #:color-p #:length-p #:variable-ref-p))

(uiop:define-package :cl-styles.selector
  (:use :cl :alexandria :cl-styles.protocols)
  (:export
   #:type> #:id> #:cls> #:attr> #:state>
   #:first-child #:last-child #:nth-child
   #:sel-and #:sel-or #:sel-not
   #:descendant> #:child> #:has
   #:compile-selector #:selector-specificity #:match-selector-p))

(uiop:define-package :cl-styles.rule
  (:use :cl :alexandria :cl-styles.selector :cl-styles.tokens)
  (:export
   #:rule #:make-rule #:rule-selector #:rule-declarations #:rule-specificity
   #:defrule #:expand-shorthands))

(uiop:define-package :cl-styles.sheet
  (:use :cl :alexandria :cl-styles.rule :cl-styles.selector :cl-styles.tokens)
  (:export
   #:stylesheet #:make-stylesheet #:stylesheet-rules #:stylesheet-variables
   #:stylesheet-namespace
   #:defstylesheet #:compile-stylesheet #:merge-stylesheets #:with-variables))



(uiop:define-package :cl-styles.properties
  (:use :cl :alexandria)
  (:export
   ;; property registry
   #:defproperty #:register-property #:property-definition
   #:normalize-declarations #:validate-declarations #:ensure-declarations
   ;; groups
   #:define-group #:properties-for-group #:groups-for-layout #:properties-for-layout
   ;; condition
   #:style-contract-violation))

(uiop:define-package :cl-styles.engine
  (:use :cl :alexandria :cl-styles.protocols :cl-styles.sheet :cl-styles.rule
   :cl-styles.selector :cl-styles.tokens)
  (:export
   #:style-patch #:style-patch-path #:style-patch-computed
   #:match-rules #:compute-style #:inherit-properties
   #:apply-stylesheet #:apply-stylesheet-to-tree))

(uiop:define-package :cl-styles.api
  (:use :cl :cl-reexport)
  (:reexport :cl-styles.protocols :cl-styles.tokens :cl-styles.selector
   :cl-styles.rule :cl-styles.sheet :cl-styles.engine :cl-styles.properties))
