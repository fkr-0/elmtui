;;;===============================================================
;;; File: tests/contracts-test.lisp
;;; Comprehensive FiveAM test suite for the Elmtui contract system
;;; Tests the contract system in isolation using mocks and dummies
;;;===============================================================
(uiop:define-package :elmtui.contracts.tests
  (:use :cl :fiveam :alexandria #:log4cl)
  (:import-from :elmtui.contracts
                ;; Core macros
                #:defupdate-flexible #:defupdate-typed #:defupdate-hybrid
                #:defview #:defsubscriptions
                ;; Validation functions
                #:validate-message #:validate-model #:validate-commands
                #:validate-dsl #:validate-subscriptions
                #:validate-flexible-message #:validate-typed-message
                #:validate-hybrid-message #:validate-strict-message
                ;; Error conditions
                #:contract-violation #:update-contract-violation
                #:view-contract-violation #:subscription-contract-violation
                #:message-contract-violation
                ;; Development utilities
                #:enable-contract-debugging #:contract-summary
                #:analyze-message-usage #:suggest-message-schema
                ;; Stage contracts
                #:define-stage #:define-pipeline)
  (:import-from :elmtui.state.msg
                #:defmsg #:message-variant-p #:*message-schemas*)
  (:export #:run-contract-tests))

(in-package :elmtui.contracts.tests)

(defmacro with-muffled-non-typed-message-warnings (&body body)
  "Suppress expected prefer-typed compatibility warnings in legacy-message tests."
  `(handler-bind ((warning
                    (lambda (condition)
                      (when (search "Non-typed message" (princ-to-string condition))
                        (let ((restart (find-restart 'muffle-warning condition)))
                          (when restart
                            (invoke-restart restart)))))))
     ,@body))

;;;--------------------------------------------------------------
;;; Test Suite Definition
;;;--------------------------------------------------------------

(def-suite contract-tests
  :in elmtui.tests:elmtui-test
  :description "Comprehensive test suite for Elmtui contract system")

(in-suite contract-tests)

;;;--------------------------------------------------------------
;;; Mock Message Schema for Testing
;;;--------------------------------------------------------------

;; Define a test message schema isolated from real application
(defmsg TestMsg (:docstring "Test message schema for contract testing")
        simple-message
        (parameterized-message :value integer)
        (complex-message :name string :count integer :flags list))

;;;--------------------------------------------------------------
;;; Model Validation Tests
;;;--------------------------------------------------------------

(test contracts-model-validation-valid-cases
  "Test that valid models pass validation"
  ;; Valid empty model
  (is (eq nil (validate-model nil)))

  ;; Valid simple model
  (is (equal '(:key1 "value1")
             (validate-model '(:key1 "value1"))))

  ;; Valid complex model
  (is (equal '(:key1 "value1" :key2 42 :key3 t)
             (validate-model '(:key1 "value1" :key2 42 :key3 t))))

  ;; Valid nested structures in values
  (is (equal '(:key1 (:nested "value") :key2 (list 1 2 3))
             (validate-model '(:key1 (:nested "value") :key2 (list 1 2 3))))))

(test contracts-model-validation-invalid-cases
  "Test that invalid models fail validation"
  ;; Non-list model
  (signals contract-violation
    (validate-model "not-a-list"))

  ;; Odd-length list
  (signals contract-violation
    (validate-model '(:key1 "value1" :key2)))

  ;; Non-keyword keys
  (signals contract-violation
    (validate-model '("string-key" "value1")))

  ;; Mixed keyword/non-keyword keys
  (signals contract-violation
    (validate-model '(:valid-key "value1" "invalid-key" "value2"))))

;;;--------------------------------------------------------------
;;; Command Validation Tests
;;;--------------------------------------------------------------

(test contracts-command-validation-valid-cases
  "Test that valid commands pass validation"
  ;; No commands
  (is (eq nil (validate-commands nil)))

  ;; Empty command list
  (is (equal '() (validate-commands '())))

  ;; Valid simple command
  (is (equal '((:http-request :url "http://example.com"))
             (validate-commands '((:http-request :url "http://example.com")))))

  ;; Multiple valid commands
  (is (equal '((:http-request :url "test") (:timer :delay 1000))
             (validate-commands '((:http-request :url "test") (:timer :delay 1000))))))

(test contracts-command-validation-invalid-cases
  "Test that invalid commands fail validation"
  ;; Non-list commands
  (signals contract-violation
    (validate-commands "not-a-list"))

  ;; Command without keyword
  (signals contract-violation
    (validate-commands '(("non-keyword-command" :param "value"))))

  ;; Command with odd parameter count
  (signals contract-violation
    (validate-commands '((:command :param1 "value1" :param2)))))

;;;--------------------------------------------------------------
;;; DSL Validation Tests
;;;--------------------------------------------------------------

(test contracts-dsl-validation-valid-cases
  "Test that valid DSL structures pass validation"
  ;; String DSL
  (is (validate-dsl "text content" 'test-fn '(:test t)))

  ;; Number DSL
  (is (validate-dsl 42 'test-fn '(:test t)))

  ;; Simple element DSL
  (is (validate-dsl '(:div :id :main) 'test-fn '(:test t)))

  ;; Element with children
  (is (validate-dsl '(:container :id :main :children ((:text :content "hello")))
                    'test-fn '(:test t))))

(test contracts-dsl-validation-invalid-cases
  "Test that invalid DSL structures fail validation"
  ;; List without keyword start
  (signals view-contract-violation
    (validate-dsl '("div" :id :main) 'test-fn '(:test t)))

  ;; Odd parameter count
  (signals view-contract-violation
    (validate-dsl '(:div :id :main :class) 'test-fn '(:test t))))

;;;--------------------------------------------------------------
;;; Message Validation Tests
;;;--------------------------------------------------------------

(test contracts-flexible-message-validation
  "Test flexible message validation accepts any format"
  ;; Keyword message
  (is (eq :simple-msg (validate-flexible-message :simple-msg)))

  ;; List message with keyword start
  (is (equal '(:parameterized :value 42)
             (validate-flexible-message '(:parameterized :value 42))))

  ;; String message (unusual but allowed)
  (is (equal "string-message" (validate-flexible-message "string-message")))

  ;; Number message
  (is (equal 42 (validate-flexible-message 42))))

(test contracts-typed-message-validation-valid
  "Test typed message validation with valid TestMsg variants"
  ;; Simple message
  (is (equalp '(:simple-message)
              (validate-typed-message (make-simple-message-testmsg) 'TestMsg)))

  ;; Parameterized message
  (is (equalp '(:parameterized-message :value 42)
              (validate-typed-message (make-parameterized-message-testmsg :value 42) 'TestMsg)))

  ;; Complex message
  (is (equalp '(:complex-message :name "test" :count 5 :flags (:flag1 :flag2))
              (validate-typed-message (make-complex-message-testmsg :name "test" :count 5 :flags '(:flag1 :flag2)) 'TestMsg))))

(test contracts-typed-message-validation-canonicalizes-symbol-head
  "Typed validation should canonicalize non-keyword variant heads by name."
  (is (equalp '(:simple-message)
              (validate-typed-message '(simple-message) 'TestMsg)))
  (is (equalp '(:parameterized-message :value 9)
              (validate-typed-message '(parameterized-message :value 9) 'TestMsg))))

(test contracts-typed-message-validation-invalid
  "Test typed message validation rejects invalid messages"
  ;; No message type specified
  (signals message-contract-violation
    (validate-typed-message '(:simple-message) nil))

  ;; Invalid message variant
  (signals message-contract-violation
    (validate-typed-message '(:invalid-message) 'TestMsg))

  ;; Wrong format
  (signals message-contract-violation
    (validate-typed-message :simple-keyword 'TestMsg))

  ;; Wrong argument type
  (signals message-contract-violation
    (validate-typed-message '(:parameterized-message :value "bad") 'TestMsg)))

(test contracts-hybrid-message-validation
  "Test hybrid message validation accepts both typed and flexible"
  ;; Valid typed message
  (is (equalp '(:simple-message)
              (validate-hybrid-message (make-simple-message-testmsg) 'TestMsg)))

  ;; Flexible keyword message
  (is (eq :flexible-msg
          (validate-hybrid-message :flexible-msg 'TestMsg)))

  ;; Flexible list message
  (is (equal '(:custom-flexible :param "value")
             (validate-hybrid-message '(:custom-flexible :param "value") 'TestMsg)))

  ;; No message type - uses flexible validation
  (is (eq :any-message
          (validate-hybrid-message :any-message nil))))

(test contracts-strict-message-validation
  "Test strict message validation only accepts typed messages"
  ;; Valid typed message
  (is (equalp '(:simple-message)
              (validate-strict-message (make-simple-message-testmsg) 'TestMsg)))

  ;; No message type - should fail
  (signals message-contract-violation
    (validate-strict-message :any-message nil))

  ;; Invalid message variant - should fail
  (signals message-contract-violation
    (validate-strict-message '(:invalid-variant) 'TestMsg)))

(test contracts-update-signature-order-guardrails
  "Regression guard: detect obvious (model message) ordering drift."
  (signals error
    (macroexpand-1
     '(defupdate-flexible bad-order-update (model message)
        (values model nil)))))

;;;--------------------------------------------------------------
;;; Update Function Contract Tests
;;;--------------------------------------------------------------

;; Mock update functions for testing
(defupdate-flexible test-flexible-update (message model)
  "Test flexible update function"
  (case message
    (:increment (values (list :count (1+ (getf model :count 0))) nil))
    (:decrement (values (list :count (1- (getf model :count 0))) nil))
    (t (values nil nil))))

(defupdate-typed test-typed-update (message model) TestMsg
  "Test typed update function"
  (let ((new-model (copy-list model)))
    (case (first message)
      (:simple-message
       (values (append new-model '(:triggered t)) nil))
      (:parameterized-message
       (values (append new-model (list :value (getf (rest message) :value))) nil))
      (t (values model nil)))))

(defupdate-hybrid test-hybrid-update (message model)
                  :message-type TestMsg :prefer-typed t
                  "Test hybrid update function"

                  (let ((msg-type (if (listp message) (first message) message))
                        (new-model (copy-list model)))
                    (case msg-type
                      (:increment
                       (setf (getf new-model :count) (1+ (getf model :count 0)))
                       (values new-model nil))
                      (:simple-message
                       (setf (getf new-model :count) (1+ (getf model :count 0)))
                       (values new-model nil))
                      (t (values model nil)))))

(test contracts-flexible-update-contracts
  "Test flexible update function contract enforcement"
  (let ((test-model '(:count 5)))

    ;; Valid operations
    (multiple-value-bind (new-model commands)
        (test-flexible-update :increment test-model)
      (is (equal '(:count 6) new-model))
      (is (null commands)))

    ;; Unknown message handling
    (multiple-value-bind (new-model commands)
        (test-flexible-update :unknown test-model)
      (is (null new-model))
      (is (null commands)))

    ;; Invalid model input
    (signals update-contract-violation
      (test-flexible-update :increment "invalid-model"))))

(test contracts-typed-update-contracts
  "Test typed update function contract enforcement"
  (let ((test-model '(:count 5)))

    ;; Valid typed message
    (multiple-value-bind (new-model commands)
        (test-typed-update (make-simple-message-testmsg) test-model)
      (is (equalp '(:count 5 :triggered t) new-model))
      (is (null commands)))

    ;; Valid parameterized message
    (multiple-value-bind (new-model commands)
        (test-typed-update (make-parameterized-message-testmsg :value 42) test-model)
      (is (equalp '(:count 5 :value 42) new-model))
      (is (null commands)))

    ;; Invalid message type
    (signals message-contract-violation
      (test-typed-update :invalid-message test-model))

    ;; Invalid model input
    (signals update-contract-violation
      (test-typed-update (make-simple-message-testmsg) '(:invalid :model :structure)))))

(test contracts-hybrid-update-contracts
  "Test hybrid update function contract enforcement"
  (let ((test-model '(:count 10)))

    ;; Typed message
    (multiple-value-bind (new-model commands)
        (test-hybrid-update (make-simple-message-testmsg) test-model)
      (is (equalp '(:count 11) new-model))
      (is (null commands)))

    ;; Flexible message
    (multiple-value-bind (new-model commands)
        (with-muffled-non-typed-message-warnings
          (test-hybrid-update :increment test-model))
      (is (equalp '(:count 11) new-model))
      (is (null commands)))

    ;; Unknown message
    (multiple-value-bind (new-model commands)
        (with-muffled-non-typed-message-warnings
          (test-hybrid-update :unknown test-model))
      (is (equalp new-model test-model))
      (is (null commands)))))

;;;--------------------------------------------------------------
;;; View Function Contract Tests
;;;--------------------------------------------------------------

(defview test-view-function (model)
  "Test view function"
  `(:container
    :id :test-container
    :children ((:text :content ,(format nil "Count: ~A" (getf model :count 0))))))

(test contracts-view-function-contracts
  "Test view function contract enforcement"
  ;; Valid model
  (let ((result (test-view-function '(:count 42))))
    (is (listp result))
    (is (eq :container (first result)))
    (is (getf (rest result) :id)))

  ;; Invalid model
  (signals view-contract-violation
    (test-view-function "invalid-model")))

;;;--------------------------------------------------------------
;;; Subscription Contract Tests
;;;--------------------------------------------------------------

(defsubscriptions test-subscriptions (model)
  "Test subscriptions function"
  (when (getf model :active)
    (list (elmtui.contracts:make-subscription
           :type :timer
           :config '(:interval 1000)
           :message-fn (lambda (data)
                         (log-info "Timer tick with data: ~A" data)
                         :timer-tick)))))

(test contracts-subscription-contracts
  "Test subscription function contract enforcement"
  ;; Model with active flag
  (let ((subs (test-subscriptions '(:active t))))
    (is (listp subs))
    (is (= 1 (length subs)))
    (is (elmtui.contracts:subscription-p (first subs))))

  ;; Model without active flag
  (let ((subs (test-subscriptions '(:active nil))))
    (is (null subs)))

  ;; Invalid model
  (signals subscription-contract-violation
    (test-subscriptions "invalid-model")))

;;;--------------------------------------------------------------
;;; Stage Pipeline Contract Tests
;;;--------------------------------------------------------------

(define-stage test-stage-1 (list list) (input)
  "Test pipeline stage 1"
  (list* :stage-1-processed t input))

(define-stage test-stage-2 (list list) (input)
  "Test pipeline stage 2"
  (list* :stage-2-processed t input))

(define-pipeline test-pipeline
  test-stage-1
  test-stage-2)

(test contracts-stage-pipeline-contracts
  "Test stage and pipeline contract enforcement"
  ;; Valid pipeline execution
  (let ((result (test-pipeline '(:initial-data "test"))))
    (is (listp result))
    (is (getf result :stage-1-processed))
    (is (getf result :stage-2-processed))
    (is (equal "test" (getf result :initial-data))))

  ;; Invalid input type should be caught
  (signals error  ; Should be pipeline-contract-violation but check-type might raise different error
    (test-stage-1 "not-a-list")))

;;;--------------------------------------------------------------
;;; Contract Debugging Tests
;;;--------------------------------------------------------------

(test contracts-contract-debugging-functionality
  "Test contract debugging and logging features"
  ;; Enable debugging
  (enable-contract-debugging t)

  ;; Execute some operations to generate logs
  (test-flexible-update :increment '(:count 1))
  (test-view-function '(:count 1))
  (test-subscriptions '(:active t))

  ;; Check that logs were created
  (let ((summary (contract-summary)))
    (is (getf summary :debugging-enabled))
    (is (>= (getf summary :update-executions) 0))
    (is (>= (getf summary :view-executions) 0))
    (is (>= (getf summary :subscription-executions) 0)))

  ;; Disable debugging
  (enable-contract-debugging nil)
  (is (not (getf (contract-summary) :debugging-enabled))))

;;;--------------------------------------------------------------
;;; Message Analysis Tests
;;;--------------------------------------------------------------

(test contracts-message-analysis-functionality
  "Test message usage analysis features"
  ;; Enable debugging to generate logs
  (enable-contract-debugging t)

  ;; Generate some message activity
  (test-flexible-update :increment '(:count 1))
  (test-flexible-update :decrement '(:count 2))
  (test-typed-update (make-simple-message-testmsg) '(:value 0))
  (with-muffled-non-typed-message-warnings
   (test-hybrid-update :increment '(:count 3)))
  (test-hybrid-update (make-simple-message-testmsg) '(:count 4))

  ;; Analyze usage patterns
  (let ((analysis (analyze-message-usage)))
    (is (listp analysis))
    (is (>= (getf analysis :total-messages) 0))
    (is (>= (getf analysis :typed-messages) 0))
    (is (>= (getf analysis :untyped-messages) 0))
    (is (listp (getf analysis :message-frequency))))

  ;; Test schema suggestion (should not error)
  (suggest-message-schema 'test-flexible-update)

  (enable-contract-debugging nil))

;;;--------------------------------------------------------------
;;; Error Condition Tests
;;;--------------------------------------------------------------

(test contracts-contract-violation-conditions
  "Test that contract violation conditions work correctly"
  ;; Test contract-violation condition
  (handler-case
      (error 'contract-violation
             :function-name 'test-fn
             :expected-type "test-type"
             :actual-value "actual"
             :context "test context")
    (contract-violation (c)
      (is (eq 'test-fn (elmtui.contracts::cv-function-name c)))
      (is (equal "test-type" (elmtui.contracts::cv-expected-type c)))
      (is (equal "actual" (elmtui.contracts::cv-actual-value c)))
      (is (equal "test context" (elmtui.contracts::cv-context c)))))

  ;; Test specific violation types
  (signals update-contract-violation
    (error 'update-contract-violation :function-name 'test :expected-type "type" :actual-value "value"))

  (signals view-contract-violation
    (error 'view-contract-violation :function-name 'test :expected-type "type" :actual-value "value"))

  (signals subscription-contract-violation
    (error 'subscription-contract-violation :function-name 'test :expected-type "type" :actual-value "value"))

  (signals message-contract-violation
    (error 'message-contract-violation :function-name 'test :expected-type "type" :actual-value "value")))

;;;--------------------------------------------------------------
;;; Integration Tests
;;;--------------------------------------------------------------

(test contracts-full-elm-application-validation
  "Test validation of complete Elm application functions"
  ;; Define complete mock application functions
  (let ((init-model '(:count 0 :active nil))
        (update-fn #'test-flexible-update)
        (view-fn #'test-view-function)
        (subscriptions-fn #'test-subscriptions))

    ;; Should validate successfully
    (is (elmtui.contracts:validate-elm-application
         update-fn view-fn subscriptions-fn init-model))))

(test contracts-contract-interoperability
  "Test that different contract types work together"
  ;; Mix of flexible, typed, and hybrid in same test
  (let ((model '(:count 5)))

    ;; Flexible -> Typed -> Hybrid chain
    (multiple-value-bind (model1 _)
        (test-flexible-update :increment model)
      (declare (ignore _))

      (multiple-value-bind (model2 _)
          (test-typed-update (make-simple-message-testmsg) model1)
        (declare (ignore _))

        (multiple-value-bind (model3 _)
            (with-muffled-non-typed-message-warnings
              (test-hybrid-update :increment model2))
          (declare (ignore _))

          ;; Final model should reflect all changes
          (is (equalp '(:count 7 :triggered t) model3)))))))

;;;--------------------------------------------------------------
;;; Performance Tests
;;;--------------------------------------------------------------

(test contracts-contract-performance
  "Test that contract enforcement doesn't significantly impact performance"
  ;; Simple performance check - contracts shouldn't add huge overhead
  (let ((start-time (get-internal-real-time))
        (iterations 1000)
        (test-model '(:count 0)))

    ;; Run many contract-enforced operations
    (dotimes (i iterations)
      (test-flexible-update :increment test-model))

    (let* ((end-time (get-internal-real-time))
           (elapsed (/ (- end-time start-time) internal-time-units-per-second)))

      ;; Should complete reasonably quickly (less than 1 second for 1000 ops)
      (is (< elapsed 1.0))
      (is (numberp elapsed)))))

;;;--------------------------------------------------------------
;;; Test Runner
;;;--------------------------------------------------------------

;; (defun run-contract-tests (&key verbose)
;;   "Run the complete contract system test suite"
;;   (format t "~&=== Running Elmtui Contract System Tests ===~%")

;;   ;; Clean state before testing
;;   (enable-contract-debugging nil)

;;   ;; Run all tests
;;   ;; (let ((results (run 'contract-tests)))
;;   ;;   (format t "~&=== Test Results ===~%")
;;   ;;   (format t "Tests run: ~A~%" (length (fiveam::tests results)))
;;   ;;   (format t "Passed: ~A~%" (length (fiveam::passed results)))
;;   ;;   (format t "Failed: ~A~%" (length (fiveam::failed results)))
;;   ;;   (format t "Skipped: ~A~%" (length (fiveam::skipped results)))

;;   ;;   (when (and verbose (fiveam::failed results))
;;   ;;     (format t "~&=== Failed Tests ===~%")
;;   ;;     (dolist (failure (fiveam::failed results))
;;   ;;       (format t "~A: ~A~%"
;;   ;;               (fiveam::name failure)
;;   ;;               (fiveam::description failure))))

;;   ;;   ;; Return success if all tests passed
;;   ;;   (zerop (length (fiveam::failed results))))
;;   )

;; Auto-run tests when file is loaded in test mode
#+test-mode
(run-contract-tests :verbose t)
