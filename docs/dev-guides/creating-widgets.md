# Creating widgets in ElmTUI

Widgets (also called components) are reusable UI building blocks with
their own local state, message handlers, and view function. ElmTUI
defines them with the `defcomponent` macro.

## `defcomponent` syntax

```lisp
(defcomponent widget-name (superclasses...)
  (:state (slot-name initial-value &key type doc)
          ...)

  (:init (props self-id-path)
    body...)

  (:update (message local-state app-state self-id-path)
    (:message-keyword (args...)
      (values patches commands))
    ...)

  (:view (local-state app-state self-id-path children)
    dsl-tree))
```

### Clauses

- **`:state`** — declares local state slots with initial values and
  optional type/documentation annotations.
- **`:init`** — called with props and the component's ID path. Returns
  `(values initial-local-state commands)`.
- **`:update`** — dispatches on message keywords. Each handler receives
  destructured arguments and returns `(values patches commands)`.
  Patches update local state; commands are async effects.
- **`:view`** — receives local state, application state, the ID path,
  and children. Returns a DSL tree.

## Example: a label widget

```lisp
(defcomponent my-label ()
  (:state (text "" :type string)
          (style nil))

  (:init (props self-id-path)
    (list :text (getf props :text "")))

  (:update (message local-state app-state self-id-path)
    (:set-text (new-text)
      (values `(((:text) ,new-text)) nil)))

  (:view (local-state app-state self-id-path children)
    `(:text :id :label
      :content ,(getf local-state :text)
      :style ,(getf local-state :style))))
```

Use it in a parent view by referencing its DSL type:

```lisp
'(:my-label :id :greeting :text "Hello, world!")
```

## DSL type registration

Every `defcomponent` expansion automatically registers the component's
DSL type keyword in a global registry at load time. The keyword is
derived from the class name (e.g., `my-label` becomes `:my-label`).

This registration serves two purposes:

1. **DSL resolution** -- The `resolve-dsl-type` generic function
   dispatches on the keyword via the auto-generated `dsl-type` method
   to map it to the component class.
2. **Parser disambiguation** -- The `split-props/children` function
   consults the registry to decide whether a keyword in an ambiguous
   position is a child node type or a property key. Without
   registration, user-defined component keywords would be consumed as
   property keys when they appear as positional children in a DSL form.

You do not need to call `register-dsl-type` manually; `defcomponent`
handles it. If you define types outside of `defcomponent` (for example
using `defcomponent-dsl`), they are also registered automatically.

User-defined components work as child nodes in DSL trees with no extra
registration step:

```lisp
;; my-label is recognized as a child node, not a property key
`(:container :id :root
   :children
   ((:my-label :id :greeting :text "Hello!")
    (:text :content "plain text")))
```

## Update handler contract

Each handler branch under `:update` is keyed by a message keyword:

```lisp
(:update (message local-state app-state self-id-path)
  (:increment (amount)
    (values `(((:count) ,(+ (getf local-state :count 0) amount)))
            nil))
  (:reset ()
    (values '(((:count) 0)) nil)))
```

Handlers return `(values patches commands)`:

- **patches** — `((path new-value) ...)` applied to local state.
- **commands** — async effect descriptors, or `nil`.

The component never mutates `local-state` directly. Unhandled messages
follow the `:on-unhandled-message` policy (default: `:no-op`).

## View contract

The view function returns a DSL tree describing the widget's appearance:

```lisp
(:view (local-state app-state self-id-path children)
  `(:container :id ,(elmtui.ui.api:id-from-path self-id-path)
    :children
    ((:text :id :value :content ,(format nil "~D" (getf local-state :count 0)))
     ,@children)))
```

Available DSL node types include `:container`, `:text`, `:button`,
`:label`, and registered component types. Style is specified with a
`:style` plist using CSS-like properties.

## Built-in widgets

ElmTUI ships several `defcomponent`-based widgets:

| Widget | Package | Purpose |
|---|---|---|
| `label` | `elmtui.ui.widgets.label` | Read-only text display |
| `button` | `elmtui.ui.widgets.button` | Clickable action trigger |
| `scroll-panel` | `elmtui.ui.widgets.scroll-panel` | Scrollable content region |
| `button-enhanced` | `elmtui.ui.widgets.button-enhanced` | Button with variant/size/tooltip |
| `label-enhanced` | `elmtui.ui.widgets.label-enhanced` | Label with accessibility props |

Some widgets follow an explicit TEA model pattern instead (e.g.
`listbox` with `init-listbox` / `update-listbox` / `view-listbox`).
Both styles coexist; prefer `defcomponent` for new work.

## Widget authoring checklist

A well-documented widget should cover:

1. **Identity** — stable ID across renders, component path formation.
2. **State** — which state is owned vs. supplied by the parent.
3. **Init** — props, defaults, initial commands, error conditions.
4. **Messages** — every supported message shape with examples.
5. **Update** — whether the model is mutated, what is returned, which
   commands can be emitted, which conditions can be signalled.
6. **View** — rendered node types, focusability, accessibility props,
   empty/disabled/loading/error states.
7. **Focus and keymap** — focus entry/exit, activation keys, whether
   application keymaps may override them.
8. **Conditions/restarts** — do not hide failures behind
   `ignore-errors`; expose recoverable conditions with `use-value` or
   `skip` restarts where safe.

## Testing widgets

### Pure update test

```lisp
(multiple-value-bind (patches commands)
    (funcall update-fn :increment local-state app-state id-path)
  (assert (equal '(((:count) 1)) patches))
  (assert (null commands)))
```

### View test

Call the view with synthetic state and inspect the returned DSL — no
terminal needed.

### Component integration test

Initialize, send messages, and assert the resulting local state and
emitted commands through the component lifecycle.

## Next steps

- [Widgets and patterns](../longform/02-core-principles-widgets-and-patterns.md)
  for the complete widget inventory and authoring contract.
- [Creating applications](./creating-applications.md) for how widgets
  compose into a full application.
