(uiop:define-package :elmtui.tests.focus-keymaps-example
  (:use :cl :fiveam)
  (:import-from :elmtui.core.event-types #:make-key-event)
  (:import-from :elmtui.keymaps #:process-key-event)
  (:export #:run-focus-keymaps-example-tests))

(in-package :elmtui.tests.focus-keymaps-example)

(def-suite focus/keymaps/example)
(in-suite focus/keymaps/example)

(defun %copy-focus-fixture-state ()
  (let ((state (copy-tree (elmtui.tests.focus-simple-tests::%initial-state))))
    ;; Make shutdown state an existing plist cell so helper-level SETF/GETF
    ;; mutates the shared fixture instead of rebinding only the helper's local
    ;; STATE variable when app-update returns (:should-quit t).
    (unless (getf state :should-quit)
      (setf state (list* :should-quit nil state)))
    state))

(defun %current-focus-id (state)
  (getf (getf state :focus-manager) :current-focus-id))

(defun %apply-focus-update-result! (state result)
  (dolist (patch (elmtui.state.api:ur-patches result))
    (destructuring-bind (key value) patch
      (setf (getf state key) value)))
  state)

(defun %dispatch-focus-message! (state message)
  (let* ((*standard-output* (make-broadcast-stream))
         (result (elmtui.tests.focus-simple-tests::app-update message state)))
    (%apply-focus-update-result! state result)
    (dolist (command (elmtui.state.api:ur-commands result))
      (%dispatch-focus-message! state command)))
  state)

(defun %make-focus-dispatcher (state seen-messages)
  (lambda (message)
    (push message (symbol-value seen-messages))
    (%dispatch-focus-message! state message)))

(test tab-moves-focus-and-enter-activates-buttons
  "Tab and Enter behavior is enforced with a minimal core fixture, not the examples system."
  (let* ((state (%copy-focus-fixture-state))
         (*seen-messages* nil)
         (dispatch (%make-focus-dispatcher state '*seen-messages*)))
    (declare (special *seen-messages*))
    (is (eq :choices (%current-focus-id state)))

    (is-true (process-key-event (make-key-event :key :tab)
                                nil
                                :app-state state
                                :dispatch-fn dispatch))
    (is (equal '(:focus-next) (first *seen-messages*)))
    (is (eq :btn-ok (%current-focus-id state)))

    (is-true (process-key-event (make-key-event :key :enter)
                                nil
                                :app-state state
                                :dispatch-fn dispatch))
    (is (equal '(:ok) (first *seen-messages*)))
    (is-true (getf state :should-quit))))

(defun run-focus-keymaps-example-tests ()
  (run! :focus/keymaps/example))

(test typed-focus-state-dispatches-keys-and-allows-unbound-context
  "DEFAPPLICATION's typed model must expose its focused component keymap."
  (asdf:load-system :elmtui-examples)
  (let* ((package (find-package :elmtui.examples.focus-simple))
         (init (find-symbol "INITIALIZE-APP-STATE-FOCUS-SIMPLE-APP" package))
         (state (funcall (symbol-function init)))
         (seen nil)
         (elmtui.keymaps::*active-contexts* nil))
    (is-true (process-key-event
              (make-key-event :key :tab) nil :app-state state
              :dispatch-fn (lambda (message) (push message seen))))
    (is (equal '(:focus-next) (first seen)))
    (is-false (process-key-event
               (make-key-event :key :f4) nil :app-state state
               :dispatch-fn (lambda (message) (push message seen))))))
