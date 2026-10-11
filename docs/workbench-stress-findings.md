# W8 stress findings — 2026-10-09

Canonical OCP task: ELMTUI-WB-08-STRESS-20261009
Packet: 207beafb-8900-4ca4-ae85-c62ea39ab21b
Owned paths: tests/workbench/stress/** and docs/workbench-stress-findings.md

## Reproduction

Run from repository root:

    python3 -m py_compile tests/workbench/stress/test_stress.py tests/workbench/stress/pty_probe.py
    python3 -m unittest discover -s tests/workbench/stress -p 'test_*.py' -v
    WB08_SEED=42 WB08_ROUNDS=128 python3 -m unittest discover -s tests/workbench/stress -p 'test_*.py' -v
    WB08_SEED=987654 WB08_ROUNDS=128 python3 -m unittest discover -s tests/workbench/stress -p 'test_*.py' -v
    python3 -m unittest discover -s tests/workbench/independent -p 'test_*.py' -v
    clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load scripts/run-tests-clpm.lisp

Each test invokes actual standalone W1–W4 sources using CLPM/SBCL in isolated processes with no mocked module methods. Parameters: WB08_SEED default 20261009; WB08_ROUNDS default 32, permitted 1–128; WB08_TIMEOUT default 18, permitted 3–30 seconds per subprocess. W2 polling is capped at 500 × 4ms, head evaluation sleeps 60ms, and no uncontrolled loop or hostile untrusted EVAL is sent.

## Evidence

| Run | Result |
| --- | --- |
| Default 20261009, 32 rounds | 4 pass / 3 NOT RUN / 0 fail |
| Seed 42, 128 rounds | 4 pass / 3 NOT RUN / 0 fail |
| Seed 987654, 128 rounds | 4 pass / 3 NOT RUN / 0 fail |
| Read-only independent workbench harness | 18 pass / 3 W5 skips / 0 fail |
| Full root FiveAM test suite | 4479 checks: 4473 pass / 6 intentional skips / 0 fail |

Root count is a new observation, not a restatement of the prior 4471-pass baseline. All 6 root skips are the opt-in live tmux integration tests requiring ELMTUI_RUN_TMUX_INTEGRATION=1. Root suite returned 0.

## Exercised contracts

- W1: seeded Unicode wide characters, combining accents, ZWJ emoji, undo/redo, resize at 8/18/80 columns, cursor geometry, grapheme backspace and a final independently computed expected string.
- W2: real two-session async workers with overlapping numeric IDs, sequential per-session finishes, typed values bound to IDs, queued cancellation of read-time #.(setf ...) and no sentinel side effect, followed by successful evaluation.
- W3: completion generation comparison, candidate identity, passive #. sentinel, documentation dwell before and exactly at 450ms, stale generation/selection suppression, single-shot consumption and cancellation.
- W4: cyclic vector and cycle marker, bounded paginated child inspection, maximum preview length, inventory paging, refreshed and cached generations.

These W1–W4 passes do NOT prove actual W5 completion-popup coordinates or interactive repaint behavior.

## Discovered and recovered harness failure

First 128-round editor run with seed 42 raised OSError Errno 7 Argument list too long (clpm). The test generator embedded quadratic expected-text prefixes in one command-line argument; no ElmTUI assertion failed. Replaced it with a bounded incremental oracle plus final independent expected-string comparison. The same seed and 128 rounds then passed, followed by seed 987654 at 128 rounds. Do not classify the initial run as passed.

## W5 real UI — NOT RUN

At first inspection, elmtui-workbench.asd, examples/workbench.lisp and src/workbench/app.lisp were missing. They appeared later in the same shared checkout. The first three default test skips were therefore honest at the time; late-arrival real-W5 verification was then attempted and failed as recorded below. To enable real tests once available:

    ELMTUI_WORKBENCH_TEST_CMD='clpm bundle exec --with-client sbcl -- ...' python3 -m unittest discover -s tests/workbench/stress -p 'test_*.py' -v

The command must be a real W5 app, not a fixture. Optional ELMTUI_WORKBENCH_READY_PATTERN and ELMTUI_WORKBENCH_CANCEL_PATTERN must match verified actual UI text.

Opt-in tests:
1. Private isolated tmux: repeated app start/exit, key-burst erase, finite expression output, resizes 80x24 to 120x40 to 160x50 and back, exit status and stty restoration.
2. Raw PTY: read real emitted bytes; after settle, assert no idle writes, edit causes writes, then no subsequent unchanged-frame writes. Require ECHO off so kernel echo cannot count as app paint. Check terminal attributes restored after Ctrl+D.
3. Idle process CPU: find actual SBCL descendant of CLPM from bounded /proc traversal; compare process user+system CPU ticks for the same idle interval. If unavailable, mark NOT RUN, never a false zero-CPU pass. Zero recorded ticks establishes only sample-resolution idle CPU, not perpetual zero.
4. Ctrl+C: bounded visible cancellation feedback for a finite 0.5-second EVAL. Trusted, potentially blocking Lisp code is cooperative; do not claim arbitrary preemption of infinite loops.

A stable tmux screen snapshot is not proof of zero raw terminal writes. Existing private-PTY fixture passes exercise a fixture, not W5 and not idle UI CPU. All actual W5 acceptance gates remain unproven until the opt-in tests execute on its launcher.

## Late W5 arrival — real application qualification FAILED

With the official launcher now present, executed:

    ELMTUI_WORKBENCH_TEST_CMD='clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load examples/workbench.lisp' python3 -m unittest discover -s tests/workbench/stress -p 'test_*.py' -v
    python3 tests/workbench/pty-workbench.py

Actual W8 opt-in result: 4 W1-W4 passes; 4 W5 assertion failures
across 3 test methods (two independent restart subtests), total 7
methods, exit 1. All three failures originated at W5 readiness: no
CL-USER or Lisp Workbench display appeared. Real raw PTY output
showed ESC[6n (cursor query), ESC[?25l, ESC[?1049h, ESC[H,
ESC[1;1H, ESC[?1049l and cursor reset, then process exited
with code 0. Raw bytes and CPU *after a ready interactive screen*
were consequently NOT MEASURED; cancellation was NOT OBSERVED.
Do not misreport these as repaint, CPU, or cancellation failures.

The independent W5-owned PTY smoke separately failed its startup
frame oracle in all three geometries: 80x24, 120x40 and 160x50
(exit 1). Those reports also show log4cl runtime generic
redefinition warnings; W1-W4 stand-alone compile-file checks were
warning-clean for editor, eval, completion, docs and inspector,
with compiled FASLs written only under /tmp.

Shared-workspace note sequence 7378, note ID
e1525d5e-aaa8-47e5-9802-f3884ee1be1a, notified the W5
owner of the reproducible failure. No W5-owned files were changed.

## W5 follow-up recovery (9 October 2026)

The W5 launcher startup issue from the original W8 report had already
been fixed in the shared checkout. Native PTY smoke passed at 80x24,
120x40 and 160x50 before subsequent changes.

Confirmed and fixed:

- Ctrl+C caused a nonlocal exit from the event consumer before W5's
  update function. The input adapter correctly decoded byte 0x03 as
  character key #\c with :ctrl modifier. But the shared AppMsg KeyEvent
  variant in src/state/msg.lisp constrained :key to SYMBOL, so its
  constructor signaled a type error. Changed :key to
  (or symbol character) and added a real CLPM/SBCL constructor regression.
- The W5-only terminal setup clears ISIG after cl-inputs has activated
  its input source, on the first setup timer event. It retains
  cooperative cancellation semantics and original termios restoration.
  The first attempted early initialization was discarded after it
  revealed terminal restoration drift.
- The 75 ms application timer is now conditional. It runs during the
  initial setup, pending evaluations, documentation dwell, or live
  inspector watches. It is not permanently installed during idle.

Real application verification command:

    ELMTUI_WORKBENCH_TEST_CMD='clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load examples/workbench.lisp' python3 -m unittest discover -s tests/workbench/stress -p 'test_*.py' -v

Observed with the initial seven cases: 7 passed, 0 skipped, 0 failed.
Included an actual Ctrl+C message, unchanged-frame raw byte measurement,
sampled zero SBCL CPU ticks during idle, two repeated start/exit cycles,
and terminal restoration. Zero sampled CPU ticks is limited to the
measured interval and /proc tick resolution; not a perpetual zero-CPU
guarantee. Arbitrary trusted blocking Lisp is not forcibly preempted.

Independent existing workbench suite: 18 passed, 3 W5 opt-in skipped,
zero failures. Native W5 PTY smoke: three geometry passes.

Separate current root-suite blocker: 4666 checks (4659 pass, six
intentional tmux skips, one failure). The DEV-TEST-SUITE
MAINTAINED-RUNTIME-DOES-NOT-SILENTLY-IGNORE-ERRORS test detected
ignore-errors at src/platform/driver.lisp:313 in concurrently edited
rendering code. That path is not owned by this work; notified the
rendering owner via ws-bridge note sequence 7410.

Remaining caveat: during the first setup-timer interval, Ctrl+C may
still behave as the terminal's inherited SIGINT policy. Elimination
of this narrow race belongs to an explicitly configurable cl-inputs
per-application input-source signal policy. This follow-up does
not modify shared cl-inputs or shared driver source.


## Corrected CPU evidence and additional regression — final rerun

The earlier seven-case green sample and subsequent eight-case failing sample
were both real observations. The strict process-total test occasionally
recorded one or two CPU ticks over 550 ms: these ticks include all SBCL
threads, runtime housekeeping and input polling, not necessarily application
rendering. The earlier claim that the whole SBCL process always consumes
zero CPU ticks at idle was too strong.

New test test_w5_idle_subscription_state_machine loads the real workbench,
confirms the one-time setup timer, then verifies quiescence has NO application
timer subscriptions. A pending evaluation or documentation dwell installs a
timer; cancelled documentation returns to no timers. This application-level
invariant is independent of the raw PTY zero-idle-writes check. The real
PTY test also reports process-wide CPU ticks and fails if they exceed a
conservative 6% CPU-equivalent bound for its 550-ms interval, without
misrepresenting background runtime CPU as application UI work.

Most recent real-launcher stress command:

    ELMTUI_WORKBENCH_TEST_CMD='clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load examples/workbench.lisp' python3 -m unittest discover -s tests/workbench/stress -p 'test_*.py' -v

Result: 9 tests, 9 PASS, 0 skips, 0 failures; exit code 0.
Observed WB08_IDLE_SBCL_CPU_TICKS=1 over 0.55s for that run.
The app-level idle timer contract and strict zero emitted raw terminal
bytes were both separately asserted. These results are valid for that
bounded sample and do not establish universally zero process-wide CPU.
The Ctrl+C key constructor regression additionally confirms both character
and symbolic KeyEvent keys.

Original W5 startup failures documented above remain preserved as historical
evidence. A separate full-root-suite failure in src/platform/driver.lisp was
reported to its owner and must be independently rechecked before release.

## Final verification addendum (same day)

After the independently owned rendering fix landed, reran the root suite:

    clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load scripts/run-tests-clpm.lisp

Result: 4666 checks, 4660 pass / six intentional opt-in live tmux skips /
zero failures, exit code 0. The previous src/platform/driver.lisp
policy failure is no longer reproducible in this checkout.

Reran all nine actual W8 tests with WB08_SEED=42 WB08_ROUNDS=128
and the CLPM real W5 launcher: nine pass / zero skip / zero fail,
exit code 0. The observed process CPU sample this time was zero ticks
for 550ms. Earlier samples of 1-2 process-wide ticks remain valid
and are not erased or attributed to UI repaint.

Independent application PTY smoke passed at 80x24, 120x40 and 160x50.
Preexisting independent workbench harness passed 18 cases and skipped
three W5 opt-in cases without a launcher command.

The W5 canonical work packet still needs independent workflow
recovery/reconciliation and review by a distinct worker. No source
push, review approval, or release action was performed here.


## Final W5 follow-up: paste and pre-frame Ctrl+C (2026-10-09)

W6 initially reported 29 of 30 application cases. Editor paste failed
because src/platform/input.lisp emits (:paste :content STRING) but W5
did not handle the message. W5 now inserts paste atomically only if
editor-focused and payload is a string, clears stale completions,
increments generation, and never evaluates content on paste.
Multiline pasted text requires explicit Enter to submit.

W6 validation rerun: 30 PASS, zero FAIL, zero NOT_RUN, exit 0.
Artifact: tests/workbench/validation/artifacts/run-1f199f3d79/result.json.

The Ctrl+C startup race was eliminated without changing cl-inputs.
The optional launcher passes :signal-keys-as-input t through the driver
to the terminal backend. Immediately after cl-inputs captures original
termios, the backend clears ISIG on the actual device FD, before the
initial ESC[6n cursor query. It is opt-in and restores original termios
on shutdown. W5 no longer configures TTY at a late setup tick; startup
and quiescent sessions have no W5 timer subscription.

The new early signal-mode regression checks ISIG off at ESC[6n, Ctrl+C
feedback, successful Ctrl+D exit, and exact terminal attribute restoration.

W8 real workbench: 10 PASS, 0 FAIL, 0 SKIP.
Independent workbench suite with real launcher: 21 PASS, 0 FAIL.
Native PTY smoke: PASS 80x24, 120x40 and 160x50.
CLPM workbench load/compilation: exit 0.

Root suite, concurrently edited checkout: 4706 checks, 4699 pass,
6 intentional live tmux skips, 1 failure in separately claimed
src/platform/tmux-capture.lisp:447 due to runtime ignore-errors policy.
EX11 owner notified at project coordination note sequence 7455.
W5 did not modify the tmux capture path.

Earlier mentions of a first-75ms startup window above are historical
and superseded by the verified opt-in backend initialization.
No approval, full release qualification, or push is claimed.


## After cross-lane reconciliation: root suite clean

Subsequently, the separately owned EX11 tmux-capture policy issue
was fixed by its owner (not by W5). On the new shared checkout,
the complete root FiveAM suite returned exit 0:

    4707 checks: 4701 PASS, 6 intentional live-tmux SKIP, 0 FAIL

This supersedes the immediately preceding root failure count,
without erasing that earlier observation. The 10/10 W8 stress,
30/30 W6 live PTY matrix, 21/21 independent workbench suite,
and 3/3 native W5 PTY smoke are the verified W5 qualification
set. The W5 source, runner, and user guide were committed locally
in guarded per-claim commits; remote push and approval remain separate.

## Ownership and remaining risks

Existing staged/unstaged/untracked checkout state, bridge manifest and submodule changes were preserved. No W1–W7 files were edited, no release-owned source modified, no push or publication. Generated Lisp forms were used for runtime probes but no tracked Lisp source file was created or modified.

Remaining gaps: no real app-level PTY evidence, screen-cell popup geometry, or W5 idle CPU measurement. Inspector bounded vector tests do not establish safety of arbitrary user-defined print methods. Independent reviewer (a different worker) must inspect source and exact commands, run the new suite, and record a review verdict; implementation worker must not self-approve.
