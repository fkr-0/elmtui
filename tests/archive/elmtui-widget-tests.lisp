;;;===============================================================
;;; File: tests/elmtui-widget-tests.lisp
;;; Basic Tests for Elm-style Widgets
;;;===============================================================
;; (defpackage :elmtui-widget-tests
;;   (:use :cl :fiveam :alexandria)
;;   (:import-from :elmtui.view.core #:ui-node #:ui-node-p)
;;   ;; Import widget packages
;;   (:import-from :elmtui.ui.widgets.button
;;                 #:init-button #:update-button #:view-button #:button-model)
;;   (:import-from :elmtui.ui.widgets.label
;;                 #:init-label #:update-label #:view-label #:label-model)
;;   (:import-from :elmtui.ui.widgets.textinput
;;                 #:init-textinput #:update-textinput #:view-textinput #:textinput-model
;;                 #:msg-textinput-key-press #:msg-textinput-focus #:msg-textinput-blur
;;                 #:msg-form-child-update #:msg-form-submit)
;;   (:import-from :elmtui.ui.widgets.listbox
;;                 #:init-listbox #:update-listbox #:view-listbox ))

;; (in-package :elmtui-widget-tests)

;; (def-suite widget-tests
;;   :description "Tests for ElmTUI widgets (buttons, forms, etc.)")

;; (in-suite widget-tests)

;; ;;; Button Widget Tests
;; (test button-widget-basics
;;   "Test basic button widget properties and behavior"
;;   (let* ((button (init-button :test-button :label "Click Me"))
;;          (button-view (view-button button #'identity)))
;;     (is (equal (getf button :id) :test-button) "Button ID should be set")
;;     (is (equal (getf button :label) "Click Me") "Button label should be set")
;;     (is (ui-node-p button-view) "Button view should return a UI node")
;;     (is (equal (ui-node-type button-view) :button) "Button view should have :button type")))

;; ;;; Label Widget Tests
;; (test label-widget-basics
;;   "Test basic label widget properties"
;;   (let* ((label (init-label :test-label :value "Hello World"))
;;          (label-view (view-label label #'identity)))
;;     (is (equal (getf label :id) :test-label) "Label ID should be set")
;;     (is (equal (getf label :value) "Hello World") "Label value should be set")
;;     (is (ui-node-p label-view) "Label view should return a UI node")
;;     (is (equal (ui-node-type label-view) :label) "Label view should have :label type")))

;; ;;; TextInput Widget Tests
;; (test textinput-widget-basics
;;   "Test basic text input widget properties"
;;   (let* ((input (init-textinput :test-input :value "Initial text"))
;;          (input-view (view-textinput input #'identity)))
;;     (is (equal (getf input :id) :test-input) "TextInput ID should be set")
;;     (is (equal (getf input :value) "Initial text") "TextInput value should be set")
;;     (is (ui-node-p input-view) "TextInput view should return a UI node")
;;     (is (equal (ui-node-type input-view) :textinput) "TextInput view should have :textinput type")))

;; ;;; Listbox Widget Tests
;; (test listbox-widget-basics
;;   "Test basic listbox widget properties"
;;   (let* ((items '((:id :item1 :value "Item 1")
;;                   (:id :item2 :value "Item 2")
;;                   (:id :item3 :value "Item 3")))
;;          (listbox (init-listbox :test-listbox :items items))
;;          (listbox-view (view-listbox listbox #'identity)))
;;     (is (equal (getf listbox :id) :test-listbox) "Listbox ID should be set")
;;     (is (equal (length (getf listbox :items)) 3) "Listbox should have 3 items")
;;     (is (ui-node-p listbox-view) "Listbox view should return a UI node")
;;     (is (equal (ui-node-type listbox-view) :listbox) "Listbox view should have :listbox type")))

;; ;;; Run all tests
;; (defun run-elmtui-widget-tests ()
;;   (run! 'widget-tests))
