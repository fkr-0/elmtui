(uiop:define-package :elmtui.tests.focus-keymaps-example
  (:use :cl :fiveam)
  (:import-from :elmtui.examples.focus-simple #:run-focus-simple)
  (:import-from :elmtui.core.event-types #:make-key-event)
  (:import-from :elmtui.keymaps #:process-key-event)
  (:export #:run-focus-keymaps-example-tests))

(in-package :elmtui.tests.focus-keymaps-example)

(def-suite focus/keymaps/example)
(in-suite focus/keymaps/example)

(test tab-moves-focus-and-enter-activates-buttons
  (let* ((app-state (funcall (intern "%INITIAL-STATE" :elmtui.examples.focus-simple)))
         (dispatched '())
         (dispatch (lambda (msg) (push msg dispatched))))
    ;; Initially focus on listbox; Tab should dispatch :focus-next
    (let ((evt (make-key-event :key :tab :modifiers nil)))
      (is-true (process-key-event evt nil :app-state app-state :dispatch-fn dispatch))
      (is (eq (caar dispatched) :focus-next))
      ;; Apply focus-next change
      (destructuring-bind (&key focus-manager &allow-other-keys) app-state
        (let* ((ids (getf focus-manager :focusable-elements))
               (cur (getf focus-manager :current-focus-id))
               (pos (position cur ids))
               (next (if pos (nth (mod (1+ pos) (length ids)) ids) (first ids))))
          (setf (getf (getf app-state :focus-manager) :current-focus-id) next)))
      (setf dispatched '()))

    ;; Now focused on OK button; Enter should dispatch :ok
    (let ((evt (make-key-event :key :enter :modifiers nil)))
      (is-true (process-key-event evt nil :app-state app-state :dispatch-fn dispatch))
      (is (eq (caar dispatched) :ok)))))

(defun run-focus-keymaps-example-tests ()
  (run! :focus/keymaps/example))
