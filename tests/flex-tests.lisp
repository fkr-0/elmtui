;; == tests/flex-offset-test.lisp ==
;;; Patch #4 – FiveAM regression (run (fiveam:run! :flex-offset)) ─────────────

(defpackage :elmtui.flex.tests
  (:use :cl :fiveam :elmtui.view.layout :elmtui.view.layout.flex))
(in-package :elmtui.flex.tests)

(def-suite flex-offset
  :in elmtui.tests:elmtui-test
  :description "Comprehensive test suite for Elmtui contract system")
(in-suite flex-offset)

(test grandchildren-get-offset
  (let* ((root (make-instance 'flex-container
                              :rectangle (elmtui.view.geo:make-rectangle
                                          :pos (elmtui.view.geo:make-pos :x 10 :y 5)
                                          :size (elmtui.view.geo:make-size :w 100 :h 40))
                              :children nil))
         (child-a (make-instance 'flex-container
                                 :rectangle (elmtui.view.geo:make-rectangle
                                             :pos (elmtui.view.geo:make-pos :x 0 :y 0)
                                             :size (elmtui.view.geo:make-size :w 30 :h 20))
                                 :children nil))
         (grand (make-instance 'flex-item
                               :rectangle (elmtui.view.geo:make-rectangle
                                           :pos (elmtui.view.geo:make-pos :x 0 :y 0)
                                           :size (elmtui.view.geo:make-size :w 10 :h 10)))))
    (push grand (flex-item-children child-a))
    (push child-a (flex-item-children root))

    (layout-flex-container root)
    ;; (dump-rect-tree
    ;; root)
    ;; (list grand child-a root)
    (is (= 10 (elmtui.view.geo:x (et.geo:rectangle child-a))))
    (is (= 5  (elmtui.view.geo:y (et.geo:rectangle child-a))))
    (is (= 10 (elmtui.view.geo:x (et.geo:rectangle grand))) "grandchild got X offset")
    (is (= 5  (elmtui.view.geo:y (et.geo:rectangle grand))) "grandchild got Y offset")))

;; == end/flex-offset-test.lisp ==
