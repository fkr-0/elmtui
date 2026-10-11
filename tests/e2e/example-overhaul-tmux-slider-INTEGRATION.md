# EX-10 tmux slider — integration and blocker handoff

Canonical task: `ELMTUI-EX-10-TMUX-SLIDER-20261009`
Canonical packet: `bc76b3a6-5bf8-44d5-be37-ea8d13590dd2`
Status: **BLOCKED — do not advertise, register in a release, or capture the promotional GIF yet.**
Owner scope for EX-10 is restricted to `examples/tmux-slider.lisp`,
`examples/tmux-idle-screensaver.lisp`, and `tests/e2e/example-overhaul-tmux-*`.
The existing `run-tmux-idle` remains untouched and backward compatible.

## Candidate implementation

`elmtui.examples.tmux-slider:run-tmux-slider` snapshots the visible tmux pane
using `capture-pane -p -e -S 0` **before** the driver enters its alternate
screen. It parses ANSI SGR into immutable per-cell `(glyph . style)` data.
The intended ElmTUI DSL frame contains contiguous style runs, with the original
glyph preserved beneath an eight-column cyan/violet highlight. Frame state,
timing, pause/resume and controls use native TEA update/subscriptions. Pausing
removes the timer subscription. No terminal ANSI is written manually by the
application; tmux commands only read metadata/capture. No-tmux or capture
failure refuses to start before touching the TTY.

Controls: Space/P pause, Left/Right direction, Up/Down or +/- speed, Q/Escape
exit; optional `:speed` and `:frames` runner keywords allow finite GIF takes.
A small HUD occupies top-row characters; this intentionally does *not* preserve
those particular visible characters while the alternate-screen demo is active.
This exception must be made explicit in release messaging.

## Reproductions / verification

Run with CLPM-installed SBCL:

    clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
      --eval '(asdf:load-system "elmtui")' \
      --eval '(compile-file "examples/tmux-slider.lisp")'

    python3 tests/e2e/example-overhaul-tmux-slider-unit.py
    python3 tests/e2e/example-overhaul-tmux-slider.py
    python3 tests/e2e/tmux-scrollback-restoration.py

Observed with the contemporaneous worktree:

- Source compiles; standalone pure styled-cell/immutable-highlight fixture
  passes 1/1.
- Existing broader tmux restoration tests passed 5/5 at task start.
- Real private tmux early-exit test passes, preserving 75 seeded history
  markers, visible underlay marker, styled marker, terminal termios and cursor.
- Fake/direct-row diagnostic could animate and exit; pause-no-writes,
  finite-8-frame and no-tmux tests passed (4-case script yielded 3/4).
- **Hard failure:** grouped native per-cell styled-row DSL produces no frames
  beyond alternate-screen entry in a 70-marker fixture; underlay content is
  not visible. Flat one-text-per-row diagnostic allows frame changes, but
  its viewport still paints only the HUD; underlying text in subsequent rows
  remains invisible. The flat variant also cannot retain individual cell
  styles. Thus neither layout is eligible for release.
- 80x24 / 120x40, resize, repeated launch and interrupt qualification have
  **not** been passed. The prototype root viewport is presently fixed
  at 100x35. Wide grapheme/combining-width/SGR details also need validation.
- Test harness first versions raced `terminal.raw` creation; corrected by
  checking for file existence. Comparing `capture-pane -p` without `-e`
  hides style-only frame changes. Historical matching uses full `-S -`
  capture, separate from the app's own terminal scrollback.

## Separate-owner backend/layout fixup (do not edit shared code as EX-10)

Establish a renderer-native small fixture with two visible rows, one styled
red word and an adjacent default-colored word, for both regular and
alternate-screen presenters. Inspect `src/view/layout/flex.lisp`,
`src/ui/widgets/root-viewport.lisp`, `src/pipeline`,
`src/render/presentation.lisp`, and terminal diff presenter to verify:
(a) each nested flex row has a distinct y coordinate,
(b) each native style-run text child has a distinct x coordinate,
(c) the virtual frame contains all original visible cells,
(d) the initial diff actually writes those cells in alternate-screen mode,
(e) no frame starts painting after exit, and
(f) no unrelated scrollback displacement occurs.
Do not patch the shared render/driver code through the EX-10 ownership claim.
Request a separately ownable follow-up with a focused failing regression, then
rerun EX-10 private PTY tests and obtain an independent reviewer verdict.

## EX-08 integration instructions (conditional; not release-ready)

When EX-10 independently passes all acceptance tests and is committed:

1. Add `examples/tmux-slider.lisp` to `elmtui-examples.asd` in the maintained
   examples component list, after the tmux examples it depends on.
2. Register the `tmux-slider` argument in `scripts/examples.sh` with runner
   `(elmtui.examples.tmux-slider:run-tmux-slider)`.
3. Update `examples/README.md` to document tmux requirement, capture
   preconditions, speed/finite-frame options, pause and quit controls,
   alternate-screen restoration, and known escape/Unicode limitations.
4. Include EX-10 private tmux/PTY tests in the integration release gate only
   after independent approval. Do **not** mark successful just because the
   original five tests pass.

This file is deliberately under the EX-10-owned test prefix rather than
editing the shared runner, manifest or README.
