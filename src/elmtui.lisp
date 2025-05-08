(uiop:define-package :elmtui
  (:use :cl
   :elmtui.ui.primitives
        :elmtui.ui.composite
   :elmtui.style.core
        :elmtui.style.presets )
  (:export :button-widget :input-widget :label-widget
   :form-widget :list-widget
   :dark-theme :light-theme)
  (:nicknames :elmtui)
  (:reexport :elmtui.style-lib
   :elmtui.view.core
             :elmtui.platform.input
   :elmtui.platform.output
             :elmtui.platform.driver)

  (:export :message
   :cmd :send-message :dev-main))
(in-package :elmtui)
(defun dev-main ()
  (format t "huhu"))
