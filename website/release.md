# 0.3.2 release status

**ElmTUI 0.3.2 is the current release.** It fixes the problems the [API review](https://github.com/fkr-0/elmtui/blob/main/docs/reviews/api-review-20261101.md) found without breaking compatibility: `deftea-app` applications run, the state facades export their working symbols, and `elmtui.app` gains `key-pressed-p` and `quit-requested-p`. See the [GitHub releases](https://github.com/fkr-0/elmtui/releases) for notes and the [changelog](https://github.com/fkr-0/elmtui/blob/main/CHANGELOG.md) for details. The next minor release, 0.4.0, curates the root `elmtui` package and removes exported names that were never implemented.

Every release tag is qualified by the canonical `scripts/release-check.sh` gate in CI: warning-clean builds, the test suites, coverage, real-PTY and tmux end-to-end tests (including the README Quickstart and a `deftea-app` application), the Workbench, an unbound-export ratchet, documentation freshness, a frozen source archive, a cold install and public dependency pins.

Qualified platform: SBCL on POSIX terminals. Dependencies are the pinned `cl-events`, `cl-inputs`, `cl-state` and `cl-styles` submodules; clone with `git clone --recurse-submodules https://github.com/fkr-0/elmtui.git`.

Known limitations:

- tmux width reflow of rows wider than a shrunken pane is not modelled.
- The optional Workbench keeps its own component version (0.1.0).

See the [release checklist](https://github.com/fkr-0/elmtui/blob/main/docs/release-checklist.md) for the qualification record.
