;;; ElmTUI-native interactive Lisp REPL: flagship Workbench example entry.
;;; The UI is owned by elmtui.workbench.app / defapplication, not this loader.
(uiop:define-package :elmtui.examples.repl
  (:use :cl)
  (:export #:run-repl))
(in-package :elmtui.examples.repl)

(defun run-repl (&key (backend-type :terminal))
  "Start the optional ElmTUI Workbench in the normal terminal screen.
Evaluation is trusted Common Lisp in this process, never sandboxed."
  (unless (eq backend-type :terminal)
    (error "The interactive Lisp REPL requires the terminal backend."))
  (asdf:load-system "elmtui-workbench")
  (funcall (symbol-function
            (find-symbol "RUN-WORKBENCH"
                         (find-package :elmtui.workbench.app)))
           :platform :terminal
           :platform-options '(:use-alternate-screen nil
                               :signal-keys-as-input t)
           :argv nil))
