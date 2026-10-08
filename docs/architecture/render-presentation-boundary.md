# ElmTUI rendering/presentation boundary — first milestone

## Responsibility split

The runtime owns event consumption, update scheduling, and deciding when a view
requires recomputation. No presenter starts a timer, polls the input device,
or initiates a redraw.

The view pipeline continues to resolve DSL/layout and render the layout into a
`virtual-terminal-buffer` (the next frame). The new
`elmtui.render.presentation` package owns the handoff from that next frame to
a presenter.

```text
message -> update -> view -> tree/layout -> virtual back buffer
                                             |
                             compute-frame-operations(front, back)
                                             |
                                    zero changes? -> no output
                                             |
                                  present-diff(presenter, operations)
                                             |
                                       success? -> commit front=back
```

## Contract

- `presenter-ready-p presenter`: availability check. Unknown presenters are
  unsupported and skip display in the pipeline.
- `compute-frame-operations front back`: calculate terminal-cell diff
  operations **without writing output**. A missing front frame or a size
  mismatch explicitly selects initial-frame policy. Operation rows and columns are zero
  based, relative to the frame origin.
- `present-diff presenter operations origin-row origin-col`: presenter
  protocol. Implementations must return non-NIL only if presentation
  succeeded. The diff operation format is the current
  `:write-chars` plist (`:row`, `:start-col`, `:chars`, `:style`).
- `present-frame presenter front back &key origin-row origin-col`: checks
  readiness, computes changes, skips the presenter call if there are none,
  and returns `(values operations t diff-metrics)` only after acknowledged
  presentation. The first two values remain compatible with earlier callers.

The `display-buffer` pipeline stage checks presenter readiness and sets its
front buffer only after `present-frame` returns successfully. A presenter
signalling an error or returning NIL for a nonempty diff must not cause the
application context to treat the unpresented frame as the new front frame.

No-op frames incur diff computation but **zero backend I/O**. Idle periods
incur **zero view/raster/diff/presentation passes**, because only the runtime
drives rendering on events (or explicit render requests).

## Adapters

- **Terminal:** the existing `terminal-instance` is accepted directly as
  `ctx-backend`; `present-diff` delegates to the existing terminal ANSI
  diff writer. No CLI/backend configuration change is required.
- **Recording:** `(make-recording-presenter)` is a backend substitute for
  tests. Inspect entries with `(recorded-presentations recorder)` in
  chronological order or call `(clear-recordings recorder)`. Each entry
  contains `:row`, `:col`, and a copied `:operations` list. It does not
  touch terminal output.

The recording backend is useful for screenshot-like assertions on cells and
style operations, without a terminal, a PTY, or any asynchronous event thread.

To add a presenter, implement `presenter-ready-p` and `present-diff`
methods on its backend class. Existing apps need not change their view DSL.

## Tested invariants

The `render-presentation-tests` suite verifies that changes are batched
and recorded, equal frames produce no presentation, resizing invalidates
the old dimensions, rejected/unsupported presenters do not advance the
front buffer, origin coordinates and recording order are preserved, the
terminal adapter calls the existing writer, and replaying cell operations
reproduces a target frame. Run it with:

```sh
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:load-system :elmtui-tests)' \
  --eval '(fiveam:run! (quote elmtui.tests.render-presentation::render-presentation-tests))'
```

## Pure cell diff core (second milestone)

The comparison and batching algorithm now lives in
`src/platform/render/diff.lisp` (package `elmtui.render.diff`), outside the
terminal backend. It reads virtual buffers and returns two values:

```lisp
(elmtui.render.diff:compute-buffer-diff
  previous next :initial-frame-p nil)
;; => values list-of-write-ops, diff-metrics
```

This function has no mutable process-wide first-call state, no terminal I/O,
and no writes to any global statistics structure. Every comparison has its
own counters (compared cells, changed cells, batches, full-redraws), returned
as `diff-metrics`. Input virtual buffers are not mutated.

An initial presentation is explicit: pass `NIL` as the previous frame or
`:INITIAL-FRAME-P T`. Initial comparison emits only painted characters and
styled spaces, leaving untouched background cells alone. An incremental
comparison requires identical sizes; a mismatched pair signals
`buffers-not-compatible-error`. The presentation facade treats a missing
or resized front buffer as an initial frame, without allocating a dummy
previous buffer or changing a shared first-call flag. Prefilled tmux frames
remain actual previous buffers and therefore receive incremental diffs.

The terminal-facing `compute-buffer-diff` remains a compatibility wrapper:
it delegates to the pure algorithm and returns per-call metrics, without
mutating diagnostic counters. The old exported
`*compute-buffer-diff-first-call*` variable is deprecated and **ignored**;
no driver code writes it during app startup, prefill or shutdown. Callers must
use the explicit frame argument instead. Terminal output still belongs to
`apply-diff-to-backend`, and the event loop still exclusively decides when
to schedule rendering; no frame timer was added.

Tests exercise deterministic repeated/interleaved initial and incremental
comparisons, explicit full redraw, resize validation, styled background
spaces, isolation from global diagnostics and replay correctness.

## Deferred work

The terminal writer now records successful writes and output operations in
each `terminal-instance` (operations, characters, cursor movements, style
changes, and style resets). Mutations, snapshots, and resets use the same
recursive terminal lock.

```lisp
(elmtui.platform.backend.terminal:terminal-output-statistics terminal)
(elmtui.platform.backend.terminal:reset-terminal-output-statistics terminal)
```

Both return independent `terminal-output-stats` snapshots. Resetting one
terminal does not affect any other terminal. The former global
`rendering-stats`, `get-rendering-stats`, `reset-rendering-stats`, and
process-wide mutable diagnostics were **removed**, not deprecated. Pure
comparison still returns per-call `diff-metrics`; `present-frame` also
returns them as the third value. No-op frames never enter the writer, and
partial failures only count output operations that completed.

Further qualification should include PTY performance measurements and
randomized tests for styles, clipping, and partial failure recovery.

The tree/layout engine is unchanged. Input remains the event-driven blocking
consumer introduced previously. No separate library or plugin framework
was introduced.
