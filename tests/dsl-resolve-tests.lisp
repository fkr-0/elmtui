;;; tests/view/dsl.lisp
;;;
;;; Tests for the elmtui view DSL.

(uiop:define-package :elmtui.tests.view.dsl
  (:use :cl :fiveam :elmtui.contracts :elmtui.pipeline)
  (:import-from :elmtui.view.core #:ui-node-p)
  (:import-from :elmtui.view.styled #:styled-ui-node-p)
  (:import-from :elmtui.pipeline
    #:generate-dsl)
  (:import-from :elmtui.ui.dsl-resolution #:dsl-type)
  (:import-from :elmtui.ui.api #:view)
  (:import-from :elmtui.view.geo #:make-rectangle #:w #:h #:rectangle #:make-size
    #:make-pos)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:virtual-terminal-buffer-p
    #:make-virtual-buffer)
  (:import-from :elmtui.tests.rainbow
    #:rainbow-content-view
    #:rainbow-stylesheet
    #:initialize-app-state-rainbow-example-app))
(in-package :elmtui.tests.view.dsl)


(def-suite elmtui.view.dsl
  :in elmtui.tests:elmtui-test
  :description "Tests for the elmtui view DSL.")

(in-suite elmtui.view.dsl)

(test dsl-resolve-scalar-leaf
  (let ((dsl "hello")
         (app-state nil))
    (is (equal "hello" (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state)))))

;; Register DSL types for test components
(defmethod dsl-type ((type (eql :row)) &optional props)
  (values 'elmtui.ui.widgets.layout:layout props))

(defmethod dsl-type ((type (eql :column)) &optional props)
  (values 'elmtui.ui.widgets.layout:layout props))

(test dsl-resolve-layout-element-positional-children
  (let ((dsl '(:row (:text :content "a") (:text "b")))
         (app-state nil))
    (is (equalp '(:row :children ((:text :content "a") (:text :content "b")))
          (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state)))))

(test dsl-resolve-layout-element-children-prop
  (let ((dsl '(:column :class "p-2" :children ((:text "x") (:text "y"))))
         (app-state nil))
    (is (equalp
          '(:column :class "p-2"
             :children ((:text :content "x") (:text :content "y")))
          (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state)))))

(test dsl-resolve-nested-layout
  (let ((dsl '(:row :class "flex"
                :children ((:column :class "col-1"
                             :children ((:text "a") (:text "b")))
                            (:column :class "col-2"
                              :children ((:text "c"))))))
         (app-state nil))
    (let ((result (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state)))
      (is (consp result))
      (is (eq :row (first result)))
      (is (getf (rest result) :children)))))

(test dsl-resolve-deeply-nested
  (let ((dsl '(:row
                (:column
                  (:row
                    (:column
                      (:text "deep"))))))
         (app-state nil))
    (let ((result (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state)))
      (is (consp result))
      (is (eq :row (first result)))
      (is (getf (rest result) :children)))))

(test dsl-resolve-empty-children
  (let ((dsl '(:column :children nil))
         (app-state nil))
    (let ((result (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state)))
      (is (consp result))
      (is (eq :column (first result)))
      (is (null (getf (rest result) :children))))))

;; --- Stateful component tests ---

;; Mock counter component for testing
(defclass mock-counter-component ()
  ())

(defmethod view ((component mock-counter-component) app-state &key id-path children)
  (declare (ignore app-state id-path children))
  ;; Return a simple DSL representation with an id
  '(:column :id :counter-view :children ((:text :content "Counter"))))

(defmethod dsl-type ((type (eql :counter)) &optional props)
  (values 'mock-counter-component props))

(test dsl-resolve-stateful-component
  (let ((dsl '(:counter :id :my-counter))
         (app-state nil))
    ;; The component should be resolved even without state
    (let ((result (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state)))
      (is (consp result))
      (is (eq :counter (car result))))))

(test dsl-resolve-mixed-nesting-with-path-tracking
  (let ((dsl '(:column
                (:text "header")
                (:counter :id :main-counter)
                (:text "footer")))
         (app-state nil))
    (let ((result (elmtui.view.dsl::render-dsl-to-resolved-tree dsl app-state)))
      (is (consp result))
      (is (eq :column (car result))))))
