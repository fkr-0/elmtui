;;;===============================================================
;;; File: src/style/presets.lisp
;;; Style Presets (Themes)
(uiop:define-package :elmtui.style.presets
  (:use :cl
        :cl-styles.styles   ;; default-styles generic
        :cl-styles.sheet)   ;; defstylesheet macro
  (:export :dark-theme
           :light-theme))
(in-package :elmtui.style.presets)

(defparameter dark-theme
  (make-instance 'stylesheet
    :rules (default-styles :dark))
  "Predefined dark theme style rules.")

(defparameter light-theme
  (make-instance 'stylesheet
    :rules (default-styles :light))
  "Predefined light theme style rules.")
