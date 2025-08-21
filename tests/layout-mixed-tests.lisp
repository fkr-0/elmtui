                                        ; == elmtui/tests/layout-smoke-fiveam.lisp ==
(uiop:define-package :elmtui.tests.layout-smoke
  (:use :cl :fiveam)
  (:import-from :elmtui.view.geo
                #:make-pos #:make-size #:make-rectangle #:x #:y #:w #:h #:pos #:size)
  (:import-from :elmtui.view.base-elements
                #:container-element #:text-element
                #:element-children #:element-style #:element-id)
  (:import-from :elmtui.view.element
                #:el/layout-rect)
  (:import-from :elmtui.view.tree-transforms
                #:process-tree)
  (:import-from :elmtui.contracts
                #:make-app-context))

(in-package :elmtui.tests.layout-smoke)

;;;; ------------------------------------------------------------------------
;;;; helpers
;;;; ------------------------------------------------------------------------

(defun %vp (w h)
  (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w w :h h)))

(defun %commit-children! (parent children)
  (setf (element-children parent) children)
  parent)

(defun %rect (node) (el/layout-rect node))
(defun %rx (node) (x (%rect node)))
(defun %ry (node) (y (%rect node)))
(defun %rw (node) (w (%rect node)))
(defun %rh (node) (h (%rect node)))

(defun %inside-p (child parent)
  (and (<= (x (%rect parent)) (x (%rect child)))
       (<= (y (%rect parent)) (y (%rect child)))
       (<= (+ (x (%rect child)) (w (%rect child)))
           (+ (x (%rect parent)) (w (%rect parent))))
       (<= (+ (y (%rect child)) (h (%rect child)))
           (+ (y (%rect parent)) (h (%rect parent))))))

(defun %distinct-positions-p (nodes)
  "At least two nodes differ by x or y."
  (let ((xy (mapcar (lambda (n) (cons (%rx n) (%ry n))) nodes)))
    (not (every (lambda (p) (equal p (car xy))) (cdr xy)))))

(defun %nonzero-any-p (nodes)
  "At least one node has positive width or height."
  (some (lambda (n) (or (> (%rw n) 0) (> (%rh n) 0))) nodes))

(defun %run (root vpw vph)
  "Top-down layout run using process-tree (ensures viewport)."
  (let ((vp (%vp vpw vph)))
    (process-tree root
                  :ctx (make-app-context :viewport-rect vp)
                  :root-rect vp)))

(defun %find (root id)
  (find id (element-children root) :key #'element-id))

(defmacro approx= (a b &optional (eps 1e-4))
  `(let ((aa (coerce ,a 'double-float))
         (bb (coerce ,b 'double-float)))
     (< (abs (- aa bb)) ,eps)))

;;;; ------------------------------------------------------------------------
;;;; suite
;;;; ------------------------------------------------------------------------

(def-suite layout/smoke

  :in elmtui.tests:elmtui-test)
(in-suite layout/smoke)

;;; ┌─────────────── block, depth 1 ───────────────┐
;;; │ root (block, padding 2/1) → child (block)    │
;;; │ expect child rect == parent content box      │
;;; └───────────────────────────────────────────────┘
(test block-depth1-content-box
  (let* ((root (make-instance 'container-element
                              :id :root
                              :style '(:display :block :padding-left 2 :padding-top 1)))
         (child (make-instance 'container-element :id :child :style '()))
         (root (%commit-children! root (list child)))
         (laid  (%run root 20 6)))
    (declare (ignore laid))
    (is (= (%rx child) (+ (%rx root) 2)))
    (is (= (%ry child) (+ (%ry root) 1)))
    (is (= (%rw child) (- (%rw root) 2))) ; no right padding set → just subtract left
    (is (= (%rh child) (- (%rh root) 1)))
    (is (%inside-p child root))))

;;; ┌─────────────── block, depth 2 ───────────────┐
;;; │ root (pad 2/1) → mid (pad 3/2) → leaf text  │
;;; │ expect accumulated offsets (2+3, 1+2)       │
;;; └───────────────────────────────────────────────┘
(test block-depth2-accumulated-offsets
  (let* ((root (make-instance 'container-element
                              :id :root :style '(:display :block :padding-left 2 :padding-top 1)))
         (mid  (make-instance 'container-element
                              :id :mid  :style '(:display :block :padding-left 3 :padding-top 2)))
         (leaf (make-instance 'text-element :id :leaf))
         (root (%commit-children! root (list (%commit-children! mid (list leaf)))))
         (laid (%run root 30 10)))
    (declare (ignore laid))
    (is (= (%rx mid) (+ (%rx root) 2)))
    (is (= (%ry mid) (+ (%ry root) 1)))
    (is (= (%rx leaf) (+ (%rx mid) 3)))
    (is (= (%ry leaf) (+ (%ry mid) 2)))
    (is (%inside-p leaf root))))

;;; ┌─────────────── flex row, depth 1 ────────────┐
;;; │ padding-left=1, gap=2, A w=4, B w=5         │
;;; │ expect A.x=1, B.x=1+4+2=7; y=0               │
;;; └───────────────────────────────────────────────┘
(test flex-row-gap-positions
  (let* ((root (make-instance 'container-element
                              :id :root
                              :style '(:display :flex :flex-direction :row :padding-left 1 :gap 2)))
         (a    (make-instance 'container-element :id :a :style '(:width 4 :height 2)))
         (b    (make-instance 'container-element :id :b :style '(:width 5 :height 2)))
         (root (%commit-children! root (list a b)))
         (laid (%run root 20 6)))
    (declare (ignore laid))
    (is (= (%rx a) 1))
    (is (= (%ry a) 0))
    (is (= (%rx b) 7)) ; 1 + 4 + 2
    (is (= (%ry b) 0))
    (is (= (%rw a) 4))
    (is (= (%rw b) 5))
    (is (%inside-p a root))
    (is (%inside-p b root))))

;;; ┌────────── flex nested (col → row), depth 2 ──────────┐
;;; │ root: column, pad-top=1; inner: row, gap=2           │
;;; │ expect inner.y=1; inner children honor row gaps       │
;;; └───────────────────────────────────────────────────────┘
(test flex-nested-column-row
  (let* ((root  (make-instance 'container-element
                               :id :root
                               :style '(:display :flex :flex-direction :column :padding-top 1)))
         (inner (make-instance 'container-element
                               :id :inner
                               :style '(:display :flex :flex-direction :row :gap 2)))
         (a     (make-instance 'container-element :id :a :style '(:width 3 :height 2)))
         (b     (make-instance 'container-element :id :b :style '(:width 4 :height 2)))
         (root  (%commit-children! root (list (%commit-children! inner (list a b)))))
         (laid  (%run root 20 8)))
    (declare (ignore laid))
    (is (= (%ry inner) 1))
    (is (= (%rx a) 0))
    (is (= (%rx b) (+ 3 2)))
    (is (%inside-p a inner))
    (is (%inside-p b inner))
    (is (%inside-p inner root))))

;;; ┌────────────── grid basic, depth 1 ──────────────┐
;;; │ root: display:grid; 4 children                  │
;;; │ smoke: each child has a rect inside root;       │
;;; │        at least two children differ in pos;     │
;;; │        at least one child has non-zero size     │
;;; └─────────────────────────────────────────────────┘
(test grid-basic-children-have-rects
  (let* ((root (make-instance 'container-element
                              :id :root :style '(:display :grid)))
         (a (make-instance 'container-element :id :a))
         (b (make-instance 'container-element :id :b))
         (c (make-instance 'container-element :id :c))
         (d (make-instance 'container-element :id :d))
         (root (%commit-children! root (list a b c d)))
         (laid (%run root 20 10)))
    (declare (ignore laid))
    (dolist (n (element-children root))
      (is (typep (%rect n) 'elmtui.view.geo:rectangle))
      (is (%inside-p n root)))
    (is (%distinct-positions-p (element-children root)))
    (is (%nonzero-any-p      (element-children root)))))

;;; ┌──────── grid nested with flex, depth 2 ─────────┐
;;; │ root: grid; cell B hosts a flex row (gap=1)     │
;;; │ smoke: inner flex children keep offsets inside  │
;;; └──────────────────────────────────────────────────┘
(test grid-nested-flex
  (let* ((root (make-instance 'container-element :id :root :style '(:display :grid)))
         (a (make-instance 'container-element :id :cell-a))
         (b (make-instance 'container-element :id :cell-b
                                              :style '(:display :flex :flex-direction :row :gap 1)))
         (c1 (make-instance 'container-element :id :c1 :style '(:width 3 :height 1)))
         (c2 (make-instance 'container-element :id :c2 :style '(:width 2 :height 1)))
         (root (%commit-children! root (list a (%commit-children! b (list c1 c2)))))
         (laid (%run root 24 10)))
    (declare (ignore laid))
    ;; basic containment
    (is (%inside-p a root))
    (is (%inside-p b root))
    (is (%inside-p c1 b))
    (is (%inside-p c2 b))
    ;; inner flex should place c2 to the right of c1 by width(c1)+gap
    (is (= (%rx c1) 0))
    (is (= (%rx c2) (+ (%rw c1) 1)))
    (is (%distinct-positions-p (list c1 c2)))))

;;; ┌────────────── deep mixed tree, depth 3 ──────────────┐
;;; │ root:flex(row) → mid:grid → leaf:flex(row)           │
;;; │ smoke: offsets accumulate (leaf.x >= mid.x >= root.x)│
;;; └───────────────────────────────────────────────────────┘
(test deep-mixed-accumulation
  (let* ((root (make-instance 'container-element
                              :id :root :style '(:display :flex :flex-direction :row :padding-left 1 :gap 2)))
         (mid  (make-instance 'container-element :id :mid :style '(:display :grid)))
         (pad  (make-instance 'container-element :id :pad :style '(:width 3 :height 2)))
         (leaf (make-instance 'container-element :id :leaf
                                                 :style '(:display :flex :flex-direction :row :gap 1)))
         (la   (make-instance 'container-element :id :la :style '(:width 2 :height 1)))
         (lb   (make-instance 'container-element :id :lb :style '(:width 2 :height 1)))
         (root (%commit-children! root (list pad (%commit-children! mid (list (%commit-children! leaf (list la lb)))))))
         (laid (%run root 30 10)))
    (declare (ignore laid))
    (is (<= (%rx root) (%rx mid)))
    (is (<= (%rx mid)  (%rx leaf)))
    (is (= (%rx la) 0))
    (is (= (%rx lb) (+ (%rw la) 1)))
    (is (%inside-p leaf mid))
    (is (%inside-p mid root))))

(defun run-layout-smoke-tests ()
  (run! :layout/smoke))
                                        ; == end/layout-smoke-fiveam.lisp ==
