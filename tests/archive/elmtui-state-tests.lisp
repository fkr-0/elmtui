;;;===============================================================
;;; File: tests/elmtui-state-tests.lisp
;;; FiveAM Unit Tests for Step 3: State Management & Elm Integration
(defpackage :elmtui-state-tests
  (:use :cl :fiveam
        :elmtui.state.model
   :elmtui.state.msg
        :elmtui.state.update
        ;; Import state, transaction, and observe symbols for testing
        :elmtui.statelib.state
        :elmtui.statelib.transaction
        :elmtui.statelib.observe)
  (:import-from :elmtui.statelib.observe :add-observer)
  (:shadowing-import-from :ut.state.state #:set-state!) ; Shadow potential local set-state! in defupdate
  (:export #:make-baz-test-msg #:make-bar-test-msg #:make-foo-test-msg)) ; Explicitly export this symbol to fix the warning

(in-package :elmtui-state-tests)

(def-suite step3-state)
(in-suite step3-state)

;;; 1. defmodel macro: struct creation and slot defaults
(defmodel test-model
    (:docstring "Test model for basic structure testing")
    (foo :type integer :initform 1)
    (bar :type string :initform "baz"))

(defmodel counter-model-test (:docstring "A simple counter model for testing")
          (count-m :type integer :initform 0 :validate #'plusp :observe t) ; Observe count
          (label :type string :initform "Clicks")) ; Don't observe label

;; Add missing function that was being exported

;;   "Create a test message for foo updates"
;;   (list :update-foo value))

(test defmodel-struct-creation
  (let ((m (make-test-model))) ; m is a plist
    (is (= (get-slot m 'test-model 'foo) 1))
    (is (string= (get-slot m 'test-model 'bar) "baz")))
  (let ((c (make-counter-model-test))) ; c is a plist
    (is (= (get-slot c 'counter-model-test 'count-m) 0))
    (is (string= (get-slot c 'counter-model-test 'label) "Clicks"))))

;;; 2. defmsg macro: constant creation and variant registration
(defmsg test-msg
    (:docstring "Test message variants")
    :foo :bar :baz) ; Define allowed message variants

;; (test defmsg-constant-creation
;;   (is (boundp (intern (string :test-msg) :elmtui-state-tests))) ; defmsg creates a constant
;;   (is (equal (symbol-value (intern (string :test-msg) :elmtui-state-tests)) '(:foo :bar :baz))))

;;; 3. defupdate macro: function creation and update contract
(defupdate test-update (current-state msg)
  "Updates the test model in the state based on a message."
  (let ((model (state-ref current-state 'test-model)))
    (let ((new-model-plist (copy-list model))) ; Create a mutable copy
      (setf (getf new-model-plist :foo) 42)    ; Modify the copy
      ;; Return a patch for the 'test-model key and the new plist value
      (values (list 'test-model new-model-plist)
              nil)))) ; No commands

(test defupdate-function-creation
  (let* ((state (make-application-state))
         (initial-model-plist (list :foo 1 :bar "baz")))
    ;; Set up the test model in the state
    (set-state state 'test-model initial-model-plist)

    ;; Call the update function. It will modify 'state' and return commands.
    (let ((commands (test-update state :some-message)))
      (declare (ignore commands)) ; Commands are nil in this specific test-update

      ;; Verify that the state was updated correctly
      (let ((updated-model-plist (state-ref state 'test-model)))
        (is (not (null updated-model-plist)))
        (is (= (getf updated-model-plist :foo) 42))
        (is (string= (getf updated-model-plist :bar) "baz"))))))

;;; 4. Transaction Tests

;; Helper fixture to ensure clean state for transaction tests
(def-fixture transaction-test-fixture ()
  (let ((app-state (make-application-state)))
    ;; Initialize some state
    (set-state app-state :counter 0)
    (set-state app-state :user "Alice")
    ;; Clear history before each test
    (clear-transaction-history app-state)
    (&body)))
(with-fixture transaction-test-fixture ()
  (with-transaction (app-state)
    (set-state app-state :counter 3)
    (set-state app-state :user "Bob")
    (setf (state-ref app-state :user) "Bobby")
    )
  app-state)
(test with-transaction-commit
  (with-fixture transaction-test-fixture ()
    (is (zerop (length (application-state-transaction-history app-state))))
    (with-transaction (app-state)
      ;; (setf (state-ref app-state :counter) 1)
      (setf (state-ref app-state :counter )1)
      (setf (state-ref app-state :user) "Bob"))

    (is (= (state-ref app-state :counter) 1))
    (is (string= (state-ref app-state :user) "Bob"))
    (is (= (length (application-state-transaction-history app-state)) 1))
    (is (null (application-state-undone-history app-state)))
    (let ((tx (first (application-state-transaction-history app-state))))
      (is (= (length (transaction-changes tx)) 2)))))

(test with-transaction-abort-on-error
  (with-fixture transaction-test-fixture ()
    (signals error
      (with-transaction (app-state)
        ;; (set-state app-state :counter 10)
        (setf (state-ref app-state :counter) 10)
        (error "Test error during transaction")))
    ;; State should remain unchanged because transaction wasn't committed
    (is (= (state-ref app-state :counter) 0))
    (is (string= (state-ref app-state :user) "Alice"))
    ;; No transaction should be added to history
    (is (zerop (length (application-state-transaction-history app-state))))))

(test undo-last-transaction
  (with-fixture transaction-test-fixture ()
    (with-transaction (app-state)
      (set-state app-state :counter 5))
    (is (= (state-ref app-state :counter) 5))
    (is (= (length (application-state-transaction-history app-state)) 1))

    (let ((undone-tx (undo-last-transaction app-state)))
      (is (typep undone-tx 'transaction))
      (is (= (state-ref app-state :counter) 0)) ; State reverted
      (is (zerop (length (application-state-transaction-history app-state)))) ; History popped
      (is (= (length (application-state-undone-history app-state)) 1)) ; Added to undone
      (is (eq undone-tx (first (application-state-undone-history app-state)))))

    ;; Test undo on empty history
    (is (null (undo-last-transaction app-state)))))

(test redo-last-transaction
  (with-fixture transaction-test-fixture ()
    (with-transaction (app-state)
      (set-state app-state :counter 9))
    (undo-last-transaction app-state)
    (is (= (state-ref app-state :counter) 0))
    (is (= (length (application-state-undone-history app-state)) 1))

    (let ((redone-tx (redo-last-transaction app-state)))
      (is (typep redone-tx 'transaction))
      (is (= (state-ref app-state :counter) 9)) ; State re-applied
      (is (= (length (application-state-transaction-history app-state)) 1)) ; Added back to history
      (is (zerop (length (application-state-undone-history app-state)))) ; Undone history cleared
      (is (eq redone-tx (first (application-state-transaction-history app-state)))))

    ;; Test redo on empty undone history
    (is (null (redo-last-transaction app-state)))))

(test undo-redo-sequence
  (with-fixture transaction-test-fixture ()
    ;; Tx1
    (with-transaction (app-state) (set-state app-state :counter 1))
    ;; Tx2
    (with-transaction (app-state) (set-state app-state :user "Bob"))
    (is (= (state-ref app-state :counter) 1))
    (is (string= (state-ref app-state :user) "Bob"))
    (is (= (length (application-state-transaction-history app-state)) 2))

    ;; Undo Tx2
    (undo-last-transaction app-state)
    (is (= (state-ref app-state :counter) 1))
    (is (string= (state-ref app-state :user) "Alice")) ; Reverted
    (is (= (length (application-state-transaction-history app-state)) 1))
    (is (= (length (application-state-undone-history app-state)) 1))

    ;; Undo Tx1
    (undo-last-transaction app-state)
    (is (= (state-ref app-state :counter) 0)) ; Reverted
    (is (string= (state-ref app-state :user) "Alice"))
    (is (= (length (application-state-transaction-history app-state)) 0))
    (is (= (length (application-state-undone-history app-state)) 2))

    ;; Redo Tx1
    (redo-last-transaction app-state)
    (is (= (state-ref app-state :counter) 1)) ; Re-applied
    (is (string= (state-ref app-state :user) "Alice"))
    (is (= (length (application-state-transaction-history app-state)) 1))
    (is (= (length (application-state-undone-history app-state)) 1))

    ;; Redo Tx2
    (redo-last-transaction app-state)
    (is (= (state-ref app-state :counter) 1))
    (is (string= (state-ref app-state :user) "Bob")) ; Re-applied
    (is (= (length (application-state-transaction-history app-state)) 2))
    (is (= (length (application-state-undone-history app-state)) 0))))

(test new-commit-clears-redo-stack
  (with-fixture transaction-test-fixture ()
    ;; Tx1
    (with-transaction (app-state) (set-state app-state :counter 1))
    ;; Tx2
    (with-transaction (app-state) (set-state app-state :user "Bob"))
    ;; Undo Tx2
    (undo-last-transaction app-state)
    (is (= (length (application-state-undone-history app-state)) 1))

    ;; Tx3 (New transaction)
    (with-transaction (app-state) (set-state app-state :counter 2))
    (is (= (state-ref app-state :counter) 2))
    (is (string= (state-ref app-state :user) "Alice")) ; Still reverted from Tx2 undo
    (is (= (length (application-state-transaction-history app-state)) 2)) ; Tx1, Tx3
    ;; Redo stack should be cleared
    (is (zerop (length (application-state-undone-history app-state))))
    (is (null (redo-last-transaction app-state)))))

(test clear-transaction-history
  (with-fixture transaction-test-fixture ()
    (with-transaction (app-state) (set-state app-state :counter 1))
    (undo-last-transaction app-state)
    (is (= (length (application-state-transaction-history app-state)) 0))
    (is (= (length (application-state-undone-history app-state)) 1))
    (clear-transaction-history app-state)
    (is (zerop (length (application-state-transaction-history app-state))))
    (is (zerop (length (application-state-undone-history app-state))))))


;;; 5. Observer Tests

(defvar *observer-calls* nil "List to record observer callback arguments.")

(defun test-observer-callback (key old-value new-value)
  (push (list key old-value new-value) *observer-calls*))

;; Helper fixture for observer tests
(def-fixture observer-test-fixture ()
  (let ((app-state (make-application-state)))
    ;; Initialize like transaction fixture
    (set-state app-state :counter 0)
    (set-state app-state :user "Alice")
    (clear-transaction-history app-state)
    ;; Clear observer calls
    (setf *observer-calls* nil)
    (&body)
    (setf *observer-calls* nil)))
(test add-remove-observer
  (with-fixture observer-test-fixture ()
    (is (zerop (length (application-state-observers app-state))))
    (let ((observer-id (add-observer app-state :counter #'test-observer-callback)))
      (is (symbolp observer-id))
      (is (= (length (application-state-observers app-state)) 1))
      (is (eq (observer-key (first (application-state-observers app-state))) :counter))
      (is (eq (observer-callback (first (application-state-observers app-state))) #'test-observer-callback))

      (is (remove-observer app-state observer-id))
      (is (zerop (length (application-state-observers app-state))))

      ;; Test removing non-existent ID
      (is (not (remove-observer app-state (gensym "FAKE-ID")))))))

(test observer-notification-on-commit
  (with-fixture observer-test-fixture ()
    (add-observer app-state :counter #'test-observer-callback)
    (add-observer app-state :user #'test-observer-callback)

    (with-transaction (app-state)
      (set-state app-state :counter 1) ; Old=0, New=1
      (set-state app-state :user "Bob")) ; Old="Alice", New="Bob"

    (is (= (length *observer-calls*) 2))
    ;; Calls are pushed, so check in reverse order of changes
    (is (equal (first *observer-calls*) '(:user "Alice" "Bob")))
    (is (equal (second *observer-calls*) '(:counter 0 1)))))

(test observer-notification-on-undo
  (with-fixture observer-test-fixture ()
    (add-observer app-state :counter #'test-observer-callback)
    (with-transaction (app-state)
      (set-state app-state :counter 1)) ; Commit: Notifies (:counter 0 1)
    (setf *observer-calls* nil) ; Clear calls after commit notification

    (undo-last-transaction app-state) ; Revert: Should notify (:counter 1 0)

    (is (= (length *observer-calls*) 1))
    (is (equal (first *observer-calls*) '(:counter 1 0)))))

(test observer-notification-on-redo
  (with-fixture observer-test-fixture ()
    (add-observer app-state :counter #'test-observer-callback)
    (with-transaction (app-state)
      (set-state app-state :counter 1)) ; Commit: Notifies (:counter 0 1)
    (undo-last-transaction app-state) ; Undo: Notifies (:counter 1 0)
    (setf *observer-calls* nil) ; Clear calls after undo notification

    (redo-last-transaction app-state) ; Redo: Should notify (:counter 0 1)

    (is (= (length *observer-calls*) 1))
    (is (equal (first *observer-calls*) '(:counter 0 1)))))

(test multiple-observers-same-key
  (with-fixture observer-test-fixture ()
    (add-observer app-state :counter #'test-observer-callback)
    (add-observer app-state :counter (lambda (k o n) (push (list :second-observer k o n) *observer-calls*)))

    (with-transaction (app-state)
      (set-state app-state :counter 5))

    (is (= (length *observer-calls*) 2))
    ;; Order isn't guaranteed, check presence
    (is (member '(:counter 0 5) *observer-calls* :test #'equal))
    (is (member '(:second-observer :counter 0 5) *observer-calls* :test #'equal))))

(test observer-not-called-for-other-key
  (with-fixture observer-test-fixture ()
    (add-observer app-state :counter #'test-observer-callback)

    (with-transaction (app-state)
      (set-state app-state :user "Charlie")) ; Change different key

    (is (null *observer-calls*))))


;;; 6. Undo/Redo tests (Now covered by transaction tests above)
;; (test undo-redo-functionality
;;   (skip "Undo/Redo tests not yet implemented (Roadmap item 3, TODO)"))

;;; Run all tests
;;; #-asdf
;;; (run! 'step3-state) ; Now handled by elmtui-all-tests:run-all-elmtui-tests
