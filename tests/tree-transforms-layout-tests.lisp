(uiop:define-package :elmtui.tests.tree-transforms
  (:use :cl :fiveam)
  (:import-from :elmtui.view.base-elements
                #:container-element #:text-element
                #:element-children)
  (:import-from :elmtui.view.geo
                #:make-rectangle #:make-size #:make-pos #:w #:h)
  (:import-from :elmtui.view.element
                #:el/layout-rect)
  (:import-from :elmtui.contracts
                #:make-app-context)
  (:import-from :elmtui.view.tree-transforms
                #:process-tree))
(in-package :elmtui.tests.tree-transforms)

(def-suite elmtui/tree-transforms :in elmtui.tests:elmtui-test)
(in-suite elmtui/tree-transforms)

(defun %vp (w h)
  (make-rectangle :pos (make-pos :x 0 :y 0)
                  :size (make-size :w w :h h)))

(defun %layout (root w h)
  (process-tree root :ctx (make-app-context :viewport-rect (%vp w h)) :root-rect (%vp w h)))

(test child-rect-propagation-to-descendants
  (let* ((root (make-instance 'container-element :id :root :style '(:display :flex :flex-direction :row :gap 1)))
         (a    (make-instance 'container-element :id :a    :style '(:width 10 :height 3)))
         (b    (make-instance 'text-element      :id :b    :content "hello world"))
         (_    (setf (element-children a) (list b)))
         (_    (setf (element-children root) (list a)))
         (laid (%layout root 80 10))
         (A    (car (element-children laid)))
         (B    (car (element-children A))))
    (is (= 10 (elmtui.view.geo:w (el/layout-rect A)))
        "Container A width remains fixed (not overridden by viewport).")
    (is (<= (elmtui.view.geo:w (el/layout-rect B))
            (elmtui.view.geo:w (el/layout-rect A)))
        "Descendant B receives A's rect, not the parent's rect.")))

(test sibling-placement-and-child-bounds
  (let* ((root (make-instance 'container-element :id :root :style '(:display :flex :flex-direction :row :gap 2)))
         (a    (make-instance 'container-element :id :a :style '(:width 4 :height 2)))
         (b    (make-instance 'container-element :id :b :style '(:width 5 :height 2)))
         (leaf (make-instance 'text-element      :id :leaf :content "xx"))
         (_    (setf (element-children a) (list leaf)))
         (_    (setf (element-children root) (list a b)))
         (laid (%layout root 20 6))
         (A    (car (element-children laid)))
         (B    (cadr (element-children laid)))
         (Leaf (car (element-children A))))
    ;; A at x>=0, B starts at or after A's right edge (gap accepted if present)
    (is (= 0 (elmtui.view.geo:x (el/layout-rect A))))
    (is (>= (elmtui.view.geo:x (el/layout-rect B))
            (elmtui.view.geo:w (el/layout-rect A))))
    ;; Leaf must fit within A
    (is (<= (elmtui.view.geo:w (el/layout-rect Leaf))
            (elmtui.view.geo:w (el/layout-rect A))))))
