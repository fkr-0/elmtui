# Release repairs and developer utility review — 2026-10-26

The repairs following `release-readiness-20261026.md` passed the expanded local
release gate in an isolated, clean candidate. This is local qualification,
not publication or proof that unpublished library commits are remotely reachable.

## Implemented

- Fixed component update-handler inheritance, quoted syntax rewriting and
  explicit NIL defaults; retained legacy ignored loop keyword compatibility.
- Fixed memo cache ownership so discarded wrappers release cached values.
- Made example widgets and developer tooling optional ASDF systems, with
  explicit default-test dependencies and a regenerated CLPM lock.
- Replaced workbench character-grid painting with native ElmTUI pane/text DSL.
  Added rendered Unicode/style, tab/newline geometry, cursor and completion
  placement regressions. Workbench does not own a parallel terminal renderer.
- Fixed root ASDF false-success behavior and added a real failing-test injection
  check. Default CI and release gates execute the new acceptance suites and
  configure the workbench launcher instead of silently skipping app tests.
- Enhanced optional developer diagnostics: Unicode buffer dumps, preserved
  original errors/restarts, bounded cyclic tree inspection, native view previews,
  timestamped process counters without arbitrary event payloads.
- Enhanced benchmarks: CPU/time/context metadata, explicit clock-resolution
  validity, comparison validation, data-only baseline input and correct even
  medians. Moved benchmark tests out of runtime sources.

Usage, API descriptions and retained legacy-tool inventory:
[`docs/developer-tools.md`](../developer-tools.md).

## Independent review

A separate reviewer found three additional defects: root ASDF false success,
tab/newline clustering, and depth-limit bypass of the tree node budget. All
were reproduced with failing checks, repaired and independently rechecked.
The reviewer approved the repaired source, explicitly excluding publication.

Evidence: `/tmp/elmtui-reviewer-asdf-recheck.log`,
`/tmp/elmtui-reviewer-dev-recheck.log`,
`/tmp/elmtui-reviewer-geometry-recheck.log`.

## Frozen local candidate

Candidate: `/tmp/elmtui-release-candidate-20261026-kj0tin73/repo`

| Repository | Candidate commit |
|---|---|
| ElmTUI | `1f66ad82609764dabc5fc249f2d0572efaa7b7a0` |
| cl-events | `57f1bc8504d61f9b1c49a41bed96eae2b736bd47` |
| cl-inputs | `67e8546856bc6e30ed07e45e8d9d413c046c348b` |
| cl-state | `8f116e7191a545719b9d4500f0d87880861e776e` |
| cl-styles | `58f287d7f6a116f3cab2ad98ae0443dbd3cb3716` |

This candidate snapshots existing tracked library work without committing,
resetting or repinning the shared checkout. Its library snapshots and root
commit are local only. The shared source branch remains dirty at `a6be0e7`.
Receipt: `test-output/release-candidate-20261026-pre-coverage.json`.

`scripts/release-check.sh` in this exact candidate exited **0**. Evidence:
`/tmp/elmtui-candidate-release-check.log`.

| Gate | Observed result |
|---|---|
| Independent library bundles and root integration | PASS |
| Root warning-clean suite | 9,525 checks: 9,519 pass, 0 fail, 6 opt-in tmux skips |
| Developer utility tests | 30 diagnostics + 24 benchmark checks, no skips |
| ASDF acceptance/failure propagation | 2/2 PASS, including injected FiveAM failure |
| Workbench black-box/native presentation | 26/26 PASS, no skips |
| Workbench raw PTY smoke | 80x24, 120x40, 160x50 PASS |
| Mandatory-source SB-COVER expression coverage | 19,101/40,060, **47.68%**, 88 sources |
| Packaged executable private-PTY smoke | PASS |
| API reference qualification | 1,822 bindings, 1,644 documented, 178 missing |

No tag, push, deployment or publication occurred. Formal release publication
still needs the intended candidate changes adopted/pinned and made reachable
through the intended release remotes. Local tests do not establish native
terminal/font compatibility beyond the named PTY cases.

## Follow-up requested during handoff

The user requested a further coverage improvement after the candidate above
passed. Treat 47.68% as the pre-improvement baseline; later test changes require
a fresh measured result and updated qualification rather than reusing this
candidate's evidence.
