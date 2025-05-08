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

;;; 1.5 Schema-based message validation (using defmsg schemas)
(defmsg schema-validation-msg (:docstring "Message type for schema validation tests")
 NoArgsVariant
 (TypedArgVariant :count integer :label string)
 (OptionalArgVariant &key (id t) (activep boolean :initform t))) ; Assuming defmsg handles &key and initforms for schema

(test schema-based-validation-correct
 ;; Test with a message that conforms to the defmsg schema
 (let ((msg-no-args (make-message 'schema-validation-msg '(:no-args-variant)))
       (msg-typed-args (make-message 'schema-validation-msg '(:typed-arg-variant :count 123 :label "hello")))
       (msg-optional-args (make-message 'schema-validation-msg '(:optional-arg-variant :id "test-id" :activep nil)))
       (msg-optional-default (make-message 'schema-validation-msg '(:optional-arg-variant :id "another"))))

   ;; Ensure no explicit contract is set for schema-validation-msg for these tests
   (remhash 'schema-validation-msg elmtui.core.events::*message-contracts*)

   (is (not (signals elmtui.core.conditions:message-validation-error
                     (validate-message msg-no-args)))
       "Correct NoArgsVariant should pass schema validation.")
   (is (not (signals elmtui.core.conditions:message-validation-error
                     (validate-message msg-typed-args)))
       "Correct TypedArgVariant should pass schema validation.")
   (is (not (signals elmtui.core.conditions:message-validation-error
                     (validate-message msg-optional-args)))
       "Correct OptionalArgVariant with all args should pass schema validation.")
   (is (not (signals elmtui.core.conditions:message-validation-error
                     (validate-message msg-optional-default)))
       "Correct OptionalArgVariant with default for activep should pass.")))

(test schema-based-validation-incorrect
 ;; Ensure no explicit contract is set for schema-validation-msg for these tests
 (remhash 'schema-validation-msg elmtui.core.events::*message-contracts*)

 (let ((msg-unknown-variant (make-message 'schema-validation-msg '(:unknown-variant-for-schema)))
       (msg-wrong-type (make-message 'schema-validation-msg '(:typed-arg-variant :count "not-an-int" :label "world")))
       (msg-missing-arg (make-message 'schema-validation-msg '(:typed-arg-variant :count 456)))
       (msg-extra-arg (make-message 'schema-validation-msg '(:no-args-variant :extra "data")))
       (msg-not-a-list (make-message 'schema-validation-msg :no-args-variant))) ; Data is not a list

   (is (signals elmtui.core.conditions:message-validation-error
                (validate-message msg-unknown-variant))
       "Unknown variant should fail schema validation.")
   (is (signals elmtui.core.conditions:message-validation-error
                (validate-message msg-wrong-type))
       "Wrong argument type should fail schema validation.")
   (is (signals elmtui.core.conditions:message-validation-error
                (validate-message msg-missing-arg))
       "Missing argument should fail schema validation.")
   (is (signals elmtui.core.conditions:message-validation-error
                (validate-message msg-extra-arg))
       "Extra argument should fail schema validation (based on current validate-message-via-schema logic).")
   (is (signals elmtui.core.conditions:message-validation-error
                (validate-message msg-not-a-list))
       "Message data not being a list should fail schema validation.")))

;;; 2. Message dispatch to handler
(defvar *handler-called* nil)
(defun test-handler (msg) (setf *handler-called* (message-data msg)))
(test message-dispatch
  (let ((msg (make-message :bar 42)))
    (setf *handler-called* nil)
    (let ((token (subscribe :bar #'test-handler)))
      (publish msg)
      (is (= *handler-called* 42) "Handler should be called after subscribe and publish.")
      ;; Clean up
      (is (elmtui.core.loop:unsubscribe token) "Unsubscribe should return T for a valid token.")
      (setf *handler-called* nil)
      (publish msg) ; Publish again
      (is (null *handler-called*) "Handler should not be called after unsubscribe."))))

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
      (is (elmtui.core.loop:unsubscribe token) "Unsubscribe should return T for a valid token."))))

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

;;; 8. Message Lifecycle Hooks for send-message (Basic Check)
(defvar *test-before-send-hook-args* nil)
(defvar *test-after-send-hook-args* nil)

(defun test-before-send-hook (target msg)
  (setf *test-before-send-hook-args* (list target (message-type msg))))

(defun test-after-send-hook (target msg successp result)
  (declare (ignore result))
  (setf *test-after-send-hook-args* (list target (message-type msg) successp)))

(test message-send-lifecycle-hooks
  (let ((dummy-target (gensym "TARGET-"))
        (msg (make-message :hook-test :data)))
    ;; Mock on-message for the dummy target to avoid errors if it's not a real clevelib target
    (let ((original-on-message (fdefinition 'clevelib.api:on-message)))
      (setf (fdefinition 'clevelib.api:on-message)
            (lambda (target message)
              (declare (ignore target message))
              ;; Simulate some processing result
              :processed))
      (unwind-protect
           (progn
             (setf *test-before-send-hook-args* nil)
             (setf *test-after-send-hook-args* nil)
             (add-before-send-message-hook #'test-before-send-hook)
             (add-after-send-message-hook #'test-after-send-hook)

             (send-message dummy-target msg)

             (is (equal *test-before-send-hook-args* (list dummy-target :hook-test))
                 "Before-send hook should be called with correct target and message type.")
             (is (equal *test-after-send-hook-args* (list dummy-target :hook-test t))
                 "After-send hook should be called with correct target, message type, and success status.")

             ;; Test removal
             (remove-before-send-message-hook #'test-before-send-hook)
             (remove-after-send-message-hook #'test-after-send-hook)
             (setf *test-before-send-hook-args* nil)
             (setf *test-after-send-hook-args* nil)

             (send-message dummy-target (make-message :hook-test-2 :more-data))

             (is (null *test-before-send-hook-args*) "Before-send hook should not be called after removal.")
             (is (null *test-after-send-hook-args*) "After-send hook should not be called after removal."))
        ;; Restore original on-message
        (setf (fdefinition 'clevelib.api:on-message) original-on-message)))
    ;; Ensure hooks are clear for other tests if any error occurred
    (setf elmtui.core.events::*before-send-message-hooks* nil)
    (setf elmtui.core.events::*after-send-message-hooks* nil)))

;;; Run all tests
;;; #-asdf
;;; (run! 'step1-event-message) ; Now handled by elmtui-all-tests:run-all-elmtui-tests
