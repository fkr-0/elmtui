# ElmTUI style capability qualification — rendered cells (2026-10-23)

This follow-up extends the [cross-layer declaration/type review](style-contract-cross-layer-20261023.md).
Registry acceptance, layout consumption and terminal painting are **different
contracts**. The new ordinary FiveAM suite
`tests/style-render-capabilities-tests.lisp` tests actual cells and diff
operations; it runs automatically through `elmtui-tests.asd`.

## Proven rendering behavior

| Property family | Observable behavior established in regression tests |
|---|---|
| Text colors and attributes | HSL -> RGB foreground, hex background and bold/underline/inverse/faint/strike are present on actual text cells |
| Border colors | `:border-color` changes border glyph foreground without changing node text foreground or terminal background |
| Per-edge border colors | `:border-top-color`, `:border-right-color`, `:border-bottom-color`, `:border-left-color` independently change their edge; corner colors follow the top/bottom edge |
| Border shapes | `:solid`, `:double`, `:ascii`, `:dashed`, `:dotted` yield distinct 1-cell glyphs; `:none` suppresses border |
| Visibility and overflow | `:display :none`, `:visibility :hidden` suppress painting; `:overflow :hidden` clips descendants |
| Diff lifecycle | Colored border glyphs survive frame diff; an identical subsequent frame generates no write operations |

### Previously accepted, now fixed

`:border-color` and per-edge colors were registered and accepted by
`cl-styles`, but `draw-border` always used the node's foreground color.
The renderer now builds edge-specific terminal styles from the existing
node style. This retains background and flags and does not mutate the
node's text style. Dotted/dashed declarations formerly displayed solid
borders; they now use terminal single-cell line-drawing glyphs.

### Not promised by these tests

- Accepted CSS-like metadata does **not** imply implementation: e.g.
  `:opacity`, `:font-family`, `:font-size`, `:border-radius` and
  `:z-index` are not qualified as visual terminal effects.
- Per-edge `:border-*-style` properties and multi-cell-thick borders
  need separate painting semantics and dedicated coverage. Per-edge
  **colors** are qualified; do not confuse the two.
- No alternate screen, terminal app startup, tmux underlay restore or
  Unicode grapheme-width promise is inferred from in-memory cell tests.
  Existing PTY suites remain their own release requirements.

## Run

    clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
      --eval '(require :asdf)' \
      --eval '(asdf:load-system "elmtui-tests")' \
      --eval '(fiveam:run! (quote elmtui.tests.style-render-capabilities::style-render-capabilities-suite))'

For global regressions:

    clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
      --load scripts/run-tests-clpm.lisp

**Verified on this checkout:** 60/60 new rendering assertions, full ElmTUI
FiveAM **8,960 PASS / 6 expected live-tmux SKIP / 0 FAIL** (8,966 checks),
and REPL CLI/private-PTY **4/4 PASS**. The exact total includes unrelated
concurrent work and is not a fixed snapshot of historical test counts.

Unrelated concurrent checkout modifications were left untouched.
