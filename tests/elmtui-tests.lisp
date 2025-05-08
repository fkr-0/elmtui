;;;===============================================================
;;; File: tests/elmtui-tests.lisp
;;; FiveAM Unit Tests for Step 1: Advanced Event & Message Layer

(defpackage :elmtui-tests
  (:use :cl :fiveam
        :elmtui.core.events
        :elmtui.state.msg ; For defmsg tests
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

;;; 6. defmsg constructor generation and validation
(defmsg test-construct-msg (:docstring "Test message for constructors")
  NoArgs
  (OneArg :value integer)
  (MultiArg :name string :count fixnum :active-p boolean))

(test defmsg-constructors
  ;; Test no-args variant
  (is (equal (make-no-args-test-construct-msg) '(:no-args)))
  ;; Test one-arg variant
  (is (equal (make-one-arg-test-construct-msg :value 123) '(:one-arg :value 123)))
  (is (signals type-error (make-one-arg-test-construct-msg :value "not-an-int")))
  ;; Test multi-arg variant
  (is (equal (make-multi-arg-test-construct-msg :name "Test" :count 5 :active-p t)
             '(:multi-arg :name "Test" :count 5 :active-p t)))
  (is (signals type-error (make-multi-arg-test-construct-msg :name "Test" :count "five" :active-p t))))

;;; 7. message-variant-p validation
(test message-variant-p-validation
  (is (message-variant-p 'test-construct-msg '(:no-args)))
  (is (message-variant-p 'test-construct-msg '(:one-arg :value 10)))
  (is (message-variant-p 'test-construct-msg '(:multi-arg :name "a" :count 1 :active-p nil)))
  ;; Check invalid variant keyword
  (is (not (message-variant-p 'test-construct-msg '(:unknown-variant))))
  ;; Check wrong message type
  (is (not (message-variant-p 'another-msg-type '(:no-args))))
  ;; Check non-list message instance
  (is (not (message-variant-p 'test-construct-msg :no-args)))
  ;; Check list not starting with keyword
  (is (not (message-variant-p 'test-construct-msg '(no-args)))))

;;; 8. Message Lifecycle Hooks (Basic Check)
;; Note: Testing exact hook call order might require more complex setup or mocks.
;; This checks if the hook variables exist and can be modified.
(defvar *test-before-hook-called* nil)
(defvar *test-after-hook-called* nil)
(defun test-before-hook (msg) (setf *test-before-hook-called* (message-type msg)))
(defun test-after-hook (msg) (setf *test-after-hook-called* (message-type msg)))

(test message-lifecycle-hooks
  (setf *test-before-hook-called* nil)
  (setf *test-after-hook-called* nil)
  (push #'test-before-hook elmtui.core.events::*before-publish-hooks*)
  (push #'test-after-hook elmtui.core.events::*after-publish-hooks*)
  (let ((msg (make-message :hook-test :data)))
    (publish msg)
    (is (eq *test-before-hook-called* :hook-test))
    (is (eq *test-after-hook-called* :hook-test)))
  ;; Clean up hooks
  (setf elmtui.core.events::*before-publish-hooks* (remove #'test-before-hook elmtui.core.events::*before-publish-hooks*))
  (setf elmtui.core.events::*after-publish-hooks* (remove #'test-after-hook elmtui.core.events::*after-publish-hooks*)))

;;; Run all tests
;;; #-asdf
;;; (run! 'step1-event-message) ; Now handled by elmtui-all-tests:run-all-elmtui-tests
