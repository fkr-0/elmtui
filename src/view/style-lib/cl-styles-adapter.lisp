(uiop:define-package :elmtui.view.style-adapter
  (:use :cl)
  (:import-from :cl-styles.protocols
                #:stylable-id #:stylable-classes #:stylable-type #:stylable-inline-style
                #:stylable-attributes #:stylable-state
                #:stylable-parent #:stylable-children #:stylable-index
                #:set-computed-style #:get-computed-style)
  (:import-from :elmtui.view.base-elements
                #:base-element #:element-id #:element-classes #:element-type
                #:element-style #:element-children #:element-props)
  (:export))

(in-package :elmtui.view.style-adapter)

;; Read protocol mapping
(defmethod cl-styles.protocols:stylable-id ((obj base-element))
  (element-id obj))
(defmethod cl-styles.protocols:stylable-classes ((obj base-element))
  (element-classes obj))
(defmethod cl-styles.protocols:stylable-type ((obj base-element))
  (element-type obj))
(defmethod cl-styles.protocols:stylable-inline-style ((obj base-element))
  (element-style obj))
(defmethod cl-styles.protocols:stylable-attributes ((obj base-element))
  (element-props obj))
(defmethod cl-styles.protocols:stylable-state ((obj base-element))
  nil)
(defmethod cl-styles.protocols:stylable-parent ((obj base-element))
  ;; elmtui elements don’t keep a parent slot; engine will traverse downwards
  nil)
(defmethod cl-styles.protocols:stylable-children ((obj base-element))
  (element-children obj))
(defmethod cl-styles.protocols:stylable-index ((obj base-element))
  ;; Without a parent pointer, default to 0 (most selectors won’t rely on nth-child)
  0)

;; Write-back: store computed style on element-props under :computed-style
(defun %set-computed-prop (obj computed)
  (let ((props (element-props obj)))
    (setf (getf props :computed-style) computed)
    (setf (element-props obj) props)
    ;; For elmtui integration, make computed style available to layout by
    ;; writing it into element-style as well (computed already includes inline).
    (setf (element-style obj) computed)
    obj))

(defmethod cl-styles.protocols:set-computed-style ((obj base-element) computed)
  (%set-computed-prop obj computed))

(defmethod cl-styles.protocols:get-computed-style ((obj base-element))
  (getf (element-props obj) :computed-style nil))
