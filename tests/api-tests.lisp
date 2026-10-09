;;;; API Tests
;;;; Tests for the core elmtui.api module

(uiop:define-package :elmtui-tests.api
  (:use :cl :fiveam)
  (:import-from :elmtui.api #:dsl-type)
  (:export #:api-suite))

(in-package :elmtui-tests.api)

(def-suite api-suite
  :in elmtui.tests:elmtui-test
  :description "Test suite for core API")

(in-suite api-suite)

(test dsl-type-generic-exported
  "dsl-type generic is exported from elmtui.api"
  (is (fboundp 'elmtui.api:dsl-type))
  (is (symbol-package 'elmtui.api:dsl-type)))

(test component-lookup-rejects-invalid-state
  "Invalid component state arguments must signal a type error, not recurse."
  (signals type-error (elmtui.app.api:get-component-instance :button nil))
  (signals type-error (elmtui.app.api:get-component-instance '(:button) :invalid)))

(test platform-options-recognize-real-tmux-options
  "Public validation must accept the options consumed by the terminal driver."
  (is (null (elmtui.app.api:validate-platform-options
             :tty '(:prefill-from-tmux t :tmux-prefill-mode :screen))))
  (is (null (elmtui.app.api:validate-platform-options
             :tty '(:prefill-from-tmux nil :tmux-prefill-mode :pane))))
  (is (null (elmtui.app.api:validate-platform-options
             :tty '(:signal-keys-as-input t :use-alternate-screen nil)))))

(test platform-options-reject-malformed-arguments
  "Odd-length option lists, unknown keys and non-list values are rejected."
  (signals error (elmtui.app.api:validate-platform-options :tty '(:timeout)))
  (signals error (elmtui.app.api:validate-platform-options :tty '(:unknown t)))
  (signals type-error (elmtui.app.api:validate-platform-options :tty (read-from-string ":invalid")))
  (signals error (elmtui.app.api:validate-platform-options :tty '(:tmux-prefill-mode :typo)))
  (signals type-error (elmtui.app.api:validate-platform-options :tty '(:prefill-from-tmux 42)))
  (signals error (elmtui.app.api:validate-platform-options :tty '(:use-alternate-screen t))))

(test public-docstrings-terminal-style
  "Guard the documented public binding kinds and important semantics."
  (dolist (spec (quote ((elmtui.platform.backend.common.ansi-styling:terminal-color type "color descriptor")
             (elmtui.platform.backend.common.ansi-styling:terminal-style type "style descriptor")
             (elmtui.platform.backend.common.ansi-styling:make-terminal-color function "RED, GREEN, BLUE")
             (elmtui.platform.backend.common.ansi-styling:make-terminal-style function "FG-COLOR")
             (elmtui.platform.backend.common.ansi-styling:make-termcolor function "shorthand")
             (elmtui.platform.backend.common.ansi-styling:terminal-color-simple function "SIMPLE")
             (elmtui.platform.backend.common.ansi-styling:terminal-color-bg function "BG flag")
             (elmtui.platform.backend.common.ansi-styling:no-color-p function "no RGB component")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color function "FG-COLOR")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-bg-color function "BG-COLOR")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color-val function "RGB integer list")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-bg-color-val function "RGB integer list")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-bold function "BOLD attribute")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-italic function "ITALIC attribute")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-underline function "UNDERLINE attribute")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-faint function "FAINT attribute")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-blink function "BLINK attribute")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-inverse function "INVERSE attribute")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-strike function "STRIKE attribute")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-invisible function "INVISIBLE attribute")
             (elmtui.platform.backend.common.ansi-styling:terminal-style-kv function "Accepted keys")
             (elmtui.platform.backend.common.ansi-styling:update-style! function "raw plist")
             (elmtui.platform.backend.common.ansi-styling:ansi-seqs function "SGR")
             (elmtui.platform.backend.common.ansi-styling:exec-sequence function "LOCKABLE"))))
    (destructuring-bind (symbol kind fragment) spec
      (is (search fragment
                  (or (documentation symbol kind) "")
                  :test (function char-equal))
          "Incorrect or absent ~A metadata for ~S; expected ~S"
          kind symbol fragment))))

(test public-docstrings-contract-conditions
  "Guard the documented public binding kinds and important semantics."
  (dolist (spec (quote ((elmtui.contracts:make-dsl-tree function "DSL-TREE")
             (elmtui.contracts:make-raw-tree function "RAW-TREE")
             (elmtui.contracts:make-styled-tree function "STYLED-TREE")
             (elmtui.contracts:make-atomic-tree function "ATOMIC-TREE")
             (elmtui.contracts:make-laid-out-tree function "LAID-OUT-TREE")
             (elmtui.contracts:contract-violation type "EXPECTED-TYPE")
             (elmtui.contracts:update-contract-violation type "update")
             (elmtui.contracts:view-contract-violation type "view")
             (elmtui.contracts:subscription-contract-violation type "subscription")
             (elmtui.contracts:message-contract-violation type "message")
             (elmtui.contracts:pipeline-contract-violation type "STACK-TRACE")
             (elmtui.contracts:cv-function-name function "function name")
             (elmtui.contracts:cv-expected-type function "expected type")
             (elmtui.contracts:cv-actual-value function "offending value")
             (elmtui.contracts:cv-context function "contextual information")
             (elmtui.contracts:violation-stage function "stage identifier")
             (elmtui.contracts:violation-expected function "expected type")
             (elmtui.contracts:violation-got function "offending object")
             (elmtui.contracts:make-subscription function "MESSAGE-FN")
             (elmtui.contracts:subscription-p function "SUBSCRIPTION"))))
    (destructuring-bind (symbol kind fragment) spec
      (is (search fragment
                  (or (documentation symbol kind) "")
                  :test (function char-equal))
          "Incorrect or absent ~A metadata for ~S; expected ~S"
          kind symbol fragment))))

(test public-docstrings-terminal-instance
  "Guard the documented public binding kinds and important semantics."
  (dolist (spec (quote ((elmtui.platform.backend.terminal:terminal-instance-stream function "STREAM slot")
             (elmtui.platform.backend.terminal:terminal-instance-width function "80")
             (elmtui.platform.backend.terminal:terminal-instance-height function "24")
             (elmtui.platform.backend.terminal:terminal-instance-cursor-visible-p function "visibility flag")
             (elmtui.platform.backend.terminal:terminal-instance-cursor-row function "ROW")
             (elmtui.platform.backend.terminal:terminal-instance-cursor-col function "COLUMN"))))
    (destructuring-bind (symbol kind fragment) spec
      (is (search fragment
                  (or (documentation symbol kind) "")
                  :test (function char-equal))
          "Incorrect or absent ~A metadata for ~S; expected ~S"
          kind symbol fragment))))
