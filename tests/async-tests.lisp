(uiop:define-package :elmtui.tests.async
  (:use :cl :fiveam)
  (:import-from :elmtui.core.async
                #:cmd-async))

(in-package :elmtui.tests.async)

(def-suite async-tests
  :in elmtui.tests:elmtui-test)
(in-suite async-tests)

(test cmd-async-make-promise-zero-args
  (let ((cmd (cmd-async (lambda (_progress)
                          (declare (ignore _progress))
                          :ok))))
    (is (eq :async (first cmd)))
    (is-true (typep (getf (rest cmd) :task) 'cl-events.async:async-task))
    (is-true (typep (getf (rest cmd) :promise) 'cl-events.async:promise))))

(test cmd-async-timeout-calls-cancellation-and-cancels-promise
  (let* ((cancellation-called nil)
         (cmd (cmd-async (lambda (_progress)
                           (declare (ignore _progress))
                           :ok)
                         :timeout 0.01
                         :cancellation-fn (lambda ()
                                            (setf cancellation-called t))))
         (promise (getf (rest cmd) :promise)))
    (sleep 0.05)
    (is-true cancellation-called)
    (is-true (cl-events.async:promise-cancelled-p promise))))
