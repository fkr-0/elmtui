---
# AI Metadata Tags
ai_keywords: [Dev Module, Development Tools, Debugging, Introspection, Runtime Snapshot, Buffer Dump, Element Tree, REPL]
ai_contexts: [development, debugging, meta]
ai_relations: [
  "./implementation.md",
  "../core/overview.md",
  "../view/overview.md",
  "../platform/overview.md",
  "../../dev-guides/troubleshooting.md",
  "../../../tasks/README.md"
]
---

# Dev Module Overview

The maintained `elmtui.dev` package is intentionally small. It provides read-oriented helpers for inspecting the current runtime and renderer data from a Lisp REPL without introducing a second event loop, dashboard, transaction system, or rendering path.

The authoritative implementation is `src/dev/dev.lisp`, which is loaded by the main `elmtui` ASDF system. Older files under `src/dev/` such as `event-monitor.lisp`, `event-dashboard.lisp`, `transaction-viewer.lisp`, and `view-debug.lisp` are not part of a maintained ASDF system and must not be treated as available public APIs. Their status is tracked in `tasks/README.md`.

## Maintained public API

### `runtime-snapshot`

Returns a plist containing a side-effect-free snapshot of currently exposed runtime diagnostics:

- `:event-loop` — the result of `elmtui.core.loop:get-event-loop-status`;
- `:queue-length` — current queued-event count;
- `:subscription-count` — current topic subscription count;
- `:topics` — topics that currently have subscribers;
- `:application-state-present-p` — whether the global application-state slot is populated.

```lisp
(elmtui.dev:runtime-snapshot)
```

### `format-runtime-snapshot`

Formats a snapshot for interactive inspection. With no argument it captures a fresh snapshot first.

```lisp
(format t "~A" (elmtui.dev:format-runtime-snapshot))
```

The formatter reports consumer-thread activity, active channels, queue length, processed-event count, average processing time, subscription count, topics, and whether application state is present.

### `format-element-tree`

Formats a lowered `elmtui.view.base-elements:base-element` tree. It shows element type and id, and includes layout rectangles when layout has been computed. Pass `:include-style t` to include the resolved style plist.

```lisp
(format t "~A"
        (elmtui.dev:format-element-tree root-element
                                        :include-style t))
```

This helper operates on the maintained lowered element model, not the historical `ui-node` debugging stack.

### `buffer->string`

Returns the contents of a virtual terminal buffer as plain text. It does not write to `*standard-output*`, which makes it suitable for assertions, debugger output, and snapshot-style diagnostics.

```lisp
(elmtui.dev:buffer->string buffer)
```

### `with-buffer-dump`

Runs a body with an error handler that prints the current virtual-buffer contents to `*error-output*` before invoking the debugger on the original condition.

```lisp
(elmtui.dev:with-buffer-dump (buffer)
  (operation-that-may-fail))
```

Use this when the rendered buffer is useful failure context. It is deliberately not a recovery mechanism.

### `dev-main`

Prints the formatted current runtime snapshot and returns the underlying plist. It is a quick REPL entry point rather than a separate development server.

```lisp
(elmtui.dev:dev-main)
```

## What is not currently supported

The maintained dev package does **not** currently promise:

- an event-monitor dashboard;
- transaction-history UI or time-travel debugging;
- a hot-reload development server;
- component dependency visualization;
- always-on profiling hooks;
- per-widget debug renderers;
- state replay APIs.

Some older documentation and orphan source files described or prototyped those capabilities. They are not loaded by maintained systems and several no longer compile against current APIs. New tooling should be built from current runtime/state/rendering contracts rather than reviving those files wholesale.

## Development direction

The validated backlog in `tasks/README.md` keeps four development-tool directions:

1. reproducible runtime/event/render benchmarks before optimization;
2. an opt-in structured event → update/state → render causality trace;
3. one optional tested profiler instead of the two orphan profiler implementations;
4. focused current API/troubleshooting documentation rather than broad duplicate guides.

Any new tool should remain opt-in, preserve runtime semantics, expose structured data before presentation, and have deterministic focused tests where practical.

## Verification

The maintained dev helpers are covered by `tests/dev-tests.lisp`. The focused suite checks pure buffer conversion, runtime-snapshot shape/formatting, and lowered-element tree formatting.

## Related resources

- [Implementation details](./implementation.md)
- [Current task audit](../../../tasks/README.md)
- [Troubleshooting guide](../../dev-guides/troubleshooting.md)
- [Core module overview](../core/overview.md)
- [View module overview](../view/overview.md)
- [Platform module overview](../platform/overview.md)
