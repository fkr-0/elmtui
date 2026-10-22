# ElmTUI REPL flagship — nested text composition

**Priority:** high. **Status:** native ASCII styled rows repaired and
qualified; remaining work is Unicode display-cell geometry, syntax
highlighting, and authentic website capture.

**Confirmed cause, not a flex mathematics defect:** the application style
validator rejects `:white-space :nowrap` as an unknown property, although
the low-level text painter recognizes it. The REPL's experimental native
rows triggered that contract violation *before rendering*; the application
silently presented a blank viewport. Isolated flex rectangles and virtual
buffer output were correct. Explicit segment widths now provide an accepted
layout without that property. A second issue was fixed in ElmTUI's terminal
style converter: boolean `:bold t`/`:italic t`/`:underline t` previously did
not reach the terminal even though `:attributes` lists worked.

1. **Completed:** native flex/text style spans, virtual-buffer character and
   color/bold assertions, REPL CLI evaluation/completion/inspector smoke, and
   three-size PTY startup/evaluation/exit/termios smoke.
2. **Still open:** make style contract and terminal text properties consistent
   if `:white-space` is to become public; errors must be surfaced as explicit
   diagnostics rather than blank applications.
3. **Still open:** make row layout and cursor/selection geometry use terminal
   *display cells*, not character indices, including combining marks, East
   Asian wide glyphs, emoji/ZWJ sequences and tabs. Current non-ASCII rows
   intentionally keep the safe single-text-node fallback.
4. **Next:** add reader-safe Lisp syntax highlighting (comments, strings,
   symbols, keywords, quote operators); verify zero evaluation in lexing and
   no jitter as tokens edit.
5. **Release:** qualify idle writes, resizing, 80/120/160 geometry, REPL
   completion and terminal restoration; replace website mockup with an
   authentic private-PTY/tmux capture.

**Verification:** `tests/repl-native-layout-regression.lisp` is exercised by
`tests/workbench/independent/test_native_repl_presentation.py`; private PTY
startup/eval/quit passed at 80×24, 120×40 and 160×50. The full Lisp test run
reported 8,099 PASS, 6 SKIP and 28 FAIL; failures reference the missing
`./scripts/tmux-slider.lisp` path. This unrelated pre-existing fixture problem
must be resolved separately before claiming a green release suite.

**Release invariant:** normal screen only; no redraw while idle; no
destructive scrollback operations; no silent terminal style/cursor drift.
