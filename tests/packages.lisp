;;;===============================================================
;;; File: tests/packages.lisp
;;; Defines a package for running all elmtui tests and ASDF integration.
;;;===============================================================

(defpackage :elmtui-all-tests
  (:use :cl :fiveam)
  (:export #:run-all-elmtui-tests))

(in-package :elmtui-all-tests)

(defun run-all-elmtui-tests ()
  "Run all elmtui test suites and print a summary.
Returns T if all tests pass, NIL otherwise."
  (let ((overall-success t)
        (suites-info '(("STEP1-EVENT-MESSAGE" . "ELMTUI-TESTS")
                       ("STEP2-LOOP-ASYNC" . "ELMTUI-LOOP-ASYNC-TESTS")
                       ("STEP3-STATE" . "ELMTUI-STATE-TESTS")
                       ("VIEW-TESTS" . "ELMTUI-VIEW-TESTS")
                       ("WIDGET-TESTS" . "ELMTUI-WIDGET-TESTS")))) ; Added widget test suite

    (format t "~&~%Starting elmtui test execution...")

    (dolist (suite-spec suites-info)
      (let* ((suite-name-str (car suite-spec))
             (package-name-str (cdr suite-spec))
             (package (find-package package-name-str))
             (suite-sym (when package (find-symbol suite-name-str package))))
        (if suite-sym
            (progn
              (format t "~&~%---> Running suite: ~S (~A::~A)~%" suite-sym package-name-str suite-name-str)
              (let ((suite-passed (fiveam:run! suite-sym)))
                (unless suite-passed
                  (setf overall-success nil))
                (format t "~&---> Suite ~S finished. Pass: ~A~%" suite-sym suite-passed)))
            (progn
              (format t "~&~%[ERROR] Could not find suite ~S in package ~S. Skipping.~%"
                      suite-name-str package-name-str)
              (setf overall-success nil))))) ; Mark as failure if a suite is not found

    (format t "~&~%--- Overall Test Summary ---~%")
    (fiveam:explain! (fiveam:results-status)) ; Provides a summary of all tests run.
    (format t "~&--- End of Test Summary ---~%~%")
    overall-success))

;;;-----------------------------------------------------------------------------
;;; ASDF test-op integration
;;; This method is called when (asdf:test-system :elmtui-tests) is invoked.
;;;-----------------------------------------------------------------------------
(defmethod asdf:perform ((op asdf:test-op) (system (eql (asdf:find-system "elmtui-tests"))))
  (handler-bind ((error (lambda (e) ; Catch any unexpected errors during the test run
                          (format *error-output* "~&~%[FATAL ERROR] Unhandled error during test-op for ~A:~%  ~A~%Backtrace:~%~A~%"
                                  (asdf:component-name system)
                                  e
                                  (with-output-to-string (s) (uiop:print-backtrace :stream s :count 10 :condition e)))
                          (uiop:quit 1 t)))) ; Force exit with error code
    (format t "~&===> Performing ASDF test-op for system: ~A~%" (asdf:component-name system))
    ;; ASDF should have already loaded the system and its dependencies,
    ;; including all test files specified in elmtui-tests.asd.

    (format t "~&===> Running tests via elmtui-all-tests:run-all-elmtui-tests...~%")
    (let ((success (uiop:symbol-call :elmtui-all-tests '#:run-all-elmtui-tests)))
      (format t "~&===> Test run completed for ~A.~%" (asdf:component-name system))
      (if success
          (progn
            (format t "~&~%[SUCCESS] All elmtui tests passed for system ~A.~%" (asdf:component-name system))
            ;; ASDF test-op should exit 0 on success by default if no uiop:quit is called.
            ;; (uiop:quit 0 t) ; Optionally, be explicit.
            )
          (progn
            (format t "~&~%[FAILURE] Some elmtui tests FAILED for system ~A. See output above for details.~%" (asdf:component-name system))
            (uiop:quit 1 t)))))) ; Crucial: Exit with 1 on failure.