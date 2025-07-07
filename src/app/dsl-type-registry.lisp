(uiop:define-package #:elmtui.app.dsl-type-registry
  (:use #:cl)
  (:import-from #:elmtui.app.api #:register-dsl-component-type))

(in-package #:elmtui.app.dsl-type-registry)

;;; Register built-in DSL types to component classes.
(register-dsl-component-type :label 'elmtui.ui.widgets.label:label)
(register-dsl-component-type :root-viewport 'elmtui.ui.widgets.root-viewport:root-viewport)
(register-dsl-component-type :viewport 'elmtui.ui.widgets.viewport:viewport)
(register-dsl-component-type :grid-container 'elmtui.ui.widgets.grid-container:grid-container)
;; (register-dsl-component-type :scrollable-container 'elmtui.ui.widgets.scrollable-container:scrollable-container)
;; (register-dsl-component-type :counter 'elmtui.ui.widgets.counter:counter)
(register-dsl-component-type :layout 'elmtui.ui.widgets.layout:layout)

;;; Sanity check (can be removed in production)
(assert (eq (elmtui.app.api:get-component-class-for-dsl-type :label)
            'elmtui.ui.widgets.label:label))
