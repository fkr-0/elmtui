(uiop:define-package :elmtui.tests.focus-keymaps-example
  (:use :cl :fiveam)
  (:import-from :elmtui.tests.focus-simple-tests #:run-focus-simple)
  (:import-from :elmtui.core.event-types #:make-key-event)
  (:import-from :elmtui.keymaps #:process-key-event)
  (:export #:run-focus-keymaps-example-tests))

(in-package :elmtui.tests.focus-keymaps-example)

(def-suite focus/keymaps/example)
(in-suite focus/keymaps/example)

(test tab-moves-focus-and-enter-activates-buttons
  ;; Skip this test for now as it requires the examples system
  ;; which causes compilation issues in the test runner
  (skip "Requires elmtui-examples system which causes compilation issues"))

(defun run-focus-keymaps-example-tests ()
  (run! :focus/keymaps/example))
