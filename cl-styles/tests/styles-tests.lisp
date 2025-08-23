;;;; ELMTUI Test Suite
;;;; This file sets up the main test package and defines basic test infrastructure

(uiop:define-package :cl-styles.tests
  (:use :cl :fiveam)
  (:export #:run-tests #:cl-styles-test #:run-all-cl-styles-tests))

(in-package :cl-styles.tests)

;; Define the main test suite
(def-suite cl-styles-test
  :description "Main test suite for cl-styles TUI framework")

;; Set this as the default test suite
(in-suite cl-styles-test)

;; Basic smoke test to ensure the package loads
(test package-loads
      "Test that the cl-styles package loads without errors"
      (is (not (null (find-package :cl-styles.api)))))

;; Convenience function to run all tests
(defun run-tests ()
  "Run all cl-styles tests"
  (run! 'cl-styles-test))

;; Also provide this function for ASDF integration
(defun run-all-cl-styles-tests ()
  "Run all cl-styles tests (alias for run-tests)"
  (fiveam:run-all-tests))
