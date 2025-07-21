;;; tests/view/dsl.lisp
;;;
;;; Tests for the elmtui view DSL.

(uiop:define-package :elmtui.tests.view.dsl
  (:use :cl :fiveam :elmtui.contracts :elmtui.pipeline)
  (:import-from :elmtui.view.core #:ui-node-p)
  (:import-from :elmtui.view.styled #:styled-ui-node-p)
  (:import-from :elmtui.pipeline
                #:generate-dsl)

  (:import-from :elmtui.app.api #:clear-dsl-component-registry)
  (:import-from :elmtui.view.geo #:make-rectangle #:w #:h #:rectangle #:make-size
                #:make-pos)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer-p
                #:make-virtual-buffer)
  (:import-from :elmtui.examples.rainbow-app
                #:rainbow-content-view
                #:rainbow-stylesheet))
(in-package :elmtui.tests.view.dsl)



(def-suite elmtui.view.dsl
  :in elmtui.tests:elmtui-test
  :description "Tests for the elmtui view DSL.")

(in-suite elmtui.view.dsl)

(test dsl-resolve-scalar-leaf
  (let ((dsl "hello")
        (app-state nil))
    (is (equal "hello" (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state)))))

(test dsl-resolve-layout-element-positional-children
  (elmtui.app.api:with-temporary-dsl-component-registry
    (elmtui.app.api:clear-dsl-component-registry)
    (let ((dsl '(:row (:text "a") (:text "b")))
          (app-state nil))
      (is (equalp '(:row :children ((:text :children ("a")) (:text :children ("b"))))
                  (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state))))))

(test dsl-resolve-layout-element-children-prop
  (elmtui.app.api:with-temporary-dsl-component-registry
    (elmtui.app.api:clear-dsl-component-registry)
    (let ((dsl '(:column :class "p-2" :children ((:text "x") (:text "y"))))
          (app-state nil))
      (is (equalp
           '(:column :class "p-2" :children ((:text "x") (:text :content "y")))
           (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state))))
    (let ((dsl '(:column :class "p-2" :children ((:text "x") (:text :content "y"))))
          (app-state nil))
      (is (equalp
           '(:column
             :class "p-2"
             :children ((:text :children ("x")) (:text :content "y" :children nil)))
           (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state))))))
;; elmtui.core.globals:*dsl-type-to-component-class*
;; (elmtui.app.api:with-temporary-dsl-component-registry
;;    (elmtui.app.api:clear-dsl-component-registry)
;;   )
;; --- Mocks for stateful component tests ---

(defclass mock-app-state ()
  ((components :initarg :components :initform (make-hash-table :test 'equal))))

(defclass mock-counter-component () ())

(defmethod elmtui.ui.api:view ((component mock-counter-component) app-state &key id-path)
  (declare (ignore app-state id-path))
  '(:text "0"))

(defmethod elmtui.state:get-component-by-path ((app-state mock-app-state) path)
  (gethash path (slot-value app-state 'components)))

(defun setup-test-app-state (component-specs)
  (let ((app-state (make-instance 'mock-app-state))
        (components (make-hash-table :test 'equal)))
    (dolist (spec component-specs)
      (destructuring-bind (path component) spec
        (setf (gethash path components) component)))
    (setf (slot-value app-state 'components) components)
    app-state))

;; --- Stateful component tests ---

(test dsl-resolve-stateful-component
  (elmtui.app.api:with-temporary-dsl-component-registry
    (unwind-protect
         (progn
           (elmtui.app.api:register-dsl-component-type :counter 'mock-counter-component)
           (let* ((app-state (setup-test-app-state `(((:ctr) ,(make-instance 'mock-counter-component)))))
                  (dsl '(:counter :id :ctr)))
             (is (equalp '(:counter :id :ctr :resolved-view (:text "0"));:children ("0")))
                         (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state))))
           ;; Test that an error is signaled if :id is missing
           (signals error (elmtui.view.dsl::render-dsl-to-resolved-tree '(:counter) (make-instance 'mock-app-state))))
      (clear-dsl-component-registry))))

(test dsl-resolve-mixed-nesting-with-path-tracking
  (elmtui.app.api:with-temporary-dsl-component-registry
    (unwind-protect
         (progn
           (elmtui.app.api:register-dsl-component-type :counter 'mock-counter-component)
           (let* ((app-state (setup-test-app-state `(((:main :ctr) ,(make-instance 'mock-counter-component)))))
                  (dsl '(:container :id :main
                         :children ((:row :children ((:counter :id :ctr)))
                                    (:text "bye")))))
             (is (equalp '(:container :id :main :children ((:row :children ((:counter :id :ctr :resolved-view (:text :children ("0")))))
                                                           (:text :children ("bye"))))
                         (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state)))))
      (clear-dsl-component-registry))))
