# ElmTUI terminal style capabilities — executable contract

**2026-10-23 · Implementation and qualification**

The `cl-styles` registry validates declaration syntax; ElmTUI's terminal
renderer owns each property's runtime capability. The public functions
`elmtui.platform.tree-renderer:style-property-capability` and
`style-property-capability-report` expose the exact classifications.
An ASDF-loaded FiveAM suite fails if any registered canonical property is
missing, duplicated, or assigned an invalid tier. Registered aliases
inherit their canonical property's tier.

| Level | Properties | Meaning |
|---|---:|---|
| `:rendered` | 33 | Changes terminal cells or paint order, including documented terminal approximations |
| `:layout-only` | 41 | Influences geometry/flex/grid/spacing, without direct cell styling |
| `:metadata-only` | 7 | Retained for higher-level widgets or other backends |
| `:unimplemented` | 2 | Accepted by cl-styles but no supported terminal-tree behavior |

Exactly **83 canonical properties** are classified. The two unimplemented
ones are `:position` and `:border-radius`.

## Query it programmatically

```lisp
(elmtui.platform.tree-renderer:style-property-capability :border-top-style)
;; => :RENDERED
(elmtui.platform.tree-renderer:style-property-capability :border-radius)
;; => :UNIMPLEMENTED
(elmtui.platform.tree-renderer:style-property-capability-report)
;; => sorted list of (PROPERTY . LEVEL)
```

## Concrete semantics delivered

**Per-side borders:** `:border-top-style`, `:border-right-style`,
`:border-bottom-style` and `:border-left-style` independently select
solid/dashed/dotted/double/none and their own foreground colors. When
two sides intersect, the top/bottom edge wins the corner shape and color;
otherwise the remaining edge extends to the corner. A single edge can
override global `:border-style :none`. Border widths greater than one
cell do not yet imply a multi-cell-thick glyph stroke.

**Opacity:** Terminal cells cannot alpha-blend. ElmTUI's explicit
approximation is 0 = hide subtree, intermediate value = inherited SGR faint,
1 = normal paint. Multiplication of ancestor opacity is respected for
hiding/dimming. Different intermediate numbers need not yield distinct
visual intensities; this is not CSS opacity.

**Z-index:** Stable, ascending sibling paint order, equal indices retain
source order. Parents still bound clipping and stacking. This is not
browser-like positioned overlay composition or general CSS stacking contexts.

**Unicode cells:** Intrinsic sizing, painting, buffer comparison, diff
batches and physical clipping share cell-width accounting. Wide CJK and emoji
use a lead cell plus non-printing continuation; a lead cell can retain
an intact multi-codepoint grapheme, including uncomposable combining marks,
ZWJ emoji, flags, skin tones and variation selectors. NFC-composable accents,
copy, resize, clipping and diff idleness have direct FiveAM cases.
Terminal-dependent ambiguous East Asian widths and font-specific shaping
remain possible; this is a portable terminal approximation, not a promise
of identical glyph presentation on every terminal emulator.

## Test gates

The normal `elmtui-tests.asd` load now includes four relevant FiveAM suites:
`style-contract-matrix-suite`, `style-render-capabilities-suite`,
`style-capability-contract-suite` and `unicode-cell-contract-suite`.
One tests accepted declarations and types, one painted cell effects,
one enforces the full property tier map, and one verifies cluster/width,
copy/resize and physical diff boundaries.

```sh
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --load scripts/run-tests-clpm.lisp
python3 -m unittest discover -s tests/workbench/independent \
  -p 'test_native_repl_presentation.py' -v
python3 tests/workbench/pty-workbench.py
```

Live tmux tests are opt-in through `ELMTUI_RUN_TMUX_INTEGRATION=1`.
No alternate screen or custom Workbench ANSI painter was introduced.

## Architectural boundary

`cl-styles` stays renderer-agnostic: declaration validity is not the same
as terminal effect. The runtime manifest belongs to the ElmTUI terminal
tree renderer; other rendering backends may have different capabilities.
`:rendered` means a tested terminal effect, **not full CSS conformance**.
