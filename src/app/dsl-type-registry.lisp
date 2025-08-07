(uiop:define-package #:elmtui.app.dsl-type-registry
  (:use #:cl)
  (:import-from #:elmtui.app.api #:register-dsl-component-type))

(in-package #:elmtui.app.dsl-type-registry)

;;; Register built-in DSL types to component classes.
;; (register-dsl-component-type :label 'elmtui.ui.widgets.label:label)
(register-dsl-component-type :root-viewport 'elmtui.ui.widgets.root-viewport:root-viewport)
(register-dsl-component-type :key-tester-widget 'example.key-tester:key-tester)
(register-dsl-component-type :viewport 'elmtui.ui.widgets.viewport:viewport)
(register-dsl-component-type :grid-container 'elmtui.ui.widgets.grid-container:grid-container)
;; (register-dsl-component-type :scrollable-container 'elmtui.ui.widgets.scrollable-container:scrollable-container)
;; (register-dsl-component-type :counter 'elmtui.ui.widgets.counter:counter)
(register-dsl-component-type :layout 'elmtui.ui.widgets.layout:layout)
                                        ; (register-dsl-component-type :column 'elmtui.ui.widgets.layout:layout)
                                        ;(register-dsl-component-type :container 'elmtui.ui.widgets.viewport:viewport)
;;; Sanity check (can be removed in production)
;; (assert (eq (elmtui.app.api:get-component-class-for-dsl-type :label)
;;             'elmtui.ui.widgets.label:label))

;; above translates to: 'this class provides a view logic for that keyword'
;; that means: it should be *easily* feasible to write a macro that
;; allows to build views like
;;   (defview :double-label '((:label :content "Hello") (:label :content "World")))
;;   (defview :allcaps-label ...) ;; label with state modification to content:upcase
;;   (defview :column '(:layout :direction :vertical) ...) ;; syntax sugar for
;;   (defview :row 'layout 'horizontal ...) ;; syntax?
;; TODO
;; ;; core api -------------------------------------------------------
;; (defgeneric dsl-component-class (dsl-type)
;;   (:documentation "Return the component class metaobject for DSL-TYPE (a keyword)."))

;; ;; registry-backed default ---------------------------------------
;; (defmethod dsl-component-class (dsl-type)
;;   (or (gethash dsl-type *dsl-type-to-component-class*)
;;       (error "No component class registered for DSL type: ~S" dsl-type)))

;; ;; defcomponent enhancement --------------------------------------
;; (defmacro defcomponent (name (&rest supers) &body body)
;;   ;; ...existing expansion...
;;   (let* ((dsl-type (or (getf body :dsl-type)
;;                        (intern (string-upcase (symbol-name name)) :keyword))))
;;     `(progn
;;        ,@(expand-defcomponent ...)         ; what you already have
;;        ;; automatic two-way registration
;;        (register-dsl-component-type ,dsl-type ',name)
;;        (defmethod dsl-component-class ((type (eql ,dsl-type))) ',name))))
