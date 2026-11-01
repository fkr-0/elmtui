# Release readiness review — 2026-10-26

Verdict: **hold publication**. The frozen candidate passes the previously expanded local release gate, but additional release checks fail and delivery provenance is incomplete. This is a review; implementation and publication were not changed.

## Findings

1. **P1 — strict documentation build fails.** Running `scripts/prepare-site.py` followed by `mkdocs build --strict` on the candidate aborts with five link warnings. The copied examples catalog retains two `../docs/` links (each occurs twice), and the Workbench guide references an uncopied review under `guide/reviews/`. Repair copied-document link resolution and rerun the strict build. Log: `/tmp/elmtui-readiness-site.log`.

2. **P1 — candidate cannot yet be reproduced from public commits.** Candidate root `4d536d81019e2d5fff60dff3032bc667bd6a632c`, cl-inputs `d0475d30fffc02b51c39ac131a861b8c8a970a7e`, and cl-styles `bc4d0eca9959dea7aa6a185ed9f2f1a58a86a2ac` do not resolve through GitHub's commit API. Candidate cl-events and cl-state commits do resolve. The shared checkout has 106 dirty status paths and its release gate fails immediately on the cl-events pin mismatch. Prepare the intended committed source and dependency set before tagging; validate that exact revision in CI.

3. **P1 — distribution and version decisions remain open.** The gate builds and tests a minimal executable but does not produce a bundled source archive or install it in a fresh environment. Git submodule archives alone do not supply dependency contents. `docs/release-checklist.md` overstates this proof near its introduction while leaving archive deliverables open later. Root metadata uses 0.2.0, `website/release.md` proposes 0.1.0, and existing local v0.2.0 points at older commit `511edb2bf066bdd80343cc82e49d2ec2d0773814`. Choose the release version and concrete deliverable without silently moving an existing tag.

4. **P2 — maintained terminal sweep fails in both backends.** `scripts/test-terminal-apps.py:320` expects `Ⅱ PAUSED`, while Game of Life renders `◉ PAUSED`. Its reset assertion also expects an obsolete generation format. Both tmux and private-Xvfb urxvt runs pass 8/9 cases and stop at this assertion. Captured output demonstrates the paused state; it does not establish a runtime pause defect. Reset/resume remains unverified by these runs. Logs: `/tmp/elmtui-readiness-tmux.log` and `/tmp/elmtui-readiness-urxvt.log`.

5. **P2 — qualification matrices differ.** CI additionally checks generated API documentation and Neon; the local release gate additionally checks warning-clean loading and packaged-executable PTY behavior. Neither requires the complete example terminal matrix. The gate also lacks an explicit clean-tree check. Use one declared release matrix and require clean root and dependency trees for the qualified artifact.

6. **P3 — stale instructions and status.** `examples/README.md:338` refers to absent `rt.sh`. Older October 9 release checklists contain superseded failure/coverage claims; distinguish them from this review and the current coverage report.

## Evidence and limits

- Frozen candidate root and all four dependency working trees are clean. Candidate-tracked source, tests, and scripts match the shared checkout byte for byte; only three review/planning documents differ. Candidate receipt: `test-output/release-candidate-20261026.json`.
- Previously recorded expanded candidate gate: 9,972 root checks, 9,966 passed, six opt-in live tmux skips, zero failures; SB-COVER 22,318/40,199 forms, **55.52%**, across 88 primary files; Workbench 26/26 and three PTY sizes; dependency suites, ASDF failure injection, and packaged minimal executable PTY passed. These results were not rerun wholesale in this review.
- Fresh checks: Neon **68/68** with no skips; mini-editor Ctrl-S persistence/dirty-state PTY **1/1**; terminal sweeps **8/9 each**; strict site build **failed**. Candidate remains clean after checks.
- Public main is `b9368770ef6fccc05ed6a71e0be0cb3e1eb6a742`. Latest verification run [38181086488](https://github.com/fkr-0/elmtui/actions/runs/38181086488) is green for that October 11 revision, not this candidate. GitHub releases API returned an empty collection. Public Pages deployment and live website behavior were not qualified by this review.

Release closure requires fixing the documentation/test failures, selecting version and source distribution, preparing publicly resolvable dependency pins, and passing the declared matrix on the final exact revision. Existing Workbench/native composition evidence remains positive; this review found no new Workbench rendering regression.
