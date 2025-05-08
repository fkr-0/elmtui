(uiop:define-package :elmtui
  (:use :cl
   :elmtui.ui.primitives
        :elmtui.ui.composite
   :elmtui.style.core
        :elmtui.style.presets )
  ;; Removed all old widget exports (:button-widget, :label-widget, :input-widget, :form-widget, :list-widget)
  (:export :dark-theme :light-theme) ; Export themes or other top-level items
  (:nicknames :elmtui)
  ;; Added re-export for all new widget packages
  (:reexport :elmtui.style-lib
   :elmtui.view.core
             :elmtui.platform.input
   :elmtui.platform.output
             :elmtui.platform.driver
             :elmtui.ui.widgets.button      ; Re-export new button symbols
             :elmtui.ui.widgets.label       ; Re-export new label symbols
             :elmtui.ui.widgets.textinput   ; Re-export new textinput symbols
             :elmtui.ui.widgets.form        ; Re-export new form symbols
             :elmtui.ui.widgets.listbox)    ; Re-export new listbox symbols

  (:export :message
   :cmd :send-message :dev-main))
(in-package :elmtui)
(defun dev-main ()
  (format t "huhu"))
