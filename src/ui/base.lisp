;;;===============================================================
;;; File: src/ui/base.lisp
;;; Base UI definitions (placeholder, to be refactored for Elm architecture)
;;;===============================================================
(uiop:define-package :elmtui.ui.base
  (:use :cl)
  (:export #:elm-widget #:widget-id #:widget-props #:widget-children #:widget-handlers
           #:widget-init #:widget-update #:widget-render) ; Export class and generics
  (:documentation "Base definitions for UI components.
                   Following Elm architecture, widgets are typically defined as modules
                   with their own model, messages, update, and view functions.
                   A central 'application-state' holds the models of all components.
                   This file is a placeholder and may be refactored or removed
                   as widgets are implemented in a more Elm-idiomatic way."))
(in-package :elmtui.ui.base)

;; NOTE: The concept of a base 'elm-widget' class is being de-emphasized
;; in favor of widgets as modules with pure functions and data (models).
;; Generic functions like widget-update and widget-render might still be useful
;; if they dispatch on model types, or they might be replaced by specific
;; update-<widget> and view-<widget> functions.

;; Define the base class and its slots/accessors
(defclass elm-widget ()
  ((id         :initarg :id         :reader widget-id) ; Use reader for now
   (props      :initarg :props      :accessor widget-props) ; Use accessor if props might change
   (children   :initarg :children   :accessor widget-children) ; Use accessor
   (handlers   :initarg :handlers   :accessor widget-handlers)) ; Use accessor
  (:documentation "Base class for UI widgets (potentially being phased out)."))

;; Define generic functions for widget operations
(defgeneric widget-init (widget &key &allow-other-keys)
  (:documentation "Initializes a widget. Returns the widget (or its initial state)."))

(defgeneric widget-update (widget message &key &allow-other-keys)
  (:documentation "Updates a widget based on a message.
                   Returns (values new-widget/state commands)."))

(defgeneric widget-render (widget &key &allow-other-keys)
  (:documentation "Renders a widget to a UI description (e.g., ui-node)."))

;; Default methods (can be specialized by subclasses)
(defmethod widget-init ((w elm-widget) &key &allow-other-keys)
  ;; Default init might do nothing or return the widget itself
  w)

(defmethod widget-update ((w elm-widget) message &key &allow-other-keys)
  ;; Default update returns the widget unchanged and no commands
  (declare (ignore message))
  (values w nil))

(defmethod widget-render ((w elm-widget) &key &allow-other-keys)
  ;; Default render returns nil or a placeholder node
  nil)

;; Define generic functions for the accessors (needed if using reader/accessor in defclass)
;; Although defclass generates methods for reader/accessor, defining generics can be good practice.
(defgeneric widget-id (widget))
(defgeneric widget-props (widget))
(defgeneric (setf widget-props) (value widget))
(defgeneric widget-children (widget))
(defgeneric (setf widget-children) (value widget))
(defgeneric widget-handlers (widget))
(defgeneric (setf widget-handlers) (value widget))

;; (defgeneric widget-update (model message &key &allow-other-keys)
;;   (:documentation "Updates a widget's model based on a message.
;;                    Returns (values new-model commands)."))

;; (defgeneric widget-render (model dispatch-fn &key &allow-other-keys)
;;   (:documentation "Renders a widget's model to a UI description.
;;                    'dispatch-fn' is used by the view to send messages."))
