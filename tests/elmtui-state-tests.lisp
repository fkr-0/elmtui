;;;===============================================================
;;; File: tests/elmtui-state-tests.lisp
;;; FiveAM Unit Tests for Step 3: State Management & Elm Integration

(defpackage :elmtui-state-tests
  (:use :cl :fiveam
        :elmtui.state.model
   :elmtui.state.msg
        :elmtui.state.update
        ;; Import state, transaction, and observe symbols for testing
        :ut.state.state
        :ut.state.transaction
        :ut.state.observe)
  (:shadowing-import-from :ut.state.state #:set-state!) ; Shadow potential local set-state! in defupdate
  )

(in-package :elmtui-state-tests)

(def-suite step3-state)
(in-suite step3-state)

;;; 1. defmodel macro: struct creation and slot defaults
(defmodel test-model
    (foo :type integer :initform 1)
    (bar :type string :initform "baz"))

(defmodel counter-model-test (:docstring "A simple counter model for testing"
                              :package :elmtui-state-tests ; Ensure it's in the test package
                              ;; :observe-changes-default-callback my-model-observer ; Assuming my-model-observer is defined
                              )
          (count :type integer :initform 0 :validate #'plusp :observe t) ; Observe count
          (label :type string :initform "Clicks")) ; Don't observe label

(test defmodel-struct-creation
  (let ((m (make-test-model))) ; Uses the generated constructor for test-model
    (is (= (funcall (intern (string :foo) :elmtui-state-tests) m) 1)) ; Accessor needs to be in the correct package or use slot-value
    (is (string= (funcall (intern (string :bar) :elmtui-state-tests) m) "baz")))
  (let ((c (make-counter-model-test)))
    (is (= (funcall (intern (string :count) :elmtui-state-tests) c) 0))
    (is (string= (funcall (intern (string :label) :elmtui-state-tests) c) "Clicks"))))

;;; 2. defmsg macro: constant creation and variant registration
(defmsg test-msg
    (:docstring "aloaha")

    (a be  i barz )) ; Corrected :bazz to :baz for consistency if intended

(test defmsg-constant-creation
  (is (boundp (intern (string :test-msg) :elmtui-state-tests))) ; defmsg creates a constant
  (is (equal (symbol-value (intern (string :test-msg) :elmtui-state-tests)) '(:foo :bar :baz))))

;;; 3. defupdate macro: function creation and update contract
;; Assuming elmtui.state.update exports set-state! or it's available
;; and that test-model is a plist-based model as per docs/state-management.md
(defupdate test-update (current-state msg)
  (declare (ignore msg)) ; msg is not used in this simple test
  ;; defupdate typically works with a global *app-state* or a passed state
  ;; and set-state! modifies a key within that state.
  ;; This test needs to align with how defupdate and set-state! are meant to be used.
  ;; For now, let's assume it returns a new model and commands.
  (let ((model (getf current-state 'test-model)))
    (values (list* :foo 42 (remove :foo model :key #'car)) ; Create new plist for test-model part
            nil))) ; No commands

(test defupdate-function-creation
  (let* ((initial-model-plist (make-test-model)) ; plist like (:foo 1 :bar "baz")
         (app-state (list 'test-model initial-model-plist)) ; Simulate app-state structure
         (result-model-plist commands (test-update app-state :some-message)))
    (declare (ignore commands))
    (is (= (getf result-model-plist :foo) 42))))

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

(test with-transaction-commit
  (with-fixture transaction-test-fixture ()
    (is (zerop (length (application-state-transaction-history app-state))))
    (with-transaction (app-state)
      (set-state app-state :counter 1)
      (set-state app-state :user "Bob"))
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
        (set-state app-state :counter 10)
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
(def-fixture observer-test-fixture (transaction-test-fixture) ; Inherit from transaction fixture
  (setf *observer-calls* nil) ; Clear calls before each test
  (&body)
  (setf *observer-calls* nil)) ; Clear calls after each test

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
