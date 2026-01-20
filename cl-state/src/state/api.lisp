;;; cl-state/src/state/api.lisp
;;;
;;; Public API for cl-state
;;; This file serves as the main entry point that re-exports all public symbols
;;; from the cl-state subsystems (utils, core, patch, tx, observer, undo).

(in-package :cl-state.api)

;;; The api.lisp file intentionally contains only package definitions and re-exports.
;;; All actual functionality is provided by the subsystems which are re-exported
;;; via the package definition in packages.lisp.
;;;
;;; To use cl-state, simply use the :cl-state.api package:
;;;   (use-package :cl-state.api)
;;;
;;; Or require individual subsystems:
;;;   (use-package :cl-state.core)
;;;   (use-package :cl-state.patch)
;;;   etc.
