;;;===============================================================
;;; File: cl-state/tests/cl-state-tests.lisp
;;; Main test suite loader for cl-state
;;;===============================================================
(uiop:define-package :cl-state-tests
  (:use :cl :fiveam)
  (:import-from :cl-state.api
                #:make-state
                #:state-ref
                #:state-set
                #:get-state
                #:get-path
                #:set-path
                #:remove-path
                #:plist->hash-table
                #:hash-table->plist
                #:coerce-data
                #:merge-patch
                #:merge-patches
                #:apply-patch
                #:apply-patches
                #:normalize-patches
                #:diff-states
                #:make-patch
                #:patch-path
                #:patch-op
                #:patch-value
                #:with-transaction
                #:undo
                #:redo
                #:make-tx
                #:tx-p
                #:tx-id
                #:tx-name
                #:tx-changes
                #:add-observer
                #:remove-observer
                #:notify-observers
                #:application-state
                #:application-state-p
                #:application-state-data
                #:application-state-backend
                #:application-state-history
                #:application-state-undone
                #:application-state-version
                #:application-state-observers
                #:set-application-state-backend
                #:deep-copy-application-state
                #:application-state-plist
                #:get-component-by-path
                #:make-history
                #:history-past
                #:history-future
                #:push-snapshot
                #:validate-type
                #:list-registered-types
                #:register-enum-type
                #:validate-model-schema
                #:validate-nested
                #:validate-field
                #:make-validator
                #:type-predicate)
  (:export #:run-cl-state-tests
           #:run-all-cl-state-tests))

(in-package :cl-state-tests)

(def-suite cl-state-suite
  :description "Master test suite for cl-state")

(in-suite cl-state-suite)

;; Legacy tests that were in the original file
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
    ;; Perform merges - functional API returns modified state
    ;; We wrap setf in progn to suppress return values
    (progn (setf data (merge-patch data (list '(:user :name) "Alice"))) nil)
    (progn (setf data (merge-patches data (list (list '(:user :age) 30) (list '(:settings :theme) :dark)))) nil)
    ;; Check results
    (is (equal (get-path '(:user :name) data) "Alice"))
    (is (equal (get-path '(:user :age) data) 30))
    (is (equal (get-path '(:settings :theme) data) :dark))
    ;; Delete and check
    (progn (setf data (merge-patch data (list '(:user :age) :elmtui-delete-path))) nil)
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

(defun run-all-cl-state-tests ()
  "Run all cl-state test suites and display unified summary."
  (format t "~&╔════════════════════════════════════════════════════════════╗~%")
  (format t "║          CL-STATE TEST SUITE - RUNNING ALL TESTS            ║~%")
  (format t "╚════════════════════════════════════════════════════════════╝~%~%")

  ;; Run all test suites
  (format t "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━~%")
  (format t "Running Utils Tests...~%")
  (cl-state-tests.utils:run-utils-tests)

  (format t "~%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━~%")
  (format t "Running Core Tests...~%")
  (cl-state-tests.core:run-core-tests)

  (format t "~%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━~%")
  (format t "Running Patch Tests...~%")
  (cl-state-tests.patch:run-patch-tests)

  (format t "~%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━~%")
  (format t "Running Transaction Tests...~%")
  (cl-state-tests.tx:run-tx-tests)

  (format t "~%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━~%")
  (format t "Running Observer Tests...~%")
  (cl-state-tests.observer:run-observer-tests)

  (format t "~%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━~%")
  (format t "Running Undo (History) Tests...~%")
  (cl-state-tests.undo:run-undo-tests)

  (format t "~%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━~%")
  (format t "Running Schema Tests...~%")
  (cl-state-tests.schema:run-schema-tests)

  (format t "~%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━~%")
  (format t "Running Validation Tests...~%")
  (cl-state-tests.validation:run-validation-tests)

  (format t "~%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━~%")
  (format t "Running Legacy Tests...~%")
  (run! 'cl-state-suite)

  (format t "~%~%╔════════════════════════════════════════════════════════════╗~%")
  (format t "║                   ALL TESTS COMPLETED                        ║~%")
  (format t "╚════════════════════════════════════════════════════════════╝~%")
  :done)

;; Alias for compatibility
(setf (symbol-function 'run-cl-state-tests) #'run-all-cl-state-tests)
