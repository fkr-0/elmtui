# Elmtui Troubleshooting Guide

This guide provides solutions and debugging tips for common issues encountered while developing with or using the Elmtui library.

## Common Setup Issues

*   **Symptom:** System `:elmtui` not found by ASDF/Quicklisp.
    *   **Cause:** Elmtui directory not correctly added to ASDF's source registry or `~/quicklisp/local-projects/`.
    *   **Solution:** Review the [Setup Guide](./setup.md#2-make-elmtui-discoverable-by-asdf) and ensure paths are correct. Try `(asdf:clear-source-registry)` and reloading your Lisp image.

*   **Symptom:** Dependency not found (e.g., `XYZ system not found`).
    *   **Cause:** A required library is missing or not discoverable by Quicklisp/CLPM.
    *   **Solution:**
        *   If using Quicklisp, ensure the library is available in your Quicklisp distribution or `local-projects`. Try `(ql:update-all-dists)` if it's a Quicklisp library.
        *   If using CLPM, ensure `clpm install` was successful and the library is listed in `clpmfile`.

## Runtime Issues

*   **Symptom:** Terminal output is garbled or looks incorrect.
    *   **Cause:**
        *   Incorrect terminal type (`$TERM` environment variable) or capabilities.
        *   Unsupported terminal emulator features.
        *   Bugs in the Elmtui rendering backend for your specific terminal.
        *   Character encoding issues (ensure UTF-8).
    *   **Debugging Steps:**
        *   Try a different, well-supported terminal emulator (e.g., `xterm`, `gnome-terminal`).
        *   Check your `$TERM` variable (e.g., `xterm-256color`).
        *   Simplify your UI to isolate the problematic component or style.
        *   Enable any Elmtui debug logging related to rendering (see [Logging Guide](../core/logging.md) - *placeholder link*).

*   **Symptom:** Application freezes or becomes unresponsive.
    *   **Cause:**
        *   Infinite loop in update logic or event handling.
        *   Deadlock in concurrent operations.
        *   Blocking call in the main event loop.
    *   **Debugging Steps:**
        *   Use the Lisp debugger to inspect the backtrace when the freeze occurs.
        *   Add logging to trace event flow and state changes.
        *   If using threads, check for deadlocks or race conditions.

*   **Symptom:** Incorrect layout or component sizing.
    *   **Cause:**
        *   Incorrect flexbox/grid properties.
        *   Intrinsic size of components conflicting with layout constraints.
        *   Bugs in the Elmtui layout engine.
    *   **Debugging Steps:**
        *   Use any Elmtui layout debugging tools (if available, e.g., visual outlines).
        *   Simplify the component tree to isolate the layout issue.
        *   Experiment with different layout properties.

*   **Symptom:** Events (e.g., key presses) not being handled as expected.
    *   **Cause:**
        *   Incorrect keymap definitions.
        *   Focus issues (the wrong component has focus).
        *   Event propagation being stopped prematurely.
        *   Bugs in event handling logic.
    *   **Debugging Steps:**
        *   Enable Elmtui event logging to see the event flow.
        *   Check which component currently has focus.
        *   Verify your keymap definitions and event handlers.

## Performance Issues

*   **Symptom:** Application is slow or laggy.
    *   **Cause:**
        *   Inefficient rendering (too many updates, complex diffs).
        *   Expensive computations in the update logic or view function.
        *   Too frequent state updates.
    *   **Debugging Steps:**
        *   Use Lisp profiling tools (e.g., `SB-PROFILE` in SBCL) to identify bottlenecks.
        *   Enable Elmtui performance monitoring or benchmarking tools (if available).
        *   Optimize your view functions and state update logic.
        *   Consider memoization or other techniques to reduce re-computation.

## Reporting Issues

If you encounter an issue not covered here or suspect a bug in Elmtui:
1.  Try to create a minimal reproducible example.
2.  Gather relevant information:
    *   Elmtui version.
    *   Common Lisp implementation and version.
    *   Operating System and version.
    *   Terminal emulator and version.
    *   Relevant code snippets.
    *   Error messages and backtraces.
3.  Report the issue on the Elmtui project's issue tracker (provide link here).

---
*This guide will be expanded with more specific issues and solutions as they are identified.*