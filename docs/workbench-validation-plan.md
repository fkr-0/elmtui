# ElmTUI Lisp Workbench — independent qualification plan

This plan is a **test specification**, not evidence that the workbench currently passes. The machine-readable cases are in `tests/workbench/qualification-matrix.json`; the catalog-integrity test is `tests/workbench/test_qualification_matrix.py`. All test-case statuses begin `not-run` intentionally.

## Commands

- Validate test specification: `python3 -m unittest discover -s tests/workbench -p 'test_qualification_matrix.py' -v`
- Run existing ElmTUI baseline: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load scripts/run-tests-clpm.lisp` (capture warnings, failures and known existing failures separately).
- After W1–W4 APIs stabilize: run each workbench package's FiveAM suites through CLPM/SBCL; compilation success alone is not a test pass.
- After W5 launcher exists: run full real PTY workbench scenarios at 80×24, 120×40 and 160×50; use independent `tmux -S` session/PTY and preferably native urxvt/Xvfb cross-check.
- PTY fixture must capture `stty -g` before/after, stdout/stderr independently, raw ANSI writes, screen captures, cursor coordinates, exit code, wall-clock time and process cleanup.

## Reviewer release gates

1. **Source provenance:** Only owners' claimed files changed; no shared runtime overwrite or unintended submodule changes; manifests and CLPM dependency resolution audited.
2. **Module APIs:** editor/eval/completion/inspector contracts are stable and callable from actual app; package imports/exports and ASDF loading order are correct; Slynk is optional.
3. **Correctness:** error recovery; persistent Lisp namespace; multiple-value semantics; no passive eval; safe bounded previews, cyclic printing and stale async result filtering.
4. **Interactive proof:** cursor-anchored above popup, timed docs, actual keyboard codes, responsive cancel/resize, narrow/large layouts.
5. **Terminal safety:** no unbounded repaint; no frozen input; no leaked worker threads or cursors; termios restored even on interrupt/failure.
6. **Verdict:** different reviewer than author, with exact command, exit code, pass/fail/skip, warnings, reproducible artifacts and review decision.

## Workflow

Do not approve a packet merely because the worker says it is done. Inspect its submitted changed paths, tests, actual source, and independent review policy. Mark incomplete features `revision_required` with actionable findings; use packet-local recovery for crashed/dirty leases and never issue a duplicate task until canonical OCP state is reconciled. Validation and reviewer workers own only new narrowly scoped paths and workflow reviews; no edits to W1–W5 files. The QA worker must replace catalog status only in a separate evidence artifact, not by writing optimistic `passed` into the planned matrix.

## Important gaps for W6 validation implementation

Implement runnable PTY cases rather than only this metadata smoke test. Reuse `scripts/test-terminal-apps.py` concepts but do not modify that existing release harness. Ensure terminal escape sequences are parsed by a terminal emulator, not asserted as substrings of stdout. Maintain a fixture per test with no actual host Wi-Fi, no remote network listener, and no unrestricted eval of untrusted files. Test parser-safety sentinel `#.(error "...")` only through passive completion path, not executing source. Delayed documentation must be verified by timestamped captures without fixed sleeps in the product application.
