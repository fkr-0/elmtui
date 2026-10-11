# Non-interactive verification command matrix

This project has terminal, tmux, example, and faketerm code paths. Prefer the
non-interactive gates below when reviewing or changing code so verification does
not depend on the current terminal pane, server stdout, or ambient tmux state.

## Default gates

| Purpose | Command | Expected behavior |
| --- | --- | --- |
| Fast runner/static contracts | `python3 tests/test_runner_contracts.py` | Verifies the CLPM runner, stdout/log isolation, tmux opt-in policy, ASDF naming hygiene, and documentation contracts without loading the Lisp system. |
| Normal default test suite | `clpm bundle exec --with-client sbcl -- --noinform --load scripts/run-tests-clpm.lisp` | Runs the default FiveAM suite, exits non-zero on failure, writes log4cl output to `test-output/`, and skips live tmux capture tests unless explicitly opted in. |
| Warning-clean release gate | `scripts/run-tests-warning-clean.sh` | Wraps the declared CLPM runner, captures stdout/stderr logs under `test-output/`, and fails if unexpected compiler/runtime warning markers appear. |

## Live tmux integration gates

Live tmux tests intentionally do not run by default. They read from real tmux
state and are therefore unsuitable for the normal CI/review gate unless the
operator deliberately opts in.

| Purpose | Command | Notes |
| --- | --- | --- |
| Run live tmux integration when tmux is available | `ELMTUI_RUN_TMUX_INTEGRATION=1 clpm bundle exec --with-client sbcl -- --noinform --load scripts/run-tests-clpm.lisp` | Enables live tmux capture tests, but still skips them if tmux is unavailable. |
| Require live tmux integration | `ELMTUI_REQUIRE_TMUX=1 clpm bundle exec --with-client sbcl -- --noinform --load scripts/run-tests-clpm.lisp` | Enables live tmux tests and treats missing tmux as a test failure. Use only on a host prepared for tmux integration checks. |

## Faketerm tests

`tests/faketerm-tests.lisp` is the preferred non-interactive TUI testing layer.
It avoids live terminal/tmux state while still exposing behavior-level assertions.
Important harness primitives include:

- `faketerm-screen-lines` for deterministic screen snapshots.
- `faketerm-enqueue-input` for post-initialization input injection.
- `faketerm-log-lines` for backend operation-log snapshots.
- `faketerm-run-to-quiescence` for deterministic step-driven scenarios without
  arbitrary sleeps.

Use faketerm tests for widget rendering, input routing, and view/update loops
before escalating to live terminal or tmux integration.

## Output and log locations

The CLPM runner removes inherited log4cl stdout appenders before running tests.
Application log output is redirected away from server stdout and into files under
`test-output/`. The warning-clean gate also writes timestamped stdout/stderr logs
there so failed review runs can be inspected without re-running the suite.

Known external caveat: some bridge/tool invocations outside this repository have
emitted an ambient `3024 i3` line before command output. That line is not produced
by the Lisp test runner or log4cl configuration; repository-owned verification
should rely on captured test logs and process exit status instead of assuming the
outer bridge stdout is pristine.
