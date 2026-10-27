# Unicode overlapping glyph ownership — renderer regression closure

**Date:** 2026-10-27

## Root cause

ElmTUI already stores a double-width grapheme as one lead cell and a
`#\Null` continuation. Its virtual renderer originally wrote new glyphs one
cell at a time. When a later sibling, border or retained-frame update
overwrote the second cell of an existing wide grapheme, the old lead
remained. Physical diffs could then emit both the original wide glyph and
the new, overlapping glyph, producing inconsistent terminal geometry.
Overwriting a wide lead similarly stranded a continuation.

## Correctness contract

`src/platform/tree-renderer.lisp` now owns a single painting helper for
ordinary glyphs, full grapheme clusters, backgrounds, and borders:

* A written glyph reserves its complete cell footprint, including its
  trailing non-printing continuation.
* Overpainting any cell belonging to a prior wide glyph erases **both**
  cells before painting the replacement.
* Replacing the old glyph with a newly positioned wide glyph also clears
  an overlapping old footprint in full.
* Existing grapheme strings (including VS16 emoji presentation) determine
  the actual width, rather than relying solely on the lead codepoint.
* If clearing the prior wide glyph would cross an inherited clipping
  boundary, the new partial write is refused. Nothing outside the clip
  is silently modified.

This is the terminal-tree painter's ownership rule, not a Workbench
special-case or a second ANSI renderer. No alternate screen was added.

## Regression coverage

Regular FiveAM assertions under
`tests/style-render-capabilities-tests.lisp` cover:

* Wide-then-narrow overlap at the lead and continuation;
* A new wide glyph positioned on the old wide glyph's continuation;
* Incremental rendering without clearing the original buffer;
* Border glyphs painted across an earlier wide glyph;
* A hidden-overflow parent where the old glyph crosses the clip boundary;
* Multi-codepoint emoji presentation graphemes and actual resulting diffs.

The test suite was first run against the original painter and failed on
orphaned leads/continuations; all cases pass after the fix.

## Qualification

* `style-render-capabilities-suite`: **107 PASS, 0 FAIL**.
* Entire ElmTUI FiveAM suite: **9,989 PASS / 6 SKIP / 0 FAIL**
  (9,995 checks; six tmux integration checks intentionally opt-in).
* Workbench native REPL independent tests: **5 PASS**.
* Workbench private PTY: **PASS** at 80×24, 120×40, 160×50.
* `git diff --check`: clean.
* Approximate 160×50 all-background paint benchmark: **7.1 ms per
  frame**, across 12 in-process frames on the current test machine.
  This is not a baseline comparison or a release performance guarantee.

## Remaining behavior to qualify

Physical emulator glyph shaping and ambiguous-width fonts remain
terminal-dependent. This patch guarantees *virtual-buffer integrity* and
correctly addressed diff operations for supported grapheme widths, not a
full implementation of Unicode's every grapheme boundary or a universal
terminal rendering conformance suite. Further end-to-end capture fixtures
for actual unicode-overlap transitions should be performed in the live tmux
integration lane before claiming visual parity across terminal emulators.
