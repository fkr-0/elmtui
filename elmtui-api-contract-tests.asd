(asdf:defsystem "elmtui-api-contract-tests"
  :version "0.4.0"
  :description "Public ElmTUI utility contract regressions"
  :license "MIT"
  :depends-on (#:elmtui #:fiveam)
  :pathname "./tests/"
  :components ((:file "api-contract-tests"))
  :perform (test-op (op c)
             (declare (ignore op c))
             (unless (uiop:symbol-call :elmtui.tests.api-contract :run-api-contract-tests)
               (error "ElmTUI API-contract tests failed"))))
