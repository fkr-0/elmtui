;;;; ELMTUI Test Suite
;;;; This file sets up the main test package and defines basic test infrastructure

(uiop:define-package :elmtui.tests
  (:use :cl :fiveam)
  (:export #:run-tests #:elmtui-test-suite #:run-all-tests))

(in-package :elmtui.tests)

;; Define the main test suite
(def-suite elmtui-test-suite
  :description "Main test suite for elmtui TUI framework")

;; Set this as the default test suite
(in-suite elmtui-test-suite)

;; Basic smoke test to ensure the package loads
(test package-loads
  "Test that the elmtui package loads without errors"
  (is (find-package :elmtui)))

;; Convenience function to run all tests
(defun run-tests ()
  "Run all elmtui tests"
  (run! 'elmtui-test-suite))

;; Also provide this function for ASDF integration
(defun run-all-tests ()
  "Run all elmtui tests (alias for run-tests)"
  (run-tests))
;;   (let ((msg-no-args (make-message 'schema-validation-msg '(:noargsvariant)))
;;         (msg-typed-args (make-message 'schema-validation-msg '(:typedargvariant :count 123 :label "hello")))
;;         (msg-optional-args (make-message 'schema-validation-msg '(:optionalargvariant :id "test-id" :activep nil)))
;;         (msg-optional-default (make-message 'schema-validation-msg '(:optionalargvariant :id "another" :activep nil))))

;;     ;; Ensure no explicit contract is set for schema-validation-msg for these tests
;;     (remhash 'schema-validation-msg elmtui.core.events::*message-contracts*)

;;     (is
;;      (not (null (validate-message msg-no-args)))
;;      "Correct NoArgsVariant should pass schema validation.")
;;     (is (not (null
;;               (validate-message msg-typed-args)))
;;         "Correct TypedArgVariant should pass schema validation.")
;;     (is (not (null
;;               (validate-message msg-optional-args)))
;;         "Correct OptionalArgVariant with all args should pass schema validation.")
;;     (is (not (null
;;               (validate-message msg-optional-default)))
;;         "Correct OptionalArgVariant with default for activep should pass.")))

;; (test schema-based-validation-incorrect
;;   ;; Ensure no explicit contract is set for schema-validation-msg for these tests
;;   (remhash 'schema-validation-msg elmtui.core.events::*message-contracts*)

;;   (let ((msg-unknown-variant (make-message 'schema-validation-msg '(:unknown-variant-for-schema)))
;;         (msg-wrong-type (make-message 'schema-validation-msg '(:typed-arg-variant :count "not-an-int" :label "world")))
;;         (msg-missing-arg (make-message 'schema-validation-msg '(:typed-arg-variant :count 456)))
;;         (msg-extra-arg (make-message 'schema-validation-msg '(:no-args-variant :extra "data")))
;;         (msg-not-a-list (make-message 'schema-validation-msg :no-args-variant))) ; Data is not a list

;;     ;; (is
;;     (signals elmtui.core.conditions:message-validation-error
;;       (validate-message msg-unknown-variant))
;;     ;; "Unknown variant should fail schema validation.")
;;     ;; (is
;;     (signals elmtui.core.conditions:message-validation-error
;;       (validate-message msg-wrong-type))
;;     ;; "Wrong argument type should fail schema validation.")
;;     ;; (is
;;     (signals elmtui.core.conditions:message-validation-error
;;       (validate-message msg-missing-arg))
;;     ;; "Missing argument should fail schema validation.")
;;     ;; (is
;;     (signals elmtui.core.conditions:message-validation-error
;;       (validate-message msg-extra-arg))
;;     ;; "Extra argument should fail schema validation (based on current validate-message-via-schema logic).")
;;     ;; (is
;;     (signals elmtui.core.conditions:message-validation-error
;;       (validate-message msg-not-a-list))))
;; ;; "Message data not being a list should fail schema validation.")))

;; ;;; 2. Message dispatch to handler
;; (defvar *handler-called* nil)
;; (defun test-handler (msg) (setf *handler-called* (message-data msg)))
;; ;; (test message-dispatch
;; ;;   (let ((msg (make-message :bar 42)))
;; ;;     (setf *handler-called* nil)
;; ;;     (let ((token (subscribe :bar #'test-handler)))
;; ;;       (publish msg)
;; ;;       (is (= *handler-called* 42) "Handler should be called after subscribe and publish.")
;; ;;       ;; Clean up
;; ;;       (is (elmtui.core.loop:unsubscribe token) "Unsubscribe should return T for a valid token.")
;; ;;       (setf *handler-called* nil)
;; ;;       (publish msg) ; Publish again
;; ;;       (is (null *handler-called*) "Handler should not be called after unsubscribe."))))

;; ;;; 3. Message dispatch with error and restart
;; (defvar *error-handler-called* nil)
;; (defun error-handler (msg)
;;   (declare (ignore msg))
;;   (setf *error-handler-called* t)
;;   (error "Handler error"))
;; ;; (test message-dispatch-error
;; ;;   (let ((msg (make-message :baz 99)))
;; ;;     (setf *error-handler-called* nil)
;; ;;     (let ((token (subscribe :baz #'error-handler)))
;; ;;       (is (signals elmtui.core.conditions:subscriber-handler-error
;; ;;             (publish msg)))
;; ;;       (is (not (null *error-handler-called*)))
;; ;;       (is (elmtui.core.loop:unsubscribe token) "Unsubscribe should return T for a valid token."))))

;; ;;; 4. Message priorities (stub: correct registration)
;; (test message-priority-registration
;;   (register-message-contract :prio (lambda (msg) t) 42)
;;   (is (= (gethash :prio *message-priorities*) 42)))

;; ;;; 5. Logging/tracing (message log output)
;; (test message-logging
;;   (let ((msg (make-message :logtest :foo)))
;;     (is (stringp (with-output-to-string (s)
;;                    (let ((*standard-output* s))
;;                      (log-message msg :test)))))))

;; ;;; 6. defmsg constructor generation and validation
;; (defmsg test-construct-msg (:docstring "Test message for constructors")
;;         NoArgs
;;         (OneArg :value integer)
;;         (MultiArg :name string :count fixnum :active-p boolean))
;; (test defmsg-constructors

;;   (is (equalp (make-noargs-test-construct-msg) (list :noargs)))
;;   ;; Test one-arg variant
;;   (is (equalp (make-onearg-test-construct-msg :value 123) '(:onearg :value 123)))
;;   (signals cl:type-error  (make-onearg-test-construct-msg :value "not-an-int"))
;;   ;; Test multi-arg variant
;;   (is (equalp (make-multiarg-test-construct-msg :name "Test" :count 5 :active-p t)
;;               '(:multiarg :name "Test" :count 5 :active-p t)))
;;   (signals cl:type-error (make-multiarg-test-construct-msg :name "Test" :count "five" :active-p t)))

;; ;;; 7. message-variant-p validation
;; (test message-variant-p-validation
;;   (is (message-variant-p 'test-construct-msg '(:noargs)))
;;   (is (message-variant-p 'test-construct-msg '(:onearg :value 10)))
;;   (is (message-variant-p 'test-construct-msg '(:multiarg :name "a" :count 1 :active-p nil)))
;;   ;; Check invalid variant keyword
;;   (is (not (message-variant-p 'test-construct-msg '(:unknown-variant))))
;;   ;; Check wrong message type
;;   (is (not (message-variant-p 'another-msg-type '(:no-args))))
;;   ;; Check non-list message instance
;;   (is (not (message-variant-p 'test-construct-msg :no-args)))
;;   ;; Check list not starting with keyword
;;   (is (not (message-variant-p 'test-construct-msg '(no-args)))))

;; ;;; 8. Message Lifecycle Hooks for send-message (Basic Check)
;; (defvar *test-before-send-hook-args* nil)
;; (defvar *test-after-send-hook-args* nil)

;; (defun test-before-send-hook (target msg)
;;   (setf *test-before-send-hook-args* (list target (message-type msg))))

;; (defun test-after-send-hook (target msg successp result)
;;   (declare (ignore result))
;;   (setf *test-after-send-hook-args* (list target (message-type msg) successp)))

;; (test message-send-lifecycle-hooks
;;   (let ((dummy-target (gensym "TARGET-"))
;;         (msg (make-message :hook-test :data)))
;;     ;; Mock on-message for the dummy target to avoid errors if it's not a real clevelib target
;;     (let ((original-on-message (fdefinition 'cleve-elm.api:on-message)))
;;       (setf (fdefinition 'cleve-elm.api:on-message)
;;             (lambda (target message)
;;               (declare (ignore target message))
;;               ;; Simulate some processing result
;;               :processed))
;;       (unwind-protect
;;            (progn
;;              (setf *test-before-send-hook-args* nil)
;;              (setf *test-after-send-hook-args* nil)
;;              (add-before-send-message-hook #'test-before-send-hook)
;;              (add-after-send-message-hook #'test-after-send-hook)

;;              (send-message dummy-target msg)

;;              (is (equal *test-before-send-hook-args* (list dummy-target :hook-test))
;;                  "Before-send hook should be called with correct target and message type.")
;;              (is (equal *test-after-send-hook-args* (list dummy-target :hook-test t))
;;                  "After-send hook should be called with correct target, message type, and success status.")

;;              ;; Test removal
;;              (remove-before-send-message-hook #'test-before-send-hook)
;;              (remove-after-send-message-hook #'test-after-send-hook)
;;              (setf *test-before-send-hook-args* nil)
;;              (setf *test-after-send-hook-args* nil)

;;              (send-message dummy-target (make-message :hook-test-2 :more-data))

;;              (is (null *test-before-send-hook-args*) "Before-send hook should not be called after removal.")
;;              (is (null *test-after-send-hook-args*) "After-send hook should not be called after removal."))
;;         ;; Restore original on-message
;;         (setf (fdefinition 'cleve-elm.api:on-message) original-on-message)))
;;     ;; Ensure hooks are clear for other tests if any error occurred
;;     (setf elmtui.core.events::*before-send-message-hooks* nil)
;;     (setf elmtui.core.events::*after-send-message-hooks* nil)))

;; ;;; Additional coverage: test message contract registration with invalid contract
;; (test message-contract-invalid-registration
;;   (signals error
;;     (register-message-contract :bad (lambda (msg) (error "bad contract")))))

;; ;;; Additional coverage: test subscribe with nil handler
;; (test subscribe-nil-handler
;;   (is (null (subscribe :foo nil))))

;; ;;; Additional coverage: test publish with no subscribers
;; (test publish-no-subscribers
;;   (is (null (publish (make-message :no-subscribers :data)))))

;; ;;; Run all tests
;; ;;; #-asdf
;; ;;; (run! 'step1-event-message) ; Now handled by elmtui-all-tests:run-all-elmtui-tests
;;;===============================================================
;;; File: tests/packages.lisp
;;; Defines a package for running all elmtui tests and ASDF integration.
;;;===============================================================

(uiop:define-package :elmtui-all-tests
  (:use :cl :fiveam)
  (:export #:run-all-elmtui-tests))

(in-package :elmtui-all-tests)

(def-suite elmtui-test-suite)
(in-suite elmtui-test-suite)
(defun run-all-elmtui-tests ()
  "Run all elmtui test suites and print a summary.
Returns T if all tests pass, NIL otherwise."
  ;; (let ((overall-success t)
  ;;       (suites-info '(("STEP1-EVENT-MESSAGE" . "ELMTUI-TESTS")
  ;;                      ("STEP2-LOOP-ASYNC" . "ELMTUI-LOOP-ASYNC-TESTS")
  ;;                      ("STEP3-STATE" . "ELMTUI-STATE-TESTS")
  ;;                      ("CORE-KEYMAP-SUITE" . "ELMTUI-TESTS.ELMTUI-CORE-KEYMAP-TESTS") ; Added keymap suite
  ;;                      ("KEYMAP-FOCUS-EVENT-TESTS" . "ELMTUI-KEYMAP-FOCUS-EVENT-TESTS") ; Added keymap-focus-event chain tests
  ;;                      ("VIEW-TESTS" . "ELMTUI-VIEW-TESTS")
  ;;                      ("WIDGET-TESTS" . "ELMTUI-WIDGET-TESTS")
  ;;                      ("STYLE-LIB-TESTS" . "ELMTUI-STYLE-LIB-TESTS")
  ;;                      ("CANVAS-TESTS" . "ELMTUI.TESTS.CANVAS") ; Added canvas tests
  ;;                      ;; New V2 test suites
  ;;                      ("ELMTUI-TEST-DSL-SUITE" . "ELMTUI-TEST-DSL")
  ;;                      ("ELMTUI-TEST-WIDGETS-LIFECYCLE-SUITE" . "ELMTUI-TEST-WIDGETS-LIFECYCLE")
  ;;                      ("ELMTUI-TEST-APP-LIFECYCLE-SUITE" . "ELMTUI-TEST-APP-LIFECYCLE")
  ;;                      ("ELMTUI-UI-WIDGETS-UTILS-SUITE" . "ELMTUI-UI-WIDGETS-UTILS-TESTS"))))

  ;;   (format t "~&~%Starting elmtui test execution...")

  ;;   (dolist (suite-spec suites-info)
  ;;     (let* ((suite-name-str (car suite-spec))
  ;;            (package-name-str (cdr suite-spec))
  ;;            (package (find-package package-name-str))
  ;;            (suite-sym (when package (find-symbol suite-name-str package))))
  ;;       (if suite-sym
  ;;           (progn
  ;;             (format t "~&~%---> Running suite: ~S (~A::~A)~%" suite-sym package-name-str suite-name-str)
  ;;             (let ((suite-passed (fiveam:run! suite-sym)))
  ;;               (unless suite-passed
  ;;                 (setf overall-success nil))
  ;;               (format t "~&---> Suite ~S finished. Pass: ~A~%" suite-sym suite-passed)))
  ;;           (progn
  ;;             (format t "~&~%[ERROR] Could not find suite ~S in package ~S. Skipping.~%"
  ;;                     suite-name-str package-name-str)
  ;;             (setf overall-success nil))))) ; Mark as failure if a suite is not found

  ;;   (format t "~&~%--- Overall Test Summary ---~%")
  ;;   (fiveam:explain! (fiveam:results-status t)) ; Provides a summary of all tests run.
  ;;   (format t "~&--- End of Test Summary ---~%~%")
  ;;   overall-success)
  )

;;;-----------------------------------------------------------------------------
;;; ASDF test-op integration
;;; This method is called when (asdf:test-system :elmtui-tests) is invoked.
;;;-----------------------------------------------------------------------------
(defmethod asdf:perform ((op asdf:test-op) (system (eql (asdf:find-system "elmtui-tests"))))
  (handler-bind ((error (lambda (e) ; Catch any unexpected errors during the test run
                          (format *error-output* "~&~%[FATAL ERROR] Unhandled error during test-op for ~A:~%  ~A~%Backtrace:~%~A~%"
                                  (asdf:component-name system)
                                  e
                                  (with-output-to-string (s) (uiop:print-backtrace :stream s :count 10 :condition e)))
                          (uiop:quit 1 t)))) ; Force exit with error code
    (format t "~&===> Performing ASDF test-op for system: ~A~%" (asdf:component-name system))
    ;; ASDF should have already loaded the system and its dependencies,
    ;; including all test files specified in elmtui-tests.asd.

    (format t "~&===> Running tests via elmtui-all-tests:run-all-elmtui-tests...~%")
    (let ((success (uiop:symbol-call :elmtui-all-tests '#:run-all-elmtui-tests)))
      (format t "~&===> Test run completed for ~A.~%" (asdf:component-name system))
      (if success
          (progn
            (format t "~&~%[SUCCESS] All elmtui tests passed for system ~A.~%" (asdf:component-name system))
            ;; ASDF test-op should exit 0 on success by default if no uiop:quit is called.
            ;; (uiop:quit 0 t) ; Optionally, be explicit.
            )
          (progn
            (format t "~&~%[FAILURE] Some elmtui tests FAILED for system ~A. See output above for details.~%" (asdf:component-name system))
            (uiop:quit 1 t)))))) ; Crucial: Exit with 1 on failure.
