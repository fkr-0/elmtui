(uiop:define-package :elmtui.style.stylable
  (:use :cl)
  (:import-from :cl-styles.protocols
                #:stylable-id #:stylable-classes #:stylable-type
                #:stylable-inline-style #:stylable-attributes #:stylable-state
                #:stylable-parent #:stylable-children #:stylable-index
                #:set-computed-style #:get-computed-style)
  (:import-from :cl-styles.adapters
                #:normalize-tui-declarations)
  (:import-from :elmtui.view.base-elements
                #:base-element #:element-id #:element-classes #:element-style
                #:element-children #:element-type #:element-props)
  (:export))

(in-package :elmtui.style.stylable)

(flet ((->sel (x)
         (etypecase x
           (null nil)
           (string (string-downcase x))
           (keyword (string-downcase (symbol-name x)))
           (symbol (string-downcase (symbol-name x))))))
  (defmethod cl-styles.protocols:stylable-id ((n base-element))
    (->sel (element-id n)))

  (defmethod cl-styles.protocols:stylable-type ((n base-element))
    (->sel (element-type n)))

  (defmethod cl-styles.protocols:stylable-classes ((n base-element))
    (mapcar #'->sel (or (element-classes n) nil))))

(defmethod cl-styles.protocols:stylable-inline-style ((n base-element))
  (normalize-tui-declarations (element-style n)))

(defmethod cl-styles.protocols:stylable-attributes ((n base-element))
  nil)

(defmethod cl-styles.protocols:stylable-state ((n base-element))
  nil)

(defmethod cl-styles.protocols:stylable-parent ((n base-element))
  ;; We do not maintain back-pointers; the engine can traverse via children.
  nil)

(defmethod cl-styles.protocols:stylable-children ((n base-element))
  (element-children n))

(defmethod (setf cl-styles.protocols:stylable-children) (new-value (n base-element))
  (setf (element-children n) new-value))

(defmethod cl-styles.protocols:stylable-index ((n base-element))
  0)

(defun %merge-computed-into-inline (inline computed)
  (labels ((plist-keys (pl) (loop for (k v) on pl by #'cddr collect k))
           (remove-keys (pl keys)
             (loop with out = nil for (k v) on pl by #'cddr
                   unless (member k keys)
                     do (setf out (list* k v out))
                   finally (return (nreverse out)))))
    (let* ((ckeys (plist-keys computed))
           (base (or inline nil))
           (stripped (remove-keys base ckeys)))
      (nconc (copy-list stripped) (copy-list computed)))))

(defmethod cl-styles.protocols:set-computed-style ((n base-element) computed)
  ;; Store computed style for inspection and merge into inline style so layout sees it.
  (let* ((props (element-props n)))
    (setf (getf props :computed-style) computed)
    (setf (element-props n) props))
  (let* ((merged (%merge-computed-into-inline (element-style n) computed)))
    (setf (element-style n) merged))
  ;; Return the updated node so :return :objects workflows keep the object tree.
  n)

(defmethod cl-styles.protocols:get-computed-style ((n base-element))
  (getf (element-props n) :computed-style))
