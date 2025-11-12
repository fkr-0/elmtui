---
ai_keywords: [Elmtui, Architecture, App Creation, Configuration, defcomponent, defmodel, defapplication, State Flow, Message Dispatch, Integration Guide]
ai_contexts: [architecture, development, guide]
ai_relations: [
  "../ai-index/overview.md",
  "../ai-index/navigation-guide.md",
  "../modules/ui/component-lifecycle.md",
  "../modules/tea-state/state-transactions.md",
  "../modules/app/application-patterns.md",
  "../dev-guides/creating-applications.md"
]
---
# Elmtui: App Creation and Configuration Architecture Guide

This guide provides a comprehensive overview of how Elmtui's core systems—`defcomponent`, `defmodel`, and `defapplication`—integrate to form robust and interactive terminal user interfaces. It addresses key architectural findings and aims to clarify the interplay between state management, UI rendering, and event handling.

<!-- AI-IMPORTANCE:level=critical -->
## 1. Core Systems Overview

Elmtui applications are built upon three fundamental macro systems, each serving a distinct purpose:

*   **`defcomponent`**: Defines reusable UI elements, managing their local state, rendering logic, and event handlers.
*   **`defmodel`**: Establishes the application's global state, providing mechanisms for state transitions and observation.
*   **`defapplication`**: Orchestrates the entire application, integrating components and models, handling top-level configuration, and managing the main event loop.

### 1.1. Architectural Findings Addressed

The architectural review highlighted several critical areas for improvement and documentation:

*   **State Representation Mismatch**: Components currently use both hash-tables and plists for local state, while the `defmodel` system exclusively uses plists. This guide will clarify best practices and recommend a unified approach.
*   **Message Handling Fragmentation**: Elmtui employs dual dispatch systems (keymap-based and component-specific message handling) without a unified schema. This document will illustrate these patterns and suggest strategies for coherent message flow.
*   **Error Handling Variance**: Inconsistent error recovery patterns across the three systems lead to unpredictable behavior. This guide will outline recommended error handling strategies.

<!-- AI-CONTEXT-START:type=architecture -->
## 2. Integration of `defcomponent`, `defmodel`, and `defapplication`

A typical Elmtui application leverages these three systems in a hierarchical and reactive manner.

### 2.1. State Flow Diagram

```mermaid
graph TD
    A[User Input / External Event] --> B{defapplication Event Loop};
    B --> C{Message Dispatch};
    C --> D[Component Event Handlers];
    D --> E{State Update (defmodel)};
    E --> F[Model Observers Notify];
    F --> G[Component Re-render (based on new state)];
    G --> H[Terminal Output];

    subgraph Application Lifecycle
        B --- C --- D --- E --- F --- G --- H
    end

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#bbf,stroke:#333,stroke-width:2px
    style C fill:#ccf,stroke:#333,stroke-width:2px
    style D fill:#dfd,stroke:#333,stroke-width:2px
    style E fill:#ffc,stroke:#333,stroke-width:2px
    style F fill:#fcf,stroke:#333,stroke-width:2px
    style G fill:#dfd,stroke:#333,stroke-width:2px
    style H fill:#f9f,stroke:#333,stroke-width:2px
```
*Figure 1: Simplified Elmtui Application State Flow*

### 2.2. Message Dispatch Patterns

Elmtui utilizes two primary message dispatch mechanisms:

1.  **Keymap-based Dispatch**: Global keybindings defined within `defapplication` or specific components can trigger messages.
2.  **Component-specific Dispatch**: Messages are sent directly to components, often as a result of user interaction with that component (e.g., button click, text input).

A unified message schema is crucial for maintainable applications. We recommend using a consistent plist-based message format: `(:type :message-type :payload (:key value ...))`.

### 2.3. Configuration Examples

`defapplication` serves as the central point for application-wide configuration, including initial state, root component, and global keymaps.

```lisp
(defapplication my-app ()
  ((initial-state :initform '(:counter 0 :status "Ready"))
   (root-component :initform (make-instance 'my-root-component))
   (global-keymap :initform (elmtui.keymap:make-keymap
                              #\q '(:type :quit)
                              #\+ '(:type :increment-counter)))))

(defcomponent my-root-component ()
  ((state :initform '(:local-message "Hello"))))

(defmodel my-app-model ()
  ((counter :initform 0)
   (status :initform "Initialized")))

;; Example of how defapplication, defcomponent, and defmodel interact
(defmethod elmtui.app:handle-message ((app my-app) (message (eql :increment-counter)))
  (elmtui.state:with-transaction ((model (elmtui.app:model app)))
    (incf (elmtui.state:get-value model :counter))
    (elmtui.state:set-value model :status "Counter Incremented")))

(defmethod elmtui.component:render ((component my-root-component) &key app-model)
  (let ((counter (elmtui.state:get-value app-model :counter))
        (status (elmtui.state:get-value app-model :status))
        (local-msg (getf (elmtui.component:state component) :local-message)))
    (elmtui.view:vstack
      (elmtui.view:text (format nil "Counter: ~a" counter))
      (elmtui.view:text (format nil "Status: ~a" status))
      (elmtui.view:text (format nil "Local: ~a" local-msg))
      (elmtui.view:button "Increment" '(:type :increment-counter)))))
```
<!-- AI-CONTEXT-END -->

## 3. Best Practices for Integration

### 3.1. Unifying State Representation

<!-- AI-IMPORTANCE:level=high -->
To mitigate the state representation mismatch, it is strongly recommended to use **plists exclusively** for both component local state and `defmodel` global state. This ensures consistency and simplifies state management logic across the application.

### 3.2. Implementing a Unified Message Schema

<!-- AI-IMPORTANCE:level=high -->
All messages, whether from keymaps or component interactions, should adhere to a consistent plist-based schema. This allows for easier debugging, logging, and future tooling development.

**Recommended Message Structure:**
```lisp
'(:type :message-type
  :payload (:key1 value1 :key2 value2 ...))
```
Where `:message-type` is a keyword identifying the message, and `:payload` is an optional plist containing message-specific data.

### 3.3. Enhancing Error Handling

Implement a centralized error handling mechanism within `defapplication` to catch and log unhandled errors. Components and models should use `handler-case` or `handler-bind` for localized error recovery where appropriate, propagating critical errors upwards.

## 4. Developer Experience Improvements

### 4.1. Reducing Complexity

Understanding the interaction between `defcomponent`, `defmodel`, and `defapplication` is key. This guide, along with practical examples, aims to flatten the learning curve.

### 4.2. Tooling for Message Schema Design

While dedicated tooling is under development, developers can use simple validation functions to ensure messages conform to the unified schema.

## Related Resources

*   [Component Lifecycle Documentation](../modules/ui/component-lifecycle.md)
*   [State Transactions Guide](../modules/tea-state/state-transactions.md)
*   [Application Patterns Documentation](../modules/app/application-patterns.md)
*   [Creating Applications Developer Guide](../dev-guides/creating-applications.md)
*   [Elmtui Coding Standards](../dev-guides/coding-standards.md)