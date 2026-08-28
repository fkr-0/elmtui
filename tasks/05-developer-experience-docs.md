# Tasks: Developer Experience & Documentation

> **2026-08-20 audit:** superseded as an active checklist. Dev-tooling work was revalidated against current APIs and documentation duplicates were collapsed. See [`tasks/README.md`](README.md).

This file lists pending tasks related to improving developer experience, code cleanup, and documentation for ELMTUI.

## General Code Cleanup

-   **[ ] Remove obsolete file `src/core.lisp`.**
    -   **Changes:**
        -   As per `docs/implementation.md`, `src/core.lisp` contains only commented-out, obsolete code.
        -   Delete the file `src/core.lisp` from the project.
        -   Remove any references to this file from ASD files or build scripts if they exist.
    -   **Affected Files:**
        -   `src/core.lisp` (to be deleted)
        -   `elmtui.asd` (or other system definition files, if it's listed)

-   **[ ] Confirm removal of other obsolete files.**
    -   **Changes:**
        -   Conduct a codebase audit to identify any other files that are no longer used or contain obsolete code (e.g., remnants from previous refactorings like the legacy focus system files, which were already noted as deleted in `docs/implementation.md`).
        -   Delete these identified files.
        -   Update system definitions if necessary.
    -   **Affected Files:**
        -   Any identified obsolete files throughout the `src/` directory.
        -   `elmtui.asd` or other system definition files.

## Developer Tools

-   **[ ] Expand the interactive Dev Module (`src/dev/dev.lisp`).**
    -   **Changes:**
        -   Review the current capabilities of `src/dev/dev.lisp`.
        -   Add more interactive commands or REPL utilities for inspecting application state, model schemas, active widgets, focus information, and event system metrics.
        -   Consider adding features like live component tree inspection or style inspection.
    -   **Affected Files:**
        -   `src/dev/dev.lisp`
        -   Potentially hooks into various core modules (`state/`, `view/`, `core/focus/`) to expose data.

-   **[ ] Create more general debugging visualization tools (beyond events).**
    -   **Changes:**
        -   Design and implement visualization tools for:
            -   Application state tree (similar to Redux DevTools).
            -   Component hierarchy and properties.
            -   Layout box model for specific components.
        -   These tools could generate Graphviz diagrams, TUI representations, or integrate with `src/dev/dev.lisp`.
    -   **Affected Files:**
        -   New files in `src/dev/` (e.g., `src/dev/state-visualizer.lisp`, `src/dev/component-tree-viewer.lisp`).
        -   Hooks in `src/state/model.lisp`, `src/view/core.lisp`, `src/view/layout.lisp`.

## Integration Tasks (Post-Event System Enhancements)

-   **[ ] Connect event visualization with transaction history.**
    -   **Changes:**
        -   Enhance the event monitoring/visualization tools (`src/dev/event-monitor.lisp`, `src/dev/transaction-viewer.lisp`) to correlate events with the transactions they trigger or are part of.
        -   Allow developers to see which events led to specific state changes recorded in transactions.
    -   **Affected Files:**
        -   `src/dev/event-monitor.lisp`
        -   `src/dev/transaction-viewer.lisp` (if created from Task 01)
        -   `src/state/statelib/transaction.lisp` (to ensure transactions can be linked to originating events if possible).

-   **[ ] Link event monitoring to state change debugging.**
    -   **Changes:**
        -   When an event causes a state change, the event monitor should be able to show the "before" and "after" state, or at least a diff of the changed parts of the model.
        -   This requires integration between event monitoring and state observation/diffing capabilities.
    -   **Affected Files:**
        -   `src/dev/event-monitor.lisp`
        -   `src/state/model.lisp` (or state diffing utilities)
        -   `src/state/statelib/observe.lisp` (if observers are used to track changes).

-   **[ ] Create holistic debugging tools showing event-to-state causality.**
    -   **Changes:**
        -   Develop a unified debugging interface or dashboard that provides a timeline view.
        -   This timeline should show incoming events, their propagation, the update functions triggered, commands issued, transactions created, and the resulting state changes.
        -   This is a high-level integration of multiple debugging tools.
    -   **Affected Files:**
        -   A new overarching dev tool in `src/dev/` (e.g., `src/dev/holistic-debugger.lisp`).
        -   Integration points with `event-monitor`, `transaction-viewer`, state inspection tools.

-   **[ ] Connect event throttling to UI update optimization.**
    -   **Changes:**
        -   Ensure that when events are throttled (e.g., mouse-move), the UI rendering or update logic also respects this, preventing unnecessary render calls for events that were filtered out by the throttler.
        -   This might involve the throttler directly influencing the render loop or update scheduling.
    -   **Affected Files:**
        -   `src/dev/event-throttler.lisp`
        -   `src/core/loop.lisp`
        -   `src/runtime.lisp` (render scheduling)

-   **[ ] Add performance metrics for event-to-render latency.**
    -   **Changes:**
        -   Implement precise measurement of the time taken from an input event being received by the system to the corresponding UI changes being fully rendered on the screen (or virtual buffer).
        -   Expose these metrics through developer tools.
    -   **Affected Files:**
        -   `src/platform/input.lisp` (start timestamp)
        -   `src/core/loop.lisp`
        -   `src/runtime.lisp`
        -   `src/platform/backend/terminal/diff-renderer.lisp` (end timestamp)
        -   `src/dev/event-monitor.lisp` or performance dashboard.

-   **[ ] Optimize render triggers from high-frequency events.**
    -   **Changes:**
        -   Analyze how high-frequency events (e.g., mouse-move, continuous scroll) trigger view updates.
        -   Implement strategies like requestAnimationFrame-style batching for renders, ensuring that even if many events arrive, rendering happens at a controlled pace (e.g., matching display refresh rate).
    -   **Affected Files:**
        -   `src/runtime.lisp` (render loop)
        -   `src/core/loop.lisp` (event handling that triggers renders)

-   **[ ] Standardize event handling patterns across widget implementations.**
    -   **Changes:**
        -   Review all widget implementations in `src/ui/widgets/`.
        -   Establish and document a consistent pattern for how widgets should define, subscribe to, and handle events (both internal and external).
        -   Refactor existing widgets to adhere to this standard.
    -   **Affected Files:**
        -   All files in `src/ui/widgets/`
        -   `docs/widget-authoring.md` or a new style guide.

-   **[ ] Document best practices for widget event handling.**
    -   **Changes:**
        -   Update `docs/widget-authoring.md` or create new documentation detailing best practices for event handling within widgets.
        -   Include advice on when to use direct handlers, when to dispatch messages, how to manage local widget state in response to events, and performance considerations.
    -   **Affected Files:**
        -   `docs/widget-authoring.md` (or new documentation file).

-   **[ ] Create widget-specific event debug tools.**
    -   **Changes:**
        -   Develop tools that allow developers to inspect the events a specific widget instance is receiving, its internal state related to event handling (e.g., active keymaps, focus status), and how it responds to those events.
        -   This could be part of the interactive dev module or a dedicated widget inspector.
    -   **Affected Files:**
        -   `src/dev/dev.lisp` (if extended)
        -   Or a new tool, e.g., `src/dev/widget-inspector.lisp`.
        -   Hooks in `src/ui/widgets/` or `src/view/core.lisp` to access widget data.

## Documentation

-   **[ ] Create clear design documentation for async integration patterns with TEA.**
    -   **Changes:**
        -   Write a new document in `docs/` explaining the recommended patterns for integrating asynchronous operations (promises, channels, async commands) with The Elm Architecture (Model, Update, View) in ELMTUI.
        -   Cover topics like initiating async tasks from `update`, handling their results as new messages, managing loading states, and error handling.
    -   **Affected Files:**
        -   New file in `docs/` (e.g., `docs/async-tea-patterns.md`).

-   **Event System Documentation:**
    -   **[ ] Create comprehensive developer guide.**
        -   **Changes:** Write a detailed guide covering all aspects of the ELMTUI event system: event types, propagation, async events, topic-based messaging, keymaps, focus, throttling/debouncing, and debugging tools.
        -   **Affected Files:** New file in `docs/` (e.g., `docs/event-system-guide.md`).
    -   **[ ] Add examples for common event handling patterns.**
        -   **Changes:** Include practical code examples within the developer guide or a separate examples document, showcasing how to handle various event scenarios.
        -   **Affected Files:** `docs/event-system-guide.md` or new `docs/event-examples.md`.
    -   **[ ] Provide troubleshooting guidelines for event-related issues.**
        -   **Changes:** Compile a list of common problems developers might encounter with the event system and provide solutions or debugging strategies.
        -   **Affected Files:** `docs/event-system-guide.md` or `docs/troubleshooting.md`.
    -   **[ ] Document all public event system APIs.**
        -   **Changes:** Ensure all public functions, macros, classes, and variables related to the event system have clear, accurate docstrings. Consider auto-generating API documentation from these.
        -   **Affected Files:** All relevant source files in `src/core/`, `src/dev/` related to events.
    -   **[ ] Clarify relationships between event subsystems.**
        -   **Changes:** Create diagrams and explanations in the documentation to illustrate how different parts of the event system (e.g., `core.loop`, `event-async`, `event-propagation`, `topic-registry`, `keymap`, `focus`) interact.
        -   **Affected Files:** `docs/event-system-guide.md`.
    -   **[ ] Provide usage examples for each API.**
        -   **Changes:** Include small, focused usage examples in the docstrings or API reference for key public APIs.
        -   **Affected Files:** Relevant source files (docstrings).
    -   **[ ] Document performance characteristics of event system.**
        -   **Changes:** Summarize the findings from performance testing (Task 04) in the documentation. Provide guidance on expected performance and factors that can affect it.
        -   **Affected Files:** `docs/event-system-guide.md` or `docs/performance.md`.
    -   **[ ] Provide optimization guidelines for event handlers.**
        -   **Changes:** Offer advice to developers on how to write efficient event handlers and use features like throttling/debouncing effectively.
        -   **Affected Files:** `docs/event-system-guide.md` or `docs/performance.md`.
    -   **[ ] Create troubleshooting guide for event-related performance issues.**
        -   **Changes:** Specifically address how to diagnose and resolve performance problems related to the event system, using the provided debugging and benchmarking tools.
        -   **Affected Files:** `docs/performance.md` or `docs/troubleshooting.md`.

## After Completion of Tasks in This File

### Accomplishments
*(This section will be filled upon completion of the tasks above. It will summarize the improvements made to developer experience and documentation.)*

- The codebase will be cleaner with obsolete files removed.
- Developers will have significantly improved interactive and visual debugging tools for a wide range of subsystems.
- Event handling and its impact on state and rendering will be much more transparent and debuggable.
- Performance from event to render will be measurable and optimized.
- Widget development will benefit from standardized event handling patterns and better debugging.
- Comprehensive documentation for async patterns and the entire event system will be available, greatly aiding developer onboarding and productivity.

### Remaining or Emerging Tasks
*(This section will be updated if any new tasks arise from the solutions implemented, or if any sub-tasks are deferred.)*

- Ongoing documentation updates will be needed as the framework evolves.
- New developer tool ideas might emerge based on usage.

### Next Steps

- All planned task categorization and detailing will be complete. The project can then focus on implementing the tasks within these structured files.
