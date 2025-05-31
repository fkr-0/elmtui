(in-package :asdf-user)

(asdf:defsystem "elmtui"
  :version      "0.1.0"
  :description  "ElmTUI: A TUI framework inspired by Elm architecture"
  :author       "User <user@archlinux>"
  :license      "GNU GPL, version 3"
  :source-control (:git "https://github.com/user/elmtui.git")
  :depends-on   (#:alexandria #:str #:sb-posix
                              #:log4cl #:slynk
                              #:cl-reexport
                              #:bordeaux-threads)
  :pathname "./src/"
  :serial t
  :components ((:module "cleve-elm"
                :pathname "clevelib/"
                :serial t
                :components ((:file "api")
                             (:file "config")
                             (:file "queue")
                             (:file "thread")
                             (:file "async")
                             (:file "thread-pool")
                             (:file "event-loop")
                             (:file "channel")
                             (:file "event")
                             (:file "message")
                             (:file "emitter")
                             (:file "target")
                             (:file "translator")
                             ;; (:file "relay")
                             (:file "ems")
                             (:file "clevelib")))
               (:file "core/globals")

               ;; State Management (Load before Core/Conditions)
               (:module "state"
                :pathname "state/"
                :serial t
                :components (
                             (:module "state-lib"
                              :serial t
                              :pathname "statelib/"
                              :components (
                                           (:file "state")
                                           (:file "observe")
                                           (:file "transaction")
                                           (:file "package")))

                             (:file "state")
                             (:file "msg")
                             (:file "model")
                             (:file "elm")
                             (:file "update")))

               (:file "view/geo")
               (:file "view/core")
               (:module "view/style-lib"
                :pathname "view/style-lib/"
                :serial t
                :components ((:file "api") ; Defines stylable, selector base class, etc.
                             (:file "util")
                             (:file "types")
                             (:file "styles")
                             (:file "style-set")
                             (:file "macros")
                             (:file "properties")
                             (:file "selector")
                             ;; Selector implementations moved after view/styled
                             (:file "rule")
                             (:file "stylable") ; Implementation details? Might depend on api.
                             (:file "styled-strings")
                             (:file "stylesheet")
                             (:file "style-lib")))
               (:file "view/styled")
               (:file "view/position")
               ;; Core Modules (Load after State)
               (:module "core"
                :pathname "./core/"
                :serial t
                :components (
                             (:file "conditions")
                             (:file "async")
                             (:file "threads")
                             (:file "event-channels")
                             (:file "message-bus")
                             (:file "topics")
                             (:file "topic-registry")
                             (:file "event-types") ; Event type definitions
                             (:file "events")
                             (:file "event-compat") ; Event compatibility layer
                             (:file "event-propagation") ; Event propagation system
                             (:file "event-async") ; Async event handling
                             (:file "base-keymap")
                             ;; (:file "focus-manager")
                             ;; Enhanced Focus Management
                             ;; Advanced Keyboard Event Handling

                             (:module "keymap"
                              :pathname "keymap/"
                              :serial t
                              :components ((:file "sequence")
                                           (:file "registry")
                                           (:file "defaults")
                                           (:file "event-integration")))
                             (:module "focus"
                              :pathname "focus/"
                              :serial t
                              :components ((:file "manager")))
                             (:file "keymap-system") ; Main entry point for keyboard/focus system
                             (:file "loop")))

               ;; --- View / UI Dependency Resolution ---
               ;; Load core view definitions first
               ;; Load the style library needed by styled nodes and UI
                                        ; Main package file?

               ;; Load the styled node definition (depends on style-lib/api)


               ;; Load selector implementations (depends on view/styled)

               ;; Load UI Components (depend on view/core, view/styled, view/style-lib)
               (:module "ui"
                :serial t
                :pathname "ui/"
                :components ((:module "widgets"
                              :pathname "widgets/"
                              :serial t
                              :components (
                                           (:file "utils")
                                           (:file "button")
                                           (:file "label")
                                           (:file "textinput")
                                           (:file "grid-container")
                                           (:file "form") ; Using v2 form widget
                                           (:file "listbox")
                                           (:file "counter")
                                           (:file "scrollable-container")))
                             ;; Load the main package file AFTER the individual widget files
                             (:file "widgets-pkg") ; Correct filename to load widgets.lisp
                             (:file "widget-registry")))

               ;; Load remaining View components (depend on UI widgets, layout etc)
               (:file "view/memo")
               ;; (:file "view/dsl")
               (:file "view/dsl")
               (:file "view/flex")
               (:file "view/layout") ; Load layout before grid
               (:file "view/grid")   ; Grid depends on layout now
               (:file "view/grid-layout") ; Load layout before grid
               (:file "view/reactive") ; Reactive view system
               (:file "view/animation") ; Animation framework

               ;; Styling System (Moved here as it depends on view/style-lib)
               (:module "style"
                :serial t
                :pathname "style/"
                :components ((:file "core")
                             (:file "presets")))
               ;; --- End View / UI ---

               ;; Platform Abstraction (Moved here as it depends on view modules)
               (:module "platform"
                :serial t
                :pathname "platform/"
                :components (
                             ;; Platform API Definition
                             (:file "api")
                             (:file "backend/common/virtual-buffer")
                             (:file "canvas")
                             ;; Backend Implementations
                             (:module "backend"
                              :pathname "backend/"
                              :serial t
                              :components (
                                           ;; Common utilities for backends
                                           (:module "common"
                                            :serial t
                                            :pathname "common/"
                                            :components ((:file "utils")
                                                         (:file "ansi-styling")
                                                         ))
                                           ;; Fake Terminal Backend
                                           (:module "faketerm"
                                            :pathname "faketerm/"
                                            :components ((:file "faketerm")))
                                           ;; Standard Terminal Backend
                                           (:module "terminal"
                                            :pathname "terminal/"
                                            :serial t
                                            :components ((:file "terminal")
                                                         (:file "diff-renderer")))
                                           ;; URxvt Backend
                                           (:module "urxvt"
                                            :pathname "urxvt/"
                                            :components ((:file "urxvt")))
                                           ))

                             ;; Original driver/input/output
                             (:file "input")
                             (:file "output")

                             (:file "driver")))

               ;; Files loaded after modules
               (:file "runtime")

               ;; Development Utilities
               ;; (:module "dev"
               ;;   :serial t
               ;;   :pathname "dev/"
               ;;   :components (
               ;;                 (:file "dev")))
               (:module "examples"
                :serial t
                :pathname "../examples/"
                :components ((:file "keymap-app")
                             (:file "rainbow-app")
                             (:file "boxes-app")
                             (:file "colortext-app")))
               (:module "dirlister"
                :serial t
                :pathname "../examples/dirlister_poc/"
                :components ((:file "dirlister_poc")))
               (:file "../dev-setup")
               (:file "elmtui"))
  ;; Build a binary:
  :build-operation "program-op"
  :build-pathname "elmtui"
  :entry-point "elmtui:dev-main")
