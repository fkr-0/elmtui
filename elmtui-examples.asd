;; Examples in a separate system to keep core load time minimal
(asdf:defsystem "elmtui-examples"
  :version      "0.1.0"
  :description  "ElmTUI example applications"
  :author       "User <user@archlinux>"
  :license      "GNU GPL, version 3"
  :depends-on   (:elmtui :cl-fzy)
  :pathname "./examples/"
  :components (
                (:file "rainbow-app")
                (:file "key-tester")
                (:file "focus-simple")
                (:file "mini-rainbow")
                (:file "minimal-app")
                ;; (:file "dirli")
                (:file "keymap-app")
                (:file "cursor-inspector")
                (:file "fzy-picker")))


;; Legacy/experimental examples that may rely on older APIs
(asdf:defsystem "elmtui-examples/legacy"
  :version      "0.1.0"
  :description  "ElmTUI legacy/experimental examples (may require older APIs)"
  :author       "User <user@archlinux>"
  :license      "GNU GPL, version 3"
  :depends-on   (:elmtui)
  :pathname "./examples/"
  :components (
                (:file "boxes-app")
                (:file "colorblocks-app")
                (:file "colortext-app")
                (:file "comprehensive-widgets-demo")
                (:file "dirli")
                (:file "dsl-integration-demo")
                (:file "game-of-life")
                (:file "grid-event-form-app")
                (:file "message-contract-demo")
                (:file "rainbow-app-canvas")
                (:file "rainbow-app-contracted")
                (:file "root-viewport-test-app")
                (:file "simple-counter")
                (:file "standardized-widgets-example")))
