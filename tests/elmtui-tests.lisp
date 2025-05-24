;;;===============================================================
;;; File: tests/elmtui-tests.lisp
;;; FiveAM Unit Tests for Step 1: Advanced Event & Message Layer

(uiop:define-package :elmtui-tests
  (:use :cl :fiveam :log4cl
   :elmtui.core.events
        :elmtui.state.msg ; For defmsg tests
   :elmtui.core.conditions)
  (:import-from :elmtui.core.events
   #:register-message-contract
   #:validate-message
   #:make-message
   #:message-data
   #:remove-before-send-message-hook
   #:message-type
   #:add-before-send-message-hook
   #:add-after-send-message-hook
   :*message-priorities*
                :*message-contracts*
                #:remove-after-send-message-hook
                )
  (:import-from :elmtui.state.msg
                #:message-variant-p
                #:defmsg)
  (:import-from :elmtui.core.loop
                #:publish
                #:subscribe
                #:unsubscribe)
  (:import-from :elmtui.core.conditions
                #:message-validation-error)
  (:import-from :cl :type-error)
  (:export :run-all-elmtui-tests))


(in-package :elmtui-tests)

(def-suite step1-event-message)
(in-suite step1-event-message)

;;; 1. Message contract registration and enforcement
(test message-contract-validation
  (let ((msg-valid (make-message :foo :ok))
        (msg-invalid (make-message :foo :fail)))
    (register-message-contract :foo (lambda (msg) (equal (message-data msg) :ok)))
    (is (validate-message msg-valid))
    (signals elmtui.core.conditions:message-validation-error
      (validate-message msg-invalid))))

;;; 1.5 Schema-based message validation (using defmsg schemas)
(defmsg schema-validation-msg (:docstring "Message type for schema validation tests")
        NoArgsVariant
        (TypedArgVariant :count integer :label string)
        (OptionalArgVariant ;; &key
         :id t :activep boolean ;; :initform t
         )) ; Assuming defmsg handles &key and initforms for schema

(test schema-based-validation-correct
  ;; Test with a message that conforms to the defmsg schema
  (let ((msg-no-args (make-message 'schema-validation-msg '(:noargsvariant)))
        (msg-typed-args (make-message 'schema-validation-msg '(:typedargvariant :count 123 :label "hello")))
        (msg-optional-args (make-message 'schema-validation-msg '(:optionalargvariant :id "test-id" :activep nil)))
        (msg-optional-default (make-message 'schema-validation-msg '(:optionalargvariant :id "another" :activep nil))))

    ;; Ensure no explicit contract is set for schema-validation-msg for these tests
    (remhash 'schema-validation-msg elmtui.core.events::*message-contracts*)

    (is
     (not (null (validate-message msg-no-args)))
     "Correct NoArgsVariant should pass schema validation.")
    (is (not (null
              (validate-message msg-typed-args)))
        "Correct TypedArgVariant should pass schema validation.")
    (is (not (null
              (validate-message msg-optional-args)))
        "Correct OptionalArgVariant with all args should pass schema validation.")
    (is (not (null
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

    ;; (is
    (signals elmtui.core.conditions:message-validation-error
      (validate-message msg-unknown-variant))
    ;; "Unknown variant should fail schema validation.")
    ;; (is
    (signals elmtui.core.conditions:message-validation-error
      (validate-message msg-wrong-type))
    ;; "Wrong argument type should fail schema validation.")
    ;; (is
    (signals elmtui.core.conditions:message-validation-error
      (validate-message msg-missing-arg))
    ;; "Missing argument should fail schema validation.")
    ;; (is
    (signals elmtui.core.conditions:message-validation-error
      (validate-message msg-extra-arg))
    ;; "Extra argument should fail schema validation (based on current validate-message-via-schema logic).")
    ;; (is
    (signals elmtui.core.conditions:message-validation-error
      (validate-message msg-not-a-list))))
;; "Message data not being a list should fail schema validation.")))

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
  (declare (ignore msg))
  (setf *error-handler-called* t)
  (error "Handler error"))
(test message-dispatch-error
  (let ((msg (make-message :baz 99)))
    (setf *error-handler-called* nil)
    (let ((token (subscribe :baz #'error-handler)))
      (is (signals elmtui.core.conditions:subscriber-handler-error
            (publish msg)))
      (is (not (null *error-handler-called*)))
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

  (is (equalp (make-noargs-test-construct-msg) (list :noargs)))
  ;; Test one-arg variant
  (is (equalp (make-onearg-test-construct-msg :value 123) '(:onearg :value 123)))
  (signals cl:type-error  (make-onearg-test-construct-msg :value "not-an-int"))
  ;; Test multi-arg variant
  (is (equalp (make-multiarg-test-construct-msg :name "Test" :count 5 :active-p t)
              '(:multiarg :name "Test" :count 5 :active-p t)))
  (signals cl:type-error (make-multiarg-test-construct-msg :name "Test" :count "five" :active-p t)))

;;; 7. message-variant-p validation
(test message-variant-p-validation
  (is (message-variant-p 'test-construct-msg '(:noargs)))
  (is (message-variant-p 'test-construct-msg '(:onearg :value 10)))
  (is (message-variant-p 'test-construct-msg '(:multiarg :name "a" :count 1 :active-p nil)))
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
    (let ((original-on-message (fdefinition 'cleve-elm.api:on-message)))
      (setf (fdefinition 'cleve-elm.api:on-message)
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
        (setf (fdefinition 'cleve-elm.api:on-message) original-on-message)))
    ;; Ensure hooks are clear for other tests if any error occurred
    (setf elmtui.core.events::*before-send-message-hooks* nil)
    (setf elmtui.core.events::*after-send-message-hooks* nil)))

;;; Additional coverage: test message contract registration with invalid contract
(test message-contract-invalid-registration
  (signals error
    (register-message-contract :bad (lambda (msg) (error "bad contract")))))

;;; Additional coverage: test subscribe with nil handler
(test subscribe-nil-handler
  (is (null (subscribe :foo nil))))

;;; Additional coverage: test publish with no subscribers
(test publish-no-subscribers
  (is (null (publish (make-message :no-subscribers :data)))))

;;; Run all tests
;;; #-asdf
;;; (run! 'step1-event-message) ; Now handled by elmtui-all-tests:run-all-elmtui-tests
