;;;; STATE Module Extended Tests
;;;; Test suite for elmtui state management beyond API

(uiop:define-package :elmtui.state.extended-tests
  (:use :cl :fiveam :elmtui.state.api :elmtui.state.model :elmtui.state.schema)
  (:export #:run-state-extended-tests))

(in-package :elmtui.state.extended-tests)

(def-suite state-extended-test-suite
  :description "Test suite for elmtui state management (extended)")

(in-suite state-extended-test-suite)

;; Test for state model
(test state-model-basic
  "Test state model functionality"
  (when (fboundp 'elmtui.state.model:make-model)
    (let ((model (elmtui.state.model:make-model)))
      (is (not (null model))
          "State model should be created")
      (when model
        ;; Set initial state if function exists
        (when (fboundp 'elmtui.state.model:set-model-state)
          (elmtui.state.model:set-model-state model :counter 0)
          (elmtui.state.model:set-model-state model :name "test"))
          
          ;; Get state if function exists
          (when (fboundp 'elmtui.state.model:get-model-state)
            (is (= (elmtui.state.model:get-model-state model :counter) 0)
                "Counter should be 0")
            (is (string= (elmtui.state.model:get-model-state model :name) "test")
                "Name should be 'test'"))))
        
        ;; Update state if function exists
        (when (and (fboundp 'elmtui.state.model:increment-model)
                   (fboundp 'elmtui.state.model:get-model-state))
          (elmtui.state.model:increment-model model :counter)
          (is (= (elmtui.state.model:get-model-state model :counter) 1)
              "Counter should be incremented")))))))

(test state-model-validation
  "Test state model validation"
  (when (fboundp 'elmtui.state.model:make-model)
    (let ((model (elmtui.state.model:make-model))
          (validated nil)
          (errors nil))
      (is (not (null model))
          "State model should be created")
      (when model
        ;; Add validator if function exists
        (when (fboundp 'elmtui.state.model:add-validator)
          (elmtui.state.model:add-validator model :counter
                                           (lambda (value) 
                                             (and (numberp value) 
                                                  (>= value 0)))))
        
        ;; Set valid state if function exists
        (when (fboundp 'elmtui.state.model:set-model-state)
          (setf validated (elmtui.state.model:set-model-state model :counter 5))
          (is validated
              "Valid state should be accepted")))
        
        ;; Try to set invalid state if functions exist
        (when (fboundp 'elmtui.state.model:get-validation-errors)
          (setf errors (elmtui.state.model:get-validation-errors model)))
        (when (fboundp 'elmtui.state.model:set-model-state)
          (elmtui.state.model:set-model-state model :counter -1))
        (when (fboundp 'elmtui.state.model:get-validation-errors)
          (setf errors (elmtui.state.model:get-validation-errors model)))
        (is (> (length errors) 0)
            "Invalid state should produce errors")))))))

;; Test for state schema
(test state-schema-basic
  "Test state schema functionality"
  (when (fboundp 'elmtui.state.schema:make-schema)
    (let ((schema (elmtui.state.schema:make-schema)))
      (is (not (null schema))
          "Schema should be created")
      (when schema
        ;; Define schema if function exists
        (when (fboundp 'elmtui.state.schema:define-field)
          (elmtui.state.schema:define-field schema :counter :type :number :default 0)
          (elmtui.state.schema:define-field schema :name :type :string :required t)
          (elmtui.state.schema:define-field schema :active :type :boolean :default nil))
          
          ;; Validate against schema if function exists
          (when (fboundp 'elmtui.state.schema:validate-data)
            (let ((valid-data '(:counter 10 :name "test" :active t))
                  (invalid-data '(:counter "not-a-number" :name nil)))
              (is (elmtui.state.schema:validate-data schema valid-data)
                  "Valid data should pass schema validation")
              (is (not (elmtui.state.schema:validate-data schema invalid-data))
                  "Invalid data should fail schema validation"))
            
            ;; Generate default state if function exists
            (when (fboundp 'elmtui.state.schema:generate-default)
              (let ((default-state (elmtui.state.schema:generate-default schema)))
                (is (= (getf default-state :counter) 0)
                    "Default counter should be 0")
                (is (null (getf default-state :name))
                    "Required field should be nil in defaults")
                (is (null (getf default-state :active))
                    "Default active should be nil")))))))))))

;; Test for state transactions
(test state-transaction-basic
  "Test state transaction functionality"
  (when (and (fboundp 'elmtui.state.api:make-state)
             (fboundp 'elmtui.state.api:begin-transaction)
             (fboundp 'elmtui.state.api:commit-transaction))
    (let ((state (elmtui.state.api:make-state))
          (transaction nil))
      (is (not (null state))
          "State should be created")
      (when state
        ;; Initialize state if function exists
        (when (fboundp 'elmtui.state.api:set-state)
          (elmtui.state.api:set-state state :counter 0 :name "test"))
          
          ;; Start transaction if function exists
          (setf transaction (elmtui.state.api:begin-transaction state))
          (is (not (null transaction))
              "Transaction should be created")
          
          ;; Perform operations in transaction if functions exist
          (when (and (fboundp 'elmtui.state.api:tx-set)
                     (fboundp 'elmtui.state.api:get-state))
            (elmtui.state.api:tx-set transaction :counter 5)
            (elmtui.state.api:tx-set transaction :name "updated")
            
            ;; Verify changes aren't committed yet
            (is (= (elmtui.state.api:get-state state :counter) 0)
                "Original state unchanged before commit"))
            
            ;; Commit transaction
            (elmtui.state.api:commit-transaction transaction)
            
            ;; Verify changes are committed
            (is (= (elmtui.state.api:get-state state :counter) 5)
                "State should be updated after commit")
            (is (string= (elmtui.state.api:get-state state :name) "updated")
                "State should be updated after commit")))))))))

(test state-transaction-rollback
  "Test state transaction rollback"
  (when (and (fboundp 'elmtui.state.api:make-state)
             (fboundp 'elmtui.state.api:begin-transaction)
             (fboundp 'elmtui.state.api:rollback-transaction))
    (let ((state (elmtui.state.api:make-state))
          (transaction nil))
      (is (not (null state))
          "State should be created")
      (when state
        ;; Initialize state if function exists
        (when (fboundp 'elmtui.state.api:set-state)
          (elmtui.state.api:set-state state :counter 10 :name "original")
          
          ;; Start transaction if function exists
          (setf transaction (elmtui.state.api:begin-transaction state))
          (is (not (null transaction))
              "Transaction should be created")
          
          ;; Perform operations if function exists
          (when (fboundp 'elmtui.state.api:tx-set)
            (elmtui.state.api:tx-set transaction :counter 20)
            (elmtui.state.api:tx-set transaction :name "modified"))
          
          ;; Rollback transaction
          (elmtui.state.api:rollback-transaction transaction)
          
          ;; Verify original state is preserved if function exists
          (when (fboundp 'elmtui.state.api:get-state)
            (is (= (elmtui.state.api:get-state state :counter) 10)
                "Original counter should be preserved")
            (is (string= (elmtui.state.api:get-state state :name) "original")
                "Original name should be preserved"))))))))

;; Test for state update
(test state-update-basic
  "Test state update functionality"
  (when (and (fboundp 'elmtui.state.api:make-state)
             (fboundp 'elmtui.state.api:set-state)
             (fboundp 'elmtui.state.api:apply-update)
             (fboundp 'elmtui.state.api:get-state))
    (let ((state (elmtui.state.api:make-state)))
      (is (not (null state))
          "State should be created")
      (when state
        ;; Initialize state
        (elmtui.state.api:set-state state :counter 0)
        
        ;; Define update function if function exists
        (when (fboundp 'elmtui.state.api:make-update-fn)
          (let ((update-fn (elmtui.state.api:make-update-fn 
                            (lambda (s action)
                              (ecase (getf action :type)
                                (:increment 
                                 (list :counter (+ (getf s :counter) 1)))
                                (:set-value
                                 (setf (getf s :counter) 
                                       (getf action :value)))))))))
            (is (not (null update-fn))
                "Update function should be created")
            
            ;; Apply updates
            (elmtui.state.api:apply-update state update-fn '(:type :increment))
            (is (= (elmtui.state.api:get-state state :counter) 1)
                "Counter should be incremented")
            
            (elmtui.state.api:apply-update state update-fn 
                                            '(:type :set-value :value 10))
            (is (= (elmtui.state.api:get-state state :counter) 10)
                "Counter should be set to specified value"))))))))

;; Test for state utils
(test state-utils-basic
  "Test state utility functions"
  (when (and (fboundp 'elmtui.state.api:make-state)
             (fboundp 'elmtui.state.api:set-state)
             (fboundp 'elmtui.state.api:get-state))
    (let ((state (elmtui.state.api:make-state)))
      (is (not (null state))
          "State should be created")
      (when state
        ;; Initialize complex state
        (elmtui.state.api:set-state state 
                                     :counter 0 
                                     :name "test"
                                     :nested '(:inner "value" :count 5))
        
        ;; Test path access if function exists
        (when (fboundp 'elmtui.state.api:get-state-path)
          (is (= (elmtui.state.api:get-state-path state '(:counter)) 0)
              "Simple path should work")
          (is (string= (elmtui.state.api:get-state-path state '(:name)) "test")
              "String path should work")
          (is (string= (elmtui.state.api:get-state-path state '(:nested :inner)) "value")
              "Nested path should work")
          (is (= (elmtui.state.api:get-state-path state '(:nested :count)) 5)
              "Nested number path should work"))
        
        ;; Test path setting if function exists
        (when (and (fboundp 'elmtui.state.api:set-state-path)
                   (fboundp 'elmtui.state.api:get-state-path))
          (elmtui.state.api:set-state-path state '(:counter) 10)
          (is (= (elmtui.state.api:get-state-path state '(:counter)) 10)
              "Simple path setting should work")
          
          (elmtui.state.api:set-state-path state '(:nested :inner) "new-value")
          (is (string= (elmtui.state.api:get-state-path state '(:nested :inner)) "new-value")
              "Nested path setting should work"))
        
        ;; Test deep merge if function exists
        (when (and (fboundp 'elmtui.state.api:merge-state)
                   (fboundp 'elmtui.state.api:get-state-path))
          (let ((new-data '(:name "updated" :nested '(:inner "merged" :new-prop 123))))
            (elmtui.state.api:merge-state state new-data)
            
            (is (string= (elmtui.state.api:get-state-path state '(:name)) "updated")
                "Name should be updated")
            (is (string= (elmtui.state.api:get-state-path state '(:nested :inner)) "merged")
                "Nested value should be updated")
            (is (= (elmtui.state.api:get-state-path state '(:nested :count)) 5)
                "Nested unchanged value should be preserved")
            (is (= (elmtui.state.api:get-state-path state '(:nested :new-prop)) 123)
                "New nested property should be added")))))))))

(test state-validation-extended
  "Test extended state validation"
  (when (and (fboundp 'elmtui.state.api:make-state)
             (fboundp 'elmtui.state.api:set-state)
             (fboundp 'elmtui.state.api:get-state))
    (let ((state (elmtui.state.api:make-state))
          (validator nil))
      (is (not (null state))
          "State should be created")
      (when state
        ;; Initialize state
        (elmtui.state.api:set-state state :email "test@example.com" :age 25)
        
        ;; Create validator if function exists
        (when (fboundp 'elmtui.state.api:make-validator)
          (setf validator 
                (elmtui.state.api:make-validator 
                 :email (lambda (email) 
                          (and (stringp email) 
                               (ppcre:scan "^.+@.+\\..+$" email)))
                 :age (lambda (age) 
                        (and (numberp age) 
                             (>= age 0) 
                             (<= age 150))))))
        
        ;; Validate state if function exists
        (when validator
          (when (fboundp 'elmtui.state.api:validate-state)
            (let ((results (elmtui.state.api:validate-state state validator)))
              (is (elmtui.state.api:validation-success-p results)
                  "Valid state should pass validation")
              
              ;; Test invalid state
              (elmtui.state.api:set-state state :email "invalid-email")
              (setf results (elmtui.state.api:validate-state state validator))
              (is (not (elmtui.state.api:validation-success-p results))
                  "Invalid state should fail validation")
              
              ;; Check error details if functions exist
              (when (fboundp 'elmtui.state.api:get-validation-errors)
                (let ((errors (elmtui.state.api:get-validation-errors results)))
                  (is (> (length errors) 0)
                      "Should have validation errors")
                  (is (find "email" errors :key (lambda (e) 
                                                      (elmtui.state.api:validation-error-field e)))
                          :test #'string=)
                      "Should have email field error")))))))))))

(defun run-state-extended-tests ()
  "Run all extended state module tests"
  (run! 'state-extended-test-suite))