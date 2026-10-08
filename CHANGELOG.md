# Changelog

All notable release-facing changes are recorded here.

The project follows semantic versioning from the first published release.

## Unreleased

### Added

- Added `elmtui.render.diff`, a terminal-independent virtual-frame differ with
  explicit first-frame policy and deterministic, per-call diff metrics.
- Added a swappable `elmtui.render.presentation` protocol with a recording
  presenter for TTY-free verification of write operations and buffer ownership.
- Added architectural contract, deterministic frame-replay, failed-presentation
  retry, compatibility, resize, and output-isolation regression tests.

- Added a centralized cooperative polling primitive in `cl-events` and migrated
  ElmTUI readiness/shutdown waits to it, with deterministic timeout and
  cancellation coverage.
- Added structured condition/restart recovery with preserved condition identity,
  debugger-visible context, and `retry`, `skip`, `ignore-task`, `use-value`, and
  `abort` recovery paths.
- Added transactional and `:strict-elm` application state semantics sharing one
  update/patch contract; strict mode uses frozen, structurally shared persistent
  snapshots with an eager persistent correctness oracle.
- Added a runtime context object and deterministic runtime/state/async E2E
  coverage, including retained-snapshot and differential state-engine traces.
- Added explicit renderer overflow semantics: descendants remain visible by
  default, while `:overflow :hidden` clips to nested content-box intersections.
- Added terminal image fallback rendering using `:alt` text or `[image]` and
  regression coverage for source-order sibling painting.
- Added maintained REPL/runtime introspection and optional `elmtui-dev` benchmark
  tooling with deterministic result-shape/baseline tests; benchmark artifacts are
  written beneath the repository rather than system temporary directories.
- Added warning-clean coverage execution and bridge commands for benchmarks,
  documentation generation/audit, and focused example verification.

### Changed

- Routed the display pipeline through the presenter interface; unchanged frames
  perform no backend writes or flushes and rejected frames do not advance the
  authoritative front buffer. Idle event-driven periods do not render.
- Moved cell comparison/batching out of the terminal backend; the terminal
  diff wrapper is stateless. Terminal output counters now belong to each
  `terminal-instance`, with explicit snapshot/reset operations, and are
  independent across multiple terminals.
- `present-frame` now optionally returns pure diff metrics as a third value,
  preserving its first two return values for existing callers.

- Replaced the embedded `cl-events`, `cl-inputs`, `cl-state`, and `cl-styles`
  source trees with Git submodules pinned to their standalone repository commits;
  ElmTUI integration tests now target the current `cl-inputs` public and optional
  `cl-inputs/events` adapter contracts rather than historical in-tree internals.
- `DEFAPPLICATION` is the recommended full application constructor while
  `DEFTEA-APP` remains the supported minimal direct-transition adapter.
- Public `APPLICATION-STATE-DATA` compatibility reads now return owned snapshots;
  explicit live representation access remains confined to `cl-state.core`.
- Removed large commented legacy implementations from `cl-inputs` input decoding
  and loop code after executable behavior was covered independently.
- Normalized ElmTUI terminal geometry and color aliases through `cl-styles`, while
  retaining inline-style priority and the existing flex/grid layout model.

### Removed

- Removed the process-global rendering diagnostics API, including
  `rendering-stats`, `get-rendering-stats`, and `reset-rendering-stats`.
  Pure diff metrics remain per-call values and output counters require
  an explicit terminal-instance.

### Fixed

- Eliminated process-wide first-render state from frame comparisons, including
  independent initial frames and resize handling for multiple presenters.

- Fixed observer failure reporting and transaction rollback/notification ordering
  so failures remain inspectable without silently corrupting transaction state.
- Fixed inherited component update composition, keymap/runtime polling edge cases,
  and async completion/error recovery contracts exposed by the expanded E2E suite.
- Fixed the real blank-TUI regression by making primitive `:text`, `:label`, and
  `:button` tags win at render time and preserving NIL as the pre-layout rectangle
  sentinel instead of synthesizing a zero-sized box.
- Replaced broad renderer/layout/terminal exception probes with maintained-type
  checks or narrow, logged teardown handlers; buffer/diff conditions now join the
  structured ElmTUI error hierarchy.
- Fixed enhanced label style construction and preserved arbitrary button action
  payloads through the widget contract.
- Fixed reactive state dependencies so observer invalidations schedule an actual
  debounced render instead of returning an uninterpreted async command; cleanup
  now cancels pending debounce work before shutting the view down.

- Quarantined local debug, review, generated-release, editor, and agent artifacts
  from the release surface without deleting preserved workspace material.
- Archived superseded root-level implementation and design notes under
  `docs/archive/legacy-root-notes/`.
- Clarified that `actiwat` is an independent consumer/application repository,
  not a reusable ElmTUI release member.
- Added standalone README/changelog/CLPM bundle contracts for `cl-events`,
  `cl-inputs`, `cl-state`, and `cl-styles`, with path-independent regenerated locks.
- Split generic `cl-inputs` from its optional `cl-events` integration; the
  `cl-inputs/events` secondary system now owns event-bus adapter code while
  compatibility entry points remain available from `cl-inputs.sink`.
- Extended the release gate to run every reusable subsystem under both its own
  CLPM bundle and the root integration bundle.

## [0.2.0] - 2026-07-10

First public-release candidate.

### Added

- Independent ASDF test gates for `cl-events`, `cl-inputs`, `cl-state`, and
  `cl-styles`.
- A documented ownership model for reusable libraries versus ElmTUI adapters.
- Transactional batch patch application for `application-state`, including
  undo/redo of removals.
- Canonical style-property aliases, including `background` to
  `background-color`, and an `opacity` property contract.
- Curated example documentation and reproducible subsystem/release scripts.
- Internal literal-string helpers for trimming, blank checks, prefix checks, and
  bounded splitting without pulling a regex stack into the runtime.
- Root GPL-3.0-only and per-library MIT license files.

### Changed

- Generic event, input, state, and style mechanics are factored into the four
  `cl-*` systems; ElmTUI retains UI/runtime policy and thin adapters.
- `cl-events` is now tracked directly in the release tree instead of through a
  self-referential local submodule, making fresh clones and source archives
  self-contained.
- `elmtui.utils` now delegates nested path operations to `cl-state` and contains
  only one conversion protocol.
- `cl-state` schema and model validation share one type registry.
- `cl-inputs` tests are modular, ASDF-discoverable, and fail the build on failed
  checks.
- `cl-state` and `cl-styles` runners now return failing ASDF operations when
  checks fail instead of only printing summaries.
- Key canonicalization uses stable `C-`, `M-`, and `S-` modifier prefixes.
- The `cl-fzy` picker is an explicit optional example system; the default
  examples and release tests have no sibling-checkout dependency.
- CLPM metadata is path-independent and now includes the previously omitted
  enhanced-widgets ASD.
- SLY/Slynk development dependencies are isolated in `dev/clpmfile`; the main
  release/test lock contains no editor-server packages.
- System metadata no longer contains placeholder authors or a nonexistent
  source-control URL.

### Fixed

- Missing `channel-remove-filter` import in the ElmTUI event-channel adapter.
- Invalid internal UIOP program lookup in tmux executable detection.
- Hidden `cl-inputs` keymap, decoder, ANSI, fake-terminal, and API test defects.
- State validation conditions, nested model validation, built-in predicates,
  observer cleanup expectations, and single-key patch shorthand.
- Macro normalization of `#'(lambda ...)` function forms.
- Multi-key binding parsing and serialization, including the leading-space bug
  in canonical sequence keys.
- Grid `minmax(...)` parsing and decimal `fr` track values without reversed
  prefix checks or integer-only parsing.
- Compile-time undefined-function and unused-variable warnings in a forced clean
  load.

### Removed

- Orphaned legacy event-filter and topic-subscription implementations that were
  not part of the ASDF load graph.
- Duplicate path traversal and duplicate conversion implementations from
  `src/utils.lisp`.
- The undiscoverable standalone `cl-inputs-tests.asd`; its secondary system now
  lives in `cl-inputs.asd` as required for reliable ASDF discovery.
- The direct `str`/`cl-str` runtime dependency and its unnecessary Unicode/regex
  dependency chain.
- Duplicate `cl-events` package-manager locks, local runners, empty test files,
  and completed implementation-plan artifacts inherited from the old submodule.
- The hard-coded Slynk/Emacs bootstrap and its explicitly obsolete `bad`
  variant; the replacement launcher uses only the CLPM development bundle and
  an environment-configurable port.

### Known limitations

- The qualified release platform is SBCL on POSIX-like systems.
- Live tmux integration tests require an active tmux session and are opt-in.
- A public repository URL, release tag, and signed distribution artifacts are
  not configured yet.
