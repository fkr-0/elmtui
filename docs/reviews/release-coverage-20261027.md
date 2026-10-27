# ElmTUI E4 — release source coverage and quality, 2026-10-27

**Canonical OCP task:** `ELMTUI-CLPM-E4-COVERAGE-QUALITY-20261027-120EB8`

**Dispatch:** `8896af22f6c54237aef1ecd76c0c2b5c`

**Workspace:** `/home/user/code/lisp/elmtui.lisp`; **baseline checkout HEAD:** `a6be0e79e7a954eb77b4b299038984ad7170cb41`
**Scope:** new `tests/coverage-*-20261027*`, `scripts/coverage.lisp`, this report. No release/tag/push/deploy.

## Observable result and precise provenance

| Metric (primary SB-COVER forms, not README/docstrings) | Before E4 | After E4 | E4 delta |
| --- | ---: | ---: | ---: |
| Covered forms | 22,401 | 22,492 | **+91** |
| Total forms (ASDF primary source inventory) | 40,199 | 40,199 | 0 |
| Weighted coverage | 55.73% | 55.95% | **+0.22 pp** |
| Primary source files | 88 | 88 | 0 |
| Explicit gate minimum | 55.00% | 55.00% | **unchanged** |
| Instrumented run FiveAM checks | 9,972 | 10,016 | **+44** |
| Fail / optional live tmux skips | 0 / 6 | 0 / 6 | 0 / 0 |

The **frozen October 26 candidate** had 22,318/40,199 (55.52%). The current dirty checkout had *already* risen to 22,401/40,199 (55.73%) before E4 touched files. The earlier +83 forms **are not credited to E4**. Current E4 gained +91 additional runtime-reached forms; no denominator reduction, source-exclusion change, or threshold relaxation was used.

Primary inventory is exported from `asdf:find-system "elmtui"` to `coverage/primary-sources.txt`, compared against `docs/assets/coverage-primary-sources.txt`, and joined with SB-COVER per-file form counts by `scripts/coverage-gate.py`. The script fails on missing files, duplicate names, malformed counts and denominator/inventory drift. Source hashes are checked before/after the run; coverage FASLs have a fresh private ASDF output cache, separated from ordinary test compilation. Test and dependency systems are loaded after disabling source instrumentation. **An 88-file summary does not measure test-file coverage**.

The 12 zero-hit primary files are still in the denominator:
- `src/api.lisp` (0/3), `src/core/condition-docs.lisp` (0/190),
  `src/core/event-types.lisp` (0/265), `src/core/globals.lisp` (0/32),
  `src/core/logging.lisp` (0/61), `src/core/public-api-docstrings.lisp` (0/4769),
  `src/platform/backend/urxvt/urxvt.lisp` (0/25), `src/state/state.lisp` (0/2),
  `src/style/presets.lisp` (0/76), `src/ui/widgets/grid-container.lisp` (0/2),
  `src/view/api.lisp` (0/52), `src/view/styled.lisp` (0/12).

**Interpretation:** the 4,769 unhit forms in public-api-docstrings are primary-source SB-COVER instrumentation, not README quality or a separate documentation metric. Some zero-hit sources are declarative/compatibility-only. They must not be silently dropped solely to improve a percentage. Investigate whether each has executable production paths before setting per-file minimums.

## E4 behavior-driven regressions and CI wiring

File: `tests/coverage-release-quality-20261027.lisp`. Six new FiveAM cases, 44 assertions:
1. Atomic nested state patch batches, update/prepend/append/delete and unchanged earlier snapshot.
2. Invalid patch after a valid change throws without altering original state.
3. Legacy transaction failure returns original state and no committed transaction; expected warning is intercepted *inside the assertion* (not globally masked).
4. Nested updater / merge / full forward and reverse state diffs.
5. Whole-view replacement plus dynamic view context restoration after nested scope and error.
6. Terminal-cell and grapheme-aware slicing, wide-glyph clipping and tab-stop width.

First falsification run (as designed) failed **two new test expectations**, not production code: reversed state diffs report all changed fields, not merely the removed key; a tab after the first column followed by a character occupies nine display columns. Corrected the expectations after reviewing actual behavior. First run exit **1**, 10,015 checks, 2 failures; final run exit **0**, 10,016 checks, no failures.

The tests have an explicit **fatal load** in `scripts/coverage.lisp` after `elmtui-tests` is loaded and SB-COVER instrumentation disabled. CI (`.github/workflows/ci.yml`) invokes `scripts/run-coverage-warning-clean.sh`, which invokes this script and enforces failure status and the 55% gate. A missing E4 source file or load error therefore fails the CI coverage job rather than being skipped. This hook is the sole E4 addition to the previously dirty coverage script; E4 did not commit another agent's pre-existing changes.

**Important ASDF limitation:** `elmtui-tests.asd` is shared, already dirty, and not in the E4 governed write scope. Therefore `scripts/run-tests-warning-clean.sh` and `asdf:test-system "elmtui-tests"` still perform **9,972** rather than **10,016** checks. The E4 regressions *are run by CI coverage* but are **not independently present in the plain ASDF/root test run**. This is a known integration gap, not a claim of complete root-suite wiring. Coordination note `469d15b1-2633-40aa-96d7-0f86af4da234` requests governed addition of the new test file to the root ASDF components after owner review. No shared CI/ASDF edits have been made in E4.

The root ASDF test-op wiring itself is verified: `elmtui-tests.asd` invokes `elmtui.tests:run-all-elmtui-tests` and errors on a false result. `tests/test_asdf_acceptance.py` tests that injected FiveAM failure changes process status and that the declared default acceptance suites execute. All two cases passed. CI also invokes 15 negative coverage-gate cases and one badge/provenance negative test, all passed.

## Exact local verification

| Command | Exit | Evidence |
| --- | ---: | --- |
| `ELMTUI_TEST_RUN_ID=e4-pre-20261027 scripts/run-coverage-warning-clean.sh` | 0 | `test-output/coverage-e4-pre-20261027.{stdout,stderr}.log` |
| `ELMTUI_TEST_RUN_ID=e4-post-first-20261027 scripts/run-coverage-warning-clean.sh` | 1 | Two falsified assertions, `test-output/coverage-e4-post-first-20261027.{stdout,stderr}.log` |
| `ELMTUI_TEST_RUN_ID=e4-post-fixed-20261027 scripts/run-coverage-warning-clean.sh` | **0** | `test-output/coverage-e4-post-fixed-20261027.{stdout,stderr}.log`; `coverage/coverage-summary.json` |
| `ELMTUI_TEST_RUN_ID=e4-root-20261027 scripts/run-tests-warning-clean.sh` | **0** | `test-output/warning-clean-e4-root-20261027.{stdout,stderr}.log`: 9,966 pass/6 opt-in skips |
| `python3 -m unittest discover -s tests -p 'test_asdf_acceptance.py' -v` | 0 | 2/2 |
| `python3 -m unittest discover -s tests -p 'test_coverage_gate.py' -v` | 0 | 15/15 |
| `python3 -m unittest discover -s tests -p 'test_coverage_badge.py' -v` | 0 | 1/1 |
| `git diff --check -- scripts/coverage.lisp tests/coverage-release-quality-20261027.lisp` | 0 | No whitespace errors |

Both successful runners finished without compiler-warning markers. The **same six explicitly named live tmux skips** remain opt-in, conditional on `ELMTUI_RUN_TMUX_INTEGRATION=1`; their presence is counted and visible rather than silently excluded. The root suite's commented-out dormant test components (`app-tests`, `ui-widgets-tests`, `state-extended-tests`) are still outside the ASDF system and have not been represented as passing.

## Remaining risk / release judgement

Coverage is **above the existing 55% floor** and now has stronger behavioral checks, but it is not independent proof of release readiness. High-risk uncovered/low-coverage files in this run include `src/platform/driver.lisp` 639/1643 (**38.89%**), `src/state/model.lisp` (transaction/observer complexity), `src/core/loop.lisp` (shutdown/concurrency), `src/view/layout/core.lisp` (dispatch), `src/ui/widgets/button.lisp` 1/47, `src/core/topics.lisp` 17/182 and `src/platform/input.lisp` 57/178. Zero-hit URxvt and conditional real PTY/terminal behavior need supported real-environment qualification; **six live tmux tests are still skipped**. No hosted CI execution, device matrix, full release-check, tag, push or deployment is asserted here.

Next governed scope, **not an automatic replacement or duplicate**: register the E4 behavioral file in the shared `elmtui-tests.asd` ASDF components with owner review; prove root warning-clean and coverage both execute the same six cases, with 0 unexpected warnings and explicit failure propagation. Then improve driver/event-loop/layout branch coverage based on high-risk miss maps, subject to workbench/E2 ownership. Keep the frozen denominator and 55% threshold unchanged.
