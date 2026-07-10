;;;===============================================================
;;; File: tests/state-tests.lisp
;;; Unit tests for elmtui.state.api
;;;===============================================================

(uiop:define-package :elmtui-tests.state
  (:use :cl :fiveam )
  (:import-from :cl-state.core
    #:get-state
    #:application-state
    #:make-state
    #:state-ref)
  (:import-from :elmtui.state
    #:with-transaction) 
  (:import-from :cl-state.patch
    #:apply-patches)
  (:import-from :cl-state.tx
    #:undo
    #:redo)
  (:import-from :elmtui.state
    #:add-observer
    #:remove-observer)
  (:export :run-state-tests))

(in-package :elmtui-tests.state)

;; Define a test suite
(def-suite elmtui-state-suite
  :description "Tests for the new elmtui.state API.")

(in-suite elmtui-state-suite)

;; Test case for APPLICATION-STATE struct creation
(test state-application-state-creation
  (let ((state (make-state)))
    (is (typep state 'application-state))
    (is (hash-table-p (elmtui.state.api:application-state-data state)))
    (is (null (elmtui.state.api:application-state-history state)))
    (is (null (elmtui.state.api:application-state-undone state)))))

(test state-initial-state-creation
  (let ((state (make-state :initial (alexandria:plist-hash-table '(:a 1 :b 2)))))
    (is (= (get-state state :a) 1))
    (is (= (get-state state :b) 2))))

(test state-with-transaction-basic
  (let ((state (make-state)))
    (with-transaction (state :name :add-user)
      (elmtui.state:state-set state :name "Alice")
      (elmtui.state:state-set state :age 30))
    (is (equal (get-state state :name) "Alice"))
    (is (= (get-state state :age) 30))
    (is (= (length (elmtui.state.api:application-state-history state)) 1))
    (let ((tx (first (elmtui.state.api:application-state-history state))))
      (is (eq (elmtui.state.api:tx-name tx) :add-user))
      (is (= (length (elmtui.state.api:tx-changes tx)) 2)))))

(test state-with-transaction-rollback-on-error
  (let ((state (make-state)))
    (handler-case
      (with-transaction (state :name :fail)
        (elmtui.state:state-set state :a 1)
        (error "Something went wrong"))
      (error ()))
    (is (null (get-state state :a)))
    (is (null (elmtui.state.api:application-state-history state)))))

(test state-apply-patches-basic
  (let ((state (make-state)))
    (apply-patches state '((:name "Bob") (:city "New York")))
    (is (equal (get-state state :name) "Bob"))
    (is (equal (get-state state :city) "New York"))
    (is (= (length (elmtui.state.api:application-state-history state)) 1))))

(test state-undo-redo-basic
  (let ((state (make-state)))
    (with-transaction (state :name :tx1)
      (elmtui.state:state-set state :a 1))
    (with-transaction (state :name :tx2)
      (elmtui.state:state-set state :b 2))

    (is (= (get-state state :a) 1))
    (is (= (get-state state :b) 2))

    ;; Undo tx2
    (undo state)
    (is (= (get-state state :a) 1))
    (is (null (get-state state :b)))
    (is (= (length (elmtui.state.api:application-state-history state)) 1))
    (is (= (length (elmtui.state.api:application-state-undone state)) 1))

    ;; Undo tx1
    (undo state)
    (is (null (get-state state :a)))
    (is (= (length (elmtui.state.api:application-state-history state)) 0))
    (is (= (length (elmtui.state.api:application-state-undone state)) 2))

    ;; Redo tx1
    (redo state)
    (is (= (get-state state :a) 1))
    (is (= (length (elmtui.state.api:application-state-history state)) 1))
    (is (= (length (elmtui.state.api:application-state-undone state)) 1))

    ;; Redo tx2
    (redo state)
    (test state-observer-notification
      (let ((state (make-state))
             (observed-old-val nil)
             (observed-new-val nil))
        (add-observer state :a (lambda (old new)
                                 (setf observed-old-val old)
                                 (setf observed-new-val new)))
        (with-transaction (state :name :test-observers)
          (elmtui.state:state-set state :a 10))
        (is (eq observed-old-val :not-present))
        (is (= observed-new-val 10))

        (with-transaction (state :name :test-observers-2)
          (elmtui.state:state-set state :a 20))
        (is (= observed-old-val 10))
        (is (= observed-new-val 20))))

    (test state-remove-observer
      (let ((state (make-state))
             (counter 0))
        (let ((observer-fn (lambda (old new)
                             (declare (ignore old new))
                             (incf counter))))
          (add-observer state :a observer-fn)
          (with-transaction (state) (elmtui.state:state-set state :a 1))
          (is (= counter 1))
          (remove-observer state :a observer-fn)
          (with-transaction (state) (elmtui.state:state-set state :a 2))
          (is (= counter 1)))))
    (is (= (get-state state :b) 2))
    (is (= (length (elmtui.state.api:application-state-history state)) 2))
    (is (= (length (elmtui.state.api:application-state-undone state)) 0))))
(test state-get-state-basic
  (let ((state (make-state)))
    (elmtui.state:state-set state :name "Alice")
    (is (equal (get-state state :name) "Alice"))
    (is (null (get-state state :age)))
    (is (equal (get-state state :age 25) 25))))

;; Function to run all tests in this suite
(defun run-state-tests ()
  (run! 'elmtui-state-suite))
