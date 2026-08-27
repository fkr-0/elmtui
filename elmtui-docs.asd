(asdf:defsystem "elmtui-docs"
  :description "Generated API and long-form documentation for ElmTUI."
  :license "GPL-3.0-only"
  :depends-on ("elmtui")
  :serial t
  :components ((:file "docs/api/package")
               (:file "docs/api/generator")))
