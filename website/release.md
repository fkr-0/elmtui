# 0.3.1 release status

**ElmTUI 0.3.1 is released.** It is the first release since 0.2.0 and includes the 0.3.0 feature line; 0.3.0 was never tagged on its own. See the [GitHub release](https://github.com/fkr-0/elmtui/releases/tag/v0.3.1) for notes and recordings, and the [changelog](https://github.com/fkr-0/elmtui/blob/main/CHANGELOG.md) for details.

The `v0.3.1` tag was qualified by the canonical `scripts/release-check.sh` gate in CI: warning-clean builds, the test suites, coverage, real-PTY and tmux end-to-end tests, the Workbench, documentation freshness, a frozen source archive, a cold install and public dependency pins.

Qualified platform: SBCL on POSIX terminals. Dependencies are the pinned `cl-events`, `cl-inputs`, `cl-state` and `cl-styles` submodules; clone with `git clone --recurse-submodules https://github.com/fkr-0/elmtui.git`.

Known limitations:

- tmux width reflow of rows wider than a shrunken pane is not modelled.
- The optional Workbench keeps its own component version (0.1.0).

See the [release checklist](https://github.com/fkr-0/elmtui/blob/main/docs/release-checklist.md) for the qualification record.
