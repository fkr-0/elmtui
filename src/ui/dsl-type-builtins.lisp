(uiop:define-package :elmtui.ui.dsl-type-builtins
  (:use :cl)
  (:import-from :elmtui.ui.dsl-resolution #:dsl-type #:register-dsl-type))

(in-package :elmtui.ui.dsl-type-builtins)

;; Built-in UI component aliases owned by the UI layer.
(defmethod dsl-type ((type (eql :root-viewport)) &optional props)
  (values 'elmtui.ui.widgets.root-viewport:root-viewport props))
(register-dsl-type :root-viewport 'elmtui.ui.widgets.root-viewport:root-viewport)

(defmethod dsl-type ((type (eql :viewport)) &optional props)
  (values 'elmtui.ui.widgets.viewport:viewport props))
(register-dsl-type :viewport 'elmtui.ui.widgets.viewport:viewport)

;; Keep :text as a convenience alias for the label component.
(defmethod dsl-type ((type (eql :text)) &optional props)
  (values 'elmtui.ui.widgets.label:label props))
(register-dsl-type :text 'elmtui.ui.widgets.label:label)
