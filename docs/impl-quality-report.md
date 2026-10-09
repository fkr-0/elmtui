# ElmTUI implementation-quality report

Date: 2026-08-12

## Executive verdict

ElmTUI has a much stronger verification base than its source presentation initially suggests: the deterministic full suite was green before this pass and remains green after the runtime/error-handling changes. The main architectural problem is not lack of capability; it is that several generations of API and runtime design coexist in the same primary system. The project currently contains a clean TEA-style model-replacement path, a transactional mutable `cl-state` path, legacy component/update machinery, multiple package facades, and large areas of partially documented exported API.

The most important correctness problems found in this pass were concentrated around polling and the condition/restart layer. Those were safe to correct immediately and are now covered by tests. The largest remaining quality debt is public documentation and API surface control, followed by making the two state semantics explicit rather than calling the entire framework strictly immutable Elm.

## Verification baseline and result

- Baseline full suite: 2,179 passed checks, 0 failures, 6 opt-in live-tmux skips.
- After structurally-shared strict state and retained-snapshot coverage: 3,075 passed checks, 0 failures, 6 opt-in live-tmux skips (3,081 total checks).
- `cl-events`: 128/128 checks pass after central polling extraction, including multiple-value success, zero-timeout single-probe, and pre-probe cancellation contracts.
- `cl-inputs`: 207 passed, 0 failed, 1 expected no-controlling-TTY skip after fixing default input-source creation.
- API documentation generator: loads `elmtui-docs` and renders both Markdown and HTML.
- Runtime TEA e2e now asserts the model object passed into UPDATE remains unchanged while the driver installs a distinct returned replacement model.
- Structurally-shared state has 4,377 focused CL-state checks including a deterministic 256-transition transactional/eager/shared differential trace and destructive-`:UPDATE` isolation. Generated application structural-sharing coverage adds 768 checks over 128 transitions while retaining old strict snapshots.
- Async e2e executes real worker tasks with a fake transport: success emits its completion message; failure emits its error message and is recoverable through standard `USE-VALUE` while the original `ASYNC-TASK-ERROR` remains active.
- Warning-clean verification passes after the complete change set.
- Docstring audit: 1,552 unique exported bindings; 782 currently lack Common Lisp `DOCUMENTATION` metadata, for 49.6% current coverage. New strict-state API symbols were documented so the missing-doc debt did not increase. Re-export duplicates are removed from this count.

## Corrections implemented in this pass

### P0 — polling ownership and semantics

**Before:** ElmTUI had several hand-written deadline/sleep loops. `src/core/event-channels.lisp` implemented its own `get-internal-real-time` deadline loop and `sleep 0.001`; consumer shutdown in `src/core/loop.lisp` had another timeout loop. `wait-for-event` also claimed priority semantics but relied on caller ordering.

**Now:** `cl-events.loop:poll-until` is the single cooperative repeated-probe primitive. It owns deadline construction, timeout-zero behavior, stop predicates, backoff, injectable clock/sleep hooks, and multiple-value preservation. `try-receive-event`, `wait-for-event`, consumer-thread shutdown, platform-driver input-thread liveness waiting, and the main runtime shutdown-flag wait delegate to it. Blocking device waits remain backend I/O primitives and are intentionally not converted into spin polling; recurring-task sleeps, debounce timers, and development dashboard refresh intervals remain timer/scheduler behavior rather than readiness polling.

`wait-for-event` now stably orders channels by declared priority before probing, so implementation behavior matches its public contract.

### P0 — debugger-hostile error reconstruction

**Before:** `elmtui.core.errors:with-error-context` caught `elmtui-error`, constructed a new condition of the same type, copied only base slots, and re-signaled it. For subclasses with additional required slots this can lose information or even make reconstruction invalid. It also breaks condition object identity and weakens debugger/restart inspection.

**Now:** the macro uses `handler-bind`, annotates diagnostic slots on the original condition, and allows the same object to continue through the condition system. Subclass slots, condition identity, debugger state, and active restarts are preserved.

### P0 — condition constructor contract mismatch

**Before:** `make-elmtui-error` always passed `:message`, while the base `elmtui-error` condition had no corresponding initarg. It also stringified structured context even though contextual data is much more useful as inspectable Lisp data.

**Now:** `elmtui-error` has an explicit message slot/reader, and `make-elmtui-error` preserves structured context rather than coercing it to text.

### P0 — restart scope and quoted restart-list bug

**Before:** `with-recovery` established a handler, then re-signaled the condition from inside that handler and put `restart-case` around the re-signal rather than around the failing operation. In addition, call sites using a normal quoted restart list such as `'(:ignore-task :retry)` were inspected incorrectly at macro-expansion time, so requested restarts could silently fail to be generated. `cmd-async` requested `:ignore-task`, which the macro did not actually implement.

**Now:** restarts surround the operation. The original condition remains active and inspectable. Literal and quoted restart lists are normalized at macro-expansion time. `:retry`, `:skip`, `:ignore-task`, `:use-value`, and `:abort` are supported. Message-, render-, and async-specific restart macros use the same correct scope pattern.

A dedicated condition-system suite now provides 80 focused checks covering condition construction and subtype slots, structured context, exact condition identity, nested annotation, restart presence/absence, multiple-value preservation, `SKIP`, `IGNORE-TASK`, `USE-VALUE`, `ABORT`, `RETRY` execution counts, message replacement, render fallback, async replacement/provided results, unrelated-condition propagation, restart lifetime, pre-unwind handler semantics, and a real non-interactive SBCL debugger-hook path. The debugger tests prove that the condition reaching the debugger is the exact object seen by the handler, that structured enriched context is already visible there, and that recovery restarts remain active during debugger inspection.

### P1 — package pollution fixed

`elmtui.view.geo` explicitly imported and exported `SB-PCL:MAKE-INSTANCE`. The symbol is a Common Lisp implementation facility and should never be part of ElmTUI's geometry API. The import/export was removed; ordinary `CL:MAKE-INSTANCE` remains available internally through `:use :cl`.

### P1 — concrete `cl-inputs` contract bug fixed

`cl-inputs.loop:get-input-source` documented lazy creation but returned NIL whenever no default source existed. It now delegates to `make-input-source` on first use and has a contract-style docstring describing raw-mode side effects and condition behavior.

## Remaining findings

### P1 — Elm semantics now have an explicit reference/optimized split

The earlier report wording was too coarse: mutation in the representation is not itself an Elm violation. The correct criterion is observable transition semantics.

ElmTUI now treats the `DEFAPPLICATION` state transition as one abstract TEA contract with two commit engines:

```text
:transactional   optimized in-place representation commit
:strict-elm      fresh-state reference semantics
```

The strict engine now uses persistent path copying: containers on changed paths are copied, caller-owned changed values are copied at the patch boundary, and untouched branches are structurally shared. Returned strict `APPLICATION-STATE` objects are frozen, so supported mutation is rejected even outside the immediate update/view dynamic phase. The update draft itself remains independently deep-copied before decision logic; this preserves the fix for the earlier plist-backend aliasing hole.

The earlier full-copy `APPLY-PATCHES-PERSISTENT` implementation is retained as a deliberately simple oracle. Verification now compares three implementations: transactional in-place commit, eager persistent commit, and structurally shared persistent commit. A deterministic 256-transition CL-state trace compares all three; a separate 128-transition generated-application trace retains every old strict snapshot and proves it never drifts while untouched subtrees remain shared. The defensible architectural claim is therefore:

> Elm/TEA semantics are specified at the observable transition boundary. Eager persistent commit is the simple reference oracle; structurally shared `:STRICT-ELM` is the production replacement-snapshot implementation; transactional commit is the lowest-cost mutable refinement. All three must produce the same supported logical state trace.

This is not a claim that arbitrary Common Lisp code cannot distinguish the implementations. `STATE-REF` exposes ordinary Lisp values and custom mutable leaf objects remain caller-owned. The user-facing `CL-STATE.API:APPLICATION-STATE-DATA` / `ELMTUI.STATE:APPLICATION-STATE-DATA` compatibility read now returns an owned snapshot and rejects `(SETF ...)`; only the explicitly low-level `CL-STATE.CORE:APPLICATION-STATE-DATA` representation accessor remains an internal escape hatch. Destructive operations on borrowed values or explicitly internal raw storage bypass the strict state API and are outside the persistent-value contract.

### P1 — public docstring debt is still large

The runtime audit de-duplicates re-exported symbols by symbol identity and currently reports:

| home package | missing documentation |
|---|---:|
| `CL-EVENTS.TYPES` | 52 |
| `ELMTUI.PLATFORM.API` | 42 |
| `ELMTUI.VIEW.BASE-ELEMENTS` | 36 |
| `ELMTUI.CONTRACTS` | 33 |
| `ELMTUI.KEYMAPS` | 28 |
| `CL-EVENTS.ASYNC` | 28 |
| `CL-INPUTS.TERMINAL.ANSII` | 27 |
| `ELMTUI.CORE.EVENT-TYPES` | 26 |
| `ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING` | 24 |
| `ELMTUI.CORE.ERRORS` | 21 |
| `ELMTUI.CORE.CONDITIONS` | 20 |
| `ELMTUI.CORE.EVENT-CHANNELS` | 20 |
| `ELMTUI.CORE.TOPICS` | 20 |
| `ELMTUI.VIEW.GEO` | 18 |
| `CL-EVENTS.CHANNEL` | 18 |
| `ELMTUI.PLATFORM.BACKEND.TERMINAL` | 16 |
| `ELMTUI.CORE.TOPIC-REGISTRY` | 16 |
| `ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER` | 15 |
| `CL-STYLES.SELECTOR` | 15 |
| `ELMTUI.APP.API` | 15 |

The remaining 372 missing bindings are distributed across smaller packages. Generated accessors account for part of the total, but generated public accessors are still API and need documented slot semantics or a deliberate decision not to export them.

**Enforcement added:** `scripts/check-docstrings.sh` fails if missing-documentation debt rises above the current baseline. `ELMTUI_DOCSTRING_STRICT=1` requires zero missing bindings. The audit is exposed through `bridge.yml` and runs from `scripts/release-check.sh`, converting the debt from an invisible aspiration into a release-gated ratchet. The strict zero-debt target intentionally remains open: mass-generating low-value accessor prose would make the metric green without making the API clearer.

### P1 — condition hierarchy is richer than the public abstraction

ElmTUI has many custom conditions, but they do not form one consistently navigable hierarchy. Some inherit from `elmtui-error`; others inherit directly from `error`, and several expose generic reader names such as `message`, `reason`, `event`, or `state`. That increases package conflicts and makes generic framework-level handlers less useful than they could be.

Recommended migration:

1. Introduce/standardize condition families such as `elmtui-condition`, `elmtui-warning`, `elmtui-error`, `runtime-error`, `render-error`, `input-error`, `state-error`, and `async-error`.
2. Prefer prefixed readers (`runtime-error-event`, `async-error-task`, etc.) for exported API.
3. Keep rich context as Lisp data: operation, component id/path, message/event, backend, state path, offending value, expected type, and underlying condition.
4. Associate restarts with operations, not condition constructors.
5. Use `handler-bind` for observation/annotation and `handler-case` only where non-local recovery by replacement is actually intended.

### Resolved — one normative application constructor with a compatible minimal adapter

`defapplication` is the normative full application constructor selected for the next stable major version. It owns the production surface: `cl-state`, component/root initialization, patch application, CLI/binary integration, keymaps, generated wrappers and runtime entry points, with `:transactional` and `:strict-elm` commit engines sharing one update/patch contract.

`deftea-app` remains supported as the small direct model-replacement constructor for teaching and deliberately minimal applications. It is not a second production architecture: canonical `:transition` plus `:init`/`:view`/`:subscriptions` lower through `make-runtime-app-spec`, and legacy `:update` remains only a compatibility alias. The two constructors therefore retain intentionally different authoring surfaces while sharing one runtime transition vocabulary.

### P1 — primary ASDF system is also an executable

`elmtui.asd` is simultaneously the library graph and a `program-op` target:

```lisp
:build-operation "program-op"
:build-pathname "elmtui"
:entry-point "elmtui:dev-main"
```

A library system should not implicitly mean “build the development binary.” Recommended target architecture:

```text
elmtui                 library runtime
elmtui/widgets         optional/extended widget surface where useful
elmtui/backends/...    optional backend systems as they become independently loadable
elmtui/program         executable/dev entry point
elmtui/docs            or elmtui-docs, documentation tooling only
elmtui/tests           verification only
elmtui/examples        examples only
```

A compatibility window can retain `asdf:make :elmtui` while introducing `elmtui/program`, then remove the executable metadata at the next suitable compatibility boundary.

### P1 — broad `:serial t` masks dependency architecture

The primary system and `cl-styles` rely on broad serial ordering in several modules. Serial loading is valid, but in a library this large it can hide undeclared dependencies and makes safe extraction/reuse harder. `cl-inputs` demonstrates the better direction by declaring many file-level `:depends-on` relations.

Recommendation: progressively replace broad serial modules with explicit component dependencies, starting at subsystem boundaries rather than rewriting the entire ASD in one change.

### P1 — top-level package facade is not yet a designed minimal API

`src/elmtui.lisp` mixes hand exports with broad package re-exports, while `src/api.lisp`, `elmtui.app.api`, `elmtui.ui.api`, `elmtui.state.api`, and sublibrary `*.api` packages also exist. This makes it hard to answer “what is stable public ElmTUI?”

Recommendation: define one intentionally small convenience facade and treat subsystem `.api` packages as the stable expert interface. Avoid re-exporting backend internals, generated accessors, or implementation-specific symbols merely because another package exports them.

### P1 — `ignore-errors` weakens Common Lisp's strongest diagnostic mechanism

The codebase contains multiple `ignore-errors` uses around device/raw-mode handling, observer notification, terminal cleanup, rendering cleanup, and logging. Some are justified during best-effort teardown; others lose actionable condition data during normal operation.

Policy recommendation:

- teardown: `handler-bind` + logging + explicit continue restart or deliberately documented suppression;
- optional feature probe: handle the narrow expected condition type;
- normal runtime path: never blanket `ignore-errors` unless the condition is recorded with operation/context first.

### P2 — large commented-out implementations remain in production files

`cl-inputs/src/input/loop.lisp`, `src/app/application.lisp`, and parts of the driver contain substantial old implementations preserved as comments. They make code review harder and blur which semantics are current. Git already preserves history; keep only comments that explain *why* the current code is shaped as it is.

### P2 — generated/accessor-heavy API needs export discipline

A large fraction of documentation debt comes from constructors/readers generated by `defstruct`, condition slots, and broad facade exports. The right fix is not 700 generic one-line docstrings. First decide which accessors are stable API, then document those exhaustively and unexport the rest.

### P2 — naming drift

The project contains both `ANSI` and `ANSII` spellings in package/file names. Renaming a public package is compatibility-sensitive, so this should be handled with a package nickname/deprecation window rather than a blind rename.

## Sublibrary review

### `cl-events`

Strengths:

- independent ASDF system and test system;
- coherent channels/bus/dispatcher/async/loop layering;
- now owns the canonical polling primitive;
- timeout helpers and runtime-shell helpers are reusable below ElmTUI.

Remaining work:

- 52 missing docs in generated/event type API plus 28 in async and 18 in channel;
- establish one condition family for channel closed, timeout, task failure/cancellation, and dispatcher errors;
- document whether each receive function consumes, peeks, blocks, or polls;
- keep `poll-until` as the only repeated-probe/backoff loop and prevent local sleep loops in reviews.

### `cl-state`

Strengths:

- clean standalone responsibility: state container, transaction, patch, undo, observer, schema, validation;
- transaction/rollback semantics are valuable and independent of ElmTUI.

Remaining work:

- documentation must stop implying immutable Elm semantics where mutation occurs;
- observer notification uses broad suppression in places;
- public state mutation functions need explicit mutation, rollback, observer, and condition contracts;
- 35 missing docs were observed through the `CL-STATE.API` facade before re-export de-duplication; 14 originate in `CL-STATE.CORE`, with additional debt in patch/tx/schema/validation/undo.

### `cl-inputs`

Strengths:

- backend/device abstraction is separated from token decoding;
- faketerm gives deterministic tests;
- many ASDF component dependencies are explicit;
- 207/207 executable checks pass when the one no-TTY test is skipped.

Fixed here:

- `get-input-source` now actually creates the documented default source.

Remaining work:

- remove large commented legacy loop implementations;
- replace blanket raw-mode `ignore-errors` with narrow conditions + explicit best-effort policy;
- document blocking/nonblocking/timeout semantics consistently across device and loop APIs;
- the top-level package file loading last is unconventional and should be reviewed when package ownership is normalized.

### `cl-styles`

Strengths:

- small independent styling engine with no ElmTUI runtime dependency;
- logical protocols/tokens/selectors/rules/sheets/engine/properties/adapters/API split.

Remaining work:

- broad system-level `:serial t` should become explicit dependencies;
- public selector/token/property objects are documentation-heavy APIs and currently contribute substantial generated-accessor debt;
- mutation semantics of stylesheet/rule changes should be explicit in docs.

### main `elmtui`

Strengths:

- clear subsystem directories;
- deterministic faketerm/runtime e2e coverage;
- TEA driver path already supports clean model replacement;
- current tests cover rendering, layout, focus/keymaps, root viewport, terminal lifecycle, examples, async, and state behavior.

Remaining work:

- choose/brand the normative application architecture;
- shrink the public facade;
- split executable/dev tooling from the library system;
- consolidate condition hierarchy;
- reduce global dynamic runtime state over time by moving lifecycle-owned values into a runtime context object;
- delete dead commented implementations after current behavior is locked by tests.

### widgets and enhanced widgets

The stable/experimental secondary split in `elmtui-widgets-enhanced.asd` is directionally good. Widget APIs should converge on the same contract vocabulary: model/init/update/view, emitted messages/commands, state ownership, focus behavior, mutating behavior, and signaled conditions. The long-form widget guide now uses that vocabulary.

## Documentation architecture deployed

`elmtui-docs.asd` is a documentation-only ASDF system that depends on ElmTUI but is not a runtime dependency. `elmtui.docs:public-api-bindings` introspects exported bindings and Common Lisp `DOCUMENTATION` metadata; `build-api-docs` writes Markdown and HTML references. This intentionally uses standard Common Lisp documentation metadata so it works in the current CLPM/SBCL environment.

MGL-PAX was evaluated because its section/docstring model is a strong fit. The Quicklisp snapshot available in this bundle failed to load on current SBCL through an old `pythonic-string-reader` dependency, while current PAX Git introduced a CLPM-unresolved `autoload` system. Therefore PAX is not made a required docs dependency in this pass. The generated-docs abstraction can be replaced by PAX later without changing the docstring convention.

## Architectural conclusion

The project does not need a rewrite. It needs convergence:

1. keep `cl-events`, `cl-state`, `cl-inputs`, and `cl-styles` as real independent libraries;
2. make `cl-events` own runtime waiting/polling primitives;
3. designate TEA/model replacement as the recommended pure application path;
4. treat transactional `cl-state` as an explicit alternative/compatibility state mode;
5. make conditions/restarts part of the public framework contract rather than incidental error handling;
6. shrink package exports before attempting to document every generated accessor;
7. ratchet documentation debt to zero;
8. split library/program/docs/tests/examples systems cleanly;
9. preserve the strong deterministic test suite while removing dead historical code.
