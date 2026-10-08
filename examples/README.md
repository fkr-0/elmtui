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

## Mini text editor

A compact, file-backed editor illustrating ElmTUI's state/update/view lifecycle.
Start a scratch buffer with `./examples.sh run mini-text-editor`, or edit a
UTF-8 text file by setting `ELMTUI_EDITOR_FILE`:

```sh
ELMTUI_EDITOR_FILE=/tmp/notes.txt ./examples.sh run mini-text-editor
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

## Tmux examples

| File | Purpose |
|---|---|
| `tmux-hover-demo.lisp` | Capture and display tmux pane content |
| `tmux-idle-screensaver.lisp` | Tmux-aware idle application and timer subscriptions |

Tmux examples require a running tmux session. The automated live integration
checks are gated behind:

```sh
ELMTUI_RUN_TMUX_INTEGRATION=1 scripts/release-check.sh
```

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
