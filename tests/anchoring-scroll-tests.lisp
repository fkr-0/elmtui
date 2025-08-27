(uiop:define-package :elmtui.tests.anchoring-scroll
  (:use :cl :fiveam)
  (:import-from :elmtui.pipeline #:pre-render-terminal-prep)
  (:import-from :elmtui.contracts #:make-app-context)
  (:import-from :elmtui.tea-state #:apply-patches)
  (:import-from :elmtui.state.model #:make-state-patch)
  (:import-from :elmtui.platform.api #:scroll-lines #:clear-below-cursor))

(in-package :elmtui.tests.anchoring-scroll)

(defclass mock-backend ()
  ((scrolls :initform 0 :accessor scrolls)
   (clears  :initform 0 :accessor clears)))

(defmethod elmtui.platform.api:scroll-lines ((b mock-backend) (dir (eql :down)) count)
  (incf (scrolls b) (or count 0)) b)

(defmethod elmtui.platform.api:clear-below-cursor ((b mock-backend))
  (incf (clears b)) b)

(def-suite elmtui/anchoring-scroll)
(in-suite elmtui/anchoring-scroll)

(test pending-scroll-triggers-backend
  (let* ((backend (make-instance 'mock-backend))
         (state   (list :components :rv :state
                        '(:anchor :below-cursor :pending-scroll (:down 3))))
         (ctx     (make-app-context :state state :backend backend)))
    (let ((new-ctx (pre-render-terminal-prep ctx)))
      (declare (ignore new-ctx))
      (is (= 1 (clears backend)))
      (is (= 3 (scrolls backend))))))

(defun run-anchoring-scroll-tests () (run! :elmtui/anchoring-scroll))
