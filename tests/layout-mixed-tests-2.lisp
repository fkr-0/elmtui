;;; == elmtui/tests/layout-smoke-fiveam.lisp ==
;;; Smoke plausibility tests for block, flex, grid — depths 1/2/3.
;;; NOTE: we always re-find nodes by :id in the *returned* tree to avoid stale refs.

(uiop:define-package :elmtui.tests.layout-smoke
  (:use :cl :fiveam)
  (:import-from :elmtui.view.geo
                #:make-pos #:make-size #:make-rectangle #:x #:y #:w #:h #:pos #:size
                #:rectangle)
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

;;; ───────────────────────── helpers ─────────────────────────

;;;; helpers

(defun %vp (w h)
  (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w w :h h)))

(defun %rect (node) (el/layout-rect node))
(defun %rx (node) (x (%rect node)))
(defun %ry (node) (y (%rect node)))
(defun %rw (node) (w (%rect node)))
(defun %rh (node) (h (%rect node)))

(defun %ensure-rect (node)
  (let ((r (%rect node)))
    (unless (typep r 'rectangle)
      (error "Node ~S has no layout rect." (ignore-errors (element-id node))))
    r))

(defun %inside-p (child parent)
  (%ensure-rect child) (%ensure-rect parent)
  (and (<= (x (%rect parent)) (x (%rect child)))
       (<= (y (%rect parent)) (y (%rect child)))
       (<= (+ (x (%rect child)) (w (%rect child)))
           (+ (x (%rect parent)) (w (%rect parent))))
       (<= (+ (y (%rect child)) (h (%rect child)))
           (+ (y (%rect parent)) (h (%rect parent))))))

(defun %distinct-positions-p (nodes)
  (let* ((pts (mapcar (lambda (n) (prog1 (cons (%rx n) (%ry n)) (%ensure-rect n))) nodes))
         (p0  (car pts)))
    (some (lambda (p) (not (equal p p0))) (cdr pts))))

(defun %nonzero-any-p (nodes)
  (some (lambda (n) (prog1 (or (> (%rw n) 0) (> (%rh n) 0)) (%ensure-rect n))) nodes))

(defun %run (root vpw vph)
  (let ((vp (%vp vpw vph)))
    (process-tree root :ctx (make-app-context :viewport-rect vp) :root-rect vp)))

(defun %id-of (n)
  (ignore-errors (element-id n))) ; accessor-based, robust

(defun %find-deep (root id)
  "Find by id in the laid-out tree using the accessor, not slot inspection."
  (labels ((walk (n)
             (when (eql (%id-of n) id) (return-from walk n))
             (dolist (c (element-children n))
               (let ((hit (walk c)))
                 (when hit (return-from walk hit))))
             nil))
    (or (walk root)
        (error
         (format nil"Node with id ~S not found in laid-out tree." id)))))

(defmacro approx= (a b &optional (eps 1e-4))
  `(let ((aa (coerce ,a 'double-float))
         (bb (coerce ,b 'double-float)))
     (< (abs (- aa bb)) ,eps)))


;;; ───────────────────────── suite ─────────────────────────

(def-suite  layout/smoke
  :in elmtui.tests:elmtui-test)
(in-suite  layout/smoke)

;;; Block — depth 1
(test block-depth1-content-box
  (let* ((root (make-instance 'container-element
                              :id :root
                              :style '(:display :block :padding-left 2 :padding-top 1)))
         (child (make-instance 'container-element :id :child :style '()))
         (_    (setf (element-children root) (list child)))
         (laid (%run root 20 6))
         (R    laid)
         (C    (%find-deep R :child)))
    (is (= (%rx C) (+ (%rx R) 2)))
    (is (= (%ry C) (+ (%ry R) 1)))
    (is (>= (%rw C) 0))
    (is (>= (%rh C) 0))
    (is (%inside-p C R))))

;;; Block — depth 2
(test block-depth2-accumulated-offsets
  (let* ((root (make-instance 'container-element
                              :id :root
                              :style '(:display :block :padding-left 2 :padding-top 1)))
         (mid  (make-instance 'container-element
                              :id :mid
                              :style '(:display :block :padding-left 3 :padding-top 2)))
         (leaf (make-instance 'text-element :id :leaf))
         (_    (setf (element-children mid) (list leaf)))
         (_    (setf (element-children root) (list mid)))
         (laid (%run root 30 10))
         (R    laid)
         (M    (%find-deep R :mid))
         (L    (%find-deep R :leaf)))
    (is (= (%rx M) (+ (%rx R) 2)))
    (is (= (%ry M) (+ (%ry R) 1)))
    (is (= (%rx L) (+ (%rx M) 3)))
    (is (= (%ry L) (+ (%ry M) 2)))
    (is (%inside-p L R))))

;;; Flex row — depth 1
(test flex-row-gap-positions
  (let* ((root (make-instance 'container-element
                              :id :root
                              :style '(:display :flex :flex-direction :row :padding-left 1 :gap 2)))
         (a    (make-instance 'container-element :id :a :style '(:width 4 :height 2)))
         (b    (make-instance 'container-element :id :b :style '(:width 5 :height 2)))
         (_    (setf (element-children root) (list a b)))
         (laid (%run root 20 6))
         (A    (%find-deep laid :a))
         (B    (%find-deep laid :b))
         (R    laid))
    (is (= (%rx A) 1))
    (is (= (%ry A) 0))
    (is (= (%rx B) 7)) ; 1 + 4 + 2
    (is (= (%ry B) 0))
    (is (= (%rw A) 4))
    (is (= (%rw B) 5))
    (is (%inside-p A R))
    (is (%inside-p B R))))


;;; Grid basic — depth 1 (plausibility)
(test grid-basic-children-have-rects
  (let* ((root (make-instance 'container-element :id :root :style '(:display :grid)))
         (a (make-instance 'container-element :id :a))
         (b (make-instance 'container-element :id :b))
         (c (make-instance 'container-element :id :c))
         (d (make-instance 'container-element :id :d))
         (_ (setf (element-children root) (list a b c d)))
         (laid (%run root 20 10))
         (A (%find-deep laid :a))
         (B (%find-deep laid :b))
         (C (%find-deep laid :c))
         (D (%find-deep laid :d)))
    (dolist (n (list A B C D))
      (is (typep (%rect n) 'rectangle))
      (is (%inside-p n laid)))
    (is (%distinct-positions-p (list A B C D)))
    (is (%nonzero-any-p      (list A B C D)))))

;;; Grid with nested flex — depth 2 (plausibility + inner row offsets)
(test grid-nested-flex
  (let* ((root (make-instance 'container-element :id :root :style '(:display :grid)))
         (cell-a (make-instance 'container-element :id :cell-a))
         (cell-b (make-instance 'container-element :id :cell-b
                                                   :style '(:display :flex :flex-direction :row :gap 1)))
         (c1 (make-instance 'container-element :id :c1 :style '(:width 3 :height 1)))
         (c2 (make-instance 'container-element :id :c2 :style '(:width 2 :height 1)))
         (_  (setf (element-children cell-b) (list c1 c2)))
         (_  (setf (element-children root) (list cell-a cell-b)))
         (laid (%run root 24 10))
         (R   laid)
         (B   (%find-deep R :cell-b))
         (C1  (%find-deep R :c1))
         (C2  (%find-deep R :c2)))
    (is (%inside-p B R))
    (is (%inside-p C1 B))
    (is (%inside-p C2 B))
    (is (= (%rx C1) 0))
    (is (= (%rx C2) (+ (%rw C1) 1)))
    (is (%distinct-positions-p (list C1 C2)))))

;;; Deep mixed (flex → grid → flex) — depth 3
(test deep-mixed-accumulation
  (let* ((root (make-instance 'container-element
                              :id :root
                              :style '(:display :flex :flex-direction :row :padding-left 1 :gap 2)))
         (mid  (make-instance 'container-element :id :mid :style '(:display :grid)))
         (pad  (make-instance 'container-element :id :pad :style '(:width 3 :height 2)))
         (leaf (make-instance 'container-element
                              :id :leaf
                              :style '(:display :flex :flex-direction :row :gap 1)))
         (la   (make-instance 'container-element :id :la :style '(:width 2 :height 1)))
         (lb   (make-instance 'container-element :id :lb :style '(:width 2 :height 1)))
         (_    (setf (element-children leaf) (list la lb)))
         (_    (setf (element-children mid)  (list leaf)))
         (_    (setf (element-children root) (list pad mid)))
         (laid (%run root 30 10))
         (R    laid)
         (M    (%find-deep R :mid))
         (L    (%find-deep R :leaf))
         (LA   (%find-deep R :la))
         (LB   (%find-deep R :lb)))
    (is (<= (%rx R) (%rx M)))
    (is (<= (%rx M) (%rx L)))
    (is (= (%rx LA) 0))
    (is (= (%rx LB) (+ (%rw LA) 1)))
    (is (%inside-p L M))
    (is (%inside-p M R))))

;;; Grid basic — depth 1 (plausibility)
