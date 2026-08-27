;;; ===============================================================
;;; File: tests/state-update-tests.lisp
;;; Unit Tests for elmtui.state.update
;;; ===============================================================
(uiop:define-package :elmtui.tests.state-update
  (:use :cl :fiveam :alexandria)
  (:import-from :elmtui.state.update
    #:*log-update-results*
    #:malformed-update-result-error
    #:make-update-context
    #:context-patches
    #:context-commands
    #:sref
    #:sapply
    #:sdelete
    #:send-command
    #:cmd
    #:topic-command-p
    #:topic-command-topic
    #:topic-command-payload
    #:dispatch-to-topic
    #:process-update-result
    #:handle-async-command
    #:defupdate
    #:update-context)
  (:import-from :elmtui.state.api
    #:plist-to-application-state)
  (:export #:state-update-tests))

(in-package :elmtui.tests.state-update)

(def-suite state-update-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for state update module")

(in-suite state-update-tests)

;;;=============================================================================
;;; Update Context Tests
;;;=============================================================================

(test make-update-context-basic
  "Test creating a basic update context"
  (let ((ctx (make-update-context (plist-to-application-state '(:a 1 :b 2)))))
    (is-true (typep ctx 'update-context))
    (is-false (context-patches ctx))
    (is-false (context-commands ctx))))

(test make-update-context-with-base-path
  "Test creating update context with base path"
  (let* ((state (plist-to-application-state '(:a 1 :b (:nested 2))))
          (ctx (make-update-context state :base-path '(:b))))
    (is-true (typep ctx 'update-context))
    ;; Test that base-path affects reads via sref
    (is (equal '(:nested 2) (sref ctx nil)))
    (is (= 2 (sref ctx :nested)))))

(test update-context-draft-does-not-alias-plist-state
  "Draft mutation must not leak into the previous model before patches are committed."
  (let* ((state (plist-to-application-state
                 (list :nested (list :value 1)
                       :vector (vector (list :value 2)))
                 :backend :plist))
         (ctx (make-update-context state)))
    (setf (sref ctx '(:nested :value)) 10)
    ;; Deliberately mutate a nested draft value without using SREF; even this
    ;; must remain isolated from the previous application model.
    (setf (getf (aref (sref ctx :vector) 0) :value) 20)
    (is (= 1 (elmtui.state.api:state-ref state '(:nested :value))))
    (is (= 2 (getf (aref (elmtui.state.api:state-ref state :vector) 0) :value)))
    (is (= 10 (sref ctx '(:nested :value))))
    (is (= 20 (getf (aref (sref ctx :vector) 0) :value)))))

;;;=============================================================================
;;; Sref Tests
;;;=============================================================================

(test sref-read-simple-value
  "Test reading a simple value with sref"
  (let* ((state (plist-to-application-state '(:a 1 :b 2)))
          (ctx (make-update-context state)))
    (is (= 1 (sref ctx :a)))
    (is (= 2 (sref ctx :b)))))

(test sref-read-with-default
  "Test reading with default value"
  (let* ((state (plist-to-application-state '(:a 1)))
          (ctx (make-update-context state)))
    (is (= 1 (sref ctx :a :default)))
    (is (eq :not-found (sref ctx :missing :not-found)))
    (is-false (sref ctx :missing))))

(test sref-write-simple-value
  "Test writing a simple value with sref"
  (let* ((state (plist-to-application-state '(:a 1)))
          (ctx (make-update-context state)))
    (setf (sref ctx :a) 10)
    (is (= 10 (sref ctx :a)))
    (let ((patches (context-patches ctx)))
      (is (= 1 (length patches)))
      (is (eq :a (first (first patches))))
      (is (= 10 (second (first patches)))))))

(test sref-create-new-key
  "Test creating a new key with sref"
  (let* ((state (plist-to-application-state '()))
          (ctx (make-update-context state)))
    (setf (sref ctx :new) 42)
    (is (= 42 (sref ctx :new)))
    (is (equal '((:new 42)) (context-patches ctx)))))

(test sref-with-base-path
  "Test sref with base-path context"
  (let* ((state (plist-to-application-state '(:a (:nested 1 :value 2))))
          (ctx (make-update-context state :base-path '(:a))))
    (is (= 1 (sref ctx :nested)))
    (setf (sref ctx :nested) 10)
    (is (= 10 (sref ctx :nested)))))

(test sref-with-base-path-nil
  "Test sref with nil path uses base-path"
  (let* ((state (plist-to-application-state '(:a 1)))
          (ctx (make-update-context state :base-path '(:a))))
    (is (= 1 (sref ctx nil)))))

(test sref-with-list-path
  "Test sref with list path"
  (let* ((state (plist-to-application-state '(:a (:nested (:deep 5)))))
          (ctx (make-update-context state)))
    (is (= 5 (sref ctx '(:a :nested :deep))))))

(test sref-with-base-path-and-list
  "Test sref with base-path and list path"
  (let* ((state (plist-to-application-state '(:a (:nested (:deep 5)))))
          (ctx (make-update-context state :base-path '(:a))))
    (is (= 5 (sref ctx '(:nested :deep))))))

;;;=============================================================================
;;; Sapply Tests
;;;=============================================================================

(test sapply-basic-function
  "Test sapply with a basic function"
  (let* ((state (plist-to-application-state '(:count 0)))
          (ctx (make-update-context state)))
    (is (= 1 (sapply ctx :count #'1+)))
    (is (= 1 (sref ctx :count)))
    (is (equal '((:count 1)) (context-patches ctx)))))

(test sapply-with-default
  "Test sapply with default value"
  (let* ((state (plist-to-application-state '()))
          (ctx (make-update-context state)))
    (is (= 11 (sapply ctx :missing #'1+ 10)))
    (is (= 11 (sref ctx :missing)))))

(test sapply-complex-function
  "Test sapply with a complex transformation"
  (let* ((state (plist-to-application-state '(:items (1 2 3))))
          (ctx (make-update-context state)))
    (sapply ctx :items (lambda (x) (mapcar #'1+ x)))
    (is (equal '(2 3 4) (sref ctx :items)))))

;;;=============================================================================
;;; Sdelete Tests
;;;=============================================================================

(test sdelete-existing-key
  "Test deleting an existing key"
  (let* ((state (plist-to-application-state '(:a 1 :b 2)))
          (ctx (make-update-context state)))
    (sdelete ctx :a)
    (is-false (sref ctx :a))
    (let ((patches (context-patches ctx)))
      (is (= 1 (length patches)))
      (is (eq :elmtui-delete-path (second (first patches)))))))

(test sdelete-with-base-path
  "Test sdelete with base-path"
  (let* ((state (plist-to-application-state '(:a (:nested 1))))
          (ctx (make-update-context state :base-path '(:a))))
    (sdelete ctx :nested)
    (is-false (sref ctx :nested))))

;;;=============================================================================
;;; Send-Command / Cmd Tests
;;;=============================================================================

(test send-command-basic
  "Test sending a basic command"
  (let* ((state (plist-to-application-state '()))
          (ctx (make-update-context state)))
    (send-command ctx :my-command)
    (let ((commands (context-commands ctx)))
      (is (= 1 (length commands)))
      (is (eq :my-command (first commands))))))

(test cmd-alias
  "Test cmd is an alias for send-command"
  (let* ((state (plist-to-application-state '()))
          (ctx (make-update-context state)))
    (cmd ctx :another-cmd)
    (is (equal '(:another-cmd) (context-commands ctx)))))

(test send-command-multiple
  "Test sending multiple commands"
  (let* ((state (plist-to-application-state '()))
          (ctx (make-update-context state)))
    (send-command ctx :cmd1)
    (send-command ctx :cmd2)
    (send-command ctx :cmd3)
    (let ((commands (context-commands ctx)))
      (is (= 3 (length commands)))
      ;; Commands are in insertion order
      (is (equal '(:cmd1 :cmd2 :cmd3) commands)))))

(test send-command-complex
  "Test sending a complex command"
  (let* ((state (plist-to-application-state '()))
          (ctx (make-update-context state)))
    (send-command ctx '(:async :task :fake-task :id :fake-id :promise :fake-promise))
    (let ((commands (context-commands ctx)))
      (is (= 1 (length commands)))
      (is (= 7 (length (first commands)))))))

;;;=============================================================================
;;; Topic Command Tests
;;;=============================================================================

(test topic-command-p-valid
  "Test topic-command-p with valid command"
  (is-true (topic-command-p '(:topic-dispatch :my-topic :payload)))
  (is-true (topic-command-p '(:topic-dispatch :topic "some payload"))))

(test topic-command-p-invalid
  "Test topic-command-p with invalid commands"
  (is-false (topic-command-p '(:not-dispatch :topic :payload)))
  (is-false (topic-command-p '(:topic-dispatch :topic)))
  (is-false (topic-command-p '(:topic-dispatch :topic :a :b)))
  (is-false (topic-command-p nil))
  (is-false (topic-command-p 'just-a-symbol)))

(test topic-command-topic
  "Test extracting topic from topic command"
  (is (eq :my-topic (topic-command-topic '(:topic-dispatch :my-topic :payload))))
  (is (eq :events (topic-command-topic '(:topic-dispatch :events "data")))))

(test topic-command-payload
  "Test extracting payload from topic command"
  (is (eq :payload (topic-command-payload '(:topic-dispatch :my-topic :payload))))
  (is (equal "data" (topic-command-payload '(:topic-dispatch :my-topic "data")))))

(test dispatch-to-topic
  "Test creating a dispatch command"
  (let ((cmd (dispatch-to-topic :my-topic :payload)))
    (is-true (topic-command-p cmd))
    (is (eq :my-topic (topic-command-topic cmd)))
    (is (eq :payload (topic-command-payload cmd)))))

(test dispatch-to-topic-complex-payload
  "Test dispatch with complex payload"
  (let ((cmd (dispatch-to-topic :events '(:type :click :x 10))))
    (is-true (topic-command-p cmd))
    (is (eq :events (topic-command-topic cmd)))
    (is (equal '(:type :click :x 10) (topic-command-payload cmd)))))

;;;=============================================================================
;;; Process Update Result Tests
;;;=============================================================================

(test process-update-result-valid
  "Test processing a valid update result"
  (multiple-value-bind (patches commands)
      (process-update-result '(((:a 1) (:b 2)) (:cmd1)) :update-fn-name 'test-update)
    (is (equal '((:a 1) (:b 2)) patches))
    (is (equal '(:cmd1) commands))))

(test process-update-result-nil-values
  "Test processing with nil patches and commands"
  (multiple-value-bind (patches commands)
      (process-update-result '(nil nil) :update-fn-name 'test-update)
    (is-false patches)
    (is-false commands)))

(test process-update-result-not-list
  "Test error when returned values is not a list"
  (signals malformed-update-result-error
    (process-update-result 'not-a-list :update-fn-name 'test-update)))

(test process-update-result-wrong-length
  "Test error when wrong number of values"
  (signals malformed-update-result-error
    (process-update-result '(1 2 3) :update-fn-name 'test-update))
  (signals malformed-update-result-error
    (process-update-result '(1) :update-fn-name 'test-update)))

(test process-update-result-patches-not-list
  "Test error when patches is not a list"
  (signals malformed-update-result-error
    (process-update-result '(42 nil) :update-fn-name 'test-update)))

(test process-update-result-commands-not-list
  "Test error when commands is not a list"
  (signals malformed-update-result-error
    (process-update-result '(nil not-a-list) :update-fn-name 'test-update)))

(test malformed-update-result-error-accessors
  "Test accessing error condition fields"
  (handler-case
      (process-update-result 'invalid :update-fn-name 'my-update)
    (malformed-update-result-error (e)
      (is-true (typep e 'malformed-update-result-error)))
    (:no-error (&rest _)
      (declare (ignore _))
      (is-false "Expected error to be signaled"))))

;;;=============================================================================
;;; Context Patches/Commands Order Tests
;;;=============================================================================

(test context-patches-order
  "Test that patches maintain insertion order"
  (let* ((state (plist-to-application-state '()))
          (ctx (make-update-context state)))
    (setf (sref ctx :first) 1)
    (setf (sref ctx :second) 2)
    (setf (sref ctx :third) 3)
    (is (equal '((:first 1) (:second 2) (:third 3)) (context-patches ctx)))))

(test context-commands-order
  "Test that commands maintain insertion order"
  (let* ((state (plist-to-application-state '()))
          (ctx (make-update-context state)))
    (send-command ctx :first)
    (send-command ctx :second)
    (send-command ctx :third)
    (is (equal '(:first :second :third) (context-commands ctx)))))

(test context-patches-and-commands-together
  "Test patches and commands don't interfere"
  (let* ((state (plist-to-application-state '()))
          (ctx (make-update-context state)))
    (setf (sref ctx :a) 1)
    (send-command ctx :cmd1)
    (setf (sref ctx :b) 2)
    (send-command ctx :cmd2)
    (is (equal '((:a 1) (:b 2)) (context-patches ctx)))
    (is (equal '(:cmd1 :cmd2) (context-commands ctx)))))

;;;=============================================================================
;;; Log Update Results Tests
;;;=============================================================================

(test log-update-results-flag
  "Test *log-update-results* special variable exists"
  (is-false *log-update-results*)
  (let ((*log-update-results* t))
    (is-true *log-update-results*)))

;;;=============================================================================
;;; Async Command Handling Tests
;;;=============================================================================

(test handle-async-command-delegates-canonical-async
  "Canonical :async commands should be delegated to core async interpreter."
  (let ((called nil)
        (captured nil)
        (command '(:async :task :fake-task :id :fake-id :promise :fake-promise)))
    (let ((original (symbol-function 'elmtui.core.async:interpret-cmd)))
      (unwind-protect
           (progn
             (setf (symbol-function 'elmtui.core.async:interpret-cmd)
                   (lambda (cmd)
                     (setf called t
                           captured cmd)
                     :ok))
             (handle-async-command command nil)
             (is-true called)
             (is (equal command captured)))
        (setf (symbol-function 'elmtui.core.async:interpret-cmd) original)))))

(test handle-async-command-unknown-shape-does-not-error
  "Unknown async command shapes should be ignored safely."
  (is-false (handle-async-command '(:unknown-async-shape :payload 7) nil)))

(defupdate test-defupdate-no-direct-effect-execution (state msg)
  (progn state msg)
  (values nil (list '(:async :task :fake-task :id :fake-id :promise :fake-promise))))

(test defupdate-does-not-execute-commands-directly
  "DEFUPDATE should only produce commands; runtime effect manager executes them."
  (let ((state (plist-to-application-state '()))
        (called nil))
    (let ((original (symbol-function 'elmtui.state.update:handle-async-command)))
      (unwind-protect
           (progn
             (setf (symbol-function 'elmtui.state.update:handle-async-command)
                   (lambda (_command _state)
                     (declare (ignore _command _state))
                     (setf called t)
                     :unexpected))
             (multiple-value-bind (patches commands)
                 (test-defupdate-no-direct-effect-execution state :ping)
               (is-false patches)
               (is (= 1 (length commands)))
               (is (equal '(:async :task :fake-task :id :fake-id :promise :fake-promise)
                          (first commands))))
             (is-false called))
        (setf (symbol-function 'elmtui.state.update:handle-async-command) original)))))
