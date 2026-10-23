# Independent ElmTUI layout correctness review — 2026-10-23

## Scope

Reviewed Git commit `7a2ad96` ("restore native styled REPL rows and terminal boolean attributes"), the current `src/workbench/view.lisp`, focused native REPL layout regression, ANSI terminal style conversion regression, and current concurrent work claims. This is a **review**, not a global release certification. Active workers own `src/platform/tree-renderer.lisp` and style-contract paths, so they were not edited.

## Verified

- The focused runtime check `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load tests/repl-native-layout-regression.lisp` completed with exit status 0 and `REPL-NATIVE-LAYOUT-PASS` on the current workspace. That checks ASCII fragments round-trip through DSL → process-tree flex layout → virtual buffer, with color and bold preserved at the correct cells.
- Fixed-width ASCII fragments have explicit `:width`, `:height 1`, zero gap and zero padding. This avoids depending on the `:white-space :nowrap` property previously rejected by the high-level style contract, and makes the committed ASCII row fix structurally sound.
- `style-to-terminal-style` now converts explicit booleans (e.g. `:bold t`) to terminal attributes while allowing explicit NIL to override a legacy `:attributes` list. Rendering tests cover this precedence.
- The change does **not** prove a general-purpose flex-row algorithm defect. The earlier reported blank REPL was a style-contract mismatch before layout and is fixed for the supported ASCII-row path.

## Correctness limitations and risks

1. **Unicode display geometry remains unresolved** (not a passed criterion). `frame-dsl` explicitly returns one text node for any non-ASCII row. Its `:width` still uses Lisp character length rather than terminal cell width, so wide glyphs, combining marks, emoji/ZWJ sequences, and tabs can misalign cursor positions or clipping.
2. **Unicode span loss:** in the non-ASCII fallback, only the first segment's style is chosen; later semantic spans are discarded. This is intentional conservative fallback, but violates a general "all styled fragments survive" guarantee. A future row compositor must keep all spans and map source codepoint indices to grapheme/cell coordinates.
3. **Cursor geometry uses character counts** in `frame-lines`, including `cursor-x`, and a single-character `|` overlay. Tabs/wide graphemes can misplace the caret and overwrite a grapheme's second terminal cell.
4. **Viewport/cursor clipping invariants need real PTY qualification:** ensure narrow inspector, transcript, completion overlay, resized narrow-to-wide transitions, wrapped source lines and EOL cursor do not paint outside the root viewport or leave stale cursor cells.
5. **Style schema cross-layer parity** is still being worked on by a separate active worker with claims on the renderer and ANSI backend. Do not accept broad support for `:white-space` until the public style validator, layout and terminal painter agree and matrix regressions pass.
6. **Release suite not proven green:** the prior review recorded 8,099 passes, 6 skips and 28 failures due to a missing tmux-slider fixture. That is historical evidence, not rerun/revalidated in this review.

## Test execution boundary

The independent native-PTY presentation-suite command was blocked before reaching ws-bridge by the platform's safety check. It was **not** retried via alternative tooling. The exact blocked tool call is recorded under the project's `.wsbridge:blocked-calls` channel; no PTY verification result is claimed in this pass.

## Release recommendation

The ASCII styled-text repair is supported by the focused runtime regression and source inspection. **Do not mark the overall layout engine or flagship REPL presentation as fully qualified** until grapheme/display-cell geometry, resize/restoration, style schema parity, and the complete PTY and release suites have independently passed. Future dedicated tests should assert narrow/wide cell placement and style ranges for ASCII, U+754C, U+0301 combining, tab, ZWJ emoji, viewport edge, and cursor at end-of-line.
