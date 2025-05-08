;;;===============================================================
;;; File: tests/elmtui-view-tests.lisp
;;; FiveAM Unit Tests for View System (Flexbox, Grid, and Styling)
;;;===============================================================

(defpackage :elmtui-view-tests
  (:use :cl :fiveam
        :elmtui.view.core
        :elmtui.view.layout
        :elmtui.view.styled
        :elmtui.view.layout.grid))

(in-package :elmtui-view-tests)

(def-suite view-tests)
(in-suite view-tests)

;;;-----------------------------------------------------------------------------
;;; Flexbox Layout Tests
;;;-----------------------------------------------------------------------------

(test flexbox-layout-basic
  (let* ((child1 (make-styled-node :type :text :props '(:content "Child 1" :flex-grow 1)))
         (child2 (make-styled-node :type :text :props '(:content "Child 2" :flex-grow 2)))
         (child3 (make-styled-node :type :text :props '(:content "Child 3" :flex-grow 1)))
         (container (make-styled-node :type :container
                                      :props '(:display :flex :flex-direction :row)
                                      :children (list child1 child2 child3)))
         (screen-rect (make-rectangle :x 0 :y 0 :w 800 :h 600)))
    (layout-tree container screen-rect)
    (is (= (getf (ui-node-props child1) :width) 200))
    (is (= (getf (ui-node-props child2) :width) 400))
    (is (= (getf (ui-node-props child3) :width) 200))))

;;;-----------------------------------------------------------------------------
;;; Grid Layout Tests
;;;-----------------------------------------------------------------------------

(test grid-layout-basic
  (let* ((child1 (make-styled-node :type :text :props '(:content "A" :grid-area "header")))
         (child2 (make-styled-node :type :text :props '(:content "B" :grid-area "main")))
         (child3 (make-styled-node :type :text :props '(:content "C" :grid-area "sidebar")))
         (child4 (make-styled-node :type :text :props '(:content "D" :grid-area "footer")))
         (container (make-styled-node :type :container
                                      :props '(:display :grid
                                               :grid-template-areas '(("header" "header" "header")
                                                                      ("main" "sidebar" "sidebar")
                                                                      ("footer" "footer" "footer"))
                                               :grid-template-columns '(:fr 1 :fr 2 :fr 1)
                                               :grid-template-rows '(:auto :auto :auto))
                                      :children (list child1 child2 child3 child4)))
         (screen-rect (make-rectangle :x 0 :y 0 :w 800 :h 600)))
    (layout-tree container screen-rect)
    (is (= (getf (ui-node-props child1) :grid-column-start) 0))
    (is (= (getf (ui-node-props child1) :grid-column-end) 3))
    (is (= (getf (ui-node-props child2) :grid-column-start) 0))
    (is (= (getf (ui-node-props child2) :grid-column-end) 1))
    (is (= (getf (ui-node-props child3) :grid-column-start) 1))
    (is (= (getf (ui-node-props child3) :grid-column-end) 3))
    (is (= (getf (ui-node-props child4) :grid-column-start) 0))
    (is (= (getf (ui-node-props child4) :grid-column-end) 3))))

;;;-----------------------------------------------------------------------------
;;; Styling Tests
;;;-----------------------------------------------------------------------------

(test styling-application
  (let* ((child (make-styled-node :type :text :props '(:content "Styled Child" :classes '("test-class"))))
         (stylesheet (lambda (node)
                       (when (member "test-class" (classes node))
                         (setf (styles node) (list :color "red" :font-size 12))))))
    (apply-stylesheet-to-tree child stylesheet)
    (is (= (style-value child :color) "red"))
    (is (= (style-value child :font-size) 12))))

;;; Run all tests
;;; #-asdf
;;; (run! 'view-tests) ; Now handled by elmtui-all-tests:run-all-elmtui-tests
