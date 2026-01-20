;;; cl-state.asd
(asdf:defsystem "cl-state"
  :description "State container, patches, transactions, undo/redo, observers."
  :license "MIT"
  :version "0.1.0"
  :author "Your Name <your.email@example.com>"
  :maintainer "Your Name <your.email@example.com>"
  :depends-on (#:alexandria #:uiop #:bordeaux-threads)
  :components
  ((:file "src/state/packages")
   (:file "src/state/utils")
   (:file "src/state/core")
   (:file "src/state/patch")
   (:file "src/state/tx")
   (:file "src/state/undo")
   (:file "src/state/observer")
   (:file "src/state/api"))
  :in-order-to ((test-op (test-op "cl-state-tests"))))
