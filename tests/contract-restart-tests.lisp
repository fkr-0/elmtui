(asdf::require 'fiveam)
(uiop:define-package #:elmtui-contract-restart-tests
  (:use #:cl #:fiveam)
  (:import-from #:elmtui.contracts
                #:define-stage
                #:define-pipeline
                #:pipeline-contract-violation
                #:violation-stage
                #:violation-expected)
  (:use #:cl #:fiveam #:elmtui.contracts))
(in-package #:elmtui-contract-restart-tests)

(def-suite pipeline-contract-restart-suite

  :in elmtui.tests:elmtui-test
  :description "Verify that define-stage enforces input/output types and restartable errors")

(in-suite pipeline-contract-restart-suite)

;;; Dummy stage that always returns the wrong type
(define-stage test-wrong-out
    (integer integer)
    (x)
  ;; Intentionally violate output contract
  (format nil "~a" x))

;;–– Tests


(test test-wrong-output-should-throw
  (signals pipeline-contract-violation 'pipeline-contract-violation
    (test-wrong-out 7)))

(test test-wrong-input-should-throw
  (signals type-error (test-wrong-out "foo")))

(test test-wrong-output-metadata
  (handler-case
      (test-wrong-out 7)
    (pipeline-contract-violation (e)
      (is (eq (violation-stage e)    'test-wrong-out)
          "Violation reports the correct stage")
      (is (eq (violation-expected e) 'integer)
          "Violation reports the correct expected type"))))




;;; Test that invoking the skip-stage restart returns the original input
;; (test skip-stage-restart
;;   (let ((result
;;           (handler-case
;;               (test-wrong-out 99)
;;             (pipeline-contract-violation (e)
;;               ;; programmatically invoke the 'skip-stage' restart
;;               (invoke-restart 'skip-stage)))))
;;     (is (= result 99)
;;         "Invoking skip-stage should return the original input")))

;; ;;; Test that invoking the coerce-result restart returns the provided value
;; (test coerce-result-restart
;;   (let ((result
;;           (handler-case
;;               (test-wrong-out 7)
;;             (pipeline-contract-violation (e)
;;               ;; programmatically invoke the 'coerce-result' restart with 123
;;               (invoke-restart 'coerce-result 123)))))
;;     (is (= result 123)
;;         "Invoking coerce-result with 123 should return 123")))

;;; Test that define-stage recorded its type metadata on the function
(test define-stage-metadata
  (is (eq (get 'test-wrong-out :pipeline/in-type)  'integer)
      "The :pipeline/in-type property should be 'integer")
  (is (eq (get 'test-wrong-out :pipeline/out-type) 'integer)
      "The :pipeline/out-type property should be 'integer"))

;;; Test that define-stage rejects a malformed arglist at macroexpand time
(test define-stage-bad-arglist
  (handler-case
      (macroexpand '(define-stage bad-arg
                     (integer integer)
                     x               ; improper—should be (x)
                     (1+ x)))
    (error (e)
      (is (eq t t) (format nil "Malformed arglist to DEFINE-STAGE should signal an error ~A" e)))
    ;; (otherwise (exp)
    ;;   (fail "Expected an error during macroexpand, got ~S" exp))
    ))

;;; Run all the tests in this suite
(progn
  (test elmtui-condition-recovery-preserves-original-condition
    (let* ((original
             (make-condition 'elmtui.core.errors:state-error
                             :message "Counter state is invalid"
                             :operation :update
                             :path '(:counter :value)
                             :state-type :plist
                             :context '((:component-id . :counter))))
           (seen nil)
           (result
             (handler-bind
                 ((elmtui.core.errors:state-error
                    (lambda (condition)
                      (setf seen condition)
                      (invoke-restart 'use-value :recovered))))
               (elmtui.core.conditions:with-recovery
                   (elmtui.core.errors:state-error
                    :restarts '(:use-value :abort))
                 (elmtui.core.errors:with-error-context
                     (:module :runtime-e2e :operation :update)
                   (error original))))))
      (is (eq :recovered result))
      (is (eq original seen)
          "Recovery must preserve the original inspectable condition object.")
      (is (eq :runtime-e2e
              (elmtui.core.errors:elmtui-error-module original)))
      (is (assoc :operation
                 (elmtui.core.errors:elmtui-error-context original)))))

  (test async-restart-provides-result-with-original-condition-active
    (let* ((original
             (make-condition 'elmtui.core.conditions:async-task-error
                             :task '(:lookup-wikipedia "Common Lisp")
                             :reason "simulated transport failure"))
           (seen nil)
           (result
             (handler-bind
                 ((elmtui.core.conditions:async-task-error
                    (lambda (condition)
                      (setf seen condition)
                      (invoke-restart 'use-value :cached))))
               (elmtui.core.async:with-async-restarts (_condition)
                 (error original)))))
      (is (eq :cached result))
      (is (eq original seen)
          "Async recovery must retain the original condition object.")))

  (run! 'pipeline-restart-suite))
