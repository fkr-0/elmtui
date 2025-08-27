(uiop:define-package :elmtui.tests.keymaps-focus
  (:use :cl :fiveam)
  (:import-from :elmtui.keymaps
                #:parse-key-string #:keymap! #:process-key-event)
  (:import-from :elmtui.core.event-types
                #:make-key-event)
  (:export #:run-keymaps-focus-tests))

(in-package :elmtui.tests.keymaps-focus)

(def-suite keymaps/focus)
(in-suite keymaps/focus)

(test simple-dispatch-to-message
  (let* (;(nk (parse-key-string ))
         (app-state '(:dummy t))
         (dispatched '())
         (dispatch (lambda (msg) (push msg dispatched)))
         (map (keymap! :test-map
                ("C-q" :type :message :target '(:quit))))
         ;; Process a struct key event
         (evt (make-key-event :key :q :modifiers '(:control))))
    (declare (ignore map))
    ;; Focus manager currently ignored by process-key-event; app-state and dispatch used
    (let ((handled (process-key-event evt nil :app-state app-state :dispatch-fn dispatch)))
      (is-true handled)
      (is (equal (first dispatched) '(:quit))))))

(defun run-keymaps-focus-tests () (run! :keymaps/focus))
