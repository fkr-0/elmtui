;;; Additional flex layout tests: auto-wrap, align-items/self, nesting
(uiop:define-package :elmtui.tests.flex2
  (:use :cl :fiveam)
  (:import-from :elmtui.view.geo #:make-pos #:make-size #:make-rectangle #:x #:y #:w #:h)
  (:import-from :elmtui.view.base-elements
                #:container-element #:element-children #:element-style #:element-id)
  (:import-from :elmtui.view.element #:el/layout-rect)
  (:export #:run-flex2-tests))

(in-package :elmtui.tests.flex2)

(defun %box (&key id (w nil) (h nil) (styles nil))
  (let ((node (make-instance 'container-element :id id :style (copy-list styles))))
    (when w (push :width (element-style node)) (push w (element-style node)))
    (when h (push :height (element-style node)) (push h (element-style node)))
    node))

(defun %rect (node) (el/layout-rect node))

(defun %child (root id) (find id (element-children root) :key #'element-id))

(defun %layout-flex (root pw ph)
  (let ((parent (make-rectangle :pos (make-pos :x 0 :y 0)
                                :size (make-size :w pw :h ph))))
    (let* ((compute (intern "COMPUTE-LAYOUT" :elmtui.view.base-elements)))
      (funcall compute root parent))
    root))

(def-suite elmtui/flex2)
(in-suite elmtui/flex2)

(test auto-wrap-row
  (let* ((root (%box :id :root :styles '(:display :flex :flex-direction :row :gap 1 :width 15 :height 10)))
         (a (%box :id :a :w 5 :h 2)) (b (%box :id :b :w 5 :h 2)) (c (%box :id :c :w 5 :h 2)))
    (setf (element-children root) (list a b c))
    ;; enable wrapping
    (push :flex-wrap (element-style root)) (push :wrap (element-style root))
    (%layout-flex root 15 10)
    (let ((ar (%rect (%child root :a))) (br (%rect (%child root :b))) (cr (%rect (%child root :c))))
      ;; c should wrap to next line due to width constraint
      (is (< (x ar) (x br)))
      (is (> (y cr) (y ar))))))

(test align-items-cross-axis
  (let* ((root (%box :id :root :styles '(:display :flex :flex-direction :row :align-items :center :height 10 :width 30)))
         (a (%box :id :a :w 5 :h 2)))
    (setf (element-children root) (list a))
    (%layout-flex root 30 10)
    (let ((ar (%rect (%child root :a))))
      ;; centered on cross-axis (vertical): y > 0
      (is (> (y ar) 0)))))

(test align-self-override
  (let* ((root (%box :id :root :styles '(:display :flex :flex-direction :row :align-items :flex-start :height 10 :width 30)))
         (a (%box :id :a :w 5 :h 2 :styles '(:align-self :end))))
    (setf (element-children root) (list a))
    (%layout-flex root 30 10)
    (let ((ar (%rect (%child root :a))))
      ;; align-self:end pushes item to bottom within cross-size
      (is (> (y ar) 0)))))

(test nested-flex
  (let* ((inner (%box :id :inner :styles '(:display :flex :flex-direction :column :justify-content :center)))
         (i1 (%box :id :i1 :w 4 :h 1)) (i2 (%box :id :i2 :w 4 :h 1))
         (outer (%box :id :outer :styles '(:display :flex :flex-direction :row :gap 1 :padding-left 1)))
         (left (%box :id :left :w 5 :h 2))
         (right inner))
    (setf (element-children inner) (list i1 i2))
    (setf (element-children outer) (list left right))
    (%layout-flex outer 30 10)
    (let* ((lr (%rect (%child outer :left)))
           (ir (%rect (%child outer :inner))))
      (is (< (x lr) (x ir)))
      ;; inner children stacked
      (let ((i1r (%rect (%child inner :i1))) (i2r (%rect (%child inner :i2))))
        (is (< (y i1r) (y i2r)))))))

(defun run-flex2-tests () (run! :elmtui/flex2))

