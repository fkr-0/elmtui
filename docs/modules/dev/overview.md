---
# AI Metadata Tags
ai_keywords: [Dev Module, Development Tools, Debugging, Introspection, Event Monitoring, Transaction Viewer, View Debug, Performance Tools, Development Utilities]
ai_contexts: [development, debugging, meta]
ai_relations: [
  "./implementation.md",
  "../app/overview.md",
  "../core/overview.md",
  "../state/overview.md",
  "../ui/overview.md",
  "../view/overview.md",
  "../utils/overview.md",
  "../../architecture/system-overview.md",
  "../../architecture/module-dependencies.md",
  "../../dev-guides/troubleshooting.md"
]
---

# Dev Module Overview

<!-- AI-IMPORTANCE:level=normal -->
## Core Functionality

The `dev` module provides development and debugging tools for Elmtui applications. It includes utilities for monitoring events, inspecting component state, visualizing transactions, debugging view generation, and profiling performance. This module is essential for developers building and debugging Elmtui applications.

## Main Features

- **Event Monitoring:** Real-time event flow inspection and logging
- **State Debugging:** Component and application state introspection tools
- **Transaction Visualization:** Visual representation of state transactions and changes
- **View Debugging:** Tools for inspecting view generation and rendering pipeline
- **Performance Profiling:** Timing and performance analysis utilities
- **Component Introspection:** Deep inspection of component lifecycle and behavior
- **Development Server:** Live development environment with hot reloading capabilities
- **Error Analysis:** Enhanced error reporting and stack trace analysis

<!-- AI-CONTEXT-START:type=architecture -->
## Architectural Design

The `dev` module operates as a meta-layer over the core Elmtui functionality, providing observability and debugging capabilities without interfering with production code.

### Key Components
- **Development Framework ([`src/dev/dev.lisp`](src/dev/dev.lisp:1)):** Core development utilities and setup
- **Event Monitor ([`src/dev/event-monitor.lisp`](src/dev/event-monitor.lisp:1)):** Real-time event tracking and analysis
- **Event Throttling ([`src/dev/event-throttler.lisp`](src/dev/event-throttler.lisp:1)):** Performance testing with controlled event rates
- **Transaction Viewer ([`src/dev/transaction-viewer.lisp`](src/dev/transaction-viewer.lisp:1)):** Visual state transaction inspection
- **View Debugger ([`src/dev/view-debug.lisp`](src/dev/view-debug.lisp:1)):** View generation and rendering debugging
- **Deprecation System ([`src/dev/deprecation.lisp`](src/dev/deprecation.lisp:1)):** API deprecation warnings and migration helpers

### Design Principles
- **Non-intrusive:** Development tools don't affect production performance
- **Modular:** Each tool can be enabled/disabled independently
- **Real-time:** Live monitoring and inspection capabilities
- **Visual:** Graphical representations where helpful
- **Extensible:** Easy to add new development tools
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
## How to Use

### Event Monitoring

```lisp
;; Start event monitoring
(dev:start-event-monitor 
  :output-stream *standard-output*
  :filter (lambda (event) (eq (event-type event) :input))
  :format :detailed)

;; Monitor specific event types
(dev:monitor-events '(:input :state-change :render)
  (lambda (event)
    (format t "Event: ~A at ~A~%" event (get-universal-time))))

;; Event statistics
(dev:get-event-statistics :since (- (get-universal-time) 60))
```

### State Debugging

```lisp
;; Inspect component state
(dev:inspect-component my-component)
(dev:show-component-state my-component :detailed t)

;; Watch state changes
(dev:watch-state-changes 
  (lambda (old-state new-state changes)
    (format t "State changed: ~A~%" changes)))

;; State history
(dev:show-state-history :limit 10)
(dev:replay-state-changes :from-timestamp timestamp)
```

### Transaction Debugging

```lisp
;; Enable transaction viewer
(dev:enable-transaction-viewer)

;; Manual transaction inspection
(dev:inspect-transaction transaction-id)
(dev:show-transaction-tree :show-rollbacks t)

;; Transaction performance analysis
(dev:analyze-transaction-performance :group-by :operation-type)
```

### View Debugging

```lisp
;; Enable view debugging
(dev:enable-view-debugging 
  :show-dsl-forms t
  :highlight-changes t
  :show-performance t)

;; Inspect view generation
(dev:debug-view-generation my-component)
(dev:show-view-tree my-component :expand-all t)

;; View diff analysis
(dev:compare-view-trees old-tree new-tree)
```

### Performance Profiling

```lisp
;; Profile application performance
(dev:start-profiling :components t :rendering t :events t)

;; Get performance report
(dev:get-performance-report 
  :format :table
  :sort-by :total-time
  :limit 20)

;; Memory usage analysis
(dev:analyze-memory-usage :group-by :component-type)

;; Benchmark operations
(dev:benchmark
  (lambda () (expensive-operation))
  :iterations 1000
  :warmup 100)
```

### Development Server

```lisp
;; Start development server with hot reloading
(dev:start-dev-server 
  :port 8080
  :watch-directories '("src/" "examples/")
  :auto-reload t
  :debug-mode t)

;; Development configuration
(dev:configure-development
  :log-level :debug
  :show-warnings t
  :enable-all-monitors t)
```

### Component Introspection

```lisp
;; Deep component analysis
(dev:analyze-component my-component
  :show-lifecycle t
  :show-props t
  :show-state-history t
  :show-event-handlers t)

;; Component dependency graph
(dev:show-component-dependencies 
  :root-component app-root
  :format :graphviz)

;; Component performance
(dev:profile-component my-component :duration 60)
```
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=implementation -->
## Implementation Notes

### Development vs Production
- **Conditional Compilation:** Development tools are conditionally compiled
- **Feature Flags:** Runtime flags control which development features are active
- **Performance Impact:** Minimal overhead when development tools are disabled
- **Clean Separation:** Development code is clearly separated from production code

### Tool Integration
- **REPL Integration:** All development tools work seamlessly with the REPL
- **IDE Support:** Tools designed to work with Lisp IDEs and editors
- **External Tools:** Integration with external debugging and profiling tools
- **Web Interface:** Some tools provide web-based interfaces for better visualization

### Data Collection
- **Event Logging:** Comprehensive event logging with configurable detail levels
- **State Snapshots:** Automatic state snapshots at key points
- **Performance Metrics:** Detailed timing and memory usage metrics
- **Error Tracking:** Enhanced error information collection and reporting
<!-- AI-CONTEXT-END -->

## Related Resources

- [Implementation Details](./implementation.md)
- [Troubleshooting Guide](../../dev-guides/troubleshooting.md)
- [App Module Overview](../app/overview.md)
- [Core Module Overview](../core/overview.md)
- [State Module Overview](../state/overview.md)
- [UI Module Overview](../ui/overview.md)
- [View Module Overview](../view/overview.md)
- [Utils Module Overview](../utils/overview.md)
- [System Architecture Overview](../../architecture/system-overview.md)
- [Module Dependencies](../../architecture/module-dependencies.md)