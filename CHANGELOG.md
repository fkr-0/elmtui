# Changelog

All notable release-facing changes are recorded here.

The project follows semantic versioning from the first published release.

## Unreleased

## [0.4.0] - 2026-11-01

Breaking release that finishes the API review's export cleanup. Every exported
ElmTUI symbol now names a binding (or a registered message/model schema), and
the release gate keeps it so.

### Changed (breaking)

- The root `elmtui` package is a curated facade of the application API. It
  imports and exports `defapplication`, `deftea-app`, `make-update-result`,
  `state-ref`, `key-pressed-p`, `quit-requested-p`, `key-event`,
  `key-event-p`, `key-event-key`, `key-event-char`, `key-event-modifiers`,
  `dark-theme` and `light-theme`. Until now it used UIOP `:reexport`, which
  exports by name only, so 127 of its 128 own exports (`elmtui:button`,
  `elmtui:vbox`, `elmtui:with-terminal-lock`, ...) were fresh, unbound symbols;
  those are gone, as is the re-exported `cl:use-value`.
- Removed `elmtui:dev-main` (a silent placeholder; use `elmtui.dev:dev-main`)
  and the `elmtui` system's program-op entry point that named it.
- Removed 88 exported names that had no definition: `defmsg`'s
  `<variant>-p` names (use the defined `<variant>-<message>-p` predicates),
  `elmtui.state.msg:statechangemsg`, `elmtui.state.model:transaction-source`,
  `elmtui.view.core:{accessible-p container get-prop has-prop-p hbox
  merge-props remove-prop set-prop text update-children update-props vbox
  widget}`, nine `elmtui.pipeline` stage names, eight `elmtui.view.geo` shape
  names, six canvas names in `elmtui.platform.backend.terminal`, six
  `elmtui.core.defaults` names, five `elmtui.view.styled` names,
  `elmtui.ui.api:{add-command add-patch get-property layout-node}`,
  `elmtui.view.api:{layout-view resolve-view stylable-id}`, and
  `property-exists-p`, `make-scrollable-container-model`,
  `compute-anchor-offset`, `make-listbox-model`, `grid-container`,
  `request-stop-input-reader`, `clip-coordinates`, `terminal-color-kv`,
  `with-terminal-output`, `interrupt-payload`, `message-p` and
  `elmtui.backend.urxvt:initialize-backend`.

### Migration

- Code that used `elmtui:` names other than the 13 above was calling unbound
  functions; use the defining packages (for example
  `elmtui.platform.backend.terminal:with-terminal-lock`), whose symbols are
  unchanged.
- Replace `<variant>-p` message predicates with `<variant>-<message>-p`, e.g.
  `keyevent-appmsg-p`.

### Added

- The `api_bindings` release gate allows no unbound exports; the audit
  recognises symbol macros and registered message/model schema names.

## [0.3.2] - 2026-11-01

### Fixed

- `deftea-app` applications now run. Their runners drew nothing and signalled
  a type error on shutdown, because the driver received a bare model instead of
  an application state; `deftea-app` only had macroexpansion tests.
  `deftea-app` now expands into `defapplication` (`:strict-elm`), keeping the
  model under `:tea-model`; views may still return a `:root-viewport` tree, and
  new optional `:anchor`/`:height` keys place the viewport. Ctrl-C, or a model
  with `:should-quit t`, quits.
- `elmtui.state` and `elmtui.state.api` exported fresh, unbound symbols instead
  of the ones they meant to re-export (UIOP `:reexport` exports by name only),
  so for example `elmtui.state.api:sapply`, `sref` and `defupdate` were
  unusable. They now re-export the working `elmtui.state.update`,
  `elmtui.state.model` and `cl-state` symbols; `diff-states` is the `cl-state`
  one.
- `elmtui.app.api:defapplication` is now the same symbol as
  `elmtui.app:defapplication`.
- `defmsg` exported `<variant>-p` predicate names it never defined; it now also
  exports the `<variant>-<message>-p` predicates it does define. The undefined
  names are deprecated.
- The `tmux-slider` example's arrow keys quit the app: its raw input loop read
  the ESC byte that starts an arrow sequence as the Escape quit key. Left/Right
  now set the direction and Up/Down (or `+`/`-`) change the speed; a bare
  Escape still quits.

### Added

- `elmtui.app:key-pressed-p` matches key messages by `:char`, `:key` and
  `:modifiers`; `elmtui.app:quit-requested-p` recognises Ctrl-C.
- Generated `run-NAME` functions accept `:log-file` and `:log-buffer`.
  `:initial-state-fn` may return startup commands as a second value.
- Release gates: `deftea_app` runs a `deftea-app` counter in tmux;
  `readme_quickstart` runs the README Quickstart and checks the website shows
  the same code; `api_bindings` (`scripts/audit-api-bindings.lisp`) forbids an
  increase in exported symbols with no binding (215 remain, removed in 0.4.0).
- `scripts/record-demo-media.py` records the website and release media from
  real example sessions; the website shows a Workbench still, the
  tmux-slider animation and recorded Workbench, neon-tetris and tmux-glider
  sessions.

### Documentation

- README: a tested Quickstart replaces the minimal-application, requirements
  and setup sections; stale status, release and tmux notes and a broken
  Workbench command were fixed. The website quickstart shows the same
  application.
- The `defapplication` docstring states the update-function contract,
  `:should-quit`, `run-NAME`, the root viewport `:height` rule and logging.
- The foundations chapter showed an application update taking an update
  context and calling the then-unbound `elmtui.state.api:sapply`; it now shows
  the `(message state)` patch contract and explains that contexts belong to
  component updates. The tutorial shows how to run its `deftea-app` counter and
  translate keys into messages, and that the counter widget moved to
  `elmtui-example-widgets`.
- `docs/reviews/api-review-20261101.md` reviews the exported API and its
  documentation; the website release page announces 0.3.1.

## [0.3.1] - 2026-11-01

### Fixed

- tmux normal-screen mode no longer loses or duplicates scrollback when the
  pane shrinks and grows while an app runs. The driver keeps a ledger of the
  logical underlay (rows tmux pulled back from history plus the launch
  capture), composites every frame over it, parks the cursor at row 0 after
  each diff and never paints pulled history rows; exit restore is
  top-anchored and scrolls back rows a shrink deleted.
- The tmux cursor inspector's B2 box is drawn at physical pane coordinates
  through a full-pane overlay, offset past protected history rows.
- A truncated `:below-cursor` root viewport is placed by its truncated
  height, so `wifi-inline` no longer blanks a history row.
- `tmux-hover-demo` loads `cursor-inspector` through ASDF from any launcher.
- The minimal example declares its viewport height, so a dumped binary
  renders when started on the terminal's last row.
- The wifi-inline e2e script loads `elmtui-examples-cli` instead of the
  removed `elmtui-tools` system.
- The tmux e2e harness traps SIGINT in its launch wrapper, so Ctrl-C quit
  tests no longer lose the pane on systems whose `/bin/sh` is dash.
- `scripts/examples.sh build` and `elmtui-packager` compress dumped cores only
  when SBCL was built with zstd (`:sb-core-compression`), instead of failing
  on runtimes without it.

### Added

- Regression suites: `normal-screen-overlay-tests` (ledger, compositor,
  protected rows, cursor parking, B2 overlay) and the un-xfailed tmux
  review-contract e2e.
- Release gates that quit every launcher example and a packager-dumped
  binary over 70 lines of tmux history and require exit 0, identical stty,
  a visible cursor and exact scrollback.
- A CI `publish-coverage` job that publishes the verified SB-COVER figure
  from a green `main` release gate to the `coverage-data` branch, and README
  CI and coverage badges. The coverage gate removes stale endpoint data
  before measuring.

### Known limitations

- tmux width reflow of rows wider than a shrunken pane is not modelled.

## [0.3.0] - 2026-11-01

Never tagged or published on its own: these changes first shipped in 0.3.1,
the first release whose commit passed the full release gate.

### Repository hygiene and developer entry points

- Rebuilt a sanitized Git lineage that removes root-level scratch scripts,
  obsolete Lisp launchers, non-release agent/plan documents, generated
  artifacts and transient directories from their first appearance onward.
  Publication of rewritten commit/tag identities requires coordination.
- Moved the maintained example CLI, tmux glider runner, test runner, coverage
  runner and Slynk launcher beneath `scripts/`. Root-level Bash and Lisp
  launchers (including the legacy `exe` command) are no longer supported;
  callers should use `scripts/examples.sh`, the release scripts or `bridge.yml`.
- Added a tracked purge manifest and automatic release/history hygiene tests.

### Licensing

- License new ElmTUI sources and distributions under MIT, consistent with its
  four MIT-licensed supporting libraries. Historical ElmTUI GPL-3.0-only
  revisions retain their original license terms.


### Added

- Added the `elmtui-example-widgets` system (keytester, keytester-map and
  counter example widgets) and moved buffer dumps, condition-preserving
  `WITH-BUFFER-DUMP-ON-ERROR` and process diagnostics into `elmtui-dev`.
- Added `elmtui-api-contract-tests` (documented API support levels),
  `elmtui-core-slim-tests`, and backend/defaults/focus/widget behaviour
  suites; `scripts/coverage-gate.py` enforces the reviewed SB-COVER source
  inventory and minimum.
- Added `*tmux-socket*` and `*tmux-target-pane*` so a process can address a
  tmux server and pane it owns without running inside tmux.
- Added `terminal-string-slice` for grapheme-preserving display-cell slices.
- Added `scripts/release-matrix-test.py` (frozen Git-vector source archive,
  checksum/provenance verification) and CI now runs the canonical
  `scripts/release-check.sh` with uploaded receipts.
- Added PTY/tmux release gates for the key tester, rainbow colour modes, the
  mini editor, dumped binaries, the packager and Wi-Fi robustness, and E3
  Workbench release suites.

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
- Added the `wifi-inline` maintained example: a below-cursor NetworkManager
  Wi-Fi scanner sharing the `wifi-menu` integration model, with escaped-SSID
  parsing, one-shot startup scan subscriptions, and two-step connect
  confirmation, covered by an offline unit suite and a fake-`nmcli`
  private-tmux e2e harness.

### Changed

- **Breaking:** the primary `elmtui` system no longer loads the example
  widgets or `dev/dev`; load `elmtui-example-widgets` or `elmtui-dev`.
- The Workbench renders through native DSL/flex panes instead of an
  application-owned character grid.
- `with-defaults` binds the defaults registry dynamically (thread-local and
  restored on unwind); ancestor overrides apply before the nearest context.
- `memoize` caches live in weak wrapper tables so dropped wrappers release
  their cached results; textinput keeps externally stored state with a
  character-index cursor.
- Rainbow examples choose truecolor, 256-colour or basic colours from
  `TERM`/`COLORTERM`.
- `elmtui-tests` aggregates the dev, API-contract and core-slim systems and
  its `test-op` signals on failure.
- Pinned `cl-events` 798cb3b, `cl-inputs` 10c75b3a, `cl-state` 91a29b7 and
  `cl-styles` e4d64c5 (all published).

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
- Restyled the `wifi-menu` example with the neon palette used by the Neon demo
  family (RGB fg/bg row roles, mint-on-navy selection highlight, amber status,
  lavender footer) and made its panel height adaptive: the panel renders at a
  four-row minimum before any scan, grows one row per discovered network, and
  windows the list around the selection with a bounded row maximum instead of
  a fixed-height list.

### Removed

- Removed the obsolete history-purge manifest document.

- Minimalized the tracked top level to the necessary configuration and
  load-bearing entry points: unreferenced legacy planning documents
  (`apispec.yml`, `architecture_design.md`, `contracts.md`,
  `PIPELINE_MIGRATION.md`, `PLAN.md`, `roadmap.org`) and superseded local
  runner/one-off scripts (`run.sh`, `rt.sh`, `run-tests.lisp`,
  `run-test.lisp`, `run-test-verbose.lisp`, `test-compile.lisp`,
  `run-dirlister*.lisp`, `run_canvas_examples.lisp`,
  `run-canvas-tests.lisp`, `run-tests-clpm-input.lisp`,
  `run-tests-clpm-styles.lisp`, `dev-setup.lisp`) were removed from the
  tree (working copies retained locally and ignored). CI-referenced
  runners, the CLPM bundle files, documented entry points (`examples.sh`,
  `exe`), and the coverage harness remain.
- Removed the process-global rendering diagnostics API, including
  `rendering-stats`, `get-rendering-stats`, and `reset-rendering-stats`.
  Pure diff metrics remain per-call values and output counters require
  an explicit terminal-instance.

### Fixed

- tmux capture parsing accepts only SGR and drops OSC, C1 and incomplete
  controls; failed tmux commands no longer yield stderr as cells. Restore
  after a resize copies only cells known in both geometries, and the driver
  owns terminal cleanup from the first backend-initialisation step.
- A self-sized root viewport keeps following later terminal resizes.
- Focus history navigation no longer cycles between two nodes; focus
  traversal understands lowered elements and canonical DSL nodes.
- Terminal styles compare the invisible attribute; box drawing restores the
  previous style on unwind and honours border colours.
- DSL resolution rejects improper, circular and over-deep forms with
  `invalid-dsl-form`; listbox clamps empty lists; scrollable-container
  matches its keyword messages.
- `wifi-menu` runs `nmcli` without a shell, with a deadline, an output limit
  and guaranteed child reaping; `mini-text-editor` accepts the adapter's
  character-key shape for Ctrl chords; `tmux-cursor-inspector` loads
  independently of the caller's FASL location.
- Workbench E3 defects: hidden selected inspector/completion rows in short
  viewports, lost editor input on tiny resizes, transcript over-scroll and
  regional-indicator/ZWJ cell alignment.

- Clipped terminal diff writes to physical pane cells, including double-width
  and combining glyphs, counted cursor movement in physical columns, and dropped
  combining marks belonging to clipped glyphs. Reconciled tmux underlay restoration
  after pane shrink/grow. Added focused regression coverage and a real tmux
  history/style, key movement, idle-output and terminal-cleanup E2E gate.
  On live pane shrink, tmux may temporarily move displayed overlay rows into
  scrollback; normal-screen mode guarantees preservation of older history and
  exact restoration after application exit, not zero transient scrollback writes.
- Hardened `wifi-menu` state reads against the hash-table state backend's
  representation of NIL-valued initial keys (empty hash tables): the busy flag
  now uses an explicit set-flag predicate and network lists are guarded before
  sequence operations, keeping refresh ticks, selection, and disconnect paths
  correct under both runtime and test-constructed application states.
- Recognized `:gray` and `:grey` as bright-black ANSI foreground/background
  colors, preventing workbench and other UIs from losing frames to the
  previously unrecognized semantic gray color.
- Repaired the remaining maintained directory, rainbow, keyboard-inspection,
  and tmux demonstrations: native Dirli list rendering/explicit Enter,
  deterministic colored rainbow glyphs and orientation changes, functional
  key tester edit/backspace/Escape paths, typed tmux-hover navigation, and
  delayed tmux-idle timer start to avoid state-transaction conflicts.
- Added isolated tmux PTY tests that seed 70 historical scrollback rows,
  snapshot the pre-app pane, verify animation/controls, and prove that all
  history rows and shell-underlay markers survive exit without leaked overlays
  or modified termios.

- Prevented the terminal driver from presenting startup frames before the
  below-cursor viewport scroll reservation. Startup now installs the cursor
  anchor before dimensions, defers frames through bootstrapping, and commits
  the first visual frame only after startup effects. Regression tests exercise
  Tetris at both the terminal top and bottom and verify no ghost drawing
  survives ordinary Q-key shutdown.
- Restored interactive terminal examples after the renderer and input refactor:
  typed application state exposes focused component keymaps, normalized
  `:keyevent` envelopes reach keymap dispatch, and unbound keys reach the
  application's update function. Semantic keys return through the active
  runtime mailbox rather than an unconsumed command queue.
- Normalize raw ASCII control chords (including Ctrl-Q) and route global
  quit/cancel to the application shutdown protocol. Destructive viewport
  blanking invalidates the previously presented frame for correct repaint.
- Fixed focus and keymap demo state conflicting with canonical
  `:components`, removed duplicate nested viewport IDs from glider, Pong,
  scroll and tmux hover demos, and replaced obsolete `:scroll-panel` DSL
  with state-driven paging. Preserve uppercase minimal-demo key display.
- Added a full 18-example initialization/render regression and typed-focus
  keymap tests; all nine live PTY example scenarios pass again.

- Fixed root-viewport readiness when terminal geometry is known but an
  initial cursor event or first-ready cleanup transition has not completed.
  Corrected below-cursor overflow accounting and shutdown scroll restoration.
- Initial terminal cursor probing now falls back to the tracked cl-inputs
  device coordinates when the routed query is unavailable, preserving
  one-based cursor events for root-viewport anchoring.
- Updated the DEFAPPLICATION render regression to compare frames through the
  resizing-aware presentation interface, and terminal shutdown regression
  to verify cl-inputs cleanup rather than obsolete stty subprocess handling.
- Scoped mainline runtime hygiene tests to exclude the separate optional Lisp
  workbench, where package introspection and defensive documentation probes
  are expected.
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
