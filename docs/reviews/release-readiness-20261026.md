# Release readiness review — 2026-10-26

Follow-up: the findings below were repaired and independently rechecked. See
[release repairs](release-repairs-20261026.md) and the subsequent
[coverage improvement and final local candidate qualification](coverage-improvement-20261026.md).
This initial review remains as the pre-repair evidence.

Verdict: **NO-GO** for the observed dirty checkout at `a6be0e7`.
Review only; no implementation files changed. Existing unpublished changes and
submodule work were preserved. This is a source/test review, not a formal OCP
packet approval or immutable release qualification.

## Findings

1. **P1 — Current integration suite is red.**
   `scripts/run-tests-warning-clean.sh` exits 1: 9,400 checks, 9,389 pass,
   5 fail, 6 live-tmux skips. The failures are parent update-handler inheritance,
   two quoted-syntax rewrite assertions, explicit NIL default preservation, and
   a cleanup scanner occurrence in the untracked `src/update-dsl.lisp`.
   `src/ui/defcomponent.lisp:398` recursively rewrites quoted forms and tests
   default truthiness rather than argument presence. Do not waive these newly
   exposed regressions to recover the older green count.
   Evidence: `test-output/warning-clean-20261026-155423.{stdout,stderr}.log`.

2. **P1 — No reproducible candidate revision vector.**
   `scripts/release-check.sh` exits 1 immediately: cl-events pinned
   `1664d9a694fdcf4520df85ca869a994fcf0cc7d5`, checked out
   `57f1bc8504d61f9b1c49a41bed96eae2b736bd47`.
   New architecture/test systems and source changes remain unpublished working
   tree content. Freeze and qualify a clean candidate without resetting this
   shared checkout.

3. **P1 — New acceptance suites are outside default acceptance.**
   The standalone API-contract and core-slim systems pass 47 and 17 checks,
   respectively, but neither is invoked by `elmtui-tests.asd`,
   `scripts/run-tests-clpm.lisp`, or CI. `clpmfile` registers core-slim but not
   API-contract. Workbench CI also omits `ELMTUI_WORKBENCH_TEST_CMD`, skipping
   three black-box application cases by default. Wire these gates explicitly.

4. **P1 for flagship Unicode/styled UI — Workbench still owns a character-grid
   compositor.** `src/workbench/app.lisp:630` calls `frame-lines` then
   `frame-dsl`; the resulting DSL goes through the normal ElmTUI runtime.
   No parallel raw terminal painter was found in this view path. However,
   `src/workbench/view.lisp:6`, `:10`, and `:136` clip, paint and position the
   cursor using character counts. `frame-dsl` at `:310` drops semantic span
   styles on any row containing non-ASCII, retaining only the first style and
   setting width from string length. This is not display-cell/grapheme-aware
   geometry; the current Unicode regression checks node shape, not rendered
   Unicode cell/style correctness. Move pane, clipping, cursor/overlay geometry
   into ElmTUI abstractions and verify wide/combining text through the full
   layout/buffer/PTY path. Strict terminal-output ownership currently holds;
   strict toolkit ownership of composition remains incomplete.

5. **P2 — Memo cache registry still retains discarded caches.**
   `src/view/memo.lisp:72` stores each cache strongly under its original function;
   `:74` stores that function in the strong statistics table. Weak wrapper keys
   do not free the original-function cache lists. Repeated wrappers for a live
   function accumulate cache tables; clearing empties but never removes them.
   Replace registry ownership with weak wrapper references and add a lifetime
   regression. Focused invalidation tests passing does not prove lifetime safety.

6. **P2 — Compatibility policy needs reconciliation.**
   `src/core/loop.lisp:177` now rejects previously ignored nondefault FPS/WAIT
   values. This is documented, but is an observable behavior break; decide the
   release/deprecation policy explicitly. The broad public facade remains;
   API support classification is not an export reduction.

## Progress and scope

The split of keytester/keytester-map/counter into `elmtui-example-widgets`
is real and the focused boundary tests pass. Core still owns widgets,
backends, rendering and `dev/dev` (`elmtui.asd:180`); developer extraction is
explicitly deferred. API work improves memo invalidation/argument forwarding
and documents VIEW-DIFF as whole-tree replacement. It is contract hardening
plus a small load-boundary reduction, not a finished minimal application API.

## Fresh verification

- API-contract: 47/47; core-slim: 17/17.
- Workbench default independent suite: 25 tests, 22 pass, 3 launcher-gated skips.
- Workbench PTY smoke: 80x24, 120x40, 160x50 PASS, including exit/restoration.
- Root warning-clean suite and release gate: FAIL as detailed above.
- Logs for focused and workbench runs: `/tmp/elmtui-review-*.log`.

Next order: repair root regressions; wire acceptance suites; replace workbench
character-grid assumptions with ElmTUI geometry; freeze submodule/source vector;
rerun release, coverage, packaging and terminal gates on that exact candidate.
