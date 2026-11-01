# Coverage R2 — generated badge plumbing and qualification boundary

Canonical task: `ELMTUI-CLPM-08-COVERAGE-REFINE-20261014-R2`
Predecessor: `ELMTUI-CLPM-07-QUALIFICATION-ENHANCE-20261014`
Work packet: `cd7de258-7320-4397-ae3f-9c06d9d71ac1`
Repository HEAD during focused tests: `d29eace7bda867a353e4086551bc0031f4cfc986`.

## Implemented

- `scripts/coverage-gate.py` emits `coverage-summary.json` and `coverage-badge.svg` using validated expression counts; the JSON includes source-file SHA-256 values and the instrumented ASDF inventory SHA-256.
- The 46.0% minimum remains unchanged. There is no fixed expected expression denominator: a reviewed 92-file inventory baseline (`docs/assets/coverage-primary-sources.txt`) guards against unintentionally dropped primary ASDF files; legitimate inventory revisions require intentional baseline review/update.
- The gate removes prior success summaries and badge before checking reports, and will never generate new success outputs for missing/malformed input or below-floor results.
- `run-coverage-warning-clean.sh` invalidates prior summaries before launching SBCL, treats its exit status as authoritative, rejects warning markers, and hashes the primary source tree before and after instrumentation to reject races.
- The README references a locally generated badge file rather than a hardcoded shields.io percentage. The image is absent until a successful local measurement. CI runs focused badge tests and uploads results; it does **not** deploy an endpoint or push a badge.

## Evidence

```text
python3 -m unittest discover -s tests -p 'test_coverage_gate.py' -q   => exit 0; 15/15
python3 -m unittest discover -s tests -p 'test_coverage_badge.py' -q  => exit 0; 1/1
python3 -m py_compile scripts/coverage-gate.py                     => exit 0
bash -n scripts/run-coverage-warning-clean.sh                       => exit 0
git diff --check                                                    => exit 0
```

Historical predecessor (not remeasured at R2 source hashes): 18,302/39,712 = 46.09%, 92 primary files; root 8,397 pass, six skips, zero failures. The known two bottom-row ROW-29 failures, neon restoration failure, native urxvt screenshot errors, and a direct cyclic DSL type CAR timeout remain runtime-lane concerns. No independent review, trusted hosted CI pass, public badge availability or combined current-source qualification is established.

## Single executable residual-work ledger

1. **High — final-source verification:** Once DSL, macros, terminal and library successor revisions are stable and reviewed, run `scripts/run-coverage-warning-clean.sh`, root FiveAM, library boundary bundles, facade/doc/reference checks and available PTY/tmux/urxvt tests at exact source hashes. Capture exit codes, skips and regressions. Do not cherry-pick concurrent measurement percentages.
2. **High — independently reviewed disposition:** Use the governed read-only review packet. Address reviewer findings within this coverage scope and obtain explicit verdict; do not self-approve.
3. **Medium — hosted publication:** The workflow remains configuration-only until a trusted default-branch workflow passes and badge URL is independently accessible. Public deployment is not authorized by this task.

The existing `docs/release-history-purge.md` deletion belongs to another lane and was preserved.
