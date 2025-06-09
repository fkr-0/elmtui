---
# AI Metadata Tags
ai_keywords: [UI, Component, Widget, View, Defcomponent, User Interface, Element, Control, UI Toolkit, Component Lifecycle, Props, Local State, Event Handling]
ai_contexts: [architecture, usage, development, implementation]
ai_relations: ["./implementation.md", "../core/overview.md", "../state/overview.md", "../view/overview.md", "../../dev-guides/creating-widgets.md", "../../architecture/core-concepts.md", "../../architecture/system-overview.md", "../../architecture/module-dependencies.md"]
---

# UI Module Overview

<!-- AI-IMPORTANCE:level=critical -->
## Core Functionality

The `ui` module is responsible for defining and managing UI components (also referred to as widgets or elements) in Elmtui. It provides the foundational tools and abstractions for creating reusable pieces of user interface, handling their local state, processing events, and defining their appearance via the `view` module. The `defcomponent` macro (likely in `src/ui/defcomponent.lisp`) is central to this.

## Main Features

- **Component Definition:** Provides a macro or system (e.g., `defcomponent` from `src/ui/defcomponent.lisp`) for defining new UI components.
- **Component Lifecycle:** (If applicable) Manages aspects of a component's lifecycle (e.g., initialization, mounting, unmounting).
- **Local State Management:** Allows components to have their own internal state, managed according to Elmtui's state principles (likely TEA-inspired via the `state` module).
- **Event Handling:** Defines how components receive and process events (e.g., key presses, mouse events, custom messages) and update their local state or emit messages.
- **Props/Attributes:** Allows components to receive input data (properties) from their parent components.
- **Composition:** Facilitates building complex UIs by composing simpler components.
- **Standard Widget Library:** May include a set of pre-built, common UI widgets (buttons, labels, input fields, lists, etc.), often in a `ui/widgets/` subdirectory (e.g., `src/ui/widgets/root-viewport.lisp`).

<!-- AI-CONTEXT-START:type=architecture -->
## Architectural Design

The `ui` module forms the building blocks of the visual part of an Elmtui application. Components defined here are organized into a tree structure. Each component is responsible for a piece of the UI and its associated logic.

### Key Concepts
- **Component:** A self-contained unit of UI with its own state, update logic, and view.
- **Props:** Input data passed to a component.
- **Local State:** Data managed internally by a component.
- **View Function:** A function associated with a component that describes its visual representation based on its props and local state, typically using the `view` module's DSL.
- **Event Handlers/Update Logic:** Functions within a component that respond to events/messages, often interacting with the `state` module's `update` mechanism.

### Component Tree
- Applications are built as a tree of components, with a single root component.
- Events and data flow through this tree.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=usage -->
## How to Use

Application developers primarily use the `ui` module to:
- **Define Custom Components:** Using `elmtui:defcomponent` or similar.
  ```lisp
  ;; (elmtui:defcomponent my-button (props state)
  ;;   (:init (initial-props) (list :label (getf initial-props :label "Click Me")))
  ;;   (:update (msg model) ...)
  ;;   (:view (props state) (elmtui-view:button (getf state :label) ...)))
  ```
- **Use Pre-built Widgets:** Instantiating and configuring standard widgets provided by Elmtui.
- **Compose Components:** Arranging components within the `view` function of parent components to build the UI hierarchy.

### Common Scenarios
- Creating a button that increments a counter in its local state.
- Building a form with input fields and a submit button.
- Displaying a list of items based on application state.

*(Refer to `src/ui/defcomponent.lisp` and `src/ui/widgets/` for concrete examples and APIs.)*
<!-- AI-CONTEXT-END -->

## Related Resources

- [Implementation Details](./implementation.md)
- [Creating Widgets Guide](../../dev-guides/creating-widgets.md)
- [View Module Overview