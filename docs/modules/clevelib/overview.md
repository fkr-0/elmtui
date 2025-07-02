---
# AI Metadata Tags
ai_keywords: [Clevelib, CFFI, Thread Primitives, Channel, Message Passing, Terminal Helpers, Mutex, Condition Variable, Native Bindings]
ai_contexts: [architecture, implementation, development]
ai_relations: [
  "./implementation.md",
  "../platform/overview.md",
  "../core/overview.md",
  "../../architecture/system-overview.md",
  "../../architecture/tech-stack.md",
  "../../architecture/module-dependencies.md"
]
---

# Clevelib Module Overview

<!-- AI-IMPORTANCE:level=normal -->
## Core Functionality

The `clevelib` module provides a focused set of low-level primitives for Elmtui, implemented via CFFI bindings to native system libraries. Its main responsibilities are thread creation and management, inter-thread communication (channels, message queues), and select terminal control helpers. It does **not** provide a general-purpose event system, async I/O, or memory management abstraction.

## Main Features

- **Thread Primitives:** Creation, joining, and synchronization of native threads
- **Channels:** Simple, thread-safe message passing between threads
- **Mutexes & Condition Variables:** Synchronization primitives for safe concurrent code
- **Terminal Helpers:** Minimal wrappers for raw mode and terminal state (used by platform module)
- **CFFI Bindings:** Safe, minimal interfaces to required C/system functions

<!-- AI-CONTEXT-START:type=architecture -->
## Architectural Role

`clevelib` is the lowest-level utility layer in Elmtui. It exposes only the minimal set of primitives needed by higher-level modules:
- The [`platform`](../platform/overview.md) module uses clevelib for terminal state and raw mode helpers.
- The [`core`](../core/overview.md) and [`app`](../app/overview.md) modules use clevelib for thread and channel primitives to implement event loops and background workers.

All higher-level event processing, async logic, and resource management are handled outside clevelib.

### Key Components
- **API Layer ([src/clevelib/api.lisp](src/clevelib/api.lisp:1)):** Public interface for thread, channel, and terminal helpers
- **Threading ([src/clevelib/thread.lisp](src/clevelib/thread.lisp:1)):** Native thread and synchronization primitives
- **Channel System ([src/clevelib/channel.lisp](src/clevelib/channel.lisp:1)):** Simple message channels for inter-thread communication
- **Terminal Control ([src/clevelib/target.lisp](src/clevelib/target.lisp:1)):** Minimal helpers for terminal state

<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
## Usage Examples

### Threading

```lisp
;; Create and start a thread
(let ((worker (clevelib:make-thread (lambda () (do-work)))))
  (clevelib:join-thread worker))
```

### Channels

```lisp
;; Create a channel and send/receive a message
(let ((ch (clevelib:make-channel)))
  (clevelib:send-message ch :ping)
  (let ((msg (clevelib:receive-message ch)))
    (process-message msg)))
```

### Mutexes

```lisp
(let ((mutex (clevelib:make-mutex)))
  (clevelib:with-mutex (mutex)
    ;; critical section
    (update-shared-state)))
```

### Terminal Helpers

```lisp
(clevelib:with-raw-terminal ()
  ;; Terminal is in raw mode here
  (read-raw-input))
```

<!-- AI-CONTEXT-END -->

## Related Resources

- [Implementation Details](./implementation.md)
- [Platform Module Overview](../platform/overview.md)
- [Core Module Overview](../core/overview.md)
- [System Architecture Overview](../../architecture/system-overview.md)
- [Technology Stack](../../architecture/tech-stack.md)
- [Module Dependencies](../../architecture/module-dependencies.md)
- [CFFI Documentation](https://cffi.common-lisp.dev/)