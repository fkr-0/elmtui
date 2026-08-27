(uiop:define-package :elmtui.tests.enhanced-widgets (:use :cl :fiveam) (:import-from :elmtui.ui.api #:view) (:import-from :elmtui.ui.widgets.label-enhanced #:label-enhanced #:make-label-state) (:import-from :elmtui.ui.widgets.button-enhanced #:make-button-state #:validate-button-state) (:export #:run-enhanced-widget-tests))

(in-package :elmtui.tests.enhanced-widgets)

(def-suite enhanced-widget-tests :description "Enhanced widget contract regressions")

(in-suite enhanced-widget-tests)

(test enhanced-label-view-uses-computed-style (let* ((component (make-instance 'label-enhanced)) (model (make-label-state :text "Styled" :text-color :red :font-weight :bold)) (app-state (cl-state.core:make-state :initial (alexandria:plist-hash-table (list :components (list :label model))))) (dsl (view component app-state :id-path ' (:components :label))) (style (getf (rest dsl) :style))) (is (eq :red (getf style :color))) (is (eq :bold (getf style :font-weight)))))

(test enhanced-button-action-contract-remains-open (let* ((action ' (:emit :value :confirmed)) (model (make-button-state :text "Go" :action action)) (nil-model (make-button-state :text "No action" :action nil))) (is (eq model (validate-button-state model))) (is (equal action (getf model :action))) (is (eq nil-model (validate-button-state nil-model))) (is (null (getf nil-model :action)))))

(defun run-enhanced-widget-tests () "Run focused enhanced-widget regression tests." (run! 'enhanced-widget-tests))
