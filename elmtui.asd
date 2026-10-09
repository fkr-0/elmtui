(in-package :asdf)

(asdf:defsystem "elmtui"
  :version      "0.2.0"
  :description  "Elm-style terminal UI toolkit for Common Lisp"
  :author       "ElmTUI contributors"
  :maintainer   "ElmTUI contributors"
  :license      "MIT"
  :depends-on   (#:alexandria #:sb-posix
                  #:log4cl  ;; #:slynk
                  #:bordeaux-threads
                  #:cl-inputs
                  #:cl-styles
                  #:cl-events
                  #:cl-state)
  :pathname "./src/"
  :components (
                ;; ----------------------------------------------------------------
                ;; 0) Foundation: shared contracts, errors, globals, core system events
                ;; ----------------------------------------------------------------
                (:file "utils")
                ;; contracts import message schema predicates from state/msg
                (:file "state/msg")
                (:file "state/message-normalization")
                (:file "state/path-context")
                (:file "core/errors")
                (:file "contracts")
                (:file "core/logging")
                (:file "core/defaults")
                (:file "core/conditions")
                (:file "core/condition-docs" :depends-on ("core/conditions" "core/errors"))
                (:file "core/globals")
                (:file "core/system-events")
                (:file "api")

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
                ;; ----------------------------------------------------------------
                (:module "core"
                  :pathname "./core/"
                  :depends-on ("utils")
                  :serial t
                  :components (
                                (:file "threads")
                                (:file "topics")
                                (:file "topic-registry" :depends-on ("topics"))
                                (:file "event-channels")
                                (:file "event-types")
                                (:file "event-async" :depends-on ("event-channels" "event-types"))
                                (:file "event-pipeline")
                                (:file "keymaps")
                                (:file "events")
                                (:file "loop")
                                (:file "focus")))

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
                                                (:file "scroll-panel")
                                                (:file "modal-dialog")))
                                )
                  )
                ;; UI-owned built-in DSL aliases (e.g. :root-viewport, :viewport, :text).
                ;; Loaded after widget classes so methods can reference concrete classes.
                (:file "ui/dsl-type-builtins")

                ;; ----------------------------------------------------------------
                ;; 7) Application runtime subsystem
                ;; ----------------------------------------------------------------
                (:file "app/api")
                (:file "runtime/context")
                (:file "runtime/protocol")
                (:file "runtime/effects")
                (:file "app/application-extension")
                (:file "app/tea-core")
                (:file "app/application")

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
                                ;; Pure, terminal-independent operations over virtual frames.
                                (:file "render/diff")
                                (:file "backend/terminal/terminal")
                                (:file "tmux-capture" :depends-on ("backend/common/virtual-buffer" "backend/terminal/terminal"))
                                (:file "backend/terminal/diff-renderer")
                                (:file "tree-renderer" :depends-on ("backend/common/ansi-styling" "backend/common/virtual-buffer"))
                                (:file "backend/faketerm/faketerm")
                                (:file "backend/urxvt/urxvt")))

                ;; ----------------------------------------------------------------
                ;; 10) Render/presentation interface and integration
                ;; ----------------------------------------------------------------
                (:file "render/presentation" :depends-on ("platform"))
                (:file "pipeline" :depends-on ("render/presentation"))
                (:file "platform/driver" :depends-on ("core/system-events" "pipeline"))


                (:file "dev/dev")
                (:file "elmtui"))
  ;; Build a binary:
  :build-operation "program-op"
  :build-pathname "elmtui"
  :entry-point "elmtui:dev-main")
