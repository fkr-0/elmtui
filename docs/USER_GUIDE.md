# ElmTUI – End‑User Guide

This guide describes how to build TUI apps with ElmTUI’s current API, integrate keyboard handling with the keymaps system, manage focus, run apps, and package fast‑boot executables.

## Install and Load

- Install deps: `clpm bundle install`
- Load core: `clpm bundle exec --with-client sbcl -- --eval '(asdf:load-system :elmtui)'`
- Load maintained examples (optional): `clpm bundle exec --with-client sbcl -- --eval '(asdf:load-system :elmtui-examples)'`

## App Structure

ElmTUI provides two application constructors. Both lower to the same
runtime specification.

### `defapplication` (production constructor)

The normative full application constructor. Uses patch-based updates with
`make-update-result` and reads state with `state-ref`.

- Required: `:root-viewport-id`, `:root-component-dsl`.
- Optional: `:initial-state-plist` or `:initial-state-fn`, `:update-fn`,
  `:view-fn`, `:subscriptions-fn`, `:command-processor-fn`,
  `:state-semantics` (`:transactional` or `:strict-elm`).

```lisp
(defun my-update (message state)
  (cond
    ((elmtui:quit-requested-p message)
     (elmtui:make-update-result :patches '(((:should-quit) t))))
    (t (elmtui:make-update-result))))

(defun my-view (state)
  '(:container :id :root :children ((:text :content "Hello"))))

(elmtui:defapplication hello-app
  :root-viewport-id :root
  :root-component-dsl '(:root-viewport :id :root :anchor :below-cursor
                        :height 3 :child-dsl-spec (:view nil))
  :initial-state-plist '(:should-quit nil)
  :update-fn #'my-update
  :view-fn #'my-view)
```

Run it: `(hello-app:run-hello-app)`.

### `deftea-app` (minimal direct-transition adapter)

For small programs whose transition function returns a whole new model
instead of patches:

```lisp
(elmtui:deftea-app hello-tea
  :init       #'init
  :transition #'transition
  :view       #'view)
```

The normative runtime vocabulary is `INIT`, `TRANSITION`, `VIEW`, and
`SUBSCRIPTIONS`. `deftea-app` expands into `defapplication` with
`:strict-elm` state semantics.

### Choosing your constructor

Both constructors lower to the same runtime, so the choice is about
ergonomics and how much of CL-STATE you want to manage directly.

**Use `deftea-app` when:**

- Your state is a single opaque model (a plist, struct, or other value).
- Your transition function returns a whole new model instead of patches.
- You want the simplest possible TEA loop.
- You host a few `defcomponent` children that read the app model with
  `app-model` (see below).

**Use `defapplication` when:**

- You need deep component trees with independent local state managed by
  CL-STATE (nested paths, transactions, scoped contexts).
- Your update function works with patches (`make-update-result :patches ...`)
  and reads state with `state-ref`.
- You want CLI/binary configuration, custom keymaps, or selectable
  `:transactional` / `:strict-elm` commit semantics.
- Components need fine-grained access to the application state tree.

### Hosting components in `deftea-app`

A `deftea-app` stores the user model under the `:tea-model` key of the
CL-STATE application state. Components receive the full application state
object in their `:update` and `:view` clauses. To read the user model
from a component, call `elmtui:app-model`:

```lisp
(elmtui:app-model app-state)  ;=> the user's model plist (or NIL)
```

To place components in a `deftea-app`, pass the `:root-component-dsl`
keyword with a DSL tree that includes component nodes. When provided,
this overrides the auto-generated root viewport:

```lisp
;; 1. Define a component that reads the app model
(defcomponent count-display (component)
  (:state
    (label "Count" :type string))
  (:view (local-state app-state id-path children)
    (let* ((model (elmtui:app-model app-state))
           (count (if model (getf model :count 0) 0)))
      `(:text :id ,(id-from-path id-path)
         :content ,(format nil "~A: ~A" (getf local-state :label) count)))))

;; 2. Define the app with the component in its DSL tree
(deftea-app my-counter
  :init       #'counter-init
  :transition #'counter-transition
  :view       #'counter-view
  :root-component-dsl '(:root-viewport :id :root-viewport
                         :anchor :below-cursor :height 5
                         :children
                         ((:count-display :id :display
                           :initial-label "Score"))))
```

The transition function manages the model as usual (pure model
replacement); the component's `:view` reads the model via `app-model`
and renders it. This keeps logic in the transition and presentation in
the component.

When `:root-component-dsl` is omitted, `deftea-app` auto-generates a
simple viewport that renders the output of your `:view` function
directly, which is the default behavior for apps without components.

`app-model` returns NIL when the application state does not contain a
`:tea-model` key (for example, when the component is used inside a plain
`defapplication`). Components that check for NIL before using the model
work in both constructors.

## State and Updates

- Use `elmtui:make-update-result` to return patches and commands from
  `defapplication` update functions.
- Each patch is `(PATH NEW-VALUE)` where PATH is a list of keys.
- Commands are async effect descriptors.

```lisp
(make-update-result :patches '(((:should-quit) t)) :commands nil)
```

## Async Commands

`cmd-async` constructs an asynchronous command that the runtime executes
on a worker thread. The update function never performs I/O directly;
instead it returns one or more `cmd-async` commands inside
`make-update-result`, and completion/error results re-enter the message
loop.

### Basic usage (no progress)

By default, `cmd-async` calls FUNCTION with the supplied `:args`. No
progress callback is injected.

```lisp
(elmtui.core.async:cmd-async
 (lambda (query)
   (fetch-data query))
 :args (list user-query)
 :on-complete
 (lambda (result)
   `(:data-arrived :data ,result))
 :on-error
 (lambda (condition)
   `(:data-failed :err ,condition))
 :timeout 10)
```

You can also pass a named function directly:

```lisp
(cmd-async #'fetch-data
  :args '("query")
  :on-complete (lambda (result) `(:data-arrived :data ,result))
  :on-error    (lambda (condition) `(:data-failed :err ,condition)))
```

### Progress callback (opt-in)

Pass `:progress t` when your function needs to report intermediate
progress. The progress callback is injected as the first argument
before `:args`.

```lisp
(cmd-async
 (lambda (progress query)
   (funcall progress '(:phase :connecting))
   (let ((result (fetch-data query)))
     (funcall progress '(:phase :parsing))
     result))
 :args (list user-query)
 :progress t
 :on-complete
 (lambda (result)
   `(:data-arrived :data ,result))
 :on-error
 (lambda (condition)
   `(:data-failed :err ,condition)))
```

Each `(funcall progress data)` sends an `(:async-progress-update :task-id
ID :progress DATA)` message to the application, which your update function
can handle to show loading indicators or phase changes.

### Timeout and cancellation

```lisp
(cmd-async #'long-running-task
  :timeout 30
  :cancellation-fn (lambda () (cleanup-resources))
  :on-complete (lambda (result) `(:task-done :result ,result))
  :on-error    (lambda (condition) `(:task-failed :err ,condition)))
```

When TIMEOUT seconds elapse, the promise is cancelled and
CANCELLATION-FN is invoked for best-effort cleanup.

### Returning commands from update

```lisp
(defun my-update (message state)
  (cond
    ((eq (first message) :start-fetch)
     (make-update-result
      :patches '(((:status) :loading))
      :commands (list (cmd-async #'fetch-data
                        :on-complete (lambda (r) `(:fetched :data ,r))))))
    ((eq (first message) :fetched)
     (make-update-result
      :patches `(((:status) :ready)
                 ((:data) ,(getf (rest message) :data)))))
    (t (make-update-result))))
```

### Migration from mandatory progress

Before this change, `cmd-async` always injected a progress callback as
the first argument, requiring every user to write:

```lisp
;; OLD (no longer needed):
(cmd-async (lambda (progress) (declare (ignore progress)) (do-work)) ...)
```

Now simply write:

```lisp
;; NEW (default, no progress):
(cmd-async (lambda () (do-work)) ...)
```

For functions that actively use the progress callback, add `:progress t`
and keep the callback parameter:

```lisp
;; NEW (with progress opt-in):
(cmd-async (lambda (progress) (funcall progress '(:phase :loading)) (do-work))
           :progress t ...)
```

## Rendering

- `:view-fn` returns a lightweight DSL tree (e.g., `:container`, `:text`, `:button`, etc.).
- ElmTUI’s pipeline resolves, styles, lays out, and renders this tree.

## Style Classes

Style classes let you name a reusable bag of style properties and
reference it from any DSL node with `:class`.  This eliminates the
repetitive inline `:style` plists that otherwise accumulate across a
view tree.

### Defining a style class

Use the `defstyle` macro (exported from the `elmtui` package).  The
first argument is a keyword name; the second is a style property list.

```lisp
(elmtui:defstyle :card
  (:display :flex :flex-direction :column
   :border :rounded :padding-x 2 :padding-y 1))

(elmtui:defstyle :muted-text
  (:dim t :fg :white))
```

Styles are registered at load time in a global registry and are
available to every view function in the image.

### Applying a style class

Add a `:class` property to any DSL node.  The value is either a single
keyword or a list of keywords.

```lisp
;; Single class
(:container :id :profile :class :card
  :children ((:text :id :name :content "Alice")))

;; Multiple classes
(:text :id :note :class (:muted-text :bold) :content "Draft")
```

When multiple classes are listed, they are merged left to right: if two
classes define the same property, the later class wins.

### Inline overrides

An explicit `:style` on the same node always wins over class-resolved
properties.  This lets you use a class for the common case and override
individual properties per-node.

```lisp
;; :card sets :padding-x 2, but this node needs more
(:container :id :wide-card :class :card :style (:padding-x 4)
  :children ((:text :id :body :content "Wider padding here")))
```

### Merge semantics

Resolution proceeds in three steps:

1. Each keyword in `:class` is looked up in the style registry.
2. The resulting plists are merged left to right (later overrides earlier).
3. Any inline `:style` plist is merged on top (inline wins on conflict).

The merged result replaces the node’s `:style` before the rest of the
pipeline sees it.  Existing behaviour of nodes that use only `:style`
(and no `:class`) is completely unchanged.

### Built-in presets

ElmTUI ships eight commonly useful presets so you can start using
`:class` immediately:

| Name                | Properties                                           |
|---------------------|------------------------------------------------------|
| `:flex-row`         | `:display :flex :flex-direction :row`                |
| `:flex-column`      | `:display :flex :flex-direction :column`             |
| `:bold`             | `:bold t`                                            |
| `:dim`              | `:dim t`                                             |
| `:centered`         | `:justify-content :center :align-items :center`      |
| `:padded`           | `:padding-x 1 :padding-y 1`                         |
| `:bordered`         | `:border :single`                                    |
| `:bordered-rounded` | `:border :rounded`                                   |

Example using presets:

```lisp
(:container :id :root :class (:flex-column :padded)
  :style (:width 80 :height 24)
  :children
  ((:text :id :title :class :bold :content "Dashboard")
   (:container :id :body :class (:flex-row :bordered-rounded)
     :children
     ((:text :id :left :content "Sidebar")
      (:text :id :right :content "Main")))))
```

### Theme integration

`apply-theme` registers a batch of named styles at once, making it easy
to define a colour vocabulary for your application or switch palettes at
runtime.

```lisp
(elmtui:apply-theme
  ‘(:title  (:bold t :fg-color (97 233 250) :bg-color (18 34 57))
    :accent (:bold t :fg-color (248 199 115) :bg-color (10 17 31))
    :muted  (:dim t  :fg-color (125 143 169) :bg-color (10 17 31))))

;; Then in your view:
(:text :id :heading :class :title :content "Hello")
```

`apply-theme` overwrites any previously registered style with the same
name, so calling it again with a different palette is sufficient to
switch themes.

### Programmatic access

`resolve-style-class` (exported from `elmtui`) returns the property list
for a registered name, or signals an error if the name is unknown.  Use
it when you need to inspect or compose styles in code rather than in DSL
nodes.

```lisp
(elmtui:resolve-style-class :flex-column)
;; => (:DISPLAY :FLEX :FLEX-DIRECTION :COLUMN)
```

## Keyboard Input and Keymaps

### Key Event Handling

For most key handling in update or transition functions, use one of the
two facade helpers:

- **`key-event-parts`** -- returns `(values KEY CHAR MODIFIERS)` for any
  key event (struct or legacy plist). This is the recommended way to
  inspect a key event.
- **`key-pressed-p`** -- a predicate that matches by `:char`, `:key`,
  and/or `:modifiers`. Use it when you only need to recognise specific
  keys.

```lisp
;; Recommended: destructure with key-event-parts
(defun my-transition (message model)
  (multiple-value-bind (key char mods) (elmtui:key-event-parts message)
    (cond
      ((eq key :escape) (list :should-quit t))
      ((and char (char= char #\q)) (list :should-quit t))
      (t model))))

;; Or use key-pressed-p for single-key checks
(defun my-transition (message model)
  (cond
    ((elmtui:key-pressed-p message :key :escape) (list :should-quit t))
    ((elmtui:quit-requested-p message)           (list :should-quit t))
    (t model)))
```

**Low-level struct accessors** (`key-event-key`, `key-event-char`,
`key-event-modifiers`, `key-event-p`, and the `key-event` type itself)
are available from the `elmtui.keys` package. They are useful when you
need to work directly with the `key-event` struct -- for example,
constructing events in tests or writing custom key normalisation.

```lisp
;; Import low-level accessors from elmtui.keys
(:import-from :elmtui.keys
              #:key-event #:key-event-p #:key-event-key
              #:key-event-char #:key-event-modifiers
              #:make-key-event)
```

These five symbols remain exported from the `elmtui` facade for backward
compatibility, but they will move exclusively to `elmtui.keys` in 0.7.0.
New code that needs direct struct access should import from `elmtui.keys`.

### Keymaps

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
(defun my-view (model)
  (declare (ignore model))
  '(:container :id :root :children
    ((:text :id :editor :focusable t :keymap-id :editor-context
       :style (:border t) :content "Edit here…"))))

;; 3) Handle dispatched messages in your transition
(defun my-update (message model)
  (case (car message)
    (:save (format t "Saved!~%") (elmtui:make-update-result))
    (:quit (elmtui:make-update-result :patches '(((:should-quit) t))))
    (:delete-last (elmtui:make-update-result))
    (t (elmtui:make-update-result))))

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

## Subscriptions

Subscriptions are declarative side-effect descriptors that the runtime
manages automatically. Your application's `:subscriptions-fn` receives
the current state and returns a list of subscription descriptors. The
runtime diffs old and new descriptor lists each update cycle: new
descriptors are started, removed ones are stopped, and unchanged ones
continue undisturbed.

```lisp
;; subscriptions-fn signature:
(defun my-subscriptions (state)
  "Return a list of subscription descriptors based on STATE."
  (when (state-ref state :watching)
    (list '(:every (:seconds 1.0 :message (:tick))))))
```

### `:timer` — legacy periodic timer

The original subscription type. Fires a message at a fixed interval.

**Descriptor format:**
```lisp
(:timer (:interval SECONDS :message MESSAGE))
;; or flat plist form:
(:timer :interval SECONDS :message MESSAGE)
```

**Message delivered:** the literal MESSAGE value.

**Example:**
```lisp
(:timer (:interval 0.1 :message (:tick)))
;; Delivers (:tick) every 100ms
```

### `:every` — periodic timer (preferred)

A clearer interface to periodic timers. Accepts `:seconds` or `:ms`
(milliseconds) for the interval. Recommended over `:timer` for new code.

**Descriptor format:**
```lisp
(:every (:seconds SECONDS :message MESSAGE))
(:every (:ms MILLISECONDS :message MESSAGE))
```

**Message delivered:** the literal MESSAGE value.

**Example:**
```lisp
;; Fire every half second
(:every (:seconds 0.5 :message (:tick)))

;; Fire every 200 milliseconds
(:every (:ms 200 :message (:fast-tick)))
```

### `:window-resize` — terminal resize events

Delivers a message when the terminal is resized (SIGWINCH). The message
is enriched with the new terminal dimensions. At most one
`:window-resize` subscription is active at a time; duplicates are
deduplicated by the reconciler.

**Descriptor format:**
```lisp
(:window-resize (:message MESSAGE))
```

**Message delivered:** MESSAGE with `:width` and `:height` appended.

**Example:**
```lisp
(:window-resize (:message (:resized)))
;; Delivers: (:resized :width 120 :height 40)
```

In your update function:
```lisp
(defun my-update (msg state)
  (when (and (consp msg) (eq (first msg) :resized))
    (let ((w (getf (rest msg) :width))
          (h (getf (rest msg) :height)))
      ;; handle resize
      ...)))
```

### `:file-watch` — file change notifications

Watches a file path for changes using periodic polling (default 500ms).
Detects creation, modification, and deletion events. Two descriptors
with the same `:path` are treated as the same subscription for
reconciliation purposes.

**Descriptor format:**
```lisp
(:file-watch (:path PATHNAME
              :message MESSAGE
              :interval SECONDS))  ;; optional, default 0.5
```

**Message delivered:** MESSAGE with `:path`, `:event` appended. The
`:event` value is one of `:created`, `:modified`, or `:deleted`.

**Example:**
```lisp
(:file-watch (:path "/tmp/config.json" :message (:config-changed)))
;; On modification delivers:
;; (:config-changed :path "/tmp/config.json" :event :modified)
```

**Note:** File modification detection relies on `file-write-date`, which
has one-second granularity on most systems. Sub-second modifications may
be coalesced into a single event.

### `:process` — external process output

Runs an external command and delivers messages for each line of stdout
and on process exit. Two descriptors with the same `:command` list are
treated as the same subscription.

**Descriptor format:**
```lisp
(:process (:command (PROGRAM ARG...)
           :on-output MESSAGE    ;; optional: fired per stdout line
           :on-exit MESSAGE))    ;; optional: fired when process exits
```

At least one of `:on-output` or `:on-exit` must be provided.

**Output message delivered:** MESSAGE with `:line` and `:pid` appended.

**Exit message delivered:** MESSAGE with `:code` and `:pid` appended.
On launch failure, `:error` is also included.

**Example:**
```lisp
(:process (:command ("tail" "-f" "/var/log/syslog")
           :on-output (:log-line)
           :on-exit (:tail-exited)))

;; Output delivers: (:log-line :line "Nov  1 12:00:00 ..." :pid 12345)
;; Exit delivers:   (:tail-exited :code 0 :pid 12345)
```

When the subscription is removed by the reconciler, the process receives
SIGTERM (and SIGKILL if it does not exit promptly).

**Error handling:** If the command cannot be found or launched, an
immediate `:on-exit` message is delivered with `:code -1` and an
`:error` description. If the process exits with a non-zero code, the
exit code is reported in `:code`.

### Subscription identity and reconciliation

The reconciler compares subscriptions by their _identity key_, not the
full descriptor. This means you can change message payloads without
restarting the underlying subscription:

| Type             | Identity key                    |
|------------------|---------------------------------|
| `:timer`         | Full descriptor (type + config) |
| `:every`         | Full descriptor (type + config) |
| `:window-resize` | Singleton (`:window-resize`)    |
| `:file-watch`    | Type + `:path`                  |
| `:process`       | Type + `:command`               |

### Combining subscriptions

Return multiple descriptors as a list from your subscriptions function:

```lisp
(defun my-subscriptions (state)
  (let ((subs nil))
    (when (state-ref state :auto-refresh)
      (push '(:every (:seconds 5.0 :message (:refresh))) subs))
    (when (state-ref state :watch-config)
      (push '(:file-watch (:path "/etc/myapp.conf"
                           :message (:config-changed)))
            subs))
    subs))
```

## Running Applications

- Prefer the `defapplication`-generated runner: `(my-app:run-my-app :platform :terminal)`.
- Or, driver API: `(elmtui.platform.driver:run-app-platform app-spec :backend-type :terminal)`.

## Packaging (Fast‑boot Executables)

- Build packager: `asdf:make :elmtui-packager` (or via CLPM).
- Dump a binary:
  - `./elmtui-packager -s elmtui -E my-app:run-my-app -o ./my-app`
  - With extra files: `-f examples/fzy-picker.lisp`

## Testing

- Root integration suite:
  `clpm bundle exec --with-client sbcl -- --noinform --load scripts/run-tests-clpm.lisp`
- Subsystem suites: `scripts/test-subsystems.sh`
- Full release gate: `scripts/release-check.sh`

## Examples

The maintained examples are in the separate `elmtui-examples` ASDF system:

```lisp
(asdf:load-system "elmtui-examples")
(elmtui.examples.minimal:run-minimal)
```

Use `./scripts/examples.sh list` to discover runnable examples and
`./scripts/examples.sh run NAME` to start one. `./scripts/examples.sh list` opens the same
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
