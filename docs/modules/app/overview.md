---
# AI Metadata Tags
ai_keywords: [App Module, Application Lifecycle, Main Loop, Application Orchestration, Startup, Shutdown, Elmtui Application, defapplication, run-application]
ai_contexts: [architecture, usage, development]
ai_relations: [
  "./implementation.md",
  "../core/overview.md",
  "../state/overview.md",
  "../ui/overview.md",
  "../platform/overview.md",
  "../../architecture/system-overview.md",
  "../../architecture/core-concepts.md",
  "../../architecture/module-dependencies.md",
  "../../examples/rainbow-app.md"
]
---

# App Module Overview

<!-- AI-IMPORTANCE:level=critical -->
## Core Functionality

The `app` module serves as the top-level orchestrator for Elmtui applications. It manages the complete application lifecycle from startup to shutdown, coordinates between core modules, and provides the primary entry points for running Elmtui applications. This module implements the main application loop that ties together event processing, state management, view rendering, and platform interaction.

## Main Features

- **Application Definition:** Provides [`defapplication`](src/app/application.lisp:1) macro for declaratively defining Elmtui applications
- **Application Startup:** Implements [`run-application`](src/app/api-impl.lisp:1) function for launching applications from specifications
- **Lifecycle Management:** Handles initialization, main loop execution, and cleanup phases
- **Module Coordination:** Orchestrates interactions between [`core`](../core/overview.md), [`state`](../state/overview.md), [`ui`](../ui/overview.md), [`view`](../view/overview.md), and [`platform`](../platform/overview.md) modules
- **Root Component Management:** Manages the top-level application component and its state

<!-- AI-CONTEXT-START:type=architecture -->
## Architectural Design

The `app` module sits at the highest level of the Elmtui architecture, acting as the coordinator for all other modules. It implements the main application pattern where:

### Key Components
- **Application Specification:** A declarative description of an application (name, init function, update function, view function, etc.)
- **Application Runner:** The [`run-application`](src/app/api-impl.lisp:1) function that takes a specification and executes the application
- **Main Loop Integration:** Coordinates with the [`core`](../core/overview.md) module's event loop to process application-level events

### Application Lifecycle
1. **Initialization Phase:** Set up application state, initialize platform backend, create root component
2. **Main Loop Phase:** Run the event processing loop, handle state updates, trigger view re-renders
3. **Shutdown Phase:** Clean up resources, restore terminal state, terminate gracefully
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=usage -->
## How to Use

### Defining an Application

`defapplication` is the normative full application constructor selected for the
next stable major version. It is the production entry point for state/component
initialization, CLI/binary configuration, keymaps, subscriptions, and generated
runners. `deftea-app` remains supported as a smaller direct-transition adapter
for teaching and deliberately minimal applications; both feed the same runtime
transition specification.

```lisp
;; Using defapplication macro (normative production approach)
(defapplication my-app
  :root-viewport-id :main-root-vp
  :initial-state-plist (my-init)
  :root-component-dsl (list (my-view nil))
  :update-fn 'my-update
  :view-fn 'my-view
  :subscriptions-fn (lambda (model) ...))

;; This generates a RUN-MY-APP function
(run-my-app)
```

### Running Applications Directly

```lisp
;; Using run-application with specification plist
(elmtui.app.api:run-application
  (list :name 'my-app
        :init-fn #'my-init
        :update-fn #'my-update
        :view-fn #'my-view
        :subscriptions-fn #'my-subs
        :message-queue my-queue
        :root-viewport-id :main-root-vp)
  :backend-type :terminal
  :platform-options '(:tty-path "/dev/tty"))
```

### Integration with TEA Pattern

The app module fully supports The Elm Architecture pattern:
- **Model:** Application state managed by the [`state`](../state/overview.md) module
- **View:** UI structure defined using the [`view`](../view/overview.md) DSL
- **Update:** State transitions handled by update functions
<!-- AI-CONTEXT-END -->

## Related Resources

- [Implementation Details](./implementation.md)
- [Core Module Overview](../core/overview.md)
- [State Module Overview](../state/overview.md)
- [UI Module Overview](../ui/overview.md)
- [Platform Module Overview](../platform/overview.md)
- [Rainbow App Example](../../examples/rainbow-app.md)
- [System Architecture Overview](../../architecture/system-overview.md)
- [Core Concepts](../../architecture/core-concepts.md)
- [Module Dependencies](../../architecture/module-dependencies.md)