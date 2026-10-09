# ElmTUI normal-screen tmux overlay contract

**Status (2026-10-09): PARTIAL — hover release qualification fails.** This is
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

**Current limitation:** The existing B2 helper only produces a three-row
panel PREVIEW. It does not paint the real selected cell and has no
physical border reconciliation.

## B1 tooltip contract

B1 is independently anchored: either fixed or cursor-following. It must
clamp to the viewport, switch sides near edges, and never obscure B2.
Report cursor coordinates, code point/glyph, display width, parsed SGR
foreground/background and attributes, normalized style as a string,
and capture geometry. Include a specimen rendered using the *captured*
style. Standard, 256-color and RGB styles are all valid.

**Current limitation:** B1 is embedded in the bottom-left inspector panel.
The RGB/256 specimen currently falls back to white/black rather than
rendering the parsed style. Fixed/follow anchoring is not yet available.

## Capture API versus restoration API

| Operation | Verified contract | Non-guarantee |
| --- | --- | --- |
| capture-pane-string | Read tmux output with ANSI SGR and history | Does not restore pane |
| %capture-visible-pane-string | Read visible styled cells only | Does not retain scrollback |
| prefill-backend-from-tmux-styled | Populate front/back and return separate styled snapshot | Cannot protect rows displaced by shrinking |
| save-tmux-capture | Copy visible virtual buffer | Not full history |
| restore-to-tmux-capture | Copy saved cells back into virtual buffer | No terminal repaint or scrollback recovery |
| Driver shutdown diff | Attempt physical-cell restoration | Reverse shrink still corrupts scrollback |

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

# Explicit P0 release gate (currently RED):
ELMTUI_STRICT_TMUX_ACCEPTANCE=1 python3 tests/e2e/example-overhaul-tmux-review-contracts.py

# Existing full hover gate (currently RED):
python3 tests/e2e/example-overhaul-tmux.py
~~~

The default review suite **skips** the two full release criteria;
a skip is never release approval. Run the strict form for actual B2
coordinates and reverse-resize preservation.

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

**P0:** Provenance-preserving normal-screen compositor and scrollback-safe
resize/shutdown for both directions (70/70 unique markers and exact SGR).

**P0:** B2 Unicode border over the exact real selected cell; independent
positioned B1 with no target occlusion or history mutation.

**P1:** RGB/256 specimen styling, Unicode combining/wide continuation,
cursor-follow collision/clamping, user-visible coordinates/statistics,
and removal of the dormant alternate-screen transition helper.

Retain the canonical ABC/OCP task identities when implementing and reviewing.
A green component test is never sufficient to close a red strict gate.
