# ElmTUI examples — capability atlas

> **One example, one visible promise.** An ElmTUI example should be something
> you can demonstrate in front of another developer, not merely a file that
> loads. This index covers **every top-level `examples/*.lisp` source** in
> the checkout as of 2026-10-22, including the interactive REPL entry. It records the current implementation and the
> specific experience each example should own.

The [examples guide](../examples/README.md) contains longer usage notes.
The [source directory](../examples/) is authoritative for behavior. This index
is a **showcase specification and inventory**, not a certification that every
example already meets the entire quality bar below.

## Five-minute tour

Start in the repository root. The first four need no external service;
acts five and six demonstrate *normal-screen, no-alternate-screen* tmux
integration, and the final act opens the full interactive Lisp REPL.

| Act | Example | The claim the audience should leave with | Action |
|---|---|---|---|
| 1. Build | [`minimal-app`](../examples/minimal-app.lisp) | ElmTUI makes state → update → view feel small and understandable. | Press keys; observe the patched label. |
| 2. Interact | [`focus-simple`](../examples/focus-simple.lisp) | Keyboard focus, selection and component messages are first-class. | Tab between the list and buttons; navigate and activate. |
| 3. Ship | [`mini-text-editor`](../examples/mini-text-editor.lisp) | ElmTUI can host a useful Unicode editor with an explicit save lifecycle. | Edit, save, and exercise the dirty-buffer dialog. |
| 4. Animate | [`neon-tetris`](../examples/neon-tetris.lisp) | Stateful games can look polished without a custom screen painter. | Move, rotate, drop, reset. |
| 5. Preserve | [`tmux-glider`](../examples/tmux-glider.lisp) | Even animation over existing shell output can leave scrollback and styling intact. | Run inside tmux, move the glider, quit, inspect the underlay. |
| 6. Inspect | [`tmux-cursor-inspector`](../examples/tmux-cursor-inspector.lisp) | Physical terminal cells can carry reversible focus and semantic tooltips. | Move the cell box; confirm each vacated cell is restored. |
| 7. Develop | [`repl`](../examples/repl.lisp) | ElmTUI can host its own interactive Lisp development environment. | Evaluate a form, complete a symbol, inspect the image, exit cleanly. |

Run a named example using:

```sh
./scripts/examples.sh list
./scripts/examples.sh run <example-name>
```

Exceptions and extra dependencies are indicated below. Use a real interactive
terminal; terminal/tmux examples are **not** browser widgets.

## The hallmark contract

An example is a **hallmark** only when someone can reproduce its intended
visible behavior and its failure/exit behavior. Before featuring it in release
material, require:

1. **Distinct capability.** A single-sentence user-facing promise. A wrapper
   inherits its canonical example's claim; aliases do not count as new features.
2. **Visible proof.** An obvious, documented key sequence or input that changes
   something meaningful. No screenshot-only or "it compiles" claims.
3. **ElmTUI-native architecture.** Prefer the real state/update/view, DSL,
   commands and terminal presenter; disclose when a direct physical tmux
   overlay intentionally uses low-level terminal painting instead.
4. **Safe lifecycle.** Clean quit, restored termios/cursor; no alternate-screen
   dependencies, no unexpected scrollback edits or screen-clearing escapes.
   Below-cursor and tmux overlays additionally restore the area they touch.
5. **No busy renderer.** Event-driven demonstrations make no terminal writes
   when nothing changed; animation subscriptions stop when paused where
   applicable. Test with a real PTY, not a mocked view alone.
6. **Legible terminal design.** Square-corner layout, purposeful information
   hierarchy, readable colors, resize/boundary behavior, Unicode/cell-width
   awareness where the example handles arbitrary text.
7. **Deterministic qualification.** At least a state-transition/unit check
   plus a private-terminal startup → interaction → exit check; error paths,
   resize, style restoration and external dependency failure are exercised
   when relevant.
8. **Reproducible delivery.** A documented CLI/entry point, a declared minimum
   terminal size and external requirements, plus an evidence capture suitable
   for the README or project site.

**Catalog vocabulary:** **Base** = source included in `elmtui-examples.asd`;
**Optional** = standalone integration source, not built by that base ASDF
system; **Compat** = maintained wrapper/legacy interface; **Support** = not a
standalone example. **Flagship** is a *curation target*, not proof of passing
all eight gates. **Workshop** means deliberately foundational or diagnostic.
All entries below have a distinct intended claim even when implementation
or qualification still needs work.

## 1. Language of ElmTUI: state, focus, styles, layout and input

| Example | Hallmark statement / one thing to demonstrate | Proof to show | Track |
|---|---|---|---|
| [`minimal-app`](../examples/minimal-app.lisp) | **Reactive core:** messages produce state patches, which rebuild only the declarative view. | Press a key and watch the label change. | Base · Workshop |
| [`keymap-app`](../examples/keymap-app.lisp) | **Semantic keymaps:** `+`, `-` and Enter dispatch component-directed counter actions. | Focus counter; increment, decrement and reset. | Base · Workshop |
| [`focus-simple`](../examples/focus-simple.lisp) | **Keyboard navigation:** listbox, focus traversal and button activation cooperate through semantic messages. | Tab / Shift-Tab, arrows, Enter; compare OK vs Cancel. | Base · Flagship target |
| [`input-selector`](../examples/input-selector.lisp) | **Reactive filtering:** input changes a styled, keyboard-navigable result set. | Type a substring, erase it, choose a matching item. | Base · Workshop |
| [`key-tester`](../examples/key-tester.lisp) | **Input transparency:** decoded key events, edit history and a responsive view make terminal input observable. | Type, use Backspace, Escape and special keys. | Base · Flagship target |
| [`rainbow-app`](../examples/rainbow-app.lisp) | **Rich terminal styling:** real colored glyph bands, responsive orientation and a terminal-color fallback. | Toggle orientation with Space; inspect colors in a true-color PTY. | Base · Flagship target |
| [`mini-rainbow`](../examples/mini-rainbow.lisp) | **Compact styling:** a deliberately small colored composition still demonstrates the same renderer vocabulary. | Toggle horizontal/vertical bands with Space. | Base · Workshop |
| [`scroll-panel-demo`](../examples/scroll-panel-demo.lisp) | **Bounded content navigation:** an 80-line model is paged through an 18-line visible window. | Up/Down, PageUp/Down, Home/End; watch the visible slice. | Base · Workshop |
| [`root-viewport-test-app`](../examples/root-viewport-test-app.lisp) | **Explicit positioning:** an offset-based rectangle exposes root-viewport geometry and clipping behavior. | Move the rectangle with arrow keys near viewport edges. | Base · Workshop |

**Architectural honesty:** `scroll-panel-demo` currently implements paging by
slicing the item list in its view; it is **not** a demonstration of a built-in
scroll-panel DSL node. `root-viewport-test-app` is a geometry diagnostic, not
yet a polished, end-user workflow. The keymap example's real package entry
point is `elmtui.examples.keymap-app:main` (the older guide listed a different
package/function).

## 2. Useful programs: editing, selection, files and external systems

| Example | Hallmark statement / one thing to demonstrate | Proof to show | Track |
|---|---|---|---|
| [`repl`](../examples/repl.lisp) | **The flagship developer experience:** ElmTUI renders a multiline Lisp editor, responsive evaluator, completion, transcript and live inspector through one `defapplication`. | Run `./scripts/examples.sh run repl`, evaluate `(+ 40 2)`, invoke completion, use F2, then Ctrl+D; verify normal-buffer/termios restoration. | Optional · **Prime flagship target** |
| [`dirli`](../examples/dirli.lisp) | **Navigable filesystem:** browse directories via a keyboard-selected list without accidental navigation. | Arrows or J/K select; Enter opens the selected directory. | Base · Flagship target |
| [`fzf-finder-real`](../examples/fzf-finder-real.lisp) | **Composable picking:** give a finder items on stdin; filter and select interactively. | Pipe newline-delimited candidate strings into its runner. | Base · Workshop |
| [`fzy-picker`](../examples/fzy-picker.lisp) | **External algorithm integration:** an optional `cl-fzy` matcher plugs into a native terminal picker. | Install `cl-fzy`, load optional ASDF system, filter and choose. | Optional · Integration |
| [`mini-text-editor`](../examples/mini-text-editor.lisp) | **Editor-quality state:** Unicode text, dirty state, save-as, overwrite confirmation and async save belong in a small TUI. | Modify a scratch buffer, save, trigger dirty quit, cancel/discard. | Base · Flagship target |
| [`neon-nano`](../examples/neon-nano.lisp) | **Product-level composition:** the existing editor state machine supports a styled Nano-like frontend without a second editor engine. | Open, edit, save and use the confirmation dialog. | Base · Flagship target |
| [`neon-less`](../examples/neon-less.lisp) | **Read-only document UX:** line numbers, viewport metadata and paging make text navigation deliberate. | J/K, F/Space, B, g/G on a long file. | Base · Flagship target |
| [`wifi-menu`](../examples/wifi-menu.lisp) | **Real-world async control:** scan, select, rescan, connect and disconnect through NetworkManager with visible outcomes. | Use a live `nmcli` adapter, review results and explicit actions. | Base · External integration |
| [`wifi-inline`](../examples/wifi-inline.lisp) | **Inline system UI:** network scanning and explicit connect confirmation can happen below the shell cursor. | Scan, select, confirm, quit and check area restoration. | Base · External integration |
| [`async-weather`](../examples/async-weather.lisp) | **Responsive I/O:** real geocoding and forecasts run asynchronously with error and cancellation handling. | Search a city, switch location while loading, inspect forecast. | Optional · External integration |

`fzf-finder-real` is a line-oriented stdin example, not a promise to implement
all `fzf` features. `fzy-picker` needs its separate
`elmtui-examples-fzy` system; `async-weather` needs network access, `curl`
and `jq`. The two Wi-Fi examples require NetworkManager/`nmcli` and may
change the machine's connection **only when an interactive user explicitly
requests the action**. These are not safe unattended release-demo actions on
the owner's current network.

## 3. Living interfaces: games, subscriptions, simulation

| Example | Hallmark statement / one thing to demonstrate | Proof to show | Track |
|---|---|---|---|
| [`neon-pong`](../examples/neon-pong.lisp) | **Interactive animation:** ElmTUI can run a two-player game with live state and styled telemetry. | W/S, I/K; serve with Space; quit cleanly. | Base · Flagship target |
| [`neon-tetris`](../examples/neon-tetris.lisp) | **Nontrivial state machine:** falling blocks, collision, rotation, ghost piece and scoring fit the declarative renderer. | A/D, W rotate, S drop, R reset. | Base · Flagship target |
| [`neon-life`](../examples/neon-life.lisp) | **Controlled simulation:** Conway B3/S23 generations, population and speed are inspectable. | Pause, step exactly once, change interval, reset. | Base · Flagship target |
| [`neon-glider`](../examples/neon-glider.lisp) | **Small animated actors:** trail, velocity and per-frame telemetry share a stable diff-rendered dashboard. | Pause, single-step, adjust speed. | Base · Flagship target |
| [`game-of-life`](../examples/game-of-life.lisp) | **Alternate model, familiar view:** a separate 20×40 Life model exercises reset, pause and progression. | Advance generations and compare the population/readout. | Base · Workshop |
| [`glider-real`](../examples/glider-real.lisp) | **API continuity:** the historical glider entry point can use the maintained Neon Glider presentation. | Launch legacy name; verify the same animation/control lifecycle. | Base · Compat |
| [`pong-below-cursor`](../examples/pong-below-cursor.lisp) | **Embedded animation:** a live ball/paddle game runs in an inline viewport below existing terminal content. | Use left/right, then quit and inspect the surrounding terminal. | Base · Flagship target |

`neon-life` is a full Conway simulation; `neon-glider` is a bouncing
particle/trail animation, **not** the physical five-cell Conway glider in
`tmux-glider`. `glider-real` is a compatibility entry, not a new rendering
engine. The Neon dashboards reuse [`neon-kit`](../examples/neon-kit.lisp);
their state/view code uses ElmTUI's presenter rather than painting ANSI itself.

## 4. The terminal is not a disposable canvas: tmux and restoration

| Example | Hallmark statement / one thing to demonstrate | Proof to show | Track |
|---|---|---|---|
| [`tmux-glider`](../examples/tmux-glider.lisp) | **Reversible physical animation:** a five-cell Conway glider moves across original pane text and restores each vacated cell's glyph and SGR. | Run in a private tmux pane with styled/history fixtures; walk, pause, step, quit. | Optional · Flagship target |
| [`tmux-cursor-inspector`](../examples/tmux-cursor-inspector.lisp) | **Inspectable cells:** a movable selection box and semantic tooltip expose the source cell, coordinates, width and style. | Move with arrows/HJKL; confirm original content reappears without history changes. | Base · Flagship target |
| [`tmux-slider`](../examples/tmux-slider.lisp) | **Transient styling:** an animated band can recolor captured pane cells and restore original SGR on departure. | Move the band across styled text; pause and exit. | Optional · Flagship target |
| [`tmux-idle-screensaver`](../examples/tmux-idle-screensaver.lisp) | **Timed overlay lifecycle:** root-viewport animation and subscriptions can coexist with tmux capture/restore semantics. | Exercise idle animation, input and exit with a restored-pane check. | Base · Flagship target |
| [`cursor-inspector`](../examples/cursor-inspector.lisp) | **Snapshot introspection:** browse captured pane/scrollback text and decoded cell styles in a state/view dashboard. | Switch pane vs scrollback; select and inspect a glyph and its SGR. | Base · Compat |
| [`tmux-hover-demo`](../examples/tmux-hover-demo.lisp) | **Legacy public API continuity:** the older hover runner delegates to the dashboard inspector. | Launch the old name; verify equivalent cached inspector behavior. | Base · Compat |

These are two **different** architectures with distinct proof obligations:
the physical `tmux-glider`, `tmux-slider` and
`tmux-cursor-inspector` use direct, narrowly bounded writes to preserve
already-rendered pane cells; `cursor-inspector`,
`tmux-hover-demo` and `tmux-idle-screensaver` exercise the ElmTUI
application/viewport route. Neither approach should enter alternate-screen
mode. The new physical cursor inspector deliberately requires a fresh capture
after a resize; it does **not** claim live-resize support yet.

## 5. Shared pieces and the development environment

| Source | Hallmark statement / one thing to demonstrate | Proof to show | Track |
|---|---|---|---|
| [`neon-kit`](../examples/neon-kit.lisp) | **Reusable presentation vocabulary:** shared colors, event helpers and stable row identities reduce duplicated game/editor UI. | Compare the common renderer-native header/rows/footer across Neon apps. | Base · Support, no standalone runner |
| [`workbench`](../examples/workbench.lisp) | **A developer's own ElmTUI:** the separate Workbench system provides interactive development tooling via a standalone launcher. | Launch Workbench, inspect/evaluate in its own documented workflow. | Standalone · Separate ASDF system |

Workbench is **not** part of `elmtui-examples.asd`; see
[the workbench guide](workbench-user-guide.md). The new `repl` example
is a small CLI-discoverable launcher that loads exactly that optional Workbench
system, without implementing its own evaluation or terminal rendering.
`examples/workbench.lisp` remains the standalone direct launcher.

**Prime flagship release gate:** The Workbench uses ElmTUI's application
state/update/view, event subscriptions, root viewport and terminal presenter,
not a separate REPL renderer. ASCII semantic style spans now render via
ElmTUI flex-row text children. The earlier blank frame was caused by an
unsupported `:white-space` declaration rejected during style validation,
not bad flex coordinates. **Still pending:** grapheme/cell-width accuracy,
syntax highlighting, real screenshots and final release qualification.
No Workbench-specific ANSI painter is permitted. It remains a prime *target*,
not a signed-off flagship.
The evaluator executes **trusted, unsandboxed Lisp**; cancellation is cooperative.
`neon-kit` is intentionally support code, not a missing runnable demo.

## Qualification map: make the statements defensible

The table identifies existing **test entry points**, not a claim they have
all been run in this documentation change.

| Claim family | Current evidence entry point | Hallmark gap to close |
|---|---|---|
| Framework-wide test coverage | `./rt.sh` | Add explicit acceptance for every visible example, not just loading. |
| Cross-example startup and exit | `python3 tests/e2e/extended-examples-pty.py -v` | Record demo-by-demo terminal sizes and deterministic visual snapshots. |
| Neon dashboard behavior | `python3 tests/e2e/neon-life-glider-pty.py -v`; `python3 tests/neon-pty.py` | Sustain pause/step/resize/idle-write invariants across all games. |
| Reversible physical tmux cells | `python3 tests/e2e/tmux-glider-pty.py -v`; `python3 tests/e2e/tmux-cursor-inspector-pty.py -v` | Test wide-cell styles, edges, small panes, and resize policy across physical overlays. |
| Legacy tmux dashboard | `python3 tests/e2e/tmux-hover-defect-regressions.py`; `python3 tests/e2e/tmux-scrollback-restoration.py` | Reduce alias duplication without breaking existing callers. |
| Network actions | `tests/wifi-inline-tests.lisp`; `tests/e2e/remainder-wifi-robustness.py` | Use a hermetic fake `nmcli` and explicit non-mutating demo fixtures. |
| Rendering and input | `tests/e2e/example-overhaul-rainbow-colors.py`; `tests/e2e/example-overhaul-key-tester.py` | Add captured-color and Unicode input fixtures to the gallery assets. |
| Async remote data | `tests/e2e/example-overhaul-async-weather.py` | Offline replay fixtures, cancelled requests, no-network error UX. |
| This catalog itself | `python3 -m unittest tests/test_examples_capability_index.py` | Keep source-file coverage from drifting as examples are added. |

### Recommended order for the next showcase pass

1. **Terminal-integrity identity:** capture before/after tmux transcripts,
   8/256/RGB SGR and Unicode, and private-tmux video/GIF for glider,
   cursor-inspector and slider. These differentiate ElmTUI immediately.
2. **Product-quality apps:** exercise Mini Editor/Nano, Less, Dirli and the
   picker with real keyboard walkthroughs, failure paths and small-pane
   handling. Make the first interaction obvious on screen.
3. **Animation with restraint:** verify zero idle writes when a timer is not
   subscribed, and pause/step determinism for each simulation. Publish the
   same frame-size test matrix for every Neon app.
4. **External integration without surprises:** freeze weather/network fixtures
   and require an explicit confirmation for any real network mutation.
5. **Teach the library:** use minimal, keymap, focus, input and viewport demos
   as tiny source-first tutorials, each mapping a visible action to the
   precise ElmTUI API used.
6. **Consolidate names:** keep compatibility entry points working while
   avoiding duplicated examples that make the gallery look larger than its
   actual feature surface.

### Inventory accounting

- **34** top-level Lisp sources, **28** members of the base
  `elmtui-examples.asd` (one is the support-only `neon-kit`).
- **6** outside the base ASDF system: `async-weather`,
  `fzy-picker`, `tmux-glider`, `tmux-slider`, `repl`,
  `workbench`.
- **32** discoverable example-name stems from `scripts/examples.sh list`
  (the runner excludes `neon-kit` and `workbench`), **not** 32 fully
  independently qualified features.
- Every top-level `examples/*.lisp` has exactly one source link in the
  five capability tables; [catalog coverage test](../tests/test_examples_capability_index.py)
  verifies this mechanically.
