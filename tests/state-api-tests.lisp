;;; ===============================================================
;;; File: tests/state-api-tests.lisp
;;; Unit Tests for elmtui.state.api
;;; ===============================================================
(uiop:define-package :elmtui.tests.state-api
  (:use :cl :fiveam)
  (:import-from :elmtui.state.api
                #:update-result #:make-update-result
                #:ur-patches #:ur-commands #:ur-handled
                #:ur-has-command-p #:ur-add-command
                #:plist-to-application-state
                #:pprinc-application-state
                #:invoke-update
                #:malformed-update-result-error
                #:malformed-update-result-fn-name
                #:malformed-update-result-reason
                #:malformed-update-result-values)
  (:import-from :cl-state.core
                #:get-state
                #:make-state
                #:application-state)
  (:export #:state-api-tests))

(in-package :elmtui.tests.state-api)

(def-suite state-api-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for state API")

(in-suite state-api-tests)

;;;=============================================================================
;;; Update Result Tests
;;;=============================================================================

(test make-update-result-default
  "Test creating update result with defaults"
  (let ((result (make-update-result)))
    (is-true (typep result 'update-result))
    (is-false (ur-patches result))
    (is-false (ur-commands result))
    (is-false (ur-handled result))))

(test make-update-result-with-values
  "Test creating update result with explicit values"
  (let ((result (make-update-result
                 :patches '((:a 1))
                 :commands '(:cmd1)
                 :handled t)))
    (is-true (typep result 'update-result))
    (is (equal '((:a 1)) (ur-patches result)))
    (is (equal '(:cmd1) (ur-commands result)))
    (is-true (ur-handled result))))

(test ur-has-command-p
  "Test ur-has-command-p"
  (let ((result (make-update-result :commands '(:cmd1 :cmd2))))
    (is-true (ur-has-command-p result :cmd1))
    (is-false (ur-has-command-p result :cmd3))))

(test ur-add-command
  "Test ur-add-command"
  (let ((result (make-update-result :commands '(:cmd1))))
    (ur-add-command result :cmd2)
    (is (equal '(:cmd2 :cmd1) (ur-commands result)))))

;;;=============================================================================
;;; Plist to Application State Tests
;;;=============================================================================

(test plist-to-application-state
  "Test converting plist to application state"
  (let ((state (plist-to-application-state '(:a 1 :b 2))))
    (is-true (typep state 'application-state))
    (is (= 1 (get-state state :a)))
    (is (= 2 (get-state state :b)))))

(test plist-to-application-state-empty
  "Test converting empty plist"
  (let ((state (plist-to-application-state '())))
    (is-true (typep state 'application-state))))

;;;=============================================================================
;;; Pprinc Application State Tests
;;;=============================================================================

(test pprinc-application-state
  "Test pretty printing application state"
  (let ((state (plist-to-application-state '(:a 1 :b 2))))
    (let ((output (pprinc-application-state state)))
      (is-true (stringp output))
      (is-true (search "Application State" output)))))

(test invoke-update-malformed-return-signals-typed-condition
  "INVOKE-UPDATE preserves malformed return evidence in the framework condition type."
  (let* ((state (make-state :initial '(:count 0)))
         (update-fn (lambda (msg ctx)
                      (declare (ignore msg ctx))
                      42)))
    (handler-case
        (progn
          (invoke-update update-fn :tick state)
          (fail "Expected MALFORMED-UPDATE-RESULT-ERROR."))
      (malformed-update-result-error (condition)
        (is (eq update-fn (malformed-update-result-fn-name condition)))
        (is (stringp (malformed-update-result-reason condition)))
        (is (equal '(42) (malformed-update-result-values condition)))))))

(test invoke-update-validates-two-value-shape
  "Two-value updates use the same patches/commands validation as DEFUPDATE results."
  (let ((state (make-state :initial '(:count 0))))
    (signals malformed-update-result-error
      (invoke-update (lambda (msg ctx)
                       (declare (ignore msg ctx))
                       (values 42 nil))
                     :tick state))))
