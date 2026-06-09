;;;===============================================================
;;; File: src/state/observers.lisp
;;; Thin wrapper over cl-state.observer
;;;===============================================================
(uiop:define-package :elmtui.state.observers
  (:use :cl :cl-state.observer)
  (:reexport :cl-state.observer))

(in-package :elmtui.state.observers)
