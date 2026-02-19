(uiop:define-package #:elmtui.app.dsl-type-registry
  (:use #:cl)
  (:import-from #:elmtui.ui.dsl-resolution #:dsl-type))

(in-package #:elmtui.app.dsl-type-registry)

;;; Register built-in DSL types to component classes.
;;;
;;; NOTE: This file is being phased out as we transition to the new polymorphic
;;; DSL resolution system. The old registry-based approach has been replaced
;;; with CLOS generic functions (dsl-type).
;;;
;;; The defcomponent macro will eventually auto-generate dsl-type methods for
;;; each component, eliminating the need for manual registration.
;;;
;;; For now, we provide dsl-type methods for the built-in components to maintain
;;; compatibility during the transition.

;;; Root viewport
(defmethod dsl-type ((type (eql :root-viewport)) &optional props)
  (values 'elmtui.ui.widgets.root-viewport:root-viewport props))

;;; Key tester widget (example)
(defmethod dsl-type ((type (eql :key-tester-widget)) &optional props)
  (values 'example.key-tester:key-tester props))

;;; Viewport
(defmethod dsl-type ((type (eql :viewport)) &optional props)
  (values 'elmtui.ui.widgets.viewport:viewport props))

;;; Grid container
(defmethod dsl-type ((type (eql :grid-container)) &optional props)
  (values 'elmtui.ui.widgets.grid-container:grid-container props))

;;; Layout
(defmethod dsl-type ((type (eql :layout)) &optional props)
  (values 'elmtui.ui.widgets.layout:layout props))

;;; Text (alias for label)
(defmethod dsl-type ((type (eql :text)) &optional props)
  (values 'elmtui.ui.widgets.label:label props))
