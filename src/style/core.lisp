;;;===============================================================
;;; File: src/style/core.lisp
;;; Styling & Theming Core (cl-styles integration)
(uiop:define-package :elmtui.style.core
  (:use :cl
        :cl-styles.api        ;; make-style-set, from-style-set, set-style, group-styles
        :cl-styles.style-set  ;; style-set struct, copy, merge-sets!
        :cl-styles.selector   ;; selector classes & macros
        :cl-styles.rule       ;; style-rule class, defrule macro
        :cl-styles.sheet      ;; query-stylesheet
        :cl-styles.properties ;; defstyle macros, property predicates
  )
  (:export :style-rule
           :apply-style))
(in-package :elmtui.style.core)

(defparameter *base-style-set* (default-style-set)
  "The baseline style-set (cl-styles.style-set).")

(defun apply-style (ui-tree &optional (style-set *base-style-set*))
  "Decorate UI-TREE via cl-styles: query-stylesheet → set-style on each node.
   Contract: decorates ui-node trees without mutating originals."
  ;; stub: walk ui-tree, for each stylable node:
  ;;   (let ((rules (query-stylesheet *stylesheet* node)))
  ;;     (dolist (rule rules) (set-style style-set (rule-property rule) (rule-value rule)))
  ;;     ;; attach final computed props into ui-node.props
  ;;     )
  )
