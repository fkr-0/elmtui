;;; Optional example integration for the external cl-fzy library.
(asdf:defsystem "elmtui-examples-fzy" :version "0.2.0" :description "Optional ElmTUI fuzzy-picker example using cl-fzy" :author "ElmTUI contributors" :license "GPL-3.0-only" :depends-on (#:elmtui) :pathname "./examples/" :serial t :components ((:module "support" :components ((:file "fzy-loader"))) (:file "fzy-picker")))
