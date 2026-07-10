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
| `pong-below-cursor.lisp` | Inline animation below the current cursor |

## Optional `cl-fzy` example

`fzy-picker.lisp` is intentionally separate from the maintained base system so
a normal ElmTUI checkout does not require an external sibling repository. After
installing the `cl-fzy` ASDF system, load:

```lisp
(asdf:load-system "elmtui-examples-fzy")
(elmtui.examples.fzy-picker:run-fzy-picker)
```

The optional system is declared in `elmtui-examples-fzy.asd` and is not part of
the default release test graph.

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
