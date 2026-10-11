# Public API and Examples Release Hardening

## Goal

Prepare ElmTUI's consumer-facing API, documentation, and maintained examples for
the first release by making the supported surface clear, fixing verified
contract or documentation defects, and providing repeatable example coverage.

## Scope and approach

- Audit the package exports and documented entry points consumers are directed
  to use, while preserving the repository's explicit ownership boundaries for
  ElmTUI and `cl-events`, `cl-state`, `cl-inputs`, and `cl-styles`. Do not
  silently remove support-library bindings from the generated reference; qualify
  their ownership and links against the live export data.
- Inspect actual package exports, API declarations, docstring coverage,
  examples, and release tooling. Fix concrete consumer-facing defects and
  update directly affected documentation; avoid unrelated cleanup.
- Keep generated API references reproducible from live symbols, report coverage
  accurately in all landing pages, and ensure checked-in generated output is
  current.
- Exercise every runnable example in the maintained default ASDF system through
  non-interactive tests. Examples requiring tmux, NetworkManager, or optional
  dependencies must be isolated or gated, and all files in `examples/` must be
  classified as maintained, optional, support-only, or intentionally excluded.

## Validation

- Add or strengthen API contract checks for public package/export visibility,
  package ownership, and generated reference freshness.
- Run compilation and focused tests for any Lisp changes, then the applicable
  release checks.
- Run example end-to-end checks without requiring a real terminal or causing
  external network/system mutations; run environment-dependent checks only when
  their prerequisites are available and explicitly enabled.
- Confirm documentation commands, entry points, and limitations agree with the
  actual examples and ASDF systems.

## Non-goals

- Re-document every transitive support-library export in ElmTUI's own reference.
- Redesign the component or rendering architecture.
- Make optional or environment-dependent examples prerequisites for a normal
  checkout or default release test run.
- Claim a first-release-ready API merely by raising docstring coverage; behavior,
  export boundaries, example execution, and guide accuracy are all in scope.
