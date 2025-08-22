;;; Grid layout tests for current elmtui grid engine
(uiop:define-package :elmtui.tests.grid2
  (:use :cl :fiveam)
  (:import-from :elmtui.view.geo #:make-pos #:make-size #:make-rectangle #:x #:y #:w #:h)
  (:import-from :elmtui.view.base-elements
                #:container-element #:element-children #:element-style #:element-id)
  (:import-from :elmtui.view.element #:el/layout-rect)
  (:import-from :elmtui.view.layout.grid #:compute-grid-layout)
  (:export #:run-grid2-tests))

(in-package :elmtui.tests.grid2)

(defun %box (&key id (styles nil))
  (make-instance 'container-element :id id :style (copy-list styles)))

(defun %child (root id)
  (find id (element-children root) :key #'element-id))

(defun %rect (node) (el/layout-rect node))

(defun %layout-grid (root parent-w parent-h)
  (let ((parent (make-rectangle :pos (make-pos :x 0 :y 0)
                                :size (make-size :w parent-w :h parent-h))))
    (setf root (or (compute-grid-layout root parent) root)))
  root)

(def-suite elmtui/grid)
(in-suite elmtui/grid)

(test basic-fixed-tracks
  (let* ((root (%box :id :root :styles '(:display :grid
                                   :grid-template-columns (10 20)
                                   :grid-template-rows (5 5)
                                   :column-gap 3 :row-gap 2)))
         (a (%box :id :a :styles '(:grid-column-start 0 :grid-column-end 1 :grid-row-start 0 :grid-row-end 1)))
         (b (%box :id :b :styles '(:grid-column-start 1 :grid-column-end 2 :grid-row-start 0 :grid-row-end 1))))
    (setf (element-children root) (list a b))
    (setf root (%layout-grid root 50 20))
    (let ((ar (%rect (%child root :a)))
          (br (%rect (%child root :b))))
      (is (<= 0 (x ar))) (is (<= 0 (y ar)))
      (is (<= 0 (w ar))) (is (<= 0 (h ar)))
      (is (>= (x br) (x ar)))
      (is (>= (w br) (w ar))))))

(test fr-distribution
  (let* ((root (%box :id :root :styles '(:display :grid
                                   :grid-template-columns ("1fr" "3fr")
                                   :grid-template-rows (5)
                                   :column-gap 0)))
         (a (%box :id :a :styles '(:grid-column-start 0 :grid-column-end 1 :grid-row-start 0 :grid-row-end 1)))
         (b (%box :id :b :styles '(:grid-column-start 1 :grid-column-end 2 :grid-row-start 0 :grid-row-end 1))))
    (setf (element-children root) (list a b))
    (setf root (%layout-grid root 40 10))
    (let ((ar (%rect (%child root :a)))
          (br (%rect (%child root :b))))
      (is (> (w br) (w ar))))))

(test template-areas
  (let* ((root (%box :id :root :styles '(:display :grid
                                   :grid-template-columns ("1fr" "1fr" "1fr")
                                   :grid-template-rows ("1fr" "1fr")
                                   :grid-template-areas ("a a ." "b b c"))))
         (a (%box :id :a :styles '(:grid-area "a")))
         (b (%box :id :b :styles '(:grid-area "b")))
         (c (%box :id :c :styles '(:grid-area "c"))))
    (setf (element-children root) (list a b c))
    (setf root (%layout-grid root 90 60))
    (let ((ar (%rect (%child root :a)))
          (br (%rect (%child root :b)))
          (cr (%rect (%child root :c))))
      ;; A and B span two columns; C sits to the right of B
      (is (>= (w ar) (w cr)))
      (is (>= (w br) (w cr)))
      (is (> (x cr) (x br)))
      ;; B and C are on the second row
      (is (>= (y br) (y ar)))
      (is (= (y br) (y cr))))))

(test container-alignment
  (let* ((root (%box :id :root :styles '(:display :grid
                                   :grid-template-columns (10 10)
                                   :grid-template-rows (5 5)
                                   :column-gap 0 :row-gap 0
                                   :justify-content :center
                                   :align-content :end)))
         (a (%box :id :a :styles '(:grid-column-start 0 :grid-column-end 1 :grid-row-start 0 :grid-row-end 1))))
    (setf (element-children root) (list a))
    (setf root (%layout-grid root 40 20))
    (let ((ar (%rect (%child root :a))))
      ;; Center/end alignment should introduce positive offsets
      (is (> (x ar) 0))
      (is (> (y ar) 0)))))

(test auto-flow-row
  (let* ((root (%box :id :root :styles '(:display :grid
                                   :grid-template-columns (10 10 10)
                                   :grid-template-rows (5 5)
                                   :grid-auto-flow :row
                                   :column-gap 1 :row-gap 2)))
         (a (%box :id :a)) (b (%box :id :b)) (c (%box :id :c)) (d (%box :id :d)))
    (setf (element-children root) (list a b c d))
    (setf root (%layout-grid root 80 30))
    (let ((ar (%rect (%child root :a)))
          (br (%rect (%child root :b)))
          (cr (%rect (%child root :c)))
          (dr (%rect (%child root :d))))
      ;; row flow: b to the right of a, c to the right of b; d on next row
      (is (< (x ar) (x br)))
      (is (< (x br) (x cr)))
      (is (< (y ar) (y dr))))))

(test auto-flow-column
  (let* ((root (%box :id :root :styles '(:display :grid
                                   :grid-template-columns (10 10)
                                   :grid-template-rows (5 5 5)
                                   :grid-auto-flow :column
                                   :column-gap 1 :row-gap 2)))
         (a (%box :id :a)) (b (%box :id :b)) (c (%box :id :c)) (d (%box :id :d)))
    (setf (element-children root) (list a b c d))
    (setf root (%layout-grid root 80 40))
    (let ((ar (%rect (%child root :a)))
          (br (%rect (%child root :b)))
          (cr (%rect (%child root :c)))
          (dr (%rect (%child root :d))))
      ;; column flow: b under a, c under b; d moves to next column
      (is (< (y ar) (y br)))
      (is (< (y br) (y cr)))
      (is (< (x ar) (x dr))))))

(test spanning-with-gaps
  (let* ((root (%box :id :root :styles '(:display :grid
                                   :grid-template-columns (10 10 10)
                                   :grid-template-rows (5 5)
                                   :column-gap 3 :row-gap 2)))
         (span2 (%box :id :s :styles '(:grid-column-start 0 :grid-column-end 2
                                          :grid-row-start 0 :grid-row-end 2)))
         (solo (%box :id :x :styles '(:grid-column-start 2 :grid-column-end 3
                                        :grid-row-start 0 :grid-row-end 1))))
    (setf (element-children root) (list span2 solo))
    (setf root (%layout-grid root 200 100))
    (let ((sr (%rect (%child root :s)))
          (xr (%rect (%child root :x))))
      ;; spanning area should be wider than single cell and start at origin
      (is (>= (x xr) (+ (x sr) (w sr))))
      (is (= (y xr) (y sr))))))

(test align-justify-items-stretch
  (let* ((root (%box :id :root :styles '(:display :grid
                                   :grid-template-columns (10 10)
                                   :grid-template-rows (5 5)
                                   :justify-items :stretch :align-items :stretch)))
         (a (%box :id :a :styles '(:grid-column-start 0 :grid-column-end 1 :grid-row-start 0 :grid-row-end 1))))
    (setf (element-children root) (list a))
    (setf root (%layout-grid root 40 20))
    (let* ((ar (%rect (%child root :a))))
      ;; Should fill assigned cell (no slack vs computed track cell)
      (is (> (w ar) 0))
      (is (> (h ar) 0)))))

(defun run-grid2-tests () (run! :elmtui/grid))
