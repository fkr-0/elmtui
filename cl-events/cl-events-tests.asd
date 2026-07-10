;;; cl-events-tests.asd
(asdf:defsystem "cl-events-tests"
  :description "FiveAM tests for cl-events"
  :author "ElmTUI contributors"
  :license "MIT"
  :depends-on (#:cl-events #:fiveam)
  :components
  ((:file "tests/packages")
   (:file "tests/protocols-tests")
   (:file "tests/types-tests")
   (:file "tests/channel-tests")
   (:file "tests/bus-tests")
   (:file "tests/dispatcher-tests")
   (:file "tests/async-tests")
   (:file "tests/messaging-tests")
   (:file "tests/loop-tests")
   (:file "tests/api-tests"))
  :perform (test-op (o c)
             (uiop:symbol-call :fiveam :run! :cl-events/tests)))
