# ElmTUI examples

The `elmtui-examples` ASDF system contains the maintained applications used by
smoke tests and manual verification. Load the system once, then call an
example's exported runner.

```sh
clpm bundle exec --with-client sbcl -- \
  --noinform \
  --eval '(require :asdf)' \
  --eval '(asdf:load-system "elmtui-examples")' \
  --eval '(elmtui.examples.minimal:run-minimal)'
```

Most examples use the terminal backend and are interactive. Exit keys vary by
example; `q`, `Escape`, and `Ctrl-C` are the common choices.

## Start here

| File | Entry point | Demonstrates |
|---|---|---|
| `minimal-app.lisp` | `elmtui.examples.minimal:run-minimal` | Small TEA application, state patching, text rendering |
| `keymap-app.lisp` | `elmtui.examples.keymap:run-keymap` | Application keymaps and command dispatch |
| `focus-simple.lisp` | `elmtui.examples.focus-simple:run-focus-simple` | Focus traversal and button activation |
| `mini-rainbow.lisp` | `elmtui.examples.mini-rainbow:run-mini-rainbow` | Compact styled layout |
| `scroll-panel-demo.lisp` | `elmtui.examples.scroll-panel-demo:run-scroll-panel-demo` | Scrollable content and viewport behavior |
| `mini-text-editor.lisp` | `elmtui.examples.mini-text-editor:run-mini-text-editor` | Editable multiline text buffer, cursor navigation and async file saving |
| `neon-pong.lisp` | `elmtui.examples.neon-pong:run-neon-pong` | Neon Circuit: two-player Pong with live match telemetry |
| `neon-tetris.lisp` | `elmtui.examples.neon-tetris:run-neon-tetris` | Stack Lab: falling blocks, ghost piece, lines and side panel |
| `neon-nano.lisp` | `elmtui.examples.neon-nano:run-neon-nano` | Midnight Editor: styled Nano-style editor with safe file saving |
| `neon-less.lisp` | `elmtui.examples.neon-less:run-neon-less` | Deep File Viewer: numbered, read-only pager |

## NILMSP-inspired Neon Quartet

These four ElmTUI-native ports reproduce the presentation and main interactions
of `/home/user/code/nilmsp/release/nilmsp-tea/poc-apps/{pong,tetris,nano,less}.nl`.
They use ElmTUI's normal DSL and terminal diff presenter, not embedded ANSI
escapes or independent renderers. Each app has a cyan/violet midnight palette,
telemetry or line-number panels, a footer help strip, and stable row IDs.

```sh
./scripts/examples.sh run neon-pong       # W/S left paddle, I/K right, Space serve, Q exit
./scripts/examples.sh run neon-tetris     # A/D move, W rotate, S drop, R reset, Q exit
./scripts/examples.sh run neon-nano       # arrows edit, Ctrl+O save, Ctrl+X exit
./scripts/examples.sh run neon-less       # J/K scroll, F/Space forward, B back, g/G ends, Q
```

For file-backed tools, set `ELMTUI_NANO_FILE=/path/to/notes.txt` or
`ELMTUI_LESS_FILE=/path/to/document.txt` before launch. Alternatively, load
`elmtui-examples` and invoke the exported runner with `:path`. Less uses a
demonstration document when no filename is provided; Nano opens a scratch
buffer. Nano reuses the mature Mini Text Editor state machine and therefore
adds Unicode editing, save-as, overwrite confirmation and unsaved-change
dialogues beyond the ASCII-only NILMSP prototype.

Only Pong and Tetris subscribe to game ticks. Nano and Less are event-driven;
unchanged updates produce no state patches. The UI is designed for a terminal
of at least 74 columns and 24 rows. Rendering uses a Unicode-capable font.

Run the isolated suite with `projmgrauth` command `test-neon` or directly:

```sh
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:test-system "elmtui-neon-tests")'
```

For black-box terminal startup, controls, clean exit and idle-write checks,
run the bridge command `test-neon-pty` (or `python3 tests/neon-pty.py`).

## Mini text editor

A compact, file-backed editor illustrating ElmTUI's state/update/view lifecycle.
Start a scratch buffer with `./scripts/examples.sh run mini-text-editor`, or edit a
UTF-8 text file by setting `ELMTUI_EDITOR_FILE`:

```sh
ELMTUI_EDITOR_FILE=/tmp/notes.txt ./scripts/examples.sh run mini-text-editor
```

From Lisp, load `elmtui-examples` and call
`(elmtui.examples.mini-text-editor:run-mini-text-editor :path "/tmp/notes.txt")`.
The file is read at startup and written **only** on Ctrl+S. A scratch
buffer opens a **Save As** dialog to choose its filename; overwriting an
existing file requires confirmation. Ctrl+Q or Escape quits clean buffers.
When the buffer is modified, a bordered modal asks for Save [s], Discard [d]
or Cancel [c / Enter / Esc]. Saving a nameless buffer from that dialog opens
Save As and quits only after a successful save. Arrows, Home/End, Page Up/Down,
Enter, Backspace, Delete and Tab are supported. A star in the header indicates
unsaved changes. Saving runs as an asynchronous command so the TEA update
function remains pure; modifications during a save retain the dirty flag.
The cursor is rendered visibly inside the buffer; no terminal-wide redraw is
requested while idle. The frame and dialogs use ElmTUI's rendering pipeline.
The dialog state, keyboard capture and bounded five-row presentation are reusable
through `elmtui.ui.widgets.modal-dialog` (`open-modal-dialog`, `modal-handle-key`,
`modal-dialog-view`). This is **modal-in-flow rendering**, not a compositor overlay:
the hosting application routes keys to the dialog and reserves five content rows.
The dialog result includes a return-focus token; focus restoration requires the
host to apply it. Current limitations: fixed 12-row viewport, no undo,
mouse editing, syntax highlighting or framework-managed overlay stacking. For safety, a failed load aborts launch
rather than silently replacing an existing unreadable file.

## Input and terminal inspection

| File | Purpose |
|---|---|
| `key-tester.lisp` | Inspect decoded keyboard events |
| `cursor-inspector.lisp` | Inspect cursor and terminal positioning behavior |
| `input-selector.lisp` | Select and exercise input-related behavior |
| `root-viewport-test-app.lisp` | Exercise root viewport anchoring and lifecycle |

## Larger application examples

| File | Purpose |
|---|---|
| `game-of-life.lisp` | Stateful grid simulation |
| `glider-real.lisp` | Animated grid/rendering example |
| `fzf-finder-real.lisp` | Finder-oriented application flow |
| `dirli.lisp` | Directory-listing application |
| `wifi-menu.lisp` | Live NetworkManager Wi-Fi selection driven by `nmcli` |
| `wifi-inline.lisp` | Inline below-cursor Wi-Fi scanner driven by `nmcli` |
| `pong-below-cursor.lisp` | Inline animation below the current cursor |

The old nested `examples/dirlister_poc/` prototype has been retired. It had an
invalid program entry point and duplicated the maintained `dirli.lisp` example.
Use `elmtui.examples.dirli:run-dirli` for directory-listing work.

## NetworkManager Wi-Fi menu

`wifi-menu.lisp` is a maintained example for stateful external-command
integration. It requires NetworkManager's `nmcli` executable. The menu refreshes
visible access points asynchronously, supports explicit rescans, connects to the
selected SSID, and can disconnect the selected Wi-Fi device.

```lisp
(asdf:load-system "elmtui-examples")
(elmtui.examples.wifi-menu:run-wifi-menu)
```

Passwords are masked in the UI and are passed to `nmcli --ask` through standard
input rather than process arguments. Merely loading or testing the example does
not connect to or disconnect from a network; those mutations require explicit
interactive user actions.

## Inline Wi-Fi scanner

`wifi-inline.lisp` is the below-cursor companion to the full-screen menu: it
anchors a compact scan results panel under the current cursor position, shares
the `nmcli` integration model above, and restores the captured underlay on
exit. The `ELMTUI_NMCLI` environment variable overrides the `nmcli`
executable; the offline test suite exercises the escaped-SSID parser and state
transitions with a fake binary (see `tests/wifi-inline-tests.lisp` and
`scripts/test-wifi-inline-e2e.sh`).

```lisp
(asdf:load-system "elmtui-examples")
(elmtui.examples.wifi-inline:run-wifi-inline)
```

## Optional `cl-fzy` example

`fzy-picker.lisp` is intentionally separate from the maintained base system so
a normal ElmTUI checkout does not require an external sibling repository. After
installing the `cl-fzy` ASDF system, load:

```lisp
(asdf:load-system "elmtui-examples-fzy")
(elmtui.examples.fzy-picker:run-fzy-picker)
```

The optional system is declared in `elmtui-examples-fzy.asd` and is not part of
the default release test graph. Its loader lives under `examples/support/` so
support code is not mistaken for a runnable example. If `cl-fzy` is absent, the
optional system reports a concise actionable diagnostic and points to the
built-in `fzf-finder-real` alternative.

## Optional, integration and support files

These source files are intentionally not all standalone members of the default
smoke-tested example set:

| File | Classification |
|---|---|
| `async-weather.lisp` | Optional live Open-Meteo client; requires `curl`, `jq`, and network access. |
| `fzy-picker.lisp` | Optional `elmtui-examples-fzy` integration; requires `cl-fzy`. |
| `neon-kit.lisp` | Shared palette and rendering support for the Neon examples; not an application runner or CLI entry. |
| `tmux-glider.lisp` | Optional overlay animation; requires a live tmux pane and preserves the captured underlay. |
| `tmux-slider.lisp` | Optional styled tmux-pane animation; requires a live tmux pane. |
| `workbench.lisp` | Standalone local developer launcher; loads the separate `elmtui-workbench` system and is not exposed by `scripts/examples.sh`. See the [workbench guide](../docs/workbench-user-guide.md) for its direct launch command. |

Launch the weather dashboard with `./scripts/examples.sh run async-weather`. It starts
with Berlin; use `/` to enter another city or `LAT,LON`. Lisp callers can pass
an initial city with
`(elmtui.examples.async-weather:run-async-weather :city "Tokyo")`. The example
talks to the public Open-Meteo endpoints when launched; it is not used by the
offline example smoke or PTY tests. The tmux animations are also separate from
the private-tmux example suite: they operate on the user's current pane and
should only be launched intentionally. The `fzy-picker.lisp` loader is
`examples/support/fzy-loader.lisp`.

`./scripts/examples.sh list` includes only files with runnable example entry points;
the support-only `neon-kit.lisp` and standalone `workbench.lisp` are excluded.

## Repaired directory, rainbow and key-inspection examples

`dirli.lisp` now renders its list as native ElmTUI text rows; arrows (or
`j`/`k`) move the selection without inadvertently entering a directory.
Only Enter opens the selected directory; `q` exits.

`rainbow-app.lisp` and `mini-rainbow.lisp` display deterministic colored
glyph bands (rather than blank background boxes). Space toggles horizontal
and vertical layouts; `q` exits. `key-tester.lisp` displays printable keys
and their normalized names; Backspace edits and Escape clears the input.

Run the private-terminal regression sweep, including the tmux restore cases:

```sh
python3 tests/e2e/tmux-scrollback-restoration.py
```

## Tmux examples

| File | Purpose |
|---|---|
| `tmux-glider.lisp` | Overlay a Conway glider while restoring the captured pane content |
| `tmux-hover-demo.lisp` | Capture and display tmux pane content |
| `tmux-idle-screensaver.lisp` | Tmux-aware idle application and timer subscriptions |
| `tmux-slider.lisp` | Animate a styled band over captured pane content |

Tmux examples require a running tmux session. The automated live integration
checks are gated behind:

```sh
ELMTUI_RUN_TMUX_INTEGRATION=1 scripts/release-check.sh
```

The live-pane animations can be launched intentionally with
`./scripts/examples.sh run tmux-slider` or `./scripts/examples.sh run tmux-glider`.

## Example contract

A maintained example must:

1. Be listed in `elmtui-examples.asd`, or in a clearly documented optional
   example system when it requires an external integration.
2. Compile during the root test suite.
3. Export a stable runner where the application is intended for manual use.
4. Avoid relying on generated binaries checked into the repository.
5. Use public or documented adapter APIs rather than copying subsystem logic.

Experimental snippets and debugging reproductions belong outside the maintained
ASDF example system until they satisfy this contract.

## Neon Life and Glider (animated)

These dashboard apps use the ElmTUI diff renderer and shared `neon-kit` RGB palette (no raw ANSI).
Their application sources are `neon-life.lisp` and `neon-glider.lisp`; both use
the support component in `neon-kit.lisp`.

```sh
./scripts/examples.sh run neon-life
./scripts/examples.sh run neon-glider
```

`neon-life` simulates Conway B3/S23 on a toroidal 36x16 grid with two gliders
and a blinker. Status shows generation, live-cell population and tick period.
`neon-glider` animates a bouncing particle with an eight-position comet trail,
direction readout and per-frame position telemetry.

Both have cyan/violet/amber panels and square-corner frames. Use Space/P to
pause, N to step while paused, +/- to adjust speed, R to reset and Q/Escape
to exit. Pausing removes the periodic timer subscription.

The original entry points are also available:

```sh
./scripts/examples.sh run game-of-life
./scripts/examples.sh run glider-real
```

`glider-real` preserves `elmtui.examples.glider:run-glider-animation` and
`glider-animation-app` while delegating rendering and physics to neon-glider.
The maintained `game-of-life` preserves its original 20×40 glider physics,
Space/S/R controls, and standalone runner, but now uses a 74-column, square-frame
neon dashboard with a live generation and population display, the side telemetry
panel and additional P (pause) / N (step) aliases. Both original and neon
variants fit an 80×24 terminal without relying on rounded corners.

Run the state-machine suite and PTY lifecycle checks:

```sh
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --eval '(require :asdf)' --eval '(asdf:test-system "elmtui-neon-tests")'
python3 tests/e2e/neon-life-glider-pty.py -v
```

## Example verification

Run the complete Lisp test suite and the broader private-terminal example
lifecycle suite from the repository root:

```sh
./rt.sh
python3 tests/e2e/extended-examples-pty.py -v
```

The PTY suite requires Python 3, `tmux`, `clpm`, and SBCL. It starts isolated
tmux servers and fresh Lisp processes; it does not connect to Wi-Fi or operate
on the user's tmux session. Per-case transcripts, frames, terminal settings,
and exit status are written under
`/tmp/elmtui-extended-evidence-20261009`.

The live tmux integration gate is intentionally opt-in and uses the current
tmux environment:

```sh
ELMTUI_RUN_TMUX_INTEGRATION=1 scripts/release-check.sh
```

The PTY suite checks timer advancement, frozen frames while paused, exact
single-step, reset, Q exit and restoration of terminal attributes.

## Tmux scrollback glider — real Conway cells over existing terminal text

From inside a tmux pane, run:

```sh
./scripts/run-glider.sh
```

This is **not** the separate `neon-glider` bouncing-particle demo or the
full-grid `game-of-life` dashboard. The scrollback glider is the classic
five-cell Conway B3/S23 shape. Every four generations it translates diagonally
up-left across the current tmux pane. It mirrors its shape when it reaches a
horizontal border, then resumes traveling in the opposite horizontal direction;
at the top it can leave the visible screen.

It snapshots the original pane's characters **and SGR colors/attributes** before
starting. Each animation frame overwrites only the few live cells. When a
cell is vacated, its original character and style are restored in place. The
normal tmux history is never rewritten or cleared, no alternate screen is used,
and the terminal cursor and input mode are restored on exit. The real terminal
content remains in place rather than being replaced with a full-screen TUI.
The current glider animates within the *visible pane*; earlier, offscreen tmux
history remains intact and can still be inspected after the animation.

Controls: **Space/P** pause or resume, **N** single-step while paused,
**R** restart, **Q** quit. Natural movement ends when the glider leaves the
top. Without tmux the command fails safely without changing the terminal.

```sh
python3 tests/e2e/tmux-glider-pty.py -v
```

The private-tmux suite checks actual moving five-cell frames, 4-generation
Conway translation, horizontal reflection, pause/step, SGR restoration,
non-destructive terminal output, preserved history, and termios restoration.
