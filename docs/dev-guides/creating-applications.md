---
ai_keywords: [Elmtui, Developer Guide, Onboarding, App Creation, defcomponent, defmodel, defapplication, State Models, Component Patterns, Configuration]
ai_contexts: [development, guide, process]
ai_relations: [
  "../../ai-index/overview.md",
  "../../architecture/app-creation-configuration.md",
  "../modules/ui/component-lifecycle.md",
  "../modules/tea-state/state-transactions.md",
  "../modules/app/application-patterns.md",
  "./coding-standards.md"
]
---
# Elmtui Developer Onboarding: Creating Applications

This guide provides a step-by-step introduction for new developers to understand and effectively use Elmtui's three core systems: `defcomponent`, `defmodel`, and `defapplication`. It aims to flatten the steep learning curve identified in the architectural review and provide clear guidance for building robust TUI applications.

<!-- AI-IMPORTANCE:level=critical -->
## 1. Understanding the Core Trio: `defcomponent`, `defmodel`, `defapplication`

Before diving into code, it's essential to grasp the roles of Elmtui's foundational macros.

*   **`defapplication`**: The "main" function of your Elmtui app. It sets up the global environment, defines the root UI component, initializes the global state model, and manages the main event loop. Think of it as the orchestrator.
*   **`defmodel`**: Manages your application's global state. This is where the data that drives your UI resides. `defmodel` provides a transactional system to update state safely and notify interested components of changes.
*   **`defcomponent`**: Defines individual UI elements. Components are responsible for rendering a part of the UI based on their own local state and any data passed down from parent components or observed from the global model. They also handle user interactions (messages).

<!-- AI-CONTEXT-START:type=guide -->
## 2. Step-by-Step Application Creation

Let's walk through creating a simple counter application.

### Step 2.1: Define Your Application Model (`defmodel`)

Start by defining the global state your application needs. For a counter, we just need a `count`.

```lisp
;; file: my-counter-app/src/model.lisp
(in-package :my-counter-app)

(elmtui.state:defmodel counter-model ()
  ((count :initform 0 :accessor counter-count)))
```

### Step 2.2: Define Your UI Components (`defcomponent`)

Next, create the UI elements. A simple counter might have a display and two buttons.

```lisp
;; file: my-counter-app/src/components.lisp
(in-package :my-counter-app)

(elmtui.ui:defcomponent counter-display-component ()
  ((app-model :initarg :app-model))) ; Component will receive the model

(defmethod elmtui.ui:render ((component counter-display-component) &key)
  (let ((current-count (counter-count (slot-value component 'app-model))))
    (elmtui.view:text (format nil "Count: ~a" current-count))))

(elmtui.ui:defcomponent counter-button-component ()
  ((label :initarg :label)
   (message :initarg :message)))

(defmethod elmtui.ui:render ((component counter-button-component) &key)
  (elmtui.view:button (slot-value component 'label) (slot-value component 'message)))

(elmtui.ui:defcomponent main-counter-component ()
  ((app-model :initarg :app-model)))

(defmethod elmtui.ui:render ((component main-counter-component) &key)
  (elmtui.view:vstack
    (elmtui.ui:render (make-instance 'counter-display-component :app-model (slot-value component 'app-model)))
    (elmtui.ui:render (make-instance 'counter-button-component :label "Increment" :message '(:type :increment)))
    (elmtui.ui:render (make-instance 'counter-button-component :label "Decrement" :message '(:type :decrement)))))

(defmethod elmtui.ui:handle-message ((component main-counter-component) (message (eql '(:type :increment))))
  (elmtui.state:with-transaction ((model (slot-value component 'app-model)))
    (incf (counter-count model)))
  t)

(defmethod elmtui.ui:handle-message ((component main-counter-component) (message (eql '(:type :decrement))))
  (elmtui.state:with-transaction ((model (slot-value component 'app-model)))
    (decf (counter-count model)))
  t)
```

### Step 2.3: Define Your Application (`defapplication`)

Finally, bring it all together in your application definition.

```lisp
;; file: my-counter-app/src/app.lisp
(in-package :my-counter-app)

(elmtui.app:defapplication my-counter-app ()
  ((model :initform (make-instance 'counter-model))
   (root-component :initform (make-instance 'main-counter-component :app-model (slot-value *application* 'model)))
   (global-keymap :initform (elmtui.keymap:make-keymap
                              #\q '(:type :quit)))))

(defmethod elmtui.app:handle-message ((app my-counter-app) (message (eql '(:type :quit))))
  (elmtui.app:quit app))
```

## 3. Decision Trees and Best Practices

### 3.1. Choosing State Models: Contracts vs. Simple

<!-- AI-IMPORTANCE:level=high -->
Elmtui's `defmodel` supports both simple plist-based state and more structured "contracted" state.

*   **Simple Plist State**:
    *   **When to use**: For small, simple applications or parts of an application where state structure is unlikely to change frequently. Quick to set up.
    *   **Trade-offs**: Less compile-time checking, easier to introduce inconsistencies.
*   **Contracted State**:
    *   **When to use**: For larger, more complex applications where state consistency and validation are critical. Provides compile-time checks and enforces structure.
    *   **Trade-offs**: More verbose to define, slightly higher initial setup cost.

**Recommendation**: For new projects, start with simple plist state. As complexity grows, refactor critical parts of your model to use contracts for improved robustness.

### 3.2. Component Patterns

*   **Container Components**: Manage state and logic, pass data down to presentational components.
*   **Presentational Components**: Purely responsible for rendering UI based on props, no internal state or logic.
*   **Higher-Order Components (HOCs)**: Functions that take a component and return a new component with enhanced functionality (e.g., adding logging, focus management).

### 3.3. Configuration Options

*   **Global Keymaps**: Define application-wide keyboard shortcuts in `defapplication`.
*   **Platform Backends**: Choose the appropriate terminal backend for your target environment (e.g., `tty-backend` for standard terminals, `urxvt-backend` for URXVT).
*   **Styling**: Utilize `elmtui.style` for consistent theming and visual presentation.

## 4. Troubleshooting and Debugging

*   **Message Flow**: Use `log4cl` to trace message dispatch and state changes.
*   **Macro Expansion**: Common Lisp's macro expansion tools (e.g., `macroexpand-1`, `macroexpand`) are invaluable for understanding what `defcomponent`, `defmodel`, and `defapplication` generate.
*   **State Inspection**: During development, inspect the `model` slot of your `defapplication` instance to verify state.

## Related Resources

*   [App Creation and Configuration Architecture Guide](../../architecture/app-creation-configuration.md)
*   [Component Lifecycle Documentation](../modules/ui/component-lifecycle.md)
*   [State Transactions Guide](../modules/tea-state/state-transactions.md)
*   [Application Patterns Documentation](../modules/app/application-patterns.md)
*   [Elmtui Coding Standards](./coding-standards.md)