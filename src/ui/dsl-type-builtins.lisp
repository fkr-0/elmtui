(uiop:define-package :elmtui.ui.dsl-type-builtins
  (:use :cl)
  (:import-from :elmtui.ui.dsl-resolution #:dsl-type))

(in-package :elmtui.ui.dsl-type-builtins)

;; Built-in UI component aliases owned by the UI layer.
(defmethod dsl-type ((type (eql :root-viewport)) &optional props)
  (values 'elmtui.ui.widgets.root-viewport:root-viewport props))

(defmethod dsl-type ((type (eql :viewport)) &optional props)
  (values 'elmtui.ui.widgets.viewport:viewport props))

;; Keep :text as a convenience alias for the label component.
(defmethod dsl-type ((type (eql :text)) &optional props)
  (values 'elmtui.ui.widgets.label:label props))
