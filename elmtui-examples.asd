;; Examples in a separate system to keep core load time minimal
(asdf:defsystem "elmtui-examples"
  :version      "0.2.0"
  :description  "ElmTUI maintained example applications"
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
                (:file "keymap-app")
                (:file "cursor-inspector")
                (:file "fzy-picker")
                (:file "tmux-hover-demo")
                (:file "tmux-idle-screensaver")
                (:file "pong-below-cursor")
                (:file "scroll-panel-demo")
                (:file "game-of-life")
                (:file "root-viewport-test-app")
                (:file "fzf-finder-real")
                (:file "glider-real")
                (:file "input-selector")
                (:file "dirli")))
