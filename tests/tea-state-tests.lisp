;;;===============================================================
;;; File: tests/tea-state-tests.lisp
;;; Unit tests for elmtui.tea-state.api
;;;===============================================================

(uiop:define-package :elmtui-tests.tea-state
  (:use :cl :fiveam :elmtui.tea-state.api)
  (:import-from :elmtui.tea-state.state
                #:get-state
                #:application-state
                #:state-ref)
  (:import-from :elmtui.tea-state.transactions
                #:with-transaction
                #:apply-patches
                #:undo
                #:redo)
  (:import-from :elmtui.tea-state.observers
                #:add-observer
                #:remove-observer)
  (:export :run-tea-state-tests))

(in-package :elmtui-tests.tea-state)

;; Define a test suite
(def-suite elmtui-tea-state-suite
  :description "Tests for the new elmtui.tea-state API.")

(in-suite elmtui-tea-state-suite)

;; Test case for APPLICATION-STATE struct creation
(test tea-state-application-state-creation
  (let ((state (make-state nil)))
    (is (typep state 'application-state))
    (is (hash-table-p (elmtui.tea-state.state::application-state-data state)))
    (is (null (elmtui.tea-state.state::application-state-history state)))
    (is (null (elmtui.tea-state.state::application-state-undone state)))))

(test tea-state-initial-state-creation
  (let ((state (make-state (alexandria:plist-hash-table '(:a 1 :b 2)))))
    (is (= (get-state state :a) 1))
    (is (= (get-state state :b) 2))))

(test tea-state-with-transaction-basic
  (let ((state (make-state nil)))
    (with-transaction (state :name :add-user)
      (elmtui.tea-state.transactions:state-set state :name "Alice")
      (elmtui.tea-state.transactions:state-set state :age 30))
    (is (equal (get-state state :name) "Alice"))
    (is (= (get-state state :age) 30))
    (is (= (length (elmtui.tea-state.state::application-state-history state)) 1))
    (let ((tx (first (elmtui.tea-state.state::application-state-history state))))
      (is (eq (elmtui.tea-state.state::tx-name tx) :add-user))
      (is (= (length (elmtui.tea-state.state::tx-changes tx)) 2)))))

(test tea-state-with-transaction-rollback-on-error
  (let ((state (make-state nil)))
    (handler-case
        (with-transaction (state :name :fail)
          (elmtui.tea-state.transactions:state-set state :a 1)
          (error "Something went wrong"))
      (error ()))
    (is (null (get-state state :a)))
    (is (null (elmtui.tea-state.state::application-state-history state)))))

(test tea-state-apply-patches-basic
  (let ((state (make-state nil)))
    (apply-patches state '((:name "Bob") (:city "New York")))
    (is (equal (get-state state :name) "Bob"))
    (is (equal (get-state state :city) "New York"))
    (is (= (length (elmtui.tea-state.state::application-state-history state)) 1))))

(test tea-state-undo-redo-basic
  (let ((state (make-state nil)))
    (with-transaction (state :name :tx1)
      (elmtui.tea-state.transactions:state-set state :a 1))
    (with-transaction (state :name :tx2)
      (elmtui.tea-state.transactions:state-set state :b 2))

    (is (= (get-state state :a) 1))
    (is (= (get-state state :b) 2))

    ;; Undo tx2
    (undo state)
    (is (= (get-state state :a) 1))
    (is (null (get-state state :b)))
    (is (= (length (elmtui.tea-state.state::application-state-history state)) 1))
    (is (= (length (elmtui.tea-state.state::application-state-undone state)) 1))

    ;; Undo tx1
    (undo state)
    (is (null (get-state state :a)))
    (is (= (length (elmtui.tea-state.state::application-state-history state)) 0))
    (is (= (length (elmtui.tea-state.state::application-state-undone state)) 2))

    ;; Redo tx1
    (redo state)
    (is (= (get-state state :a) 1))
    (is (= (length (elmtui.tea-state.state::application-state-history state)) 1))
    (is (= (length (elmtui.tea-state.state::application-state-undone state)) 1))

    ;; Redo tx2
    (redo state)
    (test tea-state-observer-notification
      (let ((state (make-state nil))
            (observed-old-val nil)
            (observed-new-val nil))
        (add-observer state :a (lambda (old new)
                                 (setf observed-old-val old)
                                 (setf observed-new-val new)))
        (with-transaction (state :name :test-observers)
          (elmtui.tea-state.transactions:state-set state :a 10))
        (is (eq observed-old-val :not-present))
        (is (= observed-new-val 10))

        (with-transaction (state :name :test-observers-2)
          (elmtui.tea-state.transactions:state-set state :a 20))
        (is (= observed-old-val 10))
        (is (= observed-new-val 20))))

    (test tea-state-remove-observer
      (let ((state (make-state nil))
            (counter 0))
        (let ((observer-fn (lambda (old new)
                             (declare (ignore old new))
                             (incf counter))))
          (add-observer state :a observer-fn)
          (with-transaction (state) (elmtui.tea-state.transactions:state-set state :a 1))
          (is (= counter 1))
          (remove-observer state :a observer-fn)
          (with-transaction (state) (elmtui.tea-state.transactions:state-set state :a 2))
          (is (= counter 1)))))
    (is (= (get-state state :b) 2))
    (is (= (length (elmtui.tea-state.state::application-state-history state)) 2))
    (is (= (length (elmtui.tea-state.state::application-state-undone state)) 0))))
(test tea-state-get-state-basic
  (let ((state (make-state nil)))
    (elmtui.tea-state.transactions:state-set state :name "Alice")
    (is (equal (get-state state :name) "Alice"))
    (is (null (get-state state :age)))
    (is (equal (get-state state :age 25) 25))))

;; Function to run all tests in this suite
(defun run-tea-state-tests ()
  (run! 'elmtui-tea-state-suite))
