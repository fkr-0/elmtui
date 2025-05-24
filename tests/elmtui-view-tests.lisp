;;;===============================================================
;;; File: tests/elmtui-view-tests.lisp
;;; FiveAM Unit Tests for View System (Flexbox, Grid, and Styling)
;;;===============================================================

(uiop:define-package :elmtui-view-tests
  (:use :cl :fiveam
        :elmtui.view.core
   :elmtui.view.layout
        :elmtui.view.styled
   :elmtui.view.layout.grid)
  (:import-from :elmtui.style-lib.api :classes)
  (:import-from :elmtui.view.geo
                #:make-rectangle
                #:make-pos
                #:make-size
                #:rectangle
                #:pos
                #:size
                #:w #:h #:x #:y))

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
         (screen-rect (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size  :w 800 :h 600))))
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
         (screen-rect (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size  :w 800 :h 600))))
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

;;;----------------------------------------------------------------------------- 
;;; Additional Rendering/Tree/Style Tests
;;;-----------------------------------------------------------------------------

(test ui-tree-nesting
  (let* ((leaf (make-styled-node :type :label :props '(:value "Leaf")))
         (mid (make-styled-node :type :container :children (list leaf)))
         (root (make-styled-node :type :container :children (list mid))))
    (is (eq (ui-node-type root) :container))
    (is (eq (ui-node-type (first (ui-node-children root))) :container))
    (is (eq (ui-node-type (first (ui-node-children (first (ui-node-children root))))) :label))))

(test style-inheritance
  (let* ((parent (make-styled-node :type :container :props '(:classes "parent-class")))
         (child (make-styled-node :type :label :props '(:value "Child") :parent parent))
         (stylesheet (lambda (node)
                       (when (member "parent-class" (classes node))
                         (setf (styles node) (list :color "blue")))))
         (tree parent))
    (apply-stylesheet-to-tree tree stylesheet)
    (is (= (style-value parent :color) "blue"))
    ;; Child should not inherit unless stylesheet applies to it
    (is (null (style-value child :color)))))

(test style-overrides
  (let* ((node (make-styled-node :type :label :props '(:classes '("a" "b"))))
         (stylesheet (lambda (n)
                       (when (member "a" (classes n))
                         (setf (styles n) (list :color "red")))
                       (when (member "b" (classes n))
                         (setf (styles n) (append (styles n) (list :color "green")))))))
    (apply-stylesheet-to-tree node stylesheet)
    ;; Last applied wins
    (is (= (style-value node :color) "green"))))

;;; Run all tests
(defun run-elmtui-view-tests ()
  (fiveam:run! 'view-tests))
