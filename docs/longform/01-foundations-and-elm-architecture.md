# ElmTUI foundations: Elm architecture in Common Lisp

ElmTUI is easiest to understand as a unidirectional terminal application runtime built around the Elm Architecture / TEA idea: application state is represented by a model, events become messages, update logic turns a message and model into the next model plus commands, and view logic projects the current model into a terminal UI tree.

The Common Lisp implementation adds facilities that Elm itself does not have in the same form: CLOS and generic functions, the condition/restart system, dynamic bindings, macros that can define application and widget protocols, inspectable application objects, and multiple state representations. Those facilities are strengths, but they make one distinction especially important:

> ElmTUI exposes one TEA transition model with two state-commit implementations: a low-allocation transactional implementation and an opt-in strict replacement implementation. Internal mutation does not by itself violate Elm semantics; the relevant question is whether that mutation is observable through the application contract.

This distinction between **semantic immutability** and **representation mutation** is the foundation for understanding the runtime correctly.

## 1. The TEA loop

A useful mental model is:

```text
terminal/device input
        |
        v
    event/token
        |
        v
     message -------------------------------+
        |                                    |
        v                                    |
  UPDATE(message, model)                     |
        |                                    |
        +----> next model                    |
        |          |                         |
        |          v                         |
        |       VIEW(model)                  |
        |          |                         |
        |          v                         |
        |        DSL/tree                    |
        |          |                         |
        |          v                         |
        |    layout + render                 |
        |          |                         |
        |          v                         |
        |       backend                      |
        |                                    |
        +----> commands/effects              |
                   |                         |
                   +----> result message ----+
```

There are five important concepts here.

### Model

The model is the application-visible state from which the UI is derived. A model may be a plist, structure, object, hash table, `cl-state` application state, or another representation accepted by a particular application layer.

### Message

A message is data describing something that happened or something that should happen next. Keyboard input, component messages, timer results, async completion, and explicit application actions all eventually participate in message routing.

Messages being ordinary data is important. It keeps routing inspectable and makes tests able to drive update logic without a real terminal.

### Update

Update is the decision function. In the strict TEA path it receives a message and the current model and returns a next model plus commands. It should not perform terminal rendering and should avoid performing effects directly.

### View

View is a projection of a model into a UI description. In ElmTUI that description becomes a DSL/tree which then passes through layout/rendering and backend stages.

A good view function is deterministic: the same relevant model state produces the same UI description. That makes view rendering testable without terminal input.

### Commands and subscriptions

Commands describe effects to perform after update; subscriptions describe external event sources that should produce messages over time. The important architectural property is that effect completion re-enters the application as data/messages rather than reaching sideways into rendering logic.

## 2. Elm semantics are an observable contract, not a ban on machine mutation

`src/app/tea-core.lisp` states the familiar transition contract directly:

```lisp
UPDATE-FN :: (MSG MODEL) -> (values NEXT-MODEL COMMANDS)
```

The driver installs the returned model:

```lisp
(multiple-value-bind (next-model commands)
    (funcall update-fn msg *current-app-model*)
  (setf *current-app-model* next-model
        elmtui.core.globals:*app-state* next-model)
  ...)
```

That path has straightforward replacement semantics. But the stronger point is that **a runtime may use mutation internally without changing TEA semantics**. Compilers, garbage collectors, persistent data-structure implementations, databases, and Elm runtimes themselves are free to mutate private memory as an implementation technique. What matters to the program is whether two implementations can be distinguished through the supported language/API observations.

For the `cl-state` application path, define:

```text
α(s)              = the logical model value represented by runtime state s
T(m, msg)          = the TEA transition yielding (m', commands)
R(s, msg)          = ElmTUI's concrete runtime transition
```

The fast transactional implementation is a refinement of the abstract TEA transition when the following obligations hold:

```text
1. State equivalence
   α(R(s, msg).state) = first(T(α(s), msg))

2. Effect equivalence
   R(s, msg).commands = second(T(α(s), msg))

3. No observable intermediate write
   user update/view/subscription code cannot observe the commit half-applied

4. Decision purity at the state boundary
   update expresses state change as patches against an isolated draft;
   framework commit, not user decision code, applies those patches
```

Under those obligations, changing `s` in place is representation strategy, not a different application semantics. A user who only observes model values, messages and commands sees the same trace as a replacement implementation.

ElmTUI now tests that claim directly. The state-semantics suite drives the same message trace through both commit engines and checks equality of the visible model values and emitted commands after every transition.

This is best called **observational TEA equivalence** or **an implementation refinement of Elm-style state transitions**. It is stronger and more precise than saying merely that the API “feels Elm-like.”

It is not, however, unrestricted contextual equivalence against arbitrary Common Lisp code. Common Lisp permits object identity tests, destructive operations, foreign calls, global mutation and arbitrary side effects. The public `CL-STATE.API:APPLICATION-STATE-DATA` / `ELMTUI.STATE:APPLICATION-STATE-DATA` compatibility read is now an owned snapshot, so mutating that snapshot does not mutate the model and `(SETF APPLICATION-STATE-DATA)` is rejected. Framework internals can still deliberately name the low-level `CL-STATE.CORE:APPLICATION-STATE-DATA` live representation accessor; code doing so has explicitly stepped outside the public state abstraction and can distinguish implementations.

## 3. Why the normal `DEFAPPLICATION` API already feels like Elm

Regular `DEFAPPLICATION` update functions do not normally receive a writable store interface. They receive an update context and state changes are expressed as patches:

```lisp
(defun update (message ctx)
  (case message
    (:increment
     (sapply ctx :count #'1+ 0)
     (make-update-result :handled t))
    (otherwise
     (make-update-result :handled t))))
```

The context owns a draft. That draft is now a deep copy across the supported `cl-state` container graph:

```lisp
(defun make-update-context (state &key base-path)
  ...
  (let ((draft (deep-copy-data (application-state-plist state))))
    ...))
```

That detail closes an important earlier hole: with a plist backend, the old implementation could hand the update context an alias of the current state's nested list structure while documenting it as isolated. Tests now deliberately mutate nested draft conses and vectors and prove the previous application state remains unchanged before commit.

The user-facing sequence is therefore:

```text
current model
    |
    v
isolated update draft
    |
    +-- SREF / SAPPLY / SDELETE
    |
    v
patches + commands
    |
    v
framework commit
    |
    v
next visible model
```

From the application author's side this is strongly Elm-like even in the fast mode:

- input is data/messages;
- update is a decision step;
- model changes are described, not immediately performed on the current store;
- effects are returned as commands;
- effect results return as messages;
- view reads the committed model;
- the renderer is downstream from the model transition.

## 4. Two commit engines for one transition semantics

`DEFAPPLICATION` now accepts:

```lisp
:state-semantics :transactional   ; default
:state-semantics :strict-elm
```

Both modes execute the same application update logic and produce the same patches/commands. They differ only in commit representation.

The central switch is deliberately small:

```lisp
(defun %commit-state-patches (state patches semantics)
  (ecase semantics
    (:transactional
     (apply-patches state patches))
    (:strict-elm
     (cl-state.patch::apply-patches-shared
      state patches :name :strict-elm-commit))))
```

### 4.1 `:transactional`: optimized observational TEA

The default applies patches to the existing `APPLICATION-STATE`. That preserves the current low-allocation transaction/log/observer/undo machinery and avoids copying a potentially large model graph merely to change one leaf.

Object identity therefore remains stable:

```text
state-before EQ state-after    => true is allowed
α(state-before-after-commit)   => new logical model value
```

This mode is semantically TEA-like **under the framework ownership discipline**: do not retain mutable aliases to the representation and then use them to observe or modify commits behind the state API. This is comparable to an implementation using a mutable transients layer beneath a functional interface.

### 4.2 `:strict-elm`: frozen replacement snapshots with structural sharing

Strict mode now uses a persistent path-copying commit engine. A changed path gets a new spine; branches that are not touched by the transition are reused by identity:

```text
old root --------------------+---------------- untouched branch
   |                         |                        ^
   +-- changed parent        |                        |
                             |                        |
new root -- new parent ------+------------------------+
                |
                +-- new changed leaf
```

The implementation copies caller-owned patch values before installing them. For `:UPDATE` patches it also copies the old value before calling the update function and copies the result before storage. Consequently a destructive update helper cannot mutate the source snapshot or retain an alias into the newly committed model.

The returned `APPLICATION-STATE` is marked frozen. Supported mutating state operations reject a frozen strict snapshot with `CL-STATE.CORE:STATE-MUTATION-FORBIDDEN` even after the dynamic update/view phase has ended. During update, component dispatch, view, subscriptions, and custom command processing, the existing dynamic read-only policy remains an additional guard.

The older eager `APPLY-PATCHES-PERSISTENT` engine is intentionally retained. It full-copies the supported graph and is used as a simple correctness oracle in differential tests; it is no longer the commit engine used by `:strict-elm` applications.

A strict application is therefore simply:

```lisp
(elmtui.app:defapplication counter
  :initial-state-plist '(:count 0)
  :root-component-dsl '(:root-viewport :id :root :children ())
  :root-viewport-id :root
  :update-fn counter-update
  :view-fn counter-view
  :subscriptions-fn counter-subscriptions
  :state-semantics :strict-elm)
```

The executable guarantees include:

```text
old-state EQ new-state                       => false
state-ref old-state ...                       => retained snapshot stays unchanged
state-ref new-state ...                       => transitioned values
changed path containers                      => copied
untouched branches                           => may be EQ/shared by design
supported mutation of frozen strict state    => STATE-MUTATION-FORBIDDEN
same message trace in fast/eager/shared       => same logical values + commands
```

### 4.3 What strict mode does not claim

It is important not to turn a useful guarantee into an impossible one.

Strict mode guarantees the **supported ElmTUI/cl-state mutation interface** and replacement-snapshot semantics. It does not make arbitrary Lisp objects physically immutable:

- `STATE-REF` returns ordinary Lisp values. Destructively modifying a returned shared hash table/list/vector with raw Common Lisp operations bypasses the state API and can therefore violate the persistent-value discipline;
- public `APPLICATION-STATE-DATA` is a deprecated owned-snapshot compatibility read and cannot replace the backing store; only explicitly naming `CL-STATE.CORE:APPLICATION-STATE-DATA` accesses the low-level live representation and is outside supported application code;
- custom mutable CLOS objects, foreign objects, streams, locks, etc. stored as leaf values cannot be portably cloned by Common Lisp, so strict applications must treat them as immutable values or explicitly copy them before insertion;
- update code can still mutate unrelated globals or perform arbitrary I/O because Common Lisp is not a pure language. Strict mode enforces model-transition discipline, not total functional purity.

This is the same basic ownership rule required by persistent data structures in an impure host language: **shared values are immutable by contract**. The framework protects its supported mutators and copies values crossing changed patch boundaries; it cannot intercept arbitrary `RPLACA`, `SETF GETHASH`, foreign mutation, or implementation-specific destructive operations performed on values a caller has deliberately extracted.

### 4.4 Performance is precisely why both modes are useful

Pure semantics do not require a particular allocation strategy. The strict runtime now pays primarily for containers on changed paths, copied changed values, transaction metadata, and the fresh state wrapper rather than for the full model graph. The eager full-copy implementation remains valuable because it is simple enough to serve as a differential oracle.

A reproducible SBCL benchmark lives at `scripts/benchmarks/state_semantics_benchmark.lisp`. On a representative narrow-update run with 2,000 branches and 120 transitions, the current implementation measured approximately:

```text
transactional      0.007 s      4.70 MB consed
eager persistent   0.050 s    134.33 MB consed
shared persistent  0.007 s     11.69 MB consed

shared / eager:       0.14x time, 0.087x allocation
shared / transactional: 1.00x time, 2.49x allocation
```

Wall-clock values at this scale are coarse and machine-dependent; the allocation difference is the more stable signal. The result is consistent with the intended complexity change: narrow strict updates no longer copy the entire state graph.

The transactional mode remains the lowest-allocation default when applications accept the ownership discipline. Strict mode is valuable for:

- teaching and demonstrating exact replacement semantics;
- tests that need old snapshots to remain stable;
- debugging aliasing violations;
- applications where stronger state reasoning matters more than allocation cost;
- serving as a reference semantics against which optimized commit engines can be differential-tested.

This gives ElmTUI three useful layers: **eager persistent commit is the simple test oracle; structurally shared strict mode is the production replacement-snapshot implementation; transactional mode is the lowest-cost mutable refinement.** A deterministic 256-transition CL-state trace compares all three engines, and an application-level 128-transition trace additionally retains old strict snapshots and verifies that they never drift.

## 5. The runtime core, step by step

### 5.1 Input becomes data

`cl-inputs` owns device access and decoding. It turns bytes/device activity into tokens. The platform layer turns relevant tokens into ElmTUI events/messages.

This separation matters because the runtime can be tested with `faketerm` and synthetic tokens. An application's update function should not need to call `read-char` or inspect `/dev/tty`.

### 5.2 Event routing produces application messages

Core event channels and routing connect input, subscriptions, async completion, and components. Repeated non-blocking probing is now centralized in `cl-events.loop:poll-until`; ElmTUI wrappers provide probes instead of reimplementing timeout/sleep loops.

The polling contract is intentionally small:

```text
probe succeeds      -> return all probe values
probe not ready     -> cooperative backoff, then retry
stop predicate true -> return NIL
timeout NIL         -> unbounded wait
zero timeout        -> exactly one probe
positive timeout    -> bounded wait
```

Backend functions that genuinely block in the operating system, such as “wait until a terminal device is readable,” remain backend I/O primitives. They are not rewritten as spin polling merely to satisfy an abstraction.

### 5.3 Update chooses the next state and effects

The application update function is invoked only after a message exists. In the pure path it returns the next model and commands. In transactional/component paths it may return patches/commands that the runtime applies to an isolated state store.

The conceptual rule is the same in both modes: update decides; it should not perform terminal drawing itself.

### 5.4 Commands are interpreted after the decision

`elmtui.core.async` and the runtime effect layer interpret command data. Async task completion and failures can create new messages which feed back into the update loop.

This makes slow I/O an effect rather than a reason to block rendering/input handling.

### 5.5 View produces a tree

View functions transform model data into the ElmTUI view DSL or UI nodes. Layout then assigns geometry, styling resolves appearance, and rendering derives backend operations.

The terminal backend is therefore downstream from application semantics:

```text
model -> view tree -> layout/styling -> virtual terminal buffer -> diff/backend output
```

That division is why faketerm tests can verify much of the runtime without taking over a real terminal.

## 6. Mutation boundaries

A practical ElmTUI program should identify every mutation boundary deliberately.

### Pure application model

Prefer fresh models in update:

```lisp
(defun rename-user (message model)
  (destructuring-bind (_ new-name) message
    (declare (ignore _))
    (values (list :name new-name
                  :status (getf model :status))
            nil)))
```

### Transactional framework state

When using `cl-state`, mutation should pass through its transaction/path APIs rather than arbitrary `SETF` into implementation internals. This preserves logging, rollback, versioning, and observer semantics.

### Backend state

A terminal backend necessarily mutates the external world: raw mode, cursor position, screen contents, and device buffers are effects. Keep those mutations below the runtime/backend boundary.

### Diagnostic state

Conditions may carry mutable diagnostic context. `with-error-context` now annotates the original ElmTUI condition rather than constructing a lossy replacement. That mutation is diagnostic, not application-state mutation, and preserves debugger identity.

## 7. Common Lisp conditions are part of the architecture

A Lisp framework should not reduce failures to strings or booleans when it can expose inspectable conditions and restarts.

ElmTUI's intended failure flow is:

```text
operation
  |
  +-- signals/errors with structured condition
          |
          +-- handler may inspect context
          |
          +-- debugger may inspect live stack/state
          |
          +-- active restart may recover
                 |- RETRY
                 |- SKIP / IGNORE-TASK
                 |- USE-VALUE / provide fallback
                 `- ABORT / propagate
```

The restart belongs around the operation that can be retried or substituted, not around a second re-signaling of a reconstructed condition. That distinction is important because handlers must see the original condition while recovery options are active.

For example:

```lisp
(handler-bind
    ((elmtui.core.errors:state-error
       (lambda (condition)
         (format *debug-io* "State failure: ~S~%"
                 (elmtui.core.errors:elmtui-error-context condition))
         (invoke-restart 'use-value :fallback))))
  (elmtui.core.conditions:with-recovery
      (elmtui.core.errors:state-error
       :restarts '(:use-value :abort))
    (operation-that-may-fail)))
```

A retry restart also creates an obligation: the retried body should be idempotent, transactional, or documented as potentially repeating effects.

## 8. Subscriptions and recurring work

Subscriptions should be thought of as declarations of external message sources, not as arbitrary background mutation.

Typical subscription sources include:

- terminal resize/activity;
- timers;
- recurring status refresh;
- async task completion;
- external event streams.

The clean direction is:

```text
subscription/event source
    -> message
    -> update
    -> next state + commands
```

If a recurring worker directly mutates application state, it bypasses the architecture and creates synchronization/debugging problems.

## 9. Widget state is where the two modes meet

Widgets illustrate why the distinction matters. Some ElmTUI widgets are written as `defcomponent` components with local state/patches; others such as the listbox have a conventional explicit model with `init-listbox`, `update-listbox`, and `view-listbox`.

The listbox's update logic copies its structure first:

```lisp
(let ((new-model (copy-structure model))
      ...)
  ...
  (values new-model commands))
```

This gives a TEA-style replacement at widget-model granularity even though the copied structure is subsequently mutated while constructing the new value. The caller's original `model` is not the object being changed.

By contrast, `cl-state` state paths may be mutated transactionally. Both approaches can coexist, but API documentation must say which one is in effect.

## 10. Rules for writing strict TEA ElmTUI applications

Use `:state-semantics :strict-elm` when you want ElmTUI to enforce the strongest supported state contract, then follow these rules:

1. Treat model values as values; use `STATE-REF`/`STATE-VALUE`/`STATE-SNAPSHOT`, and never depend on the internal `CL-STATE.CORE:APPLICATION-STATE-DATA` backing representation.
2. Express application changes through the update context and patches.
3. Let the runtime return/install the fresh strict replacement model.
4. Treat custom mutable leaf objects as immutable or explicitly copy them before insertion.
5. Return commands as data; do not run I/O in update.
6. Make async results return as messages.
7. Keep view deterministic and free of observable external side effects.
8. Keep terminal/device mutation behind the backend/effect layer.
9. Use conditions/restarts for exceptional control flow instead of sentinel strings or blanket `ignore-errors`.
10. Differential-test optimized state implementations against strict mode when their correctness matters.

For performance-sensitive applications using `:transactional`, the same application-level discipline is recommended even though the runtime deliberately retains the mutable representation optimization.

## 11. The architectural target

ElmTUI does not need to imitate Elm's implementation language to benefit from Elm's architecture. Common Lisp can offer the same unidirectional reasoning while adding tools that are unusually powerful for interactive systems: live debugging, restarts, generic functions, macros, runtime introspection, and hot development.

The durable target is therefore not “make Common Lisp pretend to be Elm.” It is:

> Specify Elm/TEA at the observable transition boundary, provide a strict executable reference semantics, permit optimized hidden mutation when it refines that semantics, isolate effects, preserve conditions as rich Lisp objects, and use Common Lisp's dynamic recovery machinery without weakening the ability to reason from message + model to the next visible state.

That is the foundation on which the rest of ElmTUI's APIs, widgets, and runtime documentation should be read.
