# E2 release PTY matrix — 2026-10-27

- Canonical OCP task: ELMTUI-CLPM-E2-TERMINAL-PTY-20261027-FA9FB8
- Dispatch: df4429d50724477cbed34c6856b5916e
- Root: /home/user/code/lisp/elmtui.lisp
- Baseline HEAD: a6be0e79e7a954eb77b4b299038984ad7170cb41
- Release safety: v0.2.0 and existing tag unchanged, no push/deploy, no host Wi-Fi mutation.
- Ownership: parent PTY packet ea9791bb-3ec5-4dc7-aabc-63d08df755c0 claims only scripts/test-terminal-apps.py and this report. Unique source-remediation continuation ed53baa3-b5cb-4982-9917-ddd15c79fa2b is separately scoped to src/platform/driver.lisp under the SAME OCP task. No other agent scopes modified.
- Dirty worktree: extensive preexisting modifications and dependency gitlinks preserved. The Game of Life expectation corrections existed as an unstaged diff on initial inspection and were independently tested, not silently replaced.

## Harness / trust model

Each case uses its own private tmux socket and fresh CLPM/SBCL process. Xvfb/urxvt mode starts a private Xvfb display and real urxvt window, sends X11 keys via xdotool and attaches it to the private tmux pane. It is not an independent native urxvt-without-tmux test. Initial geometry is configurable by --columns and --rows (default 100x35).

Per-run evidence: test-output/e2-20261027-*/result.json and *.log. Per-test evidence includes launch.sh, terminal.raw, stderr.txt, frames.json, last-screen.txt, before.stty, after.stty and exit-code. Normal exits require status 0, exact restored termios, visible cursor, restored shell output and no unexpected warnings/fatal diagnostics. Three precisely identified upstream Log4CL redefinition warnings from the directly loaded editor are exempt, not arbitrary compiler warnings.

Wi-Fi tests use a PATH-prepended temporary nmcli fixture. Argument arrays are recorded in ELMTUI_NMCLI_CALLS. Abort scenarios require scan-only invocation; simulated connect is recorded but does not invoke the host's NetworkManager. Real Wi-Fi hardware and network connection success are NOT qualified.

## Verified commands and results

All commands below ran from the canonical repository root. The --output paths contain full logs and frames.

| Scenario | Exact command | Exit / result |
|---|---|---|
| Initial full tmux sweep | python3 scripts/test-terminal-apps.py --terminal tmux --timeout 35 --output test-output/e2-20261027-tmux | 0; 9/9 pass |
| Initial full Xvfb/urxvt sweep | python3 scripts/test-terminal-apps.py --terminal urxvt --timeout 35 --output test-output/e2-20261027-urxvt | 0; 9/9 pass |
| Mini editor Ctrl-S persistence and clean exit | python3 tests/e2e/release-gate-mini-editor-pty.py | 0; 1/1 pass |
| Additional maintained apps (finder, selector, glider, cursor inspector, Pong, viewport, editor dirty quit) | python3 tests/e2e/extended-examples-pty.py -v | 0; 9/9 pass |
| Normal-buffer Neon restoration | python3 tests/e2e/test-neon-terminal-restoration.py --timeout 20 --output test-output/e2-20261027-neon-restore | 0; 2/2 pass |
| Life PTY animation, pause, step, no idle write | python3 tests/e2e/game-of-life-pty.py | 0; 2/2 pass |
| Dynamic tmux SIGWINCH resize: 100x35 to 68x22 to 120x40 | python3 scripts/test-terminal-apps.py --terminal tmux --timeout 25 --case resize --output test-output/e2-20261027-live-resize | 0; 1/1 pass; measured window dimensions |
| Editor Ctrl-Q dirty/cancel/discard, tmux | python3 scripts/test-terminal-apps.py --terminal tmux --timeout 18 --case editor_dirty --output test-output/e2-20261027-editor-dirty-tmux-r2 | 0; 1/1 pass |
| Editor Ctrl-Q dirty/cancel/discard, Xvfb/urxvt | python3 scripts/test-terminal-apps.py --terminal urxvt --timeout 18 --case editor_dirty --output test-output/e2-20261027-editor-dirty-urxvt-r2 | 0; 1/1 pass |
| Editor Ctrl-S actual disk write, clean Ctrl-Q, tmux | python3 scripts/test-terminal-apps.py --terminal tmux --timeout 20 --case editor_ctrl_s --output test-output/e2-20261027-editor-save-tmux | 0; 1/1 pass |
| Editor Ctrl-S actual disk write, clean Ctrl-Q, Xvfb/urxvt | python3 scripts/test-terminal-apps.py --terminal urxvt --timeout 20 --case editor_ctrl_s --output test-output/e2-20261027-editor-save-urxvt | 0; 1/1 pass |

Initial geometry matrix (the full executable command is python3 scripts/test-terminal-apps.py --terminal TERMINAL --columns COLS --rows ROWS --timeout 24 --case minimal_input --output test-output/e2-20261027-TERMINAL-COLSxROWS-minimal_input):

| Terminal | Width x height | Exit | Verification |
|---|---|---:|---|
| tmux | 68x22 | 0 | input/render/exit, exact termios/cursor |
| Xvfb/urxvt | 68x22 | 0 | X11 input/render/exit, exact termios/cursor |
| tmux | 120x40 | 0 | input/render/exit, exact termios/cursor |
| Xvfb/urxvt | 120x40 | 0 | X11 input/render/exit, exact termios/cursor |

Dynamic tmux resize is explicitly skipped for urxvt: the emulator owns its X11 window geometry. A native urxvt resize is not established by the initial-geometry matrix.

## Oracle correction and falsification

The 2026-10-26 8/9 report expected an obsolete Game of Life pause glyph (Ⅱ PAUSED) and generation-reset string (GEN 000 Ⅱ PAUSED). Real UI output instead shows ◉ PAUSED and GEN 0000. The corrected test pauses, advances to nonzero generation with the s key, resets to precisely generation zero while paused, resumes and quits. The initial 9/9 tmux and 9/9 urxvt sweeps independently confirm this is assertion drift rather than a pause defect.

A newly added editor dirty-quit test initially failed on BOTH backends due to a test oracle that assumed a full random temp filename would appear in a terminal-width-limited title bar. The title is intentionally elided. The corrected test checks the visible header dirty marker, Modified status, real Unsaved changes modal, cancel and discard. Its second run passes on BOTH backends. Ctrl-S case checks -ixon on the pane TTY, actual UTF-8 file content and normal cleanup.

## Genuine release blocker: fatal startup cleanup

Both backends reproducibly fail the independently injected model-initializer exception test:

    python3 scripts/test-terminal-apps.py --terminal tmux --columns 100 --rows 35 --timeout 24 --case init_exception --output test-output/e2-20261027-tmux-100x35-init_exception
    python3 scripts/test-terminal-apps.py --terminal urxvt --columns 100 --rows 35 --timeout 24 --case init_exception --output test-output/e2-20261027-urxvt-100x35-init_exception

Both test commands exit 1 (FAIL). The injected E2_INJECTED_INIT_FAILURE is present in stderr, SBCL exits with code 1, and shell output is visible again. But before.stty differs from after.stty (before 4500:5:f00bf:8a3b:..., after 4000:5:f00bf:8a01:...), and tmux cursor_flag=0 (cursor remains hidden).

Inspection of src/platform/driver.lisp run-app-platform around lines 949–1110 finds an outer unwind-protect around backend/model initialization with no cleanup forms, and a later distinct unwind-protect providing shutdown-platform and elm-stop-loop only for the main wait loop. Errors during startup bypass that later cleanup. The RED regression test_init_exception_restores_terminal is deliberately NOT xfailed or suppressed.

The unique source continuation packet, under the same E2 OCP identity, is ed53baa3-b5cb-4982-9917-ddd15c79fa2b. It is published ready, pending ownership capacity; its exact source write scope is src/platform/driver.lisp, distinct from this parent's script/review claim. The matrix remains RED until requalification proves cleanup after this fault on both backends.

## Follow-through / boundaries

- Fix backend exception cleanup under the separately governed exact source claim. Rerun both isolated failure probes and complete expanded 13-case suite on both backends.
- Obtain independent review of test assertions and source change, correct any findings, submit canonical typed abc-chain.phase-result and local scoped commit. No release artifact modification or publication.
- Normal shutdown does NOT demonstrate exceptional teardown; tmux-driven urxvt does not establish native urxvt restoration; and simulated nmcli does not establish live network connectivity. All three distinctions must survive release messaging.
