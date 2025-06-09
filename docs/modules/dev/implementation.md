---
# AI Metadata Tags
ai_keywords: [Dev Implementation, Debug Tools Internals, REPL Integration, Tracing Hooks, Profiling Adapters, Conditional Compilation]
ai_contexts: [implementation, development]
ai_relations: ["./overview.md", "../core/implementation.md", "../view/implementation.md", "../ui/implementation.md", "../platform/implementation.md", "../../architecture/system-overview.md", "../../architecture/module-dependencies.md"]
---

# Dev Module Implementation Details

<!-- AI-IMPORTANCE:level=normal -->
## Technical Overview

The `dev` module's implementation involves creating hooks into the Elmtui core systems to extract debugging information or inject control commands. This might include custom rendering passes for visual debuggers, wrappers around event handlers for tracing, or interfaces to Lisp's built-in inspection and profiling tools.

<!-- AI-CONTEXT-START:type=implementation -->
## Core Implementation

### Debug Overlays / Visualizers
- **Hooking into Rendering:** How the `dev` module integrates with the `view` or `platform` rendering pipeline to draw additional debug information (e.g., component boundaries, layout boxes, refresh regions).
- **Data Structures:** Storing information about what to visualize.
```lisp
;; Hypothetical: A special variable to enable layout bounds drawing
;; (defvar *draw-layout-bounds* nil)

;; In the rendering logic (view/platform module):
;; (when elmtui-dev:*draw-layout-bounds*
;;   (draw-debug-rectangle (component-x c) (component-y c) (component-width c) (component-height c)))
```

### REPL Integration
- **Accessing Application State:** Functions to get a handle to the current application instance, focused component, or component tree from the REPL.
  ```lisp
  ;; (defun current-app () *elmtui-current-application-instance*) ; If such a var exists
  ;; (defun find-component-by-id (app id) ...)
  ```
- **Invoking Actions:** REPL functions to trigger actions like requesting focus, sending messages to components, or forcing a re-render.

### Event Tracing
- **Wrapping Event Handlers:** Potentially using Lisp's method combination or advice to wrap event dispatch or component event handlers to log event details.
- **Filtering and Formatting:** Options to filter traced events and format the output.

### Performance Monitoring Hooks
- **Timing Wrappers:** Functions to wrap around critical sections (e.g., render cycle, event processing) to measure execution time.
- **Data Aggregation:** Simple mechanisms to collect and display timing data.
  ```lisp
  ;; (defmacro with-timing ((&optional (label "Operation")) &body body)
  ;;   `(let ((start (get-internal-real-time)))
  ;;      (unwind-protect (progn ,@body)
  ;;        (let ((end (get-internal-real-time)))
  ;;          (format t "~a took ~,3f ms~%" ,label (/ (- end start) internal-time-units-per-millisecond))))))
  ```

### Conditional Compilation
- Extensive use of feature flags (e.g., `:elmtui-dev-mode`) to ensure that debugging code is not compiled into production builds.
  ```lisp
  ;; #+elmtui-dev-mode
  ;; (defun expensive-debug-check (object) ...)
  ;;
  ;; #-elmtui-dev-mode
  ;; (defun expensive-debug-check (object) (declare (ignore object)) nil)
  ```
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
## Development Guide

### Key Public APIs (for Elmtui Developers)
*   `elmtui-dev:enable-tracing (&key event-types components)`
*   `elmtui-dev:disable-tracing ()`
*   `elmtui-dev:inspect-component-tree (app-instance)`
*   `elmtui-dev:show-layout-bounds (boolean-flag)`
*   `elmtui-dev:profile-render-pass (boolean-flag)`

### Important Notes
*   Most `dev` module functions should be designed to be callable from a Lisp REPL connected to a running Elmtui application.
*   Be cautious about the performance overhead of enabled debugging tools.
*   Ensure that dev tools do not inadvertently alter application state in unexpected ways unless that is their explicit purpose.

### Adding New Dev Tools
1.  Identify the information or control needed.
2.  Find appropriate hook points in the core Elmtui modules.
3.  Implement the tool, ensuring it can be conditionally compiled.
4.  Provide clear REPL-callable functions to enable/disable or use the tool.
<!-- AI-CONTEXT-END -->

## Testing Strategy

*   Testing that dev tools can be enabled and disabled correctly.
*   Verifying that enabling dev tools does not break core application functionality.
*   Testing that the information provided by dev tools is accurate (e.g., component state inspection).
*   (Testing visual debuggers might require specialized approaches, possibly manual or snapshot-based if a "faketerm" renderer is available).

## Known Limitations

*   Some debugging tools might have a noticeable performance impact.
*   The level of introspection might be limited by the design of the core modules.

## Related Resources
- [Dev Module Overview](./overview.md)
- [Core Module Implementation Details](../core/implementation.md)
- [View Module Implementation Details](../view/implementation.md)
- [UI Module Implementation Details](../ui/implementation.md)
- [Platform Module Implementation Details](../platform/implementation.md)
- [System Overview](../../architecture/system-overview.md)
- [Module Dependencies](../../architecture/module-dependencies.md)