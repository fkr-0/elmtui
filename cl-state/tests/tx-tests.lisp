;;;===============================================================
;;; File: cl-state/tests/tx-tests.lisp
;;; Unit tests for cl-state.tx module
;;;===============================================================
(uiop:define-package :cl-state-tests.tx
  (:use :cl :fiveam :cl-state.api)
  (:export #:tx-suite
           #:run-tx-tests))

(in-package :cl-state-tests.tx)

(def-suite tx-suite
  :description "Tests for cl-state.tx module")

(in-suite tx-suite)

;;; with-transaction tests

(test with-transaction-basic
  "Basic transaction creates history entry"
  (let ((state (make-state)))
    (with-transaction (state :name :test-tx)
      (state-set state :a 1)
      (state-set state :b 2))
    (is (= 1 (length (application-state-history state))))
    (is (= 1 (state-ref state :a)))
    (is (= 2 (state-ref state :b)))))

(test with-transaction-name
  "Transaction stores name"
  (let ((state (make-state)))
    (with-transaction (state :name :my-tx)
      (state-set state :a 1))
    (let ((tx (first (application-state-history state))))
      (is (eq :my-tx (tx-name tx))))))

(test with-transaction-changes
  "Transaction records changes"
  (let ((state (make-state)))
    (state-set state :a 0) ;; Set initial value
    (with-transaction (state :name :test)
      (state-set state :a 1)
      (state-set state :b 2))
    (let ((tx (first (application-state-history state))))
      (is (= 2 (length (tx-changes tx))))
      ;; Changes are (key old new)
      (is (some (lambda (c) (and (eq :a (first c)) (= 0 (second c)) (= 1 (third c))))
                (tx-changes tx))))))

(test with-transaction-clears-undone
  "New transaction clears undone stack"
  (let ((state (make-state)))
    (with-transaction (state)
      (state-set state :a 1))
    (undo state)
    (is (= 1 (length (application-state-undone state))))
    (with-transaction (state)
      (state-set state :b 2))
    (is (null (application-state-undone state)))))

(test with-transaction-empty
  "Empty transaction still creates history entry"
  (let ((state (make-state)))
    (with-transaction (state))
    (is (= 1 (length (application-state-history state))))))

(test with-transaction-nested-calls
  "Nested state-set calls work within transaction"
  (let ((state (make-state)))
    (with-transaction (state)
      (state-set state '(:outer :inner) 42))
    (is (= 42 (state-ref state '(:outer :inner))))))

(test with-transaction-preserves-multiple-values
  "with-transaction should preserve all values produced by the wrapped body."
  (let ((state (make-state)))
    (multiple-value-bind (a b c)
        (with-transaction (state :name :multi-values)
          (state-set state :a 1)
          (values :x :y :z))
      (is (eq :x a))
      (is (eq :y b))
      (is (eq :z c)))))

;;; undo tests

(test undo-single-change
  "Undo single change transaction"
  (let ((state (make-state)))
    (with-transaction (state)
      (state-set state :a 1))
    (is (= 1 (state-ref state :a)))
    (undo state)
    (is (null (state-ref state :a nil)))))

(test undo-multiple-changes
  "Undo transaction with multiple changes"
  (let ((state (make-state)))
    (state-set state :a 0)
    (state-set state :b 0)
    (with-transaction (state)
      (state-set state :a 1)
      (state-set state :b 2))
    (undo state)
    (is (= 0 (state-ref state :a)))
    (is (= 0 (state-ref state :b)))))

(test undo-multiple-transactions
  "Undo multiple transactions in sequence"
  (let ((state (make-state)))
    (with-transaction (state :name :tx1)
      (state-set state :a 1))
    (with-transaction (state :name :tx2)
      (state-set state :b 2))
    (is (= 1 (state-ref state :a)))
    (is (= 2 (state-ref state :b)))
    (undo state)
    (is (= 1 (state-ref state :a)))
    (is (null (state-ref state :b nil)))
    (undo state)
    (is (null (state-ref state :a nil)))))

(test undo-moves-to-undone
  "Undo moves transaction to undone stack"
  (let ((state (make-state)))
    (with-transaction (state)
      (state-set state :a 1))
    (is (= 1 (length (application-state-history state))))
    (is (null (application-state-undone state)))
    (undo state)
    (is (null (application-state-history state)))
    (is (= 1 (length (application-state-undone state))))))

(test undo-empty-history
  "Undo with empty history does nothing"
  (let ((state (make-state)))
    (is (null (undo state)))))

(test undo-new-key
  "Undo restores state for new keys"
  (let ((state (make-state)))
    (with-transaction (state)
      (state-set state :new-key 42))
    (is (= 42 (state-ref state :new-key)))
    (undo state)
    (is (null (state-ref state :new-key nil)))))

;;; redo tests

(test redo-after-undo
  "Redo after undo restores changes"
  (let ((state (make-state)))
    (with-transaction (state)
      (state-set state :a 1))
    (undo state)
    (is (null (state-ref state :a nil)))
    (redo state)
    (is (= 1 (state-ref state :a)))))

(test redo-multiple-transactions
  "Redo multiple undone transactions"
  (let ((state (make-state)))
    (with-transaction (state :name :tx1)
      (state-set state :a 1))
    (with-transaction (state :name :tx2)
      (state-set state :b 2))
    (undo state)
    (undo state)
    (redo state)
    (is (= 1 (state-ref state :a)))
    (is (null (state-ref state :b nil)))
    (redo state)
    (is (= 1 (state-ref state :a)))
    (is (= 2 (state-ref state :b)))))

(test redo-moves-to-history
  "Redo moves transaction back to history"
  (let ((state (make-state)))
    (with-transaction (state)
      (state-set state :a 1))
    (undo state)
    (is (null (application-state-history state)))
    (is (= 1 (length (application-state-undone state))))
    (redo state)
    (is (= 1 (length (application-state-history state)))
    (is (null (application-state-undone state))))))

(test redo-empty-undone
  "Redo with empty undone stack does nothing"
  (let ((state (make-state)))
    (with-transaction (state)
      (state-set state :a 1))
    (is (null (redo state)))))

(test redo-clears-undone-on-new-tx
  "New transaction after undo clears redo stack"
  (let ((state (make-state)))
    (with-transaction (state)
      (state-set state :a 1))
    (undo state)
    (is (= 1 (length (application-state-undone state))))
    (with-transaction (state)
      (state-set state :b 2))
    (is (null (application-state-undone state)))
    (is (null (redo state)))))

(defun run-tx-tests ()
  (run! 'tx-suite))
