(in-package :asdf-user)
(defsystem "elmtui-tests"
  :description "Test suite for the uncharming-tui system"
  :author "CL User <cl.user@mail.com>"
  :version "0.0.1"
  :depends-on (:elmtui
               :fiveam)
  :license "BSD"
  :serial t
  :components ((:module "tests"
                :serial t
                :components ((:file "packages")
                             (:file "elmtui-tests")
                             (:file "elmtui-loop-async-tests")
                             (:file "elmtui-state-tests")
                             (:file "elmtui-view-tests")
                             (:file "elmtui-widget-tests")))) ; Added new widget test file

  ;; The following would not return the right exit code on error, but still 0.
  ;; :perform (test-op (op _) (symbol-call :fiveam :run-all-tests))
  )
