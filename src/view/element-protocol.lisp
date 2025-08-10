;; == elmtui/core/element-protocol.lisp ==
(uiop:define-package :elmtui.view.element
  (:use :cl)
  (:import-from :elmtui.view.base-elements
   :base-element :element-children :element-props
                :element-style :element-type :element-id)
  (:import-from :elmtui.view.geo
   :rectangle)
  (:export
   ;; predicates
   #:element-p
   ;; core getters
   #:el/children #:el/props #:el/styles #:el/type #:el/id
   #:el/layout-rect #:el/display
   ;; setters
   ;; helpers
   #:ensure-element
   #:with-element
   #:el/styles-of
   ))

(in-package :elmtui.view.element)

(defgeneric element-p (x))

(defgeneric el/children (el))
(defgeneric el/props    (el))
(defgeneric el/styles   (el))
(defgeneric el/type     (el))
(defgeneric el/id       (el))
(defgeneric el/layout-rect (el))
;; (defgeneric (setf el/layout-rect) (rect el))
(defgeneric el/styles-of   (el  style &optional default))
(defgeneric el/display  (el))

(defmacro with-element ((var obj) &body body)
  "Assert OBJ is an element (via protocol); bind VAR to OBJ for BODY."
  `(let ((,var (ensure-element ,obj)))
     ,@body))

(defgeneric ensure-element (x)
  (:documentation "Return X if element-p, otherwise try to adapt or error."))
;; == end/element-protocol.lisp ==
;; == elmtui/core/element-base-impl.lisp ==

(defmethod element-p ((x base-element)) t)
(defmethod ensure-element ((x base-element)) x)

(defmethod el/children ((el base-element)) (element-children el))
(defmethod el/props    ((el base-element)) (element-props el))
(defmethod el/styles   ((el base-element)) (elmtui.view.base-elements:element-style el))
(defmethod el/styles-of   ((el base-element) style &optional default)
  (getf (elmtui.view.base-elements:element-style el) style default))
(defmethod el/type     ((el base-element)) (element-type el))
(defmethod el/id       ((el base-element)) (element-id el))

(defmethod el/layout-rect ((el base-element))
  (elmtui.view.base-elements:element-layout-rect el))
(defmethod (setf el/layout-rect) ((rect rectangle) (el base-element))
  (setf (elmtui.view.base-elements:element-layout-rect el) rect))

(defmethod el/display ((el base-element))
  ;; style wins; default :block
  (or (getf (element-style el) :display) :block))
;; == end/element-base-impl.lisp ==
