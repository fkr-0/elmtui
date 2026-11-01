# ElmTUI Workbench E3 release qualification — 2026-10-27

## Identity, safety and outcome

- Canonical OCP: `ELMTUI-CLPM-E3-WORKBENCH-UX-20261027-7FC1E4`.
- Workspace: `/home/user/code/lisp/elmtui.lisp`; initial HEAD `a6be0e79e7a954eb77b4b299038984ad7170cb41`.
- Workflow packet: `983e3055-3ead-4692-8e59-d25bcf43c6a8`, sourceId equals the canonical OCP task.
- Owned paths only: `src/workbench/**`, `tests/workbench/**`, this report.
- **Outcome: reviewer revisions implemented; release-quality dynamic PTY resize remains FAIL; independent re-review required.** No tag, release or deployment.

The original shared Git tree was heavily dirty. In particular, `src/workbench/app.lisp`, `src/workbench/view.lisp`, `tests/workbench/pty-workbench.py`, and `tests/workbench/independent/test_native_repl_presentation.py` already had independent modifications. E3 edits are additive and narrowly applied; unowned diffs must not be attributed to this task. The existing v0.2.0 tag was not touched.

## Implemented changes

1. `src/workbench/view.lisp`: keep the selected inspector row visible in a viewport smaller than its snapshot; show the active completion candidate when selection advances beyond five candidates. Preserve the existing native ElmTUI semantic tree; no second renderer.
2. `src/workbench/app.lisp`: paginate the inspector's bounded snapshots rather than stopping at its first 25 entries; reset page/selection when filter or section changes. Bound transcript PageUp, reflect actual small resize dimensions in Workbench state, and align initial editor columns with native pane width.
3. `src/workbench/editor.lisp`: handle paired regional indicator flags in grapheme cursor movement/deletion and share grapheme width calculation with ElmTUI layout (ZWJ/emoji variation included). Removed redundant private wide-glyph table.
4. `tests/workbench/editor-tests.lisp`: unicode/flag/ZWJ/tab/newline insertion, movement, deletion and cursor-cell cases.
5. `tests/workbench/e3-release-tests.lisp`: explicit FiveAM viewport, candidate, inspector pagination, small-state resize, scroll and Slynk-disabled regressions.
6. `tests/workbench/independent/test_e3_release_pty.py`: genuine private tmux + public launcher tests for completion, evaluator-error recovery and resizing with retained draft; termios checked on clean exit. Hard resize oracle intentionally remains failing.

## Exact executed commands and evidence

From project root, commands executed via ws-bridge `run_workspace_command`:

| Command | Exit | Observation |
| --- | ---: | --- |
| `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(require :asdf)' --eval '(asdf:load-system "elmtui-workbench")'` | 0 | Compiled E3 sources. Three LOG4CL-IMPL redefinition warnings existed before these edits. |
| `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(require :asdf)' --eval '(asdf:load-system "elmtui-workbench")' --eval '(asdf:load-system "fiveam")' --load tests/workbench/editor-tests.lisp --eval '(fiveam:run! (quote elmtui.workbench.editor.tests:editor-tests))'` | 0 | Pre-edit editor 54/54 checks PASS. |
| FiveAM command above extended with `--load tests/workbench/completion-tests.lisp --load tests/workbench/inspector-tests.lisp --load tests/workbench/eval-tests.lisp --load tests/workbench/e3-release-tests.lisp` and one `--eval '(fiveam:run! (quote ...))'` per suite | 0 | Editor 68/68; completion 72/72; inspector 46/46; evaluator 32/32; E3 27/27. **245/245 total checks.** The first authoring attempt exited 1 due to an extra test parenthesis; corrected before this run. |
| `python3 tests/workbench/pty-workbench.py --traces /tmp/elmtui-e3-before` | 0 | Baseline three-size smoke: 80×24, 120×40, 160×50 all PASS; captured 8,799/12,943/19,469 bytes respectively. |
| `python3 tests/workbench/pty-workbench.py --traces /tmp/elmtui-e3-after` | 0 | Post-edit same three-size smoke all PASS; captured 6,038/12,943/19,469 bytes respectively. Not a performance benchmark; do not infer improvement from byte count. |
| `python3 -m unittest discover -s tests/workbench/independent -p test_e3_release_pty.py -k completion -v` | 0 | Completion visible/selection/dismissal PTY case PASS after correcting a regex typo in the test. |
| `python3 -m unittest discover -s tests/workbench/independent -p test_e3_release_pty.py -v` | **1** | Three tests: completion PASS, evaluator error recovery PASS, resizing FAIL (two subcase failures, 40×12 and 120×40). This is the final full E3 PTY result. |
| `python3 -m unittest discover -s tests/workbench/independent -p test_e3_release_pty.py -k editor -v` | 1 | Evaluation-error recovery PASS; small-terminal resize FAIL with two subcase failures. |
| `git diff --check -- src/workbench tests/workbench` | 0 | No whitespace errors in tracked E3-scope diff. |

Historical comparison: `docs/reviews/release-repairs-20261026.md` recorded **26/26 Workbench** black-box cases green on 2026-10-26. Those oracles are not sufficient to cover this newly added 24×8 growth scenario; do not overwrite historical results or characterize all Workbench PTY cases as now green.

## Release-blocking black-box finding: small resize

**Repro:** In `test_small_terminal_resize_preserves_incomplete_editor_and_exit` launch `./scripts/examples.sh run repl` under private tmux at **24×8**, wait for `Ready  |`, type the unsubmitted `(list 123`, and confirm it is visible. Resize private tmux to **40×12** and then **120×40**. Geometry queries report those sizes, but screen captures retain only a 24-column truncated header and `Transcript (0)`; editor rows and draft disappear from the captured pane. Each transition was waited on for 12 seconds; both failed. The same test checks exit/termios.

**Boundary:** Unit-direct Workbench `:terminal-resized` tests preserve source and reflect even 12×5 and 1×1; static three-size PTY startup smoke passes. Thus whether the cause lies in the native ElmTUI repaint, event delivery, terminal anchor, or private-tmux resize path remains **unproven**. Do not patch `src/core/**` or `src/platform/**` from E3. An E2 coordination note (`67d5d68c-dd58-4f4b-be75-4cdc8221a718`) records the exact reproducer. Next gate: independent PTY implementation using a second terminal driver, then scoped terminal-event/paint trace before any root fix.

## Additional semantic limits

- Slynk: `slynk-capability-report` explicitly returns `:transport :disabled` and `:remote-inspection :not-implemented`. No remote listener, session, failure recovery or reconnect exists to exercise. Qualify local evaluator error recovery only; **do not claim Slynk reconnection**.
- Editor grapheme widths follow the shared ElmTUI approximation. Terminal fonts and emoji presentation widths vary; tested pairs and VS16/ZWJ are not comprehensive UAX #29 grapheme coverage.
- Completion popup is the existing inline declarative pane, not a separate cursor-anchored popup. The PTY test demonstrates selection visibility and dismissal, not all off-screen terminal/emulator focus behavior.
- Native terminal integration was not exercised on urxvt in E3. The three-size smoke and private tmux cases do not substitute for urxvt/Xvfb.
- Existing 26/26 Workbench and broader 9,972-test release-gate statements were historical, not rerun wholesale in this lane.

## Review / continuation gate

The first authoring session could not launch an independent backend. A subsequent independent managed reviewer **did** inspect the packet and requested changes on 2026-10-27 at 05:00:33Z; its concrete findings and scoped repairs are recorded below. Independent re-review of these revisions is pending and must not be represented as approval.

**One evidence-backed scoped continuation:** terminal resize delivery/redraw qualification for E2 (or a new unique non-overlapping follow-up if E2 has completed): second-driver reproduction of the 24×8 → 40×12 → 120×40 sequence, trace actual `:terminalresized` event and viewport rect, implement a root fix only if independently verified, preserve all unrelated dirty state, and pass both the existing three-size smoke and new E3 hard PTY resize oracle at exit 0 with termios restored. Do not silently dispatch a duplicate while E2 is active.

**Release disposition:** blocked pending resize qualification, native terminal regression review, and an actual independent Workbench reviewer approval; no push/publish/tag.

## E3 independent-review revisions — 2026-10-27, second dispatch

- Dispatch attempt `c84cc224a9ca471786870a56e58c5918` resumed **the existing** `983e3055-3ead-4692-8e59-d25bcf43c6a8` workflow packet with the same canonical OCP task; no duplicate opportunity or legacy `next.md`.
- Independent reviewer `elmtui-e3-review-20261027-review2` issued `request_changes` at 05:00:33Z, after confirming the pre-revision real PTY resize failure. Additional specific defects were RI cursor/backspace parity on 3/5 consecutive indicators and a selection hidden behind the height-clipped completion pane at 40×12. This supersedes the earlier statement that no independent reviewer was available.
- Scoped repair `src/workbench/editor.lisp`: one boundary predicate now pairs consecutive regional indicators by left-to-right parity for both forward and backward segmentation. The previous three-indicator counterexample `🇩🇪🇫` no longer deletes the last two individual codepoints together. Five-indicator motion, backspace, forward-delete, and reset at ASCII boundaries are exercised in `tests/workbench/editor-tests.lisp`.
- Scoped repair `src/workbench/view.lisp`: pass actual popup height budget to the *existing* semantic ElmTUI completion pane. The active candidate stays within the rendered row budget; at 24×8, the only available row favors the selected candidate over a header. Optional signature/docs are appended only when there is room. Corrected a subsequent `NIL` height edge case at 1×1. No second renderer.
- Scoped regression `tests/workbench/e3-release-tests.lisp`: assert the selected candidate remains in the semantic tree for 40×12 and 24×8, in addition to inspector paging, tiny resize, transcript, and disabled Slynk. These are semantic-frame checks; no claim that they prove cursor visibility on every emulator.

### Measured post-revision acceptance

Executed from `/home/user/code/lisp/elmtui.lisp` via ws-bridge `run_workspace_command`:

```sh
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:load-system "elmtui-workbench")' \
  --eval '(asdf:load-system "fiveam")' \
  --load tests/workbench/editor-tests.lisp \
  --load tests/workbench/completion-tests.lisp \
  --load tests/workbench/inspector-tests.lisp \
  --load tests/workbench/eval-tests.lisp \
  --load tests/workbench/e3-release-tests.lisp \
  --eval '(fiveam:run! (quote elmtui.workbench.editor.tests:editor-tests))' \
  --eval '(fiveam:run! (quote elmtui.workbench.completion.tests::completion-suite))' \
  --eval '(fiveam:run! (quote elmtui.workbench.inspector.tests::inspector-tests))' \
  --eval '(fiveam:run! (quote elmtui.workbench.eval.tests::eval-tests))' \
  --eval '(fiveam:run! (quote elmtui.workbench.e3.tests::e3-release-suite))'
python3 tests/workbench/pty-workbench.py --traces /tmp/elmtui-e3-after-review-20261027
python3 -m unittest discover -s tests/workbench/independent -p test_e3_release_pty.py -v
git diff --check -- src/workbench tests/workbench
```

| Check | Before reviewer fixes | After fixes | Exit after | Remarks |
| --- | --- | --- | ---: | --- |
| Editor FiveAM | 68/68 | **80/80** | 0 | 12 new assertions, including RI odd-run behavior |
| Completion FiveAM | 72/72 | 72/72 | 0 | No regression |
| Inspector FiveAM | 46/46 | 46/46 | 0 | No regression |
| Evaluator FiveAM | 32/32 | 32/32 | 0 | Local error recovery only |
| E3 FiveAM | 27/27 | **31/31** | 0 | 4 new selection/height assertions |
| Total FiveAM | **245/245** | **261/261** | 0 | FiveAM must be assessed by printed check counts as run! can exit zero even when assertions fail |
| Three-size PTY launcher smoke | 3/3 | **3/3** | 0 | 80×24, 120×40, 160×50; 6,114 / 13,019 / 19,545 trace bytes |
| E3 private tmux PTY | 2/3 | **2/3** | **1** | Completion and evaluator recovery PASS; dynamic resize FAIL at 40×12 and 120×40 |
| Scoped `git diff --check` | pass | pass | 0 | No whitespace defects |

The dynamic PTY failure reproduces unchanged after this revision: start 24×8, insert unsent `(list 123`, then `tmux resize-window` to 40×12 and 120×40. Both target geometries are confirmed but the captured image remains a 24-column truncated header with `Transcript (0)`, no editor/draft, after 12 seconds each. We have not established whether this lies in the test's tmux pane resize behavior, terminal dimension events or repaint anchoring. This is **not** a passing release gate. A second-driver trace belongs to the non-E3 terminal event/render owner; E3 scope prohibits core/platform modification.

Baseline git HEAD in this second dispatch: `533c97d6d7c9c0ac6045efc0aa19f6e4f1d88bb7`. The shared tree includes unrelated in-flight tracked/untracked changes, so aggregate `git diff --stat` cannot attribute these changes solely to E3. The scoped changes were applied as guarded ws-bridge file transactions; no E3 Git commit, staging, tag movement, push, publication or deployment occurred. The existing `v0.2.0` tag remains present. Slynk transport/reconnection remains **unsupported**, not tested successfully. Independent **re-review is required** on the revision, and until the dynamic resize gate is resolved release disposition stays blocked.

