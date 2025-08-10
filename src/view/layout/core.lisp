(uiop:define-package :elmtui.view.layout
  (:use :cl)
  (:nicknames :et.layout)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.view.base-elements
                #:base-element #:element-children #:element-style
                #:element-layout)
  (:import-from :elmtui.view.api #:layout-node)
  (:import-from :elmtui.view.geo
                #:make-pos #:make-size
                #:rectangle #:make-rectangle #:copy-rectangle
                #:x #:y #:w #:h)
  (:import-from :elmtui.view.layout.size-utils #:compute-size #:content-rect-of)
  (:export #:layout-tree #:layout-node #:dispatch-layout #:style-value #:layout-grid-container-impl))

(in-package :elmtui.view.layout)

(defun style-value (node key &optional default)
  (getf (element-style node) key default))

(defun %copy-el (el &key children)
  (let* ((class (class-of el))
         (na nil)
         ;; (new   (make-instance class))
         )
    (dolist (slot (sb-mop:class-slots (class-of el)))
      (let ((name (sb-mop:slot-definition-name slot)))
        (when (slot-boundp el name)
          ;; (setf (slot-value new name) (slot-value el name))
          (push (slot-value el name) na)
          (push (elmtui.utils:ensure-keyword name) na))))
    (when children ;; (setf (element-children new) children)
      (push children na)
      (push :children na))
    (push class na)
    (apply #'make-instance na)))

(defgeneric layout-grid-container-impl (node available-rect)
  (:documentation "The actual implementation for grid layout, to be defined by the grid module."))

(defgeneric dispatch-layout (display node available-rect parent-styles)
  (:documentation "Dispatches to the appropriate layout algorithm based on display type."))

(defmethod dispatch-layout ((display (eql :grid)) node available-rect parent-styles)
  (declare (ignore parent-styles))
  (layout-grid-container-impl node available-rect))

(defmethod dispatch-layout ((display (eql :flex)) node available-rect parent-styles)
  (elmtui.view.layout.flex:compute-flex-layout node available-rect parent-styles))

(defmethod dispatch-layout (display node available-rect parent-styles)
  "Default block layout."
  (declare (ignore display parent-styles))
  (let* ((border-box-size (compute-size node (make-size :w (w available-rect) :h (h available-rect))))
         (new-rect (make-rectangle
                    :pos (make-pos :x (x available-rect) :y (y available-rect))
                    :size border-box-size))
         (content-rect (content-rect-of new-rect node))
         (laid-out-children
           (loop for child in (element-children node)
                 collect (layout-node child content-rect (element-style node)))))
    (let ((new-node (%copy-el node :children laid-out-children)))
      (setf (elmtui.view.element:el/layout-rect new-node) new-rect)
      new-node)))


(defmethod layout-node ((node base-element) available-rect parent-styles)
  (let ((display (elmtui.view.element:el/styles-of node :display :block)))
    (dispatch-layout display node available-rect parent-styles)))

(defmethod layout-node ((node t) available-rect parent-styles)
  "Pass-through for non-element nodes like strings."
  (declare (ignore available-rect parent-styles))
  node)

(defun layout-tree (root-element screen-rect)
  (layout-node root-element screen-rect nil))
