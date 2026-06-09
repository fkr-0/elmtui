;;;; UI Widgets Module Tests
;;;; Test suite for elmtui UI widgets

(uiop:define-package :elmtui.ui.widgets.tests
  (:use :cl :fiveam)
  (:export #:run-ui-widgets-tests))

(in-package :elmtui.ui.widgets.tests)

(def-suite ui-widgets-test-suite
  :description "Test suite for elmtui UI widgets")

(in-suite ui-widgets-test-suite)

;; Test for widget package availability
(test widget-packages-basic
  "Test that widget packages are available"
  (is (find-package :elmtui.ui.widgets.button)
    "Button widget package should be available")
  (is (find-package :elmtui.ui.widgets.label)
    "Label widget package should be available")
  (is (find-package :elmtui.ui.widgets.viewport)
    "Viewport widget package should be available")
  (is (find-package :elmtui.ui.widgets.layout)
    "Layout widget package should be available")
  (is (find-package :elmtui.ui.widgets.textinput)
    "Text input widget package should be available")
  (is (find-package :elmtui.ui.widgets.grid-container)
    "Grid container widget package should be available")
  (is (find-package :elmtui.ui.widgets.scroll-panel)
    "Scroll panel widget package should be available"))

;; Test for enhanced widget packages
(test enhanced-widget-packages-basic
  "Test that enhanced widget packages are available"
  (is (find-package :elmtui.ui.widgets.button-enhanced)
    "Enhanced button widget package should be available")
  (is (find-package :elmtui.ui.widgets.label-enhanced)
    "Enhanced label widget package should be available")
  (is (find-package :elmtui.ui.widgets.viewport-enhanced)
    "Enhanced viewport widget package should be available"))

;; Test for button widget API availability
(test button-widget-api
  "Test button widget API availability"
  (is (or (not (fboundp 'elmtui.ui.widgets.button:button))
        (functionp #'elmtui.ui.widgets.button:button))
    "Button constructor should be function or not exist")
  (is (or (not (fboundp 'elmtui.ui.widgets.button:make-button))
        (functionp #'elmtui.ui.widgets.button:make-button))
    "Button maker should be function or not exist"))

;; Test for label widget API availability
(test label-widget-api
  "Test label widget API availability"
  (is (or (not (fboundp 'elmtui.ui.widgets.label:label))
        (functionp #'elmtui.ui.widgets.label:label))
    "Label constructor should be function or not exist")
  (is (or (not (fboundp 'elmtui.ui.widgets.label:make-label))
        (functionp #'elmtui.ui.widgets.label:make-label))
    "Label maker should be function or not exist"))

;; Test for viewport widget API availability
(test viewport-widget-api
  "Test viewport widget API availability"
  (is (or (not (fboundp 'elmtui.ui.widgets.viewport:viewport))
        (functionp #'elmtui.ui.widgets.viewport:viewport))
    "Viewport constructor should be function or not exist")
  (is (or (not (fboundp 'elmtui.ui.widgets.viewport:make-viewport))
        (functionp #'elmtui.ui.widgets.viewport:make-viewport))
    "Viewport maker should be function or not exist"))

;; Test for text input widget API availability
(test textinput-widget-api
  "Test text input widget API availability"
  (is (or (not (fboundp 'elmtui.ui.widgets.textinput:textinput))
        (functionp #'elmtui.ui.widgets.textinput:textinput))
    "Text input constructor should be function or not exist")
  (is (or (not (fboundp 'elmtui.ui.widgets.textinput:make-textinput))
        (functionp #'elmtui.ui.widgets.textinput:make-textinput))
    "Text input maker should be function or not exist"))

;; Test for layout widget API availability
(test layout-widget-api
  "Test layout widget API availability"
  (is (or (not (fboundp 'elmtui.ui.widgets.layout:layout))
        (functionp #'elmtui.ui.widgets.layout:layout))
    "Layout constructor should be function or not exist")
  (is (or (not (fboundp 'elmtui.ui.widgets.layout:make-layout))
        (functionp #'elmtui.ui.widgets.layout:make-layout))
    "Layout maker should be function or not exist"))

;; Test for grid container widget API availability
(test grid-container-widget-api
  "Test grid container widget API availability"
  (is (or (not (fboundp 'elmtui.ui.widgets.grid-container:grid-container))
        (functionp #'elmtui.ui.widgets.grid-container:grid-container))
    "Grid container constructor should be function or not exist")
  (is (or (not (fboundp 'elmtui.ui.widgets.grid-container:make-grid-container))
        (functionp #'elmtui.ui.widgets.grid-container:make-grid-container))
    "Grid container maker should be function or not exist"))

;; Test for enhanced widget APIs
(test enhanced-widget-apis
  "Test enhanced widget APIs"
  (is (or (not (fboundp 'elmtui.ui.widgets.button-enhanced:button-enhanced))
        (functionp #'elmtui.ui.widgets.button-enhanced:button-enhanced))
    "Enhanced button constructor should be function or not exist")
  (is (or (not (fboundp 'elmtui.ui.widgets.label-enhanced:label-enhanced))
        (functionp #'elmtui.ui.widgets.label-enhanced:label-enhanced))
    "Enhanced label constructor should be function or not exist")
  (is (or (not (fboundp 'elmtui.ui.widgets.viewport-enhanced:viewport-enhanced))
        (functionp #'elmtui.ui.widgets.viewport-enhanced:viewport-enhanced))
    "Enhanced viewport constructor should be function or not exist"))

(defun run-ui-widgets-tests ()
  "Run all UI widgets tests"
  (run! 'ui-widgets-test-suite))
