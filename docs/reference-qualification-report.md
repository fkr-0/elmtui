# ElmTUI API reference qualification — 2026-10-09

## Verdict

**Structure and publication: PASS. Public-docstring coverage: BLOCKED.**

The reference was regenerated from live CLPM/SBCL-exported metadata, independently cross-checked against the running Lisp image, and built into the MkDocs site. All recorded structure checks passed. This does **not** mean every docstring is accurate, the whole library is release-qualified, or the documentation-completeness gate is green.

## Evidence

| Gate | Result | Evidence |
|---|---|---|
| Lisp reference generator | PASS | `scripts/build-api-docs.sh`; compiled without new style warnings; writes `docs/api/generated/api.md` and `api.html` |
| Actual public symbol identities | PASS | `python3 scripts/qualify-api-reference.py --structure-only`; 1,822 live, deduplicated exported bindings match the 1,822 documented entries in order |
| Qualified package names | PASS | Each generated `PACKAGE:SYMBOL` is explicitly checked with Common Lisp `FIND-SYMBOL` for `:EXTERNAL` in the named package; previous home-package `::` labeling corrected |
| Markdown/HTML equivalence | PASS | 1,822 HTML sections and public headings; each entry's escaped HTML documentation matches its Markdown documentation block; 870 missing-documentation markers agree |
| Markdown safety | PASS | Documentation strings are fenced using an adaptive-length fence so embedded Markdown headings cannot create counterfeit API entries |
| Rebuild determinism | PASS | Two consecutive live builds produced byte-identical `api.md` and `api.html` (compared with `cmp`) |
| Corruption detection | PASS | Replacing one legitimate heading with a nonexistent symbol in a temporary copy caused the verifier to reject it; four reusable negative/positive parser tests also pass via tests/reference/test_qualifier.py |
| Site integrity | PASS | `scripts/prepare-site.py`, strict MkDocs build and `actionlint` passed; generated reference is linked in the site reference navigation; rendered page exists |
| Generated artifact source disclosure | PASS, narrow | Searched generated Markdown/HTML for local home-directory paths, token-style secrets and private-key banners; no hits. This is not a comprehensive sensitive-data audit |
| Existing docstring-debt ratchet | **FAIL (expected, release blocker)** | `scripts/check-docstrings.sh`: 1,819 public bindings loaded without the documentation generator, 870 missing, coverage 52.2%, maximum allowed debt 782. Exit 1 |
| Full content completeness | **FAIL (expected)** | `python3 scripts/qualify-api-reference.py` without `--structure-only` rejects all missing binding descriptions. Generated docs report 952 of 1,822 documented (52.3%) |

The generated reference counts three exported symbols in `ELMTUI.DOCS` because that system is loaded during generation; the legacy debt check only loads `ELMTUI` and four supporting libraries, hence 1,822 versus 1,819 without a conflict in missing counts.

## Live missing metadata by package family

| Family | Exported live bindings | No docstring |
|---|---:|---:|
| ElmTUI | 1,166 | 504 |
| cl-events | 191 | 131 |
| cl-inputs | 196 | 79 |
| cl-state | 132 | 60 |
| cl-styles | 137 | 96 |
| **Total** | **1,822** | **870** |

The existing docstring debt ratchet must improve by at least **88** without raising the threshold to become green; fully qualified content means all missing descriptions have been filled and semantically reviewed. Counts reflect this checkout only and can change with legitimate exported-symbol changes.

## Relevant commands

    scripts/build-api-docs.sh
    python3 scripts/qualify-api-reference.py --structure-only
    python3 scripts/qualify-api-reference.py
    scripts/check-docstrings.sh
    python3 scripts/prepare-site.py
    python3 -m mkdocs build --strict
    actionlint -color=false .github/workflows/*.yml

The first and second commands succeed; the third and fourth currently fail on explicit documentation debt. CI now regenerates and checks the structure before enforcing the debt gate; the Pages workflow builds from the checked-in generated reference and triggers on changes to that snapshot.

## Further release qualifications

1. Document at least the missing 88 public bindings required to meet the existing debt ratchet, prioritizing interactive terminal lifecycle, rendering, input, app construction and state APIs. Prefer reducing missing descriptions toward zero; do not add empty boilerplate strings to game the count.
2. Semantically review existing docstrings and all example calls rather than concluding text is correct merely because the symbol exists and renders. Particular emphasis: `DEFAPPLICATION`, `RUN-APPLICATION`, state patches, subscriptions and cursor/TTY restoration.
3. Run the final full FiveAM and PTY matrix against a pinned clean checkout after concurrent Workbench/tmux changes are integrated. A successful reference build does not substitute for passing application tests.
4. Verify the public GitHub Pages deployment and asset URLs after publication. A local MkDocs build is not a deployment attestation.
5. Consider splitting the currently large single-page generated reference by package once coverage is improved, while retaining machine-checkable exported-symbol parity.
