(in-package :asdf)
(defsystem "elmtui-workbench"
  :description "Optional local ElmTUI interactive Lisp workbench (no required Slynk)"
  :version "0.1.0"
  :license "MIT"
  :depends-on ("elmtui")
  :pathname "src/workbench/"
  :serial t
  :components
  ((:file "editor")
   (:file "eval")
   (:file "completion")
   (:file "docs")
   (:file "inspector")
   (:file "slynk-adapter")
   (:file "view")
   (:file "app")))
