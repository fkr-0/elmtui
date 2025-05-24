# ELMTUI Target Architecture

This document describes the target architecture for ELMTUI after completing the refactoring plan. It details the data structures, APIs, types, and function signatures that will form the core of the pure Elm architecture implementation in Common Lisp.

## Core Concepts

ELMTUI follows the Elm Architecture (TEA) with three fundamental components:

1. **Model**: The complete application state
2. **Update**: Pure functions that transform state in response to messages
3. **View**: Pure functions that render the state to the terminal UI

## 1. State Management

### 1.1. Model Definition

```lisp
(defmodel counter-model
  (:docstring "A simple counter model")
  (count :type integer :initform 0 :validate #'plusp :observe t)
  (label :type string :initform "Counter"))
```

#### Generated Functions

```lisp
;; Constructor
(defun make-counter-model (&key (count 0) (label "Counter"))
  "Create a new counter-model plist instance with validation"
  ;; Returns a plist with validated values
  )

;; Initialization
(defun initialize-counter-model-state (app-state initial-plist)
  "Initialize counter-model in application state and set up observers")

;; Accessors (schema-aware, not raw state access)
(defun counter-model-count (app-state)
  "Get the count from counter-model")

(defun counter-model-label (app-state)
  "Get the label from counter-model")
```

### 1.2. Model Storage

Models are stored as property lists within an `application-state` instance. The state provides transaction and undo/redo support.

```lisp
(defclass application-state ()
  ((state-data :initform (make-hash-table :test 'equal))   ; Hash table with model name keys
   (transaction-history :initform nil)                     ; List of committed transactions
   (current-transaction :initform nil)                     ; Transaction in progress
   (undone-history :initform nil)                          ; Undone transactions for redo
   (observers :initform nil)))                             ; Registered state observers
```

### 1.3. State Access Functions

```lisp
;; Generic access (primarily for internal use)
(defun state-ref (app-state key)
  "Get value for key from app-state")

;; Model-specific accessors (preferred public API)
(defun get-slot (app-state model-name slot-name)
  "Get the value of a model slot with schema validation")

(defun set-slot (new-value app-state model-name slot-name)
  "Set the value of a model slot with schema validation and transaction support")

;; Transaction support
(defmacro with-transaction ((app-state &key description) &body body)
  "Execute body within a transaction, committing changes atomically")

;; Undo/Redo
(defun undo-last-transaction (app-state)
  "Undo the most recent transaction")

(defun redo-last-transaction (app-state)
  "Redo the most recently undone transaction")
```

## 2. Message System

### 2.1. Message Definition

```lisp
(defmsg counter-msg
  (:docstring "Messages for counter component")
  (:increment
   :type (integer)
   :docstring "Increment counter by the specified amount"
   :validation (plusp amount))
  (:decrement
   :type (integer)
   :docstring "Decrement counter by the specified amount")
  (:reset
   :docstring "Reset counter to zero"))
```

#### Generated Functions

```lisp
;; Constructors with validation
(defun make-counter-msg-increment (amount)
  "Create increment counter message"
  ;; Validates amount is a positive integer
  (list :increment amount))

(defun make-counter-msg-decrement (amount)
  "Create decrement counter message"
  ;; Validates amount is an integer
  (list :decrement amount))

(defun make-counter-msg-reset ()
  "Create reset counter message"
  :reset)
```

### 2.2. Message Format

Messages follow a standardized format:

1. **Keyword symbol**: For simple messages without data (e.g., `:reset`)
2. **List with keyword and args**: For messages with data (e.g., `(:increment 5)`)

## 3. Update System

### 3.1. Update Definition

```lisp
(defupdate update-counter (app-state msg)
  "Handle counter-msg messages by updating counter-model"
  (with-transaction (app-state)
    (ematch msg
      (:reset
       (set-slot 0 app-state 'counter-model 'count))
      
      ((:increment amount)
       (set-slot (+ amount (get-slot app-state 'counter-model 'count))
                 app-state 'counter-model 'count))
      
      ((:decrement amount) 
       (set-slot (- (get-slot app-state 'counter-model 'count) amount)
                 app-state 'counter-model 'count)))))
```

### 3.2. Main Update Function

```lisp
(defupdate main-update (app-state msg)
  "Main update function that delegates to component-specific updates"
  (ematch msg
    ;; Counter component messages
    ((or :reset (:increment _) (:decrement _))
     (update-counter app-state msg))
    
    ;; Input component messages
    ((or (:input-text _) :submit (:key-pressed _))
     (update-input app-state msg))
    
    ;; Focus management messages
    ((or :focus-next :focus-previous (:focus-widget _))
     (update-focus app-state msg))
    
    ;; Unknown message
    (_ (warn "Unknown message: ~S" msg))))
```

## 4. View System

### 4.1. Widget Functions

All widgets follow a standard functional pattern:

```lisp
(defun counter-view (app-state &key widget-id)
  "Render a counter widget based on counter-model"
  (let ((count (get-slot app-state 'counter-model 'count))
        (label (get-slot app-state 'counter-model 'label)))
    (make-box
     :id widget-id
     :width 20
     :height 3
     :content (format nil "~A: ~D" label count)
     :focusable t
     :on-click (lambda () (make-counter-msg-increment 1)))))
```

### 4.2. View DSL

A concise DSL for creating view structures:

```lisp
(defmacro ui (&body elements)
  "DSL for building UI structures"
  `(let ((result (make-ui-container)))
     ,@(mapcar (lambda (el) `(ui-add-element result ,el)) elements)
     result))

;; Example usage
(defun app-view (app-state)
  (ui
    (vstack
      (label :text "Counter Example")
      (counter-view app-state :widget-id "main-counter")
      (hstack
        (button :text "+" :on-click (make-counter-msg-increment 1))
        (button :text "-" :on-click (make-counter-msg-decrement 1))
        (button :text "Reset" :on-click (make-counter-msg-reset))))))
```

### 4.3. View Result Type

```lisp
(defclass ui-element ()
  ((id :initarg :id :initform (gensym "UI-EL"))
   (attributes :initarg :attributes :initform nil)
   (children :initarg :children :initform nil)
   (handlers :initarg :handlers :initform nil)))
```

## 5. Event Handling

### 5.1. Standard Event Types

```lisp
(deftype key-event ()
  '(cons keyword t))

(deftype mouse-event ()
  '(cons keyword (cons integer (cons integer t))))
```

### 5.2. Event Processing

```lisp
(defun process-event (app-state event &key (sender *default-sender*))
  "Process input event and dispatch resulting messages"
  (let ((msgs (event->messages app-state event)))
    (dolist (msg msgs)
      (funcall sender msg))))
```

### 5.3. Focus Management

```lisp
(defun focus-next-widget (app-state)
  "Move focus to the next focusable widget")

(defun focus-previous-widget (app-state)
  "Move focus to the previous focusable widget")

(defun focus-widget (app-state widget-id)
  "Set focus to specific widget")
```

## 6. Core Runtime

### 6.1. Main Loop

The main event loop leverages the channel-based concurrency model from clevelib to achieve a clean separation of concerns while maintaining high performance. This approach is:

1. **More performant**: Utilizes multiple threads for specialized tasks
2. **More flexible**: Allows for priority-based processing and timeouts
3. **Simpler**: Clear separation between event sources and processors
4. **Elm idiomatic**: Maintains unidirectional data flow
5. **Lisp idiomatic**: Leverages concurrency features of Common Lisp

```lisp
(defun run-app (initial-state view-fn update-fn &key (driver *default-driver*))
  "Run application with the Elm architecture pattern using channels for message passing"
  (let ((app-state (make-application-state :data initial-state))
        (app-channel (make-channel :capacity 100)) ; Primary message channel
        (event-channel (make-channel :capacity 50)) ; Input event channel
        (command-channel (make-channel :capacity 50)) ; Command execution channel
        (render-channel (make-channel :capacity 1))) ; Render notification channel
    
    ;; Initialize driver
    (driver-init driver)
    
    ;; Message processing thread - core of the Elm architecture
    (gogo
      (loop
        (let ((msg (<- app-channel)))
          (when (eq msg :quit)
            (-> command-channel :quit)
            (-> render-channel :quit)
            (return))
          
          (with-transaction (app-state :description (format nil "Update: ~A" msg))
            (let ((commands (funcall update-fn app-state msg)))
              ;; Signal render needed
              (-> render-channel :render)
              ;; Queue commands for processing
              (when commands
                (-> command-channel commands)))))))
    
    ;; Command processing thread
    (gogo
      (loop
        (let ((cmd (<- command-channel)))
          (when (eq cmd :quit)
            (return))
          
          (process-command cmd app-channel))))
    
    ;; Event processing thread
    (gogo
      (loop
        (let ((event (driver-next-event driver)))
          (when event
            (let ((msgs (event->messages event)))
              (dolist (msg msgs)
                (-> app-channel msg)))))))
    
    ;; Rendering thread
    (gogo
      (loop
        (let ((signal (<- render-channel)))
          (when (eq signal :quit)
            (return))
          
          ;; Perform rendering on dedicated thread
          (let ((view (funcall view-fn app-state)))
            (driver-render driver view))
          
          ;; Use select to implement frame rate limiting
          (select
            (default (sleep 0.016)) ; ~60 FPS
            )))))
  
  ;; Return control to caller
  t)

;; Enhanced process-command with channel support
(defun process-command (command app-channel)
  "Process a command and dispatch resulting messages to the app-channel"
  (ematch command
    ((:dispatch msg)
     (-> app-channel msg))
    
    ((:dispatch-later ms msg)
     (gogo
       (sleep (/ ms 1000.0))
       (-> app-channel msg)))
    
    ((:http-get url on-success &optional on-error)
     (gogo
       (handler-case
         (let ((response (http-get-sync url)))
           (-> app-channel (funcall on-success response)))
         (error (e)
           (when on-error
             (-> app-channel (funcall on-error e)))))))
    
    (_ (warn "Unknown command: ~S" command))))
```

### 6.2. Command System

The command system uses the async-task and promise infrastructure to handle side effects while preserving the purity of update functions:

```lisp
(deftype command ()
  "Command type for side effects"
  '(cons keyword t))

(defmethod execute ((cmd command) (app-channel channel))
  "Execute a command by dispatching to appropriate handler based on command type"
  (ematch cmd
    ((:dispatch msg)
     (-> app-channel msg)
     nil)
    
    ((:dispatch-later ms msg)
     (let ((task (new-task 
                  (lambda ()
                    (sleep (/ ms 1000.0))
                    (-> app-channel msg)))))
       (async-exec task)
       task))
    
    ((:http-get url on-success &optional on-error)
     (let ((promise (make-instance 'promise))
           (task (new-task
                  (lambda ()
                    (handler-case
                      (let ((response (http-get-sync url)))
                        (-> app-channel (funcall on-success response))
                        (resolve-promise promise response))
                      (error (e)
                        (when on-error
                          (-> app-channel (funcall on-error e)))
                        (reject-promise promise e)))))))
       (async-exec task)
       promise))
    
    ((:animation duration from to step-fn complete-fn)
     (let ((start-time (get-internal-real-time))
           (task (new-task
                  (lambda ()
                    (loop
                      (let* ((elapsed (/ (- (get-internal-real-time) start-time) 
                                         internal-time-units-per-second))
                             (progress (min 1.0 (/ elapsed duration)))
                             (value (+ from (* (- to from) progress))))
                        
                        ;; Send step message
                        (-> app-channel (funcall step-fn value))
                        
                        ;; Check if animation is complete
                        (when (>= progress 1.0)
                          (-> app-channel (funcall complete-fn))
                          (return))
                        
                        ;; Sleep until next frame (~60 FPS)
                        (sleep 0.016)))))))
       (async-exec task)
       task))))

(defun process-commands (commands app-channel)
  "Process all commands and return any promises or tasks created"
  (loop for cmd in commands
        collect (execute cmd app-channel)))
```

### 6.3. Subscription System

The subscription system leverages channels to create clean, maintainable sources of messages from external events:

```lisp
(defclass subscription ()
  ((id :initform (gensym "SUB") :reader subscription-id)
   (type :initarg :type :reader subscription-type)
   (channel :initarg :channel :reader subscription-channel)
   (task :initarg :task :accessor subscription-task)
   (active :initform t :accessor subscription-active)))

(defun subscribe (app-channel subscription-type &rest args)
  "Register a subscription that will generate messages"
  (let* ((sub-channel (make-channel))
         (subscription (make-instance 'subscription 
                                     :type subscription-type
                                     :channel sub-channel)))
    
    ;; Create specific subscription based on type
    (setf (subscription-task subscription)
          (case subscription-type
            (:time-every
             (let ((interval (first args)))
               (new-task 
                (lambda ()
                  (loop while (subscription-active subscription) do
                    (-> app-channel `(:time-tick ,(subscription-id subscription)))
                    (sleep interval))))))
            
            (:keyboard
             (new-task
              (lambda ()
                (loop while (subscription-active subscription) do
                  (let ((key (read-key)))
                    (-> app-channel `(:key-event ,key ,(subscription-id subscription))))))))
            
            (:websocket
             (let ((url (first args))
                   (msg-converter (second args)))
               (new-task
                (lambda ()
                  (with-websocket-connection (ws url)
                    (loop while (subscription-active subscription) do
                      (let ((ws-msg (read-websocket-message ws)))
                        (-> app-channel (funcall msg-converter ws-msg (subscription-id subscription))))))))))))
    
    ;; Start the subscription task
    (async-exec (subscription-task subscription))
    
    ;; Return subscription ID for later reference
    (subscription-id subscription)))

(defun unsubscribe (app-state subscription-id)
  "Remove a subscription"
  (let ((sub (find subscription-id (application-state-subscriptions app-state)
                  :key #'subscription-id)))
    (when sub
      (setf (subscription-active sub) nil)
      (cancel-async-task (subscription-task sub))
      (setf (application-state-subscriptions app-state)
            (remove sub (application-state-subscriptions app-state)))
      t)))

(defun process-subscription-msg (app-state msg)
  "Handle a message from a subscription"
  (ematch msg
    ((:time-tick sub-id)
     (handle-time-tick app-state sub-id))
    
    ((:key-event key sub-id)
     (handle-key-event app-state key sub-id))
    
    ((list :websocket-msg data sub-id)
     (handle-websocket-message app-state data sub-id))))
```

## 7. Data Flow

### 7.1 Event Processing Flow

1. Input event arrives from platform driver
2. Event is converted to one or more messages
3. Messages are sent to update function
4. Update function produces state changes and commands
5. Commands are processed, potentially generating more messages
6. View is re-rendered if state changed

### 7.2 State Update Flow

1. Update function receives a message
2. A transaction is started
3. State modifications are made through `set-slot`
4. Transaction is committed
5. Observers are notified of changes
6. View re-rendering is triggered

### 7.3 Subscription Flow

1. Component subscribes to external events (timer, network, etc.)
2. When external event occurs, a message is generated
3. Message is sent through normal update flow
4. Component can unsubscribe when no longer needed

## 8. Key Semantic Guarantees

### 8.1 Pure Functions

- Update functions are pure with respect to external state
- View functions are pure renderers of application state
- Side effects occur only through the command system

### 8.2 Type Safety

- Model slots have runtime type checking
- Messages have validation on construction
- Error handling is explicit through result types

### 8.3 Transaction Safety

- State changes occur in atomic transactions
- Undo/redo preserves consistent state
- Observers only see consistent state after commit

### 8.4 Unidirectional Data Flow

- State flows down through view hierarchy
- Events flow up as messages
- Components don't directly modify state of other components

### 8.5 Composition

- Models can be composed of other models
- Views can be composed of other views
- Update functions delegate to component-specific functions
