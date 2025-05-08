;;;===============================================================
;;; File: src/ui/widgets.lisp
;;; Main package for Elm-style UI Widgets.
;;; Re-exports symbols from individual widget packages.
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets
  (:use :cl)
  (:use-reexport
   :elmtui.ui.widgets.utils
   :elmtui.ui.widgets.button
   :elmtui.ui.widgets.label
   :elmtui.ui.widgets.textinput
   :elmtui.ui.widgets.listbox
   :elmtui.ui.widgets.scrollable-container)
  (:documentation "Provides Elm-style UI widgets.
Each widget (button, label, textinput, listbox, scrollable-container)
is defined in its own package (e.g., elmtui.ui.widgets.button)
and re-exported here for convenience.

Each widget typically follows the Elm Architecture pattern with:
- A model struct (e.g., button-model)
- An init function to create an initial model (e.g., init-button-model).
- An update function (model, msg, props) -> (values new-model cmd) (e.g., update-button-model)
- A view function (model, dispatch-fn, props) -> ui-node-description (e.g., view-button-model)
- Widget-specific message types (e.g., button-msg)."))
(in-package :elmtui.ui.widgets)

;; All exports are handled by :use-reexport above.
;; No further definitions needed in this file.
