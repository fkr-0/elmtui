(in-package :asdf-user)

(asdf:defsystem "elmtui"
  :version      "0.1.0"
  :description  "ElmTUI: A TUI framework inspired by Elm architecture"
  :author       "User <user@archlinux>"
  :license      "GNU GPL, version 3"
  :source-control (:git "https://github.com/user/elmtui.git")
  :depends-on   (#:clevelib #:alexandria #:str #:sb-posix)
  :pathname "./src/"
  :serial t
  :components (
               ;; Global Definitions (Load First)
               (:file "core/globals")

               ;; State Management (Load before Core/Conditions)
               (:module "state"
                :pathname "state/"
                :serial t
                :components (
                             (:module "statelib"
                              :serial t
                              :pathname "statelib/"
                              :components (
                                           (:file "state")
                                           (:file "observe")
                                           (:file "transaction")
                                           (:file "package")))

                             (:file "state")
                             (:file "elm")
                             (:file "model")
                             (:file "msg")
                             (:file "update")))

               ;; Core Modules (Load after State)
               (:module "core"
                :pathname "./core/"
                :serial t
                :components (
                             (:file "conditions")
                             (:file "input_events") ; Added input events definition
                             (:file "async")
                             (:file "events")
                             (:file "keymap")
                             (:file "loop")))

               ;; --- View / UI Dependency Resolution ---
               ;; Load core view definitions first
               (:file "view/geo")
               (:file "view/core")
               ;; Load the style library needed by styled nodes and UI
               (:module "view/style-lib"
                :pathname "view/style-lib/"
                :serial t
                :components ((:file "api")
                             (:file "util")
                             (:file "types")
                             (:file "styles")
                             (:file "style-set")
                             (:file "macros")
                             (:file "properties")
                             (:file "selector")
                             (:file "rule")
                             (:file "stylable")
                             (:file "styled-strings")
                             (:file "stylesheet")
                             (:file "style-lib")))
               ;; Load the styled node definition
               (:file "view/styled")

               ;; Load UI Components (depend on view/core, view/styled, view/style-lib)
               (:module "ui"
                :serial t
                :pathname "ui/"
                :components ((:file "base")
                             (:module "widgets"
                              :pathname "widgets/"
                              :serial t
                              :components ((:file "utils")
                                           (:file "button")
                                           (:file "label")
                                           (:file "textinput")
                                           (:file "form") ; Added form widget
                                           (:file "listbox")
                                           (:file "scrollable-container")))
                             ;; Load the main package file AFTER the individual widget files
                             (:file "elm-widgets") ; Correct filename to load widgets.lisp
                             (:file "primitives")
                             (:file "composite")))

               ;; Load remaining View components (depend on UI widgets, layout etc)
               (:file "view/dsl")
               (:file "view/flex")
               (:file "view/layout") ; Load layout before grid
               (:file "view/grid")   ; Grid depends on layout now

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
                             ;; Backend Implementations
                             (:module "backend"
                              :pathname "backend/"
                              :serial t
                              :components (
                                           ;; Common utilities for backends
                                           (:module "common"
                                            :pathname "common/"
                                            :components ((:file "utils")))
                                           ;; Fake Terminal Backend
                                           (:module "faketerm"
                                            :pathname "faketerm/"
                                            :components ((:file "faketerm")))
                                           ;; Standard Terminal Backend
                                           (:module "terminal"
                                            :pathname "terminal/"
                                            :components ((:file "terminal")))
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
               (:file "elmtui")
               ;; Development Utilities
               (:module "dev"
                :serial t
                :pathname "dev/"
                :components (
                             (:file "dev"))))
  ;; Build a binary:
  :build-operation "program-op"
  :build-pathname "elmtui"
  :entry-point "elmtui:dev-main")
