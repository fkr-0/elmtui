# ElmTUI Lisp Workbench

**Prime ElmTUI showcase: interactive Common Lisp REPL.** Launch from the
examples CLI:

    ./scripts/examples.sh run repl

This small `examples/repl.lisp` adapter loads the existing optional
Workbench system and calls its generated ElmTUI application runner; it does
not implement a second terminal renderer or evaluator. The direct standalone
launcher remains available:

    clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load examples/workbench.lisp

This loads the separately defined `elmtui-workbench.asd` system; `elmtui.asd` and Slynk remain unchanged. Local evaluation is in-process, **trusted Lisp** (not a security sandbox). No remote server is started. The launcher uses the **normal terminal screen**, not the alternate screen. Its viewport is anchored below the current cursor, allowing existing shell output to remain in scrollback. The Workbench blanks its own viewport on exit; it does not restore the previous screen by swapping terminal buffers.

## Keyboard and layout

- Enter submits a complete expression and indents incomplete forms; Ctrl+Enter forces submission where the terminal reports that modified key.
- Ctrl+Space requests symbol completion, Up/Down navigates, Tab accepts, Esc closes.
- F2 focuses the package/ASDF image panel (at 120+ columns both panels appear); F3 toggles delayed documentation; F4 displays diagnostics.
- Bracketed multiline paste inserts text atomically without evaluating it. Ctrl+C requests **cooperative** cancellation; arbitrary Lisp can continue running or block. Ctrl+D exits when the editor is empty. PageUp/PageDown scroll the transcript.
- The main view includes a terminal-cell-derived cursor marker. Documentation is delayed about 450 ms and cancelled on changed selection. The application uses ElmTUI timer subscriptions for nonblocking event delivery, avoiding UI-thread sleeps.

## Architecture and qualification

W1 editor, W2 evaluation worker, W3 completion/docs, W4 inspector are imported through their actual exported APIs. Their own modules are not modified by integration. Text/frame composition is in `src/workbench/view.lisp`; TEA model/update glue is in `src/workbench/app.lisp`.

The evaluator is serialized and supplies tagged result messages; the optional inspector does not claim lexical locals outside debugger frames. Output is bounded and command-line completion is read-only. A 75 ms timer is installed only while evaluation, delayed documentation or live inspector watches require it; startup and idle have no timer subscription. The optional launcher passes :signal-keys-as-input t to the terminal backend. After cl-inputs saves original terminal attributes, the backend disables ISIG before the initial cursor query, so Ctrl+C is a key even at startup; terminal teardown restores the saved attributes. This opt-in policy leaves other ElmTUI applications unchanged. The real PTY stress suite checks zero idle writes and bounds process-wide SBCL CPU ticks.

Run PTY smoke and the CLI integration acceptance:

    python3 tests/workbench/pty-workbench.py
    python3 -m unittest discover -s tests/workbench/independent -p test_native_repl_presentation.py -v

The smoke verifies the visible transcript, editor prompt and status, the image inspector at 120+ columns, evaluation of `(+ 1 2)` to `3`, completion, and clean Ctrl+D/normal-screen/termios restoration. It is not by itself a complete golden/Unicode/keymap conformance matrix. Qualification and review require explicit independent verdict and 80x24 / 120x40 / 160x50 trace inspection. In particular, Ctrl+Enter and Ctrl+Space terminal support depends on key protocol negotiation; fallback Enter submits balanced forms.

## Important limitations

Workbench uses `elmtui.app:defapplication`, canonical state/update/view,
subscriptions and the terminal diff presenter. **Native ASCII styled
segments are now enabled** in `frame-dsl` using ElmTUI flex rows with
explicit child widths. The former blank screen was traced to the application
style validator rejecting `:white-space :nowrap` (although the terminal
painter recognizes it), not a failure of the flex layout algorithm. The
unsupported property is no longer emitted. Public boolean attributes such
as `:bold t` are now propagated by the terminal style converter, too.

**Remaining release gate:** display-cell-aware positioning, composition and
syntax highlighting of arbitrary Unicode (combining marks, wide glyphs,
emoji/ZWJ, tabs). Rows containing non-ASCII currently use a single ElmTUI
text node to avoid splitting glyph clusters. There is no raw ANSI painter
in Workbench. Display-cell alignment of combining marks, grapheme clusters, and emoji remains a release-qualification gate. The `:root-viewport` controls terminal lifecycle, and normal-screen/termios cleanup must be checked against actual PTY traces. Evaluation cancellation does not forcibly interrupt user code.
