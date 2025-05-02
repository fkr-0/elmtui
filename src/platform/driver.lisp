;;;===============================================================
;;; File: src/platform/driver.lisp
;;; Platform Driver
(uiop:define-package :elmtui.platform.driver
  (:use :cl
        :elmtui.platform.input
        :elmtui.platform.output
        :elmtui.core.loop)
  (:export :run-platform))
(in-package :elmtui.platform.driver)

(defun run-platform ()
  "Wire input, loop, and output: start-reader, start-loop, render on each update.
   Contract: wire start-reader, start-loop, render-frame on every update; clean shutdown."
  ;; stub
  )
