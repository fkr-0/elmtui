;;;===============================================================
;;; File: src/ui/widgets.lisp
;;; Main package for Standardized Elm-style UI Widgets.
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets
  (:use :cl)
  (:use-reexport
   :elmtui.ui.widgets.utils
   :elmtui.ui.widgets.button
   :elmtui.ui.widgets.label
   :elmtui.ui.widgets.textinput
   :elmtui.ui.widgets.listbox
   :elmtui.ui.widgets.scrollable-container
   :elmtui.ui.widgets.grid-container
   ;; :elmtui.ui.widgets.form
   ;; TODO: Add more specialized widgets as needed
   )
  (:documentation "Provides standardized Elm-style UI widgets.

   Each widget follows the unified Widget Pattern with:

   1. Model Structure:
      - widget-model with standard and custom fields

   2. Core Functions:
      - init-widget: Initialize the widget model and any commands
      - update-widget: Process messages and update the model
      - view-widget: Render the widget based on app-state and widget-id

   3. Standard Signature:
      All widget view functions follow this signature:
      (defun view-widget (app-state &key widget-id prop1 prop2 ...)

   This package re-exports all standardized widget modules for convenience."))
(in-package :elmtui.ui.widgets)

;; This file only provides the package definition and documentation.
;; All functionality is imported from the individual widget modules.
