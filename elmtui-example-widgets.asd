(asdf:defsystem "elmtui-example-widgets"
  :version "0.3.0"
  :description "Optional legacy key tester and counter example components"
  :author "ElmTUI contributors"
  :license "MIT"
  :depends-on (#:elmtui)
  :pathname "./src/ui/widgets/"
  :serial t
  :components ((:file "keytester")
               (:file "keytester-map")
               (:file "counter")))
