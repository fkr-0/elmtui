;;;===============================================================
;;; File: cl-state/tests/cl-state-tests.lisp
;;; Unit tests for cl-state
;;;===============================================================
(uiop:define-package :cl-state-tests
  (:use :cl :fiveam :cl-state.api)
  (:export :run-cl-state-tests))

(in-package :cl-state-tests)

(def-suite cl-state-suite
  :description "Tests for the cl-state core API.")

(in-suite cl-state-suite)

(test make-state-basic
  (let ((state (make-state)))
    (is (application-state-p state))
    (is (hash-table-p (application-state-data state)))
    (is (eq (application-state-backend state) :hash-table))))

(test state-ref-basic
  (let ((state (make-state)))
    (setf (state-ref state '(:a :b)) 1)
    (is (= (state-ref state '(:a :b)) 1))
    (is (= (state-ref state '(:missing) 42) 42))))

(test merge-patches-basic
  (let* ((state (make-state))
         (data (application-state-data state)))
    (merge-patch data '((:user :name) "Alice"))
    (merge-patches data '(((user :age) 30) ((settings :theme) :dark)))
    (is (equal (get-path '(:user :name) data) "Alice"))
    (is (equal (get-path '(:user :age) data) 30))
    (is (equal (get-path '(:settings :theme) data) :dark))
    (merge-patch data '((:user :age) :elmtui-delete-path))
    (is (null (get-path '(:user :age) data)))))

(test transaction-undo-redo
  (let ((state (make-state)))
    (with-transaction (state :name :tx1)
      (state-set state :a 1)
      (state-set state :b 2))
    (is (= (length (application-state-history state)) 1))
    (undo state)
    (is (null (state-ref state :b)))
    (redo state)
    (is (= (state-ref state :b) 2))))

(defun run-cl-state-tests ()
  (run! 'cl-state-suite))
