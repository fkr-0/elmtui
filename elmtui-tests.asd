(in-package :asdf-user)

(asdf:defsystem "elmtui-tests"
  :description "Test suite for the uncharming-tui system"
  :author "CL User <cl.user@mail.com>"
  :version "0.0.1"
  :depends-on (#:elmtui #:fiveam)
  :license "BSD"
  :serial t
  :components ((:module "tests"
                :serial t
                :components ((:file "packages")
                             (:file "elmtui-tests")
                             (:file "elmtui-loop-async-tests")
                             (:file "elmtui-state-tests")
                             (:file "elmtui-core-keymap-tests") ; Added keymap tests
                             (:file "elmtui-keyboard-focus-tests") ; Added keyboard and focus integration tests
                             (:file "elmtui-view-tests")
                             (:file "elmtui-widget-tests")
                             (:file "elmtui-style-lib-tests") ; Added new style-lib tests
                             (:file "elmtui-style-selector-tests") ; Added selector tests
                             (:file "elmtui-virtual-buffer-tests")
                             (:file "elmtui-integration-tests") ; Added integration tests
                             (:file "elmtui-event-system-tests") ; Added event system tests
                             (:file "elmtui-grid-layout-tests") ; Added grid layout tests
                             (:file "elmtui-backend-utils-tests") ; Added backend utils tests
                             (:file "elmtui-diff-renderer-tests") ; Added diffing renderer tests
                             (:file "elmtui-keymap-focus-event-tests") ; Added keymap-focus-event chain tests
                             (:file "elmtui-canvas-tests") ; Added canvas tests
                             
                             ;; V2 Tests
                             (:module "v2"
                              :serial t
                              :components ((:file "test-widgets-utils")
                                           (:file "test-dsl")
                                           (:file "test-widgets-lifecycle")
                                           (:file "test-app-lifecycle")
                                           (:file "run-v2-tests")))))))

;; The following would not return the right exit code on error, but still 0.
;; :perform (test-op (op _) (symbol-call :fiveam :run-all-tests))
