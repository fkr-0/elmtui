# Release repairs implementation plan

**Goal:** Resolve the findings in `docs/reviews/release-readiness-20261026.md`.
**Architecture:** Retain the shared ElmTUI runtime and compatible entry points.
Workbench emits semantic pane/text/overlay DSL; ElmTUI owns geometry and painting.
**Tech stack:** Common Lisp, ASDF/CLPM, FiveAM, Python PTY tests.
**Constraints:** Preserve unrelated dirty changes. No publication or tag changes.

- [x] Repair component syntax rewriting and inherited update dispatch against
  the already failing FiveAM regressions; remove obsolete unloaded duplicate
  sources that confuse source qualification only after checking references.
- [x] Include API/core-slim suites in the default test runner and CI; configure
  the workbench black-box launcher. Preserve standalone test entry points.
- [x] Add a failing cache-lifetime regression, fix weak ownership, and preserve
  function/wrapper invalidation. Restore ignored legacy loop keyword behavior
  with a documented deprecation contract and test it without leaking threads.
- [x] Replace workbench character-array painting with native pane/text DSL;
  keep compatibility frame helpers only if needed. Add full rendered Unicode,
  style, clipping and cursor checks, then exercise completion/inspector in PTY.
- [x] Run root warning-clean, focused acceptance, workbench full black-box,
  PTY, coverage, packaging and release checks. Record exact source/submodule
  state and any remaining immutable-candidate limitation.

## Developer utilities extension (user request during implementation)

- Review the ASDF-loaded `src/dev/dev.lisp` and `benchmark.lisp`, and inventory
  unloaded legacy developer files without silently promoting their APIs.
- Add regressions for grapheme-aware dumps, original-error/restart preservation,
  bounded cyclic tree inspection, native DSL preview, invalid benchmark
  comparisons, and data-only baseline reading.
- Enhance maintained diagnostics and microbenchmarks; keep them opt-in and
  terminal-independent. Move benchmark tests under `tests/dev`, make the
  standalone developer test system run both diagnostics and benchmarks, and
  include it in root acceptance.
- Write a developer guide with runnable examples, returned metrics and limits;
  run standalone developer tests, root tests and final release qualification.

## Coverage follow-up (user request during handoff)

- [x] Compare weighted per-source SB-COVER expression gaps against the frozen
  47.68% candidate, retaining all 88 mandatory files.
- [x] Add independent focus and widget behavioral suites plus backend/style and
  scoped-default suites; repair defects exposed by their failing regressions.
- [x] Independently review the repairs and recheck all reported edge cases.
- [x] Measure 55.52%, raise the ratchet to 55.0%, and isolate instrumented FASLs
  from ordinary developer compilations.
- [x] Freeze and qualify the updated candidate; persist final evidence.
