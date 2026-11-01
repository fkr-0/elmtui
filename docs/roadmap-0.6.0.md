# ElmTUI 0.6.0 Roadmap

Target: reduce ceremony, unify the two-constructor model, and make the
subscription/style/component layers pull their weight.

Items 1-4 from the API review shipped in 0.5.0 (convenience constructors,
facade exports, default quit handling, viewport defaults, example migration).
Everything below builds on that foundation.

---

## 1. Unify the state contract across constructors

**Problem.** `defapplication` and `deftea-app` expose different state models:
CL-STATE patches vs direct model replacement.  The boundary between them
("when does my app outgrow `deftea-app`?") is undocumented and blurry.

**Direction.**

- Let `deftea-app` apps host `defcomponent` children.  The component tree
  already receives `app-state` — wire a read-only projection of the
  `deftea-app` model into that slot so components can observe application
  state without requiring CL-STATE.
- Document the explicit boundary: `deftea-app` for single-view and
  light-component apps, `defapplication` for deep component trees that
  need independent local-state and cross-component messaging.
- Consider a third path — `defapplication` with `patch`-style flat updates
  as the default, making the full `make-update-result` an opt-in power mode
  rather than the baseline.

**Success criteria.** At least two examples with `deftea-app` + child
components.  A "choosing your constructor" section in the user guide.

---

## 2. Subscription types beyond :timer

**Problem.** The subscription model (declarative `subscriptions(model) →
descriptors`, automatic reconciliation) is well designed but only `:timer`
exists as a built-in type.  Every other event source (resize, file change,
external process) must be hand-wired through `cmd-async`.

**Direction.**  Add built-in subscription descriptors for:

| Descriptor          | Fires on                        |
|---------------------|---------------------------------|
| `:every`            | Interval tick (clearer `:timer`) |
| `:window-resize`    | Terminal size change (SIGWINCH)  |
| `:file-watch`       | Inotify / kqueue on a path      |
| `:process`          | Subprocess stdout line / exit    |

Each descriptor follows the existing pattern:
`(:type (:interval N :path P :message MSG ...))`.

**Success criteria.** `:window-resize` and `:every` implemented and used in
at least one example.  The `file-watch` and `process` descriptors are
stretch goals gated on real-world demand.

---

## 3. Style classes in the view DSL

**Problem.** Inline `:style (...)` plists repeat across every view function.
`cl-styles` exists underneath but isn't exposed to the view DSL layer.

**Direction.**

- Add a `defstyle` form that registers named style plists:
  ```lisp
  (defstyle :flex-column (:display :flex :flex-direction :column))
  (defstyle :padded-box  (:padding-x 2 :padding-y 1 :border :single))
  ```
- Accept `:class :flex-column` (or `:class (:flex-column :padded-box)` for
  composition) on any DSL node.  Named styles merge with inline `:style`
  at render time (inline wins on conflict).
- Theme presets (`dark-theme`, `light-theme`) should be expressible as a
  set of named styles that override defaults.

This is not a CSS engine.  It is named plists with merge semantics.

**Success criteria.** `defstyle` + `:class` works in DSL nodes.  At least
one example migrated from inline styles to style classes.

---

## 4. `cmd-async` progress callback opt-in

**Problem.** `cmd-async` requires `(lambda (progress ...) ...)` — every
real usage ignores the progress callback with
`(declare (ignore progress))`.

**Direction.**

- Default signature becomes `(lambda (&rest args) ...)` (no progress).
- Opt in with `:progress t`:
  ```lisp
  (cmd-async (lambda (progress) (funcall progress '(:phase :loading)) ...)
             :progress t)
  ```
- Backward-compatible: detect arity of FUNCTION at expansion time, or
  accept both forms and dispatch.  Prefer detection if portable.

**Success criteria.** Existing async examples drop the `(declare (ignore
progress))`.  Progress-using code (if any) still works.

---

## 5. Facade surface cleanup

**Problem.** 5 of the original 13 facade exports are low-level key-event
struct accessors (`key-event`, `key-event-p`, `key-event-key`,
`key-event-char`, `key-event-modifiers`).  With `key-event-parts` now in
the facade, these are escape-hatch internals.

**Direction.**

- Move the five struct accessors to `elmtui.keys` (secondary package).
- Keep re-exporting them from the facade for backward compatibility in
  0.6.0 with a deprecation note.
- Remove from the facade in 0.7.0.
- The facade should converge toward: constructors, update helpers,
  predicates, commands, styles — the things every app uses.

**Success criteria.** `elmtui.keys` package exists.  Deprecation warnings
documented in changelog.

---

## 6. `defcomponent` view clause documentation and init ergonomics

**Problem.** The `:view` clause docstring says 3 parameters
(`local-state app-state self-id-path`) but the generated method actually
receives 4 (`children` is the fourth, passed as a keyword arg).  The
`:init` clause receives props as a raw plist with no destructuring.

**Direction.**

- Fix the docstring to document all four parameters.
- Add optional destructuring syntax to `:init`:
  ```lisp
  (:init ((label count &key style) self-id-path)
    ...)
  ```
  where `(label count &key style)` destructures the props plist.
- Consider a `:view` shorthand that auto-binds `children` only when
  the component declares `:children t` in its metadata.

**Success criteria.** Docstring accurate.  At least one component uses
destructured init.

---

## 7. `split-props/children` extensibility

**Problem.** The DSL parser uses a hardcoded list of known component
keywords to disambiguate child nodes from property values.  User-defined
components added via `defcomponent` are not in this list, causing parse
ambiguity.

**Direction.**

- Register `defcomponent` DSL types in a runtime table that
  `split-props/children` consults.
- Fall back to the existing heuristic for unregistered types.
- Alternatively, require `:children (...)` explicitly and remove the
  heuristic entirely (breaking, but the DSL already requires it in most
  places).

**Success criteria.** A user-defined component used as a DSL child node
parses correctly without heuristic failure.

---

## Non-goals for 0.6.0

- Full CSS-like cascade / specificity (style classes use flat merge, not
  cascade).
- Reactive / signal-based state (CL-STATE patches remain the production
  state model).
- Multi-window / multi-terminal support.
- Mouse event subscriptions (terminal mouse support is inconsistent;
  defer to 0.7.0 if demand materializes).
