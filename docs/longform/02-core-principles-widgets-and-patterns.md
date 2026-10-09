# ElmTUI core principles, program parts, widgets, and application patterns

This chapter moves from the architectural foundation to everyday framework use. The central design question for every piece of an ElmTUI program is:

> Is this data, a decision about data, a description of UI, or an effect on the outside world?

Keeping those categories distinct produces applications that remain understandable when input, async work, focus, rendering, terminal resize, and failure recovery all happen at once.

## 1. Core principles

### 1.1 Messages are data

Prefer messages that can be printed, inspected, logged, stored, and synthesized in tests:

```lisp
:increment
'(:set-filter "common lisp")
'(:search-started :request-id 17 :query "terminal ui")
'(:search-succeeded :request-id 17 :results (...))
'(:search-failed :request-id 17 :condition condition)
```

Avoid hiding application decisions inside callbacks when a message can name the event instead.

A useful message vocabulary normally distinguishes:

- user intent: `:increment`, `:submit`, `:choose-item`;
- framework/input events: key, resize, focus;
- effect lifecycle: `:request-started`, `:request-succeeded`, `:request-failed`;
- component-local messages: `:button-click`, `:set-label`, `:focus`;
- lifecycle messages such as shutdown.

### 1.2 Update decides; effects execute elsewhere

In the strict TEA path:

```text
update(message, model) -> next-model + commands
```

A command is a description of work to execute after the decision. It should be possible to test update by asserting command data without actually doing network, file, or terminal I/O.

Bad boundary:

```lisp
(defun update (message model)
  (when (eq message :refresh)
    (http-request "https://example.invalid")) ; effect hidden inside update
  (values model nil))
```

Better boundary:

```lisp
(defun update (message model)
  (case message
    (:refresh
     (values (list* :loading t model)
             '((:fetch-status))))
    (otherwise
     (values model nil))))
```

The command interpreter/effect manager owns `:fetch-status` and returns completion as another message.

### 1.3 View describes; rendering mutates the terminal

View should describe what the terminal should look like. It should not print directly to the terminal.

The downstream pipeline owns:

- DSL/tree normalization;
- widget/component expansion;
- geometry and layout;
- style resolution;
- virtual-buffer construction;
- buffer diffing;
- backend output.

This is what makes a deterministic fake terminal useful: the terminal side effect has a replaceable boundary.

### 1.4 State ownership must be obvious

For every stateful object, be able to answer:

```text
Who owns it?
Who may change it?
How is change represented?
Can the old value remain valid?
How are observers notified?
Can the operation be rolled back?
```

For a pure TEA model, update owns state transitions by returning a next model.

For a `cl-state` application state, mutation occurs through path/transaction APIs.

For a widget model such as `listbox-model`, `update-listbox` copies the incoming structure and builds a replacement model.

### 1.5 Blocking belongs at explicit boundaries

Terminal/device waits are backend operations. Cooperative repeated probing belongs to the central `cl-events.loop:poll-until` primitive. Network/file work belongs in effects/async tasks.

A UI update path should not unexpectedly sleep, poll a file descriptor, or wait for a network response.

### 1.6 Conditions are typed information, not error strings

Application/library failures should carry enough data for both humans and programs:

```text
condition type
message
module/subsystem
operation
state/component path
message/event/task
expected value/type
actual offending value
underlying condition
recovery suggestions
```

Handlers should generally observe/annotate with `handler-bind`. Restarts should surround the operation that can be retried, skipped, replaced, or supplied a value.

### 1.7 Recovery should be interactive and programmable

A restart is useful only when it represents a legitimate continuation.

Examples:

```text
RETRY          repeat an idempotent/transactional operation
SKIP           omit an optional item/frame/message
IGNORE-TASK    abandon one async task and continue the app
USE-VALUE      substitute a fallback value
REPLACE-TASK   choose a different task
ABORT          propagate/end the operation
```

Do not advertise `RETRY` around an operation that has irreversible side effects unless the duplicate-effect semantics are explicitly acceptable.

## 2. Anatomy of an ElmTUI program

A complete application normally contains the following conceptual parts. The
snippets in this section deliberately use `deftea-app` to expose the smallest
direct model-transition shape. `defapplication` is the normative full
application constructor for production/new next-major applications; the minimal
adapter remains useful for teaching these same runtime concepts.

### 2.1 Package

Keep the application package explicit about its framework dependencies. Prefer importing the public API you intend to support rather than `:use`-ing implementation packages.

```lisp
(uiop:define-package :example.counter
  (:use :cl)
  (:import-from :elmtui.app.tea-core
                #:deftea-app))

(in-package :example.counter)
```

### 2.2 Init

Initialization creates the first model and optionally initial commands:

```lisp
(defun init-counter ()
  (values '(:count 0) nil))
```

Keep expensive startup I/O out of the returned model construction when it can be represented as an initial command instead.

### 2.3 Update

Update maps messages to state transitions and commands:

```lisp
(defun update-counter (message model)
  (case message
    (:increment
     (values (list :count (1+ (getf model :count 0))) nil))
    (:decrement
     (values (list :count (1- (getf model :count 0))) nil))
    (otherwise
     (values model nil))))
```

For larger models, use constructors/helpers that make replacement explicit rather than scattering destructive updates through branches.

### 2.4 View

View maps the current model to UI data:

```lisp
(defun view-counter (model)
  `(:root-viewport
    :id :counter-root
    :children
    ((:text
      :id :counter-value
      :content ,(format nil "Count: ~D" (getf model :count 0))))))
```

The exact available DSL props depend on the node/widget. Keep view-specific formatting here; keep state transition decisions in update.

### 2.5 Subscriptions

Subscriptions describe long-lived external message sources. If the model changes which subscriptions should exist, derive the desired subscription set from the model.

Typical cases:

```text
none                         static application
terminal/timer subscription  periodic refresh/status
external event subscription  stream of messages
```

A subscription should deliver a message. It should not modify the model from a worker thread.

### 2.6 Command processor/effect manager

ElmTUI has a runtime effect layer plus async helpers. A command processor is the seam for application-specific effects that the core does not know about.

A testable pattern is dependency injection:

```lisp
(defun process-command (command queue model config)
  (declare (ignore model config))
  (ecase (first command)
    (:lookup
     (destructuring-bind (_ query request-id) command
       (declare (ignore _))
       (perform-lookup-async query request-id queue)))))
```

Tests can replace `perform-lookup-async` with a fake transport.

### 2.7 Runtime declaration

For this deliberately minimal path, `deftea-app` ties the parts together using
canonical `:transition` semantics. Keep the declaration declarative and move
logic into named functions that are independently testable. Production
applications should normally express the corresponding wiring through
`defapplication`; both constructors lower to the shared runtime app-spec
contract.

## 3. Components and widgets

ElmTUI currently contains more than one widget implementation style. That is important to understand rather than hide.

### 3.1 `defcomponent` widgets

The current `counter` and `button` are defined through `defcomponent`. The component declaration groups:

```text
local state schema
initialization
message/update branches
view
unhandled-message policy
```

For example, the counter owns state values for `value`, `initial-value`, and an active keymap. Its local messages include:

```text
:increment
:decrement
:reset
```

Its keymap sends messages back to its component path. This is a good example of keyboard input being translated into data rather than directly changing the rendered text.

### 3.2 Explicit TEA widget models

The listbox follows a more explicit Elm shape:

```text
listbox-model
init-listbox
update-listbox
view-listbox
```

`update-listbox` begins with:

```lisp
(let ((new-model (copy-structure model))
      (commands nil)
      ...)
  ...
  (values new-model commands))
```

That is a useful widget-level pattern: copy/build a new value, mutate only that new value while constructing it, then return it. The caller's old widget model remains a separate object.

### 3.3 Older/manual component methods

`textinput` currently uses a manually defined component class and `init`/`update` methods with application-state patches. It is functional but illustrates architecture drift: not all widgets share one authoring shape yet.

When authoring new widgets, prefer the framework's current recommended component protocol and make the state semantics explicit.

## 4. Practical widget inventory

The main system currently includes these built-in widget areas.

### Root viewport

Purpose:

- owns the root terminal viewport contract;
- participates in startup/shutdown terminal lifecycle;
- manages inline/full terminal placement and cleanup semantics.

Use it as the application root rather than making arbitrary children responsible for terminal restoration.

### Viewport

Purpose:

- establishes a region for child rendering;
- supports viewport sizing/placement behavior;
- acts as a useful clipping/layout boundary.

An enhanced viewport implementation also exists in the enhanced-widgets system.

### Drawable content

Purpose:

- represents content that participates directly in drawing/rendering.

Use it for low-level visual content rather than for ordinary labels/buttons when a semantic widget exists.

### Label / text

Purpose:

- read-only textual presentation;
- headings, values, descriptions, status messages.

UX guidance:

- avoid forcing users to infer state only from color;
- use stable labels and avoid changing layout width unnecessarily for frequently changing values;
- communicate async/error status explicitly.

### Button

The current `button` supports state including:

```text
label
on-click-msg
disabled
focused
variant
size
aria-label
tooltip
```

Its important messages include:

```text
:button-click
(:set-label new-label)
(:set-disabled boolean)
:focus
:blur
```

On click, it emits the configured command/message rather than performing arbitrary work in the view.

Example component construction from the source contract:

```lisp
(make-instance 'elmtui.ui.widgets.button:button
               :id :save
               :label "Save"
               :on-click-msg '(:save-document)
               :disabled nil)
```

### Text input

The current text input tracks:

```text
value
placeholder
cursor-pos
on-change
on-submit
disabled
```

Its message vocabulary includes:

```text
:textinput-key-press
:textinput-set-value
:textinput-submit
:set-property
```

UX guidance:

- cursor position must remain coherent after external value replacement;
- disabled input must not accept editing commands;
- submit and change are application messages/effects, not hidden direct I/O;
- validation failure should be represented in nearby visible state, not only in a log.

### Listbox

The listbox supports:

```text
items
selected-index
scroll-offset
height
on-select
```

Keyboard behavior includes up/down (`k`/`j` aliases), page up/down, home/end, and enter. Its update logic also ensures the selected item remains in the visible scroll window.

Example view call from its public contract:

```lisp
(elmtui.ui.widgets.listbox:view-listbox
 app-state
 :widget-id :files
 :items '("README.md" "src" "tests")
 :height 8
 :selected-index 0
 :on-select '(:file-selected)
 :empty-text "No files"
 :aria-label "Files"
 :width 32)
```

### Counter

The built-in counter is primarily a compact example of component-local state and keymap messaging. `+`/`=` increment, `-` decrements, and Enter resets.

Use it as an architectural example, not as evidence that every widget should embed a component-specific keymap. Application keymaps should remain predictable and composable.

### Layout and grid container

Purpose:

- compose widgets spatially;
- use flex/grid layout primitives rather than manually computing terminal coordinates for normal UI.

UX guidance:

- keep focus order aligned with visual order;
- reserve enough width for dynamic labels/status;
- verify narrow terminals and resize behavior;
- avoid layouts whose only readable state depends on a precise initial terminal size.

### Scrollable container / scroll panel

Purpose:

- present content larger than the visible region;
- maintain scroll position and scrollbar/viewport behavior.

UX guidance:

- expose current selection/focus independently from scroll position;
- keep page navigation predictable;
- clamp offsets after content shrink;
- ensure shutdown/inline viewport behavior restores the surrounding terminal correctly.

### Key tester / key tester map

Purpose:

- diagnostic/demo tooling for input/keymap behavior.

These are valuable for development but should not enlarge the stable application API merely because they live in the main system.

## 5. A widget authoring contract

New widgets should document and test the same categories.

### Identity

```text
How is the widget identified?
Is its ID stable across renders?
How is the component path formed?
```

### Model/state

```text
What state does it own?
Which state is supplied by the parent?
Is update replacement-based or patch/transaction-based?
```

### Init

Document:

- props/constructor arguments;
- default state;
- initial commands;
- conditions that invalid props can signal.

### Messages

List every supported message shape with examples.

```lisp
:focus
'(:set-label "Continue")
'(:set-items :items ("a" "b"))
```

### Update

State explicitly:

- whether the incoming model is mutated;
- what is returned;
- what commands can be emitted;
- which conditions can be signaled;
- which restarts, if any, are meaningful.

### View

Document:

- rendered node type/tree;
- focusability;
- relevant accessibility/semantic props;
- empty/disabled/loading/error states;
- terminal-size assumptions.

### Focus and keymap

A widget should never make keyboard behavior mysterious.

For interactive widgets document:

```text
focus entry/exit
activation key(s)
arrow-terminal behavior
scroll/navigation keys
whether application keymaps may override them
```

### Conditions/restarts

Do not hide widget failures behind `warn`/`ignore-errors` when the caller can reasonably recover.

A validation condition might expose:

```lisp
(define-condition invalid-widget-prop (elmtui.core.errors:component-error)
  ((property :initarg :property :reader invalid-widget-prop-property)
   (value :initarg :value :reader invalid-widget-prop-value)
   (expected :initarg :expected :reader invalid-widget-prop-expected)))
```

The operation can then offer `USE-VALUE` or `SKIP` if those continuations are safe.

## 6. Focus, keyboard, and terminal UX

Terminal UIs fail usability tests most often at interaction boundaries rather than rendering correctness.

### Make focus visible

An interactive component should have an obvious focused state. Do not rely on “the user knows where the cursor is.”

### Keep key behavior discoverable

For core actions, provide at least one of:

- visible shortcut hints;
- a help overlay;
- contextual status text;
- a predictable conventional key.

The built-in counter's rendered string is a good small example:

```text
Counter [id]: value (+, -, Enter to reset)
```

### Preserve spatial stability

Frequently updating status widgets should avoid changing the entire layout width on each update. Reserve space or choose concise stable labels.

### Treat resize as normal

A terminal resize is not an exceptional event. Layout/view logic must be able to recompute from current model + new geometry without stale cached coordinates leaking into application logic.

### Loading is a state

Async UI should distinguish at least:

```text
idle
loading
success/ready
failure
```

For overlapping requests, track a request ID so late responses cannot overwrite newer intent.

### Failure must be visible and inspectable

User-facing state might show:

```text
Could not load results. Press r to retry.
```

The corresponding Lisp condition should still retain the original transport condition, operation, query/request id, and any retry metadata for handlers/debugging.

## 7. Async work pattern

`elmtui.core.async:cmd-async` builds an async command around a function. The current function contract supplies a progress callback as the first argument, followed by `:args`.

A task can return application messages through `:on-complete` and `:on-error` callbacks.

Schematic example:

```lisp
(elmtui.core.async:cmd-async
 (lambda (progress query)
   (funcall progress '(:phase :connecting))
   (lookup query))
 :args (list query)
 :on-complete
 (lambda (result)
   `(:lookup-succeeded :result ,result))
 :on-error
 (lambda (condition)
   `(:lookup-failed :condition ,condition)))
```

Do not call the network from `view` or synchronously from `update`. The update branch should emit the command and set `:loading` state; completion messages move state to success/failure.

## 8. Condition/restart application pattern

Suppose a command needs a cached value when a live lookup fails. Make the operation recoverable without discarding the original condition:

```lisp
(defun read-value-with-policy (thunk cached-value)
  (handler-bind
      ((elmtui.core.errors:elmtui-error
         (lambda (condition)
           (format *debug-io* "Lookup failed in ~A: ~A~%"
                   (elmtui.core.errors:elmtui-error-module condition)
                   condition)
           (when cached-value
             (invoke-restart 'use-value cached-value)))))
    (elmtui.core.conditions:with-recovery
        (elmtui.core.errors:elmtui-error
         :restarts '(:retry :use-value :abort))
      (funcall thunk))))
```

This has three useful properties:

1. the debugger/handler sees the original structured condition;
2. a cached fallback is an explicit recovery decision;
3. retry remains available when the operation is safe to repeat.

## 9. Polling pattern

Do not write another local loop like:

```lisp
(loop
  (when (ready-p) (return ...))
  (when (> (get-internal-real-time) deadline) (return nil))
  (sleep 0.001))
```

Use the shared primitive:

```lisp
(cl-events.loop:poll-until
 (lambda ()
   (when (ready-p)
     (values result metadata)))
 :timeout 0.5
 :interval 0.001)
```

Tests can inject `:sleep-fn` and `:now-fn`; production call sites share one timeout/backoff contract.

## 10. Testing layers

A widget/application should be testable at several levels.

### Pure update test

```lisp
(multiple-value-bind (next commands)
    (update-counter :increment '(:count 4))
  (is (= 5 (getf next :count)))
  (is (null commands)))
```

### Model non-mutation test

```lisp
(let ((before (list :count 4)))
  (multiple-value-bind (next commands)
      (update-counter :increment before)
    (declare (ignore commands))
    (is (= 4 (getf before :count)))
    (is (= 5 (getf next :count)))
    (is-false (eq before next))))
```

### View test

Call the view with a model and inspect the resulting node/DSL without a terminal.

### Component test

Initialize/update one widget and assert state patches/models plus emitted commands.

### Runtime e2e

Feed synthetic token/event input through routing, update, command handling, and rendering. ElmTUI's existing runtime e2e and faketerm suites already exercise this seam.

### Terminal lifecycle e2e

Verify raw-mode cleanup, cursor restoration, inline viewport cleanup, and shutdown commands. These tests protect behavior that pure update tests cannot see.

## 11. Architecture decisions to make explicitly

The current repository should continue converging around these decisions:

```text
Recommended application state semantics?
  -> pure model replacement, with transactional state explicitly opt-in

Stable API boundary?
  -> small elmtui facade + subsystem .api packages

Widget authoring model?
  -> one documented protocol, not three historical styles

Condition hierarchy?
  -> one navigable framework family with prefixed readers

ASDF packaging?
  -> library runtime separate from program/docs/tests/examples

Documentation?
  -> docstrings are executable API metadata, generated references are derived output
```

The framework already has the mechanisms necessary for these choices. The next stage is consistency: make every package, widget, condition, and document tell the same architectural story.
