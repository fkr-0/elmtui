;;;===============================================================
;;; File: src/style/core.lisp
;;; Styling & Theming Core (elmtui.style-lib integration)
(uiop:define-package :elmtui.style.core
  (:use :cl :elmtui.style-lib)
  ;; (:import-from :elmtui.style-lib.style-set :default-styles)
  (:export :style-rule)) ; Removed :apply-style
(in-package :elmtui.style.core)

(defparameter *base-style-set* (elmtui.style-lib.api:make-style-set)
  "The baseline style-set (elmtui.style-lib.style-set).")

;; Removed apply-style function as it's redundant with
;; elmtui.view.styled:apply-stylesheet-to-tree
