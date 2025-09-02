;;; src/state/packages.lisp
(uiop:define-package :cl-state.patch
  (:use :cl :alexandria)
  (:export
   #:patch #:make-patch #:patch-path #:patch-op #:patch-value
   #:apply-patch #:apply-patches #:diff-states))

(uiop:define-package :cl-state.tx
  (:use :cl :alexandria :cl-state.patch)
  (:export
   #:tx-context #:make-tx-context
   #:with-transaction #:tx-commit #:tx-rollback))

(uiop:define-package :cl-state.undo
  (:use :cl :alexandria :cl-state.patch)
  (:export
   #:undo-stack #:redo-stack #:push-snapshot #:undo #:redo))

(uiop:define-package :cl-state.observer
  (:use :cl :alexandria :cl-state.patch)
  (:export
   #:add-observer #:remove-observer #:notify-observers))

(uiop:define-package :cl-state.api
  (:use :cl)
  (:reexport :cl-state.patch :cl-state.tx :cl-state.undo :cl-state.observer))