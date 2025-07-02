---
# AI Metadata Tags
ai_keywords: [State Module, Elm Architecture, TEA, Model, Update, Message Handling, State Management, Immutable State, State Transactions, Component State]
ai_contexts: [architecture, development, implementation]
ai_relations: [
  "./implementation.md",
  "../app/overview.md",
  "../core/overview.md",
  "../ui/overview.md",
  "../view/overview.md",
  "../../architecture/system-overview.md",
  "../../architecture/core-concepts.md",
  "../../architecture/module-dependencies.md"
]
---

# State Module Overview

<!-- AI-IMPORTANCE:level=critical -->
## Core Functionality

The `state` module implements The Elm Architecture (TEA) pattern for Elmtui, providing predictable state management through the Model-Update-View cycle. It handles both global application state and local component state, ensuring all state changes are managed in a controlled and predictable manner. The module includes support for state transactions, immutable updates, and reactive state propagation.

## Main Features

- **TEA Implementation:** Complete implementation of The Elm Architecture (Model-Update-View) pattern
- **State Management:** Both global application state and local component state handling
- **Message Processing:** Type-safe message handling and routing system
- **Update Functions:** Pure functions for state transformations based on messages
- **State Transactions:** Atomic state updates with rollback capabilities
- **Immutable Updates:** Controlled state mutation with immutability helpers
- **State Observation:** Reactive state change notifications and subscriptions
- **Command Effects:** Side effect management through command dispatching

<!-- AI-CONTEXT-START:type=architecture -->
## Architectural Design

The `state` module implements a functional reactive architecture based on The Elm Architecture, ensuring predictable and maintainable state management.

### Key Components
- **State Store ([`src/state/state.lisp`](src/state/state.lisp:1)):** Central state container and management
- **Message System ([`src/state/msg.lisp`](src/state/msg.lisp:1)):** Type definitions and routing for messages
- **Update Engine ([`src/state/update.lisp`](src/state/update.lisp:1)):** State transformation logic
- **Model Definitions ([`src/state/model.lisp`](src/state/model.lisp:1)):** State structure and validation
- **Elm Integration ([`src/state/elm.lisp`](src/state/elm.lisp:1)):** TEA pattern implementation
- **State Library ([`src/state/statelib/`](src/state/statelib/:1)):** Low-level state management utilities
- **Transaction System ([`src/state/transactions.lisp`](src/state/transactions.lisp:1)):** Atomic state updates

### TEA Pattern Implementation
1. **Model:** Application and component state represented as immutable data structures
2. **Update:** Pure functions that transform state in response to messages: `(model, message) -> (new-model, command)`
3. **View:** Functions that derive UI structure from current state (handled by [`view`](../view/overview.md) module)
4. **Messages:** Data structures representing events or user actions
5. **Commands:** Side effects to be executed by the runtime (HTTP requests, timers, etc.)
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
## How to Use

### Defining State Models

```lisp
;; Define application state structure
(defmodel app-model
  :counter 0
  :user-name ""
  :todos (list)
  :current-view :home)

;; Define component-specific state
(defmodel counter-component-state
  :value 0
  :increment-step 1
  :max-value 100)
```

### Message Definitions

```lisp
;; Define message types
(defmsg app-msg
  (:increment)
  (:decrement)
  (:set-user-name string)
  (:add-todo string)
  (:toggle-todo integer)
  (:change-view keyword))
```

### Update Functions

```lisp
;; Global update function
(defun app-update (model msg)
  (match msg
    (:increment 
     (values (update-model model :counter (1+ (model-counter model)))
             nil))
    (:decrement
     (values (update-model model :counter (1- (model-counter model)))
             nil))
    ((:set-user-name name)
     (values (update-model model :user-name name)
             nil))
    ((:add-todo text)
     (values (update-model model :todos 
                          (append (model-todos model) (list text)))
             ;; Command to save todos to storage
             (cmd:save-todos (model-todos model))))))

;; Component update function (using defcomponent)
(defcomponent counter (props state)
  (:init (initial-props)
    (make-counter-component-state :value 0))
  
  (:update (msg local-state)
    (match msg
      (:increment
       (values (update-model local-state 
                           :value (1+ (counter-component-state-value local-state)))
               nil))
      (:reset
       (values (make-counter-component-state :value 0)
               nil)))))
```

### State Transactions

```lisp
;; Atomic state updates
(state:with-transaction ()
  (state:update-global-state :counter 42)
  (state:update-component-state my-component :value 10)
  ;; If any operation fails, all changes are rolled back
  )

;; Manual transaction control
(let ((transaction (state:begin-transaction)))
  (state:update-in-transaction transaction :user-name "Alice")
  (state:update-in-transaction transaction :todos (list "New task"))
  (if (validate-state-changes transaction)
      (state:commit-transaction transaction)
      (state:rollback-transaction transaction)))
```

### State Observation

```lisp
;; Subscribe to state changes
(state:observe-state :counter
  (lambda (old-value new-value)
    (log:info "Counter changed from ~A to ~A" old-value new-value)))

;; Subscribe to component state changes
(state:observe-component-state my-component :value
  (lambda (old-value new-value)
    (when (> new-value 100)
      (send-message my-component :reset))))
```
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=implementation -->
## Implementation Notes

### State Storage
- **Global State:** Single atom/ref containing the entire application state
- **Component State:** Local state stored within component instances
- **State Structure:** Typically implemented as nested maps/plists with fast access patterns
- **Persistence:** Optional state persistence through serialization

### Update Processing
- **Pure Functions:** All update functions are side-effect free
- **Batching:** Multiple state updates can be batched for performance
- **Validation:** State changes can be validated before application
- **Rollback:** Failed updates can be rolled back to previous state

### Memory Management
- **Structural Sharing:** Immutable updates use structural sharing to minimize memory allocation
- **Garbage Collection:** Old state versions are eligible for garbage collection
- **State History:** Optional state history tracking for debugging and undo functionality
<!-- AI-CONTEXT-END -->

## Related Resources

- [Implementation Details](./implementation.md)
- [App Module Overview](../app/overview.md)
- [Core Module Overview](../core/overview.md)
- [UI Module Overview](../ui/overview.md)
- [View Module Overview](../view/overview.md)
- [TEA Architecture Concepts](../../architecture/core-concepts.md#2-the-elm-architecture-tea-influence)
- [System Architecture Overview](../../architecture/system-overview.md)
- [Module Dependencies](../../architecture/module-dependencies.md)