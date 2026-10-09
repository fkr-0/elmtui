
;; Standalone packager executable for dumping fast-boot images
(asdf:defsystem "elmtui-packager"
  :version "0.2.0"
  :description "ElmTUI packager: dump fast-boot executable Lisp images"
  :author "ElmTUI contributors"
  :license "MIT"
  :depends-on (:elmtui)
  :components ((:module "src/tools"
                :components ((:file "packager"))))
  :build-operation "program-op"
  :build-pathname "elmtui-packager"
  :entry-point "elmtui.packager:main")
