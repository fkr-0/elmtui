(asdf:defsystem "elmtui-core-slim-tests"
  :version "0.3.0"
  :description "Optional module and package compatibility regressions"
  :license "MIT"
  :depends-on (#:elmtui-example-widgets #:fiveam)
  :pathname "./tests/"
  :components ((:file "core-slim-tests"))
  :perform (test-op (op c)
             (declare (ignore op c))
             (unless (uiop:symbol-call :elmtui.tests.core-slim :run-core-slim-tests)
               (error "ElmTUI core-slim tests failed"))))
