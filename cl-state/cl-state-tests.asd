;;; cl-state-tests.asd
(in-package :asdf-user)

(asdf:defsystem "cl-state-tests"
  :description "Test suite for the cl-state system"
  :author "User <user@archlinux>"
  :version "0.0.1"
  :depends-on (#:cl-state #:fiveam)
  :license "MIT"
  :serial t
  :components ((:module "tests"
                 :serial t
                 :components
                 ((:file "utils-tests")
                  (:file "core-tests" :depends-on ("utils-tests"))
                  (:file "patch-tests" :depends-on ("utils-tests"))
                  (:file "tx-tests" :depends-on ("core-tests"))
                  (:file "observer-tests" :depends-on ("core-tests" "tx-tests"))
                  (:file "undo-tests")
                  (:file "schema-tests")
                  (:file "validation-tests")
                  (:file "cl-state-tests" :depends-on ("utils-tests" "core-tests"
                                                       "patch-tests" "tx-tests"
                                                       "observer-tests" "undo-tests"
                                                       "schema-tests" "validation-tests")))))
  :perform (test-op (o c)
             (declare (ignore o c))
             (uiop:symbol-call :cl-state-tests :run-all-cl-state-tests)))
