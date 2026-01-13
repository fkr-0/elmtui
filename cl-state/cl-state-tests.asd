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
                 :components ((:file "cl-state-tests")))))
