# ElmTUI style contract — cross-layer review (2026-10-23)

## Outcome

Reconciled the `cl-styles` registry, strict type checker, TUI compatibility
adapter, ElmTUI DSL, terminal-style conversion and per-cell painter.
**83 registered canonical properties** now have automatically enumerated
representative and rejection cases in an ordinary, ASDF-loaded FiveAM suite:
`tests/style-contract-matrix-tests.lisp`, under
`elmtui.tests:elmtui-test`. Every advertised enum value is tested.

## Cross-layer contract

| Surface | Validated behavior | Caveat |
|---|---|---|
| Dimensions | Numbers, `:auto`, `:fill`, integer percentage strings for width, height and flex-basis | Arbitrary CSS lengths are not implemented by ElmTUI layout |
| Flex/grid | All registered names, enums and declarative collection types; legacy aliases `:direction`, `:justify`, `:align`, `:spacing` and `:grid-gap` | Matrix checks value/type propagation, not visual parity of every advanced grid feature |
| Box/visibility | Border, margin, padding, overflow, visibility, aspect-ratio, z-index, position and border-radius have strict declaration definitions | Not all CSS semantics are implemented: z-index, absolute positioning, rounded borders, and dashed/dotted border glyphs need separate visual qualification |
| Text | `:white-space :normal` / `:nowrap`, opacity, font metadata and foreground/background color aliases are recognized | Font size/family and opacity are not terminal glyph rasterization/blending operations |
| Boolean SGR attributes | `:bold`, `:italic`, `:underline`, `:inverse`, `:faint`, `:blink`, `:strike` and `:invisible`, plus list aliases `:attrs` / `:attributes` | Explicit NIL overrides flags in both adapter paths |
| Colors | Named keywords, raw RGB triples, validated `(:rgb r g b)`, `(:rgba r g b alpha)`, `(:hsl hue sat light)`, `(:256 index)`, palette integers and `#RRGGBB` hex strings | RGBA alpha is representable in declarations, but no alpha blending exists in a terminal; HSL is converted to RGB |
| Terminal conversion | One canonical implementation behind both conversion entry points | The compatibility terminal backend keeps NIL input as NIL; canonical converter supplies an empty style |
| Normal-screen painter | Styled segments yield virtual-buffer cells and physical diff operations through the regular backend | Live tmux tests remain an opt-in integration lane |

## Defects found and closed

- The style registry omitted keys consumed by ElmTUI, including `:white-space`,
  `:overflow`, `:visibility`, `:align-self` and CSS-like editor/viewport hints.
- Style normalization incorrectly coerced optional NIL into `:NIL`; boolean
  flags had no typed contract; false booleans did not always override attr lists.
- The compatibility terminal converter had drifted from the canonical
  implementation: it dropped several SGR attributes and tokenized colors.
  Now it delegates after normalizing legacy aliases.
- The canonical color validator previously accepted malformed RGB/RGBA/HSL
  tokens; HSL tokens passed validation but rendered as no color. Both fixed.
- The cross-repository example source inventory was stale: it omitted the
  Workbench REPL adapter and the independently PTY-qualified tmux inspector.

## Verified commands

From the ElmTUI repository root:

    clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
      --eval '(require :asdf)' --eval '(asdf:load-system "elmtui-tests")' \
      --eval '(fiveam:run! (quote elmtui.tests.style-contract-matrix:style-contract-matrix-suite))'

    clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
      --eval '(require :asdf)' --eval '(asdf:test-system "cl-styles")'

    clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
      --load scripts/run-tests-clpm.lisp

**Results:** style matrix 446/446; cl-styles test suite 280/280; complete
ElmTUI FiveAM 8,894 checks, 8,888 passes, six expected live-tmux skips,
zero failures. All of this was run on the user's repo checkout.

Remaining high-value follow-up: public style-property capability tiers
(actually painted vs metadata vs accepted-but-unimplemented), byte-accurate
RGB/Unicode live terminal captures, and strict CI gates over that matrix.
