(uiop:define-package :elmtui.tests.root-viewport
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.widgets.root-viewport
                #:root-viewport #:compute-anchor-offset #:compute-view-size)
  (:export #:run-root-viewport-tests))

(in-package :elmtui.tests.root-viewport)

(def-suite elmtui/root-vp)
(in-suite elmtui/root-vp)

(test anchor-offsets-basics
  (let ((cols 80) (rows 24) (w 20) (h 5) (cr 12) (cc 40))
    (multiple-value-bind (oy ox) (compute-anchor-offset :center w h cols rows cr cc)
      (is (>= oy 0)) (is (>= ox 0)))
    (multiple-value-bind (oy ox) (compute-anchor-offset :below-cursor w h cols rows cr cc)
      (is (>= oy (1+ cr))) (is (>= ox 0)))
    (multiple-value-bind (oy ox) (compute-anchor-offset :above-cursor w h cols rows cr cc)
      (is (<= oy cr)) (is (>= ox 0)))))

(test dynamic-view-size
  (let ((cols 80) (rows 24) (cr 12))
    (multiple-value-bind (w h _) (compute-view-size :below-cursor cols rows cr)
      (is (= w cols)) (is (= h (max 1 (- rows cr 1)))))
    (multiple-value-bind (w h _) (compute-view-size :above-cursor cols rows cr)
      (is (= w cols)) (is (= h (max 1 cr))))))

(defun run-root-viewport-tests () (run! :elmtui/root-vp))
