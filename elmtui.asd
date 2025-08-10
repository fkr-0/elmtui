(in-package :asdf-user)

(asdf:defsystem "elmtui"
  :version      "0.1.0"
  :description  "ElmTUI: A TUI framework inspired by Elm architecture"
  :author       "User <user@archlinux>"
  :license      "GNU GPL, version 3"
  :source-control (:git "https://github.com/user/elmtui.git")
  :depends-on   (#:alexandria #:str #:sb-posix
                              #:log4cl  #:slynk
                              #:cl-reexport
                              #:bordeaux-threads)
  :pathname "./src/"
  :serial t
  :components (
               (:file "utils")
               ;; (:file "state/utils")
               (:file "tea-state/msg")

               (:file "contracts")
               (:file "core/logging")
               (:file "core/globals")
               (:file "api")
               (:module "cleve-elm"
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

               (:file "view/geo")
               (:file "view/style-lib/api") ; Defines stylable, selector base class, etc.
               ;; Core Modules (Load after cleve-elm, before API Layer)
               (:file "view/position") ; Load position before focus manager
               (:file "view/api") ; Imports: cl (pure declarations)
               (:file "view/base-elements") ;
               (:file "view/element-protocol") ;

               (:file "core/conditions")
               ;; Load state module early since focus manager needs it
               (:module "tea-state"
                :pathname "tea-state/"
                :serial t
                :components ((:file "api")
                             (:file "state")
                             (:file "transactions") ; Added transactions.lisp
                             (:file "observers")
                             (:file "update")
                             (:file "model")
                             (:file "core")))
               (:file "update-dsl")
               (:file "app/system-events")
               ;; (:module "state"
               ;;  :pathname "state/"
               ;;  :serial t
               ;;  :components ((:file "api")
               ;;               ;; (:module "state-lib"
               ;;               ;;  :serial t
               ;;               ;;  :pathname "statelib/"
               ;;               ;;  :components (
               ;;               ;;               (:file "state")
               ;;               ;;               (:file "observe")
               ;;               ;;               (:file "transaction")
               ;;               ;;               (:file "package")))

               ;;               (:file "state")
               ;;               (:file "model")
               ;;               (:file "transactions") ; Added transactions.lisp
               ;;               (:file "update")
               ;;               ))
                                        ; Moved here - loads after state implementation
               (:module "core"
                :pathname "./core/"
                :serial t
                :components (
                             (:file "async")
                             (:file "threads")
                             (:file "event-channels")
                             (:file "message-bus")
                             (:file "topics")
                             (:file "topic-registry")
                             (:file "event-types") ; Event type definitions
                             (:file "keymaps")
                             (:file "events")
                             (:file "event-compat") ; Event compatibility layer
                             (:file "event-propagation") ; Event propagation system
                             (:file "event-async") ; Async event handling
                             ;; (:file "base-keymap")
                             ;; (:file "focus-manager")
                             ;; Enhanced Focus Management
                             ;; Advanced Keyboard Event Handling

                             ;; (:module "keymap"
                             ;;  :pathname "keymap/"
                             ;;  :serial t
                             ;;  :components ((:file "sequence")
                             ;;               (:file "registry")
                             ;;               (:file "defaults")
                             ;;               (:file "event-integration")))
                             (:module "focus"
                              :pathname "focus/"
                              :serial t
                              :components ((:file "manager")))
                             ;; (:file "keymap-system")
                                        ; Main entry point for keyboard/focus system
                             (:file "loop")))
               ;; ================= API LAYER =================
               ;; These API files define the public interface for each module
               ;; Each contains both the interface declarations and implementations
               (:file "ui/api") ; Imports: elmtui.state.api, elmtui.utils
               (:file "app/api") ; Imports: elmtui.core.globals, elmtui.core.event-channels

               (:file "platform/api") ; Imports: elmtui.utils, bordeaux-threads




               (:file "view/core")
               (:module "view/style-lib"
                :pathname "view/style-lib/"
                :serial t
                :components (
                             (:file "util")
                             (:file "types")
                             (:file "styles")
                             (:file "style-set")
                             (:file "macros")
                             (:file "selector")
                             (:file "properties")

                             ;; Selector implementations moved after view/styled
                             (:file "rule")
                             (:file "stylable") ; Implementation details? Might depend on api.
                             (:file "styled-strings")
                             (:file "stylesheet")
                             (:file "style-lib")))
               (:file "view/styled")
               ;; --- View / UI Dependency Resolution ---
               ;; Load core view definitions first
               ;; Load the style library needed by styled nodes and UI
                                        ; Main package file?

               ;; Load the styled node definition (depends on style-lib/api)


               ;; Load selector implementations (depends on view/styled)

               ;; Load UI Components (depend on view/core, view/styled, view/style-lib)
               ;; Load remaining View components (depend on UI widgets, layout etc)
               (:file "view/memo")
               (:module "ui"
                :serial t
                :pathname "ui/"
                :components (

                             (:file "api") ; Correct filename to load widgets.lisp
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
                                           (:file "form") ; Using v2 form widget
                                           (:file "keytester")
                                           (:file "keytester-map")
                                           (:file "listbox")
                                           (:file "counter")
                                           (:file "scrollable-container")
                                           ))
                             ;; Load the main package file AFTER the individual widget files
                             (:file "widgets-pkg") ; Correct filename to load widgets.lisp
                             (:file "widget-registry")))
               (:file "app/application")
               (:file "app/dsl-type-registry")
               ;; (:file "view/dsl")
               (:file "view/dsl")
               (:file "view/layout/utils")   ; Grid depends on layout now
               (:file "view/layout/flex")
               (:file "view/layout/grid")   ; Grid depends on layout now
               (:file "view/layout/core") ; Load layout before grid
               (:file "view/reactive") ; Reactive view system
               (:file "view/animation") ; Animation framework
               (:file "view/tree-transforms")

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
                             ;; Platform API Definition is loaded earlier in the "API LAYER" block
                             (:file "backend/common/ansi-styling")
                             (:file "backend/common/virtual-buffer")
                             (:file "backend/common/utils")
                             (:file "backend/terminal/terminal")
                             (:file "backend/terminal/diff-renderer")
                             (:file "tree-renderer" :depends-on ("backend/common/ansi-styling"))
                             (:file "input")
                             ;; Backend Implementations
                             (:module "backend"
                              :pathname "backend/"
                              :serial t
                              :components (
                                           (:module "faketerm"
                                            :pathname "faketerm/"
                                            :components ((:file "faketerm")))
                                           (:module "terminal"
                                            :pathname "terminal/"
                                            :serial t
                                            :components ((:file "terminal")
                                                         (:file "diff-renderer")))
                                           (:module "urxvt"
                                            :pathname "urxvt/"
                                            :components ((:file "urxvt")))))))

               ;; Files loaded after modules
               (:file "pipeline")
               (:file "platform/driver" :depends-on ("app/system-events"))

               ;; Development Utilities
               (:module "examples"
                :serial t
                :pathname "../examples/"
                :components (
                             (:file "rainbow-app")
                             (:file "key-tester")
                             (:file "mini-rainbow")))
               (:file "../dev-setup")
               (:file "dev/dev")
               (:file "elmtui"))
  ;; Build a binary:
  :build-operation "program-op"
  :build-pathname "elmtui"
  :entry-point "elmtui:dev-main")

(asdf:defsystem "elmtui/examples"
  :author "User <user@archlinux>"
  :license "GNU GPL, version 3"
  :depends-on (:elmtui)
  :components ((:module "examples"
                :pathname "../examples/"
                :serial t
                :components
                ((:file "keymap-app")
                 (:file "boxes-app") ; Added boxes-app
                 ;; Add other example app files here as they are updated
                 ;; (:file "rainbow-app")
                 ;; (:file "rainbow-app-canvas")
                 ;; (:file "dirli")
                 ;; (:file "colortext-app")
                 )))
  :description "Examples for elmtui.")

;; (asdf:defsystem "elmtui/tests"
;;   :author "User <user@archlinux>"
;;   :license "GNU GPL, version 3"
;;   :depends-on (:elmtui :fiveam :alexandria)
;;   :components ((:module "tests"
;;                 :serial t ; Ensure tests run in a defined order if necessary, or remove if not.
;;                 :components
;;                 ((:file "elmtui-tests")
;;                  (:file "application-init-tests")
;;                  (:file "component-init-tests")
;;                  ;; (:file "flex-layout-tests")
;;                  ;; (:file "grid-layout-engine-tests")
;;                  ;; (:file "tree-renderer-tests") ; Added tree-renderer tests
;;                  ;; Add other test files here
;;                  )))
;;   :description "Test suite for elmtui."
;;   :perform (test-op (op c) (symbol-call :fiveam :run! c)))
