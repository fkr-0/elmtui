;; (defpackage :elmtui.ui.widgets.legacy-compat
;;   (:use :cl)
;;   (:export :functional-widget-adapter
;;            :define-adapter-for-class
;;            :widget->component
;;            :with-legacy-widgets))

;; (in-package :elmtui.ui.widgets.legacy-compat)

;; ;; Registry of class -> functional adapters
;; (defvar *class-adapters* (make-hash-table :test #'eq)
;;   "Registry of class to functional component adapters")

;; ;; Registry of component instances
;; (defvar *instance-registry* (make-hash-table :test #'eq)
;;   "Registry of legacy widget instances for state tracking")

;; ;; Define an adapter function for a class
;; (defun define-adapter-for-class (class-name adapter-fn)
;;   "Register an adapter that converts instances of CLASS-NAME to functional components"
;;   (setf (gethash class-name *class-adapters*) adapter-fn)
;;   class-name)

;; ;; Create an adapter for a class
;; (defmacro functional-widget-adapter (class-name &rest slot-mappings)
;;   "Define a functional adapter for CLASS-NAME that maps slots to props"
;;   (let ((instance-var (gensym "INSTANCE-"))
;;         (key-var (gensym "KEY-")))
;;     `(define-adapter-for-class ',class-name
;;                                (lambda (,instance-var &key (,key-var nil))
;;                                  (declare (ignorable ,key-var))
;;                                  (unless (gethash ,instance-var *instance-registry*)
;;                                    (setf (gethash ,instance-var *instance-registry*) t))
;;                                  (funcall (get-view-fn)
;;                                           ,(intern (string-downcase (symbol-name class-name)) :keyword)
;;                                           (list
;;                                            ,@(loop for (slot prop) in slot-mappings
;;                                                   collect `(cons ,prop (slot-value ,instance-var ',slot))))
;;                                           (slot-value ,instance-var 'children))))))

;; ;; Function to convert a class instance to a functional component
;; (defun widget->component (widget)
;;   "Convert a legacy widget instance to a functional component"
;;   (let ((class-name (class-name (class-of widget))))
;;     (let ((adapter (gethash class-name *class-adapters*)))
;;       (if adapter
;;           (funcall adapter widget)
;;           (error "No adapter defined for class ~a" class-name)))))

;; ;; Helper to get view function
;; (defun get-view-fn ()
;;   "Get the current view rendering function"
;;   (or (and (boundp '*view-fn*) *view-fn*)
;;       (error "No *view-fn* bound in current context")))

;; ;; Macro to use legacy widgets in functional components
;; (defmacro with-legacy-widgets ((&key view-fn) &body body)
;;   "Execute BODY with legacy widget support enabled"
;;   `(let ((*view-fn* ,view-fn))
;;      ,@body))

;; ;; Example adapter definitions
;; #|
;; ;; Define an adapter for the old Panel class
;; (functional-widget-adapter panel
;;   (title :title)
;;   (border-style :border)
;;   (styles :styles)
;;   (padding :padding)
;;   (width :width)
;;   (height :height))

;; ;; Define an adapter for the old Table class
;; (functional-widget-adapter table
;;   (columns :columns)
;;   (data :data)
;;   (selected-row :selected-row)
;;   (sort-column :sort-column)
;;   (sort-direction :sort-direction)
;;   (header-style :header-style)
;;   (row-style :row-style)
;;   (zebra-striping :zebra-striping)
;;   (bordered :bordered))

;; ;; Example usage with legacy widgets
;; (with-legacy-widgets (:view-fn (lambda (type props children)
;;                                 (render-component type props children)))
;;   (let ((legacy-panel (make-instance 'panel :title "Legacy Panel")))
;;     (widget->component legacy-panel)))
;; |#
