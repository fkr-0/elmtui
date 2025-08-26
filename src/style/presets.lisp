;;;===============================================================
;;; File: src/style/presets.lisp
;;; Style Presets (Themes)
(uiop:define-package :elmtui.style.presets
  (:use :cl)
  (:import-from #:cl-styles.rule #:defrule)
  (:import-from #:cl-styles.tokens #:rgb)

  (:import-from #:cl-styles.sheet
                #:defstylesheet)
  (:import-from #:cl-styles.selector
                #:type> #:id> #:cls> #:sel-and)
  (:export :dark-theme :light-theme))
(in-package :elmtui.style.presets)

;; Define the dark theme with basic rules using cl-styles
(defparameter dark-theme
  (defstylesheet
      (defrule (type> :root)
        :color :blue :background-color :green)

      (defrule (type> :list-box)
        :display :block
        :border (list 2 :solid (rgb 0 255 255))
        :height 10)

    (defrule (sel-and (type> :list-box) (cls> "listbox-focused"))
      :border-color (rgb 0 255 255))

    (defrule (id> :main-listbox)
      :flex (list 1 1 0)
      :min-height 5)

    (defrule (type> :list-item)
      :color :white :background-color :black
      :padding (list 0 1) :height 1)

    (defrule (sel-and (type> :list-item) (cls> "list-item-selected"))
      :color :black :background-color :white :attributes '(:bold))

    (defrule (type> :text-input)
      :background-color (rgb 51 51 51) :padding (list 0 1))

    (defrule (sel-and (type> :text-input) (cls> "textinput-focused"))
      :background-color (rgb 68 68 68)
      :border (list 1 :solid (rgb 0 255 255))))
  "Predefined dark theme style rules.")

;; Define an empty light theme for now
(defparameter light-theme
  (defstylesheet)
  "Predefined light theme style rules.")
