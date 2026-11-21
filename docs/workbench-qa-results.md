# Workbench W6 QA results — 2026-10-09

Canonical OCP task: ELMTUI-WB-06-VALIDATION-20261009

## Initial dependency

The separately loadable elmtui-workbench.asd and actual launcher
examples/workbench*.lisp were not present at initial inspection. Source
modules W1–W4 exist, but no W5 black-box process is currently launchable.

## Evidence classes

- Terminal fixture: true input through a private tmux PTY, real decoded
  frames, 80×24 / 120×40 / 160×50, idle byte measurement, termios and
  cursor restoration. Fixture proof never counts toward application passes.
- Catalog check: test specification integrity only.
- CLPM baseline: existing elmtui system load through the mandated
  clpm bundle exec --with-client sbcl -- invocation. It cannot qualify
  the absent workbench ASDF startup.
- Per-case evidence: stored under tests/workbench/validation/artifacts/
  as a 30-row result.json. There are no fabricated successful cases.

## Actual verification run

- Evidence manifest: tests/workbench/validation/artifacts/run-ae17b81f43/result.json.
- Matrix catalog integrity: exit 0, zero warnings, 0.048 s.
- Two real private tmux fixture tests: exit 0, zero warnings, 0.759 s.
- Existing ElmTUI CLPM/SBCL ASDF load: exit 0, 0.706 s,
  three warnings; all are LOG4CL-IMPL generic-function redefinitions
  (APPENDER-ADDED, APPENDER-REMOVED, PROPERTY-ALIST).
- Private terminal input: actual "z" produced FIXTURE_KEY:7A on decoded
  screen; resize was verified 80x24 → 120x40 → 160x50 → 80x24.
- Fixture idle: raw terminal output stayed at 38 bytes for 0.35 seconds
  (delta 0). The fixture, not the workbench, was idle.
- Both fixture exits were code 0 with matching before/after stty state,
  a visible cursor and shell exit sentinel.
- Timed frames, terminal.raw, stderr and exit records are retained in
  fixture-traces under that run. Native urxvt/Xvfb and actual workbench
  application scenarios were **not run**.

## Qualification

| Category | PASS | FAIL | NOT RUN |
|---|---:|---:|---:|
| 30 application cases | 0 | 0 | 30 |

**Blocker:** W5 must deliver the genuine app, stable keybindings,
separate ASDF entry point and launcher. Resume this exact OCP task
through governed continuation, execute all 30 application scenarios,
then request a separate independent review. No self-approval or
publication. Preserve W1–W5 source and unrelated repository dirt.

## Live-workbench continuation — 2026-10-09 (supersedes the initial absence diagnosis)

W5 subsequently supplied the real optional system and launcher.
The earlier 0/0/30 table above remains a historical **initial run**, not the current result.

- Real application evidence: tests/workbench/validation/artifacts/run-30d96b41ea/result.json.
- Complete 30-case matrix: **29 PASS, 1 FAIL, 0 NOT RUN**.
- Remaining failure: editor-paste-controls. A literal bracketed paste carrying two
  lines did not become editable text in the actual tmux terminal; the test does
  not substitute normal key typing or suppress a possible unwanted EVAL.
- Independent native root/input discovery found a transport gap: cl-inputs
  recognizes :paste, but its normalized event adapter returns NIL. A narrowly
  guarded src/platform/input.lisp change now preserves the UTF-8 paste as
  (:paste :content text); fresh CLPM/SBCL confirms exact multiline payload.
  The W5 workbench must still consume this application event as one editor
  insertion (never emit Enter or evaluate pasted source).
- Full passing live cases cover private PTY geometry 80x24, 120x40, 160x50;
  actual termios/cursor restoration on Ctrl+D, zero idle writes, popup above
  editor, docs dwell plus selection-change cancellation, live inspector watch
  refresh, responsive Ctrl+C during a bounded sleeping evaluation, resize
  draft preservation, completion safety, native reader/evaluator contracts and
  optional Slynk absence.
- Three LOG4CL-IMPL method-redefinition warnings from inherited dependency
  compilation are identified separately from the owned workbench modules.
- Matrix statuses derive only from executed per-case oracles. The runner exits
  1 for any failure, 2 for incomplete unexecuted coverage, or 0 only when all
  thirty cases actually pass. The current run exits **1**.
- The canonical W6 workflow packet is still blocked pending governed
  same-task continuation and independent re-review; neither W5 nor W7
  receives a release approval from this report.

No synthetic fixture success was counted as an application case, no
legacy OCP task was created, and no publication occurred.
