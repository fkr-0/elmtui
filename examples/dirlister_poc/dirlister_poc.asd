(in-package :asdf-user)

(asdf:defsystem "dirlister_poc"
  :description "A directory lister TUI application using the elmtui library."
  :author "Your Name"
  :license "MIT"
  :depends-on (#:elmtui #:log4cl)
  :components ((:file "dirlister_poc"))

  :build-operation "program-op"
  :build-pathname "dirlister_poc"
  :entry-point );"dirlister_poc:start-dirlister-poc")
