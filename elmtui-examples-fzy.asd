;;; Optional example integration for the external cl-fzy library.
(asdf:defsystem "elmtui-examples-fzy" :version "0.2.0" :description "Optional ElmTUI fuzzy-picker example using cl-fzy" :author "ElmTUI contributors" :license "MIT" :depends-on (#:elmtui) :pathname "./examples/" :serial t :components ((:module "support" :components ((:file "fzy-loader"))) (:file "fzy-picker")))
