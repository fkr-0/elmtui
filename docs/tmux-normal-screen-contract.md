# ElmTUI normal-screen tmux overlay contract

**Status (2026-10-31): P0 GATES PASS — physical B2 and lossless resize are
qualified in real tmux; P1 items below remain open.** This is
the normative behavior contract for cursor inspector B1/B2, slider, and other
in-place tmux examples. Requirements and verified implementation are kept
separate.

## Non-negotiable terminal semantics

1. **Only the normal/main buffer.** Never emit CSI ?1049h/l, ?1047h/l,
   or ?47h/l. Alternate-screen cannot be a fallback, debug trick, or release
   loophole. The driver rejects alternate mode at app startup. Its legacy
   transition helper remains and needs a separate removal review.
2. **Zero scrollback mutation.** Historical rows, Unicode, SGR and order must
   survive exactly. The final tmux history must contain every numbered marker
   *once*, not merely text copied somewhere on the screen.
3. **Bounded overlay.** Take a styled visible-pane snapshot, then paint only
   changed physical cells. Never allocate pane rows, trigger implicit newline
   or terminal scroll, or re-render the original shell history.
4. **Resize is a transaction.** A 120x40 -> 80x24 shrink may transfer pane
   content into history. A visible-cell snapshot cannot reconstruct that
   history by itself; save row identity and validate both resize directions.
5. **No idle writes.** Unchanged state/geometry means no terminal output.
6. **Restorable exits.** q, Escape, Ctrl-C and repeated launches must leave
   original cells, cursor visibility, termios/stty, and history intact.

## B2 physical cursor box

B2 is a **3x3 Unicode border centered on the actual terminal cell**, not
a preview inside a bottom-left inspector panel:

~~~text
    x-1  x  x+1
y-1  ┌   ─   ┐
 y   │   G   │   G: original glyph, foreground, background, attributes
y+1  └   ─   ┘
~~~

The inner single-column cell must occupy physical (x,y) exactly. Drawing
a border must not clear, move, or restyle G. Near pane edges, clip or
reposition *without scrolling*. Wide and combining glyphs require an
explicit continuation-cell policy. Initial selection must use the actual
tmux cursor coordinates rather than hard-coded (0,0).

**Implementation (2026-10-31):** when launched over a captured tmux
underlay in PANE mode, the inspector runs a full-pane root viewport
(`cursor-inspector-overlay-app`). Its view paints only the B2 border cells
at the real pane coordinates and the inspector panel; every other cell is an
unpainted layout spacer. The panel moves to the top when it would cover B2.
SCROLLBACK mode has no physical cell and keeps the in-panel PREVIEW, as does
the bounded panel app used without a tmux underlay (a full-pane viewport
without an underlay would blank the user's screen).

The compositor (`elmtui.pipeline:*underlay-buffer*`) starts every frame
from the captured underlay instead of the previous frame, so a moved B2
leaves no stale border cells.

## B1 tooltip contract

B1 is independently anchored: either fixed or cursor-following. It must
clamp to the viewport, switch sides near edges, and never obscure B2.
Report cursor coordinates, code point/glyph, display width, parsed SGR
foreground/background and attributes, normalized style as a string,
and capture geometry. Include a specimen rendered using the *captured*
style. Standard, 256-color and RGB styles are all valid.

**Current limitation:** B1 is embedded in the bottom-left inspector panel.
The specimen now reproduces captured RGB and 256-palette foreground/
background and selected SGR attributes; the strict private-tmux color test passes. A separate real-PTY test for a
combined bold+underline+RGB/palette SGR cell remains RED: B1 border and
metadata rows can disappear or shift. Fixed/follow anchoring is also missing.

## Capture API versus restoration API

| Operation | Verified contract | Non-guarantee |
| --- | --- | --- |
| capture-pane-string | Read tmux output with ANSI SGR and history | Does not restore pane |
| %capture-visible-pane-string | Read visible styled cells only | Does not retain scrollback |
| prefill-backend-from-tmux-styled | Populate front/back and return separate styled snapshot | Cannot protect rows displaced by shrinking |
| save-tmux-capture | Copy visible virtual buffer | Not full history |
| restore-to-tmux-capture | Copy saved cells back into virtual buffer | No terminal repaint or scrollback recovery |
| normal-screen ledger | Logical underlay: rows tmux pulled from history ++ launch capture | Width reflow of over-wide rows is not modelled |
| Driver shutdown restore | Repaint the logical underlay, scroll shrink-deleted rows back into history | Requires the cursor-parking invariant below |

### Resize transaction (2026-10-31)

tmux resizes relative to the cursor: a height shrink first **deletes rows
below the cursor**, then scrolls the rest off the top into history; a height
grow pulls previously scrolled lines (`hscrolled`, which counts *every* line
ever scrolled into history) back down onto the pane top. Leaving the cursor
mid-pane therefore destroyed bottom rows, and leaving it on the last row
pushed overlay cells into history.

The driver now parks the cursor on pane row 0 after every frame that wrote
output. A shrink then only deletes bottom rows and never touches history; a
grow only appends blank rows or pulls *pristine* history rows. The
`normal-screen-ledger` records pulled rows (from the change in
`#{history_size}`) so the pane always shows the top rows of
`[pulled history] ++ [launch capture]`:

- frames composite onto that logical underlay;
- pulled rows are **protected**: the compositor reverts any paint on them
  (`*underlay-protected-rows*`), and views can offset snapshot rows by
  `underlay-protected-rows`;
- shutdown repaints the logical rows in place, then appends rows a shrink
  deleted by scrolling, which moves the rows above them into native history
  in their original order and with their original SGR.

The real tmux pane can differ from the cached PTY/backend dimensions.
The driver probes actual pane geometry before restoring but still cannot
reconstruct historical rows displaced while the application runs.
Display-width detection is an approximation, not full grapheme segmentation.

## Reproducible tests

Run from the ElmTUI repository with CLPM/SBCL and private tmux:

~~~sh
# Component and ordinary lifecycle tests:
python3 tests/e2e/example-overhaul-tmux-review-contracts.py
python3 tests/e2e/example-overhaul-tmux-normal.py
python3 tests/e2e/example-overhaul-tmux-slider.py
python3 tests/e2e/example-overhaul-tmux-resize-driver-geometry.py
python3 tests/e2e/example-overhaul-tmux-backend-pty.py

# Existing full hover gate (currently RED):
python3 tests/e2e/example-overhaul-tmux.py
~~~

The review suite runs every test on every invocation; nothing is skipped or
opt-in. The two full release criteria (actual B2 coordinates and reverse-resize
preservation) are ordinary assertions and block release when red. Unit
regressions for the ledger, compositor, protected rows, cursor parking,
shrink restore and B2 layout live in `tests/normal-screen-overlay-tests.lisp`.

### Evidence, 2026-10-31

- Review contracts 5/5, including strict physical B2 at (5,6), stale-border
  removal after moving, and 120x40 -> 80x24 with 70/70 unique markers.
- `tmux-hover-defect-regressions.py` 9/9 (was 6/9), both resize directions
  with exact styled history; `tmux-normal-compositor-resize.py` 2/2 (was
  1/2) across 70x22 / 100x35 / 48x12 / 100x35 with protected history intact
  at every step; `example-overhaul-tmux.py` 7/7 (was 6/7).
- Root FiveAM suite 0 failures, 0 skips.

### Evidence, 2026-10-09

- Docstrings/SGR/hard alternate-mode rejection: 3/3 pass.
- Strict physical B2 test: FAIL. Expected top box at physical row 5,
  cols 4..6, but observed ordinary pane text ORY instead of ┌─┐.
- Strict 120x40 -> 80x24 test: FAIL. History markers 39..49 are missing,
  so only 59 of 70 remain, despite normal exit.
- Styled capture 195/195 and virtual-buffer restore 13/13 pass.
- Renderer 22/22 + rendering pipeline 18/18 pass.
- Slider real PTY tests 5/5 pass, including pause/no idle writes.

These results qualify components, **not the hover feature**.

## Work remaining / independent acceptance

**Done (2026-10-31):** underlay compositor and scrollback-safe
resize/shutdown in both directions; B2 border over the exact real selected
cell with the panel kept clear of it.

**P1:** Independently positioned B1 tooltip (fixed / cursor-following);
modelling tmux reflow for rows wider than a shrunken pane.

**P1:** Unicode combining/wide continuation, independent cursor-follow
collision/clamping, user-visible coordinates/statistics, and removal of
the dormant alternate-screen transition helper. RGB/256 specimen styling
was qualified separately by the strict B1 real-tmux regression test.

Retain the canonical ABC/OCP task identities when implementing and reviewing.
A green component test is never sufficient to close a red strict gate.
