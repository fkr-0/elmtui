;;; == exampleproject/tests/contracts-tests.lisp ==
;;; FiveAM test suite for pipeline-contract enforcement (Stages 0–5)
;;; Assumes:
;;;   • elmtui/contracts/stage.lisp defines DEFINE-STAGE
;;;   • elmtui/contracts/pipeline.lisp defines DEFINE-PIPELINE
;;;   • elmtui/contracts/types.lisp defines pipeline-contract-violation

;;;; Load dependencies
;; (eval-when (:compile-toplevel :load-toplevel :execute)
;;   (unless (find-package :fiveam)
;;     (require 'fiveam))
;;   (unless (find-package :elmtui.contracts)

(asdf::require 'fiveam)
(uiop:define-package #:elmtui-contract-tests
  (:use #:cl #:fiveam)
  (:import-from #:elmtui.contracts
                #:define-stage
                #:define-pipeline
                #:pipeline-contract-violation
                #:violation-stage
                #:violation-expected)
  (:use #:cl #:fiveam #:elmtui.contracts))
(in-package #:elmtui-contract-tests)

(def-suite pipeline-contract-suite

  :in elmtui.tests:elmtui-test
  :description "Verify that define-stage enforces input/output types and restartable errors")

(in-suite pipeline-contract-suite)

;;;;;; Define some dummy stages for testing ;;;;;;

;;; Stage that correctly echoes an integer
(define-stage dummy-stage-ok
    (integer integer)
    (x)
  ;; Body simply returns the integer it was given
  x)

;;; Stage that returns the wrong type (string instead of integer)
(define-stage dummy-stage-wrong-output
    (integer integer)
    (x)
  ;; Intentionally wrong return type
  (format nil "oops ~a" x))

;;; Stage that expects a string but we will pass an integer
(define-stage dummy-stage-wrong-input
    (string string)
    (s)
  s)

;;;;;; Tests ;;;;;;

(test dummy-stage-ok-accepts-integer
  (is (typep (dummy-stage-ok 123) 'integer)
      "dummy-stage-ok should accept and return an integer"))

(test dummy-stage-ok-rejects-wrong-input
  (handler-case
      (dummy-stage-ok "not-an-int")
    (type-error (e)
      (is (eq t t) "Passing a string to dummy-stage-ok should trigger a TYPE-ERROR"))
    (error (e)
      (fail "Expected a TYPE-ERROR, got ~S" e))))

(test dummy-stage-wrong-output-signals-contract-violation
  (handler-case
      (dummy-stage-wrong-output 42)
    (pipeline-contract-violation (e)
      (is (eq (violation-stage e) 'dummy-stage-wrong-output)
          "Violation should report the correct stage")
      (is (eq (violation-expected e) 'integer)
          "Violation should expect an integer output"))
    (error (e)
      (fail "Expected pipeline-contract-violation, got ~S" e))))

;;;;;; Composite pipeline test ;;;;;;

;;; Compose two stages that agree on types
(define-pipeline dummy-pipeline-ok
  dummy-stage-ok
  dummy-stage-ok)

(test pipeline-ok
  (is (= (dummy-pipeline-ok 7) 7)
      "Pipeline of two dummy-stage-ok should succeed"))

;;; Compose stages with a type mismatch at linkage
;; Note: DEFINE-PIPELINE will SIGNAL at compile-time if linkage mismatches;
;; so we simulate it by macroexpanding and checking that an error is signaled.

(test pipeline-linkage-mismatch
  (handler-case
      ;; Attempt to compose a pipeline with incompatible stages
      (eval '(define-pipeline dummy-pipeline-bad
              dummy-stage-ok
              dummy-stage-wrong-output))
    (error (e)
      (is (search "mismatch" (princ-to-string e))
          "DEFINE-PIPELINE should signal a linkage mismatch at compile-time"))))

;;; Run the suite
;; (run! 'pipeline-contract-suite)
