;; Examples in a separate system to keep core load time minimal
(asdf:defsystem "elmtui-examples"
  :version      "0.2.0"
  :description  "ElmTUI maintained example applications"
  :author       "ElmTUI contributors"
  :license      "GPL-3.0-only"
  :depends-on   (:elmtui)
  :pathname "./examples/"
  :components (
                (:file "rainbow-app")
                (:file "key-tester")
                (:file "focus-simple")
                (:file "mini-rainbow")
                (:file "minimal-app")
                (:file "keymap-app")
                (:file "cursor-inspector")
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
