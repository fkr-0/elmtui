# Changelog

All notable release-facing changes are recorded here.

The project follows semantic versioning from the first published release.

## Unreleased

### Changed

- Quarantined local debug, review, generated-release, editor, and agent artifacts
  from the release surface without deleting preserved workspace material.
- Archived superseded root-level implementation and design notes under
  `docs/archive/legacy-root-notes/`.
- Clarified that `actiwat` is an independent consumer/application repository,
  not a reusable ElmTUI release member.

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
