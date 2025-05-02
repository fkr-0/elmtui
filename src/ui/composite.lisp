;;;===============================================================
;;; File: src/ui/composite.lisp
;;; Composite Widgets
;;;===============================================================
(uiop:define-package :elmtui.ui.composite
  (:use :cl
        :elmtui.ui.base
        :elmtui.view.core) ; For ui-node
  (:export :form-widget
           :list-widget))
(in-package :elmtui.ui.composite)

;;;---------------------------------------------------------------
;;; Form Widget
;;;---------------------------------------------------------------

(defclass form-widget (elm-widget)
  ()
  (:documentation "A composite form of fields and buttons.
   Contract: implements init/update/render per base API.
   Renders its children within a container. Layout is determined by styles."))

(defmethod widget-render ((w form-widget))
  "Renders the form by rendering its children within a container node.
   Adds a 'form' class for styling."
  (let ((child-nodes (mapcar #'widget-render (widget-children w))))
    (make-ui-node :type :container
                  :props (list* :class "form" :widget-id (widget-id w) (widget-props w))
                  :children child-nodes)))

(defmethod widget-update ((w form-widget) msg)
  "Handles messages, potentially delegating to children.
   Succinct version: Does nothing for now."
  (declare (ignore msg))
  ;; TODO: Implement message delegation based on msg target/widget-id
  (values w nil))

;;;---------------------------------------------------------------
;;; List Widget
;;;---------------------------------------------------------------

(defclass list-widget (elm-widget)
  (;; Potential internal state for scroll position, selection etc.
   ;; (scroll-offset :initform 0)
   ;; (selected-index :initform nil)
   )
  (:documentation "A scrollable list of items.
   Contract: implements init/update/render per base API.
   Renders its children (items) within a container. Scrollability requires platform support."))

(defmethod widget-render ((w list-widget))
  "Renders the list by rendering its children within a container node.
   Adds a 'list' class for styling. Assumes children are widgets."
  (let ((item-nodes (mapcar #'widget-render (widget-children w))))
    ;; TODO: Handle scrolling - only render visible items based on scroll-offset and container height.
    (make-ui-node :type :container
                  :props (list* :class "list" :widget-id (widget-id w) (widget-props w))
                  :children item-nodes)))

(defmethod widget-update ((w list-widget) msg)
  "Handles messages, potentially for selection, scrolling.
   Succinct version: Does nothing for now."
  (declare (ignore msg))
  ;; TODO: Implement scrolling logic (e.g., on :scroll-up/:scroll-down messages)
  ;; TODO: Implement selection logic
  (values w nil))
