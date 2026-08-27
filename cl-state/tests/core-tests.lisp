;;;===============================================================
;;; File: cl-state/tests/core-tests.lisp
;;; Unit tests for cl-state.core module
;;;===============================================================
(uiop:define-package :cl-state-tests.core
  (:use :cl :fiveam :cl-state.api)
  (:export #:core-suite
    #:run-core-tests))

(in-package :cl-state-tests.core)

(def-suite core-suite
  :description "Tests for cl-state.core module")

(in-suite core-suite)

;;; make-state tests

(test make-state-default
  "Creating state with defaults"
  (let ((state (make-state)))
    (is (application-state-p state))
    (is (hash-table-p (application-state-data state)))
    (is (eq (application-state-backend state) :hash-table))
    (is (zerop (hash-table-count (application-state-data state))))))

(test make-state-with-plist-initial
  "Creating state with plist initial data"
  (let ((state (make-state :initial '(:a 1 :b 2))))
    (is (application-state-p state))
    (is (= 1 (state-ref state :a)))
    (is (= 2 (state-ref state :b)))))

(test make-state-with-hash-table-initial
  "Creating state with hash-table initial data"
  (progn
    (let* ((initial (plist->hash-table '(:x 10 :y 20)))
           (state (make-state :initial initial)))
      (is (application-state-p state))
      (is (= 10 (state-ref state :x)))
      (is (= 20 (state-ref state :y))))))

(test make-state-with-plist-backend
  "Creating state with plist backend"
  (let ((state (make-state :initial '(:a 1 :b 2) :backend :plist)))
    (is (application-state-p state))
    (is (eq (application-state-backend state) :plist))
    (is (listp (application-state-data state)))))

(test make-state-from-existing-state
  "Creating state from existing state"
  (progn
    (let* ((state1 (make-state :initial '(:a 1)))
           (state2 (make-state :initial state1)))
      (is (application-state-p state2))
      (is (= 1 (state-ref state2 :a))))))

(test make-state-from-existing-state-isolates-mutable-data
  (let* ((state1 (make-state :initial '(:nested (:value 1))))
         (state2 (make-state :initial state1)))
    (state-set state2 '(:nested :value) 9)
    (is (= 1 (state-ref state1 '(:nested :value))))
    (is (= 9 (state-ref state2 '(:nested :value))))
    (is-false (eq (state-ref state1 :nested)
                  (state-ref state2 :nested)))))

;;; state-ref tests

(test state-ref-nested-path
  "Reading nested paths"
  (let ((state (make-state :initial '(:user (:name "Alice" :age 30)))))
    (is (equal "Alice" (state-ref state '(:user :name))))
    (is (= 30 (state-ref state '(:user :age))))))

(test state-ref-with-default
  "Reading with default value"
  (let ((state (make-state :initial '(:a 1))))
    (is (= 42 (state-ref state :missing 42)))
    (is (= 99 (state-ref state '(:a :missing) 99)))))

(test state-ref-from-hash-table
  "Reading from hash-table directly"
  (let ((ht (plist->hash-table '(:a 1 :b 2))))
    (is (= 1 (state-ref ht :a)))
    (is (= 2 (state-ref ht :b)))))

;;; state-set tests

(test state-set-basic
  "Setting values in state"
  (let ((state (make-state)))
    (state-set state :foo 42)
    (is (= 42 (state-ref state :foo)))))

(test state-set-nested
  "Setting nested values"
  (let ((state (make-state)))
    (state-set state '(:user :name) "Bob")
    (state-set state '(:user :age) 25)
    (is (equal "Bob" (state-ref state '(:user :name))))
    (is (= 25 (state-ref state '(:user :age))))))

(test state-set-update-existing
  "Updating existing values"
  (let ((state (make-state :initial '(:a 1))))
    (state-set state :a 99)
    (is (= 99 (state-ref state :a)))))

(test state-set-with-setf
  "Using setf with state-ref"
  (let ((state (make-state)))
    (setf (state-ref state :x) 10)
    (is (= 10 (state-ref state :x)))))

(test state-set-increments-version
  "Setting values increments version"
  (let ((state (make-state)))
    (let ((v1 (application-state-version state)))
      (state-set state :a 1)
      (state-set state :b 2)
      (is (> (application-state-version state) v1)))))

(test state-set-logs-changes
  "Setting values logs changes"
  (let ((state (make-state)))
    (state-set state :a 1)
    (state-set state :b 2)
    (is (> (length (application-state-log state)) 0))))

;;; get-state tests

(test get-state-convenience
  "get-state is convenience wrapper for state-ref"
  (let ((state (make-state :initial '(:a 1))))
    (is (= 1 (get-state state :a)))
    (is (null (get-state state :missing nil)))))

;;; application-state-plist tests

(test application-state-plist-from-hash
  "Converting hash-table state to plist"
  (let ((state (make-state :initial '(:a 1 :b (:nested 2)))))
    (let ((plist (application-state-plist state)))
      (is (listp plist))
      (is (= 1 (getf plist :a)))
      (is (= 2 (get-path '(:b :nested) plist))))))

(test application-state-plist-from-plist
  "Getting plist from plist state returns same"
  (let ((state (make-state :initial '(:a 1 :b 2) :backend :plist)))
    (let ((plist (application-state-plist state)))
      (is (equal plist '(:a 1 :b 2))))))

;;; deep-copy-application-state tests

(test deep-copy-application-state
  "Deep copying state creates independent copy"
  (progn
    (let* ((state1 (make-state :initial '(:a 1 :b 2)))
           (state2 (deep-copy-application-state state1)))
      (is (application-state-p state2))
      (is (= 1 (state-ref state2 :a)))
      (is (= 2 (state-ref state2 :b)))
      ;; Modify state2 and check state1 is unchanged
      (state-set state2 :a 99)
      (is (= 1 (state-ref state1 :a)))
      (is (= 99 (state-ref state2 :a))))))

(test deep-copy-preserves-all-fields
  "Deep copy preserves all state fields"
  (progn
    (let* ((state1 (make-state :initial '(:a 1)))
           (state2 (deep-copy-application-state state1)))
      (is (equal (application-state-backend state1)
                 (application-state-backend state2)))
      (is (equal (application-state-version state1)
                 (application-state-version state2))))))

(test deep-copy-data-isolates-supported-nested-containers
  "Nested conses, hash tables, and vectors in a copied state do not alias source containers."
  (let* ((vector (vector (list :value 1)))
         (source (list :nested (list :value 2)
                       :vector vector))
         (copy (deep-copy-data source)))
    (setf (getf (getf copy :nested) :value) 20)
    (setf (getf (aref (getf copy :vector) 0) :value) 10)
    (is (= 2 (getf (getf source :nested) :value)))
    (is (= 1 (getf (aref (getf source :vector) 0) :value)))
    (is (= 20 (getf (getf copy :nested) :value)))
    (is (= 10 (getf (aref (getf copy :vector) 0) :value)))))

(test state-mutation-policy-rejects-supported-write-with-inspectable-condition
  (let ((state (make-state :initial '(:count 1))))
    (let ((*state-mutation-policy* :forbid))
      (handler-case
          (progn
            (state-set state :count 2)
            (fail "STATE-SET should be rejected under :FORBID."))
        (state-mutation-forbidden (condition)
          (is (eq state (state-mutation-forbidden-state condition)))
          (is (eq :count (state-mutation-forbidden-path condition)))
          (is (eq :set (state-mutation-forbidden-operation condition))))))
    (is (= 1 (state-ref state :count)))))

;;; set-application-state-backend tests

(test set-backend-hash-to-plist
  "Converting backend from hash-table to plist"
  (let ((state (make-state :initial '(:a 1 :b 2) :backend :hash-table)))
    (set-application-state-backend state :plist)
    (is (eq (application-state-backend state) :plist))
    (is (listp (application-state-data state)))
    (is (= 1 (getf (application-state-data state) :a)))))

(test set-backend-plist-to-hash
  "Converting backend from plist to hash-table"
  (let ((state (make-state :initial '(:a 1 :b 2) :backend :plist)))
    (set-application-state-backend state :hash-table)
    (is (eq (application-state-backend state) :hash-table))
    (is (hash-table-p (application-state-data state)))
    (is (= 1 (gethash :a (application-state-data state))))))

;;; get-component-by-path tests

(test get-component-by-path-existing
  "Getting existing component by path"
  (progn
    (let ((state (make-state :initial
                             '(:components (:my-comp (:component-instance (:value 42)))))))
      (let ((comp (get-component-by-path state '(:my-comp))))
        (is (not (null comp)))
        (is (= 42 (get-path '(:value) comp)))))))

(test get-component-by-path-missing
  "Getting missing component returns nil"
  (let ((state (make-state)))
    (is (null (get-component-by-path state '(:missing))))))

(test get-component-by-path-nested
  "Getting nested component"
  (let ((state (make-state :initial
                 '(:components (:foo (:bar (:component-instance :data "test")))))))
    (let ((comp (get-component-by-path state '(:foo :bar))))
      (is (not (null comp))))))

(defun run-core-tests ()
  (run! 'core-suite))

(test public-application-state-data-is-an-owned-snapshot
  (let* ((state (make-state :initial '(:nested (:value 1))))
         (borrowed (state-ref state :nested))
         (owned (state-value state :nested))
         (snapshot (application-state-data state))
         (snapshot-nested (gethash :nested snapshot)))
    (is (eq borrowed
            (gethash :nested (cl-state.core:application-state-data state))))
    (is-false (eq borrowed owned))
    (is-false (eq borrowed snapshot-nested))
    (setf (gethash :value owned) 9)
    (setf (gethash :value snapshot-nested) 8)
    (is (= 1 (state-ref state '(:nested :value))))))
