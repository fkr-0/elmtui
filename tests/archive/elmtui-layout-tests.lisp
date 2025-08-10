;;;===============================================================
;;; File: tests/elmtui-layout-tests.lisp
;;; Unit Tests for Layout Engine
;;;===============================================================

(defpackage #:elmtui-layout-tests
  (:use #:cl #:fiveam)
  (:import-from #:elmtui.view.core
                #:make-ui-node #:ui-node-props #:ui-node-children)
  (:import-from #:elmtui.view.styled
                #:make-styled-node #:styled-ui-node #:apply-stylesheet-to-tree #:style-value #:styles)
  (:import-from #:elmtui.style-lib.api #:selects
                #:make-style-set #:stylesheet #:style-rule)
  (:import-from #:elmtui.style-lib.sheet #:defstylesheet)
  (:import-from #:elmtui.style-lib.selector #:type>)
  (:import-from #:elmtui.style-lib.style-set #:set-style)
  (:import-from #:elmtui.view.layout #:layout-tree )
  (:import-from #:elmtui.view.geo
                #:make-rectangle #:make-pos #:make-size
                #:x #:y #:w #:h #:rectangle))

(in-package #:elmtui-layout-tests)

;; Define a test suite
(def-suite elmtui-layout-suite
  :description "Tests for the ElmTUI layout engine.")

(in-suite elmtui-layout-suite)
;; Helper to create a simple stylesheet for tests

(defun make-test-stylesheet (rules-plist)
  (let ((rules (loop for (selector . styles) in rules-plist
                     collect (make-instance 'style-rule
                                            :selector selector
                                            :styles (let ((ss (make-style-set)))
                                                      (loop for (prop val) on styles by #'cddr
                                                            do (set-style ss prop val))
                                                      ss)))))
    (make-instance 'stylesheet :rules rules)))

;; Helper to get layout-rect from a node
(defun get-lr (node)
  (elmtui.view.element:el/layout-rect node))

(test basic-block-layout-single-child
  "Test block layout with a single child, padding, border, and margin."
  (let* ((stylesheet (make-test-stylesheet
                      (list (list (type> :root) :width 50 :height 30 :padding 1 :border-style :single :border-width 1)
                            (list (type> :child) :width 10 :height 5 :margin 2 :background-color :blue))))
         (root-view (make-ui-node :type :root :props '(:id :root)
                                  :children (list (make-ui-node :type :child :props '(:id :c1))))))
    (let* ((styled-tree (apply-stylesheet-to-tree root-view stylesheet))
           (laid-out-tree (layout-tree styled-tree (make-rectangle :pos (make-pos :x 0 :y 0) :size  (make-size :w 80 :h 40))))
           (root-lr (get-lr laid-out-tree))
           (child1 (first (ui-node-children laid-out-tree)))
           (child1-lr (get-lr child1)))

      (is (not (null root-lr)) "Root should have layout rectangle")
      (is (not (null child1-lr)) "Child should have layout rectangle")

      ;; Root layout (border-box)
      (is (= (x root-lr) 0) "Root X position should be 0")
      (is (= (y root-lr) 0) "Root Y position should be 0")
      (is (= (w root-lr) 50) "Root width should be 50") 
      (is (= (h root-lr) 30) "Root height should be 30")

      ;; Child layout (border-box)
      ;; Root padding 1, border 1. Child margin 2.
      ;; Child X = parent-content-x + child-margin-left = (0 + 1 + 1) + 2 = 4
      (is (= (x child1-lr) 4) (format nil "Child X position should be 4 but ~A~%"
                                      (x child1-lr)))
      ;; Child Y = parent-content-y + child-margin-top = (0 + 1 + 1) + 2 = 4
      (is (= (y child1-lr) 4) (format nil "Child Y position should be 4 but ~A~%"
                                      (y child1-lr)))
      ;; Child Width = styled width
      (is (= (w child1-lr) 10) "Child width should be 10")
      ;; Child Height = styled height
      (is (= (h child1-lr) 5) "Child height should be 5"))))

(test basic-flex-layout-row
  "Test flex layout (row) with two children, padding, border, and margins."
  (let* ((stylesheet (make-test-stylesheet
                      (list (list (type> :root) :display :flex :flex-direction :row :width 60 :height 20 :padding 1 :border-style :single :border-width 1)
                            (list (type> :child) :width 10 :height 10 :margin 1 :background-color :red)
                            (list (type> :child2) :width 15 :height 10 :margin 1 :background-color :green))))
         (root-view (make-ui-node :type :root :props '(:id :root)
                                  :children (list (make-ui-node :type :child :props '(:id :c1))
                                                  (make-ui-node :type :child2 :props '(:id :c2))))))
    (let* ((styled-tree (apply-stylesheet-to-tree root-view stylesheet))
           (laid-out-tree (layout-tree styled-tree (make-rectangle :pos (make-pos :x 0 :y 0) :size  (make-size :w 80 :h 40))))
           (root-lr (get-lr laid-out-tree))
           (child1 (first (ui-node-children laid-out-tree)))
           (child1-lr (get-lr child1))
           (child2 (second (ui-node-children laid-out-tree)))
           (child2-lr (get-lr child2)))

      (is (not (null root-lr)) "Root should have layout rectangle")
      (is (not (null child1-lr)) "Child1 should have layout rectangle")
      (is (not (null child2-lr)) "Child2 should have layout rectangle")

      ;; Root layout (border-box)
      (is (= (x root-lr) 0) "Root X position should be 0")
      (is (= (y root-lr) 0) "Root Y position should be 0")
      (is (= (w root-lr) 60) "Root width should be 60")
      (is (= (h root-lr) 20) "Root height should be 20")
      ;; Child1 layout (border-box)
      ;; Root padding 1, border 1. Child1 margin 1.
      ;; Child1 X = parent-content-x + child1-margin-left = (0 + 1 + 1) + 1 = 3
      (is (= (w child1-lr) 10) "Child1 width should be 10")
      (is (= (h child1-lr) 10) "Child1 height should be 10")
      (is (= (x child1-lr) 3) (format nil "Child1 X position should be 3 but was ~A~%"
                                      (x child1-lr)))
      ;; Child1 Y = parent-content-y + child1-margin-top = (0 + 1 + 1) + 1 = 3
      (is (= (y child1-lr) 3) (format nil "Child1 Y position should be 3 but ~A~%"
                                      (y child1-lr)))

      ;; Child2 layout (border-box)
      ;; Child2 X = child1-x + child1-width (border-box) + child1-margin-right + child2-margin-left
      ;;          = 3 + 10 + 1 + 1 = 15
      (is (= (x child2-lr) 15)(format nil "Child2 X position should be 15 but ~A~%"
                                      (x child2-lr)))
      ;; Child2 Y = parent-content-y + child2-margin-top = (0 + 1 + 1) + 1 = 3
      ;; (assuming default align-items: stretch or flex-start)
      (is (= (y child2-lr) 3) "Child2 Y position should be 3")
      (is (= (w child2-lr) 15) "Child2 width should be 15")
      (is (= (h child2-lr) 10) "Child2 height should be 10"))))

;; Add more tests for flex-grow, flex-shrink, wrapping, different alignments, etc.
;; Add tests for grid layout once implemented.
