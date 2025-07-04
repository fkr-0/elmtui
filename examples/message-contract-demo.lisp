;;;===============================================================
;;; File: examples/message-contract-demo.lisp
;;; Comprehensive demonstration of message contract approaches
;;; Shows flexible, typed, and hybrid message validation in action
;;;===============================================================
(uiop:define-package :elmtui.examples.message-contract-demo
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug #:log-warn)
  (:import-from :elmtui.contracts 
                #:defupdate-flexible #:defupdate-typed #:defupdate-hybrid
                #:defview #:defsubscriptions
                #:enable-contract-debugging #:validate-elm-application
                #:analyze-message-usage #:suggest-message-schema)
  (:import-from :elmtui.state.msg 
                #:defmsg #:message-variant-p
                #:make-increment-counter-countermsg
                #:make-decrement-counter-countermsg
                #:make-set-label-countermsg
                #:make-key-event-countermsg)
  (:export
   :run-message-demo
   :demo-flexible-messaging
   :demo-typed-messaging  
   :demo-hybrid-messaging
   :compare-message-approaches))

(in-package :elmtui.examples.message-contract-demo)

;;;--------------------------------------------------------------
;;; Message Schema Definition
;;;--------------------------------------------------------------

;; Define a comprehensive message schema using defmsg
(defmsg CounterMsg (:docstring "Messages for counter application with different complexity levels")
  ;; Simple messages (no parameters)
  IncrementCounter
  DecrementCounter
  ResetCounter
  
  ;; Parameterized messages  
  (SetLabel :new-label string)
  (SetStep :step-size integer)
  (SetValue :value integer)
  
  ;; Complex messages with multiple parameters
  (KeyEvent :key symbol :modifiers list :char t)
  (ThemeChange :theme-name string :colors list)
  (StateSnapshot :timestamp integer :model t))

;;;--------------------------------------------------------------
;;; 1. FLEXIBLE MESSAGE APPROACH (Backward Compatible)
;;;--------------------------------------------------------------

(defupdate-flexible flexible-counter-update (model message)
  "Flexible update function - accepts any message format.
   Useful for rapid prototyping and backward compatibility."
  
  (log-debug "FLEXIBLE: Processing message ~S" message)
  
  ;; Handle both :keyword and (:keyword ...) formats
  (let ((msg-type (if (listp message) (first message) message))
        (msg-args (when (listp message) (rest message))))
    
    (case msg-type
      ;; Simple keyword messages
      (:increment 
       (values (list :count (1+ (getf model :count 0))
                     :label (getf model :label "Counter"))
               nil))
      
      (:decrement
       (values (list :count (1- (getf model :count 0))
                     :label (getf model :label "Counter"))
               nil))
      
      (:reset
       (values (list :count 0 :label "Counter") nil))
      
      ;; Parameterized messages (manual parsing)
      (:set-label
       (let ((new-label (if (listp message)
                           (getf msg-args :new-label)
                           "Updated")))  ; Fallback for simple format
         (values (list :count (getf model :count 0)
                       :label new-label)
                 nil)))
      
      (:set-step
       (let ((step (if (listp message)
                      (getf msg-args :step-size)
                      1)))  ; Default step
         (values (list :count (getf model :count 0)
                       :label (getf model :label "Counter")
                       :step step)
                 nil)))
      
      ;; Unknown messages
      (t 
       (log-warn "FLEXIBLE: Unknown message ~S" message)
       (values nil nil)))))

;;;--------------------------------------------------------------
;;; 2. TYPED MESSAGE APPROACH (Type Safe)
;;;--------------------------------------------------------------

(defupdate-typed typed-counter-update (model message) CounterMsg
  "Typed update function - only accepts valid CounterMsg variants.
   Provides compile-time + runtime type safety."
  
  (log-debug "TYPED: Processing message ~S" message)
  
  ;; Message is GUARANTEED to be a valid CounterMsg variant
  ;; Format is always (:variant-name :param1 value1 :param2 value2 ...)
  (case (first message)
    (:increment-counter
     (let ((step (getf model :step 1)))
       (values (list :count (+ (getf model :count 0) step)
                     :label (getf model :label "Typed Counter")
                     :step step)
               nil)))
    
    (:decrement-counter
     (let ((step (getf model :step 1)))
       (values (list :count (- (getf model :count 0) step)
                     :label (getf model :label "Typed Counter")
                     :step step)
               nil)))
    
    (:reset-counter
     (values (list :count 0 
                   :label "Typed Counter"
                   :step (getf model :step 1))
             nil))
    
    (:set-label
     ;; Type-safe parameter access (guaranteed to exist and be correct type)
     (let ((new-label (getf (rest message) :new-label)))
       (values (list :count (getf model :count 0)
                     :label new-label
                     :step (getf model :step 1))
               nil)))
    
    (:set-step
     (let ((new-step (getf (rest message) :step-size)))
       (values (list :count (getf model :count 0)
                     :label (getf model :label "Typed Counter")
                     :step new-step)
               nil)))
    
    (:set-value
     (let ((new-value (getf (rest message) :value)))
       (values (list :count new-value
                     :label (getf model :label "Typed Counter")
                     :step (getf model :step 1))
               nil)))
    
    (:key-event
     (let ((key (getf (rest message) :key))
           (modifiers (getf (rest message) :modifiers)))
       (log-info "TYPED: Key event - key: ~S, modifiers: ~S" key modifiers)
       (cond
         ((and (eq key :q) (member :control modifiers))
          (values (list :should-quit t) nil))
         (t (values nil nil)))))
    
    ;; All other valid messages (no action needed)
    (t (values nil nil))))

;;;--------------------------------------------------------------
;;; 3. HYBRID MESSAGE APPROACH (Best of Both Worlds)
;;;--------------------------------------------------------------

(defupdate-hybrid hybrid-counter-update (model message) 
    :message-type CounterMsg :prefer-typed t
  "Hybrid update function - accepts both typed and flexible messages.
   Prefers typed messages but gracefully handles flexible ones with warnings."
  
  (log-debug "HYBRID: Processing message ~S" message)
  
  ;; Normalize message format - works with both typed and flexible
  (let* ((is-typed (message-variant-p 'CounterMsg message))
         (msg-type (if (listp message) (first message) message))
         (msg-args (when (listp message) (rest message))))
    
    (when (not is-typed)
      (log-warn "HYBRID: Using flexible message ~S (consider migrating to typed)" message))
    
    (case msg-type
      ;; Handle both :increment and :increment-counter
      ((:increment :increment-counter)
       (let ((step (if is-typed
                      (getf model :step 1)
                      (getf msg-args :step 1))))  ; Flexible can include :step
         (values (list :count (+ (getf model :count 0) step)
                       :label (getf model :label "Hybrid Counter")
                       :step step)
                 nil)))
      
      ;; Handle both :decrement and :decrement-counter  
      ((:decrement :decrement-counter)
       (let ((step (getf model :step 1)))
         (values (list :count (- (getf model :count 0) step)
                       :label (getf model :label "Hybrid Counter")
                       :step step)
                 nil)))
      
      ;; Handle both :reset and :reset-counter
      ((:reset :reset-counter)
       (values (list :count 0
                     :label "Hybrid Counter"
                     :step (getf model :step 1))
               nil))
      
      ;; Handle parameterized messages in both formats
      (:set-label
       (let ((new-label (if is-typed
                           (getf msg-args :new-label)
                           (getf msg-args :new-label "Flexible Label"))))
         (values (list :count (getf model :count 0)
                       :label new-label
                       :step (getf model :step 1))
                 nil)))
      
      ;; Flexible-only messages (not in schema)
      (:custom-action
       (log-info "HYBRID: Handling flexible-only message")
       (values (list :count (getf model :count 0)
                     :label "Custom Action Applied"
                     :step (getf model :step 1))
               nil))
      
      ;; Unknown messages
      (t 
       (log-warn "HYBRID: Unknown message ~S" message)
       (values nil nil)))))

;;;--------------------------------------------------------------
;;; View Function (Shared across all approaches)
;;;--------------------------------------------------------------

(defview demo-counter-view (model)
  "Shared view function for all message approaches"
  `(:container
    :id :demo-counter-main
    :style (:display :flex :flex-direction :column :padding 2)
    :children 
    ((:text :id :title :text ,(format nil "~A (Count: ~A)" 
                                     (getf model :label "Counter")
                                     (getf model :count 0)))
     (:text :id :step-info :text ,(format nil "Step: ~A" (getf model :step 1)))
     (:container
      :id :button-container
      :style (:display :flex :flex-direction :row :spacing 1)
      :children
      ((:text :id :increment-btn :text "[+] Increment")
       (:text :id :decrement-btn :text "[-] Decrement")
       (:text :id :reset-btn :text "[R] Reset")))
     (:text :id :instructions 
           :text "Press Q+Ctrl to quit, or any key for demo"))))

;;;--------------------------------------------------------------
;;; Subscription Functions (Message Generation Examples)
;;;--------------------------------------------------------------

(defsubscriptions flexible-subscriptions (model)
  "Subscriptions that generate flexible messages"
  (declare (ignore model))
  (list
    (elmtui.contracts:make-subscription
     :type :keyboard
     :config '(:all-keys t)
     :message-fn (lambda (key-data)
                   ;; Generate flexible message
                   (case (getf key-data :key)
                     (:+ :increment)
                     (:- :decrement)
                     (:r :reset)
                     (t (list :key-event 
                             :key (getf key-data :key)
                             :modifiers (getf key-data :modifiers))))))))

(defsubscriptions typed-subscriptions (model)
  "Subscriptions that generate typed messages"
  (declare (ignore model))
  (list
    (elmtui.contracts:make-subscription
     :type :keyboard
     :config '(:all-keys t)
     :message-fn (lambda (key-data)
                   ;; Generate typed message using constructors
                   (case (getf key-data :key)
                     (:+ (make-increment-counter-countermsg))
                     (:- (make-decrement-counter-countermsg))
                     (:r (make-reset-counter-countermsg))
                     (t (make-key-event-countermsg 
                         :key (getf key-data :key)
                         :modifiers (getf key-data :modifiers)
                         :char (getf key-data :char))))))))

(defsubscriptions hybrid-subscriptions (model)
  "Subscriptions that generate mixed message types"
  (declare (ignore model))
  (list
    (elmtui.contracts:make-subscription
     :type :keyboard
     :config '(:all-keys t)
     :message-fn (lambda (key-data)
                   ;; Mix of typed and flexible messages
                   (case (getf key-data :key)
                     ;; Use typed for common actions
                     (:+ (make-increment-counter-countermsg))
                     (:- (make-decrement-counter-countermsg))
                     ;; Use flexible for less common actions
                     (:r :reset)
                     (:c :custom-action)
                     ;; Use typed for complex events
                     (t (make-key-event-countermsg 
                         :key (getf key-data :key)
                         :modifiers (getf key-data :modifiers)
                         :char (getf key-data :char))))))))

;;;--------------------------------------------------------------
;;; Demo Application Runners
;;;--------------------------------------------------------------

(defun demo-flexible-messaging ()
  "Demonstrates flexible message approach"
  (log-info "=== FLEXIBLE MESSAGING DEMO ===")
  (enable-contract-debugging t)
  
  ;; Test flexible update function
  (let ((model '(:count 5 :label "Flexible Counter")))
    
    ;; Test simple messages
    (log-info "Testing simple messages...")
    (multiple-value-bind (new-model commands)
        (flexible-counter-update model :increment)
      (log-info "Result: ~S, Commands: ~S" new-model commands))
    
    ;; Test parameterized messages (manual format)
    (log-info "Testing parameterized messages...")
    (multiple-value-bind (new-model commands)
        (flexible-counter-update model '(:set-label :new-label "Flexible Label"))
      (log-info "Result: ~S, Commands: ~S" new-model commands))
    
    ;; Test unknown messages (graceful handling)
    (log-info "Testing unknown message...")
    (multiple-value-bind (new-model commands)
        (flexible-counter-update model :unknown-action)
      (log-info "Result: ~S, Commands: ~S" new-model commands))))

(defun demo-typed-messaging ()
  "Demonstrates typed message approach"
  (log-info "=== TYPED MESSAGING DEMO ===")
  (enable-contract-debugging t)
  
  ;; Test typed update function
  (let ((model '(:count 5 :label "Typed Counter" :step 2)))
    
    ;; Test typed messages using constructors
    (log-info "Testing typed messages...")
    (multiple-value-bind (new-model commands)
        (typed-counter-update model (make-increment-counter-countermsg))
      (log-info "Result: ~S, Commands: ~S" new-model commands))
    
    ;; Test parameterized typed messages
    (log-info "Testing parameterized typed messages...")
    (multiple-value-bind (new-model commands)
        (typed-counter-update model (make-set-label-countermsg :new-label "Type Safe!"))
      (log-info "Result: ~S, Commands: ~S" new-model commands))
    
    ;; Test complex typed messages
    (log-info "Testing complex typed messages...")
    (multiple-value-bind (new-model commands)
        (typed-counter-update model (make-key-event-countermsg 
                                    :key :q :modifiers '(:control) :char #\q))
      (log-info "Result: ~S, Commands: ~S" new-model commands))
    
    ;; Demonstrate contract violation (would fail)
    (log-info "Testing contract validation...")
    (handler-case
        (typed-counter-update model :invalid-message)
      (elmtui.contracts:message-contract-violation (e)
        (log-info "✓ Contract violation caught: ~A" e)))))

(defun demo-hybrid-messaging ()
  "Demonstrates hybrid message approach"
  (log-info "=== HYBRID MESSAGING DEMO ===")
  (enable-contract-debugging t)
  
  ;; Test hybrid update function
  (let ((model '(:count 5 :label "Hybrid Counter" :step 1)))
    
    ;; Test typed messages
    (log-info "Testing typed messages in hybrid mode...")
    (multiple-value-bind (new-model commands)
        (hybrid-counter-update model (make-increment-counter-countermsg))
      (log-info "Result: ~S, Commands: ~S" new-model commands))
    
    ;; Test flexible messages (with warnings)
    (log-info "Testing flexible messages in hybrid mode...")
    (multiple-value-bind (new-model commands)
        (hybrid-counter-update model :increment)
      (log-info "Result: ~S, Commands: ~S" new-model commands))
    
    ;; Test flexible-only messages
    (log-info "Testing flexible-only messages...")
    (multiple-value-bind (new-model commands)
        (hybrid-counter-update model :custom-action)
      (log-info "Result: ~S, Commands: ~S" new-model commands))
    
    ;; Test message format compatibility
    (log-info "Testing both message formats...")
    (multiple-value-bind (typed-result typed-commands)
        (hybrid-counter-update model (make-set-label-countermsg :new-label "Typed"))
      (multiple-value-bind (flexible-result flexible-commands)
          (hybrid-counter-update model '(:set-label :new-label "Flexible"))
        (log-info "Typed result: ~S" typed-result)
        (log-info "Flexible result: ~S" flexible-result)))))

(defun compare-message-approaches ()
  "Compares all three message approaches side by side"
  (log-info "=== MESSAGE APPROACH COMPARISON ===")
  (enable-contract-debugging t)
  
  (let ((test-model '(:count 10 :label "Test" :step 1)))
    
    ;; Test same logical operation across all approaches
    (log-info "Comparing increment operation across approaches:")
    
    ;; Flexible approach
    (multiple-value-bind (flex-model flex-commands)
        (flexible-counter-update test-model :increment)
      (log-info "FLEXIBLE: ~S -> ~S" test-model flex-model))
    
    ;; Typed approach  
    (multiple-value-bind (typed-model typed-commands)
        (typed-counter-update test-model (make-increment-counter-countermsg))
      (log-info "TYPED: ~S -> ~S" test-model typed-model))
    
    ;; Hybrid approach (both ways)
    (multiple-value-bind (hybrid-flex-model hybrid-flex-commands)
        (hybrid-counter-update test-model :increment)
      (log-info "HYBRID (flexible): ~S -> ~S" test-model hybrid-flex-model))
    
    (multiple-value-bind (hybrid-typed-model hybrid-typed-commands)
        (hybrid-counter-update test-model (make-increment-counter-countermsg))
      (log-info "HYBRID (typed): ~S -> ~S" test-model hybrid-typed-model)))
  
  ;; Analyze message usage patterns
  (log-info "Analyzing message usage patterns...")
  (let ((usage-analysis (analyze-message-usage)))
    (log-info "Message usage analysis: ~S" usage-analysis)))

(defun run-message-demo (&key (demo-type :all))
  "Runs message contract demonstrations"
  (case demo-type
    (:flexible (demo-flexible-messaging))
    (:typed (demo-typed-messaging))
    (:hybrid (demo-hybrid-messaging))
    (:compare (compare-message-approaches))
    (:all 
     (demo-flexible-messaging)
     (demo-typed-messaging)
     (demo-hybrid-messaging)
     (compare-message-approaches))
    (t (error "Unknown demo type: ~S" demo-type)))
  
  ;; Generate final report
  (log-info "=== CONTRACT SUMMARY ===")
  (let ((summary (elmtui.contracts:contract-summary)))
    (log-info "Contract execution summary: ~S" summary)))

;; Usage examples:
;; (run-message-demo :demo-type :flexible)   ; Just flexible demo
;; (run-message-demo :demo-type :typed)      ; Just typed demo  
;; (run-message-demo :demo-type :hybrid)     ; Just hybrid demo
;; (run-message-demo :demo-type :compare)    ; Comparison only
;; (run-message-demo)                        ; All demos