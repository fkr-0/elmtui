(asdf:defsystem "elmtui-dev-tests"
  :version "0.2.0"
  :description "Diagnostics and benchmarks for optional ElmTUI developer tooling"
  :author "ElmTUI contributors" :license "MIT"
  :depends-on (#:elmtui-dev #:fiveam)
  :pathname "./tests/" :serial t
  :components ((:file "dev-tests") (:file "dev/benchmark-tests"))
  :perform (test-op (op c)
             (declare (ignore op c))
             (let ((diagnostics (symbol-call :elmtui.dev.tests :run-dev-tests))
                   (benchmarks (symbol-call :elmtui.dev.benchmark.tests :run-benchmark-tests)))
               (unless (and diagnostics benchmarks)
                 (error "ElmTUI developer utility tests failed")))))
