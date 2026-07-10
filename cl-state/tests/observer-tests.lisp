;;;===============================================================
;;; File: cl-state/tests/observer-tests.lisp
;;; Unit tests for cl-state.observer module
;;;===============================================================
(uiop:define-package :cl-state-tests.observer
  (:use :cl :fiveam :cl-state.api)
  (:export #:observer-suite
    #:run-observer-tests))

(in-package :cl-state-tests.observer)

(def-suite observer-suite
  :description "Tests for cl-state.observer module")

(in-suite observer-suite)

;;; add-observer tests

(test add-observer-single
  "Adding single observer for key"
  (let ((state (make-state))
         (called nil))
    (let ((fn (lambda (old new)
                (setf called (list old new)))))
      (add-observer state :test-key fn)
      (is (= 1 (length (application-state-observers state))))
      ;; Observer is stored - we can't directly test it gets called
      ;; because that happens in with-transaction, but we verify storage
      (let ((pair (assoc :test-key (application-state-observers state))))
        (is (not (null pair)))
        (is (= 1 (length (cdr pair))))))))

(test add-observer-multiple-same-key
  "Adding multiple observers for same key"
  (let ((state (make-state))
         (calls-1 nil)
         (calls-2 nil))
    (let ((fn1 (lambda (old new) (push (list old new) calls-1)))
           (fn2 (lambda (old new) (push (list old new) calls-2))))
      (add-observer state :key fn1)
      (add-observer state :key fn2)
      (let ((pair (assoc :key (application-state-observers state))))
        (is (not (null pair)))
        (is (= 2 (length (cdr pair))))))))

(test add-observer-different-keys
  "Adding observers for different keys"
  (let ((state (make-state)))
    (add-observer state :key1 (lambda (o n) (declare (ignore o n))))
    (add-observer state :key2 (lambda (o n) (declare (ignore o n))))
    (is (= 2 (length (application-state-observers state))))
    (is (assoc :key1 (application-state-observers state)))
    (is (assoc :key2 (application-state-observers state)))))

(test add-observer-returns-fn
  "add-observer returns the function"
  (let ((state (make-state))
         (fn (lambda (o n) (declare (ignore o n)))))
    (is (eq fn (add-observer state :key fn)))))

;;; remove-observer tests

(test remove-observer-existing
  "Removing existing observer"
  (let ((state (make-state))
         (fn (lambda (o n) (declare (ignore o n)))))
    (add-observer state :key fn)
    (is (= 1 (length (application-state-observers state))))
    (is (remove-observer state :key fn))
    ;; Empty observer buckets are removed to keep the registry compact.
    (let ((pair (assoc :key (application-state-observers state))))
      (is (null pair)))))

(test remove-observer-one-of-many
  "Removing one of multiple observers for same key"
  (let ((state (make-state))
         (fn1 (lambda (o n) (declare (ignore o n))))
         (fn2 (lambda (o n) (declare (ignore o n))))
         (fn3 (lambda (o n) (declare (ignore o n)))))
    (add-observer state :key fn1)
    (add-observer state :key fn2)
    (add-observer state :key fn3)
    (is (remove-observer state :key fn2))
    (let ((pair (assoc :key (application-state-observers state))))
      (is (not (null pair)))
      (is (= 2 (length (cdr pair))))
      (is (not (member fn2 (cdr pair)))))))

(test remove-observer-non-existent-key
  "Removing observer for non-existent key returns nil"
  (let ((state (make-state))
         (fn (lambda (o n) (declare (ignore o n)))))
    (is (null (remove-observer state :missing fn)))))

(test remove-observer-non-existent-fn
  "Removing non-existent observer returns nil"
  (let ((state (make-state))
         (fn1 (lambda (o n) (declare (ignore o n))))
         (fn2 (lambda (o n) (declare (ignore o n)))))
    (add-observer state :key fn1)
    (is (null (remove-observer state :key fn2)))))

;;; notify-observers tests

(test notify-observers-single
  "Notifying single observer"
  (let ((state (make-state))
         (received nil))
    (let ((fn (lambda (old new)
                (setf received (list old new)))))
      (add-observer state :key fn)
      (notify-observers state :key 1 2)
      (is (equal '(1 2) received)))))

(test notify-observers-multiple
  "Notifying multiple observers for same key"
  (let ((state (make-state))
         (calls nil))
    (let ((fn1 (lambda (old new) (push (list :fn1 old new) calls)))
           (fn2 (lambda (old new) (push (list :fn2 old new) calls))))
      (add-observer state :key fn1)
      (add-observer state :key fn2)
      (notify-observers state :key :old :new)
      (is (= 2 (length calls)))
      (is (some (lambda (c) (equal '(:fn1 :old :new) c)) calls))
      (is (some (lambda (c) (equal '(:fn2 :old :new) c)) calls)))))

(test notify-observers-no-observers
  "Notifying when no observers does nothing"
  (let ((state (make-state)))
    (notify-observers state :key 1 2)
    ;; Should not error - trivial assertion to verify we got here
    (is (= 1 1))))

(test notify-observers-wrong-key
  "Notifying for key with no observers does nothing"
  (let ((state (make-state))
         (called nil))
    (add-observer state :key1
                  (lambda (old-value new-value)
                    (declare (ignore old-value new-value))
                    (setf called t)))
    (notify-observers state :key2 1 2)
    (is (not called))))

;;; Observer integration with transactions

(test observer-called-in-transaction
  "Observers are called when changes happen in transaction"
  (let ((state (make-state))
         (old-value nil)
         (new-value nil))
    (add-observer state :counter
      (lambda (old new)
        (setf old-value old)
        (setf new-value new)))
    (with-transaction (state)
      (state-set state :counter 10))
    ;; Note: observers are called when transaction completes
    (is (eql :not-present old-value))
    (is (= 10 new-value))))

(test observer-multiple-changes
  "Observer called for each change in transaction"
  (let ((state (make-state))
         (changes nil))
    (state-set state :value 0)
    (add-observer state :value
      (lambda (old new)
        (push (list old new) changes)))
    (with-transaction (state)
      (state-set state :value 1)
      (state-set state :value 2)
      (state-set state :value 3))
    ;; Observer should be called for each change in the transaction
    (is (= 3 (length changes)))))

(defun run-observer-tests ()
  (run! 'observer-suite))
