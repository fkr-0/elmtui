# 0.4.0 release status

**ElmTUI 0.4.0 is the current release.** It completes the API export cleanup: the root `elmtui` package is now a curated facade of the application API, and every exported symbol names a real binding. It is a breaking release for code that used `elmtui:` names other than the 13 it now exports, which were unbound until now; see the [changelog](https://github.com/fkr-0/elmtui/blob/main/CHANGELOG.md) for the migration notes. 0.3.2, the preceding patch release, made `deftea-app` applications run and added `key-pressed-p` and `quit-requested-p`. Release notes are on [GitHub](https://github.com/fkr-0/elmtui/releases).

Every release tag is qualified by the canonical `scripts/release-check.sh` gate in CI: warning-clean builds, the test suites, coverage, real-PTY and tmux end-to-end tests (including the README Quickstart and a `deftea-app` application), the Workbench, a check that no exported symbol is unbound, documentation freshness, a frozen source archive, a cold install and public dependency pins.

Qualified platform: SBCL on POSIX terminals. Dependencies are the pinned `cl-events`, `cl-inputs`, `cl-state` and `cl-styles` submodules; clone with `git clone --recurse-submodules https://github.com/fkr-0/elmtui.git`.

Known limitations:

- tmux width reflow of rows wider than a shrunken pane is not modelled.
- The optional Workbench keeps its own component version (0.1.0).

The release gate is `scripts/release-check.sh`.
