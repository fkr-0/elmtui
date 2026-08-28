---
# AI Metadata Tags
ai_keywords: [Dev Implementation, Runtime Introspection, Virtual Buffer, Element Tree, REPL, Testing]
ai_contexts: [implementation, development]
ai_relations: ["./overview.md", "../core/implementation.md", "../view/implementation.md", "../platform/implementation.md", "../../../tasks/README.md"]
---

# Dev Module Implementation Details

## Ownership and load boundary

The maintained dev implementation is `src/dev/dev.lisp`. It is part of the main `elmtui` system and therefore must stay lightweight: loading `elmtui` must not start monitor threads, install tracing hooks, mutate application state, or pull in an alternate rendering/event stack.

The implementation deliberately delegates to current owners instead of duplicating their state:

| Diagnostic | Owner queried by `elmtui.dev` |
| --- | --- |
| event-loop status / queue length | `elmtui.core.loop` |
| topic/subscription diagnostics | `elmtui.core.topic-registry` |
| application-state presence | `elmtui.core.globals` |
| lowered element structure | `elmtui.view.base-elements` |
| layout rectangle coordinates | `elmtui.view.geo` |
| virtual-buffer contents | `elmtui.platform.backend.common.virtual-buffer` |

This makes the dev module a presentation/introspection layer rather than another source of truth.

## Runtime snapshot contract

`runtime-snapshot` returns ordinary Lisp data. It does not retain references in a history buffer or install observers. The event-loop sub-plist comes from `get-event-loop-status`; the remaining keys are sampled independently at call time, so callers should treat the result as diagnostic rather than an atomic runtime transaction.

`format-runtime-snapshot` accepts that plist and renders a stable, human-readable REPL summary. Keeping capture and formatting separate allows tests and future structured consumers to inspect the same data without parsing text.

## Element-tree inspection

`format-element-tree` accepts either one `base-element` or a list of sibling elements. It walks `element-children` depth-first and prints:

- the canonical DSL element type;
- an element id when present;
- `(x,y) width×height` when a layout rectangle exists;
- the resolved element style only when `:include-style t` is requested.

It intentionally targets the maintained lowered-element protocol. The orphan `src/dev/view-debug.lisp` stack targets an older `ui-node` model and is not a dependency.

## Virtual-buffer diagnostics

`buffer->string` iterates rows and columns through the virtual-buffer public accessors and writes only to the local string output stream. This property is tested explicitly so the helper can be used safely in test assertions.

`with-buffer-dump` uses `handler-bind` so the original condition is still active when the debugger is entered. The buffer is written to `*error-output*` as context; the macro does not swallow or replace the failure.

## Adding developer tooling

New tooling should follow these constraints:

1. query maintained owner APIs rather than reaching into stale orphan packages;
2. return structured Lisp data separately from presentation when practical;
3. avoid background threads/hooks at system-load time;
4. keep instrumentation opt-in and make overhead visible;
5. add focused deterministic tests;
6. use a dedicated optional ASDF system if a tool needs heavyweight dependencies or persistent instrumentation.

The next validated tooling work is tracked as DEV-002 through DEV-004 in `tasks/README.md`. In particular, do not add the old event-monitor/dashboard files to ASDF just to make their packages visible; they must be redesigned around current APIs.

## Tests

`tests/dev-tests.lisp` defines `DEV-TEST-SUITE` and verifies:

- `buffer->string` returns the expected text without writing to `*standard-output*`;
- `runtime-snapshot` exposes the documented data shape and formats successfully;
- `format-element-tree` includes parent/child types and ids.

Run the focused checks through the project CLPM bundle, for example:

```text
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:load-system "elmtui-tests")' \
  --eval '(unless (uiop:symbol-call :elmtui.dev.tests :run-dev-tests) (uiop:quit 1))'
```

## Known limits

- A snapshot is observational, not atomic across subsystems.
- There is no maintained event/state causality history yet.
- There is no maintained profiling API yet.
- Element-tree inspection expects lowered base elements, not arbitrary component instances.
- Buffer dumps intentionally omit terminal escape reconstruction and expose plain cell characters only.

See `tasks/README.md` for the audited replacement tasks and the classification of orphan developer-tool sources.
