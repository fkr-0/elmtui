;;;; Separate focused suite: does not interfere with the main ElmTUI test graph.
(asdf:defsystem "elmtui-neon-tests"
  :description "NILMSP-inspired arcade and document application regression tests"
  :depends-on (:elmtui-examples :fiveam)
  :pathname "tests/"
  :components ((:file "neon-apps-tests")
               (:file "neon-life-glider-contracts"))
  :perform (test-op (op system)
             (declare (ignore op system))
             (unless (uiop:symbol-call :fiveam :run! (find-symbol "NEON-APPS-TESTS" "ELMTUI.TESTS.NEON-APPS")) (error "Neon app regressions failed"))
             (unless (uiop:symbol-call :fiveam :run! (find-symbol "NEON-LIFE-GLIDER-TESTS" "ELMTUI.TESTS.NEON-LIFE-GLIDER")) (error "Neon Life/Glider regressions failed"))))
