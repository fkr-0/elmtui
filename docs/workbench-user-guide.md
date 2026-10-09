# ElmTUI Lisp Workbench

Optional local REPL application. Load with:

    clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load examples/workbench.lisp

This loads the separately defined `elmtui-workbench.asd` system; `elmtui.asd` and Slynk remain unchanged. Local evaluation is in-process, **trusted Lisp** (not a security sandbox). No remote server is started. The workbench uses the terminal's alternate screen and a top-left, full-height viewport, restoring the previous shell screen after exit.

## Keyboard and layout

- Enter submits a complete expression and indents incomplete forms; Ctrl+Enter forces submission where the terminal reports that modified key.
- Ctrl+Space requests symbol completion, Up/Down navigates, Tab accepts, Esc closes.
- F2 focuses the package/ASDF image panel (at 120+ columns both panels appear); F3 toggles delayed documentation; F4 displays diagnostics.
- Bracketed multiline paste inserts text atomically without evaluating it. Ctrl+C requests **cooperative** cancellation; arbitrary Lisp can continue running or block. Ctrl+D exits when the editor is empty. PageUp/PageDown scroll the transcript.
- The main view includes a terminal-cell-derived cursor marker. Documentation is delayed about 450 ms and cancelled on changed selection. The application uses ElmTUI timer subscriptions for nonblocking event delivery, avoiding UI-thread sleeps.

## Architecture and qualification

W1 editor, W2 evaluation worker, W3 completion/docs, W4 inspector are imported through their actual exported APIs. Their own modules are not modified by integration. Text/frame composition is in `src/workbench/view.lisp`; TEA model/update glue is in `src/workbench/app.lisp`.

The evaluator is serialized and supplies tagged result messages; the optional inspector does not claim lexical locals outside debugger frames. Output is bounded and command-line completion is read-only. A 75 ms timer is installed only while evaluation, delayed documentation or live inspector watches require it; startup and idle have no timer subscription. The optional launcher passes :signal-keys-as-input t to the terminal backend. After cl-inputs saves original terminal attributes, the backend disables ISIG before the initial cursor query, so Ctrl+C is a key even at startup; terminal teardown restores the saved attributes. This opt-in policy leaves other ElmTUI applications unchanged. The real PTY stress suite checks zero idle writes and bounds process-wide SBCL CPU ticks.

Run PTY smoke:

    python3 tests/workbench/pty-workbench.py

The smoke verifies the visible transcript, editor prompt and status, the image inspector at 120+ columns, evaluation of `(+ 1 2)` to `3`, completion, and clean Ctrl+D/alternate-screen/termios restoration. It is not by itself a complete golden/Unicode/keymap conformance matrix. Qualification and review require explicit independent verdict and 80x24 / 120x40 / 160x50 trace inspection. In particular, Ctrl+Enter and Ctrl+Space terminal support depends on key protocol negotiation; fallback Enter submits balanced forms.

## Important limitations

Initial shell uses fixed-width row composition. While nested inline-style flex rows are being corrected in the framework, the workbench presents each complete row in a stable text node with row-level styling; per-token/segment styling is temporarily reduced. Display-cell alignment of combining marks, grapheme clusters, and emoji remains a release-qualification gate. The `:root-viewport` controls terminal lifecycle, and alternate-screen/termios cleanup must be checked against actual PTY traces. Evaluation cancellation does not forcibly interrupt user code.
