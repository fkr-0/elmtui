# Dependency Refactor Plan

## Goal
Remove cross-layer coupling in `elmtui` so module load order can follow a clean direction:
`foundation/contracts -> state/core/ui/view/platform -> app/integration`.

## Current Status (Issues 1-6)

1. `core -> app.system-events`
- Status: Implemented in this pass.
- Change: Moved system event ownership to `core/system-events` and migrated imports.

2. `platform/driver -> concrete ui widget (root-viewport class)`
- Status: Implemented in this pass.
- Change: Removed concrete widget import from `platform/driver`; driver now uses app-spec/root-id path only.

3. `pipeline -> platform/driver global (*ROOT-VIEWPORT-ID-PATH*)`
- Status: Implemented in this pass.
- Change: Removed fallback lookup; pipeline derives root viewport path only from current DSL tree.

4. Transitional `app/dsl-type-registry`
- Status: Implemented in previous pass.
- Change: Deleted app registry; UI owns built-in aliases in `src/ui/dsl-type-builtins.lisp`.

5. Stale ASD rationale / load order comments
- Status: Partially implemented.
- Change: Updated stale comments and removed obsolete entries.
- Remaining: Full submodule-by-submodule strict layering still blocked by some app/runtime integration choices.

6. Stale widget surface under `src/ui/widgets`
- Status: Implemented in previous pass.
- Change: Removed non-loaded stale files (`layout2`, `panel`, `form`, `table`) from main tree.

## Remaining Cross-Layer Hotspots

1. App runtime still carries broad orchestration responsibilities in `src/app/application.lisp`.
- Impact: difficult to keep app/api thin and dependency-pure.
- Candidate action: split macro expansion helpers and runtime wiring into smaller files with explicit contracts.

2. Legacy subtree (`src/platform/legacy/**`) still exists and can drift.
- Impact: stale imports may reintroduce outdated dependencies.
- Candidate action: isolate under optional ASD subsystem or archive.

3. `platform/driver` still depends directly on app/api + pipeline + core loop glue.
- Impact: integration module is heavy and mixes lifecycle orchestration with transport details.
- Candidate action: introduce a tiny runtime protocol package for driver-facing hooks.

## Potential Extraction to `cl-*` Libraries

These are good candidates because they are broadly reusable and not `elmtui`-specific:

1. `cl-events`
- Candidate: system-event ADT/message constructors currently in `core/system-events`.
- Why: generic event model, independent of widgets/rendering.

2. `cl-inputs`
- Candidate: token -> event normalization in `src/platform/input.lisp` (`cl-inputs-token->event` mapping layer).
- Why: purely input-domain adaptation.

3. `cl-state`
- Candidate: path/patch context helpers currently spread in `state/update` (if generalized beyond elmtui message semantics).
- Why: state transaction helpers are framework-agnostic.

4. `cl-styles`
- Candidate: remaining style plist normalization/conversion helpers currently in platform styling glue.
- Why: style translation logic can be shared across renderers.

## Task List

### Implemented Now
- [x] Add `src/core/system-events.lisp` and migrate runtime imports from `app.system-events`.
- [x] Remove `platform/driver` import of `elmtui.ui.widgets.root-viewport`.
- [x] Remove `pipeline` fallback dependency on `platform/driver::*ROOT-VIEWPORT-ID-PATH*`.
- [x] Remove `src/app/system-events.lisp` and update `elmtui.asd` load order/dependencies.
- [x] Add regression tests enforcing layering constraints.

### Next (Planned)
- [x] Create a small `elmtui.runtime.protocol` package to decouple driver orchestration from app/api concrete wiring.
- [x] Move legacy platform subtree into an optional system (`elmtui/legacy-platform`) or archive.
- [x] `cl-state`: path/patch context helpers currently spread in `state/update` (if generalized beyond elmtui message semantics).
- [x] `cl-styles`: remaining style plist normalization/conversion helpers currently in platform styling glue.
- [x] Prototype extraction of system events into `cl-events` and keep `elmtui` as a consumer.
- [x] Prototype extraction of token normalization into `cl-inputs`.

## Regression Strategy

Static layering checks now enforce:
- core files do not import `elmtui.app.system-events`
- driver does not import concrete root-viewport widget package
- pipeline does not reference `*ROOT-VIEWPORT-ID-PATH*`
- ASD uses `core/system-events` and not `app/system-events`

Dynamic coverage remains:
- full `./rt.sh`
- DSL alias resolution tests
- cleanup regression tests for removed stale files
