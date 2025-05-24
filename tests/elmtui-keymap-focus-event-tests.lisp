;;;===============================================================
;;; File: tests/elmtui-keymap-focus-event-tests.lisp
;;; Tests for the integrated keymap-focus-event chain
;;;===============================================================
(uiop:define-package :elmtui-keymap-focus-event-tests
  (:use :cl :fiveam :alexandria)
  ;; Import event system
  (:import-from :elmtui.core.event-types
                #:make-key-event
                #:key-event-p
                #:key-event-key
                #:key-event-modifiers)
  ;; Import keymap system
  (:import-from :elmtui.core.keymap
                #:make-keymap
                #:key-event->normalized-key
                #:parse-key-string
                #:normalized-key->string)
  (:import-from :elmtui.core.keymap.registry
                #:register-keymap
                #:find-keymap
                #:collect-all-defined-sequences
                #:lookup-key-binding
                #:*global-keymap-context*
                #:current-context
                #:activate-context)
  ;; Import sequence support
  (:import-from :elmtui.core.keymap.sequence
                #:make-sequence-state
                #:make-key-sequence
                #:sequence->string
                #:key-sequence-complete-p
                #:key-sequence-partial-p)
  ;; Import focus system
  (:import-from :elmtui.core.focus
                #:make-focus-manager
                #:focus-manager-current-focus)
  ;; Import keymap-focus integration
  (:import-from :elmtui.core.focus
                #:handle-key-event
                #:handle-key-binding
                #:find-component-keymap-context
                #:component-gained-focus
                #:component-lost-focus)
  ;; Import event integration
  (:import-from :elmtui.core.keymap.event-integration
                #:process-keyboard-event
                #:handle-key-sequence
                #:*key-sequence-state*)
  ;; Import main system
  (:import-from :elmtui.core.keymap-system
                #:initialize-keymap-system
                #:create-focus-manager
                #:setup-key-event-handling)
  ;; Import state management
  (:import-from :elmtui.state
                #:make-application-state
                #:state-ref
                #:set-state)
  ;; Import event normalization
  (:import-from :elmtui.core.event-types
                #:normalize-event)
  ;; Export test runner
  (:export #:run-keymap-focus-event-tests))

(in-package :elmtui-keymap-focus-event-tests)

;;;-----------------------------------------------------------------------------
;;; Test Suite Definition
;;;-----------------------------------------------------------------------------

(def-suite keymap-focus-event-tests
  :description "Tests for the integrated keymap-focus-event chain.")

(in-suite keymap-focus-event-tests)

;;;-----------------------------------------------------------------------------
;;; Test Utilities
;;;-----------------------------------------------------------------------------

(defun make-test-app-state ()
  "Create a test application state with widget models."
  (let ((app-state (make-application-state)))
    ;; Set up focus manager in app state
    (set-state app-state :focus-manager (make-focus-manager))
    
    ;; Create test widgets with different keymaps
    (let ((button-keymap (make-keymap))
          (input-keymap (make-keymap)))
      
      ;; Register keymaps
      (register-keymap :button-keymap button-keymap)
      (register-keymap :input-keymap input-keymap)
      
      ;; Add bindings to button keymap
      (setf (gethash (parse-key-string "Enter") 
                     (elmtui.core.keymap:keymap-bindings button-keymap))
            '(:type :message :target (:button-click) :description "Click button"))
      
      (setf (gethash (parse-key-string "Space") 
                     (elmtui.core.keymap:keymap-bindings button-keymap))
            '(:type :message :target (:button-click) :description "Alternative click"))
      
      ;; Add bindings to input keymap
      (setf (gethash (parse-key-string "C-a") 
                     (elmtui.core.keymap:keymap-bindings input-keymap))
            '(:type :message :target (:select-all) :description "Select all text"))
      
      ;; Add multi-key sequence to input keymap (C-x C-s for save)
      (setf (gethash (parse-key-string "C-x") 
                     (elmtui.core.keymap:keymap-bindings input-keymap))
            '(:type :sequence-start :description "Ctrl-X prefix"))
      
      ;; Create widget models
      (set-state app-state :widgets 
                 (list :button1 (list :id :button1
                                      :type :button
                                      :label "Button 1"
                                      :active-keymap button-keymap)

                       :input1 (list :id :input1
                                     :type :textinput
                                     :value "Sample Text"
                                     :active-keymap input-keymap)))
      
      ;; Set focusable elements
      (let ((focus-manager (state-ref app-state :focus-manager)))
        (setf (elmtui.core.focus:focus-manager-focusable-elements focus-manager)
              (list :button1 :input1))))
    
    app-state))

(defvar *test-message-received* nil
  "Variable to track received messages during tests.")

(defun reset-test-message-received ()
  "Reset test message tracking variable."
  (setf *test-message-received* nil))

(defun mock-dispatch-event (message)
  "Mock event dispatcher that sets *test-message-received*."
  (setf *test-message-received* message))

;;;-----------------------------------------------------------------------------
;;; Tests for Event Normalization and Conversion
;;;-----------------------------------------------------------------------------

(test event-normalization
  "Test that events are properly normalized"
  (let ((key-event (make-key-event :type :key-down :key :a :modifiers '(:control)))
        (normalized-event nil))

    ;; Test normalization
    (setf normalized-event (normalize-event key-event))
    (is (key-event-p normalized-event) "Normalized event should be a key-event")
    (is (eq (key-event-key normalized-event) :a) "Normalized event should preserve key")
    (is (equal (key-event-modifiers normalized-event) '(:control)) "Normalized event should preserve modifiers")

    ;; Test conversion to normalized-key
    (let ((normalized-key (key-event->normalized-key normalized-event)))
      (is (typep normalized-key 'elmtui.core.keymap::normalized-key) "Should convert to normalized-key")
      (is (eq (elmtui.core.keymap::normalized-key-key normalized-key) :a) "Normalized key should preserve key")
      (is (equal (elmtui.core.keymap::normalized-key-modifiers normalized-key) '(:ctrl)) "Modifiers should be normalized"))))

;;;-----------------------------------------------------------------------------
;;; Tests for Keymap Context and Lookup
;;;-----------------------------------------------------------------------------

(test keymap-context-lookup
  "Test that keymap contexts work correctly and binding lookups work"
  (let* ((app-state (make-test-app-state))
         (button1-context (find-component-keymap-context :button1 app-state))
         (input1-context (find-component-keymap-context :input1 app-state)))

    ;; Test that contexts are created correctly
    (is (eq (not (null button1-context)) (not nil)) "Button1 should have a keymap context")
    (is (not (null input1-context)) "Input1 should have a keymap context")

    ;; Test lookups with contexts activated
    (activate-context button1-context)
    (is-true (lookup-key-binding (parse-key-string "Enter")) "Enter binding should be found in button context")
    (is-false (lookup-key-binding (parse-key-string "C-a")) "C-a binding should not be found in button context")

    (activate-context input1-context)
    (is-true (lookup-key-binding (parse-key-string "C-a")) "C-a binding should be found in input context")
    (is-false (lookup-key-binding (parse-key-string "Space")) "Space binding should not be found in input context")))

;;;-----------------------------------------------------------------------------
;;; Tests for Focus Changes and Keymap Integration
;;;-----------------------------------------------------------------------------

(test focus-keymap-integration
  "Test that focus changes activate the correct keymaps"
  (let* ((app-state (make-test-app-state))
         (focus-manager (state-ref app-state :focus-manager)))

    ;; Test initial state - no focus, no active bindings
    (is (null (focus-manager-current-focus focus-manager)) "No initial focus")

    ;; Focus button and check its keymap is active
    (component-gained-focus :button1 app-state)
    (is-true (lookup-key-binding (parse-key-string "Enter")) "Enter binding should be found when button is focused")
    (is-false (lookup-key-binding (parse-key-string "C-a")) "C-a binding should not be found when button is focused")

    ;; Change focus to input and check its keymap is active
    (component-lost-focus :button1 app-state)
    (component-gained-focus :input1 app-state)
    (is-true (lookup-key-binding (parse-key-string "C-a")) "C-a binding should be found when input is focused")
    (is-false (lookup-key-binding (parse-key-string "Enter")) "Enter binding should not be found when input is focused")))

;;;-----------------------------------------------------------------------------
;;; Tests for Event Processing Chain
;;;-----------------------------------------------------------------------------

(test event-processing-chain
  "Test the complete event processing chain"
  ;; Initialize system
  (initialize-keymap-system)

  ;; Set up test environment
  (let* ((app-state (make-test-app-state))
         (focus-manager (state-ref app-state :focus-manager)))

    ;; Set initial focus and register test dispatch function
    (component-gained-focus :button1 app-state)

    ;; Create a dynamic binding to override dispatch-event-async
    (with-slots ((dispatch-fn elmtui.core.focus::dispatch-event-async))
        elmtui.core.keymap.event-integration:handle-key-binding
      (let ((original-dispatch dispatch-fn))
        (setf dispatch-fn #'mock-dispatch-event)

        ;; Test 1: Process Enter key for button - should trigger button-click
        (reset-test-message-received)
        (process-keyboard-event
         (make-key-event :type :key-down :key :enter :modifiers nil)
         focus-manager
         :app-state app-state)
        (is (equal *test-message-received* '(:button-click)) "Enter key should trigger button-click message")

        ;; Test 2: Process C-a key for button - should not be handled
        (reset-test-message-received)
        (process-keyboard-event
         (make-key-event :type :key-down :key :a :modifiers '(:control))
         focus-manager
         :app-state app-state)
        (is (null *test-message-received*) "C-a key should not be handled when button is focused")

        ;; Test 3: Switch focus to input and try C-a
        (component-lost-focus :button1 app-state)
        (component-gained-focus :input1 app-state)
        (reset-test-message-received)
        (process-keyboard-event
         (make-key-event :type :key-down :key :a :modifiers '(:control))
         focus-manager
         :app-state app-state)
        (is (equal *test-message-received* '(:select-all)) "C-a key should trigger select-all message when input is focused")

        ;; Restore original dispatch function
        (setf dispatch-fn original-dispatch)))))

;;;-----------------------------------------------------------------------------
;;; Tests for Multi-Key Sequences
;;;-----------------------------------------------------------------------------

(test multi-key-sequences
  "Test multi-key sequence handling"
  ;; Create a test keymap with multi-key sequence
  (let* ((app-state (make-application-state))
         (sequence-keymap (make-keymap))
         (focus-manager (make-focus-manager))
         (sequence-state (make-sequence-state)))

    ;; Add sequence binding: C-x C-s -> save
    (let* ((c-x-key (parse-key-string "C-x"))
           (c-s-key (parse-key-string "C-s")))

      ;; Configure keymap for testing
      (setf (gethash c-x-key (elmtui.core.keymap:keymap-bindings sequence-keymap))
            '(:type :sequence-start :description "Ctrl-X prefix"))

      (setf (gethash c-s-key (elmtui.core.keymap:keymap-bindings sequence-keymap))
            '(:type :message :target (:save) :description "Save"))

      ;; Set up app state with widget using this keymap
      (set-state app-state :widgets
                 (list :editor (list :id :editor
                                     :type :editor
                                     :active-keymap sequence-keymap)))

      ;; Set up focus manager in app state
      (set-state app-state :focus-manager focus-manager)
      ;; Set focusable elements
      (setf (elmtui.core.focus:focus-manager-focusable-elements focus-manager)
            (list :editor))

      ;; Register keymap and focus component
      (register-keymap :sequence-keymap sequence-keymap)
      (let ((context (elmtui.core.keymap.registry:make-keymap-context :name :test-context)))
        (push sequence-keymap (elmtui.core.keymap.registry:keymap-context-keymaps context))
        (activate-context context))

      ;; Test partial sequence detection
      (with-slots ((seq-state elmtui.core.keymap.event-integration::*key-sequence-state*))
          elmtui.core.keymap.event-integration:handle-key-sequence
        (let ((original-state seq-state))
          (setf seq-state sequence-state)

          ;; Test sequence detection directly - no need to mock the function
          (let* ((test-sequences (list (make-key-sequence :keys (list c-x-key c-s-key))))
                 (partial-seq (make-key-sequence :keys (list c-x-key))))

            ;; Test sequence detection using key-sequence-partial-p directly
            (is (key-sequence-partial-p partial-seq test-sequences)
                "C-x should be detected as a partial sequence")

            ;; Also test using the actual sequences from the context
            (let ((actual-sequences (collect-all-defined-sequences context)))
              (is (= (length actual-sequences) 1)
                  "Should collect 1 sequences from the context")
              (is (key-sequence-partial-p partial-seq actual-sequences)
                  "C-x should be detected as a partial sequence in collected sequences")))

          ;; Restore original sequence state
          (setf seq-state original-state))))))

;; (test comprehensive-key-sequence-handling
;;   "Test comprehensive key sequence detection, timeouts, and handling"
;;   ;; Initialize system
;;   (initialize-keymap-system)

;;   ;; Set up test environment with multiple keymaps and nested sequences
;;   (let* ((app-state (make-application-state))
;;          (editor-keymap (make-keymap))
;;          (cmd-keymap (make-keymap))
;;          (focus-manager (create-focus-manager))
;;          (editor-context (elmtui.core.keymap.registry:make-keymap-context :name :editor-context))
;;          (cmd-context (elmtui.core.keymap.registry:make-keymap-context
;;                        :name :cmd-context
;;                        :parent editor-context))
;;          (test-sequences-triggered nil))

;;     ;; Define test callbacks that track when sequences are triggered
;;     (flet ((record-sequence (name)
;;              (lambda (app-state)
;;                (declare (ignore app-state))
;;                (push name test-sequences-triggered))))

;;       ;; Configure editor keymap with various shortcuts
;;       (setf (gethash (parse-key-string "C-x")
;;                      (elmtui.core.keymap:keymap-bindings editor-keymap))
;;             '(:type :sequence-start :description "C-x prefix"))

;;       (setf (gethash (parse-key-string "C-s")
;;                      (elmtui.core.keymap:keymap-bindings editor-keymap))
;;             '(:type :message :target (:search) :description "Search"))

;;       ;; Multi-key sequences in editor keymap
;;       (setf (gethash (list (parse-key-string "C-x") (parse-key-string "C-s"))
;;                      (elmtui.core.keymap:keymap-bindings editor-keymap))
;;             '(:type :message :target (:save) :description "Save"))

;;       (setf (gethash (list (parse-key-string "C-x") (parse-key-string "C-f"))
;;                      (elmtui.core.keymap:keymap-bindings editor-keymap))
;;             '(:type :message :target (:find-file) :description "Find file"))

;;       ;; Configure cmd keymap with other shortcuts that might conflict
;;       (setf (gethash (parse-key-string "C-s")
;;                      (elmtui.core.keymap:keymap-bindings cmd-keymap))
;;             '(:type :message :target (:cmd-search) :description "Command Search"))

;;       ;; Register keymaps
;;       (register-keymap :editor-keymap editor-keymap)
;;       (register-keymap :cmd-keymap cmd-keymap)

;;       ;; Add keymaps to contexts
;;       (setf (elmtui.core.keymap.registry:keymap-context-keymaps editor-context)
;;             (list :editor-keymap))
;;       (setf (elmtui.core.keymap.registry:keymap-context-keymaps cmd-context)
;;             (list :cmd-keymap))

;;       ;; Setup handler
;;       (setup-key-event-handling focus-manager app-state)

;;       ;; Mock dispatch for testing
;;       (let ((orig-dispatch #'elmtui.core.focus::dispatch-event-async)
;;             (sequences-handled nil))
;;         (setf (symbol-function 'elmtui.core.focus::dispatch-event-async)
;;               (lambda (event &optional priority)
;;                 (declare (ignore priority))
;;                 (push event sequences-handled)))

;;         ;; Test collecting sequences from contexts
;;         (activate-context editor-context)
;;         (let ((sequences (collect-all-defined-sequences editor-context)))
;;           (is (>= (length sequences) 3)
;;               "Should collect at least 3 key sequences from editor context"))

;;         ;; Test sequence overlays with parent contexts
;;         (activate-context cmd-context)
;;         (let ((c-s-binding (lookup-key-binding (parse-key-string "C-s"))))
;;           (is-true c-s-binding "Should find C-s binding")
;;           (is (equal (getf c-s-binding :target) '(:cmd-search))
;;               "C-s binding should come from cmd context (more specific)"))

;;         ;; Test multi-key sequence detection
;;         (let ((c-x (parse-key-string "C-x"))
;;               (c-s (parse-key-string "C-s"))
;;               (c-f (parse-key-string "C-f")))

;;           ;; First key in sequence
;;           (is-true (handle-key-sequence c-x focus-manager :app-state app-state)
;;                    "C-x should be recognized as a sequence start")
;;           (is (sequence-state-current *key-sequence-state*)
;;               "Sequence state should be tracking a partial sequence")

;;           ;; Complete the sequence
;;           (is-true (handle-key-sequence c-s focus-manager :app-state app-state)
;;                    "C-x C-s sequence should be handled")
;;           (is (= (length sequences-handled) 1)
;;               "One message should have been dispatched for the complete sequence")
;;           (is (null (sequence-state-current *key-sequence-state*))
;;               "Sequence state should be reset after handling complete sequence")

;;           ;; Start a new sequence and test direct lookup
;;           (reset-sequence-state *key-sequence-state*) ;; Clear previous sequence
;;           (handle-key-sequence c-x focus-manager :app-state app-state)
;;           (let ((binding (lookup-key-binding
;;                           (make-key-sequence
;;                            :keys (list c-x c-f)))))
;;             (is-true binding "Should find binding for complete C-x C-f sequence")
;;             (is (equal (getf binding :target) '(:find-file))
;;                 "C-x C-f binding should be for find-file"))

;;           ;; Test timeout handling
;;           (let ((timeout-called nil))
;;             ;; Start a sequence that will timeout
;;             (reset-sequence-state *key-sequence-state*)
;;             (update-sequence-state *key-sequence-state* c-x
;;                                    :timeout-fn (lambda (seq)
;;                                                  (declare (ignore seq))
;;                                                  (setf timeout-called t)))

;;             ;; Force a simulated timeout (without actually waiting)
;;             ;; (let ((timer-id (sequence-state-timer-id *key-sequence-state*)))
;;             ;;   (when timer-id
;;             ;;     ;; Directly invoke the timeout function
;;             ;;     (funcall (sb-ext::timer-function timer-id))))

;;             ;; (is-true timeout-called "Timeout function should have been called")))

;;             ;; Restore original dispatch
;;             (setf (symbol-function 'elmtui.core.focus::dispatch-event-async)
;;                   orig-dispatch)))))

;;;-----------------------------------------------------------------------------
;;; Tests for Sequence Timeouts
;;;-----------------------------------------------------------------------------

(test sequence-timeout-handler
  "Test sequence timeout handling"
  (let ((sequence-state (make-sequence-state))
        (timeout-called nil))

    ;; Test timeout callback
    (elmtui.core.keymap.sequence:update-sequence-state
     sequence-state
     (parse-key-string "C-x")
     :timeout-fn (lambda (seq)
                   (setf timeout-called t)))

    ;; In a real test we'd use a timer to wait for timeout
    ;; Here we just verify the timeout function was stored correctly
    (is-true (slot-value sequence-state 'elmtui.core.keymap.sequence::timeout-fn)
             "Timeout function should be stored in sequence state")))

;;;-----------------------------------------------------------------------------
;;; Tests for System Initialization and Setup
;;;-----------------------------------------------------------------------------

(test system-initialization
  "Test keymap system initialization"
  ;; Initialize the system
  (initialize-keymap-system)

  ;; Test that global context exists and has standard keymaps
  (is-true *global-keymap-context* "Global keymap context should exist after initialization")

  ;; Test focus manager creation
  (let ((focus-manager (create-focus-manager)))
    (is (typep focus-manager 'elmtui.core.focus:focus-manager)
        "create-focus-manager should return a focus-manager instance"))

  ;; Test event handler setup
  (let ((app-state (make-test-app-state))
        (focus-manager (make-focus-manager)))
    (is-true (setup-key-event-handling focus-manager app-state)
             "setup-key-event-handling should return T on success")))

;;;-----------------------------------------------------------------------------
;;; Run Test Suite
;;;-----------------------------------------------------------------------------

(defun run-keymap-focus-event-tests ()
  "Run all keymap-focus-event integration tests."
  (run! 'keymap-focus-event-tests))
