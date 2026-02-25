(uiop:define-package :elmtui.cl-state.path-context
  (:use :cl)
  (:export #:compose-state-path))

(in-package :elmtui.cl-state.path-context)

(defun compose-state-path (base-path path)
  "Compose PATH onto BASE-PATH for state access/update contexts."
  (cond
    ((null base-path) path)
    ((null path) base-path)
    ((symbolp path) (append base-path (list path)))
    ((listp path) (append base-path path))
    (t path)))
