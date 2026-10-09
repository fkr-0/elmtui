# ElmTUI architecture, quality, documentation, and e2e TODO

Date: 2026-08-12

This is the execution checklist for the architecture/quality review. Checked items were implemented or verified during the current pass. Unchecked items are deliberately retained because they either require a compatibility decision, a broad mechanical documentation campaign, or a separately reviewable refactor.

## 0. Safety and baseline

- [x] Open the repository through the project workspace and preserve pre-existing untracked work.
- [x] Read repository-specific Common Lisp/structural-editing instructions.
- [x] Establish deterministic baseline before architecture edits.
- [x] Baseline full suite: 2,179 pass, 0 fail, 6 opt-in live-tmux skips.
- [x] Re-run full suite after runtime/restart changes.
- [x] Current full suite: 3,075 pass, 0 fail, 6 opt-in live-tmux skips (3,081 total checks).
- [x] Run sublibrary-specific tests after changing `cl-events` and `cl-inputs`.
- [x] Keep warning-clean verification in the repository release gate.
- [x] Add the docstring regression audit to `bridge.yml` and the repository release gate.
- [ ] Add warning-clean, doc audit, and generated-doc freshness checks to hosted CI when hosted CI exists.

## 1. Central polling and waiting semantics

### 1.1 Ownership

- [x] Inventory repeated polling/sleep/deadline loops in `cl-events` and ElmTUI core.
- [x] Make `cl-events.loop` the owner of cooperative repeated probing.
- [x] Add `cl-events.loop:poll-until`.
- [x] Preserve multiple values from successful probes.
- [x] Define timeout semantics: NIL = unbounded, zero = one probe, positive = bounded wait.
- [x] Support cancellation via `stop-p`.
- [x] Support deterministic tests via injectable clock/sleep functions.
- [x] Keep interval/backoff configuration in the central implementation.
- [x] Document mutation and condition propagation.

### 1.2 Call-site migration

- [x] Replace `try-receive-event` deadline/sleep loop with `poll-until`.
- [x] Replace `wait-for-event` deadline/sleep loop with `poll-until`.
- [x] Replace consumer-thread shutdown deadline/sleep loop with `poll-until`.
- [x] Fix `wait-for-event` to honor declared channel priority instead of relying on caller ordering.
- [x] Keep backend `device-wait-readable` as blocking I/O rather than pretending it is a polling loop.
- [x] Re-scan the runtime for `sleep`/deadline/poll loops and migrate the remaining platform-driver liveness and shutdown-flag waits to `poll-until`; retain true device blocking, timers, debounce, recurring-task pacing, and dev refresh intervals as explicit non-polling behavior.
- [ ] Search future changes for new `sleep` + deadline loops and reject them when `poll-until` is the correct primitive.
- [ ] Decide whether polling policy should eventually support adaptive/exponential backoff for non-terminal integrations; do not add it until a measured use case exists.

### 1.3 Tests

- [x] Unit-test repeated probing and multiple-value preservation.
- [x] Re-run all `cl-events` tests: 128/128 passing.
- [ ] Add a deterministic positive-timeout boundary test with an injected monotonic clock.
- [x] Add zero-timeout single-probe/no-sleep coverage.
- [x] Add stop-p cancellation-before-probe coverage.
- [ ] Add a priority-order integration test with high/normal/low channels supplied in intentionally scrambled order.

## 2. Common Lisp condition/restart architecture

### 2.1 Base conditions

- [x] Add a real `message` slot/reader to `elmtui-error` because the constructor already accepted `:message`.
- [x] Preserve structured context values in `make-elmtui-error` instead of coercing them to strings.
- [x] Export meaningful readers from `elmtui.core.errors` for debugger/programmatic inspection.
- [x] Document the base condition as inspectable structured diagnostic data.
- [ ] Introduce a consistent root condition hierarchy for all framework conditions, including non-error informational/warning conditions where appropriate.
- [ ] Migrate direct-`error` subclasses in `elmtui.core.conditions` under the framework hierarchy without breaking handlers.
- [ ] Replace generic exported readers such as `message`, `reason`, and `state` with prefixed reader APIs plus a deprecation window.
- [ ] Define a standard context schema vocabulary: operation, component-id, component-path, state-path, backend, message/event, offending-value, expected-type, underlying-condition.

### 2.2 Context annotation

- [x] Replace condition reconstruction in `with-error-context` with `handler-bind` annotation of the original object.
- [x] Preserve subtype slots and condition identity.
- [x] Preserve active restart/debugger relationships.
- [x] Document that only diagnostic condition slots mutate.
- [ ] Consider a non-mutating context wrapper condition for callers that require condition immutability; do not add unless a real need appears.

### 2.3 Restart scopes

- [x] Put restart cases around failing operations rather than around re-signaling from a handler.
- [x] Normalize quoted/literal restart lists correctly at macro expansion time.
- [x] Implement `:ignore-task`, which async call sites already requested.
- [x] Support `:retry`, `:skip`, `:ignore-task`, `:use-value`, and `:abort` in the generic recovery macro.
- [x] Convert message-specific and render-specific restart macros to the same correct scope model.
- [x] Document retry/idempotency hazards.
- [x] Add e2e coverage proving an outer handler can inspect the original `state-error` and invoke `USE-VALUE`.
- [x] Add dedicated restart tests for generic, message, render, and async recovery: `RETRY`, `SKIP`, `IGNORE-TASK`, replacement/fallback/provided-result, `USE-VALUE`, and `ABORT`.
- [x] Add debugger-hook tests proving exact condition identity, enriched structured context, restart visibility during debugger inspection, pre-unwind handler behavior, and restart lifetime after scope exit.
- [ ] Expose operation-specific restart helpers only where they make application-level handlers genuinely simpler.

### 2.4 Suppression policy

- [ ] Inventory every `ignore-errors` in runtime code.
- [ ] Classify each use as teardown, optional probe, or normal-path suppression.
- [ ] Replace normal-path blanket suppression with narrow handlers and structured logging/context.
- [ ] For teardown, explicitly document best-effort behavior and continue restarts.
- [ ] For optional probes, catch only expected condition types.

## 3. Elm / TEA semantics and state ownership

### 3.1 Establish the truthful model

- [x] Inspect `deftea-app`, platform driver model replacement, `cl-state`, update contexts, patch application, and transactional mutation.
- [x] Replace the coarse “mutation violates Elm” framing with an observational/refinement model: hidden representation mutation is compatible with TEA when logical state and command traces are equivalent and intermediate writes are unobservable.
- [x] Fix update-draft aliasing so supported nested plist/hash/vector state is isolated before update decisions are converted to patches.
- [x] Implement `DEFAPPLICATION :state-semantics :transactional` and `:strict-elm` as two commit engines for the same update/patch contract.
- [x] Make `:strict-elm` return a fresh state snapshot and preserve the prior supported container graph.
- [x] Dynamically forbid supported state mutation during strict update/component/view/subscription/custom-command phases via inspectable `STATE-MUTATION-FORBIDDEN`.
- [x] Differential-test strict and transactional applications over the same message trace and compare logical state + emitted commands.
- [x] Document the remaining proof boundary: explicitly internal `CL-STATE.CORE` representation access, arbitrary Common Lisp side effects, and custom mutable leaf values are escape hatches rather than magically immutable data; the public state-data compatibility read is an owned snapshot.

### 3.2 Convergence decision

- [x] Provide strict replacement semantics as an executable reference mode without removing the performance-oriented transactional default.
- [x] Add a mutation detector to the supported state API during strict user-code phases.
- [x] Add tests proving retained strict models remain observably unchanged; changed path spines are copied while untouched branches are intentionally shared.
- [x] Freeze strict snapshots so supported state mutation remains rejected outside the immediate update/view dynamic phase.
- [x] Document that Common Lisp data is not magically immutable; shared container values require persistent-value discipline and raw destructive operations remain explicit escape hatches.
- [x] Implement a structurally-shared persistent commit engine and switch `DEFAPPLICATION :STRICT-ELM` to it while retaining eager `APPLY-PATCHES-PERSISTENT` as a correctness oracle.
- [x] Add a deterministic 256-transition three-engine differential trace (transactional vs eager persistent vs shared persistent) plus destructive-`:UPDATE` isolation tests.
- [x] Add a 128-transition generated-application trace that retains old strict snapshots, verifies they never drift, and verifies untouched subtree sharing.
- [x] Add `scripts/benchmarks/state_semantics_benchmark.lisp` and benchmark shared strict against eager strict and transactional commit. Representative 2,000-branch/120-update result: shared uses ~8.7% of eager allocation and ~14% of eager wall time; versus transactional it is ~2.5x allocation and approximately equal coarse wall time on this run.
- [x] Select full `DEFAPPLICATION` as the normative next-stable-major constructor. Keep `DEFTEA-APP` as the supported minimal direct-transition teaching/small-app adapter; both lower through `MAKE-RUNTIME-APP-SPEC` and share the canonical transition vocabulary.
- [x] Narrow user-facing `APPLICATION-STATE-DATA`: `CL-STATE.API`, `ELMTUI.STATE.API`, and `ELMTUI.STATE` expose the same deprecated owned-snapshot read and reject `(SETF ...)`; live representation access requires explicitly naming `CL-STATE.CORE:APPLICATION-STATE-DATA`.

## 4. Code-quality sweep by subsystem

### 4.1 Main ElmTUI

- [x] Audit core loop, channels, driver, application macros, conditions/errors, state update layer, package facade, view geometry, and representative widgets.
- [x] Remove `SB-PCL:MAKE-INSTANCE` from the public geometry package.
- [ ] Reduce broad top-level package re-exports to an intentional convenience API.
- [ ] Mark internal packages explicitly and avoid accidental public constructors/readers.
- [ ] Move lifecycle-owned driver globals toward one runtime context object where that simplifies reasoning/testing.
- [ ] Remove large commented-out historical implementations after tests preserve current behavior.
- [ ] Replace stale comments that explain old code with comments explaining present invariants.

### 4.2 `cl-events`

- [x] Centralize polling here.
- [x] Add central polling tests.
- [ ] Complete condition taxonomy for closed channel, timeout/cancel, task failure, dispatcher failure.
- [ ] Document consume/peek/block/poll semantics for every public receive/wait operation.
- [ ] Close public docstring debt in types/async/channel first.

### 4.3 `cl-state`

- [x] Verify transactional mutation semantics and specify their observational refinement relationship to strict replacement semantics.
- [x] Add eager persistent-copy oracle, structurally-shared strict commit, frozen snapshots, and strict mutation-policy primitives without removing transactional APIs.
- [ ] Rewrite all remaining public state docs around explicit mutation/rollback/observer behavior and strict-mode applicability.
- [ ] Replace broad observer-notification suppression with inspectable policy.
- [ ] Document transaction nesting, rollback, and observer ordering guarantees.
- [ ] Review whether plist/hash-table backends expose identical semantic guarantees.
- [ ] Add mutation examples to all exported setters/patch helpers.

### 4.4 `cl-inputs`

- [x] Fix `get-input-source`: it now creates the default source it promised to create.
- [x] Run `cl-inputs` suite: 207 pass, 0 fail, 1 environment skip.
- [ ] Remove large commented legacy input-loop implementations.
- [ ] Replace raw-mode blanket suppression with narrow/documented behavior.
- [ ] Standardize timeout/blocking terminology across device/loop APIs.
- [ ] Review package-file load order during package architecture cleanup.

### 4.5 `cl-styles`

- [x] Review ASDF/package shape and public API debt.
- [ ] Replace broad `:serial t` with explicit dependencies incrementally.
- [ ] Decide which generated selector/token/property accessors are supported API before documenting them all.
- [ ] Document stylesheet/rule mutation semantics and cache invalidation.

### 4.6 Widgets

- [x] Review representative counter/button/label/textinput/listbox APIs and enhanced-widget packaging.
- [ ] Standardize every widget document around: model, init, update, view, messages, commands, focus, mutation, conditions.
- [ ] Add a widget authoring checklist and template.
- [ ] Audit enhanced experimental widgets for promotion/deprecation criteria.

## 5. Docstrings and API documentation

### 5.1 Convention

- [x] Define one docstring convention in `docs/dev-guides/coding-standards.md`.
- [x] Require `Arguments:`, `Returns:`, `Mutation:`, `Conditions:`, and `Example:` for public callables.
- [x] Require `Restarts:` when applicable.
- [x] Require mutation/condition sections even when the answer is `None`.
- [x] Prefer plain Markdown-compatible prose; deprecate legacy ad-hoc `~symbol~` markup.
- [x] Upgrade new/modified polling/error/input APIs to this richer style.

### 5.2 Audit and ratchet

- [x] Build a runtime audit over ElmTUI + `cl-events` + `cl-state` + `cl-inputs` + `cl-styles`.
- [x] De-duplicate facade re-exports by symbol identity.
- [x] Current audit after strict-state API additions: 1,552 unique public bindings; still 782 missing docs (no debt regression).
- [x] Add `scripts/check-docstrings.sh` regression gate.
- [x] Add strict zero-debt mode with `ELMTUI_DOCSTRING_STRICT=1`.
- [ ] First debt tranche: `CL-EVENTS.TYPES`, `ELMTUI.PLATFORM.API`, `ELMTUI.VIEW.BASE-ELEMENTS`, `ELMTUI.CONTRACTS`.
- [ ] Second tranche: keymaps, async, terminal ANSI, event types, condition/error APIs.
- [ ] Third tranche: state/style/widget generated API after export pruning.
- [ ] Final tranche: all remaining supported exports; enable strict mode in CI.

### 5.3 Rendering

- [x] Add documentation-only `elmtui-docs.asd`; it does not enter runtime dependencies.
- [x] Implement `elmtui.docs:public-api-bindings` using live Common Lisp `DOCUMENTATION` metadata.
- [x] Implement `elmtui.docs:docstring-audit`.
- [x] Implement `elmtui.docs:build-api-docs`.
- [x] Render Markdown to `docs/api/generated/api.md`.
- [x] Render HTML to `docs/api/generated/api.html`.
- [x] Add `scripts/build-api-docs.sh`.
- [x] Evaluate MGL-PAX integration.
- [x] Do not make broken PAX dependency mandatory: Quicklisp snapshot fails under current SBCL dependency stack; current Git introduces an unresolved CLPM `autoload` requirement.
- [ ] Re-evaluate PAX when CLPM sources can resolve its current dependency graph; retain the same docstring contract so migration is mechanical.
- [ ] Add generated-doc freshness check to CI.

## 6. Packaging / ASDF architecture

- [x] Review all five primary systems and enhanced widgets ASD.
- [x] Add a docs-only ASDF system.
- [x] Keep docs tooling out of runtime dependencies.
- [x] Remove implementation-internal `SB-PCL` symbol from public geometry API.
- [ ] Introduce `elmtui/program` and move `program-op`, binary pathname, and dev entrypoint there.
- [ ] Preserve a compatibility path for existing `asdf:make :elmtui` users during the transition.
- [ ] Introduce explicit secondary systems only where they reduce runtime dependencies or clarify ownership; avoid system proliferation for its own sake.
- [ ] Replace broad `:serial t` with explicit dependencies at subsystem boundaries.
- [ ] Normalize package naming: stable `.api` expert interfaces + one small convenience facade + internal implementation packages.
- [ ] Establish a compatibility/deprecation policy for exported symbols and package renames.
- [ ] Fix `ANSII` naming through alias/deprecation rather than an abrupt public-package rename.

## 7. Long-form documentation

- [x] Write the foundations/Elm/TEA essay.
- [x] Include actual source excerpts for model replacement, isolated update drafts, transactional commit, and structurally-shared strict persistent commit.
- [x] Explain semantic immutability vs representation mutation, give the refinement proof obligations, document structural sharing/frozen snapshots, and distinguish the supported mutation contract from raw destructive Lisp escape hatches.
- [x] Explain the runtime message/update/command/render loop.
- [x] Write core-principles/program-parts/widget guide.
- [x] Add practical widget inventory and usage patterns.
- [x] Write hands-on counter walkthrough.
- [x] Add async HTTP/Wikipedia-style command pattern without forcing network access into deterministic tests.
- [x] Link the long-form series and documentation commands from `README.org`.
- [ ] Add cross-links from generated API headings to long-form conceptual docs.

## 8. E2E and contract verification

- [x] Preserve existing deterministic input -> route -> update -> effects -> render runtime e2e.
- [x] Preserve faketerm quiescence/lifecycle e2e.
- [x] Add condition/restart e2e proving original condition identity + `USE-VALUE` recovery.
- [x] Add the comprehensive 80-check condition/restart/debugger suite covering construction, context, subtype preservation, scope, retry/abort/substitution variants, async/render/message specializations, debugger identity/context/restarts, and restart lifetime.
- [x] Keep live tmux integration opt-in and explicitly skipped when environment support is absent.
- [x] Extend runtime e2e to capture the old TEA model, prove UPDATE left it unchanged, and prove the driver installed a distinct replacement model.
- [x] Add async command e2e with deterministic fake success/failure work, completion/error messages, and no network dependency.
- [x] Add async fallback recovery e2e through standard `USE-VALUE` while the original `ASYNC-TASK-ERROR` is active.
- [ ] Add an explicit RETRY e2e around an idempotent async operation to verify retry-count/effect semantics.
- [ ] Add generated API freshness e2e/check.

## 9. Definition of done for the broader convergence effort

The broader task is complete when all of these are true:

- [ ] no local repeated polling/backoff loops exist outside the central polling primitive or genuine blocking device I/O;
- [ ] one documented application semantics is recommended and alternatives are explicitly named;
- [ ] every supported exported binding has documentation metadata;
- [ ] every public callable documents mutation and conditions, plus restarts when relevant;
- [ ] condition families are inspectable and consistently rooted;
- [ ] no normal runtime path blanket-suppresses arbitrary errors;
- [ ] the library ASDF system is not also the development executable system;
- [ ] package facades export intentionally curated stable APIs;
- [ ] generated API docs are reproducible and checked for freshness;
- [ ] deterministic e2e covers pure update, async success/failure/recovery, rendering, and lifecycle;
- [ ] full suite and warning-clean build pass with no unexpected skips.
