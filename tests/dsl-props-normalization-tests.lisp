(uiop:define-package :elmtui.tests.dsl-props-normalization
  (:use :cl :fiveam)
  (:import-from :elmtui.view.base-elements
                #:container-element #:text-element
                #:element-children #:element-style #:element-id #:dsl->objects)
  (:import-from :elmtui.view.geo
                #:make-rectangle #:make-size #:make-pos #:w #:h)
  (:import-from :elmtui.view.element
                #:el/layout-rect)
  (:import-from :elmtui.contracts
                #:make-app-context)
  (:import-from :elmtui.view.tree-transforms
                #:process-tree))
(in-package :elmtui.tests.dsl-props-normalization)

(def-suite elmtui/dsl-props :in elmtui.tests:elmtui-test)
(in-suite elmtui/dsl-props)

(defun %vp (w h)
  (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w w :h h)))

(test id-keyword-values-are-preserved
  (let* ((dsl '(:container :id :my-node :style (:min-width 10) :children ((:text :content "x"))))
         (obj (dsl->objects dsl)))
    (is (typep obj 'container-element))
    (is (eq (element-id obj) :MY-NODE))
    (is (= 10 (getf (element-style obj) :min-width)))))

(test layout-respects-min-width-in-dsl
  (let* ((dsl '(:container :id :root :style (:display :flex)
                 :children ((:container :id :child :style (:min-width 10 :height 2)
                                         :children ((:text :content "x"))))))
         (laid (process-tree (dsl->objects dsl)
                             :ctx (make-app-context :viewport-rect (%vp 40 10))
                             :root-rect (%vp 40 10)))
         (child (car (element-children laid))))
    (let ((cw (elmtui.view.geo:w (el/layout-rect child)))
          (ch (elmtui.view.geo:h (el/layout-rect child))))
      (is-true (>= cw 10) (format nil "child width ~A is less than min-width 10" cw))
      (is (= ch 2)))))

(test viewport-wraps-flex-child-with-minwidth
  (let* ((viewport '(:container :id :vp :style (:width 80 :height 10)
                         :children ((:container :id :child :style (:min-width 10 :height 2 :display :flex)
                                                 :children ((:text :content "y"))))))
         (laid (process-tree (dsl->objects viewport)
                             :ctx (make-app-context :viewport-rect (%vp 80 10))
                             :root-rect (%vp 80 10)))
         (child (car (element-children laid)))
         (cw (elmtui.view.geo:w (el/layout-rect child)))
         (ch (elmtui.view.geo:h (el/layout-rect child))))
    (is-true (>= cw 10) (format nil "viewport child width ~A < 10" cw))
    (is (= ch 2))))
