;;;; update-dsl-appstate-tests.lisp --- Tests for update-dsl API with application-state

(uiop:define-package :elmtui.update-dsl.appstate-tests
  (:use :cl :fiveam
        :elmtui.tea-state.api
   :elmtui.update-dsl.api
        :elmtui.update-dsl))

(in-package :elmtui.update-dsl.appstate-tests)

(def-suite update-dsl-appstate-suite)

(in-suite update-dsl-appstate-suite)

(defvar *test-app-state* nil)

(defun make-test-app-state ()
  (elmtui.tea-state:make-state

   (list :counter 0 :flag nil :data (list :x 1 :y 2))))

;; (with-fixture reset-app-state ()
;;   (setf *test-app-state* (make-test-app-state)))
(def-fixture reset-app-state ()
  "Resets the test application state to a known initial state."
  (setf *test-app-state* (make-test-app-state)))
(test state-get/set
  (with-fixture reset-app-state ()
    (with-cycle (ctx *test-app-state*)
      (is (= (state> :counter) 0))
      (setf (state> :counter) 42)
      (is (= (state> :counter) 42))
      (setf (state> :flag) t)
      (is (state> :flag)))))

(test state-patch
  (with-fixture reset-app-state ()
    (state-patch *test-app-state*
                 (list (make-patch :path '(:counter) :value 99)
                       (make-patch :path '(:flag) :value nil)))
    (is (= (state-get *test-app-state* :counter) 99))
    (is (not (state-get *test-app-state* :flag)))))

(test state-observe
  (with-fixture reset-app-state ()
    (let ((called nil))
      (state-observe *test-app-state* :counter
                     (lambda (old new) (setf called (list old new))))
      (state-set *test-app-state* :counter 123)
      (is (equal called (list 0 123))))))

(test transaction-undo-redo
  (with-fixture reset-app-state ()
    (state-set *test-app-state* :counter 1)
    (state-set *test-app-state* :counter 2)
    (undo-update-state *test-app-state*)
    (is (= (state-get *test-app-state* :counter) 1))
    (redo-update-state *test-app-state*)
    (is (= (state-get *test-app-state* :counter) 2))))

(test with-update-transaction
  (with-fixture reset-app-state ()
    (with-update-transaction *test-app-state* :tx1
      (lambda (state)
        (state-set state :counter 77)
        (state-set state :flag t)))
    (is (= (state-get *test-app-state* :counter) 77))
    (is (state-get *test-app-state* :flag))))

;; (run! 'update-dsl-appstate-suite)
