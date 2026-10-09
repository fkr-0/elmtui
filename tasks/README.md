# ElmTUI task audit and active backlog

Audit date: 2026-08-20

This file is the canonical interpretation of the legacy task sheets in this directory. The numbered task files were written against older implementations and contain contradictory completion claims, obsolete paths, and unchecked work aimed at source files that are no longer loaded by any maintained ASDF system. Their unchecked boxes are historical context, not directly dispatchable work.

## Status vocabulary

- **DONE** — verified in the current tree or completed by this audit.
- **KEEP** — still valid, but rewritten here against current ownership/APIs.
- **DROP** — obsolete, duplicated, contradicted by the current architecture, or premature optimization without evidence.
- **BLOCKED** — valid objective whose acceptance criteria cannot currently be met because of another known issue.

## Audit summary

| Area | Disposition |
| --- | --- |
| `01-core-tea-state.md` | Historical. Its claimed implementations do not reliably match current paths/APIs. Keep current TEA/state work in `docs/TODO-architecture-quality-e2e.md`; do not revive the old transaction viewer. |
| `02-rendering-ui.md` | Mostly superseded by the maintained `src/platform/tree-renderer.lisp`. Keep only explicit overflow/child clipping, z-order semantics, image policy, and measured renderer performance work. |
| `03-event-system-focus-async.md` | Historical. Current `cl-events` ownership and runtime-convergence work supersede its old consolidation narrative. |
| `04-performance-testing.md` | Consolidate the first five benchmark/measurement items into one benchmark harness. Drop optimization/batching/cache tasks until measurements justify them. |
| `05-developer-experience-docs.md` | Dev-module expansion is DONE in this audit. Consolidate the debugging items into one current causality/tracing task; discard duplicate documentation already covered by current guides/reviews. |
| `post-release-dispatch.json` | Most concrete findings still reproduce. Keep POST-001..009 with corrections below; POST-INT is BLOCKED until dependencies are complete. |

## Canonical active backlog

### DEV-001 — Maintained REPL/runtime introspection — DONE

Implemented in this audit:

- `src/dev/dev.lisp` now provides side-effect-free `buffer->string` output, `runtime-snapshot`, `format-runtime-snapshot`, `format-element-tree`, and a useful `dev-main`.
- `tests/dev-tests.lisp` is now an active FiveAM suite rather than commented-out placeholders.
- Focused verification passes 12/12 checks.

This intentionally does **not** load the orphan `event-monitor`, `event-dashboard`, transaction viewer, or old view-debug stack.

### DEV-002 — Current event/runtime benchmark harness — DONE

Implemented in this audit without reviving the orphan `src/dev/event-benchmark.lisp` stack:

- `elmtui-dev.asd` owns optional benchmark tooling outside the production runtime graph.
- `src/dev/benchmark.lisp` measures event-pipeline throughput, input-normalization latency, and SBCL allocation pressure when available.
- Baseline read/write and comparison helpers provide machine-readable run data without imposing timing-sensitive CI thresholds.
- `stress-event-pipeline` provides bounded repeated scenarios without changing runtime semantics.
- `elmtui-dev-tests.asd` and `src/dev/benchmark-tests.lisp` cover result shape, baseline round-trip, comparison ratios, and bounded stress behavior; focused verification passes 11/11 checks.
- `bridge.yml` now exposes `benchmark` and `benchmark-test` commands.

The maintained implementation has no dependency on the broken legacy `event-monitor`/`event-dashboard` packages. This task replaces the first five unchecked items in `04-performance-testing.md` and the event-latency metric request in `05-developer-experience-docs.md`.

### EXAMPLE-001 — Maintained `nmcli` Wi-Fi menu and example repair pass — DONE

Implemented and validated in this audit:

- `examples/wifi-menu.lisp` is part of `elmtui-examples.asd` and refreshes NetworkManager access-point state asynchronously through `nmcli`.
- The menu supports explicit rescan, current-network indication, selection, connect, password entry, and disconnect without performing network mutations at load/test time.
- Wi-Fi passwords are masked in the view and supplied to `nmcli --ask` through standard input rather than process arguments.
- Broken maintained examples were repaired where smoke-only loading had hidden runtime defects: `focus-simple`, `dirli`, `fzf-finder-real`, `input-selector`, `key-tester`, `pong-below-cursor`, `scroll-panel-demo`, `cursor-inspector`, and optional `fzy-picker`.
- The maintained examples system compiles as a whole and focused example smoke coverage passes 243/243 checks.
- `bridge.yml` now exposes `examples-smoke` for repeatable verification.

### DEV-003 — Event → update/state → render causality trace — KEEP, after DEV-002

Provide an opt-in diagnostic trace that correlates a message/event with the update decision, state transition/patch summary, effects, and resulting render. Prefer structured data plus REPL formatting over an always-running dashboard.

This consolidates these old tasks:

- general debugging visualization;
- event visualization + transaction history;
- event monitoring + state-change debugging;
- holistic event-to-state causality;
- widget-specific event debugging.

Do not revive `src/dev/event-monitor.lisp`, `src/dev/event-dashboard.lisp`, `src/dev/transaction-viewer.lisp`, or `src/dev/view-debug.lisp` as written: they target removed packages/APIs or placeholder metrics.

### DEV-004 — Unify optional profiling utilities — KEEP

Evaluate `src/dev/profiler.lisp` and `src/platform/profiler.lisp` as raw material for one optional, tested profiler. Both currently compile with style warnings and neither is in a maintained ASDF system.

Acceptance:

- one clear package/owner;
- no warning-producing unused instrumentation parameters;
- explicit opt-in overhead;
- focused tests and a documented REPL workflow;
- renderer/runtime timing integrates with DEV-002 rather than duplicating metric collection.

### RENDER-001 — Explicit overflow/child clipping — RESOLVED

The maintained terminal tree renderer preserves historical visible descendant overflow by default. A node that explicitly sets `:overflow :hidden` clips all descendant writes to its absolute content rectangle (after border and padding), and nested hidden-overflow ancestors intersect their clip rectangles. Each descendant still respects its own layout/content bounds and terminal-buffer bounds. Focused rendering regressions cover the default-visible compatibility path, parent-content versus child bounds, and nested ancestor intersection.

### RENDER-002 — Z-order semantics — RESOLVED

The maintained lowered terminal renderer uses source-order painter semantics: siblings render in `element-children` order and a later sibling paints over an earlier sibling where their cells overlap. `:z-index` is not interpreted by this backend contract. This intentionally preserves the maintained architecture instead of copying the orphan legacy canvas renderer's z-index sort. Focused overlap coverage uses contradictory z-index values and proves that the later lowered sibling still wins.

### RENDER-003 — Image element policy — RESOLVED

The maintained terminal renderer uses explicit textual fallback semantics for `:image`: a non-empty `:alt` string is rendered through the normal clipped text-content path, while an absent or empty ALT renders the visible placeholder `[image]`. The terminal backend does not decode or emit image protocols at this layer, and image content therefore cannot silently disappear. Focused coverage proves both ALT rendering and the placeholder fallback.

### RENDER-004 — Renderer performance benchmark — KEEP, measurement first

Add representative tree-renderer benchmarks before any caching/batching optimization. Reuse DEV-002 reporting where practical.

### DOC-001 — Current API/troubleshooting gap audit — KEEP, narrowed

Do **not** create another broad event-system guide from the 2025 task text. Current material already covers substantial event/runtime/async architecture in `docs/USER_GUIDE.md`, `docs/architecture/core-platform-architecture-review-and-migration-plan.md`, `docs/impl-quality-report.md`, `docs/subsys-int.md`, and `docs/TODO-architecture-quality-e2e.md`.

Instead, compare exported current APIs to those documents and close concrete gaps only: missing public API semantics, troubleshooting steps, warning/condition behavior, and stale examples.

### DOC-002 — Widget event contract audit — KEEP, narrowed

Audit maintained widgets for one canonical event/message pattern and document only verified differences. Do not build per-widget renderer/debug dispatch unless the audit finds an actual runtime need.

## Disposition of every unchecked legacy rendering task

| Legacy item | Disposition | Current reason |
| --- | --- | --- |
| Phase 1 basic element rendering | DROP as parent task | Maintained tree renderer already renders lowered elements. |
| Style resolution integration | DONE/current | `tree-renderer` consumes resolved element styles and `style-to-terminal-style`. |
| Image elements | KEEP → RENDER-003 | Public image element exists; terminal behavior is undefined. |
| Phase 2 advanced styling | DROP as parent task | Split into only the remaining concrete gaps. |
| Text styling attributes | DONE/current | Terminal style conversion already carries supported text attributes. |
| Content overflow & clipping | KEEP → RENDER-001 | Cell/text clipping exists; descendant overflow semantics remain. |
| Z-index & draw order | KEEP → RENDER-002 | Current tree renderer preserves child order. |
| Extended border styles | DROP as stated | Solid/ascii/double are implemented. Add other styles only if a public style contract requires them. |
| Phase 3 widget rendering | DROP | Widgets lower to renderer-neutral/base elements; renderer-specific widget branches would re-couple layers. |
| Button widget renderer | DROP | Same reason. |
| Input field widget renderer | DROP | Same reason. |
| Listbox widget renderer | DROP | Same reason. |
| Progress-bar widget renderer | DROP | Same reason. |
| Phase 4 refinements/extensibility | DROP as parent task | Keep only measured/current needs. |
| Custom element dispatch | DROP/defer | No current extension protocol requires it; define one only with a concrete consumer. |
| Logging & debugging | DONE/KEEP elsewhere | Basic tree/runtime inspection is DEV-001; deeper causality is DEV-003. |
| Performance review | KEEP → RENDER-004 | Benchmark before optimization. |
| Drawing primitives | DROP | Targets the orphan canvas renderer, not the maintained renderer. |
| Style property definitions | DROP as blanket task | Validate concrete missing properties when a supported feature needs them. |
| Coordinate systems | DONE/current | Tree renderer translates child layout relative to parent origin. |
| Audit virtual-buffer/canvas dependencies | DROP as canvas-scoped | Orphan canvas renderer is not a maintained backend boundary. Audit maintained renderer boundaries instead when touched. |
| Refactor renderer style/color to backend API types | DROP as written | Current terminal tree renderer intentionally writes terminal virtual-buffer styles; renderer-neutral separation occurs before this backend stage. |
| Document/test backend-agnostic rendering | DROP/reframe | Test lowering/layout backend neutrality separately from backend rendering. |
| Architectural note on same | DROP duplicate | Current architecture docs already describe staged/backend ownership; update only if the contract changes. |
| Audit old diff/patch code for backend neutrality | DROP old implementation | The orphan view diff stack is not maintained; terminal buffer diff has a different owner. |
| Document old diff boundary | DROP | Same reason. |
| Test old diff independent of backend | DROP | Same reason. |
| Integrate common utils with canvas | DROP | Canvas renderer is orphaned. |
| Integrate ANSI styling with canvas | DROP | Canvas renderer is orphaned. |
| Integrate virtual buffer with canvas | DROP | Canvas renderer is orphaned. |
| Test backend utility integration for canvas | DROP | Canvas renderer is orphaned. |

## Disposition of every unchecked performance task

| Legacy item | Disposition |
| --- | --- |
| comprehensive event benchmark suite | KEEP → DEV-002, rewritten against current APIs |
| event memory profiling | KEEP → DEV-002/DEV-004 |
| comparative event benchmark reporting | KEEP → DEV-002 |
| event latency harness | KEEP → DEV-002 |
| event stress utilities | KEEP → DEV-002 |
| identify event bottlenecks | DROP as standing task; this is an output of DEV-002 measurements |
| optimize critical event paths | DROP until a measured bottleneck exists |
| event batching for UI updates | DROP until semantics + measurements justify it |
| optimize handler dispatch | DROP until measurements justify it |
| cache topics/subscriptions | DROP until measurements justify it |

## Disposition of every unchecked developer-experience/documentation task

| Legacy item | Disposition |
| --- | --- |
| remove `src/core.lisp` | DONE/stale: file is absent |
| confirm removal of obsolete files | KEEP as the orphan classification below; do not blindly delete |
| expand `src/dev/dev.lisp` | DONE → DEV-001 |
| general debugging visualization | KEEP → DEV-003 |
| event visualization + transaction history | KEEP concept only → DEV-003; DROP old viewer implementation |
| event monitoring + state debugging | KEEP concept only → DEV-003 |
| event-to-state causality | KEEP → DEV-003 |
| event throttling + UI optimization | DROP until DEV-002 evidence |
| event-to-render latency metrics | KEEP → DEV-002/DEV-003 |
| optimize high-frequency render triggers | DROP until measured |
| standardize widget event patterns | KEEP → DOC-002 |
| widget event best-practices docs | KEEP → DOC-002 |
| widget-specific event debug tools | DROP as separate task; generic DEV-003 should expose enough evidence |
| async/TEA design documentation | DROP broad duplicate; current docs already cover async/TEA substantially, close only verified gaps under DOC-001 |
| comprehensive event developer guide | DROP broad duplicate → DOC-001 gap audit |
| common event examples | DROP broad duplicate → DOC-001 gap audit |
| event troubleshooting guidelines | KEEP only if DOC-001 finds missing current guidance |
| all public event API docs | KEEP as exported-API/docstring gap audit under DOC-001 |
| clarify event subsystem relationships | DROP duplicate of current architecture/subsystem reviews |
| usage examples for every API | DROP blanket requirement; examples should target important supported workflows |
| event performance characteristics | DONE substantially in current architecture/quality reports; refresh only from new DEV-002 measurements |
| optimization guidelines | DROP generic advice; document measured findings only |
| performance troubleshooting guide | KEEP only as a DEV-002/DOC-001 deliverable when reproducible diagnostics exist |

## Legacy core/state and event task sheets

`01-core-tea-state.md` contains claims for files and APIs that are absent from the current maintained graph and later contradicts itself by saying transaction consolidation/interactive visualization are still pending. Treat its checklist as historical narrative, not evidence of current features. Current state-semantics/API-convergence work belongs in `docs/TODO-architecture-quality-e2e.md`.

`03-event-system-focus-async.md` is similarly superseded by the current `cl-events` integration and runtime-convergence documentation. Do not reopen its old “consolidate event systems” task wholesale. New event work must identify a concrete remaining boundary in the current graph.

## 17 tracked Lisp sources outside maintained ASDF systems

The audit traversed all maintained root ASDF systems and confirmed exactly 17 tracked `src/**/*.lisp` files outside them.

| File | Disposition | Evidence/risk |
| --- | --- | --- |
| `src/dev/deprecation.lisp` | ARCHIVE/DELETE unless a compatibility consumer is identified | Self-contained and warning-clean, but no references. Do not add dead API solely because it compiles. |
| `src/dev/event-benchmark.lisp` | REWRITE → DEV-002 | Depends on legacy event monitor. |
| `src/dev/event-dashboard.lisp` | DELETE/ARCHIVE prototype | Legacy monitor dependency, missing `split-sequence`, placeholder/fake metrics; not trustworthy tooling. |
| `src/dev/event-monitor.lisp` | REWRITE concept → DEV-003 | Does not compile against current packages; old references only. |
| `src/dev/event-throttler.lisp` | DELETE/EXTRACT only with measured runtime use | Fails compile because `LOCAL-TIME` is absent; throttling is runtime policy, not inherently dev tooling. |
| `src/dev/profiler.lisp` | MERGE candidate → DEV-004 | Potentially useful startup timing, currently unreferenced and style-warning-producing. |
| `src/dev/transaction-viewer.lisp` | DELETE/ARCHIVE prototype | Uses obsolete transaction/history/UI APIs; no maintained consumer. |
| `src/dev/view-debug.lisp` | DELETE/ARCHIVE prototype | Depends on orphan/old `ui-node` debug/diff packages. DEV-001 replaces basic tree inspection. |
| `src/platform/canvas-renderer.lisp` | DELETE/ARCHIVE legacy renderer | Not in ASDF; old `ui-node` path; maintained owner is `tree-renderer.lisp`. |
| `src/platform/profiler.lisp` | MERGE candidate → DEV-004 | Unreferenced and compiles with style warning. |
| `src/state/observers.lisp` | DELETE unless compatibility package is explicitly promised | Thin unreferenced re-export over `cl-state.observer`; warning-clean but no owner/consumer. |
| `src/ui/transaction-controls.lisp` | DELETE/ARCHIVE with transaction viewer | Uses old `make-node`/button/state-history APIs and compiles with undefined-function warnings. |
| `src/view/diff.lisp` | ARCHIVE/DELETE after API compatibility check | Warning-clean but unreferenced maintained implementation; belongs to old view-diff line, not terminal buffer diff. |
| `src/view/layout-debug.lisp` | DELETE/ARCHIVE legacy debug layer | Fails against removed `ui-node`/`get-lr`/`style-value` APIs. |
| `src/view/named-area-finder.lisp` | DELETE fragment; reimplement in grid owner if needed | No package, starts as an insertion note, and references an undefined helper. |
| `src/view/props.lisp` | ARCHIVE/DELETE old parallel prop system | Warning-clean but no current runtime consumer; current component/DSL machinery owns props. |
| `src/view/view-diff-render.lisp` | DELETE/ARCHIVE broken legacy diff renderer | Does not parse: unmatched close parenthesis; only old debug/docs references. |

Do not bulk-delete these files from this audit alone. Deletion is a separate reviewed hygiene change because some names may have been user-facing in older releases.

## Post-release dispatch validation

| ID | Current disposition | 2026-08-20 validation |
| --- | --- | --- |
| POST-001 | DONE | Fixed the enhanced-label `STYLE-PROPS` lexical-scope bug and preserved the open button action contract without generated unused-bindings; the experimental system is project-warning-clean and focused enhanced-widget tests pass 6/6. |
| POST-002 | DONE | Default F1/F10/Escape/Enter bindings now dispatch canonical application messages (`:show-help`, `:show-menu`, `:cancel`, `:confirm`) instead of logging-only actions; focused keymap tests pass 18/18, including no-dispatch and existing precedence/multi-key coverage. |
| POST-003 | DONE | Removed ElmTUI’s dead type-priority registry and re-exported `cl-events.protocols:message-priority` as the sole priority source of truth. `register-message-contract` keeps its third argument only as documented deprecated source compatibility; explicit contract validation remains green and focused contract tests pass 100/100. |
| POST-004 | KEEP / ready | Core `elmtui.asd` still loads packager/examples-runner CLI concerns. |
| POST-005 | KEEP / BLOCKED | Coverage runner still has its own package/`PARSE-FLOAT`/`DECLAIM` warnings. A cold run also exposes one unrelated current suite failure in `COMPONENT-INIT-TESTS`, so zero-exit acceptance is presently blocked. |
| POST-006 | KEEP / ready | `cl-inputs` loop/decoder remain dominated by historical commented implementations (307/607 and 155/288 comment lines respectively in this audit). |
| POST-007 | KEEP / analysis complete | Exact 17-file ASDF-orphan set classified above. Source removal/migration still needs a separately reviewed change. |
| POST-008 | DONE | Retired the invalid duplicate `examples/dirlister_poc/` prototype in favor of maintained `dirli.lisp`; optional `cl-fzy` loading now has an intentional diagnostic, with support loader hidden under `examples/support/`. Base examples remain independent of `cl-fzy`. |
| POST-009 | KEEP / ready | Workspace hygiene report is absent; large untracked/nested-worktree material remains and must not be deleted automatically. |
| POST-INT | BLOCKED | Must not be `ready` while POST-001..009 remain unresolved. |
| PUB | BLOCKED | Publication remains outside this audit. |

## Verification status for this audit

- Maintained example smoke suite: 243/243 checks pass, including Wi-Fi parsing/credential-safety, generated-runner delegation, and caller-data preservation in the finder.
- Optional benchmark test suite: 11/11 checks pass.
- Example/runtime regression suite: 65/65 checks pass after correcting legacy positional key-event parsing and top-level focus-demo patch shape.
- Reusable subsystem gates pass: `cl-events`, `cl-inputs` (one expected no-TTY skip), `cl-state`, and `cl-styles`.
- The repository-wide warning-clean gate is currently blocked by one unrelated `COMPONENT-INIT-TESTS` failure caused by the current `CL-STATE.API:APPLICATION-STATE-DATA` deprecation boundary; all task-owned example regressions are green.
- The top-level release check is additionally blocked before integration tests by current docstring debt: 796 missing exported-symbol docstrings versus the configured maximum of 782. This audit does not raise the threshold to hide that debt.

## Execution order

1. DEV-001 and DEV-002 are complete in this audit.
2. Fix concrete correctness/build-boundary tasks POST-001..006.
3. Review POST-007 dispositions and complete POST-009 workspace hygiene; POST-008 is complete.
4. Implement RENDER-001/002/003 only against `tree-renderer`, with RENDER-004 measurement using DEV-002 reporting.
5. Build DEV-003/DEV-004 only as optional, test-backed tooling; do not add the old orphan stack wholesale.
6. Run DOC-001/DOC-002 as gap audits against current APIs rather than rewriting already-covered architecture material.
7. Resolve the independent warning-clean/docstring release blockers, then unblock POST-INT and make a release-version decision.
