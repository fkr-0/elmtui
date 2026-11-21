# Elmtui Architectural Refactoring Plan

**Overall Goal:** Systematically implement the architectural refactorings described in `docs/dev-guides/refactor_tasks.md` to enhance Elmtui's component definition, state management, application structure, and developer experience, including refactoring existing UI widgets and updating all relevant documentation.

---

## Proposed Phased Plan

**Phase 1: Enhancing `defcomponent` and Core Component Refactoring**
*   **Objective:** Implement the core enhancements to the `defcomponent` macro and refactor an initial set of widgets.
*   **Tasks derived from `docs/dev-guides/refactor_tasks.md`:**
    1.  **`defcomponent` Enhancements (Section 1):**
        *   Implement inline logic for `:init`, `:update`, and `:view` within `defcomponent`.
        *   Introduce the `:state` clause for local state abstraction.
        *   Ensure implicit `self-id-path` and `app-state` availability.
        *   Promote simplified state access via the passed `local-state` map.
        *   Verify and maintain the `defmethod` fallback mechanism.
        *   *(Initially deferring `:observes` and `:subscriptions` clauses unless deemed critical for this phase).*
    2.  **Initial Widget Refactoring (Related to Section 1 & 6):**
        *   Select 2-3 simple widgets from `src/ui/widgets/` (e.g., `button.lisp`, `label.lisp`, `counter.lisp`) and refactor them to use the new `defcomponent` features. These will serve as early examples and test cases.
    3.  **Documentation (Section 6 - Partial):**
        *   Begin updating documentation for `defcomponent` in `docs/modules/ui/overview.md`, `docs/modules/ui/implementation.md`, and relevant developer guides.
        *   Document the refactored example widgets.

**Phase 2: Transactional State, Message Handling, and Broader Refactoring**
*   **Objective:** Integrate transactional state management, standardize message handling, and continue widget refactoring.
*   **Tasks derived from `docs/dev-guides/refactor_tasks.md`:**
    1.  **Integrate `statelib` Transactions (Section 2):**
        *   Refactor `elmtui.state.api:set-path` to use `(setf (state-ref ...))` for transactional updates.
        *   Wrap the main application update cycle in `elmtui.statelib.transaction:with-transaction`.
        *   Implement and expose undo/redo capabilities.
    2.  **Leverage `defmsg` and Message Handling (Section 5):**
        *   Promote `defmsg` usage through documentation and examples.
        *   Implement declarative message handlers within the enhanced `defcomponent`'s `:update` clause.
        *   Define behavior for unhandled messages (log, error, no-op) at component and application levels.
    3.  **Standardize State Manipulation API (Section 4 - Core Parts):**
        *   Define and implement helper functions/macros for reading state (e.g., `get-local-property`, `get-global-property`).
        *   Define and implement helpers for generating patches (e.g., `set-local-property-patch`).
    4.  **Continued Widget Refactoring (Related to Section 1, 5 & 6):**
        *   Refactor a broader set of more complex widgets from `src/ui/widgets/` using the enhanced `defcomponent`, new message handling, and state APIs.
    5.  **Documentation (Section 6 - Partial):**
        *   Document `statelib` integration, `defmsg` usage, new message handling patterns in `defcomponent`, and the state manipulation APIs.

**Phase 3: Application Definition, API Finalization, and Comprehensive Documentation**
*   **Objective:** Refine application definition, finalize all APIs, complete widget refactoring, and ensure comprehensive documentation.
*   **Tasks derived from `docs/dev-guides/refactor_tasks.md`:**
    1.  **Refine `defapplication` Macro (Section 3):**
        *   Simplify root component specification (e.g., optional `:root-viewport-id`, convention-based root component).
        *   Ensure robust default initial state handling.
    2.  **Finalize State Manipulation API (Section 4):**
        *   Implement any remaining direct transactional update functions (e.g., `update-local-property!`, `update-global-property!`).
        *   Ensure full integration with the enhanced `defcomponent`.
    3.  **Complete Widget Refactoring (Related to all sections):**
        *   Refactor all remaining widgets in `src/ui/widgets/` and any other necessary components in `src/ui/`.
    4.  **Documentation and Examples (Section 6 - Completion):**
        *   Update all module `overview.md` and `implementation.md` files affected by the refactorings.
        *   Finalize developer guides for component creation, application definition, and state management.
        *   Provide comprehensive examples demonstrating all new APIs and refactored patterns.

---

## High-Level Flow and Dependencies

```mermaid
graph TD
    A[Phase 1: defcomponent & Core Widgets] --> B[Phase 2: Transactions, Messages, State API];
    B --> C[Phase 3: defapplication, API Finalization, Full Docs];

    subgraph Phase 1
        P1_DefComp["Task: Enhance defcomponent (Sec 1)"]
        P1_WidgetRefactor["Task: Refactor Initial Widgets"]
        P1_Docs["Task: Initial defcomponent Docs (Sec 6)"]
    end

    subgraph Phase 2
        P2_Statelib["Task: Integrate statelib (Sec 2)"]
        P2_DefMsg["Task: Leverage defmsg (Sec 5)"]
        P2_StateAPI["Task: Standardize State API - Core (Sec 4)"]
        P2_WidgetRefactor["Task: Continue Widget Refactoring"]
        P2_Docs["Task: Docs for Statelib, Defmsg, State API (Sec 6)"]
    end

    subgraph Phase 3
        P3_DefApp["Task: Refine defapplication (Sec 3)"]
        P3_StateAPIFinal["Task: Finalize State API (Sec 4)"]
        P3_WidgetRefactorFinal["Task: Complete All Widget Refactoring"]
        P3_DocsFinal["Task: Comprehensive Docs & Examples (Sec 6)"]
    end

    P1_DefComp --> P1_WidgetRefactor;
    P1_DefComp --> P2_DefMsg;
    P1_DefComp --> P2_StateAPI;
    P2_Statelib --> P2_StateAPI;
    P2_StateAPI --> P3_StateAPIFinal;
    P1_WidgetRefactor --> P2_WidgetRefactor;
    P2_WidgetRefactor --> P3_WidgetRefactorFinal;