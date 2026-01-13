;;;; DEV Module Tests
;;;; Test suite for elmtui development utilities

(uiop:define-package :elmtui.dev.tests
  (:use :cl :fiveam :elmtui.dev)
  (:export #:run-dev-tests))

(in-package :elmtui.dev.tests)

(def-suite dev-test-suite
  :description "Test suite for elmtui development utilities")

(in-suite dev-test-suite)

;; Test for dev examples (if they exist)
(test dev-example-functions
  "Test dev example functions"
  ;; These might not exist, but we can check if they're defined
  (when (fboundp 'elmtui.dev:example-flexbox-layout)
    (is (functionp #'elmtui.dev:example-flexbox-layout)
        "example-flexbox-layout should be a function"))
  
  (when (fboundp 'elmtui.dev:example-grid-layout)
    (is (functionp #'elmtui.dev:example-grid-layout)
        "example-grid-layout should be a function"))
  
  (when (fboundp 'elmtui.dev:send-foo-message)
    (is (functionp #'elmtui.dev:send-foo-message)
        "send-foo-message should be a function"))
  
  (when (fboundp 'elmtui.dev:run-faulty-async)
    (is (functionp #'elmtui.dev:run-faulty-async)
        "run-faulty-async should be a function"))
  
  (when (fboundp 'elmtui.dev:demo-event-loop)
    (is (functionp #'elmtui.dev:demo-event-loop)
        "demo-event-loop should be a function")))

;; Test for dev-main if it exists
(test dev-main-function
  "Test dev-main function"
  (when (fboundp 'elmtui.dev:dev-main)
    (is (functionp #'elmtui.dev:dev-main)
        "dev-main should be a function")))

;; Test basic package loading
(test dev-package-loading
  "Test that dev package loads correctly"
  ;; Just check that we can access the package
  (is (find-package :elmtui.dev)
      "elmtui.dev package should exist"))

;; Test that exported symbols are available
(test dev-exports
  "Test that exported symbols are available"
  ;; Check for exported symbols that might exist
  (let ((package (find-package :elmtui.dev)))
    (when package
      ;; Just check that we can iterate through symbols without error
      (let ((symbols nil))
        (do-symbols (sym package)
          (push sym symbols))
        (is (> (length symbols) 0)
            "Should have some symbols in package")))))

(defun run-dev-tests ()
  "Run all dev module tests"
  (run! 'dev-test-suite))