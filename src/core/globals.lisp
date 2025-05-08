;;;===============================================================
;;; File: src/core/globals.lisp
;;; Global Variables and Definitions needed early
;;;===============================================================
(uiop:define-package :elmtui.core.globals
  (:use :cl)
  (:export :*app-sender*))
(in-package :elmtui.core.globals)

(defvar *app-sender* (lambda (msg) (format t "[WARN] *app-sender* not defined. Dropping msg: ~S~%" msg))
  "Dynamically bound function to send messages back to the application's update loop.")
