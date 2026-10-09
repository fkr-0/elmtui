;;;; Separate focused suite: does not interfere with the main ElmTUI test graph.
(in-package :asdf-user)
(asdf:defsystem "elmtui-neon-tests"
  :description "NILMSP-inspired arcade and document application regression tests"
  :depends-on (:elmtui-examples :fiveam)
  :pathname "tests/"
  :components ((:file "neon-apps-tests"))
  :perform (test-op (op system)
             (declare (ignore op system))
             (unless (uiop:symbol-call
                      :fiveam :run!
                      (find-symbol "NEON-APPS-TESTS"
                                   "ELMTUI.TESTS.NEON-APPS"))
               (error "Neon app regressions failed"))))
