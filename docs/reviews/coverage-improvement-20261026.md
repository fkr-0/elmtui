# Coverage improvement — 2026-10-26

Mandatory-toolkit SB-COVER expression coverage increased from **47.68%**
(19,101/40,060) to **55.52%** (22,318/40,199): **+7.84 percentage points**.
The same reviewed inventory of **88 mandatory source files** is included.
No runtime sources were excluded to obtain this increase; the expression
denominator grew slightly with the repairs. Load-time documentation remains
included in the primary metric.

The minimum in `scripts/coverage-gate.py` is now **55.0%**, enforced by CI and
the release gate. Provenance, per-source counts and the generated badge are
under `coverage/`; hosted/default-branch badge publication is not established.

## Behavioral coverage

Four new suites exercise real state transitions, returned patches/commands,
rendered values, ANSI output bytes, focus/context lifecycle and threaded defaults:

- `tests/coverage-focus-behavior-tests.lisp`
- `tests/coverage-widget-behavior-tests.lisp`
- `tests/coverage-backend-behavior-tests.lisp`
- `tests/coverage-defaults-behavior-tests.lisp`

All are default `elmtui-tests` components. A separate reviewer reran their
**446 checks**, with no failures or skips.

| Mandatory source | Before | After |
|---|---:|---:|
| Focus manager | 25.9% | 79.0% |
| Scoped defaults | 0.4% | 64.6% |
| Textinput | 0.0% | 94.0% |
| Listbox | 23.0% | 90.1% |
| Scrollable container | 0.0% | 83.1% |
| Viewport | 28.0% | 48.1% |
| Terminal backend | 17.8% | 53.3% |
| Faketerm backend | 44.3% | 80.5% |
| ANSI style conversion/transitions | 49.6% | 72.6% |

## Defects found and repaired

- Textinput now implements the shared public INIT/UPDATE/VIEW generics, reads
  actual component paths, returns update results, applies bounded cursor edits,
  honors disabled input and emits on-change/on-submit commands. Callback
  commands pass through unchanged; on-change is emitted only for value changes.
- Native component DSL participates in focus traversal. Focus history consumes
  previous entries, valid dispatch/navigation reports handled status, failed
  actions remain unhandled, and keybinding listings accept canonical string keys.
- Scrollable containers accept their documented literal keyword messages and
  use application state for focus. Empty listboxes clear their selection.
- ANSI invisible attributes participate in equality, deltas and reset output.
  Virtual buffers coerce accepted style plists into canonical terminal styles.
  Styled boxes retain the supplied style when no border-color override exists.
- Faketerm restyles actual cells without losing characters or affecting their
  neighbors, and restores the caller's current style after drawing a border.
- Terminal stream fallback writes scrolling/clear sequences to binary output.
  Device and stream directions agree: positive API scrolling advances the
  viewport down, moving content up to make room below. Existing live device
  behavior was preserved.
- Scoped default overrides are hygienic, nearest-child overrides win, and
  dynamic binding prevents temporary defaults leaking to other threads.

Each behavior repair followed executable failures. A separate review exposed
additional native-focus, style, scroll-parity, failed-binding and thread-scope
cases; those regressions now pass too. Evidence is in
`/tmp/elmtui-reviewer-coverage-suites.log`,
`/tmp/elmtui-reviewer-coverage-recheck.log`,
`/tmp/elmtui-reviewer-focus-defaults-recheck.log`, and
`/tmp/elmtui-reviewer-textinput-render.log`.

## Measurement reliability and validation

An earlier concurrent build overwrote shared instrumented FASLs, making tested
focus/scrollable files report zero coverage. That run correctly failed the
55% gate and invalidated its success artifacts. A serial run measured 55.52%.
The coverage wrapper now supplies a private per-run ASDF output directory before
dependencies are loaded, and cleans it on exit. Ordinary builds cannot replace
the instrumented files. The isolated run reproduced the same **22,318/40,199**
count; library, test and developer sources remain outside the primary metric.

| Verification | Result / evidence |
|---|---|
| Full warning-clean suite | 9,972 checks: 9,966 pass, 0 fail, 6 opt-in tmux skips; `test-output/warning-clean-20261026-213545.*.log` |
| Serial coverage | 55.52%; `test-output/coverage-20261026-213822.*.log` |
| Private-cache coverage | 55.52%; `test-output/coverage-20261026-214109.*.log` |
| Coverage gate/badge negative cases | 16 tests pass; `/tmp/elmtui-coverage-guards-final.log` |
| Workbench native/PTY application suite | 26 tests pass; `/tmp/elmtui-coverage-workbench.log` |
| API reference structure | PASS, 1,822 bindings; `/tmp/elmtui-coverage-reference.log` |

These checks establish the named local behaviors and coverage gain. They do not
establish hosted CI, release publication, all real-terminal/font combinations,
or complete API documentation. The updated candidate receipt and release gate
result are recorded below.

## Updated frozen candidate

The expanded `scripts/release-check.sh` exited **0** in the clean, isolated
candidate `/tmp/elmtui-release-candidate-20261026-evi5sz9f/repo`, root commit
`4d536d81019e2d5fff60dff3032bc667bd6a632c`.

| Library | Exact candidate gitlink |
|---|---|
| cl-events | `57f1bc8504d61f9b1c49a41bed96eae2b736bd47` |
| cl-inputs | `d0475d30fffc02b51c39ac131a861b8c8a970a7e` |
| cl-state | `8f116e7191a545719b9d4500f0d87880861e776e` |
| cl-styles | `bc4d0eca9959dea7aa6a185ed9f2f1a58a86a2ac` |

This run passed the independent library bundles, warning-clean integration,
ASDF failure-injection guards, all 26 Workbench tests, raw PTY smoke at three
sizes, the **55%** coverage gate at **55.52%**, and packaged-executable PTY smoke.
The candidate remained clean. Receipt:
`test-output/release-candidate-20261026.json`; full gate log:
`/tmp/elmtui-coverage-candidate-release-check.log`.

These snapshot commits include the shared checkout's existing library work and
are local only. The shared branch, staged state and gitlink pins were preserved.
No release tag, push or publication occurred.
