---
# AI Metadata Tags
ai_keywords: [Core, Event Loop, Event System, Message Bus, Focus Management, Asynchronous Tasks, Elmtui Core]
ai_contexts: [architecture, usage, development, implementation]
ai_relations: ["./implementation.md", "../app/overview.md", "../platform/overview.md", "../state/overview.md", "../ui/overview.md", "../../architecture/system-overview.md", "../../architecture/module-dependencies.md", "../../architecture/core-concepts.md"]
---

# Core Module Overview

<!-- AI-IMPORTANCE:level=critical -->
## Core Functionality

The `core` module is the heart of the Elmtui runtime. It provides fundamental services essential for any TUI application built with Elmtui. This includes the main event processing loop, the event/message dispatch system, focus management, and potentially mechanisms for handling asynchronous operations.

## Main Features

- **Event Loop:** Manages the central loop that processes input, timers, and other events.
- **Event/Message System:** Defines how events (e.g., key presses, mouse clicks, custom messages) are represented, dispatched, and handled.
- **Focus Management:** Tracks which UI component currently has input focus and handles focus traversal.
- **Asynchronous Task Management:** (If applicable) Provides utilities for running background tasks without blocking the UI.
- **Global Services:** May host other essential global services or registries.
- **Initialization and Shutdown:** Handles setup and teardown of core Elmtui systems.

<!-- AI-CONTEXT-START:type=architecture -->
## Architectural Design

The `core` module acts as a central hub, coordinating between the `platform` (for raw input/output), `app` (for application lifecycle), `ui` (for event handling in components), and `state` (for reacting to events).

### Key Components (Conceptual)
- **Event Queue/Channel:** A mechanism for queuing incoming events.
- **Event Dispatcher:** Logic for routing events to the appropriate handlers (e.g., the focused component, global handlers).
- **Focus Manager:** A system that keeps track of the focusable components and the currently focused one.
- **Timer Service:** (If applicable) Manages scheduled events or callbacks.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=usage -->
## How to Use

Much of the `core` module's functionality is used implicitly when building an Elmtui application. For example, the event loop is started by the `app` module, and components automatically participate in the event and focus systems.

Direct interaction by application developers might involve:
- **Sending Custom Messages:** Programmatically dispatching messages through the core event system.
- **Registering Global Event Handlers:** (If supported) For application-wide event interception.
- **Programmatically Managing Focus:** Requesting focus for a specific component.

### Common Scenarios
- An input event (key press) is received by `platform`, passed to `core`.
- `core` determines the focused component and dispatches the event to it.
- The component's event handler processes the event, potentially updating its state or sending a message.
<!-- AI-CONTEXT-END -->

## Related Resources

- [Implementation Details](./implementation.md)
- [App Module Overview](../app/overview.md)
- [Platform Module Overview](../platform/overview.md)
- [UI Module Overview](../ui/overview.md)
- [State Module Overview](../state/overview.md)
- [System Overview](../../architecture/system-overview.md)
- [Module Dependencies](../../architecture/module-dependencies.md)
- [Core Concepts](../../architecture/core-concepts.md)