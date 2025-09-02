;;; cl-state.asd
(asdf:defsystem "cl-state"
  :description "State container, patches, transactions, undo/redo, observers."
  :license "MIT" :version "0.1.0"
  :depends-on (#:alexandria #:uiop )
  :components
  ((:file "src/state/packages")
   (:file "src/state/patch")
   (:file "src/state/tx")
   (:file "src/state/undo")
   (:file "src/state/observer")
   (:file "src/state/api")))
