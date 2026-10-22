# ElmTUI standalone CL package release audit — 2026-10-22

## Scope and source of truth

Audited the four independent Git repositories under `cl-events/`,
`cl-inputs/`, `cl-styles/`, and `cl-state/`, their GitHub `fkr-0/*`
remotes, ASDF/CLPM entry points, tests, GitHub Actions, measured SB-COVER
coverage, README badges, changelogs, and `bridge.yml` workflows.
Treat the GitHub `main` branches and the in-tree submodule pins as the
release source of truth; sibling checkouts containing uncommitted changes
are not safe to reset or copy over.

## Evidence

| Package | ASDF/CLPM | Local test results | Instrumented coverage | GitHub CI at baseline | GitHub revision after audit |
|---|---|---|---|---|---|
| cl-events | standalone systems and locked CLPM | 1,675 checks, 0 failures | **86.08%** (1,119/1,300 LCOV executable lines; gate 85%) | passed at d94f55f | 1664d9a |
| cl-inputs | core and separately testable optional events adapter | 921 pass, 1 no-controlling-TTY skip, 0 failures | **52.66%** (2,234/4,242 LCOV owned lines; gate 52%) | passed at b9d0cbec | 6a9b184 |
| cl-styles | standalone systems and locked CLPM | 218 checks, 0 failures | **60.42%** (774/1,281 LCOV owned lines; new gate 60%) | failed on old clpm setup step; corrected workflow passed | 64000cb |
| cl-state | standalone systems and locked CLPM | ASDF/FiveAM tests pass | **78.50%** (2,585/3,293 SB-COVER expressions; new gate 78%) | no prior main-branch workflow | 8b29300 |

These metrics are **not directly comparable**: cl-state gates instrumented
expressions; the other three gate source-line LCOV. Percentages are actual
SBCL 2.6.2 local measurements, not fixture percentages or CI badge claims.

## Reconciliation performed

- `cl-events`: fast-forwarded the nested checkout to its GitHub main,
  which carries CI, real SB-COVER gate (85%), verified badge publishing,
  release metadata, and expanded concurrency/E2E tests. Added a child
  `bridge.yml` with `agent_workflow.project.id: cl-events`, fixing
  inheritance of the parent's ElmTUI workflow.
- `cl-styles`: fixed missing compiler line coverage vectors by enabling
  SB-COVER coverage logging and data level 3. Replaced the failing
  redundant CLPM job with one verified pinned SBCL 2.6.2 / CLPM 0.4.1
  verification path, with regression-tested fail-closed LCOV gate,
  verified coverage-data badge, and CI artifacts. Removed GitHub Pages
  deployment because the repository's Pages configuration step failed;
  Pages is **not** needed for the badge endpoint. Added README badges,
  generated-artifact ignores, changelog, and OCP project manifest.
- `cl-state`: installed a standalone CI workflow, fail-closed
  expression-coverage gate and regression tests from its separately
  maintained release-candidate checkout; verified on the **newer**
  GitHub-current source tree, not by resetting it to that old checkout.
  Added status badges, changelog, ignore rules, and OCP project manifest.
- `cl-inputs`: preserved the pending device/PTY/input-loop changes;
  migrated CI to the same verified SBCL 2.6.2 / CLPM 0.4.1 binary setup
  while retaining tmux dependency and SBCL package-compatibility setup.
  Ratcheted the gate from 49% to 52% against the measured 52.66% baseline.
- Updated the parent ElmTUI Git submodule pins to the reviewed commits,
  using path-specific local commits. Other dirty parent files are preserved.

## Verified remote CI results after reconciliation

All current `main` GitHub Actions completed successfully after the final
commits (verified 2026-10-22 UTC):

| Repository | Green GitHub commit | Notes |
|---|---|---|
| `fkr-0/cl-events` | `1664d9a` | 85% measured runtime-line gate |
| `fkr-0/cl-inputs` | `6a9b184` | 52% runtime-line ratchet; one justified local TTY skip |
| `fkr-0/cl-styles` | `64000cb` | 60% measured-line ratchet; CI artifact + coverage-data badge, no Pages dependency |
| `fkr-0/cl-state` | `8b29300` | 78% measured-expression ratchet |

All package repos have been non-force pushed to their own GitHub `main`.
The parent ElmTUI checkout contains **local-only** guarded submodule-pin
commits, intentionally not pushed alongside unrelated in-progress work.

## Next test investment, from actual uncovered modules

| Package | Highest-return missing cases | Measured coverage evidence |
|---|---|---|
| cl-inputs | TTY raw-mode/termios/EOF restoration, URxvt escape handling, terminal failure paths | `tty.lisp` 54/437; `urxvt.lisp` 115/457 lines |
| cl-styles | Property validation/normalization, stylesheet variable/inheritance paths, generic protocol integration | `properties.lisp` 135/308; `sheet.lisp` 38/85; distinguish pure declarations in packages/protocols before making denominator policy decisions |
| cl-state | Persistent patch sharing/rollback adversarial cases, schema error branches | `persistent.lisp` 313/470; `schema.lisp` 212/347 expressions |

These are gaps in actual executed source, not simply missing test filenames.
Raise test coverage with behavior-driven assertions and regressions, not by
lowering current CI floors or removing production files from the denominator.

## Remaining release-blocking work

1. **Coverage depth**: cl-inputs (52.66%) and cl-styles (60.42%) are
   materially under-covered. First extend adversarial decoder/terminal
   and selector/properties/sheet tests, and ratchet gates based on actual
   measured improvements; target at least 85%, with no denominator tricks.
   cl-state measures 78.50%; target 85% with additional transaction/
   observer/validation regression fixtures.
2. **Continued CI qualification**: all four published `main` builds now pass.
   Keep them branch-protected and investigate future non-green badge/test runs
   before promoting a new source release.
3. **Legacy task identity**: cl-inputs has OCP tasks under both
   `cl-input` and `cl-inputs`. Do not casually rename the live
   `agent_workflow.project.id: cl-input` until existing durable OCP
   identities are explicitly migrated or an alias is supported.
4. **Version/release lineage**: all four use independent candidate
   0.2.0 ASDF version metadata and changelogs. cl-events has v0.2.0;
   cl-inputs preserves historical `v0.2.0` plus
   `cl-inputs-v0.2.0` lineage, which should not be rewritten. cl-styles
   and cl-state have no qualified GitHub 0.2.0 release tag; do not claim
   registry publication or invent a tag.
5. **Toolchain convergence**: all four now have ASDF tests, a CLPM lockfile,
   GitHub Actions, standalone ws-bridge workflow identity, and the same
   SHA-verified pinned SBCL 2.6.2 / CLPM 0.4.1 CI binaries (cl-inputs
   additionally installs tmux and its required compatibility startup).
   Still qualify each new GitHub run; a verified download is not itself
   proof of package integration correctness.
6. **Other working copies**: `/home/user/code/lisp/cl-events` and
   `/home/user/code/lisp/cl-state` contain older or different branches
   with uncommitted research/refinement work. Preserve them. Do not
   hard-reset or force-push over their state.
7. **Parent publication**: parent ElmTUI Git submodule pin commits were
   left local because its checkout has many unrelated in-progress changes
   and prior unpushed commits. Publish via the normal coordinated
   ElmTUI release lane, not with an indiscriminate parent push.

## Suggested release contract

For every package: `asdf:test-system` must fail on test failure;
`bridge.yml` must select that package's own OCP identity; a full
main-branch GitHub Action must pass with pinned, verified dependencies;
the coverage gate must compile production sources under SB-COVER, inventory
all owned sources, reject missing/uninstrumented records, and publish an
endpoint **only on a passing gate**; the README should link live CI and
measured coverage rather than static numbers; changelog and ASDF versions
must agree with the intended **source** release; GitHub tags are only cut
after the release criteria pass. Do not conflate registry publication
with the presence of a public Git repository.
