;;;===============================================================
;;; File: src/style/core.lisp
;;; Styling Core (cl-styles integration)
(uiop:define-package :elmtui.style.core
  (:use :cl)
  (:export))
(in-package :elmtui.style.core)

;; Placeholder module retained to keep ASDF module structure stable while
;; migrating off the legacy style-lib. This file intentionally contains no
;; runtime coupling to style-lib and defines no state.
