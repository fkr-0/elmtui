;;;===============================================================
;;; File: src/state/state.lisp
;;; Facade package that reexports state APIs.
;;;===============================================================
(uiop:define-package :elmtui.state
  (:use :cl :cl-state.api :elmtui.state.api)
  (:reexport :cl-state.api
             :cl-state.tx
             :cl-state.observer
             :elmtui.state.api
             :elmtui.state.msg
             :elmtui.state.update
             :elmtui.state.model))

(in-package :elmtui.state)
