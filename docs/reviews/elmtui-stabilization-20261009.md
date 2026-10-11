# ElmTUI stabilization and release evidence — 2026-10-09

## Execution identity and publication boundary

- Release unit: ElmTUI main repository and pinned local support-library submodules.
- Baseline before these targeted repairs: active shared worktree with tmux-hover contract regressions, interactive logging leaks, uncommitted examples and PTY evidence.
- Candidate HEAD before writing this note: `fa28caedd269b916e2d5fbcfde4dfd2a2d3b8dc7`.
- No release tag, Git push, Pages deployment, package publication or uploaded artifact was performed by this pass.
- The historical `v0.2.0` local tag and proposed `0.1.0` public release require an explicit version-history decision.

## Closed engineering issues

1. **tmux hover and cursor inspector:** Restored the legacy tmux-hover application initializer, update/view, and ASDF-visible app config while preserving the unified inspector as the default launcher. The inspector now paints to an alternate screen to avoid consuming the shell's tmux history. The existing 80×24 and 120×40 resize/scrollback tests passed in isolated real tmux.
2. **ANSI capture:** Replaced a runtime `ignore-errors` around SGR parsing with a typed `handler-case`, routing malformed-style diagnostics to Log4CL and preventing one bad SGR from aborting a valid capture.
3. **Diagnostic output:** Default examples-cli logging removes root console appenders. `ELMTUI_VERBOSE_LOGS` alone does not redirect diagnostics into the TTY; `ELMTUI_LOG_FILE` opts into a file sink. The earlier key/view hot-path INFO log removals remain in place.
4. **Input and test isolation:** Bracketed-paste events remain literal messages. Fixed the typed focus/keymaps unit test to use a core `cl-state` fixture rather than loading all examples.
5. **Committed worktree groups:** Async-weather app with offline PTY tests; Workbench W6 runnable case oracles; tmux capture, restoration and styled-underlay tests; source/website documentation and architecture proposals; local `cl-inputs` and `cl-state` commits pinned in the main repository. PTY run artifacts and Python bytecode caches are excluded from tracked sources.

## Verified gate evidence

| Gate | Command | Observed verdict |
| --- | --- | --- |
| Full root FiveAM | `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load scripts/run-tests-clpm.lisp` | 4,707 checks: 4,701 pass, 6 intentional live-tmux skips, 0 fail; exit 0 |
| Workbench PTY startup | `python3 tests/workbench/pty-workbench.py` | PASS at 80×24, 120×40 and 160×50 |
| Workbench W6 application matrix | `python3 tests/workbench/validation/runner.py` | Application cases PASS=30 FAIL=0 NOT_RUN=0; separate dependency oracle still absent |
| Tmux inspector | `python3 tests/e2e/example-overhaul-tmux.py -v` | 6 tests pass including repeated launches, interrupt, resize/history, shell restoration |
| Styled tmux underlay | `python3 tests/e2e/example-overhaul-tmux-backend-pty.py -v` | 1 pass |
| Async weather | `python3 tests/e2e/example-overhaul-async-weather.py -v` | 4 pass, optional live-network smoke skipped |
| Game of Life | `python3 tests/e2e/game-of-life-pty.py -v` | 2 pass (grid evolution and PTY pause/step/reset/quit/restore) |
| Neon Life and Glider | `python3 tests/e2e/neon-life-glider-pty.py -v` | 4 pass including original app launchers |
| CLI diagnostic routing | `python3 tests/e2e/cli-logging-isolation.py -v` | 3 pass (default, verbose-only, verbose-to-file) |
| Key hot-path logs | `python3 tests/e2e/key-logging-check.py -v` | 1 pass across four maintained apps |
| cl-inputs raw-mode teardown | `python3 cl-inputs/tests/tty-termios-regression.py` | PASS exact flags after repeated source close |
| Static runner contracts | `python3 tests/test_runner_contracts.py` | All 15 contract checks pass after typed core fixture correction |
| API reference | `python3 scripts/qualify-api-reference.py --structure-only` | 1,822 live public entries and HTML/Markdown structural parity pass |
| Website and workflows | `python3 scripts/prepare-site.py`, `python -m mkdocs build --strict`, `actionlint -color=false .github/workflows/*.yml` | PASS |

## Open / fail-closed gates

- **Tmux slider:** `python3 tests/e2e/example-overhaul-tmux-slider-unit.py` passes 1/1; `python3 tests/e2e/example-overhaul-tmux-slider.py` passes 4/5 and fails `test_real_styled_snapshot_and_70_scrollback_markers` (one observed frame; at least six transitions required). The experimental slider and its tests remain untracked.
- **API documentation coverage:** 952 of 1,822 public bindings described (52.3%); 870 missing. The existing docstring debt threshold is 782. Structure qualification is not sufficient to claim coverage or CI release readiness; do not weaken the threshold.
- **W6 dependency qualification:** The application matrix reports 30 passing cases but explicitly has no independently executable oracle for a dependency-level case.
- **Publication and reproducibility:** The candidate public version, dependencies' public GitHub accessibility, historical `v0.2.0` tag, full MIT provenance and actual Pages HTTPS publication need final review. No publish/push was authorized in this pass.
- **Untracked historical material:** Older architecture TODOs, benchmarks, instrumentation patches, draft task dispatch packets and user screenshots were deliberately not bulk-committed. They should be curated rather than mistaken for release evidence. Generated W6 PTY artifacts stay local.

## Frozen local revision vector at time of evidence

- `cl-events`: `d4399c087fdaae14e1428948c8a0b0ff5059475e`
- `cl-inputs`: `ea45ee1b6a4359380c7112743149bedb33c637e0`
- `cl-state`: `f95baab3be20d3161bbe193766737880d9a00672`
- `cl-styles`: `0ca5efcc665fa2682551f7bf6583ece6a76698c4`

**Qualification verdict:** Runtime/editor/main example stabilization passed for the tested gates. Official release qualification remains blocked by slider completeness, independent W6 oracle, coverage threshold and publication/version decisions.
