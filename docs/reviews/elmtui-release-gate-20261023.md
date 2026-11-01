# ElmTUI release gate — 2026-10-23

**Canonical OCP task:** `ELMTUI-CLPM-RELEASE-GATE-20261023-FE3161` (priority 95).  
**Repository:** `/home/user/code/lisp/elmtui.lisp`; live shared checkout, **not** a frozen release tree.  
**Observed superproject HEAD after concurrent work:** `018b8d3d1162b530ce6452a56d210008bf15ec66`.  
**Disposition:** Loader defect fixed, full warning-clean suite green, Ctrl+S and packaged-binary real-PTY smoke green; **release remains BLOCKED** on frozen gitlinks, complete multi-example terminal qualification, independent code review, and publication state.

## Root cause and scope

The `eval-when` load-time dependencies in `examples/tmux-cursor-inspector.lisp` resolved `cursor-inspector.lisp` and `tmux-slider.lisp` relative to `*load-truename*` or `*compile-file-truename*`. Under CLPM/ASDF, those variables can name `scripts/run-tests-clpm.lisp` or a FASL-cache location rather than the example source directory. The loader then attempted nonexistent `scripts/tmux-slider.lisp` or a FASL-cache sibling; the error cascaded into the smoke suite. Corrected **only** that dependency loader to use `asdf:system-relative-pathname :elmtui-examples` and the actual maintained `examples/*.lisp` paths. It retains the existing package-present guards. No fake compatibility source, test suppression, or forbidden source API edit was added.

A new isolated child-process regression in `tests/tmux-examples-smoke-tests.lisp` compiles the inspector with an intentionally unrelated load-context path, checks that it finds the slider package, then loads the generated FASL and checks the exported inspector entry point. No test skip.

The default examples inventory had three post-fix assertions failing because `tmux-cursor-inspector` and new optional `repl` were not classified/documented. Those files were exclusively claimed by another worker and were reconciled by that worker, not this task.

## Evidence ledger

These commands are executed from the repository root unless stated otherwise. Exit status is the actual tool result; counts are contemporaneous and live checkout changed between invocations.

| Gate / exact command | Exit | Observed result |
|---|---:|---|
| Baseline `scripts/run-tests-warning-clean.sh` (before loader fix) | 1 | `8,561` checks: `8,527` pass, `28` fail, `6` skip. Failed file opens under `scripts/tmux-slider.lisp` and FASL cache. `test-output/warning-clean-20261023-033242.{stdout,stderr}.log` |
| First `scripts/run-tests-warning-clean.sh` (loader fixed, inventory pending) | 1 | `8,893` checks: `8,884` pass, `3` inventory fails, `6` skip. `test-output/warning-clean-20261023-033503.{stdout,stderr}.log` |
| Final `scripts/run-tests-warning-clean.sh` after mini-editor normalization | **0** | **8,966 checks: 8,960 pass, 0 fail, 6 skip**. `test-output/warning-clean-20261023-035208.{stdout,stderr}.log` |
| `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:load-system "elmtui-tests")' --eval '(fiveam:run! (quote elmtui.tests.tmux-examples-smoke:tmux-examples-smoke-tests))'` | **0** | 37/37 pass, includes new isolated FASL-loader regression. `test-output/release-loader-focused.log` |
| `python3 tests/e2e/example-overhaul-tmux-slider-unit.py` | **0** | 1/1 pass |
| `python3 tests/workbench/independent/test_native_repl_presentation.py -v` | **0** | 4/4 pass: native layout, actual REPL eval, completion, inspector, private-tmux restoration |
| `python3 tests/workbench/pty-workbench.py` | **0** | PTY 80x24, 120x40, 160x50 PASS; no alternate-screen transitions, Ctrl+D exit, termios restored |
| `python3 tests/e2e/test-neon-terminal-restoration.py` | **0** | 2/2 private-tmux restoration cases pass |
| `python3 tests/e2e/extended-examples-pty.py ExtendedExamplesPTY.test_mini_editor_unsaved_dialog ExtendedExamplesPTY.test_mini_editor_ctrl_q_prompts_when_dirty -v` | **0** | 2/2; Escape and Ctrl+Q both show guarded dirty dialog |
| `python3 tests/e2e/release-gate-mini-editor-pty.py` | **0** | **1/1 PASS (latest run)**: requires `-ixon` on pane tty, Ctrl+S writes expected file, dirty marker clears, Ctrl+Q exits, exact termios and cursor restore. Earlier trial exited 1 due Ctrl+S timeout; next trial saved successfully but the generic harness failed on three known upstream Log4CL redefinition warnings. Dedicated gate now only allows those exact three warning lines, rejects every other diagnostic. Earlier red evidence: `/tmp/elmtui-release-mini-editor-eitwsgl9/`. |
| `./scripts/examples.sh build minimal-app /tmp/elmtui-release-minimal-bin --backend fake` | **0** | Packaged executable built (17 MB); `test-output/release-packager-build.log` |
| `timeout 15 /tmp/elmtui-release-minimal-bin` with redirected stdio | 1 | No controlling TTY; invalid negative environment for a terminal app, **not** a functional PTY smoke |
| `python3 tests/e2e/release-gate-packager-pty.py` | **0** | Fresh package build and real isolated tmux PTY startup with visible `Hello slurp` pass |
| `scripts/check-docstrings.sh` | **0** | 1,818 unique public symbols, 178 without docstrings, 90.2% coverage |
| `git diff --check` | **0** | No whitespace errors on observed dirty diff |
| `scripts/release-check.sh` | **1** | Blocked early: `cl-events` gitlink `1664d9a...` != checked-out `30d82c0...`. Some other `cl-*` checkout revisions differ too. `test-output/release-gate-20261023.log` |
| `git clone --quiet --recurse-submodules https://github.com/fkr-0/elmtui.git <temp>/repo` | **0** | Actual public remote HEAD `b9368770ef6fccc05ed6a71e0be0cb3e1eb6a742` cloned recursively with all four submodules and clean status. Does **not** certify unpublished local HEAD |
| `git clone --quiet --no-local --recurse-submodules . <temp>/repo` | 1 | Local-relative `.gitmodules` URLs require local file transport which Git blocked (`transport 'file' not allowed`); not a public remote failure |

## Frozen revision vector / publication boundary

The live superproject is dirty, and concurrent branches/claims must not be rewritten. At initial gate:

| Library | HEAD-pinned gitlink | Initially checked-out |
|---|---|---|
| `cl-events` | `1664d9a694fdcf4520df85ca869a994fcf0cc7d5` | `30d82c0b42399d66045602e8098ab1059fbe675b` |
| `cl-inputs` | `6a9b1842db2f0a311b1ce44a2ba8b6e923fdd329` | same |
| `cl-state` | `8b293004dc03c89ade9eef02cb14aa94b1a81a66` | `e4ce3d9099fe14b469cd5676e1e83cff91882436` |
| `cl-styles` | `64000cb768adb8158bc1b4687c295339417c8f56` | `1527f9631dd7696040999e265144e3019e68e147` |

Published clean-remote clone resolved `cl-events d4399c08`, `cl-inputs b9d0cbec`, `cl-state f95baab3`, `cl-styles 9c2b40c3` — a **different**, historically published revision vector.

`CHANGELOG.md` has `Unreleased` and `0.2.0` entries. Annotated local `v0.2.0` already exists at `511edb2` (2026-07-10), and is not the new current SHA. Neither tag nor version was moved. No push, publish, deployment or source-distribution upload was performed.

## Additional independently executed gates after editor normalization

| Gate | Exit | Evidence |
|---|---:|---|
| FiveAM maintained examples smoke (new normalized `Ctrl+S` regression) | **0** | 575/575 pass; `test-output/release-editor-focused.log` |
| `python3 tests/e2e/extended-examples-pty.py -v` | **0** | 9/9 pass, including dirty-quit, Escape, Ctrl+Q, navigation, and clean terminal exit |
| `python3 tests/e2e/release-gate-mini-editor-pty.py -v` | **0** | 1/1 after source correction; actual disk write, clean/dirty marker, no alternate screen, cursor+termios restoration |
| `python3 tests/e2e/release-gate-binary-pty.py <built-minimal>` | **0** | 1/1: packaged executable boots in isolated tmux, paints Hello slurp, accepts x->Hello X, Ctrl+Q cleanly restores terminal |
| `python3 -m py_compile tests/e2e/release-gate-mini-editor-pty.py tests/e2e/extended-examples-pty.py` | **0** | Syntax valid |
| `scripts/release-check.sh` after source correction | **1** | Still stops at cl-events pin mismatch (`1664d9a` pinned vs working copy `dc7b800` at last replay). No skipped checks |

The private-tmux extended-test harness had an independent observation race: `exit-code` is created just before the shell restoration marker is printed, and a valid marker may scroll outside the visible pane. The helper now requires the actual marker either on screen or in the captured raw terminal stream, and still checks exit code zero, identical before/after terminal modes and cursor visibility.

Built binary SHA-256 (current dirty checkout): `2620fdd09447a0412df418f5f2a23524096ed94a1a5f808cc0f1e15842cb53af`. The generated ELF and its private-tmux startup passed; immutable distribution and independent pinned checkout remain unverified.

## Remaining mandatory qualification

1. Preserve the now-passing live-PTY mini-editor Ctrl+S and unsaved-dialog contract across supported terminal launchers. Root cause of this lane’s Ctrl+S failure was `examples/mini-text-editor.lisp` `%control-key-p`: it handled the keyword `:s` but not the normalized character key `#\\s` with `(:ctrl)` and `CHAR=NIL`. The example-level predicate now accepts either representation. The new FiveAM regression passes, and actual disk save / `-ixon` / terminal restoration are checked by the private-PTY test.
2. Freeze an exact clean candidate revision vector, reconcile checked-out submodules to their pinned commits in an **isolated** checkout, prove those pinned commits are reachable from their public remotes, and rerun `scripts/release-check.sh` there.
3. Extend terminal lifecycle/no-alt-screen/scrollback and packaging acceptance to the intended full flagship example matrix; only named PTY cases above are verified this run.
4. Obtain **independent code review** of the loader correction and loader regression. Delegated reviewer interface attempts returned tool-unavailable; this report is self-audit plus executable test evidence, not independent review approval.
5. Reconcile changelog, semver and immutable tag/release proposal only after mandatory gates succeed. `v0.2.0` must never be force-moved.

**Release decision: NO-GO.** Root FiveAM and focused loader gates are green, but full release acceptance is not.
