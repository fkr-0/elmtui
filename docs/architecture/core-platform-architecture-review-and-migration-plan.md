# Core + Platform Architecture Review and Migration Plan

## Document Purpose

This document records architecture and performance issues discovered in the core runtime path, prioritizes them by criticality, and defines a migration plan toward a cleaner Elm-aligned runtime architecture.

Primary focus files:
- `src/platform/driver.lisp`
- `src/core/loop.lisp`

Referenced runtime modules:
- `src/core/event-channels.lisp`
- `src/core/async.lisp`
- `src/runtime/protocol.lisp`
- `src/pipeline.lisp`
- `src/contracts.lisp`
- `src/app/tea-core.lisp`
- `src/core/globals.lisp`

## Executive Summary

The current runtime contains good Elm-inspired primitives (`init/update/view`, commands, subscriptions), but execution flow has drifted away from a single deterministic message-update-effect loop.

The most serious issues are:
1. event consumer thread lifecycle bug that can spawn duplicate consumers,
2. inconsistent bootstrap processor/queue lifecycle,
3. dual model mutation paths (driver update path and direct root dispatch path).

These issues create race risk, weaken determinism, and make behavior harder to reason about and test. Performance is also impacted by avoidable hot-path allocations, aggressive polling, and high-volume logging in event/render paths.

## Implementation Status (2026-03-06)

Status by review track:
- `R1` Effect manager extraction: `complete` (subscription install/cancel/reconcile moved behind runtime effect manager API).
- `R2` Update-signature normalization: `complete` (canonical `(message model)` enforced with guardrails and regression tests).
- `R3` Reproducible baseline artifacts: `complete` (metadata-rich artifacts + threshold-based regression gate).
- `R4` Blocking wait model evaluation: `complete` (polling model retained for now; correctness issue fixed first).

Completed architecture/performance changes on this branch:
- introduced runtime effect manager module: `src/runtime/effects.lisp`,
- routed driver command execution through effect manager helpers:
  - `apply-update-effects`,
  - `run-commands-with-policy`,
- reduced direct effect execution in driver hot path (`initialize-app-model`, initial command handling),
- removed direct `interpret-cmd` dependency from `src/platform/driver.lisp` subscription path,
- centralized subscription lifecycle in runtime effect manager:
  - `reconcile-model-subscriptions`,
  - `clear-subscription-registry`,
- normalized update call contract to canonical `(message model)` in:
  - `src/contracts.lisp` macros and validation call path,
  - `src/app/application.lisp` generated contracted update forms,
  - contract/widget test/update macro call sites using defupdate wrappers,
- added compile-time update signature guardrail in contracts macros:
  - rejects obvious swapped `(model message)` forms,
- added shutdown join timeout guard in `src/core/loop.lisp`:
  - bounded wait (`+consumer-join-timeout-seconds+`),
  - forced teardown fallback instead of unbounded block,
- fixed event receive semantics in `src/core/event-channels.lisp`:
  - `no-wait` now treated as a consuming receive primitive (no double-consume),
  - removed every-other-message drop behavior in loop polling path,
  - restored graceful shutdown signal delivery (`:shutdown-loop` no longer discarded),
- added reproducible benchmark harness:
  - `scripts/benchmarks/core_platform_baseline.lisp`,
  - `scripts/benchmarks/check_core_platform_regression.lisp`,
  - `docs/benchmarks/core-platform-thresholds.sexp`,
  - artifacts in `docs/benchmarks/`.
- added regression tests for effect-manager subscription reconciliation:
  - `tests/runtime-effects-tests.lisp`.

Validation snapshot:
- full suite executed multiple times via `./rt.sh`, latest run green:
  - `Pass: 1854`, `Skip: 1`, `Fail: 0`.
- benchmark command:
  - `clpm bundle exec -- sbcl --script scripts/benchmarks/core_platform_baseline.lisp`
- regression gate command:
  - `sbcl --script scripts/benchmarks/check_core_platform_regression.lisp`
- latest baseline artifact:
  - `docs/benchmarks/core-platform-baseline-2026-03-06.json`
  - `docs/benchmarks/core-platform-baseline-2026-03-06.md`
  - `docs/benchmarks/core-platform-baseline-2026-03-06.sexp`
- latest regression artifact:
  - `docs/benchmarks/core-platform-regression-2026-03-06.json`
  - `docs/benchmarks/core-platform-regression-2026-03-06.md`

Latest measured baseline (2026-03-06):
- idle CPU: `1.076%` over `3.000s`,
- throughput: `5807.278 events/s`,
- p95 latency: `2.000 ms`,
- throughput run completes `10000 / 10000` without timeout.

## Remaining Tasks (Detailed)

### R1: Finish effect manager extraction (P0) - complete

Done:
- subscription install/cancel/reconcile internals moved to `src/runtime/effects.lisp`,
- driver now delegates subscription reconciliation to runtime effect manager,
- driver no longer imports async command interpreter primitives for subscriptions.

### R2: Finalize signature normalization enforcement (P1) - complete

Done:
- contracts macros enforce canonical parameter order heuristically and reject obvious swapped signatures,
- stale contract comments/examples updated to canonical `(message model)`,
- regression test added for swapped-signature detection in `tests/contracts-tests.lisp`.

### R3: Extend baseline into regression gate (P1) - complete

Done:
- baseline artifacts now include environment metadata and ISO timestamps,
- stable `latest` artifact set added (`json`, `md`, `sexp`),
- explicit threshold file added: `docs/benchmarks/core-platform-thresholds.sexp`,
- regression check script emits pass/fail artifacts and exit codes.

Current follow-up:
- wire regression script into CI target (outside this branch’s local scope).

### R4: Wait model decision (completed)

Observed evidence from baseline + fix validation:
- idle CPU remains low (~`1.076%`),
- graceful shutdown now works in benchmark and targeted probes,
- throughput correctness restored (`10000/10000` processed),
- root cause was `no-wait` misuse in channel polling (it consumed events; polling then consumed again).

Interpretation:
- replacing polling with a deeper blocking model is not currently justified as a priority.

Remaining work:
- optional future experiment: evaluate blocking/select wait model only if new perf goals require lower idle wakeups.

## Severity Scale

- `P0`: correctness, determinism, or shutdown/startup safety risk.
- `P1`: significant architectural or performance debt with high operational impact.
- `P2`: moderate debt; important but not immediate correctness risk.

## Findings by Criticality

### P0-1: Duplicate event consumer thread risk in `start-loop`

Evidence:
- `src/core/loop.lisp:80`

Details:
- `start-loop` currently spawns a consumer thread when this condition is true:
  - consumer thread is null, or
  - `(not *shutdown-requested*)`, or
  - thread exists but not alive.
- During normal operation `*shutdown-requested*` is false, so repeated `start-loop` calls can satisfy the condition and create additional consumer threads.

Impact:
- race conditions during dequeue and routing,
- nondeterministic message ordering,
- hard-to-reproduce rendering/state anomalies,
- difficult shutdown behavior.

Elm architecture drift:
- Elm runtime semantics assume one mailbox consumer and deterministic sequencing.

---

### P0-2: Bootstrap message processor lifecycle is internally inconsistent

Evidence:
- bootstrap processor and queue logic: `src/platform/driver.lisp:165`
- bootstrap installed: `src/platform/driver.lisp:801`
- message processor overwritten in init: `src/platform/driver.lisp:270`
- later "real processor install" step is effectively a pass-through of current value: `src/platform/driver.lisp:896`

Details:
- A bootstrap processor exists to queue early messages until terminal/cursor readiness.
- `initialize-app-model` sets `*app-message-processor*` to the real update lambda, replacing bootstrap behavior.
- `*real-app-message-processor*` is not consistently wired into this lifecycle.
- The system therefore does not enforce a clear, guaranteed buffering/flush contract.

Impact:
- startup order fragility,
- implicit temporal coupling between backend init and update path activation,
- increased risk of dropped/reordered early system messages.

Elm architecture drift:
- startup should be explicit and deterministic (stateful runtime phase), not implicit via mutable processor swapping.

---

### P0-3: Two model mutation funnels violate single update authority

Evidence:
- app-level update path in driver: `src/platform/driver.lisp:296`
- direct root dispatch + patch apply path: `src/platform/driver.lisp:428`
- startup uses synchronous root message path: `src/platform/driver.lisp:915`

Details:
- Path A: app update function processes message and returns next model + commands.
- Path B: `synchronous-root-message` dispatches directly to root component update and applies patches to current model.
- Path B is used during startup for terminal/cursor initialization events.

Impact:
- state transition logic is split across runtime surfaces,
- invariants and testing become significantly harder,
- increased regression risk when one path changes without the other.

Elm architecture drift:
- Elm architecture requires one canonical `update` boundary for model transitions.

---

### P1-1: Event metrics history reallocates and copies on hot path

Evidence:
- `src/core/loop.lisp:224`

Details:
- On each event, processing time is pushed to an adjustable vector.
- When over 100 entries, a new vector is allocated and populated with `subseq`.
- This introduces repeated allocation/copy churn in core event processing.

Impact:
- avoidable GC pressure,
- measurable latency jitter under bursty workloads,
- unnecessary CPU overhead.

Recommendation:
- replace with fixed-size ring buffer.

---

### P1-2: Polling strategy is CPU-heavy and repeatedly sorts channels

Evidence:
- sort channels per wait call: `src/core/event-channels.lisp:208`
- spin with short sleep: `src/core/event-channels.lisp:236`
- consumer repeatedly calls wait with timeout: `src/core/loop.lisp:115`

Details:
- `wait-for-event` stable-sorts channels each call.
- It then no-wait polls each channel and sleeps in a loop.
- Consumer loop calls this continuously.

Impact:
- elevated idle CPU,
- reduced throughput margin,
- less predictable latency under load.

Recommendation:
- precompute sorted channel order on topology changes,
- move to blocking/select-based wait where library capabilities allow.

---

### P1-3: Hot-path logging volume is high

Evidence:
- event process log: `src/core/loop.lisp:166`
- key event processing log: `src/core/loop.lisp:191`
- update/render logs in driver loop: `src/platform/driver.lisp:272`, `src/platform/driver.lisp:323`

Details:
- numerous `info`/`debug` statements are on per-event and per-render paths.
- if logging category levels are permissive, this materially affects runtime performance.

Impact:
- lower throughput,
- unnecessary IO overhead,
- log noise obscuring meaningful diagnostics.

Recommendation:
- introduce scoped trace categories and default-off hot-path traces.

---

### P1-4: Channel abstraction complexity exceeds practical usage

Evidence:
- channel definitions: `src/core/event-channels.lisp:166`
- publish default target: `src/core/loop.lisp:324`
- generic wrapping into `(:app-message ...)`: `src/core/loop.lisp:346`

Details:
- runtime defines multiple channel types with priorities.
- practical traffic largely funnels into default target and a generic message envelope.
- result is added indirection without full leverage of type-priority channel model.

Impact:
- complexity overhead,
- added allocation and routing branches,
- weaker conceptual clarity for event flow.

Recommendation:
- either fully commit to typed channel semantics, or simplify to a single mailbox with normalized `Msg`.

---

### P2-1: Input loop adds avoidable latency

Evidence:
- timeout polling token read: `src/platform/driver.lisp:631`
- additional sleep per loop: `src/platform/driver.lisp:636`

Details:
- input loop already blocks with timeout on token source,
- then enforces extra fixed sleep each cycle.

Impact:
- avoidable input lag/jitter,
- lower responsiveness.

---

### P2-2: Global app state usage is inconsistent for async path

Evidence:
- async route uses `*app-state*`: `src/core/loop.lisp:216`
- global definition exists, but runtime path reviewed centers on `*current-app-model*`: `src/core/globals.lisp:43`

Details:
- driver mutates `*current-app-model*` directly,
- async handler route references a separate global state slot.

Impact:
- risk of stale/nil state in async command handling,
- split-brain state ownership.

Recommendation:
- consolidate runtime state reference into one source of truth.

Current branch status:
- mitigated for active runtime flow by synchronizing `*app-state*` on each driver model commit,
- still recommended long-term to remove duplicated mutable globals and keep one canonical runtime model owner.

---

### P2-3: Update function argument-order conventions are inconsistent

Evidence:
- `deftea-app` docs indicate `(msg model)`: `src/app/tea-core.lisp:31`
- contract macro documentation indicates `(model, message)`: `src/contracts.lisp:403`
- protocol dispatch call site has its own ordering assumptions: `src/runtime/protocol.lisp:37`

Details:
- documentation/contracts/runtime shape do not consistently communicate one canonical ordering.

Impact:
- integration confusion,
- accidental adapter mistakes,
- maintenance overhead.

Recommendation:
- codify one canonical update signature and enforce in docs and macros.

## Drift Analysis vs Elm Architecture

### Present strengths
- explicit `init`, `update`, `view` application model is in place,
- command/subscription concepts are represented,
- rendering pipeline is modularized.

### Main drifts
- multiple model mutation entry points,
- global mutable runtime control state,
- startup lifecycle controlled via mutable processor swapping instead of an explicit phase machine,
- event-channel complexity that does not map cleanly to actual message flow.

## Target State Architecture

Runtime invariants:
1. exactly one consumer thread for message intake,
2. exactly one model transition boundary,
3. one canonical runtime message envelope (`Msg`),
4. effect execution managed by dedicated effect interpreter,
5. render decision made in one runtime post-update stage,
6. single source of truth for current model/state reference.

Canonical loop:
1. dequeue `Msg`,
2. run `update(model, msg) -> (model', effects)`,
3. commit model',
4. reconcile subscriptions,
5. interpret effects,
6. render according to policy,
7. continue.

## Migration Plan

### Phase 0: Safety and baselining (behavior-preserving) - Status: Mostly Complete

Objectives:
- fix consumer spawn condition,
- add runtime assertion/metric for single consumer,
- gate hot-path logging,
- capture baseline perf metrics (idle CPU, event throughput, p95 input-to-render latency).

Deliverables:
- patch set for loop lifecycle and log gating,
- benchmark script + recorded baseline artifact.

Exit criteria:
- repeated start/stop cannot create multiple consumers,
- baseline metrics are reproducible.

Progress notes:
- completed: consumer spawn fix and logging reduction on major hot paths.
- pending: explicit baseline benchmark artifact capture (idle CPU/latency numbers).

---

### Phase 1: Startup lifecycle refactor - Status: Complete (for current runtime path)

Objectives:
- replace bootstrap processor swapping with explicit startup state machine.

Suggested startup states:
- `:booting`
- `:awaiting-terminal-info`
- `:running`

Deliverables:
- runtime startup state machine,
- deterministic buffering and flush policy,
- removal of ambiguous bootstrap globals where obsolete.

Exit criteria:
- deterministic startup ordering tests pass,
- early terminal/cursor events handled predictably.

Progress notes:
- completed: bootstrap globals/queue swapping removed; startup terminal/cursor events now go through canonical processor.
- completed: explicit runtime startup phase state transitions added and exercised in driver lifecycle.

---

### Phase 2: Single update authority enforcement - Status: Complete (for reviewed driver path)

Objectives:
- remove or deprecate direct synchronous root mutation route for normal runtime transitions,
- route startup terminal/cursor events through canonical app message path.

Deliverables:
- one mutation funnel in runtime,
- refactored startup event dispatch.

Exit criteria:
- all model transitions are observable through one update boundary.

Progress notes:
- completed in core startup flow by removing direct synchronous root patch application.

---

### Phase 3: Event routing simplification - Status: Complete (current target)

Objectives:
- simplify channels to match true workload:
  - single mailbox design, or
  - minimal ingress channels that normalize to one `Msg`.
- eliminate unnecessary envelope wrapping and per-event overhead.

Deliverables:
- simplified publish/route path,
- updated docs and diagnostics.

Exit criteria:
- channel architecture and runtime behavior are conceptually aligned.

Progress notes:
- completed by moving to single-message-channel primary runtime behavior and simplifying fallback routing.

---

### Phase 4: Effect manager extraction - Status: Not Started

Objectives:
- move effect execution responsibilities from driver lambda into dedicated runtime effect manager,
- unify timer/async cancellation registry,
- keep update side-effect free from runtime perspective (outputs intent, not execution).

Deliverables:
- effect manager module,
- stable effect IDs and cancellation semantics.

Exit criteria:
- driver responsibility limited to platform orchestration.

---

### Phase 5: Performance-focused cleanup - Status: Mostly Complete

Objectives:
- ring-buffer metrics storage,
- remove per-call channel sorting,
- prefer blocking/select-based waiting,
- remove fixed extra sleep from input loop.

Deliverables:
- hot-path allocation reduction,
- improved idle efficiency and tail latency.

Exit criteria:
- measurable improvement in baseline metrics established in Phase 0.

Progress notes:
- completed: ring-buffer metrics, removal of per-call channel sorting, input-loop sleep removal.
- pending: benchmark evidence capture and optional deeper blocking/select wait model work.

---

### Phase 6: Contract and API normalization - Status: Not Started

Objectives:
- standardize update signature documentation and enforcement,
- align `deftea-app`, contracts, and runtime protocol docs,
- publish final runtime architecture ADR.

Deliverables:
- normalized docs/macros,
- architecture decision record.

Exit criteria:
- no signature ambiguity in public APIs or internal contracts.

## Recommended Pull Request Sequence

1. `PR-1`: loop lifecycle safety + logging gates + perf baseline harness
2. `PR-2`: startup state machine and bootstrap cleanup
3. `PR-3`: single update funnel enforcement
4. `PR-4`: effect manager extraction
5. `PR-5`: hot-path performance optimization
6. `PR-6`: contract/docs normalization and ADR finalization

## Validation Strategy

Required test categories during migration:
- startup determinism tests,
- shutdown race tests,
- burst input ordering tests,
- subscription reconciliation and cancellation tests,
- render stability tests across terminal resize/cursor updates,
- performance regression benchmarks.

Suggested non-functional acceptance targets:
- no duplicate consumers under restart scenarios,
- lower idle CPU than baseline,
- reduced allocations per event in profiler,
- improved p95 end-to-end input-to-render latency.

## Conclusion

The architecture can be made substantially cleaner and more Elm-aligned without a full rewrite. The key is to enforce single-thread/single-update determinism first, then converge routing/effects/state ownership, then optimize the hot paths. The phased plan above is designed to reduce risk while continuously improving correctness and performance.
