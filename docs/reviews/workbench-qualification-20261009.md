# Workbench qualification — independent W7 review (2026-10-09)

**Verdict: NOT READY / BLOCKED, not approved or published.** Canonical OCP task `ELMTUI-WB-07-REVIEW-20261009`, packet `affdbc45-6403-4e09-a57c-a959e36a7b52`; independent reviewer `elmtui-wb07-independent-review-20261009` (distinct from W1–W4 authors). This document records a point-in-time evidence review; it does not replace workflow verdicts or the maintained specification `tests/workbench/qualification-matrix.json`.

## Packet-level review decisions

| Lane | Workflow finding | Independent decision / required follow-up |
|---|---|---|
| W1 editor, `01bceeae-0af5-4a02-81b7-699e2585d48b` | Submitted awaiting_review; reviewed and now completed | **Approve standalone editor API only.** Native FiveAM 49 pass, 0 fail, 0 skip; warning-free CLPM compilation. Integration keyboard/paste/geometry/PTY still outside W1 scope. |
| W2 evaluator, `0c2adb28-4156-491c-928c-abf24e96281e` | Corrected sequential read/eval revision, approved concurrently by a different independent reviewer | **Standalone W2 API only.** Native FiveAM 32 pass, 0 fail, 0 skip; prior IN-PACKAGE and reader-macro regressions independently pass. Cancellation is cooperative: a running blocked/infinite EVAL can delay later requests and is **not** proof of bounded Ctrl+C shutdown. |
| W3 completion/docs, `e3e9a023-e491-4df9-bf9c-e32b9002bc63` | Already approved by separate independent reviewer | Scope restricted to API; 55/55 owner FiveAM checks and independent cross-module contracts. Not evidence of cursor-anchored popup/doc dwell on a real terminal. |
| W4 inspector, `ef8bb6aa-71d9-4cd4-9d92-2817aa1641aa` | Reviewed by W7; **revision_required** | **REQUEST CHANGES**: configured preview limits bypassed for symbol objects, and symbol enumeration still traverses full package after row limit. Exact independent reproduction below. No self-approval. |
| W5 app integration, `40eb391f-e289-48a5-bd2f-0231bb6b935c` | Active, not awaiting_review | **NOT READY**. Optional `elmtui-workbench.asd`, launcher and live TUI were missing at inspection. Do not issue a verdict until submitted; rerun actual CLPM/PTY cases, review dependency ordering and terminal cleanup. |
| W6 independent PTY validation, `b26f1250-a35d-4daa-9b29-6b4bd42f983a` | Active, not awaiting_review | **NOT READY**. Need launcher-bound input, emulator-decoded screen/cursor snapshots at 80x24/120x40/160x50, timed dwell, events, terminal restore, idle no-IO and interrupt evidence, not metadata/fixture-only green. |

Other runtime/render changes: repository HEAD `9e7d0c5cf33fa517e6aac8582f7d9b6c3e060015`; pre-existing working-tree changes in `bridge.yml`, `cl-inputs`, `cl-state` and many untracked paths were preserved. The full root suite currently passes except expected skips, so earlier 11 known failures are not reproduced in this baseline. This **does not** prove workbench application parity.

## Actual reviewer-run commands and counts

- `python3 -m unittest discover -s tests/workbench -p 'test_qualification_matrix.py' -v`: **4 passed, 0 failed, 0 skipped, exit 0**. **Catalog schema only**, not app tests. Matrix entries remain `not-run`.
- `python3 -m unittest discover -s tests/workbench/independent -p 'test_*.py' -v`: **21 tests = 18 passed, 0 failed, 3 skipped, exit 0**. The three skips are all `test_application_e2e.ApplicationBlackBoxTests` (missing `ELMTUI_WORKBENCH_TEST_CMD` / W5 launcher). Two private-tmux PTY **fixture** tests exercised tty input/resize/restore, not a running workbench.
- `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --no-userinit --eval '(require :asdf)' --eval '(asdf:load-system :fiveam)' --load src/workbench/editor.lisp --load tests/workbench/editor-tests.lisp --eval '(fiveam:run! (quote elmtui.workbench.editor.tests:editor-tests))'`: **49 pass / 0 fail / 0 skip, exit 0**.
- Analogous CLPM/SBCL `eval-tests`: **32 pass / 0 fail / 0 skip, exit 0**. Warning-free `compile-file` for editor and eval separately: warnings NIL, failure NIL, exits 0, FASLs `/tmp/wb07-editor-qualification.fasl` and `/tmp/wb07-eval-qualification.fasl`.
- Analogous CLPM/SBCL `elmtui.workbench.inspector.tests::inspector-tests`: **19 pass / 0 fail / 0 skip, exit 0**. Single-colon reference is not exported and gave **exit 1** in an initial misinvocation; corrected invocation was used for assertions and the misinvocation is not a product failure.
- `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load run-tests-clpm.lisp`: **4,477 checks: 4,471 passed, 6 intentionally skipped, 0 failed, exit 0**. Captured to `/tmp/wb07-root-suite-20261009.log`. Three warning lines are CL-EVENTS.PROTOCOLS method redefinitions emitted by `SUBPACKAGE-RESTORED-INPUT-SINK-PUBLISHES-TO-EVENT-BUS`; no new owner-module compile warning confirmed by the above individual compilations. All six root skips need `ELMTUI_RUN_TMUX_INTEGRATION=1`; root green is not a substitute for workbench E2E.

## W4 reproducible blocking defect

With source `src/workbench/inspector.lisp` loaded in a fresh CLPM/SBCL process:

```lisp
(let* ((s (elmtui.workbench.inspector:make-inspector-session :max-preview 32))
       (sym (make-symbol (make-string 4096 :initial-element #\X)))
       (h (elmtui.workbench.inspector:register-object s sym))
       (result (elmtui.workbench.inspector:inspect-object s h :probe)))
  (length (getf (getf result :object) :preview)))
;; => 4096, not <= 32; command exit 0
```

`%preview` returns unbounded `symbol-name` for symbols; `:symbols` inventory raw `:name` should also be checked. `%symbol-rows` increments collected count only while below `max-items` but its `do-symbols` traversal still walks the complete package. Fix output bounds and elapsed traversal bounds, add 4K+ symbol and large-package regression checks, preserve passive no-EVAL and optional Slynk. Workflow request_changes verdict was submitted, not merely documented.

## Blocked release gates and next governed action

W5 must first submit its optional ASDF/launcher application to `awaiting_review` with exact changed paths, real PTY evidence and compiler warnings. W6 must separately execute the thirty-case validation plan against the **actual app**, recording input/key events, output bytes, emulator screen cells/cursor positions, terminal sizes, termios before/after, resize, cancellation, idleness and exit status. W4 revision must be resubmitted and independently reviewed. Review W5 and W6 only when these workflow states allow reservation; no guessed pass for `not-run`. Do not make Slynk mandatory or evaluate highlighted completion source; investigate stdout/terminal escape isolation, malicious reader macros, cancellability and live thread cleanup. No publication, no bogus approval, no legacy `next.md`, no edits to W1–W6 paths.

A lightweight independent W2 cancellation probe submitted `(sleep 1.0)`, cancelled the running request, queued `42`, then checked after 250ms: `QUICK_FINISH_IN_250MS=NIL` (exit 0). This documents the known *cooperative* cancellation limitation, **not a standalone regression against W2's declared scope**. Bounding cancellation/keyboard latency and restorable shutdown remain application acceptance checks for W5/W6. There are no `recovery_required` packets at the point checked; do not dispatch replacement OCP tasks while existing packets are active.

## 2026-10-09 additional independent findings (newer than this report's first snapshot)

The earlier W4/W5/W6 statuses above are preserved as historical evidence.
W4 preview/enumeration bounds are now fixed and independently approved:
46 of 46 focused inspector checks pass.

The W5 optional launcher and system now exist. Its genuine CLPM/SBCL PTY
smoke passes 3 of 3 sizes (80x24, 120x40, 160x50), and three separate
application E2E tests pass. A W5 termios ISIG restoration defect was
reproduced using the exact before/after stty states and corrected by its
file-owning worker. Terminal restore, live popup, timed documentation,
resize draft preservation, inspector variable refresh, responsive cooperative
Ctrl+C, and zero idle writes now have independent application-level proof.

W6 qualification runner now contains executable per-case oracles for all
30 required matrix cases, rather than accepting fixture/catalog test successes
as evidence of application correctness. Result:
29 PASSED / 1 FAILED / 0 NOT RUN; exit status 1.
Evidence: tests/workbench/validation/artifacts/run-30d96b41ea/result.json.
The only failing case, editor-paste-controls, shows bracketed multiline
paste is lost before it can reach the editor. An exclusively claimed,
guarded platform adapter repair now preserves literal decoded input
in an atomic (:paste :content TEXT) message (verified in CLPM/SBCL).
The W5 app must still handle that message as one editor insertion,
without executing pasted newlines or form contents.

Independent root suite following the platform fix:
4666 checks, 4660 passed, 6 intentional live-tmux skips, 0 failed,
exit 0, log /tmp/elmtui-w6-paste-root-20261009.log.

W5's original packet remains recovery_required; W6 and W7 packets blocked.
Do not approve or publish while the one real PTY paste case fails, and do
not bypass canonical same-task OCP/workflow recovery. This is a dated audit
appendix, not a substitute reviewer verdict or a false completion receipt.
