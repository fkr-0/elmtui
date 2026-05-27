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


;; Loadable subset for systems that need only the stable enhanced viewport.
;; The full experimental slash-named system above also loads label/button files.
(asdf:defsystem "elmtui-widgets-enhanced"
  :version      "0.1.0"
  :description  "Stable enhanced widgets used by elmtui tests"
  :author       "User <user@archlinux>"
  :license      "GNU GPL, version 3"
  :depends-on   (:elmtui)
  :pathname "./src/ui/widgets/"
  :components ((:file "viewport-enhanced")))
