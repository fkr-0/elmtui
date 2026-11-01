# ElmTUI API support levels

Canonical implementation task: ELMTUI-CLPM-API-CONTRACT-20261023-458838.

The architecture has **one mandatory ElmTUI toolkit**, reusable cl-events/cl-inputs/
cl-state/cl-styles support packages, and optional applications, examples and dev systems.
This document classifies interfaces; it does **not** silently unexport historical
symbols or change ASDF dependency direction.

| Level | Audience | Representative entry points | Compatibility policy |
|---|---|---|---|
| Application | Application authors | the root `elmtui` package (DEFAPPLICATION, DEFTEA-APP, MAKE-UPDATE-RESULT, STATE-REF, KEY-PRESSED-P, QUIT-REQUESTED-P, KEY-EVENT accessors, theme presets), also available from elmtui.app, elmtui.app.tea-core and elmtui.state.api; generated RUN-NAME runners | Preserve behavior and source compatibility across patch releases |
| Extension | Widget and toolkit integrators | elmtui.ui.* components, keymaps, focus, state and view-node operations | Document contracts; deprecate before breaking changes |
| Backend | Runtime/terminal backend writers | elmtui.platform.backend.*, virtual buffers, renderer, elmtui.core.loop | Advanced contracts; distinguish backend-specific behavior; test affected integrations |
| Compatibility/experimental | Partially implemented utilities | elmtui.view.memo, elmtui.view.core:VIEW-DIFF | Keep old qualified symbols for now; document precise semantics and limitations |

**Export soundness (0.4.0, see [the API review](../reviews/api-review-20261101.md)):**
every exported ElmTUI symbol names a binding or a registered message/model
schema. The release gate's `api_bindings` check
(`scripts/audit-api-bindings.lisp`) keeps it that way. The root `elmtui`
package is a curated facade of the Application level; until 0.4.0 it
exported 127 unbound symbols created by UIOP `:REEXPORT`.

## Concrete contracts tightened

- `elmtui.view.memo:MEMO` uses a cache per returned wrapper. Previously
  `CLEAR-MEMOIZATION-CACHE` only cleared the unrelated shared component cache.
  Now clearing by original function invalidates its wrappers, clearing by wrapper
  invalidates its cache, and clearing without arguments invalidates all caches.
  On SBCL the registry uses weak keys so discarded wrapper objects need not be
  retained solely for invalidation. Statistics are preserved independently.
- `MEMOIZE-COMPONENT` forwards PROPS as one argument (including list/plist
  props), plus the remaining arguments. Previously it flattened list PROPS
  through APPLY; returned wrappers support scoped cache invalidation.
- `MEMOIZE` now executes the component when memoization is disabled instead
  of returning NIL. The `:TEST` keyword remains accepted for compatibility,
  but the legacy shared cache is keyed with EQUAL.
- `elmtui.core.loop:START-LOOP` is single-mailbox and event-driven. The
  historical `:FPS` and `:WAIT` arguments remain accepted and ignored for
  compatibility. Both are deprecated: neither enables a frame ticker nor
  changes startup behavior. START-LOOP starts the consumer and returns T.
- `elmtui.view.core:VIEW-DIFF` is a whole-tree replacement *compatibility*
  adapter; it does not perform a minimal view diff. Physical terminal
  buffer diffing is a separate, optimized backend facility.

## Do not collapse legitimate application semantics

`DEFAPPLICATION` and `DEFTEA-APP` are not duplicate alternate runtimes:
they provide different creation ergonomics with the shared
`elmtui.app.api:MAKE-RUNTIME-APP-SPEC` substrate. Both remain available, as
do `:strict-elm` and `:transactional` state semantics. The broad root
`:elmtui` facade stays backward-compatible, while examples may prefer
qualified application and extension packages.

## Deferred changes requiring independent review

A future breaking release may curate root-package reexports and move further
developer-only sources into optional systems. Do not unexport symbols, remove
the normal-screen viewport/restoration layers, or collapse global runtime
lifecycle without tests for repeat starts, late async completion, and multiple
applications. No alternate-screen requirement is introduced here.

Acceptance: `asdf:test-system "elmtui-api-contract-tests"`, force-compile
`elmtui`, and the existing warning-clean/release gates; independent review
required before release.
