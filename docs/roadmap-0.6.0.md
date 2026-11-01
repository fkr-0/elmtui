# ElmTUI 0.6.0 Roadmap

Target: reduce ceremony, unify the two-constructor model, and make the
subscription/style/component layers pull their weight.

Items 1-4 from the API review shipped in 0.5.0 (convenience constructors,
facade exports, default quit handling, viewport defaults, example migration).
Everything below builds on that foundation.

**Status: all items implemented and merged to main.**

---

## 1. Unify the state contract across constructors — DONE

Shipped in `feat/unify-state-contract`. `deftea-app` now accepts
`:root-component-dsl` to host `defcomponent` children. `app-model` accessor
extracts the user model from a `deftea-app` app state. Two new examples
(`tea-counter-component`, `tea-list-detail`) and a "Choosing your constructor"
section in the user guide.

---

## 2. Subscription types beyond :timer — DONE

Shipped in `feat/subscription-types`. Added `:every`, `:window-resize`
(SIGWINCH + ioctl), `:file-watch` (polling-based), and `:process` (subprocess
I/O) subscription types. Type-aware reconciler in `src/runtime/effects.lisp`.
`file-watcher` example, `pong-below-cursor` migrated to `:every`, 32 tests.

---

## 3. Style classes in the view DSL — DONE

Shipped in `feat/style-classes`. `defstyle` macro, `resolve-style-class`,
`apply-theme`, 8 built-in presets, `:class` keyword wired into DSL node
processing. `neon-kit` refactored to use named styles. 27 tests.

---

## 4. `cmd-async` progress callback opt-in — DONE

Shipped in `feat/cmd-async-progress-optin`. Default signature is now
`(lambda (&rest args) ...)`. Opt in to progress with `:progress t`. All
examples updated to drop `(declare (ignore progress))`. 15 tests. Full
documentation in USER_GUIDE.md.

---

## 5. Facade surface cleanup — DONE

Shipped in `feat/facade-cleanup`. `elmtui.keys` secondary package created
with 6 key-event struct accessors. 18 examples migrated to use
`elmtui.keys` imports. Deprecation documented in changelog. 18 tests.

---

## 6. `defcomponent` view clause documentation and init ergonomics — DONE

Shipped in `feat/defcomponent-ergonomics`. `:view` docstring fixed to
document all 4 parameters. `:init` supports optional props destructuring
via `parse-init-destructuring` + `generate-init-destructuring-bindings`.
New `tea-destructured-init` example. 8 tests.

---

## 7. `split-props/children` extensibility — DONE

Shipped in `feat/split-props-extensibility`. `defcomponent` now
auto-registers DSL type keywords in `*dsl-type-registry*`.
`split-props/children` replaced hardcoded list with
`known-dsl-type-p` + `element-class` fallback. Public API:
`register-dsl-type`, `known-dsl-type-p` in `elmtui.ui.dsl-resolution`.
225-line test suite covering registry, disambiguation, and end-to-end parsing.

---

## Non-goals for 0.6.0

- Full CSS-like cascade / specificity (style classes use flat merge, not
  cascade).
- Reactive / signal-based state (CL-STATE patches remain the production
  state model).
- Multi-window / multi-terminal support.
- Mouse event subscriptions (terminal mouse support is inconsistent;
  defer to 0.7.0 if demand materializes).
