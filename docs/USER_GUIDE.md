# ElmTUI – End‑User Guide

This guide describes how to build TUI apps with ElmTUI’s current API, integrate keyboard handling with the keymaps system, manage focus, run apps, and package fast‑boot executables.

## Install and Load

- Install deps: `clpm bundle install`
- Load core: `clpm bundle exec --with-client sbcl -- --eval '(asdf:load-system :elmtui)'`
- Load maintained examples (optional): `clpm bundle exec --with-client sbcl -- --eval '(asdf:load-system :elmtui-examples)'`

## App Structure (defapplication)

- Define an app with `elmtui.app:defapplication`.
- Required keywords:
  - `:root-viewport-id`: unique ID for the root viewport.
  - `:root-component-dsl`: quoted DSL for the root component subtree.
  - `:update-fn`: function `(message app-state) -> update-result`.
  - `:view-fn`: function `(app-state) -> DSL`; the generated wrapper adds the root viewport.
- Optional: `:initial-state-plist` or `:initial-state-fn`, `:command-processor-fn`, `:subscriptions-fn`.

Example skeleton:

```lisp
(defun my-update (message app-state)
  (elmtui.state.api:make-update-result))

(defun my-view (app-state &key root-id)
  (declare (ignore app-state root-id))
  '(:container :id :root :children ((:text :content "Hello"))))

(elmtui.app:defapplication hello-app
  :root-viewport-id :root
  :root-component-dsl '(:container :id :root)
  :initial-state-plist '(:should-quit nil)
  :update-fn 'my-update
  :view-fn 'my-view)
```

Run it: `(hello-app:run-hello-app :platform :terminal)`; or through the driver: `elmtui.platform.driver:run-app-platform` with an app‑spec.

## State and Updates

- Use `elmtui.state.api:make-update-result` to return patches and commands.
- Patches are plists replacing or setting keys in the model; commands are async tasks/messages.

```lisp
(make-update-result :patches '((:should-quit t)) :commands nil)
```

## Rendering

- `:view-fn` returns a lightweight DSL tree (e.g., `:container`, `:text`, `:button`, etc.).
- ElmTUI’s pipeline resolves, styles, lays out, and renders this tree.

## Keyboard Input and Keymaps

The keymap system (`elmtui.keymaps`) normalizes key events and dispatches actions/messages via contexts.

Two recommended patterns:

1) Attach a named keymap context to a widget in your view and let focus activate/deactivate it:

```lisp
;; Define keymap and context at load time
(elmtui.keymaps:define-keymap *ok-km*
  ("Enter" :type :message :target '(:ok)))
(elmtui.keymaps:define-keymap-context :ok-context :parent nil :keymaps (list *ok-km*))

;; In view: propagate :keymap-id in the widget model
`(:button :id :btn-ok :label "OK" :keymap-id :ok-context)
```

Focus integration (elmtui.core.focus) automatically activates the widget’s context when it gains focus.

2) Provide per-component keymaps as an alist in app‑state (simple and explicit):

```lisp
(let* ((km (elmtui.keymaps:keymap! :counter-km)))
  (elmtui.keymaps:add-keybinding km "+"    :type :message :target '(:dispatch-to-component :counter :increment))
  (elmtui.keymaps:add-keybinding km "-"    :type :message :target '(:dispatch-to-component :counter :decrement))
  (elmtui.keymaps:add-keybinding km "Enter" :type :message :target '(:dispatch-to-component :counter :reset))
  ;; in initial state
  (list :component-keymaps (list (cons :counter km))))
```

Notes:
- Keybindings have `:type` `:message` or `:action` (function). Messages are dispatched via the app’s queue.
- The driver calls `elmtui.keymaps:initialise` and routes `key-event`s through `elmtui.keymaps:process-key-event`.
- For printable characters, read `key-event-char` in your update.

### Example: Context + Sequence

Define a local keymap with both single keys and a multi-key sequence, attach it to a widget via a named context, and handle the dispatched messages in your update.

```lisp
;; 1) Define keymap and context
(elmtui.keymaps:define-keymap *editor-local*
  ("C-s"       :type :message :target '(:save)        :description "Save")
  ("C-x C-c"   :type :message :target '(:quit)        :description "Quit app")
  ("Backspace" :type :message :target '(:delete-last) :description "Delete"))

(elmtui.keymaps:define-keymap-context :editor-context
  :parent :global-context      ;; inherit global bindings
  :keymaps (list *editor-local*))

;; 2) Reference the context from your widget (focus activates it)
(defun my-view (app-state &key root-id)
  (declare (ignore app-state root-id))
  '(:container :id :root :children
    ((:text :id :editor :focusable t :keymap-id :editor-context
       :style (:border t) :content "Edit here…"))))

;; 3) Handle dispatched messages in your update
(defun my-update (message app-state)
  (case (car message)
    (:save (format t "Saved!~%") (elmtui.state.api:make-update-result))
    (:quit (elmtui.state.api:make-update-result :patches '((:should-quit t))))
    (:delete-last (elmtui.state.api:make-update-result))
    (t (elmtui.state.api:make-update-result))))

;; 4) Ensure keymaps are initialised once (driver does this for you)
(elmtui.keymaps:initialise)
```

Tips:
- Sequences like "C-x C-c" are recognized while you keep typing; if no binding matches the current prefix, the sequence is reset automatically.
- Use `elmtui.keymaps:list-active-keybindings` to introspect active keys for help overlays.

## Focus Management

- `elmtui.core.focus:focus-manager` tracks `:current-focus` and supports tab and directional navigation.
- Focus change triggers keymap context activation via `:keymap-id` when present in widget models.
- Utility functions: `set-focus`, `get-next-focusable`, `get-previous-focusable`, `tab-navigate`.

## Running Applications

- Prefer the `defapplication`-generated runner: `(my-app:run-my-app :platform :terminal)`.
- Or, driver API: `(elmtui.platform.driver:run-app-platform app-spec :backend-type :terminal)`.

## Packaging (Fast‑boot Executables)

- Build packager: `asdf:make :elmtui-packager` (or via CLPM).
- Dump a binary:
  - `./elmtui-packager -s elmtui -E my-app:run-my-app -o ./my-app`
  - With extra files: `-f examples/fzy-picker.lisp`

## Testing

- Run all tests: `./rt.sh`
- Subsets: `./rt-input.sh`, `./rt-styles.sh`

## Examples

The maintained examples are in the separate `elmtui-examples` ASDF system:

```lisp
(asdf:load-system "elmtui-examples")
(elmtui.examples.minimal:run-minimal)
```

Use `./examples.sh list` to discover runnable examples and
`./examples.sh run NAME` to start one. `./exe examples` opens the same
maintained-example picker. The removed `elmtui/examples-legacy` system is not a
supported API or migration source.

The optional fuzzy-picker integration is separate from the default examples
system: install its external `cl-fzy` dependency, load
`elmtui-examples-fzy`, and run `elmtui.examples.fzy-picker:run-fzy-picker`.

## Enhanced Widgets (Optional)

- Load experimental enhanced widgets: `asdf:load-system :elmtui-widgets-enhanced/experimental`
- Namespaces: `elmtui.ui.widgets.viewport-enhanced`, `...label-enhanced`, `...button-enhanced`.
- Core widgets now include a few enhanced features as optional props:
  - `label`: `:aria-label`
  - `button`: `:variant`, `:size`, `:aria-label`, `:tooltip`, `:action` (alias for `:on-click-msg`)
  - `viewport`: `:clipping`, `:scroll-x`, `:scroll-y`, message `(:set-clipping t)`, `(:scroll-by dx dy)`
