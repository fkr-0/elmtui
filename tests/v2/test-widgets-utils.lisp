;;;===============================================================
;;; File: tests/v2/elmtui-ui-widgets-utils-tests.lisp
;;; FiveAM Unit Tests for elmtui.ui.widgets.utils
;;;===============================================================

(uiop:define-package :elmtui-ui-widgets-utils-tests
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.widgets.utils
                #:get-widget-model
                #:widget-focused-p
                #:with-widget-model
                #:defwidget-view)
  (:import-from :elmtui.state #:make-application-state #:set-state #:state-ref)
  (:import-from :elmtui.ui.widgets.utils #:current-focus-id)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:export :run-elmtui-ui-widgets-utils-tests))

(in-package :elmtui-ui-widgets-utils-tests)

(def-suite elmtui-ui-widgets-utils-suite
  :description "Unit tests for elmtui.ui.widgets.utils")
(in-suite elmtui-ui-widgets-utils-suite)

(test get-widget-model-basic
  (let ((app-state (elmtui.state:make-application-state)))
    (elmtui.state:set-state app-state :my-widget '(:foo 42 :bar "baz"))
    (is (equal (get-widget-model app-state :my-widget) '(:foo 42 :bar "baz")))
    (is (null (get-widget-model app-state :nonexistent)))
    ;; Test with model-path
    (elmtui.state:set-state app-state '(widgets) (list :widget-a '(:val 1) :widget-b '(:val 2)))
    (is (equal (get-widget-model app-state :widget-a '(widgets)) '(:val 1)))
    (is (equal (get-widget-model app-state :widget-b '(widgets)) '(:val 2)))))

(test widget-focused-p-basic
  (let ((app-state (elmtui.state:make-application-state)))
    (elmtui.state:set-state app-state :current-focus-id :foo)
    (is (widget-focused-p app-state :foo))
    (is (not (widget-focused-p app-state :bar)))))

(test with-widget-model-macro
  (let ((app-state (elmtui.state:make-application-state)))
    (elmtui.state:set-state app-state :my-widget '(:foo 123))
    (elmtui.state:set-state app-state :current-focus-id :my-widget)
    (with-widget-model (model app-state :my-widget)
      (is (equal model '(:foo 123)))
      (is (eq (elmtui.state:state-ref app-state :current-focus-id) :my-widget)))))

;; Define test button model structure for defwidget-view testing
(defstruct test-button-model
  (id nil :type symbol)
  (label "Button" :type string)
  (disabled nil :type boolean)
  (on-click nil :type (or null keyword function)))

(test defwidget-view-macro-basic
  "Test basic functionality of the defwidget-view macro"
  ;; Define a dummy widget view using the macro and test its expansion
  (defwidget-view test-view (app-state
                             :model-var model
                             :widget-id-var widget-id
                             :add-args
                             (extra) :documentation "Test widget view.")
    (let ((is-focused (widget-focused-p app-state widget-id)))
      ;; Create a styled node with the given type and properties
      ;; Use the model to set the extra property and focused state
      (make-styled-node :type :dummy :props
                        (list :id widget-id :extra extra :focused is-focused))))

  (let ((app-state (elmtui.state:make-application-state)))
    (elmtui.state:set-state app-state :dummy-widget '(:foo 1))
    (elmtui.state:set-state app-state :current-focus-id :dummy-widget)
    (let ((result (test-view app-state :widget-id :dummy-widget :extra 99)))
      (is (eq (elmtui.view.core:ui-node-type result) :dummy))
      (is (= (getf (elmtui.view.core:ui-node-props result) :extra) 99))
      (is (getf (elmtui.view.core:ui-node-props result) :focused)))))

(test defwidget-view-with-model-path
  "Test defwidget-view macro with model-path argument"
  ;; Define a widget view with model-path
  (defwidget-view test-view-with-path
      (app-state
       :model-var model
       :widget-id-var widget-id
       :model-path 'buttons
       :documentation "Test widget view with path.")

    (let ((is-focused (widget-focused-p app-state widget-id)))
      ;; Create a styled button node
      ;; Use the model to set the label and focused state
      (make-styled-node
       :type :button
       :props (list :id widget-id
                    :label (if model (getf model :label) "Default")
                    :focused is-focused))))

  (let ((app-state (elmtui.state:make-application-state)))
    ;; Setup a buttons collection with widget models
    (elmtui.state:set-state app-state 'buttons
                            (list :btn1 (list :label "Button 1")
                                  :btn2 (list :label "Button 2")))
    (elmtui.state:set-state app-state :current-focus-id :btn2)

    ;; Test first button (not focused)
    (let ((result-btn1 (test-view-with-path app-state :widget-id :btn1)))
      (is (eq (elmtui.view.core:ui-node-type result-btn1) :button))
      (is (equal (getf (elmtui.view.core:ui-node-props result-btn1) :label) "Button 1"))
      (is (not (getf (elmtui.view.core:ui-node-props result-btn1) :focused))))

    ;; Test second button (focused)
    (let ((result-btn2 (test-view-with-path app-state :widget-id :btn2)))
      (is (eq (elmtui.view.core:ui-node-type result-btn2) :button))
      (is (equal (getf (elmtui.view.core:ui-node-props result-btn2) :label) "Button 2"))
      (is (getf (elmtui.view.core:ui-node-props result-btn2) :focused)))

    ;; Test non-existent button (should use default label)
    (let ((result-missing (test-view-with-path app-state :widget-id :btn3)))
      (is (eq (elmtui.view.core:ui-node-type result-missing) :button))
      (is (equal (getf (elmtui.view.core:ui-node-props result-missing) :label) "Default"))
      (is (not (getf (elmtui.view.core:ui-node-props result-missing) :focused))))))

(test defwidget-view-realistic-example
  "Test defwidget-view with a more realistic button widget example"
  ;; Define a realistic button view function
  (defwidget-view test-button-view
      (app-state
       :widget-id-var widget-id
       :model-var button-model
       :documentation "Realistic button widget view.")
    (let ((is-focused (widget-focused-p app-state widget-id)))
      ;; Create a styled button node
      (make-styled-node
       :type :button
       :props (list :id widget-id
                    :class (if is-focused "button focused" "button")
                    :disabled (when button-model (test-button-model-disabled button-model))
                    :label (if button-model
                               (test-button-model-label button-model)
                               "Default Button")
                    :on-click (when button-model (test-button-model-on-click button-model))))))

  (let ((app-state (elmtui.state:make-application-state)))
    ;; Create a button model
    (let ((button (make-test-button-model
                   :id :test-btn
                   :label "Click Me"
                   :disabled nil
                   :on-click :button-clicked)))

      ;; Add to app state
      (elmtui.state:set-state app-state :test-btn button)
      (elmtui.state:set-state app-state :current-focus-id :test-btn)

      ;; Test rendering
      (let ((result (test-button-view app-state :widget-id :test-btn)))
        (is (eq (elmtui.view.core:ui-node-type result) :button))
        (is (equal (getf (elmtui.view.core:ui-node-props result) :label) "Click Me"))
        (is (equal (getf (elmtui.view.core:ui-node-props result) :class) "button focused"))
        (is (eq (getf (elmtui.view.core:ui-node-props result) :on-click) :button-clicked))
        (is (not (getf (elmtui.view.core:ui-node-props result) :disabled))))

      ;; Test disabled button
      (setf (test-button-model-disabled button) t)
      (elmtui.state:set-state app-state :test-btn button)

      (let ((result (test-button-view app-state :widget-id :test-btn)))
        (is (getf (elmtui.view.core:ui-node-props result) :disabled))))))
(defun run-elmtui-ui-widgets-utils-tests ()
  (fiveam:run! 'elmtui-ui-widgets-utils-suite))
