(uiop:define-package :elmtui.tests.async
  (:use :cl :fiveam)
  (:import-from :elmtui.core.async
                #:cmd-async))

(in-package :elmtui.tests.async)

(def-suite async-tests
  :in elmtui.tests:elmtui-test)
(in-suite async-tests)

;;; --- Construction tests (no progress, default) ---

(test cmd-async-no-progress-constructs-valid-command
  "cmd-async without :progress produces a valid :async command plist."
  (let ((cmd (cmd-async (lambda () :ok))))
    (is (eq :async (first cmd)))
    (is-true (typep (getf (rest cmd) :task) 'cl-events.async:async-task))
    (is-true (typep (getf (rest cmd) :promise) 'cl-events.async:promise))))

(test cmd-async-no-progress-calls-function-with-args-only
  "Without :progress, FUNCTION receives only ARGS (no progress callback)."
  (let ((messages nil)
        (original-sender elmtui.core.globals:*app-sender*))
    (unwind-protect
         (progn
           (setf elmtui.core.globals:*app-sender*
                 (lambda (message) (push message messages)))
           (let ((cmd
                   (cmd-async
                    (lambda (a b) (+ a b))
                    :args '(10 32)
                    :on-complete
                    (lambda (result)
                      `(:sum-complete :result ,result)))))
             (elmtui.core.async:interpret-cmd cmd)
             (is (= 42 (elmtui.core.async:await-cmd cmd)))
             (is (member '(:sum-complete :result 42)
                         messages
                         :test #'equal))))
      (setf elmtui.core.globals:*app-sender* original-sender))))

(test cmd-async-no-progress-zero-args
  "Without :progress and no :args, FUNCTION is called with zero arguments."
  (let ((messages nil)
        (original-sender elmtui.core.globals:*app-sender*))
    (unwind-protect
         (progn
           (setf elmtui.core.globals:*app-sender*
                 (lambda (message) (push message messages)))
           (let ((cmd
                   (cmd-async
                    (lambda () :done)
                    :on-complete
                    (lambda (result)
                      `(:completed :value ,result)))))
             (elmtui.core.async:interpret-cmd cmd)
             (is (eq :done (elmtui.core.async:await-cmd cmd)))))
      (setf elmtui.core.globals:*app-sender* original-sender))))

;;; --- Construction tests (with :progress t) ---

(test cmd-async-with-progress-constructs-valid-command
  "cmd-async with :progress t produces a valid :async command plist."
  (let ((cmd (cmd-async (lambda (progress)
                          (declare (ignore progress))
                          :ok)
                        :progress t)))
    (is (eq :async (first cmd)))
    (is-true (typep (getf (rest cmd) :task) 'cl-events.async:async-task))
    (is-true (typep (getf (rest cmd) :promise) 'cl-events.async:promise))))

(test cmd-async-with-progress-injects-callback
  "With :progress t, FUNCTION receives the progress callback as first arg."
  (let ((messages nil)
        (original-sender elmtui.core.globals:*app-sender*))
    (unwind-protect
         (progn
           (setf elmtui.core.globals:*app-sender*
                 (lambda (message) (push message messages)))
           (let ((cmd
                   (cmd-async
                    (lambda (progress value)
                      (funcall progress '(:phase :working))
                      (1+ value))
                    :args '(41)
                    :progress t
                    :on-complete
                    (lambda (result)
                      `(:lookup-succeeded :result ,result)))))
             (elmtui.core.async:interpret-cmd cmd)
             (is (= 42 (elmtui.core.async:await-cmd cmd)))
             ;; Verify on-complete message was sent
             (is (member '(:lookup-succeeded :result 42)
                         messages
                         :test #'equal))
             ;; Verify progress message was sent (it's an :async-progress-update)
             (is (find :async-progress-update messages :key #'first))))
      (setf elmtui.core.globals:*app-sender* original-sender))))

;;; --- Timeout / cancellation ---

(test cmd-async-timeout-calls-cancellation-and-cancels-promise
  (let* ((cancellation-called nil)
         (cmd (cmd-async (lambda () :ok)
                         :timeout 0.01
                         :cancellation-fn (lambda ()
                                            (setf cancellation-called t))))
         (promise (getf (rest cmd) :promise)))
    (sleep 0.05)
    (is-true cancellation-called)
    (is-true (cl-events.async:promise-cancelled-p promise))))

;;; --- E2E success/failure (no progress, default) ---

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
                    (lambda (value)
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
                    (lambda ()
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
      (setf elmtui.core.globals:*app-sender* original-sender))))

;;; --- E2E success with :progress t ---

(test async-command-e2e-success-with-progress
  "With :progress t, on-complete still fires and result is correct."
  (let ((messages nil)
        (original-sender elmtui.core.globals:*app-sender*))
    (unwind-protect
         (progn
           (setf elmtui.core.globals:*app-sender*
                 (lambda (message)
                   (push message messages)))
           (let ((cmd
                   (cmd-async
                    (lambda (progress value)
                      (funcall progress '(:phase :start))
                      (* value 2))
                    :args '(21)
                    :progress t
                    :on-complete
                    (lambda (result)
                      `(:doubled :result ,result)))))
             (elmtui.core.async:interpret-cmd cmd)
             (is (= 42 (elmtui.core.async:await-cmd cmd)))
             (is (member '(:doubled :result 42)
                         messages
                         :test #'equal))))
      (setf elmtui.core.globals:*app-sender* original-sender))))

;;; --- Command plist validity in both modes ---

(test cmd-async-plist-structure-without-progress
  "Returned command plist has all required keys without :progress."
  (let ((cmd (cmd-async (lambda () :ok)
                        :on-complete #'identity
                        :on-error #'identity)))
    (is (eq :async (first cmd)))
    (let ((plist (rest cmd)))
      (is-true (getf plist :task))
      (is-true (getf plist :id))
      (is-true (getf plist :promise))
      (is-true (getf plist :on-complete))
      (is-true (getf plist :on-error)))))

(test cmd-async-plist-structure-with-progress
  "Returned command plist has all required keys with :progress t."
  (let ((cmd (cmd-async (lambda (progress)
                          (declare (ignore progress))
                          :ok)
                        :progress t
                        :on-complete #'identity
                        :on-error #'identity)))
    (is (eq :async (first cmd)))
    (let ((plist (rest cmd)))
      (is-true (getf plist :task))
      (is-true (getf plist :id))
      (is-true (getf plist :promise))
      (is-true (getf plist :on-complete))
      (is-true (getf plist :on-error)))))

;;; --- Error handling with :progress t ---

(test async-command-e2e-failure-with-progress
  "With :progress t, on-error still fires when the function signals."
  (let ((messages nil)
        (original-sender elmtui.core.globals:*app-sender*))
    (unwind-protect
         (progn
           (setf elmtui.core.globals:*app-sender*
                 (lambda (message) (push message messages)))
           (let ((cmd
                   (cmd-async
                    (lambda (progress)
                      (funcall progress '(:phase :start))
                      (error "Failure after progress"))
                    :progress t
                    :on-error
                    (lambda (condition)
                      `(:failed :message ,(princ-to-string condition))))))
             (elmtui.core.async:interpret-cmd cmd)
             (let ((result
                     (handler-bind
                         ((elmtui.core.conditions:async-task-error
                            (lambda (condition)
                              (declare (ignore condition))
                              (invoke-restart 'use-value :fallback))))
                       (elmtui.core.async:await-cmd cmd))))
               (is (eq :fallback result))
               ;; Progress message was sent before the error
               (is (find :async-progress-update messages :key #'first))
               ;; Error message was also sent
               (is (find :failed messages :key #'first)))))
      (setf elmtui.core.globals:*app-sender* original-sender))))

;;; --- Progress message structure verification ---

(test async-progress-message-has-task-id-and-data
  "Progress messages contain :task-id and :progress keys with correct values."
  (let ((messages nil)
        (original-sender elmtui.core.globals:*app-sender*))
    (unwind-protect
         (progn
           (setf elmtui.core.globals:*app-sender*
                 (lambda (message) (push message messages)))
           (let ((cmd
                   (cmd-async
                    (lambda (progress)
                      (funcall progress '(:phase :loading :pct 50))
                      :ok)
                    :progress t
                    :on-complete (lambda (r) (declare (ignore r)) '(:done)))))
             (elmtui.core.async:interpret-cmd cmd)
             (elmtui.core.async:await-cmd cmd)
             (let ((progress-msg (find :async-progress-update messages :key #'first)))
               (is-true progress-msg)
               ;; Must have :task-id
               (is-true (getf (rest progress-msg) :task-id))
               ;; Must have :progress with the data we sent
               (is (equal '(:phase :loading :pct 50)
                          (getf (rest progress-msg) :progress))))))
      (setf elmtui.core.globals:*app-sender* original-sender))))

;;; --- No spurious progress messages without opt-in ---

(test async-no-progress-messages-without-optin
  "Without :progress, no :async-progress-update messages are emitted."
  (let ((messages nil)
        (original-sender elmtui.core.globals:*app-sender*))
    (unwind-protect
         (progn
           (setf elmtui.core.globals:*app-sender*
                 (lambda (message) (push message messages)))
           (let ((cmd
                   (cmd-async
                    (lambda () :ok)
                    :on-complete (lambda (r) (declare (ignore r)) '(:done)))))
             (elmtui.core.async:interpret-cmd cmd)
             (elmtui.core.async:await-cmd cmd)
             ;; No progress messages should exist
             (is (null (find :async-progress-update messages :key #'first)))))
      (setf elmtui.core.globals:*app-sender* original-sender))))

;;; --- Timeout with :progress t ---

(test cmd-async-timeout-with-progress
  "Timeout and cancellation work correctly with :progress t."
  (let* ((cancellation-called nil)
         (cmd (cmd-async (lambda (progress)
                           (declare (ignore progress))
                           :ok)
                         :progress t
                         :timeout 0.01
                         :cancellation-fn (lambda ()
                                            (setf cancellation-called t))))
         (promise (getf (rest cmd) :promise)))
    (sleep 0.05)
    (is-true cancellation-called)
    (is-true (cl-events.async:promise-cancelled-p promise))))
