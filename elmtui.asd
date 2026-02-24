(in-package :asdf)

(asdf:defsystem "elmtui"
  :version      "0.2.0"
  :description  "ElmTUI: A TUI framework inspired by Elm architecture"
  :author       "User <user@archlinux>"
  :license      "GNU GPL, version 3"
  :source-control (:git "https://github.com/user/elmtui.git")
  :depends-on   (#:alexandria #:str #:sb-posix
                  #:log4cl  ;; #:slynk
                  #:bordeaux-threads
                  #:cl-inputs
                  #:cl-styles
                  #:cl-events
                  #:cl-state)
  :pathname "./src/"
  :components (
                ;; ----------------------------------------------------------------
                ;; 0) Foundation: shared contracts, errors, globals, system events
                ;; ----------------------------------------------------------------
                (:file "utils")
                ;; contracts import message schema predicates from state/msg
                (:file "state/msg")
                (:file "core/errors")
                (:file "contracts")
                (:file "core/logging")
                (:file "core/defaults")
                (:file "core/conditions")
                (:file "core/globals")
                (:file "api")
                (:file "app/system-events")

                ;; ----------------------------------------------------------------
                ;; 1) State subsystem
                ;; ----------------------------------------------------------------
                (:file "core/async")
                (:module "state"
                  :pathname "state/"
                  :serial t
                  :components (
                                (:file "update")
                                (:file "api")
                                (:file "model")
                                (:file "state")))

                ;; ----------------------------------------------------------------
                ;; 2) View contracts/base protocol
                ;; ----------------------------------------------------------------
                (:file "view/geo")
                (:file "view/position")
                (:file "view/api")
                (:file "view/base-elements" :depends-on ("view/api" "view/geo"))
                (:file "view/element-protocol" :depends-on ("view/base-elements"))

                ;; ----------------------------------------------------------------
                ;; 3) Core event/loop subsystem
                ;; event-propagation imports ui-node from view/api, so view contracts
                ;; must be available before this module compiles.
                ;; ----------------------------------------------------------------
                (:module "core"
                  :pathname "./core/"
                  :serial t
                  :components (
                                (:file "threads")
                                (:file "event-channels")
                                (:file "message-bus")
                                (:file "event-pipeline")
                                (:file "topics")
                                (:file "topic-registry")
                                (:file "event-types")
                                (:file "keymaps")
                                (:file "events")
                                (:file "event-propagation")
                                (:file "event-async")
                                (:file "focus")
                                (:file "loop")))

                ;; ----------------------------------------------------------------
                ;; 4) UI/App contract and API layer
                ;; ----------------------------------------------------------------
                (:file "ui/component-metaclass")
                (:file "ui/dsl-resolution")
                (:file "ui/api")
                (:file "platform/api")

                ;; ----------------------------------------------------------------
                ;; 5) View runtime implementation
                ;; ----------------------------------------------------------------
                (:file "view/core")
                (:file "view/styled")
                (:file "view/memo")
                (:file "view/layout/utils" :depends-on ("view/geo"))
                (:file "view/layout/flex" :depends-on ("view/layout/utils"))
                (:file "view/layout/grid" :depends-on ("view/layout/utils"))
                (:file "view/layout/core" :depends-on ("view/layout/flex" "view/layout/grid"))
                (:file "view/reactive")
                (:file "view/dsl")
                (:file "view/tree-transforms" :depends-on ("view/base-elements" "view/layout/core"))

                ;; ----------------------------------------------------------------
                ;; 6) UI runtime subsystem
                ;; ----------------------------------------------------------------
                (:module "ui"
                  :serial t
                  :pathname "ui/"
                  :components (
                                (:file "defcomponent")
                                (:module "widgets"
                                  :pathname "widgets/"
                                  :serial t
                                  :components (
                                                (:file "utils")
                                                (:file "viewport")
                                                (:file "root-viewport")
                                                (:file "drawable-content")
                                                (:file "button")
                                                (:file "layout")
                                                (:file "label")
                                                (:file "textinput")
                                                (:file "grid-container")
                                                (:file "keytester")
                                                (:file "keytester-map")
                                                (:file "listbox")
                                                (:file "counter")
                                                (:file "scrollable-container")
                                                (:file "scroll-panel")))
                                ))

                ;; ----------------------------------------------------------------
                ;; 7) Application runtime subsystem
                ;; ----------------------------------------------------------------
                (:file "app/api")
                (:file "app/application-extension")
                (:file "app/tea-core")
                (:file "app/application")
                (:file "app/dsl-type-registry")

                ;; ----------------------------------------------------------------
                ;; 8) Style subsystem
                ;; ----------------------------------------------------------------
                (:module "style"
                  :serial t
                  :pathname "style/"
                  :components ((:file "presets")
                                (:file "manager")
                                (:file "stylable-impl")))

                ;; ----------------------------------------------------------------
                ;; 9) Platform subsystem
                ;; ----------------------------------------------------------------
                (:module "platform"
                  :serial t
                  :pathname "platform/"
                  :components (
                                (:file "input")
                                (:file "backend/common/ansi-styling")
                                (:file "backend/common/virtual-buffer")
                                (:file "backend/terminal/terminal")
                                (:file "tmux-capture" :depends-on ("backend/common/virtual-buffer" "backend/terminal/terminal"))
                                (:file "backend/terminal/diff-renderer")
                                (:file "tree-renderer" :depends-on ("backend/common/ansi-styling" "backend/common/virtual-buffer"))
                                (:file "backend/faketerm/faketerm")
                                (:file "backend/urxvt/urxvt")))

                ;; ----------------------------------------------------------------
                ;; 10) Integration and entrypoints
                ;; ----------------------------------------------------------------
                (:file "pipeline")
                (:file "platform/driver" :depends-on ("app/system-events" "pipeline"))
                (:file "tools/packager")
                (:file "dev/dev")
                (:file "elmtui"))
  ;; Build a binary:
  :build-operation "program-op"
  :build-pathname "elmtui"
  :entry-point "elmtui:dev-main")
