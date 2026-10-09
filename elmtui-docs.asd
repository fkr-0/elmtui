(asdf:defsystem "elmtui-docs"
  :description "Generated API and long-form documentation for ElmTUI."
  :license "MIT"
  :depends-on ("elmtui")
  :serial t
  :components ((:file "docs/api/package")
               (:file "docs/api/generator")))
