;;;===============================================================
;;; File: src/platform/output.lisp
;;; Platform Output Adapter
(uiop:define-package :elmtui.platform.output
  (:use :cl
        :elmtui.view.core
        :elmtui.view.layout)
  (:export :clear-screen
           :render-frame))
(in-package :elmtui.platform.output)

(defun clear-screen ()
  "Erase terminal display."
  ;; stub
  )

(defun render-frame (ui-tree)
  "Render UI-TREE to the terminal.
   Contract: consume styled + laid-out ui-node and draw to terminal."
  (declare (ignore ui-tree)) ; Ignore unused variable (stub function)
  ;; stub
  )
