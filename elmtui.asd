(asdf:defsystem :elmtui
  :version      "0.1.0"
  :description  "description"
  :author       " <user@archlinux>"
  :serial       t
  :license      "GNU GPL, version 3"
  :components   ((:file "file.lisp"))
  :depends-on   (#:clevelib ;; #:cl-styles
                 #:alexandria))
