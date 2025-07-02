---
# AI Metadata Tags
ai_keywords: [UI Implementation, Component Internals, Widget Internals, Defcomponent Macro, CLOS, init method, update method, view method, Component Lifecycle, Event Handling in Components, Props Management]
ai_contexts: [implementation, development]
ai_relations: ["./overview.md", "../core/implementation.md", "../state/implementation.md", "../view/implementation.md", "../app/implementation.md", "../../architecture/core-concepts.md", "../../architecture/system-overview.md", "../../architecture/module-dependencies.md", "../../dev-guides/creating-widgets.md"]
---

# UI Module Implementation Details

<!-- AI-IMPORTANCE:level=critical -->
## Technical Overview

The `ui` module's implementation revolves around the `defcomponent` macro (found in `src/ui/defcomponent.lisp`), which is the primary mechanism for creating new UI components. This macro likely expands into a CLOS class definition along with methods for initialization (`init`), state updates (`update`), view rendering (`view`), and potentially other lifecycle or event handling concerns. The `src/ui/widgets/` directory contains concrete examples of components built using this system, such as `src/ui/widgets/root-viewport.lisp`.

<!-- AI-CONTEXT-START:type=implementation -->
## Core Implementation

### `defcomponent` Macro
- **Expansion:**
  - `defcomponent` generates a standard CLOS class that inherits from `elmtui.ui.api:component`.
  - It automatically defines methods for `init`, `update`, and `view` based on the clauses provided in the macro body.
- **State Management:**
  - The `:state` clause defines the local state schema for the component.
  - State is stored in the global application state, not in the component instance itself, to facilitate a centralized state management model.
- **Syntax:**
  ```lisp
  (defcomponent component-name (superclass1)
    (:state
     (slot1-name initial-value1 :type type :accessor accessor-name1)
     (slot2-name initial-value2 :type type :accessor accessor-name2))
    (:init (props self-id-path)
      ;; ... returns (values initial-local-state-plist initial-commands)
    )
    (:update (msg local-state-map app-state self-id-path)
      ;; ... returns (values local-changes-plist commands)
    )
    (:view (local-state-map app-state self-id-path)
      ;; ... returns view DSL
    ))
  ```

### Component Instance
- Each instance of a component in the UI tree is an object of the class defined by `defcomponent`.
- It holds an `id` which is used to access its state from the global application state.

### Props Handling
- Props are passed as keyword arguments to the `init` method.
- The `defcomponent` system makes these props available to the `:init` clause.

### Local State Management
- The `:init` clause defines the initial local state.
- The `:update` clause is responsible for transforming the local state based on messages. This aligns with the `state` module's principles.
- The state is typically immutable or updated in a controlled manner.

### Event Handling
- **High-level (`:update`):** Components primarily handle "semantic" messages via their `:update` clause, interacting with the `state` module.
- **Low-level (`:handle-event`):** An optional `:handle-event` clause might allow components to directly process raw input events (key, mouse) from the `core` module if they need finer-grained control before these are translated into messages. This could be used for complex input interactions.
- Event handlers determine whether to update local state, emit messages (to self, parent, or globally), or produce commands.

### Standard Widgets (`src/ui/widgets/`)
- This directory contains pre-built components like:
    - `root-viewport`: Manages the top-level view. (`src/ui/widgets/root-viewport.lisp`)
    - Buttons, labels, input fields, lists, layout containers (e.g., box, flexbox, grid).
- These serve as examples of how to use `defcomponent` and provide reusable UI elements.

### Component Lifecycle (if explicitly managed)
- **`:on-mount`:** Called when a component is added to the UI tree and becomes active.
- **`:on-unmount`:** Called when a component is removed from the UI tree, for cleanup.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
## Development Guide

### Creating a New Component
1.  Use `elmtui:defcomponent`.
2.  Define the `:init` clause to set up initial local state, often based on `initial-props`.
3.  Implement the `:update` clause to handle messages relevant to the component, updating its local state and optionally returning a new global state or commands.
4.  Implement the `:view` clause using the `elmtui-view` DSL to describe the component's appearance based on its current `props` and `local-state`.
5.  Optionally, implement other clauses like `:handle-event` for direct input processing or lifecycle hooks.

### Best Practices
- Keep components focused on a single responsibility.
- Prefer passing data down as props and emitting messages up for actions.
- Make local state as simple as possible.
- Refer to existing widgets in `src/ui/widgets/` for examples.

### Important Notes
- The `props-arg`, `state-arg`, and `global-state-arg` in `defcomponent` are symbols that will be bound to the respective data within the clauses.
- The `view` function is called whenever the component needs to be re-rendered (e.g., after its state changes or its parent re-renders).
<!-- AI-CONTEXT-END -->

## Testing Strategy

*   Unit test individual components:
    - Test the `:init` clause for correct initial state.
    - Test the `:update` clause with various messages to ensure correct state transitions and command generation.
    - Test the `:view` clause by checking the structure of the returned view representation (this might involve comparing against expected s-expressions or similar).
*   Test event handling logic within `:handle-event` if used.
*   Test lifecycle hooks if implemented.
*   `tests/component-init-tests.lisp` provides examples of component testing.

## Known Limitations

*   (e.g., Complexity of managing deeply nested component state, performance of re-rendering large component trees if not optimized.)

## Related Resources

- [UI Module Overview](./overview.md)
- [Core Module Implementation Details](../core/implementation.md)
- [State Module Implementation Details](../state/implementation.md)
- [View Module Implementation Details](../view/implementation.md)
- [App Module Implementation Details](../app/implementation.md)
- [Core Concepts: Component Model](../../architecture/core-concepts.md#1-component-model)
- [System Overview](../../architecture/system-overview.md)
- [Module Dependencies](../../architecture/module-dependencies.md)
- [Creating Widgets Guide](../../dev-guides/creating-widgets.md)