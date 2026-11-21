# Elmtui Coding Standards

This document outlines the coding standards and conventions to be followed when contributing to the Elmtui project. Adhering to these standards helps maintain code consistency, readability, and maintainability.

## General Principles

*   **Clarity and Readability:** Write code that is easy to understand. Prioritize clarity over excessive cleverness.
*   **Consistency:** Follow the established patterns and style used throughout the codebase.
*   **Simplicity (KISS):** Keep It Simple, Stupid. Avoid unnecessary complexity.
*   **Don't Repeat Yourself (DRY):** Avoid redundant code. Use functions and macros to abstract common patterns.
*   **Idiomatic Lisp:** Write code that leverages the strengths of Common Lisp.

## Formatting

*   **Indentation:**
    *   Use spaces for indentation, not tabs.
    *   Standard Lisp indentation (typically 2 spaces for most forms, aligned parameters). Most Lisp-aware editors (SLIME, Sly) handle this automatically.
*   **Line Length:**
    *   Aim for a maximum line length of around 80-100 characters to ensure readability.
*   **Whitespace:**
    *   Use whitespace judiciously to improve readability (e.g., around operators, after commas, blank lines between logical sections of code).
*   **Parentheses:**
    *   Follow standard Lisp conventions for parenthesis placement.

## Naming Conventions

*   **Variables and Functions:**
    *   Use lowercase, hyphen-separated names (e.g., `my-variable`, `calculate-total-sum`).
    *   Predicate functions (returning boolean) should often end with `-p` or `?` (e.g., `empty-p`, `valid?`).
    *   Choose descriptive names.
*   **Macros:**
    *   Follow the same naming as functions.
*   **Classes and Structs:**
    *   Often named with angle brackets (e.g., `<my-class>`, `<widget>`) or a descriptive noun. Be consistent with existing code.
*   **Constants:**
    *   Use `+constant-name+` (earmuffs) for global constants defined with `defconstant`.
*   **Special Variables (Dynamic Variables):**
    *   Use `*special-variable-name*` (asterisks) for dynamic variables defined with `defvar` or `defparameter`.
*   **Packages:**
    *   Use lowercase, hyphen-separated names (e.g., `elmtui-core`, `elmtui.widgets.button`).

## Comments

*   **Docstrings:**
    *   Every exported function, generic function, macro, class/condition, variable, and public constructor/accessor must carry documentation metadata. Generated accessors should inherit their meaning from documented slots or receive explicit documentation when they are part of the supported API.
    *   Start with one imperative summary paragraph. For public callables, then use the headings `Arguments:`, `Returns:`, `Mutation:`, `Conditions:`, and `Example:` in that order. Add `Restarts:` whenever the operation establishes or documents restarts.
    *   `Mutation:` and `Conditions:` are mandatory even when the answer is `None`; they are part of the API contract, not optional commentary. State retry/idempotency implications where a restart may repeat side effects.
    *   Examples must be runnable or obviously schematic Common Lisp, prefer complete forms over prose fragments, and use the exported API rather than implementation internals.
    *   Preserve inspectable data in diagnostic documentation. Do not describe structured condition context as strings when the implementation retains lists, plists, objects, or path data.
    *   Private helpers still need a docstring when their contract is non-obvious, they mutate shared state, establish dynamic bindings/restarts, perform I/O, or intentionally swallow/translate conditions.
    *   Use plain Markdown-compatible prose inside docstrings. Do not mix legacy `~symbol~`, ad-hoc Org markup, or multiple competing heading conventions.
    *   Run `scripts/check-docstrings.sh` before review. It rejects increases over the recorded debt baseline; run `ELMTUI_DOCSTRING_STRICT=1 scripts/check-docstrings.sh` when driving the debt to zero.
*   **Implementation Comments:**
    *   Use comments (`;;` for full-line, `;` for end-of-line) to explain complex or non-obvious parts of the code.
    *   Avoid commenting on obvious code.
    *   Keep comments up-to-date with code changes.

## Code Structure

*   **File Organization:**
    *   Organize code into logical files and directories (modules).
    *   Keep related functions and definitions together.
*   **Function Length:**
    *   Aim for short, focused functions that do one thing well.
*   **Package Management:**
    *   Use `defpackage` to define packages.
    *   Export only the public API of a module.
    *   Use package-local nicknames where appropriate to avoid long qualified names.

## Specific Lisp Practices

*   **Error Handling:**
    *   Use the Common Lisp Condition System for error signaling and handling.
    *   Define custom conditions for library-specific errors.
    *   Do not use `IGNORE-ERRORS` in maintained runtime code. Normal-path failures must remain inspectable and propagate to the owning condition/pipeline boundary rather than silently becoming `NIL`.
    *   Optional probes should prefer type/predicate checks. If malformed external input is an expected absence case, catch only the documented condition family (for example `PARSE-ERROR`, `READER-ERROR`, `STREAM-ERROR`, or `END-OF-FILE`) and return the explicit fallback.
    *   Teardown is allowed to be best-effort, but each failure must be observed with `HANDLER-CASE`/`HANDLER-BIND` and logged before cleanup continues. Do not hide teardown failures behind `IGNORE-ERRORS`.
    *   Phase-6 ISS-030 audited the former runtime uses by category: application logging cleanup; async cancellation; event/focus compatibility access; event-loop shutdown; backend readiness and interactive input probes; terminal/faketerm teardown; driver shutdown, startup subscriptions, terminal-state probes, and alternate-screen transitions; runtime subscription cancellation; DSL/MOP resolution; and layout/style/tree transforms. Normal-path suppression was removed, optional probes were narrowed, and teardown sites now log best-effort failures. Subscription callbacks are normal-path application code: unexpected callback errors propagate to the owning runtime boundary rather than being converted to an empty subscription set.
*   **Macros:**
    *   Use macros judiciously to reduce boilerplate or create DSLs, but ensure they don't obscure code logic excessively.
    *   Ensure macros are hygienic and expand cleanly.
*   **CLOS (Common Lisp Object System):**
    *   Utilize CLOS effectively for object-oriented programming (classes, generic functions, methods).
*   **Performance:**
    *   Write efficient code, but prioritize clarity first. Optimize only when necessary and after profiling.
    *   Be mindful of consing in performance-critical sections.

## Testing

*   Write unit tests for new functionality and bug fixes.
*   Follow the testing conventions used in the project (e.g., using FiveAM or another testing framework).

## Linting and Style Checking

*   `scripts/check-docstrings.sh` audits de-duplicated exported bindings across ElmTUI and the four sublibraries and rejects documentation regressions.
*   `scripts/build-api-docs.sh` renders `docs/api/generated/api.md` and `api.html` from live Common Lisp `DOCUMENTATION` metadata.
*   `clpm bundle exec --with-client sbcl -- --noinform --load run-tests-clpm.lisp` is the full deterministic verification command.
*   `scripts/run-tests-warning-clean.sh` remains the warning-clean compilation/test gate.

---
*This document is a starting point and may be refined as the project evolves. When in doubt, refer to existing code for examples of the preferred style.*