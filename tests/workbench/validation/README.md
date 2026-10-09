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
