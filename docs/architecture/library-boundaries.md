# ElmTUI library boundaries

## Purpose

ElmTUI contains four reusable Common Lisp systems and one terminal UI toolkit.
This document defines which layer owns each mechanism so future changes do not
reintroduce parallel implementations.

```text
application code
      |
      v
+---------------------------+
|          elmtui           |
| UI policy, DSL, rendering |
+---------------------------+
  |       |        |      |
  v       v        v      v
cl-events cl-inputs cl-state cl-styles
```

The dependency direction is one way: ElmTUI may depend on the reusable
libraries; the reusable libraries must never depend on ElmTUI.

All four reusable systems are ordinary tracked directories in this repository,
not Git submodules. A tagged source archive must therefore be self-contained
and buildable without fetching a second repository.

## Ownership matrix

| Concern | Canonical owner | ElmTUI responsibility | Forbidden duplication |
|---|---|---|---|
| Channels and filtered channels | `cl-events.channel` | Typed UI channel wrappers and priority policy | Alternative mailbox/channel implementation in `src/` |
| Event/message structures | `cl-events.types` | UI-specific event adapters and compatibility aliases | Second generic event hierarchy |
| Pub/sub and event bus | `cl-events.bus` | Topic naming and UI dispatch policy | Independent generic bus registry |
| Async promises/tasks/timers | `cl-events.async` | Interpret ElmTUI commands/effects | Parallel promise or task engine |
| Generic event loop mechanics | `cl-events.loop` | Terminal lifecycle, render scheduling, shutdown policy | A second generic loop runtime |
| Terminal byte decoding | `cl-inputs.decoder` | Map tokens to ElmTUI messages | Escape/UTF-8 decoder in `src/platform` |
| Key sequence mapping | `cl-inputs.keymap` | Application key bindings/focus policy | Terminal escape keymap in ElmTUI |
| Input devices and sinks | `cl-inputs.device.*`, `cl-inputs.sink` | Select/configure devices and route messages | Duplicate TTY/fake-device transport |
| Generic nested paths | `cl-state.utils` | Compatibility wrappers and component path composition | Independent path traversal engine |
| State container and mutation log | `cl-state.core` | Application model conventions | Separate generic state container |
| Patches and transactions | `cl-state.patch`, `cl-state.tx` | Produce patches from update functions | Parallel patch application/undo engine |
| Observers | `cl-state.observer` | View invalidation bindings | Separate generic observer registry |
| Schema/type validation | `cl-state.schema`, `cl-state.validation` | Message/component contracts | Second type registry |
| Selectors and specificity | `cl-styles.selector` | Adapt UI nodes to selector protocol | Separate selector matcher |
| Rules, sheets, cascade | `cl-styles.rule`, `cl-styles.sheet`, `cl-styles.engine` | Manage application themes and renderer values | Parallel cascade implementation |
| Property normalization | `cl-styles.properties` | Translate canonical style values to terminal styles | A second generic property registry |
| Components and widgets | `elmtui.ui.*` | Full ownership | Moving terminal widgets into support libraries |
| View/layout/render pipeline | `elmtui.view.*`, `elmtui.platform.*` | Full ownership | Putting terminal rendering policy into support libraries |
| Application DSL and runtime policy | `elmtui.app.*`, `elmtui.runtime.*` | Full ownership | Making support libraries know ElmTUI application objects |

## Adapter rules

An ElmTUI adapter is valid when it does one or more of the following:

1. Converts a reusable-library value into a UI-specific value.
2. Adds terminal or component policy that the generic library should not know.
3. Preserves a historical public package name while delegating directly to the
   canonical implementation.
4. Aggregates several support-library calls into an application lifecycle step.

An adapter must not:

- copy the generic algorithm;
- maintain a second registry for the same data;
- silently change the support library's contract;
- expose an untested dependency cycle;
- depend on a support library's unexported symbol unless no public extension
  point exists and the dependency is documented.

## Current compatibility facades

### `elmtui.utils`

The historical `get-path`, `set-path`, and `remove-path` names remain available,
but they delegate to `cl-state.utils`. ElmTUI-specific handling of an
`application-state` is an adapter, not a second traversal engine.

### `elmtui.state`

This package is a convenience facade over `cl-state.api`, transaction/observer
APIs, and ElmTUI update/model helpers. New generic state functionality belongs
in `cl-state`; new TEA update semantics belong in `src/state`.

### `elmtui.core.event-channels`

Typed keyboard, mouse, system, UI, command, focus, and message channel classes
wrap `cl-events.channel` values. Filtering and transport remain canonical in
`cl-events`.

### `elmtui.style.manager`

The manager chooses active sheets and variables for an application. Selector,
cascade, and property mechanics remain in `cl-styles`.

## Source-tree policy

```text
cl-*/src/       reusable implementation only
cl-*/tests/     independent unit/integration tests for that system
src/            ElmTUI policy, adapters, widgets, rendering and platform code
tests/          cross-system and user-visible behavior
examples/       maintained executable usage examples
```

Files not referenced by an ASDF system must be one of:

- documented development tooling under `src/dev`;
- an intentionally optional secondary ASDF component;
- archived outside `src`.

Unreferenced compatibility implementations are not allowed in `src` because
they make ownership ambiguous. Nested Git repositories and self-referential
submodule URLs are likewise forbidden because they make release archives
incomplete and fresh clones non-reproducible.

## Dependency tests

Every release must prove both directions of the architecture:

```sh
scripts/test-subsystems.sh   # each cl-* system independently
scripts/release-check.sh     # independent systems + full ElmTUI integration
```

A root-suite pass alone is insufficient: it can hide an undiscoverable
secondary test system or permit an individual library runner to print failures
without failing ASDF.

## Adding functionality

Use this decision sequence:

```text
Is it useful without a terminal UI?
├─ no  -> implement in elmtui/src
└─ yes
   ├─ event/concurrency concern -> cl-events
   ├─ input byte/device concern -> cl-inputs
   ├─ state/path/validation concern -> cl-state
   ├─ selector/cascade/property concern -> cl-styles
   └─ otherwise -> propose a new focused library; do not add a misc bucket
```

When moving existing code into a support library:

1. Add/repair the independent library tests first.
2. Move the implementation and define the public package contract.
3. Replace the root implementation with a thin adapter.
4. Add cross-system integration tests.
5. Delete the obsolete implementation and update architecture docs.
6. Run the full release gate.
