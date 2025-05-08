;;;===============================================================
;;; File: src/ui/base.lisp
;;; Base UI definitions (DEPRECATED)
;;;===============================================================
(uiop:define-package :elmtui.ui.base
  (:use :cl)
  ;; No exports needed as the class-based approach is removed.
  (:documentation "DEPRECATED: Base definitions for UI components.
                   The class-based elm-widget approach has been replaced by
                   individual Elm-style widget modules in src/ui/widgets/.
                   This file remains temporarily for historical reference
                   and potential utility functions in the future, but
                   exports no core widget functionality."))
(in-package :elmtui.ui.base)

;; NOTE: The elm-widget class, widget-init, widget-update, widget-render
;; generics, and their methods previously defined here have been removed
;; as part of the refactoring towards an Elm-style architecture.
;; Please refer to the individual widget modules in src/ui/widgets/.
