# ElmTUI operator qualification — 2026-10-14

## Scope and provenance

- Canonical OCP task: `ELMTUI-CLPM-07-QUALIFICATION-ENHANCE-20261014`.
- Repository: `/home/user/code/lisp/elmtui.lisp`; branch `main`;
  baseline HEAD `d29eace7bda867a353e4086551bc0031f4cfc986`.
- **Not final accepted source revision**: concurrent DSL/macro work changes
  the working tree. Any final acceptance needs a clean rerun at the accepted
  revisions. No push, tag, publication or hosted workflow is claimed.
- Runtime source hashes during measured run (uncommitted concurrent edits must
  not be mistaken for HEAD-only proof): `src/ui/dsl-resolution.lisp`
  `a34990e7107707890f632df7accf16cb3c094ae0f66f9a8bc2a3b9c73797ed25`;
  `src/ui/defcomponent.lisp`
  `0a59f1f7c1cbfed2e84108ee1f8de9021f639126fb3c5802e8b2a479ff7f026a`;
  `src/app/application.lisp`
  `6d1b5e5ade10b84bc3deb28688394bddcd98debb70cfa2c474a0aa6f5f89d90e`;
  `src/app/tea-core.lisp`
  `704be0e12d950535767b6a033b538e01ba1723e7ee9f43d0cec13b0dc64b86a9`.
- Existing unrelated deletion of `docs/release-history-purge.md` is preserved.

## Primary code coverage (local)

The unit is **SB-COVER expressions**, not executable lines or assertions.
Root ASDF system `elmtui` is the source inventory authority. The gate reads
every Lisp source pathname from its ASDF component tree; unexecuted files
count, including `src/api.lisp` (0/3). Files must have valid expression
counts in the SB-COVER report. Tests and external dependencies are compiled
without coverage instrumentation after the root system has been force-compiled
with instrumentation. Runtime and test results are executed in a fresh SBCL
process and stale SB-COVER state and output are cleared beforehand.

Measured result: **18,302 / 39,712 expressions = 46.09%, 92 files**.
Initial ratchet: 46.0% with exact expression denominator 39,712. This is a
measured local ratchet, not a claimed higher quality target. Update the
expected denominator intentionally when source changes, with a new verified
inventory and regression evidence. All source in the primary ASDF system
counts; the optional example, Workbench and independent library systems do
not silently contribute to the primary metric and require separately named
reports before their own code coverage can be claimed.

Reproduce with `scripts/run-coverage-warning-clean.sh`. Outputs:
`coverage/cover-index.html`, `coverage/primary-sources.txt`,
`coverage/coverage-summary.csv`, `coverage/coverage-summary.txt`, and
timestamped logs under `test-output/`. HTML is SB-COVER generated; CSV is
the weighted primary-source breakdown. Coverage HTML may additionally list
non-primary files, but they do not affect the named primary metric.

Coverage gate negative tests: `python3 -m unittest discover -s tests -p
'test_coverage_gate.py' -v` — **10 passed**, including missing/duplicate
inventory, missing/malformed report rows, zero-coverage files, zero or
invalid denominator, escape paths, denominator drift, and threshold failure.

## Evidence layers

| Layer | Local evidence | Status |
| --- | --- | --- |
| Primary coverage | `test-output/qualification-07-coverage.log` | PASS 46.09%, 92 files |
| Root FiveAM | `test-output/qualification-07-root.log` | PASS 8,397, SKIP 6 (tmux disabled), FAIL 0 |
| Independent subsystem runner | `test-output/qualification-07-subsystems.log` | PASS, exit 0; individual system counts in log |
| Warning-clean root suite | `test-output/qualification-07-warning-clean.log` | PASS, exit 0 |
| Independently bundled libraries | `test-output/qualification-07-subproject-bundles.log` | PASS, exit 0 |
| Facade symbol identities | `test-output/qualification-07-facade.log` | PASS, aliases=950 |
| Public docstrings | `test-output/qualification-07-docstrings.log` | PASS, 1640/1819 documented, 90.2%; not code coverage |
| Generated API structure | `test-output/qualification-07-reference.log` | PASS, 1822 entries, 179 missing |
| Game of Life real PTY | `test-output/qualification-07-life-pty.log` | PASS 2/2 |
| tmux geometry | `test-output/qualification-07-tmux-geometry.log` | PASS 1/1 |
| Glider private tmux | `test-output/qualification-07-glider-tmux.log` | PASS 6/6 |
| Extended example PTY | `test-output/qualification-07-extended-pty.log` | PASS 9/9 |
| tmux scrollback/restoration sample | `test-output/qualification-07-tmux-restoration.log` | PASS 5/5 |
| Bottom-row Wi-Fi PTY | `test-output/qualification-07-bottom-row.log` | FAIL 2/2: expected menu row 16, observed `ROW-29` |
| Neon terminal restoration | `test-output/qualification-07-restoration.log` | FAIL 1/2: expected 24 scroll-up operations, observed 0 |
| Native urxvt/private Xvfb | `test-output/qualification-07-native-urxvt.log` | ERROR 2/2: screenshot `import` timed out/failed; no verified visual proof |
| Hosted GitHub Actions | `.github/workflows/ci.yml` | NOT OBSERVED; no hosted success asserted |
| Public code coverage badge | `README.org` | Local measured badge only; hosted data/publishing pending |
| Independent review | Native OCP review gate | PENDING; reviewer tool unavailable and OpenCode backend reported unhealthy; no independent verdict |

The native urxvt harness invokes **fake `nmcli`**, not host networking.
The screenshot error means native live behavior is *not qualified*, even
though `urxvt`, `Xvfb`, and `tmux` executables are locally available.
There is not yet complete proof of tiny-to-large-to-tiny resize, all focus
and keymap transitions, exceptional-unwind termios/cursor restoration,
slow-command double-Enter, and repeated bounded worker shutdown at the
accepted final revision. No skipped scenario is marked passed.

## Cross-contract full-app matrix

| Contract | Application/evidence | Residual |
| --- | --- | --- |
| DSL resolution and macro authoring | root FiveAM / Game of Life and extended PTY (9/9) | Re-run when concurrent DSL/macro revisions settle |
| `cl-events`/`cl-state` async state and worker lifecycle | standalone subsystem checks / root tests | live repeat-shutdown and exception paths still need coverage |
| `cl-inputs` decoding/focus/keymap | Game of Life PTY, Wi-Fi terminal fixture | startup focus and slow double-Enter not yet independently verified |
| `cl-styles` cascade/render geometry | standalone tests / tmux geometry | bottom row and neon restoration failures prevent acceptance |
| Full app terminal ownership | tmux scrollback sample, bottom-row and urxvt suites | two failing scenarios and missing native screenshot proof |

## Gap ledger and boundaries

| Severity | Contract / reproduction | Repair or next proof |
| --- | --- | --- |
| High, repaired locally | Old `scripts/coverage.lisp` omitted 0%-covered files and averaged file percentages | Primary ASDF inventory, weighted SB-COVER expression gate; 10 negative tests |
| High, unresolved | `python3 tests/e2e/test-bottom-row.py` fails positioning on both Escape and Return | Runtime-owning successor: reproduce from captured tmux frames, fix narrowly if the assertion reflects the supported contract |
| High, unresolved | `python3 tests/e2e/test-neon-terminal-restoration.py` expects 24 scroll-up operations, observes 0 | Runtime-owning successor: verify expectation against current terminal ownership contract, regression then smallest fix |
| Medium, proof blocked | `python3 tests/e2e/test-native-urxvt.py` screenshot timeout/error on private Xvfb | Diagnose X/`import` capability and rerun with real framebuffer proof; do not claim live success |
| High, pending | Other workers' DSL/macro/library revisions unaccepted and hosted CI absent | Re-run impacted matrix at accepted exact revisions and obtain independent OCP review |

## Badge and CI contract

The badge in `README.org` is a static visualisation of the above explicitly
dated local measurement; it is **not** a falsely advertised live CI
endpoint. The workflow uploads the per-file report and CSV even on failure
through `actions/upload-artifact@v4`. The existing workflow remains the sole
coverage infrastructure; no public deployment job or branch write permission
has been added. A public dynamic endpoint should only be installed after
trusted successful default-branch verification, with minimum permissions.

## Operator disposition

Implementation and focused regression checks are useful but **overall
acceptance remains unmet**. Do not promote, publish or mark independent
review approved until unresolved terminal evidence and final-revision rerun
have been addressed.
