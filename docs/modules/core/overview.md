---
# AI Metadata Tags
ai_keywords: [Core Module, Event Loop, Focus Management, Message Bus, Event Handling, Asynchronous Processing, Input Processing, Topic Registry, Event Channels]
ai_contexts: [architecture, development, implementation]
ai_relations: [
  "./implementation.md",
  "../app/overview.md",
  "../platform/overview.md",
  "../ui/overview.md",
  "../state/overview.md",
  "../clevelib/overview.md",
  "../../architecture/system-overview.md",
  "../../architecture/core-concepts.md",
  "../../architecture/module-dependencies.md"
]
---

# Core Module Overview

<!-- AI-IMPORTANCE:level=critical -->
## Core Functionality

The `core` module provides the fundamental infrastructure for Elmtui applications. It implements the main event loop, handles asynchronous processing, manages input focus, and provides the message bus system that enables communication between components. This module serves as the backbone of the entire Elmtui framework, coordinating between user input, state updates, and view rendering.

## Main Features

- **Event Loop:** Main processing loop that handles input events, state updates, and rendering cycles
- **Focus Management:** Tracks and manages which UI component currently has input focus
- **Message Bus:** Pub/sub system for component communication using topics and event channels
- **Asynchronous Processing:** Thread management and async task coordination
- **Input Processing:** Raw input event handling and dispatch to focused components
- **Topic Registry:** Registration and management system for message topics
- **Event Channels:** Typed communication channels for different kinds of events

<!-- AI-CONTEXT-START:type=architecture -->
## Architectural Design

The `core` module implements a reactive event-driven architecture that forms the foundation of Elmtui applications.

### Key Components
- **Main Event Loop ([`src/core/loop.lisp`](src/core/loop.lisp:1)):** Central processing loop that coordinates all system activities
- **Topic Registry ([`src/core/topic-registry.lisp`](src/core/topic-registry.lisp:1)):** Manages registration and lookup of message topics
- **Event Channels ([`src/core/event-channels.lisp`](src/core/event-channels.lisp:1)):** Provides typed communication channels
- **Focus Manager ([`src/core/focus/manager.lisp`](src/core/focus/manager.lisp:1)):** Manages which component receives input events
- **Async Processing ([`src/core/async.lisp`](src/core/async.lisp:1)):** Handles background tasks and thread coordination
- **Message Bus ([`src/core/message-bus.lisp`](src/core/message-bus.lisp:1)):** Pub/sub event distribution system

### Event Flow
1. **Input Capture:** Raw input events received from [`platform`](../platform/overview.md) module
2. **Event Processing:** Events are parsed, validated, and routed through the message bus
3. **Focus Dispatch:** Input events are sent to the currently focused UI component
4. **State Updates:** Components process events and trigger state changes via [`state`](../state/overview.md) module
5. **View Re-rendering:** State changes trigger view updates through [`view`](../view/overview.md) module
6. **Output:** Rendered output sent back to [`platform`](../platform/overview.md) for display
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
## How to Use

### Focus Management

```lisp
;; Request focus for a component
(elmtui.core.focus:request-focus my-component)

;; Get currently focused component
(elmtui.core.focus:get-current-focus)

;; Check if component has focus
(elmtui.core.focus:has-focus-p my-component)
```

### Message Bus and Topics

```lisp
;; Register a topic
(elmtui.core.topics:register-topic :user-input :event-type :input)

;; Subscribe to a topic
(elmtui.core.topics:subscribe :user-input my-handler-function)

;; Publish to a topic
(elmtui.core.topics:publish :user-input my-event-data)
```

### Event Channels

```lisp
;; Create an event channel
(defparameter *my-channel* 
  (elmtui.core.event-channels:make-event-channel :input))

;; Send an event
(elmtui.core.event-channels:send-event *my-channel* my-event)

;; Receive events (blocking)
(elmtui.core.event-channels:receive-event *my-channel*)
```

### Asynchronous Processing

```lisp
;; Submit a background task
(elmtui.core.async:submit-task 
  (lambda () (expensive-computation))
  :on-complete (lambda (result) (handle-result result)))

;; Coordinate with main thread
(elmtui.core.async:run-in-main-thread 
  (lambda () (update-ui-safely)))
```
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=implementation -->
## Implementation Notes

### Thread Model
- **Main Thread:** Runs the primary event loop and handles all UI operations
- **Input Thread:** Dedicated thread for reading raw input from terminal
- **Background Threads:** Thread pool for handling async computations
- **Synchronization:** Careful coordination to ensure thread-safe operations

### Performance Considerations
- **Event Batching:** Multiple events can be processed together for efficiency
- **Focus Caching:** Focus information is cached to avoid repeated lookups
- **Message Filtering:** Events can be filtered before dispatch to reduce overhead
- **Memory Management:** Event objects are pooled and reused where possible
<!-- AI-CONTEXT-END -->

## Related Resources

- [Implementation Details](./implementation.md)
- [App Module Overview](../app/overview.md)
- [Platform Module Overview](../platform/overview.md)
- [UI Module Overview](../ui/overview.md)
- [State Module Overview](../state/overview.md)
- [System Architecture Overview](../../architecture/system-overview.md)
- [Core Concepts](../../architecture/core-concepts.md)
- [Module Dependencies](../../architecture/module-dependencies.md)