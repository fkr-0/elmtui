;; == elmtui/core/element-protocol.lisp ==
(uiop:define-package :elmtui.view.element
  (:use :cl)
  (:import-from :elmtui.view.base-elements
   :base-element :element-children :element-props #:element-layout-rect
   :element-props :element-content #:text-content #:text-element
   #:element-size
                :element-style :element-type :element-id)
  (:import-from :elmtui.view.geo
   :rectangle #:make-size #:make-rectangle #:make-pos)
  (:import-from :sb-mop
                #:class-slots #:slot-definition-name)
  (:export
   ;; predicates
   #:element-p
   ;; core getters
   #:el/children #:el/props #:el/styles #:el/type #:el/id
   #:el/layout-rect #:el/display #:el/content #:el/size
   ;; setters
   ;; helpers
   #:ensure-element
   #:with-element
   #:el/styles-of
   #:intrinsic-size-of
   ))

(in-package :elmtui.view.element)

(defgeneric element-p (x))

(defgeneric intrinsic-size-of (node parent-content-rect)
  (:documentation "Return a SIZE for NODE based on its content (text length, etc.)."))
(defgeneric el/children (el))
(defgeneric el/props    (el))
(defgeneric el/styles   (el))
(defgeneric el/type     (el))
(defgeneric el/id       (el))
(defgeneric el/layout-rect (el))
;; (defgeneric (setf el/layout-rect) (rect el))
(defgeneric el/styles-of   (el  style &optional default))
(defgeneric el/display  (el))

(defun %find-slot-symbol (obj slot-name)
  "Return the actual slot symbol of OBJ whose name matches SLOT-NAME, or NIL."
  (let ((target (string-upcase (string slot-name))))
    (loop for slot-def in (sb-mop:class-slots (class-of obj))
          for slot-sym = (sb-mop:slot-definition-name slot-def)
          when (string= (symbol-name slot-sym) target)
            do (return slot-sym))))

(defun %slot-value-if-bound (obj slot-name)
  (let ((slot-sym (%find-slot-symbol obj slot-name)))
    (when (and slot-sym (slot-boundp obj slot-sym))
      (slot-value obj slot-sym))))

(defmacro with-element ((var obj) &body body)
  "Assert OBJ is an element (via protocol); bind VAR to OBJ for BODY."
  `(let ((,var (ensure-element ,obj)))
     ,@body))

(defgeneric ensure-element (x)
  (:documentation "Return X if element-p, otherwise try to adapt or error."))
;; == end/element-protocol.lisp ==
;; == elmtui/core/element-base-impl.lisp ==

(defmethod element-p ((x base-element)) t)
(defmethod element-p ((x t)) nil)
(defmethod ensure-element ((x base-element)) x)

(defmethod el/size ((el base-element))
  (or (element-size el) (make-size :w 0 :h 0)))
(defmethod (setf el/size) (x (el base-element)) (setf (element-size el) x))
(defmethod (setf el/size) ((wh list) (el base-element))
  (if (= 2 (length wh))
      (setf (element-size el) (make-size :w (first wh) :h (second wh)))
      (error "Expected a list of two elements for size, got ~A" wh)))
(defmethod el/children ((el base-element)) (element-children el))
(defmethod (setf el/children) (x (el base-element)) (setf (element-children el) x))
(defmethod el/props ((el base-element))
  "Return declarative properties from bound slots (not computed cache props)."
  (let ((plist nil))
    (dolist (slot-def (sb-mop:class-slots (class-of el)))
      (let* ((slot-sym (sb-mop:slot-definition-name slot-def))
             (name (symbol-name slot-sym)))
        (when (and (slot-boundp el slot-sym)
                   ;; Expose useful element props; skip internal bookkeeping slots.
                   (not (member name '("CHILDREN" "LAYOUT-RECT" "CONTENT-MODEL")
                                :test #'string=)))
          (setf (getf plist (intern name :keyword))
                (slot-value el slot-sym)))))
    plist))
(defmethod el/styles   ((el base-element)) (elmtui.view.base-elements:element-style el))
(defmethod (setf el/styles) (x (el base-element))
  (setf (elmtui.view.base-elements:element-style el) x))
(defmethod el/styles-of   ((el list) style &optional default)
  (getf el style default))
(defmethod  (setf el/styles-of)   (x (el list) style)
  (setf (getf el style) x))
(defmethod el/styles-of   ((el base-element) style &optional default)
  (getf (elmtui.view.base-elements:element-style el) style default))
(defmethod  (setf el/styles-of)   (x (el base-element) style)
  (setf (getf (elmtui.view.base-elements:element-style el) style) x))
(defmethod el/type     ((el base-element)) (element-type el))
(defmethod el/id       ((el base-element)) (element-id el))
(defmethod el/content       ((el text-element)) (elmtui.view.base-elements:text-content el))
(defmethod el/content ((el base-element))
  ;; Slot symbols live in the defining package, so resolve by slot-name string.
  (%slot-value-if-bound el :content))

(defmethod (setf el/content) (txt (el text-element))
  (setf (elmtui.view.base-elements:text-content el) txt))
(defmethod el/layout-rect ((el base-element))
  "Return EL's assigned layout rectangle, or NIL before layout.

NIL is semantically distinct from a real zero-sized rectangle: layout passes
use it to decide whether a parent must seed the child's available rectangle."
  (elmtui.view.base-elements:element-layout-rect el))

(defmethod (setf el/layout-rect) ((rect rectangle) (el base-element))
  (setf (elmtui.view.base-elements:element-layout-rect el) rect))
(defmethod (setf el/layout-rect) ((rect rectangle) (el text-element))
  (setf (elmtui.view.base-elements:element-layout-rect el) rect))

(defmethod el/display ((el base-element))
  ;; style wins; default :block
  (or (getf (element-style el) :display) :block))
;; == end/element-base-impl.lisp ==


(defmethod intrinsic-size-of ((node text-element) parent-content-rect)
  "Very simple intrinsic: width = line length, height = 1 (no wrap yet)."
  (declare (ignore parent-content-rect))
  (let* ((s (or (el/content node) "")))
    (make-size :w (length (princ-to-string s)) :h 1)))

(defmethod intrinsic-size-of ((node base-element) parent-content-rect)
  "Default intrinsic:
   - if NODE exposes textual content, size to one-line text width
   - otherwise zero unless overridden."
  (declare (ignore parent-content-rect))
  (let ((content (el/content node)))
    (if content
        (make-size :w (length (princ-to-string content)) :h 1)
        (make-size :w 0 :h 0))))
