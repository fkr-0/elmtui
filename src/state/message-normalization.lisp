(uiop:define-package :elmtui.cl-state.message-normalization
  (:use :cl)
  (:export
   #:message-variant-p
   #:canonicalize-message-variant))

(in-package :elmtui.cl-state.message-normalization)

(defun message-variant-p (message-type message-instance)
  "Delegating boundary module for message variant checks used by state/contracts."
  (elmtui.state.msg:message-variant-p message-type message-instance))

(defun canonicalize-message-variant (message-type message-instance)
  "Delegating boundary module for message variant canonicalization."
  (elmtui.state.msg:canonicalize-message-variant message-type message-instance))
