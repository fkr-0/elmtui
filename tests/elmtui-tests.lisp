;;;===============================================================
;;; File: tests/elmtui-tests.lisp
;;; FiveAM Unit Tests for Step 1: Advanced Event & Message Layer

(defpackage :elmtui-tests
  (:use :cl :fiveam
        :elmtui.core.events
        :elmtui.core.conditions))

(in-package :elmtui-tests)

(def-suite step1-event-message)
(in-suite step1-event-message)

;;; 1. Message contract registration and enforcement
(test message-contract-validation
  (register-message-contract :foo (lambda (msg) (equal (message-data msg) :ok)))
  (let ((msg-valid (make-message :foo :ok))
        (msg-invalid (make-message :foo :fail)))
    (is (not (signals elmtui.core.conditions:message-validation-error
                      (validate-message msg-valid))))
    (is (signals elmtui.core.conditions:message-validation-error
                 (validate-message msg-invalid)))))

;;; 2. Message dispatch to handler
(defvar *handler-called* nil)
(defun test-handler (msg) (setf *handler-called* (message-data msg)))
(test message-dispatch
  (let ((msg (make-message :bar 42)))
    (setf *handler-called* nil)
    (let ((token (subscribe :bar #'test-handler)))
      (publish msg)
      (is (= *handler-called* 42))
      ;; Clean up
      (unsubscribe token))))

;;; 3. Message dispatch with error and restart
(defvar *error-handler-called* nil)
(defun error-handler (msg)
  (setf *error-handler-called* t)
  (error "Handler error"))
(test message-dispatch-error
  (let ((msg (make-message :baz 99)))
    (setf *error-handler-called* nil)
    (let ((token (subscribe :baz #'error-handler)))
      (is (signals elmtui.core.conditions:subscriber-handler-error
                   (publish msg)))
      (is *error-handler-called*)
      (unsubscribe token))))

;;; 4. Message priorities (stub: correct registration)
(test message-priority-registration
  (register-message-contract :prio (lambda (msg) t) 42)
  (is (= (gethash :prio *message-priorities*) 42)))

;;; 5. Logging/tracing (message log output)
(test message-logging
  (let ((msg (make-message :logtest :foo)))
    (is (stringp (with-output-to-string (s)
                   (let ((*standard-output* s))
                     (log-message msg :test)))))))

;;; Run all tests
#-asdf
(run! 'step1-event-message)
