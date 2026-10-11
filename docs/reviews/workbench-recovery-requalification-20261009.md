# ElmTUI Workbench W5–W7 recovery and requalification (2026-10-09)

**Status: implementation checks GREEN; operator workflow NOT YET RECONCILED; no release approval.**

This is a fresh independent evidence record, not a substitute for the original canonical W5, W6 or W7 packet receipts or W7's reviewer verdict. Earlier failure reports remain historical evidence.

## Exact canonical packets

| Lane | OCP task | Existing ws-bridge packet | Lifecycle at inspection |
| --- | --- | --- | --- |
| W5 integration | `ELMTUI-WB-05-INTEGRATION-20261009` | `40eb391f-e289-48a5-bd2f-0231bb6b935c` | `recovery_required`; obsolete startup-blank checkpoint |
| W6 live qualification | `ELMTUI-WB-06-VALIDATION-20261009` | `b26f1250-a35d-4daa-9b29-6b4bd42f983a` | `blocked`; obsolete missing-launcher prerequisite |
| W7 independent review | `ELMTUI-WB-07-REVIEW-20261009` | `affdbc45-6403-4e09-a57c-a959e36a7b52` | `blocked`; obsolete W4/launcher prerequisite |

W1–W4 and W8 have completed their individual workflow reviews. Reuse the same W5–W7 identities; do not manufacture replacement tasks or mark source ownership as transferred.

## Fresh executable evidence

- `python3 tests/workbench/validation/runner.py` — exit **0**, 30 distinct required application scenarios **30 PASS / 0 FAIL / 0 NOT RUN**. Evidence: `tests/workbench/validation/artifacts/run-385b6ec7f3/result.json`. Bracketed multiline paste now reaches the editor without implicit evaluation; this was the previously failing case.
- `python3 tests/workbench/pty-workbench.py` — exit **0**; actual application PTY smoke passed **80×24, 120×40, 160×50**.
- `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load scripts/run-tests-clpm.lisp` — exit **0**, **4,700 PASS / 6 intentional opt-in tmux SKIP / 0 FAIL** (4,706 checks).
- `ELMTUI_WORKBENCH_TEST_CMD='clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load examples/workbench.lisp' python3 -m unittest discover -s tests/workbench/stress -p 'test_*.py' -v` — exit **0**, **10/10 PASS**, including real terminal idle writes, bounded CPU sample, Ctrl+C, startup terminal signal mode and termios restoration.
- Same `ELMTUI_WORKBENCH_TEST_CMD`, `python3 -m unittest discover -s tests/workbench/independent -p 'test_*.py' -v` — exit **0**, **21/21 PASS**, no opt-in live tests skipped.

These results are observed against the shared working tree, not necessarily a clean tag. Some workbench launcher and harness paths remain uncommitted under active owners' claims. The W5 implementation was substantially committed as `558b7a97` and its optional system as `9a539c27`.

## Operator recovery constraint

The original W5 packet has a historic dirty transaction checkpoint. The public workflow recovery method supports only `restore-and-requeue` (explicit transaction **rollback**), `block`, or `cancel`. Rollback would risk valid concurrently edited work while the W5 source owner's claims remain active, and `block` would not constitute successful qualification. No destructive recovery was performed.

The W6 packet is `blocked`, not `proposed`: the proposed-only runtime publication gate returned `preserved / continue`, without mutating it. W7 must not be approved before W5/W6 lifecycle evidence is submitted. The technical blocker is cleared but the workflow states have not been promoted.

## Required guarded continuation

1. W5 owner saves/commits remaining claimed launcher/code, then resolves W5's **same** dirty packet through a supported non-destructive recovery/reconciliation operation, followed by its typed phase result and independent review.
2. Resume the **existing** W6 packet through operator-governed same-task continuation; submit exact 30-case evidence and request independent review. Do not overwrite its older artifacts, since both failure and success runs are legitimate.
3. Independent W7 reviewer inspects W5 source/PTY and W6 raw traces/per-case oracles, then issues an explicit verdict through the original W7 packet. No self-approval or release tag.

A durable `.ws-bridge/agent-checkpoints` record was also written for each original W5–W7 OCP task. This report is **not** a workflow-state transition or release sign-off.
