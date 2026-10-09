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

## Independent supporting-library oracle

`runner.py` also executes `scripts/test-subsystems.sh` through the
`dependency_oracle` gate. This separately calls `asdf:test-system` for
`cl-events`, `cl-inputs`, `cl-state` and `cl-styles`. Each library must
execute nonzero FiveAM checks, report zero failures, and return successfully.
This dependency gate is independent of the 30 Workbench application cases,
the startup fixture and the main ElmTUI test suite. Its complete command,
stdout/stderr, exit code and verdict are included in the JSON evidence report.
The gate fails closed when any library fails or is skipped.

## Current live application runner

The real W5 launcher now exists. Run all 30 executable case-specific
oracles with:

    python3 tests/workbench/validation/runner.py

The runner creates tests/workbench/validation/artifacts/run-*/result.json
and individual command stdout/stderr plus private tmux screen snapshots,
raw terminal bytes, cursor/geometry, input events, and before/after stty.
It uses exact independent CLPM/SBCL module tests for unit cases and actual
CLPM/SBCL launches for PTY cases. No fixture counts as an application pass.

Exit codes are strict: 0 = all 30 application cases and all mandatory
independent checks passed; 1 = at least one tested failure; 2 = no failed
checks, but one or more application cases not run. The October 9 integrated
run reported 30 PASS, 0 FAIL, 0 NOT RUN, and a passing independent four-library
dependency oracle. Verify the generated result.json for current results;
an independent review verdict remains a separate release requirement.
