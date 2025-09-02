
;; Standalone packager executable for dumping fast-boot images
(asdf:defsystem "elmtui-packager"
  :version      "0.1.0"
  :description  "ElmTUI packager: dump fast-boot executable Lisp images"
  :author       "User <user@archlinux>"
  :license      "GNU GPL, version 3"
  :depends-on   (:elmtui)
  :pathname "./src/tools/"
  :components ((:file "packager"))
  :build-operation "program-op"
  :build-pathname "elmtui-packager"
  :entry-point "elmtui.packager:main")

