;;;===============================================================
;;; File: src/ui/base.lisp
;;; Base Widget API
(uiop:define-package :elmtui.ui.base
  (:use :cl)
  (:export :elm-widget
           :widget-init
           :widget-update
           :widget-render))
(in-package :elmtui.ui.base)

(defclass elm-widget ()
  ((id         :initarg :id         :accessor widget-id)
   (props      :initarg :props      :accessor widget-props)
   (children   :initarg :children   :accessor widget-children)
   (handlers   :initarg :handlers   :accessor widget-handlers))
  (:documentation "Base class for all UI widgets.
   Contract: slots id, props, children, handlers."))

(defmethod widget-init ((w elm-widget))
  "Initialize W."
  ;; stub
  )

(defmethod widget-update ((w elm-widget) msg)
  "Handle MSG for W, return (new-widget Cmds).
   Contract: pure-state transitions, side-effects only in Cmds."
  ;; stub
  )

(defmethod widget-render ((w elm-widget))
  "Produce a UiNode for W."
  ;; stub
  )
