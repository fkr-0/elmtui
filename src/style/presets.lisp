;;;===============================================================
;;; File: src/style/presets.lisp
;;; Style Presets (Themes)
(uiop:define-package :elmtui.style.presets
  (:use :cl)
  ;; Import necessary classes and functions from style-lib
  (:import-from :elmtui.style-lib.api #:stylesheet #:style-rule #:make-style-set)
  (:import-from :elmtui.style-lib.sheet #:defstylesheet) ; Stylesheet definition macro
  (:import-from :elmtui.style-lib.style-set #:set-style) ; Function to add styles to a set
  (:import-from :elmtui.utils #:hex-str-to-rgb)
  ;; Import selector creation macros
  (:import-from :elmtui.style-lib.selector #:type> #:cls> #:id> #:and> #:cl-cls>) ; Added type>
  (:export :dark-theme
   :light-theme))
(in-package :elmtui.style.presets)

;; Helper to create a rule instance (assuming defrule isn't exported/available)
(defun make-rule (selector &rest styles-plist)
  (let ((style-set (make-style-set)))
    (loop for (prop value) on styles-plist by #'cddr
          do (set-style style-set prop value))
    (make-instance 'style-rule :selector selector :styles style-set)))

;; Define the dark theme with basic rules
(defparameter dark-theme
  (defstylesheet
    ;; Default text style (applies to everything unless overridden)
    (make-rule :* ; Universal selector still uses keyword :*
               :foreground-color :blue
               :background-color :green)

    ;; ListBox base style
    (make-rule (type> :list-box) ; Use type> macro
               :display :block   ; Ensure block layout for list-box
               :border-color :cyan
               :box :single      ; Add a border
               :height 10)       ; Default height for listbox

    ;; Focused ListBox style
    (make-rule (and> (type> :list-box) (cls> "listbox-focused")) ; Combine type> and cls>
               :border-color :cyan)

    ;; Rule for the dirlister_poc listbox to make it grow
    (make-rule (id> :main-listbox) ; Target the specific listbox in dirlister_poc
               :flex-grow 1         ; Allow it to grow
               :flex-shrink 1       ; Allow it to shrink (optional, but good practice)
               :min-height 5        ; Prevent it from becoming too small
               ;; :height will act as flex-basis if not overridden by flex properties
               )
    ;; List Item base style
    (make-rule (type> :list-item) ; Use type> macro
               :foreground-color :white ; Default from universal, but explicit here for clarity/fallback
               :background-color :black ; Default from universal, but explicit here
               :padding-left 1 ; Indent items slightly
               :padding-right 1
               :height 1)        ; Ensure list items have a default height of 1

    ;; Selected List Item style
    (make-rule (and> (type> :list-item)
                     (cls> "list-item-selected")) ; Combine type> and cls>
               :foreground-color :black
               :background-color :white ; Reverse video for selection
               :attributes '(:bold))

    ;; Focused + Selected List Item (ensure selection is visible when focused)
    ;; This requires a descendant or child combinator, let's use descendant for now
    ;; (descendant> (and> :list-box (cls> "listbox-focused"))
    ;;              (and> :list-item (cls> "list-item-selected")))
    ;; Simpler approach: Apply style directly to the selected item when the listbox is focused
    ;; This relies on the listbox view adding a specific class or the renderer handling context.
    ;; Let's try a combined selector on the item itself, assuming context might add classes.
    ;; Alternative: Style the selected item within a focused listbox
    (make-rule (and> (type> :list-item) (cls> "list-item-selected")) ; Base selected style
               :foreground-color :black
               :background-color :blue
               :attributes '(:bold))
    ;; Basic Text Input
    (make-rule (type> :text-input) ; Use type> macro
               :background-color "#333333"
               :padding-left 1
               :padding-right 1)

    ;; Focused Text Input
    (make-rule (and> (type> :text-input) (cls> "textinput-focused")) ; Combine type> and cls>
               :background-color "#444444"
               :border-color :cyan
               :box :single))
  "Predefined dark theme style rules.")

;; Define an empty light theme for now
(defparameter light-theme
  (make-instance 'stylesheet :rules '())
  "Predefined light theme style rules.")
