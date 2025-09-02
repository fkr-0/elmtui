;; Optional: Enhanced/experimental widgets built on contracts/DSL
(asdf:defsystem "elmtui/widgets-enhanced"
  :version      "0.1.0"
  :description  "Experimental enhanced widgets with contracts and DSL integration"
  :author       "User <user@archlinux>"
  :license      "GNU GPL, version 3"
  :depends-on   (:elmtui)
  :pathname "./src/ui/widgets/"
  :components (
               (:file "viewport-enhanced")
               (:file "label-enhanced")
               (:file "button-enhanced")))
