;;; cl-styles.asd — standalone styling engine
(in-package :asdf)
(asdf:defsystem "cl-styles"
  :description "CSS-like styling engine for arbitrary object trees (TEA friendly)."
  :author "elmtui"
  :license "MIT"
  :version "0.1.0"
  :depends-on (#:alexandria #:uiop)
  :serial t
  :components
  ((:file "src/packages")
    (:file "src/protocols")
    (:file "src/tokens")
    (:file "src/selector")
    (:file "src/rule")
    (:file "src/sheet")
    (:file "src/engine")
    (:file "src/properties")
    (:file "src/api"))
  ;; :in-order-to ((test-op (test-op "cl-styles/tests")))
  )

(asdf:defsystem "cl-styles/tests"
  :depends-on (#:cl-styles #:fiveam)
  :serial t
  :components ((:file "tests/styles-tests")
                (:file "tests/smoke")
                (:file "tests/properties")
                (:file "tests/sheets")
                (:file "tests/selector")
                (:file "tests/engine")
                (:file "tests/integration")
                (:file "tests/edge-cases"))
  :perform (test-op (o c)
             (uiop:symbol-call '#:fiveam '#:run!
               (find-symbol (string :suite) :cl-styles/tests))))
