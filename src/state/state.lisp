;;;===============================================================
;;; File: src/state/state.lisp
;;; Facade package that reexports state APIs.
;;;===============================================================
(uiop:define-package :elmtui.state
  (:use :cl)
  ;; Both CL-STATE.PATCH (via CL-STATE.API) and ELMTUI.STATE.MODEL export a
  ;; DIFF-STATES; export the CL-STATE one, as ELMTUI.STATE.API does.
  (:shadowing-import-from :cl-state.patch #:diff-states)
  ;; :USE-REEXPORT (not :REEXPORT, which only exports by name) so these are
  ;; the bound symbols of the listed packages.
  (:use-reexport :cl-state.api
             :cl-state.tx
             :cl-state.observer
             :elmtui.state.api
             :elmtui.state.msg
             :elmtui.state.update
             :elmtui.state.model))

(in-package :elmtui.state)
