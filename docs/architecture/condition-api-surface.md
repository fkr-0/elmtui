# ElmTUI 0.2.0 — condition hierarchy and public API boundary

Audit date: 2026-10-09  
OCP identity: `ELMTUI-CLPM-02-ARCHITECTURE-R020-HARDEN-20261009`

## Condition taxonomy

The canonical framework root is `ELMTUI.CORE.ERRORS:ELMTUI-CONDITION`. Multiple inheritance with Common Lisp's built-in condition families is intentional:

```text
CL:CONDITION
└── ELMTUI-CONDITION
    ├── ELMTUI-INFORMATION                      (not an ERROR or WARNING)
    ├── ELMTUI-WARNING   + CL:WARNING
    └── ELMTUI-ERROR     + CL:ERROR
        ├── RUNTIME-ERROR
        │   ├── STATE-ERROR
        │   ├── MESSAGE-VALIDATION-ERROR
        │   ├── COMMAND-EXECUTION-ERROR
        │   ├── EVENT-LOOP-DISPATCH-ERROR
        │   ├── ASYNC-TASK-ERROR
        │   ├── STATE-UPDATE-ERROR
        │   ├── SUBSCRIBER-HANDLER-ERROR
        │   ├── RENDER-ERROR
        │   └── SIGNAL-SUBSCRIBER-ERROR
        ├── PLATFORM-ERROR
        │   └── BACKEND-ERROR
        ├── COMPONENT-ERROR
        │   └── DEFCOMPONENT-ERROR
        ├── DSL-ERROR
        ├── MESSAGE-SERIALIZATION-ERROR
        ├── MESSAGE-DESERIALIZATION-ERROR
        └── ELMTUI-VALIDATION-ERROR
            ├── TYPE-VALIDATION-ERROR
            ├── PROPERTY-VALIDATION-ERROR
            ├── CONSTRAINT-VALIDATION-ERROR
            └── EVENT-VALIDATION-ERROR
```

Other maintained framework conditions in `src/contracts.lisp`, state, render, virtual-buffer, keymaps, async, and DSL modules already inherit `ELMTUI-ERROR` directly or through these families. `KEYMAP-ERROR` also inherits `CL:SIMPLE-ERROR`, intentionally preserving existing simple-error handlers. Do not remove existing subtype inheritance or reconstruct conditions inside handlers: exact condition identity, active restarts, and debugger state are part of the compatibility contract.

**Explicit remaining exception:** `src/workbench/eval.lisp` defines `EVALUATION-ABORTED` directly under `CL:CONDITION`. It has not been migrated because the workbench is concurrently owned by a separate worker and excluded from this task. Workbench ownership must be resolved before changing it. Concrete warning/information specializations can be introduced when there is an actual signaling use case; do not manufacture them solely to fill a hierarchy.

## Diagnostic context schema

Use `ELMTUI.CORE.ERRORS:+DIAGNOSTIC-CONTEXT-KEYS+` and `DIAGNOSTIC-CONTEXT-KEY-P` as the canonical vocabulary.

| Key | Value and meaning |
|---|---|
| `:operation` | Operation identifier, commonly a keyword |
| `:component-id` | Component's stable identity |
| `:component-path` | Path within the component tree |
| `:state-path` | State location represented by a path |
| `:backend` | Backend identifier |
| `:message` | Input/application message |
| `:event` | Event being processed |
| `:offending-value` | Value responsible for the failure |
| `:expected-type` | Expected type or contract |
| `:underlying-condition` | Original cause, preferably the original condition object |

The existing `ELMTUI-ERROR-CONTEXT` slot carries caller-owned Lisp data, often an alist. Do not stringify values, require one single representation retroactively, or reject extension keys: callers already provide structured legacy context. `WITH-ERROR-CONTEXT` currently annotates the original condition in place; `:context`, `:module`, and `:macro-arg` are preserved compatibility annotation keys rather than canonical domain keys. Define schema validators separately from this backward-compatible reader if a strict contract becomes necessary.

## Reader migration and compatibility

- **Public:** prefixed accessors such as `ELMTUI-ERROR-MESSAGE`, `MESSAGE-VALIDATION-ERROR-MESSAGE`, `ASYNC-TASK-ERROR-REASON`, `STATE-UPDATE-ERROR-STATE`, `SIGNAL-SUBSCRIBER-ERROR-SIGNAL`, and `VALIDATION-ERROR-MESSAGE`.
- **Legacy/internal:** `MESSAGE`, `REASON`, `STATE`, `EVENT`, `TASK`, `HANDLER`, `CMD`, `SUBSCRIBER-SIGNAL`, and `ORIGINAL-ERROR` remain interned and callable in `ELMTUI.CORE.CONDITIONS`, but not exported there. Existing explicit `package::reader` uses continue to work.
- **0.2.x compatibility:** retain the legacy internal functions and concrete condition type names. New application code must use prefixed exported readers. Any subsequent removal requires separate deprecation documentation, call-site search, and major-version approval; this pass does not remove handlers or readers.
- **Re-exports:** the API packages intentionally provide convenience facade re-exports. Retain their existing symbol identities; do not replace with parallel copied symbols or reduce them in a maintenance release.

## API-surface audit

An SBCL runtime inspection of all loaded `ELMTUI*`, `CL-EVENTS*`, `CL-STATE*`, `CL-INPUTS*`, and `CL-STYLES*` packages found:

| Measure | Value |
|---|---:|
| Inspected packages | 135 |
| External symbol occurrences (includes re-exports) | 3,094 |
| External occurrences whose home package differs | 950 |
| Exported symbols homed in `SB-*` implementation packages | 0 |

The largest facade re-export groups are `CL-EVENTS.API` (191), `ELMTUI.STATE` (157), `CL-STYLES.API` (137), `ELMTUI.STATE.API` (129), `CL-STATE.API` (123), and `CL-INPUTS` (118). **Only two public occurrences have a symbol home outside the ElmTUI/CL-* project families:** `COMMON-LISP:USE-VALUE` is exported by `ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER`, then re-exported by `ELMTUI`. This historical standard restart-name symbol is retained during the 0.2.x compatibility window; it is not a new ElmTUI reader or function and can be deprecated separately at an API-major boundary. The focused export-boundary test permits exactly those two occurrences and rejects new foreign-family exports. The full 950-row checked-in alias manifest, including seven private-origin exceptions, is recorded in `docs/architecture/facade-reexports.tsv` and analyzed in `docs/architecture/facade-reexports-review.md`; `scripts/audit-facade-exports.py` enforces the exact current identity and origin visibility in CI. This confirms **no SB-PCL-style implementation-private symbol leak** was found in the loaded packages, but is **not** proof that each of the remaining 948 same-family re-export occurrences was individually curated. Maintain explicit facade manifests in a separate compatibility-reviewed API reduction; preserve existing exports until then.

A focused regression in `tests/condition-system-tests.lisp` now verifies all `ELMTUI.CORE.ERRORS` and `ELMTUI.CORE.CONDITIONS` external symbols are owned by their named package, and that generic condition readers are not external.

The docstring ratchet (`scripts/check-docstrings.sh`) on this audit reported **1,819 unique exported bindings, 562 missing documentation, 69.1% coverage**. The non-regression threshold is now 562, down from the original 782, after adding 25 substantive condition-class/accessor contracts. These remaining bindings are *not* declared intentionally-undocumented by this audit. They are real documentation debt being addressed by the separate docstrings-remediation task, and should not be bulk-whitelisted without an explicit owner and rationale for each item. An intentional-undocumented exception should be recorded per binding and reviewed; a large automatic legacy allowlist would conceal quality debt.

## Verification and constraints

- `tests/condition-system-tests.lisp`: 3,454 focused checks passed, 0 failed, including implementation-private and cross-family export regressions.
- Required full suite: 8,052 checks; 8,046 passed, 6 opt-in live-tmux checks skipped, 0 failed.
- `ELMTUI.CORE.CONDITIONS:SIGNAL-SUBSCRIBER-ERROR` report now calls its prefixed reader instead of inadvertently calling `CL:SIGNAL`.
- `elmtui.asd` now gives `core/conditions` an explicit dependency on `core/errors` to avoid out-of-order package reads on fresh compilation.
- Pre-existing warnings from LOG4CL method redefinitions and a constant type mismatch in `tests/api-tests.lisp` occur during test loading; no warning originated from the changed condition class/report or focused tests.
- A clean SBCL invocation of `ASDF:COMPILE-SYSTEM :ELMTUI` and a fresh `ASDF:COMPILE-SYSTEM :ELMTUI :FORCE T` both succeed after explicit ordering was added: `CORE/ASYNC` depends on `CORE/GLOBALS` and `CORE/CONDITIONS`, and the `STATE` module depends on `STATE/PATH-CONTEXT` and `CORE/ASYNC`. No new compilation warnings were emitted; SBCL reports 13 non-warning compiler notes in the forced compilation. The cold compile is now enforced independently by the hosted CI workflow and the release-check script.
- Source files belonging to workbench, examples, tmux, or claimed workers have not been edited.

## Follow-up gates

1. Complete per-binding API documentation / reviewed intentional-undocumented exceptions in the existing docstring-remediation task; strict zero-debt mode remains unqualified.
2. Independently review facade-level re-export ownership before altering `CL-EVENTS.API`, `CL-STYLES.API`, `ELMTUI.STATE`, or `ELMTUI.STATE.API`.
3. Migrate `WORKBENCH:EVALUATION-ABORTED` into the framework root only after the workbench owners release that path, with condition handler/restart compatibility tests.
4. Wire the existing condition export boundary and diagnostic context tests into hosted CI when hosted CI exists; they already run through the local full test suite.
5. Preserve the now-working cold ASDF compile-only prerequisite test in hosted CI and the release checklist; any further cross-module imports must declare explicit prerequisites instead of relying on a prior `LOAD-SYSTEM`.
