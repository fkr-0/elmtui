# Workbench W6 validation

OCP task: ELMTUI-WB-06-VALIDATION-20261009. No change outside
tests/workbench/validation/** and docs/workbench-qa-results.md.

Run from repo root:

    python3 tests/workbench/validation/runner.py

This produces catalog, fixture and CLPM baseline stdout/stderr logs and a
JSON evidence report under artifacts/run-*. All commands retain exact
argv, exit code, warnings and wall time. The fixture self-test uses an
isolated tmux server/PTY, actual keystrokes, raw terminal byte capture,
decoded screen snapshots, 80x24 → 120x40 → 160x50 resize and exact
before/after termios and cursor checks.

Fixture PASS is only a harness self-test, never an application pass.
The matrix tests remain NOT RUN until W5 provides both its separate
ASDF system and real workbench launcher. After W5 handoff, the same OCP
task must resume and bind all 30 live application oracles (including
multiline editing, Unicode cells, evaluation cancellation, async stale
completion, doc dwell, popup geometry, inspector updates, passive
reader safety, terminal restoration and zero idle writes).

tmux capture-pane records ANSI-interpreted cells; terminal.raw contains
byte-stream evidence but its capture can start slightly after initial
startup. Do not use fixture output as W5 startup evidence. Never execute
untrusted input: the fixture only echoes single byte input and quits.

Independent reviewer required; no self-approval or publication.

## Current live application runner

The real W5 launcher now exists. Run all 30 executable case-specific
oracles with:

    python3 tests/workbench/validation/runner.py

The runner creates tests/workbench/validation/artifacts/run-*/result.json
and individual command stdout/stderr plus private tmux screen snapshots,
raw terminal bytes, cursor/geometry, input events, and before/after stty.
It uses exact independent CLPM/SBCL module tests for unit cases and actual
CLPM/SBCL launches for PTY cases. No fixture counts as an application pass.

Exit codes are strict: 0 = all 30 passed; 1 = at least one tested failure;
2 = no failed cases, but one or more cases not run. The most recent live
run has 29 PASS, 1 FAIL, 0 NOT RUN. The failing bracketed-paste end-to-end
case remains a release blocker until the workbench consumes a single
typed :paste payload without evaluating any contained newline. Verify
the generated result.json instead of extrapolating from the summary line.
