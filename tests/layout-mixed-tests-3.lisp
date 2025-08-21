;; == elmtui/tests/layout-smoke-fiveam.lisp ==
;; Smoke-plausibility tests for block, flex, and grid.
;; Focus: “reasonable” placement, containment, and deltas — robust across minor algo changes.
;;
;; Notes:
;; - We *always* re-find nodes by :id in the *laid-out tree* returned by `process-tree`.
;; - Assertions prefer relative relations (deltas/containment) over absolute world coords.
;; - Grid checks are plausibility-only (rects exist + containment). We avoid requiring distinct positions
;;   because grid policy may be WIP; nested-flex inside a grid cell is verified via intra-cell deltas.

(uiop:define-package :elmtui.tests.layout-smoke
  (:use :cl :fiveam)
  (:import-from :elmtui.view.geo
                #:make-pos #:make-size #:make-rectangle #:x #:y #:w #:h #:rectangle)
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

(defun %vp (w h)
  (make-rectangle
   :pos  (make-pos :x 0 :y 0)
   :size (make-size :w w :h h)))

(defun %rect (node) (el/layout-rect node))
(defun %rx (node) (x (%rect node)))
(defun %ry (node) (y (%rect node)))
(defun %rw (node) (w (%rect node)))
(defun %rh (node) (h (%rect node)))

(defun %has-rect-p (node)
  (typep (%rect node) 'rectangle))

(defun %ensure-rect (node)
  (unless (%has-rect-p node)
    (error "Node ~S has no layout rect." (ignore-errors (element-id node))))
  (%rect node))

(defun %inside-p (child parent)
  (let ((cr (%ensure-rect child))
        (pr (%ensure-rect parent)))
    (and (<= (x pr) (x cr))
         (<= (y pr) (y cr))
         (<= (+ (x cr) (w cr)) (+ (x pr) (w pr)))
         (<= (+ (y cr) (h cr)) (+ (y pr) (h pr))))))

(defun %run (root vpw vph)
  (let ((vp (%vp vpw vph)))
    (process-tree root :ctx (make-app-context :viewport-rect vp) :root-rect vp)))

(defun %id-of (n)
  (ignore-errors (element-id n)))

(defun %find-deep (root id)
  (labels ((walk (n)
             (when (eql (%id-of n) id) (return-from walk n))
             (dolist (c (element-children n))
               (let ((hit (walk c)))
                 (when hit (return-from walk hit))))
             nil))
    (or (walk root) (error "Node with id ~S not found in laid-out tree." id))))

(defmacro approx= (a b &optional (eps 1e-4))
  `(let ((aa (coerce ,a 'double-float))
         (bb (coerce ,b 'double-float)))
     (< (abs (- aa bb)) ,eps)))

;;; ───────────────────────── suite ─────────────────────────

(def-suite  layout/smoke
  :in elmtui.tests:elmtui-test)
(in-suite  layout/smoke)


;;; BLOCK ───────────────────────────────────────────────────

(test block-depth1-content-box
  "Root (block, pad-left=2 pad-top=1) → child (block). Child sits at content origin; contained."
  (let* ((root  (make-instance 'container-element
                               :id :root
                               :style '(:display :block :padding-left 2 :padding-top 1)))
         (child (make-instance 'container-element :id :child :style '()))
         (_     (setf (element-children root) (list child)))
         (laid  (%run root 20 6))
         (R     laid)
         (C     (%find-deep R :child)))
    (is (%has-rect-p R))
    (is (%has-rect-p C))
    (is (= (%rx C) (+ (%rx R) 2)))
    (is (= (%ry C) (+ (%ry R) 1)))
    (is (>= (%rw C) 0))
    (is (>= (%rh C) 0))
    (is (%inside-p C R))))

(test block-depth2-accumulated-offsets
  "Root pad(2,1) → mid pad(3,2) → leaf(text). Offsets accumulate; leaf inside root."
  (let* ((root (make-instance 'container-element :id :root
                                                 :style '(:display :block :padding-left 2 :padding-top 1)))
         (mid  (make-instance 'container-element :id :mid
                                                 :style '(:display :block :padding-left 3 :padding-top 2)))
         (leaf (make-instance 'text-element :id :leaf))
         (_    (setf (element-children mid) (list leaf)))
         (_    (setf (element-children root) (list mid)))
         (laid (%run root 30 10))
         (R laid) (M (%find-deep R :mid)) (L (%find-deep R :leaf)))
    (is (%has-rect-p R)) (is (%has-rect-p M)) (is (%has-rect-p L))
    (is (= (%rx M) (+ (%rx R) 2)))
    (is (= (%ry M) (+ (%ry R) 1)))
    (is (= (%rx L) (+ (%rx M) 3)))
    (is (= (%ry L) (+ (%ry M) 2)))
    (is (%inside-p L R))))

;;; FLEX ────────────────────────────────────────────────────

(test flex-row-gap-delta
  "Row flex: pad-left=1 gap=2, A(4×2) B(5×2). Check delta along main-axis equals w(A)+gap."
  (let* ((root (make-instance 'container-element :id :root
                                                 :style '(:display :flex :flex-direction :row
                                                          :padding-left 1 :gap 2)))
         (a (make-instance 'container-element :id :a :style '(:width 4 :height 2)))
         (b (make-instance 'container-element :id :b :style '(:width 5 :height 2)))
         (_ (setf (element-children root) (list a b)))
         (laid (%run root 20 6))
         (R laid) (A (%find-deep R :a)) (B (%find-deep R :b)))
    (is (%has-rect-p A)) (is (%has-rect-p B))
    ;; delta-only (robust to starting offset): B.x - A.x == A.w + gap
    (is (= (- (%rx B) (%rx A)) (+ (%rw A) 2)))
    (is (= (%ry A) (%ry B))) ; same row
    (is (= (%rw A) 4)) (is (= (%rw B) 5))
    (is (%inside-p A R)) (is (%inside-p B R))))

(test flex-nested-column-row
  "Nested flex: root column (pad-top=1) → inner row (gap=2) → A(3) B(4). Inner.y shifts by pad, row delta matches A.w+gap."
  (let* ((root  (make-instance 'container-element :id :root
                                                  :style '(:display :flex :flex-direction :column :padding-top 1)))
         (inner (make-instance 'container-element :id :inner
                                                  :style '(:display :flex :flex-direction :row :gap 2)))
         (a     (make-instance 'container-element :id :a :style '(:width 3 :height 2)))
         (b     (make-instance 'container-element :id :b :style '(:width 4 :height 2)))
         (_     (setf (element-children inner) (list a b)))
         (_     (setf (element-children root) (list inner)))
         (laid  (%run root 20 8))
         (R laid) (I (%find-deep R :inner)) (A (%find-deep R :a)) (B (%find-deep R :b)))
    (is (%has-rect-p I)) (is (%has-rect-p A)) (is (%has-rect-p B))
    (is (= (- (%ry I) (%ry R)) 1)) ; pad-top only
    (is (= (- (%rx B) (%rx A)) (+ (%rw A) 2))) ; row delta = A.w + gap
    (is (%inside-p I R)) (is (%inside-p A I)) (is (%inside-p B I))))

;;; GRID (plausibility-only) ────────────────────────────────

(test grid-basic-children-have-rects
  "Grid root with 4 children. Plausibility only: rects exist & are inside; at least one non-zero."
  (let* ((root (make-instance 'container-element :id :root :style '(:display :grid)))
         (a (make-instance 'container-element :id :a))
         (b (make-instance 'container-element :id :b))
         (c (make-instance 'container-element :id :c))
         (d (make-instance 'container-element :id :d))
         (_ (setf (element-children root) (list a b c d)))
         (laid (%run root 20 10))
         (R laid) (A (%find-deep R :a)) (B (%find-deep R :b)) (C (%find-deep R :c)) (D (%find-deep R :d)))
    (dolist (n (list A B C D))
      (is (%has-rect-p n))
      (is (%inside-p n R)))
    ;; at least one child gets non-zero area (weak but meaningful guard)
    (is (some (lambda (n) (> (* (%rw n) (%rh n)) 0)) (list A B C D)))))

(test grid-nested-flex
  "Grid → cell-b hosts a row flex (gap=1). Check inner flex delta inside the cell."
  (let* ((root   (make-instance 'container-element :id :root :style '(:display :grid)))
         (cell-a (make-instance 'container-element :id :cell-a))
         (cell-b (make-instance 'container-element :id :cell-b
                                                   :style '(:display :flex :flex-direction :row :gap 1)))
         (c1 (make-instance 'container-element :id :c1 :style '(:width 3 :height 1)))
         (c2 (make-instance 'container-element :id :c2 :style '(:width 2 :height 1)))
         (_  (setf (element-children cell-b) (list c1 c2)))
         (_  (setf (element-children root) (list cell-a cell-b)))
         (laid (%run root 24 10))
         (R laid) (B (%find-deep R :cell-b)) (C1 (%find-deep R :c1)) (C2 (%find-deep R :c2)))
    (is (%has-rect-p B)) (is (%has-rect-p C1)) (is (%has-rect-p C2))
    (is (%inside-p B R))
    (is (%inside-p C1 B))
    (is (%inside-p C2 B))
    ;; delta inside cell: C2.x - C1.x == C1.w + gap (1)
    (is (= (- (%rx C2) (%rx C1)) (+ (%rw C1) 1)))))


;;; DEEP MIXED (flex → grid → flex) ────────────────────────

(test deep-mixed-accumulation
  "Root flex(row, pad-left=1 gap=2) → mid grid → leaf flex(row, gap=1).
   Assertions: monotone X offsets root≤mid≤leaf; inner row delta matches la.w+gap."
  (let* ((root (make-instance 'container-element :id :root
                                                 :style '(:display :flex :flex-direction :row
                                                          :padding-left 1 :gap 2)))
         (mid  (make-instance 'container-element :id :mid :style '(:display :grid)))
         (pad  (make-instance 'container-element :id :pad :style '(:width 3 :height 2)))
         (leaf (make-instance 'container-element :id :leaf
                                                 :style '(:display :flex :flex-direction :row :gap 1)))
         (la   (make-instance 'container-element :id :la :style '(:width 2 :height 1)))
         (lb   (make-instance 'container-element :id :lb :style '(:width 2 :height 1)))
         (_    (setf (element-children leaf) (list la lb)))
         (_    (setf (element-children mid)  (list leaf)))
         (_    (setf (element-children root) (list pad mid)))
         (laid (%run root 30 10))
         (R laid) (M (%find-deep R :mid)) (L (%find-deep R :leaf))
         (LA (%find-deep R :la)) (LB (%find-deep R :lb)))
    (is (%has-rect-p R)) (is (%has-rect-p M)) (is (%has-rect-p L))
    ;; monotone main-axis offsets (don’t assume exact numbers)
    (is (<= (%rx R) (%rx M)))
    (is (<= (%rx M) (%rx L)))
    ;; inner row delta: LB.x - LA.x == LA.w + gap(=1)
    (is (= (- (%rx LB) (%rx LA)) (+ (%rw LA) 1)))
    (is (%inside-p L M))
    (is (%inside-p M R))))

;; (defun run-layout-smoke-tests ()
;;   (run! :layout/smoke))

;; == end/layout-smoke-fiveam.lisp ==
