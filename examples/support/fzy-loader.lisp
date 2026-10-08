(uiop:define-package :elmtui.examples.fzy-loader (:use :cl) (:export #:ensure-cl-fzy))

(in-package :elmtui.examples.fzy-loader)

(eval-when (:compile-toplevel :load-toplevel :execute) (defun ensure-cl-fzy () "Load the optional cl-fzy dependency or signal a concise actionable error." (handler-case (asdf:load-system "cl-fzy") (error () (error "elmtui-examples-fzy requires optional dependency cl-fzy. Add cl-fzy to the active CLPM bundle, or use the built-in fzf-finder-real example.")))) (ensure-cl-fzy))
