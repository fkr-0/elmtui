# Plan: Keymap Refactoring and Test Enhancement (2025-06-08)

This plan outlines the steps to refactor keymap definitions in specific files to use the `define-keymap` macro and to review, update, and expand test coverage.

## Part A: Refactor Keymap Definitions

The goal is to replace direct `make-keymap` calls with the `define-keymap` macro for defining named, global keymaps, improving consistency and readability.

1.  **Modify `src/ui/widgets/counter.lisp`**:
    *   **Imports**:
        *   Ensure `define-keymap` is imported from `:elmtui.core.keymap-system`.
        *   Remove direct imports of `make-keymap` and `parse-key-string`.
    *   **Keymap Definition**:
        *   Define a single global keymap using `define-keymap` at the top level of the `counter.lisp` file:
            ```lisp
            ;; In package :elmtui.ui.widgets.counter
            (define-keymap *counter-keymap*
              ("+" :type :message :target :increment)
              ("=" :type :message :target :increment)
              ("-" :type :message :target :decrement)
              ("Enter" :type :message :target :reset))
            ```
    *   **Refactor `init` method**:
        *   Remove the old `make-keymap` call.
        *   The `keymap-patch` will use the globally defined `*counter-keymap*`:
            ```lisp
            (make-state-patch :path id-path 
                              :value `(:active-keymap ,*counter-keymap*) 
                              :strategy :merge)
            ```
        *   Remove `keymap-name` generation logic.

2.  **Modify `examples/keymap-app.lisp`**:
    *   **Imports**:
        *   Ensure `define-keymap` is imported from `:elmtui.core.keymap-system`.
        *   Remove `make-keymap` and `parse-key-string` if no longer directly used.
    *   **`app-global-keymap` function**:
        *   Refactor to define `*app-global-keymap*` at the top level using `define-keymap`:
            ```lisp
            ;; In package :elmtui.examples.keymap-app
            (define-keymap *app-global-keymap*
              ("C-q" :type :message :target '(:app-quit-requested :source :global-C-q)))
            ```
        *   The function `app-global-keymap` will then simply return `*app-global-keymap*`.
    *   **`app-component-keymaps` function**:
        *   Define `*example-counter-keymap*` at the top level (after `*counter-a-id*` is defined):
            ```lisp
            ;; In package :elmtui.examples.keymap-app
            (define-keymap *example-counter-keymap*
              ("+" :type :message :target `(:dispatch-to-component ,*counter-a-id* :increment))
              ("=" :type :message :target `(:dispatch-to-component ,*counter-a-id* :increment))
              ("-" :type :message :target `(:dispatch-to-component ,*counter-a-id* :decrement))
              ("Enter" :type :message :target `(:dispatch-to-component ,*counter-a-id* :reset)))
            ```
        *   `app-component-keymaps` will return: ` `((,*counter-a-id* . ,*example-counter-keymap*))` `

## Part B: Review and Implement Tests

1.  **Review Existing Tests**:
    *   Examine `tests/component-init-tests.lisp`, `tests/elmtui-integration-tests.lisp`, and `tests/elmtui-tests.lisp`.
    *   Update tests related to the `counter` widget and keymap interactions to reflect changes from Part A.
    *   Ensure all reviewed tests align with the `defcomponent` structure and the new keymap definitions. Fix any breakages.

2.  **Identify Untested Modules/Functionality**:
    *   **Keymap System (`src/core/keymap-system.lisp`, `src/core/base-keymap.lisp`, `src/core/keymap/`)**:
        *   `define-keymap` macro expansion and correctness.
        *   `create-keymap-from-definitions` function.
        *   Key lookup functions (`lookup-keymap`, `lookup-key-in-context`, `lookup-key-binding`).
        *   Keymap registration (`register-keymap`, `find-keymap`).
        *   Context management (`define-keymap-context`, `activate-context`, `deactivate-context`, `current-context`, `add-keymap-to-context`).
        *   `parse-key-string` and `normalized-key->string` for various inputs.
    *   **Counter Widget (`src/ui/widgets/counter.lisp`)**:
        *   Test `init`: correct initial state (`value`, `initial-value`, `active-keymap` referencing the shared keymap).
        *   Test `update`: correct state changes for `:increment`, `:decrement`, `:reset` messages. Test no change for unknown messages.
        *   Test `view`: correct `ui-node` structure and properties based on state.
        *   Test accessors: `counter-value`, `counter-initial-value`.
    *   **`defcomponent` Macro (`src/ui/defcomponent.lisp`)**: Ensure comprehensive coverage of `defcomponent`'s generated methods (default `init`, `update`, `view`) and accessor generation, beyond what `component-init-tests.lisp` might already cover.
    *   **Focus Management (`src/core/focus/manager.lisp`)**: Check if tests cover focus changes and their interaction with keymap context activation/deactivation.

3.  **Implement New Tests**:
    *   Create new test files (e.g., `keymap-tests.lisp`, `counter-widget-tests.lisp`) or add to existing relevant files.
    *   Use the project's standard testing framework (e.g., FiveAM, if applicable).
    *   Write tests covering the identified untested areas, ensuring they are isolated and repeatable.

## Mermaid Diagram (Illustrating Keymap Refactoring for Counter Widget)

```mermaid
graph TD
    A[src/ui/widgets/counter.lisp] -- defines --> KM[*counter-keymap*]
    KM -- using --> DK[define-keymap macro]
    DK -- uses --> CKFD[create-keymap-from-definitions]
    CKFD -- uses --> PKS[parse-key-string]

    subgraph Counter Component
        CInit[counter init method]
    end

    CInit -- stores ref to --> KM
    CInit -- creates patch for --> AS[:active-keymap in app-state]
    AS -- points to --> KM

    style KM fill:#f9f,stroke:#333,stroke-width:2px
    style DK fill:#ccf,stroke:#333,stroke-width:2px