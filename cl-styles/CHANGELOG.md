# Changelog

All notable changes to `cl-styles` are recorded here. The library follows semantic versioning independently of ElmTUI.

## Unreleased

Candidate version: **0.2.0**. This remains an in-tree candidate and is not a
registry publication or separate-repository release.

### Added

- Terminal geometry declarations for offsets and scroll positions.
- Canonical property aliases for TUI color/background values.
- Expanded flex/gap, border, selector, inheritance, variable, and edge-case coverage.
- Path-independent local CLPM bundle metadata.

### Changed

- Property normalization now happens at the reusable styling boundary instead of in renderer-specific compatibility code.
- The CSS-like selector/cascade/property engine remains independent of ElmTUI widgets and rendering policy.

## 0.1.0

- Initial CSS-like selector, rule, stylesheet, token, property, protocol, and cascade engine.
