;;;===============================================================
;;; File: src/ui/composite.lisp
;;; Composite Widgets
;;;===============================================================
(uiop:define-package :elmtui.ui.composite
  (:use :cl :elmtui.ui.base :elmtui.view.core) ; Keep :use for elm-widget class
  (:import-from :elmtui.ui.base #:widget-id #:widget-props #:widget-children #:widget-render) ; Explicitly import accessors/generics
  (:export)) ; Removed :list-widget, :form-widget. All composites refactored.
(in-package :elmtui.ui.composite)

;;;---------------------------------------------------------------
;;; Form Widget (REMOVED - Now in src/ui/widgets/form.lisp)
;;;---------------------------------------------------------------
;;; The form-widget class and its methods (widget-render, widget-update)
;;; have been removed from this file.
;;; Please use the Elm-style component defined in
;;; elmtui.ui.widgets.form.
;;;---------------------------------------------------------------

;;;---------------------------------------------------------------
;;; List Widget (REMOVED - Now in src/ui/widgets/listbox.lisp)
;;;---------------------------------------------------------------
;;; The list-widget class and its methods (widget-render, widget-update)
;;; have been removed from this file.
;;; Please use the Elm-style component defined in
;;; elmtui.ui.widgets.listbox.
;;;---------------------------------------------------------------
