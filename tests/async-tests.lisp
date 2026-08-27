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

(progn
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

  (test async-command-e2e-success-emits-completion-message
    (let ((messages nil)
          (original-sender elmtui.core.globals:*app-sender*))
      (unwind-protect
           (progn
             (setf elmtui.core.globals:*app-sender*
                   (lambda (message)
                     (push message messages)))
             (let ((cmd
                     (cmd-async
                      (lambda (_progress value)
                        (declare (ignore _progress))
                        (1+ value))
                      :args '(41)
                      :on-complete
                      (lambda (result)
                        `(:lookup-succeeded :result ,result)))))
               (elmtui.core.async:interpret-cmd cmd)
               (is (= 42 (elmtui.core.async:await-cmd cmd)))
               (is (member '(:lookup-succeeded :result 42)
                           messages
                           :test #'equal))))
        (setf elmtui.core.globals:*app-sender* original-sender))))

  (test async-command-e2e-failure-emits-error-message-and-allows-use-value
    (let ((messages nil)
          (original-sender elmtui.core.globals:*app-sender*))
      (unwind-protect
           (progn
             (setf elmtui.core.globals:*app-sender*
                   (lambda (message)
                     (push message messages)))
             (let ((cmd
                     (cmd-async
                      (lambda (_progress)
                        (declare (ignore _progress))
                        (error "Simulated transport failure"))
                      :on-error
                      (lambda (condition)
                        `(:lookup-failed :condition ,condition)))))
               (elmtui.core.async:interpret-cmd cmd)
               (let ((result
                       (handler-bind
                           ((elmtui.core.conditions:async-task-error
                              (lambda (condition)
                                (declare (ignore condition))
                                (invoke-restart 'use-value :cached))))
                         (elmtui.core.async:await-cmd cmd))))
                 (is (eq :cached result))
                 (is (find :lookup-failed messages :key #'first)))))
        (setf elmtui.core.globals:*app-sender* original-sender)))))
