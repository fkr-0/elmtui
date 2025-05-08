;;;===============================================================
;;; File: src/ui/primitives.lisp
;;; Primitive Widgets
;;;===============================================================
(uiop:define-package :elmtui.ui.primitives
  (:use :cl :elmtui.ui.base :elmtui.view.core) ; Keep :use for elm-widget class
  (:import-from :elmtui.ui.base #:widget-id #:widget-props #:widget-handlers #:widget-render) ; Explicitly import accessors/generics
  (:import-from :elmtui.core.events #:cmd #:message #:send-message #:message-type) ; Added message-type
  (:import-from :elmtui.core.async #:cmd-async #:cmd-batch) ; For potential commands
  (:export)) ; Removed :input-widget, :label-widget. All primitives refactored.
(in-package :elmtui.ui.primitives)

;;;---------------------------------------------------------------
;;; Label Widget (REMOVED - Now in src/ui/widgets/label.lisp)
;;;---------------------------------------------------------------
;;; The label-widget class and its methods (widget-render, widget-update)
;;; have been removed from this file.
;;; Please use the Elm-style component defined in
;;; elmtui.ui.widgets.label.
;;;---------------------------------------------------------------

;;;---------------------------------------------------------------
;;; Button Widget (REMOVED - Now in src/ui/widgets/button.lisp)
;;;---------------------------------------------------------------
;;; The button-widget class and its methods (widget-render, widget-update)
;;; have been removed from this file.
;;; Please use the Elm-style component defined in
;;; elmtui.ui.widgets.button.
;;;---------------------------------------------------------------

;;;---------------------------------------------------------------
;;; Input Widget (REMOVED - Now in src/ui/widgets/textinput.lisp)
;;;---------------------------------------------------------------
;;; The input-widget class and its methods (widget-render, widget-update, widget-init)
;;; have been removed from this file.
;;; Please use the Elm-style component defined in
;;; elmtui.ui.widgets.textinput.
;;;---------------------------------------------------------------
