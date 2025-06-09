# Creating Widgets in Elmtui

This guide explains how to create new widgets (also referred to as components) for use within the Elmtui framework.

*(Note: This guide will be significantly based on and aims to supersede/integrate content from `docs_old/widget-authoring-v2.md` and other relevant existing documentation during Phase 4 of the documentation system build-out.)*

## Introduction to Elmtui Widgets

*   **What is a Widget/Component?**
    *   Reusable building blocks of the UI.
    *   Encapsulates state, view logic, and event handling.
*   **Core Principles:**
    *   Declarative definition.
    *   Composition over inheritance (usually).
    *   Adherence to the Elmtui state management model.

## Basic Widget Structure

(This section will detail the typical structure of an Elmtui widget definition, likely involving `defwidget` or a similar macro if provided by Elmtui, or standard `defclass` and method specializations.)

```lisp
;; Hypothetical example - to be replaced with actual Elmtui syntax
(elmtui:defwidget my-custom-widget (props state)
  (:initial-state
   (list :counter 0))

  (:view (widget-props widget-state)
   (elmtui:view
     (elmtui:button :on-click (lambda () (elmtui:send-msg widget :increment))
                    (format nil "Count: ~a" (getf widget-state :counter)))))

  (:update (msg widget-props widget-state)
    (case (getf msg :type)
      (:increment (list (elmtui:update-state widget-state :counter (1+ (getf widget-state :counter)))
                        nil)) ; No command
      (otherwise (list widget-state nil)))))
```

## Key Aspects of Widget Development

### 1. Defining Properties (`props`)
*   How to define input properties that can be passed to a widget.
*   Type checking or validation for props.

### 2. Managing Internal State (`state`)
*   Defining the initial state of a widget.
*   How the widget's internal state is structured and accessed.
*   The role of immutability if applicable.

### 3. Defining the View Logic
*   Using Elmtui's view DSL to describe the widget's appearance.
*   How to render child widgets.
*   Conditional rendering based on props or state.
*   Applying styles.

### 4. Handling Events and Messages (`update` / `msg`)
*   How widgets receive and process messages (e.g., user input, internal events).
*   Updating the widget's state in response to messages.
*   Emitting messages or commands to parent components or the application.

### 5. Widget Lifecycle (if applicable)
*   Methods or hooks for initialization, mounting, unmounting, etc.

### 6. Styling Widgets
*   How to apply styles defined in the Elmtui styling system.
*   Defining default styles for a widget.
*   Allowing users to override styles.

### 7. Focus Management
*   How widgets participate in focus management (if they are interactive).
*   Making a widget focusable.
*   Handling focus and blur events.

### 8. Keymap Integration
*   Defining local keymaps for a widget.
*   How widget keymaps interact with global keymaps.

## Best Practices for Widget Development

*   **Keep Widgets Focused:** Each widget should have a clear, single responsibility.
*   **Aim for Reusability:** Design widgets to be usable in different contexts.
*   **Clear API:** Define clear and understandable properties for your widget.
*   **Performance Considerations:** Be mindful of performance, especially for frequently updated or complex widgets.
*   **Documentation:** Provide good docstrings for your widget and its properties.
*   **Testing:** Write unit tests for your widget's functionality.

## Example: A Simple Counter Widget

(A step-by-step example of creating a basic widget, like a counter button, will be provided here, illustrating the concepts above.)

## Advanced Topics

*   Creating container widgets (widgets that manage children).
*   Inter-widget communication.
*   Asynchronous operations within widgets.

---
*This guide will be significantly expanded by integrating existing documentation and adding detailed examples based on Elmtui's specific APIs and conventions.*