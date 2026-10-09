# ElmTUI independent workbench contract tests

These tests are intentionally independent of W1–W7's owned files. They use **real CLPM/SBCL subprocesses** and an isolated `tmux -S` PTY, rather than mocking widget callbacks or rewriting the workers' FiveAM suites.

Run now:

    python3 -m unittest discover -s tests/workbench/independent -p 'test_unit_invariants.py' -v
    python3 -m unittest discover -s tests/workbench/independent -p 'test_pty_driver.py' -v

Run all Python-independent tests (including the not-yet-available workbench app):

    python3 -m unittest discover -s tests/workbench/independent -p 'test_*.py' -v

After W5 provides the application command, set `ELMTUI_WORKBENCH_TEST_CMD` to its actual argv string and run:

    python3 -m unittest discover -s tests/workbench/independent -p 'test_application_e2e.py' -v

The app test is **explicitly skipped** until the launcher is supplied; this is not a passing application qualification. The two PTY self-tests prove that the harness injects real bytes, observes the resulting terminal screen, resizes the terminal and checks exact pre-/post-run termios. Do not infer native urxvt compatibility from tmux tests; W6 owns a separately configured native urxvt/Xvfb test lane. For full performance/cancellation verification, retain raw terminal trace, input latency samples, and independent reviewer evidence.

These tests are snapshots against evolving interfaces. Failing public API invariants should be reported to the owning W1–W4 workers; do not modify their claimed files or soften assertions to obtain green.
