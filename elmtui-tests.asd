(in-package :asdf-user)

(asdf:defsystem "elmtui-tests"
  :description "Test suite for the elmtui system"
  :author "User <user@archlinux>"
  :version "0.0.1"
  :depends-on (#:elmtui #:fiveam)
  :license "GPL"
  :serial t
  :components ((:module "tests"
                :serial t
                :components ((:file "elmtui-tests")
                             (:file "focus-simple-test")
                             (:file "rainbow-test")
                             (:file "defcomponent-tests")
                             (:file "keymaps-tests")
                             (:file "application-init-tests")
                             (:file "component-init-tests")
                             (:file "rendering-pipeline-tests")
                             (:file "dsl-props-normalization-tests")
                             (:file "tree-transforms-layout-tests")
                             (:file "rendering-tests")
                             (:file "pipeline-contract-tests")
                             (:file "contracts-tests")
                             (:file "path-tests")
                             (:file "tea-state-tests")
                             (:file "contract-restart-tests")
                             (:file "base-dsl-tests")
                             (:file "base-elements-tests")
                             (:file "dsl-resolve-tests")
                             (:file "helpers-tests")
                             (:file "flex-tests")
                             (:file "flex-layout-tests2")
                             (:file "grid-layout-tests2")
                             (:file "update-dsl-tests")
                             (:file "update-dsl-appstate-tests")
                             (:file "root-viewport-anchor-behavior-tests")
                             (:file "keymaps-focus-integration-tests")
                             (:file "focus-keymaps-example-tests")
                             (:file "root-viewport-rewrite-tests"))))
  :perform (test-op (op c) (symbol-call :elmtui.tests :run-all-tests)))
;; (:file "elmtui-loop-async-tests")
;; (:file "elmtui-state-tests")
;; (:file "elmtui-core-keymap-tests") ; Added keymap tests
;; (:file "elmtui-keyboard-focus-tests") ; Added keyboard and focus integration tests
;; (:file "elmtui-view-tests")
;; (:file "elmtui-widget-tests")
;; (:file "elmtui-style-lib-tests") ; Added new style-lib tests
;; (:file "elmtui-style-selector-tests") ; Added selector tests
;; (:file "elmtui-canvas-renderer-tests") ; Added
;; (:file "elmtui-virtual-buffer-tests")
;; (:file "elmtui-integration-tests") ; Added integration tests
;; ;; (:file "elmtui-event-system-tests") ; Added event system tests
;; (:file "elmtui-grid-layout-tests") ; Added grid layout tests
;; (:file "elmtui-backend-utils-tests") ; Added backend utils tests
;; (:file "elmtui-diff-renderer-tests") ; Added diffing renderer tests
;; (:file "elmtui-keymap-focus-event-tests") ; Added keymap-focus-event chain tests
;; (:file "elmtui-canvas-tests") ; Added canvas tests

;; ;; V2 Tests
;; (:module "v2"
;;  :serial t
;;  :components ((:file "test-widgets-utils")
;;               (:file "test-dsl")
;;               ;; (:file "test-widgets-lifecycle")
;;               (:file "test-app-lifecycle")
;;               (:file "run-v2-tests")))))))

;; The following would not return the right exit code on error, but still 0.
