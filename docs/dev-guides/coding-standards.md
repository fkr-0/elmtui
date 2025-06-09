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
    *   Provide clear and concise docstrings for all public functions, macros, classes, and variables.
    *   Explain what the code does, its parameters, and what it returns.
    *   Follow Lisp convention for docstring placement.
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

*   (If a linter or style checker is used for the project, specify it here and how to run it.)

---
*This document is a starting point and may be refined as the project evolves. When in doubt, refer to existing code for examples of the preferred style.*