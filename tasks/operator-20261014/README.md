# ElmTUI enhancement dispatch, 2026-10-14

Reviewed current source, Git topology, dirty state, standalone coverage workflows and native operator state. No runtime/library implementation edits were made by the coordinator. Unrelated deletion `docs/release-history-purge.md` is preserved.

## Fresh baseline

`scripts/test-subsystems.sh` exited 0: cl-events 1250 pass; cl-inputs 917 pass / 1 expected controlling-TTY skip; all cl-state suites passed (5829 checks total across 11 suites); cl-styles 218 pass. Root `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load scripts/run-tests-clpm.lisp` exited 0: 8323 pass, 6 opt-in live-tmux skips, 0 fail. Logs retained alongside this file. This is not a full terminal or hosted-CI qualification.

## Source findings

- ElmTUI HEAD d29eace pins cl-events d4399c0, cl-inputs b9d0cbec, cl-state f95baab3, cl-styles 9c2b40c. Separate standalone events at 9d43a2b and state at ad70a85 are ahead and already have measured-badge workflows. The state checkout has pre-existing dirty test/coverage changes; workers must inspect ownership and preserve them.
- cl-inputs already has CI and measured-line-coverage badge plumbing with a 49% gate. Its README explicitly leaves dynamic size discovery unimplemented. Its lane verifies existing plumbing and closes reproduced protocol/lifecycle gaps.
- Local cl-styles CI expects LCOV/JSON/threshold outputs, while coverage.lisp writes HTML, ignores the test result and exits 0. No measured badge appears in that local README. Its lane reproduces and repairs the pipeline and cascade gaps.
- Root coverage script derives an unweighted average from positive HTML percentages and omits zero-covered files from that average. Its qualification lane owns the honest coverage aggregate, badge and full-app evidence.
- DSL recursive/list resolution and macro compile/evaluation contracts warrant targeted negative and cold-compilation checks; they are investigation leads, not confirmed runtime defects.

## Dispatch contract

Seven immutable catalog prompts admitted and rendered, then dispatched once through native OCP. Fleet ensure repaired missing route mappings; `chatgpt-ops inspect --refresh-semantic --json` restored current semantic admission without browser restart. Used explicit native paths because PATH shadows chatgpt-abc with the abc-v2 binary. Per-target user-message inspection provides delivery proof and current canonical URLs; early native receipts used transient URLs, so use delivery-proof.json for conversation links.

Prompts require bounded path ownership, actual implementation, regression tests, honest denominator/report/badge provenance, durable typed results, mandatory independent review, and a single idempotent successor for evidenced residual work. They prohibit threshold weakening, endless audit rounds and externally publishing changes. Library and consumer copies are distinguished. Root DSL/macros/qualification lanes coordinate shared manifest registration and final integration. Native task IDs and receipts are durable, but implementation, filesystem tool receipts, review verdicts and terminal typed results are still pending.

## Lanes

| Task | Prompt | Conversation | Delivery |
|---|---|---|---|
| CL-EVENTS-01-EVENTS-ENHANCE-20261014 | [01-events](01-events.md) | [Open](https://chatgpt.com/c/6acf3bc4-2130-83eb-a85e-e576d3e0fd13) | verified |
| CL-INPUTS-02-INPUTS-ENHANCE-20261014 | [02-inputs](02-inputs.md) | [Open](https://chatgpt.com/c/6acf3bcb-5a48-83eb-a814-5b9308882e8c) | verified |
| CL-STATE-03-STATE-ENHANCE-20261014 | [03-state](03-state.md) | [Open](https://chatgpt.com/c/6acf3bd1-d8d0-83eb-9de3-34be59ba1514) | verified |
| CL-STYLES-04-STYLES-ENHANCE-20261014 | [04-styles](04-styles.md) | [Open](https://chatgpt.com/c/6acf3bd9-3cf0-83ed-ad59-33ec0f770314) | verified |
| ELMTUI-CLPM-05-DSL-ENHANCE-20261014 | [05-dsl](05-dsl.md) | [Open](https://chatgpt.com/c/6acf3be0-6038-83eb-904a-f78628017642) | verified |
| ELMTUI-CLPM-06-MACROS-ENHANCE-20261014 | [06-macros](06-macros.md) | [Open](https://chatgpt.com/c/6acf3be6-c508-83ed-9af4-f170df425997) | verified |
| ELMTUI-CLPM-07-QUALIFICATION-ENHANCE-20261014 | [07-qualification](07-qualification.md) | [Open](https://chatgpt.com/c/6acf3bed-d83c-83eb-ae51-4e31becce7f6) | verified |

## Next action

Inspect exact task events and checkpoints at the authoritative roots; accept only revision-bound implementation/tests, independent approval and durable typed completion. Do not equate a running OCP task or browser completion with implementation. If tool activation fails, use routine registered-project adoption/admission; honor a concrete nonrecoverable denial. Do not blindly replay delivery.
