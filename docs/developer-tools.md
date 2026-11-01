# Developer utilities

`elmtui-dev` is an optional diagnostics and microbenchmark system. Loading
`elmtui` alone does not load these packages or start a monitor, timer, input
device or terminal backend.

```sh
clpm bundle exec --with-client sbcl
```

```lisp
(asdf:load-system "elmtui-dev")
```

## Maintained tools

| Tool | Purpose | Result / effect |
|---|---|---|
| `elmtui.dev:runtime-snapshot` | Inspect process event-loop counters, queues and topics | A timestamped plist; no terminal output or model/event payload dump |
| `elmtui.dev:format-runtime-snapshot` | Format a saved snapshot | String; does not resample counters |
| `elmtui.dev:format-element-tree` | Inspect lowered node IDs, layout rectangles and optional styles | Bounded string; cycles and truncation are marked |
| `elmtui.dev:render-view` | Preview base-element DSL through ElmTUI layout and rendering | Two values: virtual buffer, laid-out tree; no terminal backend |
| `elmtui.dev:buffer->string` | Read a virtual frame as plain text | Unicode rows with newlines; graphemes preserved, wide-cell continuation markers omitted |
| `elmtui.dev:with-buffer-dump` | Attach buffer evidence to an error | Writes to the selected stream and leaves normal condition/restart handling intact |
| `elmtui.dev:dev-main` | Print current process diagnostics | Prints to an optional stream and returns the snapshot |
| `elmtui.dev.benchmark:benchmark-thunk` | Time a synchronous operation with warmup | Timing/allocation/context plist |
| `elmtui.dev.benchmark:run-benchmark-suite` | Run the maintained event-transform and key-normalization microbenchmarks | List of result plists; printing is optional |
| `elmtui.dev.benchmark:stress-event-pipeline` | Repeat event-transform measurements | Individual samples and min/median/max rates |
| `elmtui.dev.benchmark:compare-benchmark-results` | Compare like-named, measurable rates | Ratio, comparison status and pass flag |
| `elmtui.dev.benchmark:write-benchmark-baseline` / `read-benchmark-baseline` | Save/load local benchmark data | One readable Lisp value; reader evaluation disabled on input |

Use `elmtui.dev:dev-main` for diagnostics. (The silent root placeholder
`elmtui:dev-main` was removed in 0.4.0.)

## Capture runtime diagnostics

```lisp
(let ((snapshot (elmtui.dev:runtime-snapshot)))
  (getf snapshot :queue-length)
  (write-string (elmtui.dev:format-runtime-snapshot snapshot)))

;; Print directly to a chosen output stream:
(elmtui.dev:dev-main *standard-output*)
```

The snapshot has `:scope :process`, `:captured-at` (universal time),
`:lisp-implementation`, `:event-loop`, `:queue-length`, `:subscription-count`,
`:topics`, and `:application-state-present-p`. The loop section includes active
consumer/channel counts, shutdown status, processing counts and average duration.
It intentionally omits the last event's arbitrary payload.

These counters are approximate, independently sampled process observations.
They are not an atomic snapshot or a per-application performance profile.

## Preview and inspect a view

```lisp
(multiple-value-bind (buffer tree)
    (elmtui.dev:render-view
     '(:container :id :preview
       :style (:display :flex :flex-direction :column)
       :children
       ((:text :id :greeting :content "Hello, 界!"
         :style (:height 1 :fg-color :cyan :bold t))))
     40 6)
  (write-string (elmtui.dev:buffer->string buffer))
  (write-string (elmtui.dev:format-element-tree
                 tree :include-style t :max-depth 8 :max-nodes 100)))
```

This runs the same ElmTUI base DSL conversion, tree layout and virtual-buffer
renderer used by the application presentation path. Width and height are
positive display-cell counts. It does not initialize application components,
run update/subscription handlers, or prove real-terminal presentation. Supply
the lowered `:container`/`:text` DSL from a view; component lifecycle lowering
still belongs to the application runtime.

Tree inspection defaults to at most 20 element levels and 500 visited nodes.
It marks element and sibling-list cycles instead of recursing indefinitely.
Printed property lists are also bounded. Buffer dumps preserve multi-codepoint
graphemes and omit the internal NUL cells that reserve wide-glyph tails.

## Preserve error diagnostics

```lisp
(multiple-value-bind (buffer tree)
    (elmtui.dev:render-view '(:text :content "Debug frame") 40 4)
  (declare (ignore tree))
  (with-open-file (log #p"/tmp/elmtui-buffer.log"
                       :direction :output :if-exists :append
                       :if-does-not-exist :create)
    (elmtui.dev:with-buffer-dump (buffer :stream log)
      ;; Replace this with the operation being investigated.
      (error "Example failure"))))
```

`with-buffer-dump` evaluates its buffer and stream expressions once and writes
at most one dump per invocation. It does not invoke the debugger directly,
replace the original condition, or remove its restarts. A dump failure does
not mask the operation's error. The default stream is `*error-output*`; choose
a file or string stream while a terminal UI owns the display.

## Measure and compare

```lisp
(let ((results (elmtui.dev.benchmark:run-benchmark-suite
                :iterations 200000 :print-results nil)))
  (elmtui.dev.benchmark:write-benchmark-baseline
   #p"test-output/benchmarks/baseline.sexp" results))

(let* ((baseline (elmtui.dev.benchmark:read-benchmark-baseline
                  #p"test-output/benchmarks/baseline.sexp"))
       (candidate (elmtui.dev.benchmark:run-benchmark-suite
                   :iterations 200000 :print-results nil)))
  (mapcar (lambda (before after)
            (elmtui.dev.benchmark:compare-benchmark-results
             before after :minimum-ratio 0.90d0))
          baseline candidate))

(elmtui.dev.benchmark:stress-event-pipeline :rounds 6 :iterations 200000)
```

Results include elapsed ticks/seconds, CPU seconds, clock resolution,
`:measurement-valid-p`, ops/s, ns/op, allocation totals and bytes/op where
supported, iteration/warmup counts, and Lisp/OS/machine context. Even-sized
stress runs average the central two rates for their median.

Zero elapsed ticks are marked insufficient resolution; increase iterations.
The numeric rate/cost fields retain their historical zero values in this case,
but printing reports the limitation and comparison cannot pass. Comparison
rejects mismatched names or invalid rates. Differing recorded runtime/host
context produces `:context-mismatch` and cannot pass; old baseline files without
context remain readable. `:comparable` means the threshold was evaluated, not
that a performance change is statistically significant.

These are synchronous microbenchmarks. Pipeline throughput does not establish
mailbox throughput, input-device latency, frame rate, idle CPU use, or PTY
correctness. Loop overhead, allocation granularity, GC, scheduling and other
process activity affect measurements. Use repeated samples on the same host
under similar load; the developer tools do not impose a CI timing threshold.

Baseline files contain exactly one data value. Empty files, reader evaluation
and additional forms are rejected. Parent directories are created on write.

## Verification and legacy inventory

```sh
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --eval '(asdf:test-system "elmtui-dev-tests")'
```

This target runs both diagnostics and benchmark tests, fails ASDF on either
failure, and is included in the root integration test dependencies. Developer
sources are excluded from the mandatory-toolkit coverage metric.

The other retained files under `src/dev` are **not loaded by this system**:

| Legacy source | Original intent / current boundary |
|---|---|
| `profiler.lisp` | Startup timing/checkpoints; not a maintained loaded profiler |
| `view-debug.lisp` | Earlier view debugging; refers to legacy view interfaces |
| `event-monitor.lisp`, `event-dashboard.lisp` | Earlier event visualization/dashboard design |
| `event-throttler.lisp` | Earlier throttling/debouncing helpers |
| `event-benchmark.lisp` | Earlier event benchmark design; use `benchmark.lisp` instead |
| `transaction-viewer.lisp` | Earlier interactive history viewer; stale widget/import contracts |
| `deprecation.lisp` | Unpromoted deprecation helpers |

They are retained for reference, with no release-readiness claim. Promoting any
one requires an explicit ASDF owner, current dependency contracts and behavioral
tests; loading `elmtui-dev` does not silently expose them.
