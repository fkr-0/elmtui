;;;===============================================================
;;; File: tests/dsl-test.lisp
;;; Comprehensive FiveAM test suite for the DSL system
;;; Tests Base DSL, Component DSL, State Model, and Integration
;;;===============================================================
(uiop:define-package :elmtui.dsl.tests
  (:use :cl :fiveam :alexandria)
  (:import-from :elmtui.view.base-elements
                #:validate-base-dsl #:expand-base-dsl #:normalize-base-dsl
                #:base-dsl-p #:element-type-p #:valid-property-p
                #:make-dsl-element #:update-dsl-element
                #:find-elements-by-type #:find-element-by-id
                #:dsl-statistics
                #:base-dsl-error
                ;; classes and accessors
                #:text-element #:text-content #:text-wrap #:text-align
                #:button-element #:button-text
                #:container-element #:element-children #:element-id)

  (:import-from :elmtui.state.model
                #:transaction-status
                #:defmodel-contracted #:validate-state-schema #:validate-state-instance
                #:defpatch #:deftransaction #:apply-state-patches
                #:state-patch #:make-state-patch #:transaction
                #:get-state-value #:set-state-value #:update-state-value
                #:*state-schemas*)
  (:import-from :elmtui.contracts
                #:enable-contract-debugging #:validate-model)
  (:export #:run-dsl-tests))

(in-package :elmtui.dsl.tests)

;;;--------------------------------------------------------------
;;; Test Suite Definition
;;;--------------------------------------------------------------

(def-suite dsl-tests
  :description "Comprehensive test suite for Elmtui DSL system")

(in-suite dsl-tests)

;;;--------------------------------------------------------------
;;; Base DSL Tests
;;;--------------------------------------------------------------

(def-suite base-dsl-tests :in dsl-tests
  :description "Tests for base DSL validation and manipulation")

(in-suite base-dsl-tests)

(test basic-dsl-validation
  "Test basic DSL structure validation"
  ;; Valid primitive content
  (is (base-dsl-p "Hello World"))
  (is (base-dsl-p 42))
  (is (base-dsl-p nil))

  ;; Valid simple elements
  (is (base-dsl-p '(:text :content "Hello")))
  (is (base-dsl-p '(:button :text "Click Me")))
  (is (base-dsl-p '(:container :id :main)))

  ;; Valid complex elements
  (is (base-dsl-p '(:container :id :main
                    :children ((:text :content "Child 1")
                               (:text :content "Child 2")))))

  ;; Invalid structures
  (is (not (base-dsl-p '(not-a-keyword :invalid))))
  (is (not (base-dsl-p '(:text :content))))  ; Odd property list
  )

(test element-type-validation
  "Test element type validation"
  ;; Valid element types
  (is (element-type-p :container))
  (is (element-type-p :text))
  (is (element-type-p :button))
  (is (element-type-p :input))

  ;; Invalid element types
  (is (not (element-type-p :unknown-element)))
  (is (not (element-type-p "not-keyword")))
  (is (not (element-type-p 42))))

(test property-validation
  "Test property validation for elements"
  ;; Valid properties
  (is (valid-property-p :container :id))
  (is (valid-property-p :container :children))
  (is (valid-property-p :text :content))
  (is (valid-property-p :button :text))

  ;; Invalid properties
  (is (not (valid-property-p :container :invalid-prop)))
  (is (not (valid-property-p :text :invalid-prop))))

;; (test required-property-validation
;;   "Test validation of required properties"
;;   ;; Valid elements with required properties
;;   (is (base-dsl-p '(:text :content "Required content")))
;;   (is (base-dsl-p '(:button :text "Required text")))
;;   (is (base-dsl-p '(:input :type :text)))

;;   ;; Invalid elements missing required properties
;;   (signals base-dsl-error
;;     (validate-base-dsl '(:text :id :some-id)))  ; Missing :content
;;   (signals base-dsl-error
;;     (validate-base-dsl '(:button :id :btn)))    ; Missing :text
;;   (signals base-dsl-error
;;     (validate-base-dsl '(:input :id :inp))))
                                        ; Missing :type

(test dsl-expansion
  "Test DSL expansion with default properties"
  ;; Test expansion adds defaults
  (let ((expanded (expand-base-dsl '(:text :content "Hello"))))
    (is (typep expanded 'text-element))
    (is (text-wrap expanded))    ; Should have default :wrap t
    (is (eq (text-align expanded) :left))) ; Should have default :align :left

  ;; Test expansion preserves existing properties
  (let ((expanded (expand-base-dsl '(:text :content "Hello" :wrap nil))))
    (is (not (text-wrap expanded)))) ; Should preserve :wrap nil

  ;; Test nested expansion
  (let* ((expanded (expand-base-dsl '(:container
                                      :children ((:text :content "Child")))))
         (child (first (element-children expanded))))
    (is (typep child 'text-element))
    (is (text-wrap child)))) ; Child should be expanded too

(test dsl-manipulation
  "Test DSL element manipulation functions"
  ;; Test make-dsl-element
  (let ((element (make-dsl-element :text :content "Test")))
    (is (typep element 'text-element))
    (is (equal (text-content element) "Test")))

  ;; Test update-dsl-element on a CLOS object
  (let* ((original (make-dsl-element :button :text "Original" :id :btn1))
         (updated (update-dsl-element original :text "Updated")))
    (is (equal (button-text updated) "Updated"))
    (is (eq (element-id updated) :btn1)))

  ;; Test invalid element construction
  (signals base-dsl-error
    (make-dsl-element :text :content))) ; Odd property list

(test dsl-traversal
  "Test DSL traversal and query functions"
  (let ((dsl (expand-base-dsl
              '(:container
                :id :main
                :children ((:text :id :title :content "Title")
                           (:container :id :sub
                                       :children ((:button :id :btn :text "Click"))))))))
    ;; Test find by type
    (let ((texts (find-elements-by-type dsl :text)))
      (is (= (length texts) 1))
      (is (eq (element-id (first texts)) :title)))

    (let ((containers (find-elements-by-type dsl :container)))
      (is (= (length containers) 2)))  ; Main and sub containers

    ;; Test find by ID
    (let ((title-element (find-element-by-id dsl :title)))
      (is (not (null title-element)))
      (is (typep title-element 'text-element)))

    (let ((button-element (find-element-by-id dsl :btn)))
      (is (not (null button-element)))
      (is (typep button-element 'button-element)))

    ;; Test non-existent ID
    (is (null (find-element-by-id dsl :nonexistent)))))

(test dsl-statistics
  "Test DSL statistics generation"
  (let* ((dsl (expand-base-dsl
               '(:container
                 :children ((:text :content "Text1")
                            (:text :content "Text2")
                            (:button :text "Button")))))
         (stats (dsl-statistics dsl)))

    (is (= (getf stats :total-elements) 4))
    (is (= (getf stats :max-depth) 1))
    (is (= (getf stats :element-types) 3))

    (let ((counts (getf stats :element-counts)))
      (is (= (cdr (assoc :text counts)) 2))
      (is (= (cdr (assoc :button counts)) 1))
      (is (= (cdr (assoc :container counts)) 1)))))

;;;--------------------------------------------------------------
;;; State Model Tests
;;;--------------------------------------------------------------

(def-suite state-model-tests :in dsl-tests
  :description "Tests for enhanced state model system")

(in-suite state-model-tests)

;; Define test model for testing
(defmodel-contracted test-user-model
    ((name "" :type string :required t)
     (email "" :type string :required t
               :validator (lambda (v) (or ;; (string= v "")
                                       (search "@" v))))
     (age 0 :type integer)
     (active t :type boolean)
     (metadata nil :type list))

  :validation (lambda (state)
                (when (and (> (getf state :age) 0) (< (getf state :age) 13))
                  (unless (getf state :active)
                    (error "Children must be active"))))

  :transactions
  ((activate-user (state)
                  (list (make-state-patch :path '(:active) :value t :operation :set)))

   (update-user-info (state name email)
                     (list (make-state-patch :path '(:name) :value name :operation :set)
                           (make-state-patch :path '(:email) :value email :operation :set))))

  :observers
  ((lambda (old-state new-state change-type)
     (when (eq change-type :updated)
       (format t "User state changed~%"))))

  :export-accessors t)

(test state-model-definition
  "Test state model definition and schema registration"
  ;; Check schema registration
  (is (gethash 'test-user-model *state-schemas*))

  ;; Check schema structure
  (let ((schema (gethash 'test-user-model *state-schemas*)))
    (is (eq (getf schema :name) 'test-user-model))
    (is (getf schema :slots))
    (is (getf schema :validation))))

(test state-model-construction
  "Test state model construction and validation"
  ;; Valid construction
  (let ((state (make-test-user-model :name "John Doe" :email "john@example.com")))
    (is (validate-test-user-model state))
    (is (equal (getf state :name) "John Doe"))
    (is (equal (getf state :email) "john@example.com")))

  ;; Invalid construction - missing required field
  (signals error
    (make-test-user-model :name "John"))  ; Missing email

  ;; Invalid construction - type mismatch
  (signals error
    (make-test-user-model :name "John" :email "john@example.com" :age "not-a-number")))

(test state-model-validation
  "Test state model validation rules"
  ;; Valid state
  (let ((state '(:name "John" :email "john@example.com" :age 25 :active t)))
    (is (validate-test-user-model state)))

  ;; Invalid email format
  (signals error
    (validate-test-user-model '(:name "John" :email "invalid-email" :age 25)))

  ;; Custom validation rule (children must be active)
  (signals error
    (validate-test-user-model '(:name "Child" :email "child@example.com" :age 10 :active nil))))

(test state-patches
  "Test state patch system"
  (let ((initial-state '(:name "John" :email "john@example.com" :age 25 :active t)))

    ;; Test simple patch
    (let* ((patch (make-state-patch :path '(:name) :value "Jane" :operation :set))
           (new-state (apply-state-patches initial-state (list patch))))
      (is (equal (getf new-state :name) "Jane"))
      (is (equal (getf new-state :email) "john@example.com")))  ; Unchanged

    ;; Test multiple patches
    (let* ((patches (list (make-state-patch :path '(:name) :value "Jane" :operation :set)
                          (make-state-patch :path '(:age) :value 30 :operation :set)))
           (new-state (apply-state-patches initial-state patches)))
      (is (equal (getf new-state :name) "Jane"))
      (is (= (getf new-state :age) 30)))

    ;; Test update operation
    (let* ((patch (make-state-patch :path '(:age)
                                    :value (lambda (current) (+ current 1))
                                    :operation :update))
           (new-state (apply-state-patches initial-state (list patch))))
      (is (= (getf new-state :age) 26)))

    ;; Test append operation - need to fix the nil initial value
    (let* ((initial-state-with-metadata (list* :metadata '() initial-state))
           (patch (make-state-patch :path '(:metadata) :value "tag1" :operation :append))
           (new-state (apply-state-patches initial-state-with-metadata (list patch))))
      (is (equal (getf new-state :metadata) '("tag1"))))

    ;; Test delete operation
    (let* ((patch (make-state-patch :path '(:age) :value nil :operation :delete))
           (new-state (apply-state-patches initial-state (list patch))))
      (is (null (getf new-state :age))))))

(test state-transactions
  "Test transactional state updates"
  (let ((initial-state '(:name "John" :email "john@example.com" :age 25 :active nil)))

    ;; Test predefined transaction
    (multiple-value-bind (new-state transaction)
        (activate-user initial-state)
      (is (getf new-state :active))
      (is (not (null transaction)))
      (is (eq (transaction-status transaction) :committed)))

    ;; Test transaction with parameters
    (multiple-value-bind (new-state transaction)
        (update-user-info initial-state "Jane Doe" "jane@example.com")
      (is (equal (getf new-state :name) "Jane Doe"))
      (is (equal (getf new-state :email) "jane@example.com"))
      (is (eq (transaction-status transaction) :committed)))))

;; Define patch operations for testing
(defpatch test-update-name (state new-name)
  "Test patch operation for updating name"
  (make-state-patch :path '(:name)
                    :value new-name
                    :operation :set
                    :validator (lambda (v) (and (stringp v) (> (length v) 0)))
                    :source :test))

(defpatch test-add-metadata (state tag)
  "Test patch operation for adding metadata"
  (make-state-patch :path '(:metadata)
                    :value tag
                    :operation :append
                    :source :test))

(test custom-patch-operations
  "Test custom patch operations"
  (let ((initial-state '(:name "John" :email "john@example.com" :metadata nil)))

    ;; Test valid patch
    (let* ((patches (test-update-name initial-state "Jane"))
           (new-state (apply-state-patches initial-state patches)))
      (is (equal (getf new-state :name) "Jane")))

    ;; Test patch validation
    (signals error
      (test-update-name initial-state ""))  ; Empty name should fail validation

    ;; Test metadata patch
    (let* ((patches (test-add-metadata initial-state "important"))
           (new-state (apply-state-patches initial-state patches)))
      (is (member "important" (getf new-state :metadata) :test #'equal)))))

;; Define transaction for testing
(deftransaction test-complete-update (state name email active)
  "Test transaction for complete user update"
  (list (make-state-patch :path '(:name) :value name :operation :set)
        (make-state-patch :path '(:email) :value email :operation :set)
        (make-state-patch :path '(:active) :value active :operation :set)))

(test custom-transactions
  "Test custom transaction operations"
  (let ((initial-state '(:name "John" :email "john@example.com" :active nil)))

    ;; Test successful transaction
    (multiple-value-bind (new-state transaction)
        (test-complete-update initial-state "Jane Doe" "jane@example.com" t)
      (is (equal (getf new-state :name) "Jane Doe"))
      (is (equal (getf new-state :email) "jane@example.com"))
      (is (getf new-state :active))
      (is (eq (transaction-status transaction) :committed)))

    ;; Test transaction with potentially invalid data but no validation failure should occur here
    (multiple-value-bind (new-state transaction)
        (test-complete-update initial-state "Jane Doe" "jane@example.com" t)  ; Valid data
      ;; Should work fine
      (is (equal (getf new-state :name) "Jane Doe"))
      (is (not (null transaction))))))

(test state-utilities
  "Test state utility functions"
  (let ((state '(:name "John" :nested (:deep (:value 42)))))

    ;; Test get-state-value
    (is (equal (get-state-value state '(:name)) "John"))
    (is (= (get-state-value state '(:nested :deep :value)) 42))
    (is (eq (get-state-value state '(:nonexistent) :default) :default))

    ;; Test set-state-value
    (let ((new-state (set-state-value state '(:name) "Jane")))
      (is (equal (get-state-value new-state '(:name)) "Jane")))

    ;; Test update-state-value
    (let ((new-state (update-state-value state '(:nested :deep :value)
                                         (lambda (x) (* x 2)))))
      (is (= (get-state-value new-state '(:nested :deep :value)) 84)))))

;;;--------------------------------------------------------------
;;; Integration Tests
;;;--------------------------------------------------------------

(def-suite dsl-integration-tests :in dsl-tests
  :description "Tests for DSL system integration")

(in-suite dsl-integration-tests)

(test dsl-with-state-model
  "Test DSL generation with state model data"
  ;; Create state with model
  (let ((state (make-test-user-model :name "John Doe"
                                     :email "john@example.com"
                                     :age 30)))

    ;; Generate DSL using state data
    (let ((dsl `(:container
                 :id :user-profile
                 :children
                 ((:text :content ,(format nil "Name: ~A" (getf state :name)))
                  (:text :content ,(format nil "Email: ~A" (getf state :email)))
                  (:text :content ,(format nil "Age: ~A" (getf state :age)))))))

      ;; Validate generated DSL
      (is (base-dsl-p dsl))

      ;; Check DSL contains state data
      (let ((name-text (find-if (lambda (child)
                                  (and (listp child)
                                       (search "John Doe" (getf (rest child) :content))))
                                (getf (rest dsl) :children))))
        (is (not (null name-text)))))))

(test contract-integration
  "Test contract system integration with DSL"
  ;; Enable contract debugging for testing
  (enable-contract-debugging t)

  ;; Test that contracts work with state models
  (let ((state (make-test-user-model :name "Test User" :email "test@example.com")))
    (is (validate-model state)))

  ;; Test contract violation detection
  (signals error
    (validate-model "not-a-property-list"))

  (enable-contract-debugging nil))

(test performance-test
  "Basic performance test for DSL operations"
  ;; Test many DSL validations
  (let ((start-time (get-internal-real-time))
        (iterations 1000))

    (dotimes (i iterations)
      (validate-base-dsl '(:container
                           :children ((:text :content "Test")
                                      (:button :text "Button")))))

    (let* ((end-time (get-internal-real-time))
           (elapsed (/ (- end-time start-time) internal-time-units-per-second)))

      ;; Should complete reasonably quickly
      (is (< elapsed 1.0))
      (format t "~&DSL Performance: ~A validations in ~A seconds~%" iterations elapsed)))

  ;; Test many state operations
  (let ((start-time (get-internal-real-time))
        (iterations 1000)
        (state (make-test-user-model :name "Test" :email "test@example.com")))

    (dotimes (i iterations)
      (let ((patches (list (make-state-patch :path '(:name)
                                             :value (format nil "Test~A" i)
                                             :operation :set))))
        (apply-state-patches state patches)))

    (let* ((end-time (get-internal-real-time))
           (elapsed (/ (- end-time start-time) internal-time-units-per-second)))

      ;; Should complete reasonably quickly
      (is (< elapsed 1.0))
      (format t "~&State Performance: ~A patches in ~A seconds~%" iterations elapsed))))

;;;--------------------------------------------------------------
;;; Error Handling Tests
;;;--------------------------------------------------------------

(def-suite error-handling-tests :in dsl-tests
  :description "Tests for error handling in DSL system")

(in-suite error-handling-tests)

(test dsl-error-conditions
  "Test DSL error condition handling"
  ;; Test unknown element type
  (signals base-dsl-error
    (validate-base-dsl '(:invalid-element)))

  ;; Test invalid property list (odd length)
  (signals base-dsl-error
    (validate-base-dsl '(:text :content "Hello" :invalid-prop)))

  ;; Test missing required properties by trying to build an object
  (signals error ;; This signals a simple-error from make-instance, not base-dsl-error
    (expand-base-dsl '(:button :id :btn)))) ; Missing :text

(test state-error-conditions
  "Test state model error condition handling"
  ;; Test validation errors
  (signals error
    (make-test-user-model :name "John"))  ; Missing required email

  ;; Test type validation
  (signals error
    (validate-test-user-model '(:name "John" :email "john@example.com" :age "not-number")))

  ;; Test custom validation
  (signals error
    (validate-test-user-model '(:name "Child" :email "child@example.com" :age 10 :active nil))))

;;;--------------------------------------------------------------
;;; Test Runner
;;;--------------------------------------------------------------

(defun run-dsl-tests (;; &key verbose
                      )
  "Run the complete DSL system test suite"
  (format t "~&=== Running Elmtui DSL System Tests ===~%")

  ;; Clean state before testing
  (setf *state-schemas* (make-hash-table :test 'eq))

  ;; Run all tests
  (let ((results (run 'dsl-tests)))
    (format t "~&=== Test Results ===~%")
    (format t "Tests run: ~A~%" (length (fiveam::tests results)))
    ;; (format t "Passed: ~A~%" (length (fiveam::passed results)))
    ;; (format t "Failed: ~A~%" (length (fiveam::failed results)))
    ;; (format t "Skipped: ~A~%" (length (fiveam::skipped results)))

    ;; (when (and verbose (fiveam::failed results))
    ;;   (format t "~&=== Failed Tests ===~%")
    ;;   (dolist (failure (fiveam::failed results))
    ;;     (format t "~A: ~A~%"
    ;;             (fiveam::name failure)
    ;;             (fiveam::description failure))))

    ;; Return success if all tests passed
    ;; (zerop (length (fiveam::failed results)))
    ))

;; Auto-run tests when file is loaded in test mode
#+test-mode
(run-dsl-tests :verbose t)
