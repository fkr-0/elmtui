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
  (signals type-error (elmtui.app.api:validate-platform-options :tty :invalid))
  (signals error (elmtui.app.api:validate-platform-options :tty '(:tmux-prefill-mode :typo)))
  (signals type-error (elmtui.app.api:validate-platform-options :tty '(:prefill-from-tmux 42)))
  (signals error (elmtui.app.api:validate-platform-options :tty '(:use-alternate-screen t))))
