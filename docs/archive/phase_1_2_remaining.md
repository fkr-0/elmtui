# Remaining Tasks and Verifications for Phase 1 & Phase 2

This document outlines tasks from Phase 1 and Phase 2 of the ELMTUI refactoring plan that are likely still pending, require further implementation, codebase-wide refactoring, comprehensive testing, or detailed documentation.

## I. Phase 1 Remaining/Unverified Tasks

### 1. Model System Consolidation (`elmtui.state.model`)

1. __Codebase-Wide Adoption & Verification:__

   - __Task P1.1.1:__ Conduct a thorough search across the entire codebase (including examples, UI components) for any remaining usages of older or alternative model definition/access patterns (e.g., if any hash-table based models were ever used beyond `elm.lisp`'s own potential old definition). Refactor these to use the standardized `defmodel` (from `elmtui.state.model` via `elmtui.state.elm`).
     - __Affected Files:__ Potentially any Lisp file in `src/`, `examples/`, `tests/`.

   - __Task P1.1.2:__ Implement comprehensive unit tests for all features of `defmodel` in `src/state/model.lisp`.

     - __Details:__

       - Verify correct error signaling for `:type` mismatches in `make-<model-name>`.
       - Verify correct error signaling for `:validate` predicate failures.
       - Verify correct application of `:initform` default values.
       - Verify correct observer registration by `initialize-model-state` for slots with `:observe t`, ensuring the observer lambda correctly identifies slot-level changes and dispatches the `:state-changed` message via `*app-sender*`.

     - __Affected Files:__ `tests/elmtui-state-tests.lisp` (or a new `tests/elmtui-model-tests.lisp`).

2. __Documentation (Model System):__

   - __Task P1.2.1:__ Add detailed examples of model definition (with all slot options) and usage (creation, initialization in `application-state`, access via generated accessors or `get-slot`) to the documentation.
     - __Affected Files:__ `docs/state-management.md`, `docs/model-guide.md` (if created).

### 2. Message System Standardization (`elmtui.state.msg`)

1. __Codebase-Wide Adoption & Verification:__

   - __Task P2.1.1:__ Implement comprehensive unit tests for `defmsg`-generated message constructors, specifically focusing on argument type checking and validation (if `:validate` is supported for message fields).
     - __Affected Files:__ `tests/elmtui-state-tests.lisp` (or a new `tests/elmtui-msg-tests.lisp`).
   - __Task P2.1.2:__ Conduct a codebase-wide search and refactor all message creation sites to consistently use the `defmsg`-generated constructor functions. Replace direct list constructions (e.g., `(list :my-event ...)`).
     - __Affected Files:__ Codebase-wide.
   - __Task P2.1.3:__ Review all message handlers (primarily in `defupdate` functions) to ensure they consistently and correctly destructure the exact list format produced by `defmsg` constructors (e.g., using `(getf (rest msg) :arg-name)` if messages are `(:type :arg-name value)`).
     - __Affected Files:__ All files containing `defupdate` functions.

### 3. Update Function Pattern (`elmtui.state.update`)

1. __Codebase-Wide Adoption & Verification:__

   - __Task P3.1.1:__ Conduct a codebase-wide audit for any direct calls to `ut.state.state:set-state!`, `ut.state.state:set-state`, `ut.state.state:merge-state` or similar raw state modification functions outside the `defupdate` mechanism. Refactor these to be managed within `defupdate` functions or clearly justify and document exceptions.
     - __Affected Files:__ Codebase-wide.

   - __Task P3.1.2 (Crucial):__ Finalize and verify the `defupdate` state modification contract.

     - __Details:__ Confirm whether `defupdate` functions are expected to call `set-state!` (or a local equivalent like `setf state-ref`) *within their body* for their primary state changes, OR if they are expected to return a `state-patch-plist` as their first value, with the `defupdate` macro itself being responsible for applying this patch transactionally. The latter is more purely functional and generally preferred in Elm architectures.

     - If `defupdate` functions are to return a patch:

       - Ensure all existing `defupdate` functions are refactored to return `(values state-patch-plist command-list)`.
       - Ensure the `defupdate` macro correctly iterates the `state-patch-plist` and uses `(setf (state-ref app-state key) value)` for each entry within its `with-transaction` block.

     - __Affected Files:__ `src/state/update.lisp` (defupdate macro definition), all files containing `defupdate` definitions.

   - __Task P3.1.3:__ Standardize on and enforce the use of a chosen pattern matching utility (e.g., `trivia`, `optima`, or an existing `ematch` if robust) for message dispatch in all `defupdate` functions. Refactor existing `case` or `cond` forms.
     - __Affected Files:__ All files containing `defupdate` functions.

   - __Task P3.1.4:__ Ensure all `defupdate` pattern matching constructs include a default case that consistently handles unknown/unmatched messages (e.g., logs a warning, signals an error, or dispatches a specific "unknown message" command).
     - __Affected Files:__ All files containing `defupdate` functions.

### 4. General Code Cleanup

1. __Task P4.1.1:__ Clarify the status of the `cleve-elm.*` packaged code within `src/core.lisp`. If it's obsolete or from a different context, remove it to avoid confusion and potential conflicts with the `elmtui.*` systems. If parts are to be integrated, plan this integration.
   - __Affected Files:__ `src/core.lisp`.

## II. Phase 2 Remaining/Unverified Tasks

### 1. Model Access Pattern (`elmtui.state.model`)

1. __`get-slot` and Model Update Philosophy:__

   - __Task S2.1.1:__ Ensure comprehensive unit test coverage for `elmtui.state.model:get-slot`, including scenarios with standalone plists, `application-state`, unknown models, and unknown slots.
     - __Affected Files:__ `tests/elmtui-state-tests.lisp` (or model-specific tests).
   - __Task S2.1.2:__ If a generic `set-slot` function still exists for modifying `application-state` directly, formally deprecate or remove it.
   - __Task S2.1.3:__ Clearly document in `docs/state-management.md` the standard pattern for updating models within `application-state` (i.e., via `defupdate` returning a patch that modifies the model's plist, which is then set back into `application-state` using `(setf state-ref)` by the `defupdate` macro).
     - __Affected Files:__ `docs/state-management.md`, `src/state/model.lisp` (docstrings).

2. __Deprecate Direct `state-ref` for Model Slot Access:__

   - __Task S2.2.1:__ Systematically review and update existing code that uses `(getf (state-ref app-state 'model-key) :slot-key)` for reading model data. Refactor to use generated accessors (e.g., `(slot-name app-state)`), `model-slot-value`, or `get-slot`. This is an ongoing effort.
     - __Affected Files:__ Codebase-wide.
   - __Task S2.2.2:__ Document the preference for using generated accessors, `model-slot-value`, or `get-slot` over direct `getf` on `state-ref` results for model data.
     - __Affected Files:__ `docs/state-management.md`, `docs/migration-guide.md`.

3. __Schema Metadata Helpers:__

   - __Task S2.3.1:__ Implement schema introspection functions in `src/state/model.lisp`:

     - `(model-slot-names model-name)`: Returns a list of slot name symbols.
     - `(model-slot-definition model-name slot-name)`: Returns the `slot-definition` struct.
     - Consider others like `(model-slot-type model-name slot-name)`.

   - __Task S2.3.2:__ Add unit tests for these new metadata helper functions.
     - __Affected Files:__ `src/state/model.lisp`, `tests/elmtui-state-tests.lisp` (or model tests).

   - __Task S2.3.3:__ Document these helper functions and their use cases (debugging, dynamic UI generation).
     - __Affected Files:__ `docs/state-management.md` or `docs/model-guide.md`.

### 2. Observer Pattern Enhancement (`elmtui.state.statelib.observe`, `elmtui.state.model`)

1. __Conditional Observers:__

   - __Task S2.4.1:__ Design and (optionally, if deemed high priority for Phase 2) implement support for conditional observers. This might involve allowing `:observe` in `defmodel` to take a predicate function or enhancing `add-observer`.
     - __Affected Files:__ `src/state/model.lisp`, `src/state/statelib/observe.lisp`, `docs/state-management.md`.

2. __Observer Debugging and Lifecycle Documentation:__

   - __Task S2.5.1:__ Add `log:debug` statements within `add-observer`, `remove-observer`, and `notify-observers` in `src/state/statelib/observe.lisp` for better tracing. Consider a global `*trace-observers*` dynamic variable.
     - __Affected Files:__ `src/state/statelib/observe.lisp`.
   - __Task S2.5.2:__ Document the complete observer lifecycle: how `:observe t` in `defmodel` leads to `add-observer` during `initialize-model-state`, how `notify-observers` is triggered by transaction commits, how the generated lambda differentiates slot changes, and how it dispatches a `:state-changed` message via `*app-sender*` for processing by the main application loop and `defupdate` functions.
     - __Affected Files:__ `docs/state-management.md`.

### 3. Transaction System Improvements (`elmtui.state.statelib.transaction`)

1. __Transaction Features:__

   - __Task S2.6.1:__ Design and implement support for named transactions. Modify `with-transaction` to accept an optional `:name` argument. Store this name in the `transaction` object and use it in logging (commit, rollback, undo, redo).
     - __Affected Files:__ `src/state/statelib/transaction.lisp`.
   - __Task S2.6.2 (Design):__ Further investigate and design mechanisms for transaction grouping if nested `with-transaction` doesn't suffice or isn't the desired approach.
   - __Task S2.6.3:__ Implement a basic transaction history visualization utility, e.g., `(print-transaction-history app-state)` that lists transactions (with names/descriptions if available) and a summary of changes.
     - __Affected Files:__ `src/state/statelib/transaction.lisp` or `src/dev/dev.lisp`.

2. __Undo/Redo Enhancements (Design):__

   - __Task S2.7.1 (Design):__ Design how transaction descriptions (beyond simple names) could be added if needed.
   - __Task S2.7.2 (Design):__ Outline a design for selective undo/redo capabilities, acknowledging this is a large feature likely for a later phase but initial thoughts can be captured.

3. __Transaction Safety Verification:__

   - __Task S2.8.1:__ Implement comprehensive unit tests for `with-transaction`, specifically covering various error scenarios within the transaction body to ensure state is correctly and consistently rolled back.
     - __Affected Files:__ `tests/elmtui-state-tests.lisp`.

### 4. Integration with Async Infrastructure (Design & Documentation)

1. __Task S2.9.1:__ Document clear design patterns for how asynchronous operations (using `clevelib`) should integrate with the synchronous Elm update cycle.

   - __Details:__

     - How commands returned by `defupdate` can trigger async tasks.
     - How these async tasks, upon completion (or error), should dispatch messages (via `*app-sender*`) back to the main loop.
     - How `defupdate` functions will handle these response messages to update application state.

   - __Affected Files:__ `docs/async-guide.md` (new or part of developer/architecture guide), `docs/state-management.md`.

This list should provide a good overview of what likely remains to fully complete and verify Phases 1 and 2 according to the detailed plans.
