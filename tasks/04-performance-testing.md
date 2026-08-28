# Tasks: Performance Testing & General Optimizations

> **2026-08-20 audit:** superseded as an active checklist. Measurement tasks are consolidated into DEV-002/DEV-004; optimization tasks require measured evidence first. See [`tasks/README.md`](README.md).

This file lists pending tasks for performance testing, benchmarking, and general optimizations in ELMTUI, with a primary focus on the event system.

## Event System Performance Testing

-   **[ ] Implement comprehensive event benchmark suite in `src/dev/event-benchmark.lisp`.**
    -   **Changes:**
        -   Develop a suite of benchmarks within `src/dev/event-benchmark.lisp` to measure various aspects of event system performance.
        -   Include benchmarks for event creation, publishing, topic lookup, subscriber notification, and end-to-end event propagation.
        -   Allow benchmarks to be run selectively and produce clear, quantifiable results.
    -   **Affected Files:**
        -   `src/dev/event-benchmark.lisp`
        -   `tests/elmtui-event-benchmark-tests.lisp` (for testing the benchmark tools themselves)
        -   Potentially hooks in `src/core/` modules (loop, topic-registry, event-propagation) to facilitate benchmarking.

-   **[ ] Add memory profiling capabilities for events.**
    -   **Changes:**
        -   Integrate Lisp's memory profiling tools (e.g., `SB-PROFILE:PROFILE-MEMORY` or equivalent for other implementations) into the benchmark suite or as standalone utilities.
        -   Focus on memory allocated during event creation, storage in queues/history, and by event handlers.
        -   Analyze results to identify areas of excessive memory consumption.
    -   **Affected Files:**
        -   `src/dev/event-benchmark.lisp` (or a new dev tool for memory profiling)
        -   Relevant Lisp implementation's profiling tools documentation.

-   **[ ] Implement comparative benchmark reporting for events.**
    -   **Changes:**
        -   Extend the benchmark suite to save results from previous runs.
        -   Implement functionality to compare current benchmark results against historical data to track performance regressions or improvements over time.
        -   Output reports in a human-readable format, possibly with charts or tables.
    -   **Affected Files:**
        -   `src/dev/event-benchmark.lisp`
        -   Potentially a new module for report generation and data storage.

-   **[ ] Create test harnesses for measuring event latency.**
    -   **Changes:**
        -   Develop specific test cases or harnesses that measure the time taken from an event's initiation (e.g., input from `platform/input.lisp`) to its final handling (e.g., execution of a widget's event handler).
        -   This will involve precise timestamping at various points in the event pipeline.
    -   **Affected Files:**
        -   `tests/elmtui-event-system-tests.lisp` (or a new latency-focused test file)
        -   `src/dev/event-monitor.lisp` (if used for timestamping/analysis)
        -   Hooks in `platform/input.lisp`, `core/loop.lisp`, `core/event-propagation.lisp`.

-   **[ ] Add stress testing utilities for the event system.**
    -   **Changes:**
        -   Create tools or test scenarios that generate a high volume of events of various types over a sustained period.
        -   Monitor system stability, memory usage, and responsiveness under such load.
        -   Identify breaking points or performance degradation patterns.
    -   **Affected Files:**
        -   New file in `src/dev/` or `tests/` (e.g., `src/dev/event-stress-tester.lisp`)

-   **[ ] Identify bottlenecks in the event system.**
    -   **Changes:**
        -   Utilize the benchmark results, latency measurements, memory profiles, and stress test outcomes to pinpoint specific areas in the event processing pipeline that are causing performance issues.
        -   This is an analytical task based on the data gathered from the tools above.
    -   **Affected Files:**
        -   This task primarily involves analysis of data from tools affecting: `src/core/loop.lisp`, `src/core/event-async.lisp`, `src/core/event-propagation.lisp`, `src/core/topic-registry.lisp`, `src/core/message-bus.lisp`.

-   **[ ] Optimize critical paths for event handling.**
    -   **Changes:**
        -   Based on identified bottlenecks, refactor and optimize the code in the critical paths.
        -   This could involve algorithmic improvements, reducing allocations, optimizing data structures, or micro-optimizations in tight loops.
        -   Re-run benchmarks after optimizations to verify improvements.
    -   **Affected Files:**
        -   Files identified as bottlenecks (e.g., `src/core/loop.lisp`, `src/core/event-propagation.lisp`, specific event handlers).

## Apply Performance Optimizations (Event System)

-   **[ ] Add event batching for UI update events.**
    -   **Changes:**
        -   Implement a mechanism where multiple UI-related events (e.g., those triggering view updates) occurring in rapid succession can be batched together.
        -   Instead of triggering a separate view update for each event, a single update is performed for the batch, reducing redundant computation.
        -   This could be integrated into the main event loop or the part of the system that schedules view renders.
    -   **Affected Files:**
        -   `src/core/loop.lisp`
        -   `src/runtime.lisp` (application render scheduling)
        -   `src/state/update.lisp` (if commands trigger view updates)

-   **[ ] Optimize handler dispatch for critical event paths.**
    -   **Changes:**
        -   Review and optimize the mechanisms for finding and invoking event handlers, especially for frequently occurring events.
        -   This might involve optimizing lookups in `elmtui.core.event-propagation:get-event-handler` or subscription lookups in `elmtui.core.topic-registry`.
        -   Consider caching or more efficient data structures for handler storage if profiling indicates this is a bottleneck.
    -   **Affected Files:**
        -   `src/core/event-propagation.lisp`
        -   `src/core/topic-registry.lisp`
        -   `src/core/message-bus.lisp`

-   **[ ] Implement caching for frequently used topics and subscriptions.**
    -   **Changes:**
        -   If topic lookups or subscriber list retrieval for popular topics prove to be performance-intensive, implement a caching layer within `elmtui.core.topic-registry`.
        -   Ensure cache invalidation is handled correctly when subscriptions change.
    -   **Affected Files:**
        -   `src/core/topic-registry.lisp`

## After Completion of Tasks in This File

### Accomplishments
*(This section will be filled upon completion of the tasks above. It will summarize the performance improvements and new optimization capabilities.)*

- The event system will have a comprehensive suite of benchmarking and profiling tools.
- Performance characteristics (latency, throughput, memory usage) of the event system will be well understood.
- Key bottlenecks in event handling will be identified and addressed.
- Specific optimizations like event batching and caching will be implemented, leading to a more responsive UI.
- A framework for ongoing performance monitoring and regression testing will be in place.

### Remaining or Emerging Tasks
*(This section will be updated if any new tasks arise from the solutions implemented, or if any sub-tasks are deferred.)*

- Performance tuning might become an ongoing activity as new features are added.
- Optimizations in one area might reveal bottlenecks in others.

### Next Steps

- Proceed to tasks outlined in `tasks/05-developer-experience-docs.md`.
