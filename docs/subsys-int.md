# Subsystem Integration Review: `cl-inputs`, `cl-state`, `cl-events`, `cl-styles`

Original review: 2026-03-07. Verified integration update: 2026-10-09.
Scope: integration boundaries between standalone `cl-*` subsystems and `elmtui` runtime/platform, with focus on replacement/extraction opportunities, architecture debt, and test/feature gaps.

## Executive Summary

The `cl-*` subsystems are already meaningfully integrated, but integration quality is uneven:

- core primitives are reused (`cl-events.channel`, `cl-state` state/observer, `cl-styles` styling engine, `cl-inputs` device/token stack),
- runtime orchestration remains duplicated in `elmtui` (loop/effect/input policy edges),
- historical subsystem test contracts were inconsistent (now corrected in this branch),
- most critical policy leaks are fixed (input transport and update macro effect execution).

High-impact corrections were implemented in this branch for:

1. subsystem test-op wiring consistency,
2. input transport policy separation,
3. update/effect boundary cleanup,
4. stylesheet type-boundary hardening,
5. transaction return-value contract correctness (multi-value preservation).

## Findings by Criticality

### P0-1: Transaction wrapper broke Elm-style update return contract (correctness)

Evidence:
- `cl-state/src/state/tx.lisp` `with-transaction` wrapped body result in `(let ((result (progn ...))) ...)`.
- That shape captures only the primary return value, dropping secondary values.
- `elmtui` update contracts rely on `(values model-or-patches commands)` and similar multi-value return forms.

Impact:
- update flows returning commands as second value could silently lose them,
- behavior depends on wrapper placement rather than explicit contract,
- architecture drifts from TEA semantics where update deterministically returns both model delta and commands.

Resolution implemented:
- `with-transaction` now captures `(multiple-value-list ...)` and returns via `values-list`,
- added regression test in `cl-state/tests/tx-tests.lisp` to lock this contract:
  `with-transaction-preserves-multiple-values`.

### P0-2: Subsystem test execution contract drift (silent regression risk)

Evidence:
- duplicate `cl-inputs/tests` system definitions with different behavior:
  - `cl-inputs/cl-inputs.asd`
  - `cl-inputs/cl-inputs-tests.asd`
- `cl-state` main system points test-op to `cl-state-tests`, but tests system had no explicit `:perform` runner:
  - `cl-state/cl-state.asd`
  - `cl-state/cl-state-tests.asd`
- `cl-styles` main system had test integration commented out:
  - `cl-styles/cl-styles.asd`
- `cl-events` main system had no test-op forwarding to `cl-events-tests`:
  - `cl-events/cl-events.asd`

Impact:
- CI/local validation may pass while missing real subsystem regressions,
- integration correctness confidence is lower than reported pass counts suggest.

Resolution implemented:
- unified test-op forwarding from each subsystem main system to its tests system,
- removed duplicate `cl-inputs/tests` declaration from `cl-inputs.asd`,
- added explicit `:perform` for `cl-state-tests`,
- restored `cl-styles` test-op integration and fixed runner target,
- added `cl-events` main system test-op forwarding.

### P1-1: Runtime loop duplication (`cl-events.loop` vs `elmtui.core.loop`)

Evidence:
- `cl-events` defines an app-loop contract in `cl-events/src/events/loop.lisp`,
- `elmtui` defines a separate event consumer runtime in `src/core/loop.lisp` + `src/core/event-channels.lisp`.

Impact:
- duplicated ownership of loop semantics (poll/wait, shutdown, sequencing),
- higher maintenance and correctness divergence risk,
- performance and diagnostics improvements must be repeated in two runtime paths.

Current status update:
- strict `cl-inputs` input loop contract is now enforced in driver/runtime,
- key loop policies are now delegated to `cl-events.loop` (`poll`, deadline helpers, consume-step policy, bootstrap selection, error-action resolution),
- remaining duplication is mostly thread lifecycle shell/orchestration glue in `elmtui.core.loop`.

### P1-2: Input transport layer had app policy leakage

Evidence:
- `src/platform/input.lisp` rewrote `Tab` / `Shift+Tab` into app-specific focus messages in reader transport path.

Impact:
- transport boundary was not pure (token/event transport mixed with app behavior policy),
- harder to test and reason about focus behavior as keymap/application concern.

Resolution implemented:
- reader path now preserves mapped input events as transport output,
- no built-in `Tab` focus policy rewrite in transport reader.

### P1-3: `defupdate` macro executed effects directly (second effect path)

Evidence:
- `src/state/update.lisp` `defupdate` applied patches and then directly executed commands via `handle-async-command`.

Impact:
- split effect authority between update macro and runtime effect manager,
- architecture drift from the single effect boundary established in runtime/driver.

Resolution implemented:
- `defupdate` now produces commands only,
- effect execution remains runtime-owned.

### P2-1: Stylesheet type-checking boundary was brittle

Evidence:
- `src/style/manager.lisp` used package-name checks on `(type-of x)` instead of type predicate.

Impact:
- fragile on non-stylesheet values and refactors,
- unnecessary coupling to type symbol package-string shape.

Resolution implemented:
- replaced with `typep` against `cl-styles.sheet:stylesheet`.

### P2-2: Message/schema validation overlap (resolved in R2)

Evidence:
- schema validation logic exists in `src/core/events.lisp`, while contracts use boundary delegation (`src/state/message-normalization.lisp`).

Impact:
- historically dual validation paths could drift.

Resolution:
- R2 now delegates both `src/contracts.lisp` and `src/core/events.lisp` validation to `src/state/message-normalization.lisp:validate-message-instance` (see implemented-change item 11). Keep parity tests when contracts change.

## Replacement / Extraction Opportunities

1. Replace ad-hoc event-channel wrappers in `elmtui.core.event-channels` with stronger use of `cl-events` channel abstractions where possible.
2. Extract reusable loop primitives (poll/backoff/shutdown coordination metrics) from `elmtui.core.loop` into `cl-events` if they are framework-agnostic.
3. Keep focus/key semantics in keymap/focus/app-update layers, not input transport.
4. Keep command/effect execution only in runtime effect manager boundary.
5. Keep stylesheet typing/normalization at `cl-styles` type contracts and adapters.

## Which Loop Direction Is Superior? (Requested Decision for Item 2)

Short answer: **prefer keeping `elmtui` as runtime orchestrator while extracting generic loop primitives into `cl-events`**.

Why this is superior in current architecture:
- `elmtui` loop is tightly integrated with `elmtui`-specific concerns (driver lifecycle, render pipeline timing, app message processor contracts, root viewport behavior, startup terminal/cursor bootstrap),
- replacing it wholesale with `cl-events.loop` now would require a broader runtime rewrite and requalification across driver/render/focus/shutdown paths,
- `cl-events.loop` is a stronger generic substrate but currently lacks some `elmtui`-specific orchestration responsibilities.

Detailed comparison:
- `cl-events.loop` strengths:
  - generic channel/event loop substrate, reusable outside `elmtui`,
  - cleaner primitive ownership for queue wait/shutdown/backoff.
- `elmtui.core.loop` strengths:
  - already integrated with render cadence, app-message processor, runtime globals, and driver lifecycle.
- immediate full replacement tradeoff:
  - high migration blast radius (driver + rendering + lifecycle + tests),
  - limited near-term architecture benefit compared with extracting only generic pieces.

Best path:
1. keep `elmtui.core.loop` as canonical runtime owner for now,
2. extract framework-agnostic pieces to `cl-events` (mailbox/channel wait semantics, stop signaling pattern, utility lifecycle primitives),
3. optionally converge toward a thinner `elmtui` orchestrator over a richer `cl-events` loop contract once parity is proven by integration tests.

This gives immediate correctness and maintainability gains without a high-risk runtime replacement.

## Subsystem Health Notes

### `cl-inputs`
- Strengths: device abstraction, token decoding, adapters, broad low-level tests.
- Gaps: test-system definition drift (fixed in this branch).
- Needed feature direction: keep transport/adapters pure; app policy outside.

### `cl-state`
- Strengths: mature core/tx/observer/schema utilities used deeply by `elmtui`.
- Gaps: tests runner contract needed explicit `:perform` (fixed here); tx wrapper had multi-value collapse bug (fixed here).
- Needed feature direction: avoid embedding effect execution in state/update helper macros.

### `cl-events`
- Strengths: solid generic channel/bus/async/loop substrate.
- Gaps: `elmtui` still owns consumer thread lifecycle shell and restart-case wrapper.
- Needed feature direction: extract shared runtime primitives from `elmtui` into `cl-events` incrementally.

### `cl-styles`
- Strengths: reusable selector/rule/engine/property stack.
- Gaps: main system test-op integration had been disabled (fixed here).
- Needed feature direction: rely on formal type contracts and adapters, not package-string checks.

## Implemented Changes (This Branch)

1. Test wiring consistency:
- `cl-inputs/cl-inputs.asd`
- `cl-events/cl-events.asd`
- `cl-state/cl-state-tests.asd`
- `cl-styles/cl-styles.asd`

2. Input transport policy separation:
- `src/platform/input.lisp`

3. Runtime effect ownership cleanup in update macro path:
- `src/state/update.lisp`

4. Robust stylesheet type boundary:
- `src/style/manager.lisp`

5. Transaction multi-value contract fix:
- `cl-state/src/state/tx.lisp`

6. Regression tests added/updated:
- `tests/state-update-tests.lisp`
- `tests/integration-adapters-tests.lisp`
- `cl-state/tests/tx-tests.lisp`
- `tests/driver-tests.lisp`

7. Loop convergence progress (strict `cl-inputs` runtime input contract in `elmtui`):
- `src/platform/driver.lisp`
  - removed fallback reader path that used backend `poll-input-event`,
  - startup now requires backend-exposed `cl-inputs` input-source,
  - driver input loop exclusively pulls via `cl-inputs.loop:next-token`,
  - `start-driver-input-loop` now enforces input-source presence.
- `src/platform/input.lisp`
  - `start-reader` switched from `poll-input-event` polling to `cl-inputs.loop:next-token` pull loop,
  - reader now enforces `backend-input-source` contract explicitly.

Parity assurance added:
- new driver tests verify strict contract and token->event publish path via `cl-inputs.loop:next-token`.

8. Loop convergence progress (shared runtime loop primitives extracted to `cl-events`):
- `cl-events/src/events/loop.lisp`
  - added reusable runtime helpers:
    - `poll-runtime-event`
    - `make-join-deadline`
    - `deadline-expired-p`
  - exported via `cl-events.loop` package contract.
- `src/core/loop.lisp`
  - replaced local poll call with `%poll-runtime-event` delegation into `cl-events.loop:poll-runtime-event`,
  - replaced local shutdown deadline math/check with `cl-events.loop` helpers.
  - switched channel bootstrap selection to `cl-events.loop:select-primary-channel`,
  - switched consume-iteration execution to `cl-events.loop:runtime-consume-once` (policy-hooked error/idle/event handling).
  - switched consumer poll-error action to policy resolution via `cl-events.loop:resolve-runtime-error-action`.

Additional parity tests:
- `cl-events/tests/loop-tests.lisp`
  - verifies poll delegation timeout contract,
  - verifies deadline helper correctness.
  - verifies channel selection policy helper behavior,
  - verifies consume-once policy hook behavior (`:stop`, `:event`, `:idle`, error-action).
- `tests/integration-adapters-tests.lisp`
  - verifies `elmtui.core.loop` poll path delegates to `cl-events.loop`.
  - verifies `elmtui.core.loop` channel bootstrap delegates to `cl-events` selection policy.
  - verifies consumer error policy controls stop vs restart semantics.
  - verifies `event-consumer-loop` delegates lifecycle shell orchestration to `cl-events.loop:run-consumer-loop-shell`.

9. Fully pluggable restart-policy convergence (completed):
- `cl-events/src/events/loop.lisp`
  - added `default-runtime-error-policy`,
  - added `resolve-runtime-error-action` contract (`:stop` / `:restart`).
- `src/core/loop.lisp`
  - added `*consumer-error-policy*` runtime policy hook,
  - added `%handle-consumer-poll-error` that delegates policy resolution to `cl-events`,
  - `event-consumer-loop` now reacts to resolved actions:
    - `:stop` => mark shutdown and exit loop,
    - `:restart` => invoke restart branch.
- Tests:
  - `cl-events/tests/loop-tests.lisp`: policy resolution contract tests,
  - `tests/integration-adapters-tests.lisp`: end-to-end policy effect tests in `elmtui.core.loop`.

10. Consumer lifecycle shell extraction (R1 completed):
- `cl-events/src/events/loop.lisp`
  - added reusable `run-consumer-loop-shell` to own generic stop/idle/restart shell flow.
- `src/core/loop.lisp`
  - `event-consumer-loop` now delegates outer lifecycle orchestration to the shared helper and only supplies app-specific callbacks.
- Tests:
  - `cl-events/tests/loop-tests.lisp`: direct lifecycle helper behavior (stop/idle/restart),
  - `tests/integration-adapters-tests.lisp`: `elmtui` delegation/parity assertion.

11. Message validation authority unification (R2 completed):
- `src/state/message-normalization.lisp`
  - added canonical shared validator `validate-message-instance` for defmsg schema checks (variant + arity + argument types).
- `src/contracts.lisp`
  - `validate-typed-message` now delegates to shared validator and surfaces reasoned contract violations.
  - hybrid cross-schema recognition now uses full schema validation instead of variant-head-only checks.
- `src/core/events.lisp`
  - `validate-message-via-schema` now delegates to shared validator and only maps failures to `message-validation-error`.
- Tests:
  - `tests/contracts-tests.lisp`: added regression for typed validation wrong argument type rejection.

12. Deterministic full-path runtime integration tests (R3 completed):
- Added `tests/runtime-e2e-tests.lisp`:
  - `runtime-e2e-token-route-update-effects-render` verifies deterministic path:
    `cl-inputs token -> event routing -> update -> runtime effects -> render`.
  - `runtime-e2e-shutdown-clears-subscriptions-and-skips-render` verifies shutdown semantics:
    subscription teardown/cancel invocation and render suppression after shutdown request.
- Wired into `elmtui-tests.asd`.

## Normal-screen scroll integration (2026-10-09)

Current integration decision: ElmTUI preserves terminal scrollback by keeping
inline/below-cursor rendering in the normal screen; alternate-screen switching
is not required or an acceptable fallback for these applications.

- `src/ui/widgets/root-viewport.lisp` computes terminal-overflow scroll effects,
  tracks issued and acknowledged scroll deltas (`:issued-scroll-net`,
  `:scrolled-net`, `:pending-scroll-ops`), and adjusts fresh cursor probes by
  already acknowledged displacement. If a scroll effect fails, overflow may
  degrade to truncation rather than claiming a successful reservation.
- `src/platform/driver.lisp` synchronously executes render scroll commands,
  collects resulting acknowledgement messages, runs them through the active
  update function, and installs the acknowledged model **before** invoking the
  next view/render pass. This prevents frame geometry from lagging one event.
- `tests/viewport-scroll-integration-tests.lisp` exercises ordered scroll
  notifications, net tracking, below-cursor startup/shutdown, and viewport
  isolation. Live tmux/PTY scrollback preservation remains a separate gate;
  deterministic unit/integration coverage is not proof of all terminal setups.

This is application/terminal orchestration, not a reason to move
root-viewport policy into `cl-events` or `cl-inputs`.

## Current verification snapshot (2026-10-09)

- Core test suite: **4,743 pass, 6 live-tmux skips, 0 fail** under
  `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load run-tests-clpm.lisp`
  in a shared working tree; this is not a clean-clone/PTY qualification.
- `scripts/check-docstrings.sh`: pass (65.0% coverage; 637 / 1,819 missing).
- `python3 -m mkdocs build --strict`: not run successfully because the
  `mkdocs` Python module is unavailable in the current environment.
- Historic P0/P1 fixes recorded above describe integration code, not independent
  proof of every release gate. R4 policy hardening and public website/PTY gates
  remain outstanding until independently verified.

## Remaining TODOs (Prioritized)

1. R4 Runtime policy contract hardening (P2)
- Scope:
  - formalize policy type/shape contracts for:
    `*consumer-error-policy*`, bootstrap selection, and consume-step hooks.
  - validate invalid policy values early with explicit conditions.
- Acceptance:
  - invalid policy configuration fails fast with clear error condition,
  - tests cover valid keyword policy and function policy cases.

2. R5 Documentation and artifact sync (P2)
- Scope:
  - keep this document and core architecture review doc in sync on completed convergence slices.
  - add a compact status table for “planned / in progress / done” per convergence track.
- Acceptance:
  - no stale “leaky boundary” claims after fixes,
  - TODOs map directly to executable backlog items.
