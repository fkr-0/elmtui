;;;===============================================================
;;; File: src/platform/input.lisp
;;; Platform Input Adapter
(uiop:define-package :elmtui.platform.input
  (:use :cl
        :elmtui.core.loop)
  (:export :start-reader
           :stop-reader))
(in-package :elmtui.platform.input)

(defun start-reader ()
  "Spawn a thread reading terminal events, mapping to Msgs via send-message.
   Contract: reader must convert terminal codes → message via send-message."
  ;; stub
  )

(defun stop-reader ()
  "Stop the input reader thread."
  ;; stub
  )
