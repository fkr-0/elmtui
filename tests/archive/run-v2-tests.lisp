;;;===============================================================
;;; File: tests/v2/run-tests.lisp
;;; Runs all v2 test suites together
;;;===============================================================

(uiop:define-package :elmtui-tests-runner
  (:use :cl)
  (:import-from :elmtui-test-dsl
                #:run-elmtui-test-dsl)
  (:import-from :elmtui-test-widgets-lifecycle
                #:run-elmtui-test-widgets-lifecycle)
  (:import-from :elmtui-test-app-lifecycle
                #:run-elmtui-test-app-lifecycle)
  (:import-from :elmtui-ui-widgets-utils-tests
                #:run-elmtui-ui-widgets-utils-tests)
  (:export #:run-all-tests))

(in-package :elmtui-tests-runner)

;; (defun run-all-tests ()
;;   "Run all v2 test suites and return true if they all pass"
;;   (format t "~&~%=== Running DSL Tests ===~%")
;;   (let ((dsl-result (run-elmtui-test-dsl)))
;;     (format t "~&~%=== Running Widget Utils Tests ===~%")
;;     (let ((utils-result (run-elmtui-ui-widgets-utils-tests)))
;;       (format t "~&~%=== Running Widget Lifecycle Tests ===~%")
;;       (let ((lifecycle-result (run-elmtui-test-widgets-lifecycle)))
;;         (format t "~&~%=== Running App Lifecycle Tests ===~%")
;;         (let ((app-result (run-elmtui-test-app-lifecycle)))

;;           ;; Report overall results
;;           (format t "~&~%=== V2 Tests Summary ===~%")
;;           (format t "DSL Tests: ~A~%" (if dsl-result "PASSED" "FAILED"))
;;           (format t "Widget Utils Tests: ~A~%" (if utils-result "PASSED" "FAILED"))
;;           (format t "Widget Lifecycle Tests: ~A~%" (if lifecycle-result "PASSED" "FAILED"))
;;           (format t "App Lifecycle Tests: ~A~%" (if app-result "PASSED" "FAILED"))

;;           ;; Return true if all tests passed
;;           (and dsl-result utils-result lifecycle-result app-result))))))

;; Run tests when loaded directly
#-asdf
(run-all-tests)
