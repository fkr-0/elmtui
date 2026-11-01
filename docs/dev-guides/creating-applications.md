# Creating ElmTUI applications

This guide walks through building an ElmTUI application from scratch.
It covers both constructors — `defapplication` (the full production
surface) and `deftea-app` (the minimal direct-transition adapter) — and
shows how the normative runtime vocabulary maps onto each.

## The runtime contract

Every ElmTUI application lowers to the same runtime specification
(`make-runtime-app-spec`). The normative vocabulary is:

```text
INIT        :: () -> (values MODEL COMMANDS)
TRANSITION  :: (MESSAGE MODEL) -> (values NEXT-MODEL COMMANDS)
VIEW        :: MODEL -> DSL-TREE
SUBSCRIPTIONS :: MODEL -> SUBSCRIPTIONS
```

`defapplication` accepts `:update-fn` / `:view-fn` keywords that adapt
the patch-based update contract into the runtime transition.
`deftea-app` accepts `:transition` / `:view` keywords for a direct
model-replacement style. Both share one runtime.

## Minimal application with `deftea-app`

`deftea-app` is the smallest path. Use it for pedagogical programs or
small tools whose update function returns a whole new model.

```lisp
(uiop:define-package :my-counter
  (:use :cl)
  (:import-from :elmtui
                #:deftea-app)
  (:export #:run-my-counter))
(in-package :my-counter)

(defun init ()
  (values '(:count 0) nil))

(defun transition (message model)
  (let ((count (getf model :count 0)))
    (cond
      ((eql message :increment)
       (values (list :count (1+ count)) nil))
      ((eql message :decrement)
       (values (list :count (1- count)) nil))
      (t (values model nil)))))

(defun view (model)
  `(:text :id :display
    :content ,(format nil "Count: ~D" (getf model :count 0))))

(deftea-app my-counter
  :init #'init
  :transition #'transition
  :view #'view
  :root-viewport-id :counter-root
  :anchor :below-cursor
  :height 3)
```

Run it:

```sh
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --eval '(require :asdf)' --eval '(asdf:load-system "elmtui")' \
  --load my-counter.lisp --eval '(my-counter:run-my-counter)'
```

Ctrl-C quits. Returning a model plist with `:should-quit t` from
`transition` also ends the application.

### What `deftea-app` generates

- Adapter functions that keep the model under `:tea-model` of the
  application state.
- A `defapplication` expansion with `:strict-elm` state semantics.
- `run-my-counter` — the application runner.
- `*my-counter-app-spec*` — a runtime spec plist for
  `elmtui.app.api:run-application`.

## Production application with `defapplication`

`defapplication` is the normative full application constructor. It owns
the production surface: CL-STATE initialization, component/root-viewport
wiring, context/patch-based updates, subscriptions, CLI and binary
configuration, keymaps, and selectable `:transactional` / `:strict-elm`
commit semantics.

```lisp
(uiop:define-package :my-app
  (:use :cl)
  (:import-from :elmtui
                #:defapplication #:make-update-result #:state-ref
                #:key-pressed-p #:quit-requested-p)
  (:export #:run-my-app))
(in-package :my-app)

(defun initial-state ()
  (list :count 0 :should-quit nil))

(defun update (message state)
  (let ((count (state-ref state :count 0)))
    (cond
      ((key-pressed-p message :char #\+)
       (make-update-result :patches `(((:count) ,(1+ count)))))
      ((key-pressed-p message :char #\-)
       (make-update-result :patches `(((:count) ,(1- count)))))
      ((or (key-pressed-p message :char #\q) (quit-requested-p message))
       (make-update-result :patches '(((:should-quit) t))))
      (t (make-update-result)))))

(defun view (state)
  `(:container
    :id :root
    :style (:display :block :width 34 :height 3 :padding 1)
    :children
    ((:text :id :count
      :content ,(format nil "Count: ~D   (+/- change, q quits)"
                        (state-ref state :count 0))))))

(defapplication my-app
  :root-component-dsl '(:root-viewport :id :app-root
                        :anchor :below-cursor :height 3
                        :child-dsl-spec (:view nil))
  :root-viewport-id :app-root
  :initial-state-fn #'initial-state
  :update-fn #'update
  :view-fn #'view)
```

### Key differences from `deftea-app`

| | `deftea-app` | `defapplication` |
|---|---|---|
| Update contract | `(message model) -> (values next-model commands)` | `(message state) -> update-result` |
| State access | Direct plist / structure access | `state-ref` reads from application state |
| State changes | Return a replacement model | Return `make-update-result` with patches |
| State semantics | Always `:strict-elm` | `:transactional` (default) or `:strict-elm` |
| Key matching | Manual `case`/`cond` | `key-pressed-p`, `quit-requested-p` |
| Root viewport | Optional `:anchor` / `:height` | Explicit `:root-component-dsl` |

### Required keywords

- `:root-viewport-id` — keyword identifying the root viewport.
- `:root-component-dsl` — quoted DSL form for the root component tree.

### Optional keywords

- `:initial-state-plist` or `:initial-state-fn` — initial model. The
  function form may return startup commands as a second value.
- `:update-fn` — `(message state) -> update-result`. Read state with
  `state-ref`; return `make-update-result` with `:patches` and
  `:commands`.
- `:view-fn` — `(state) -> dsl-tree`, rendered inside the root viewport.
- `:subscriptions-fn` — `(state) -> subscriptions`.
- `:command-processor-fn` — custom effect interpreter.
- `:state-semantics` — `:transactional` (default) or `:strict-elm`.
- `:cli-options` — CLI argument specifications.
- `:binary` — standalone packaging configuration.

### Generated runner

`defapplication` defines `run-my-app`:

```lisp
(my-app:run-my-app &key platform platform-options argv
                        log-file log-buffer)
```

Framework logging is silent while the application runs. Pass
`:log-file "app.log"` to capture it.

## State access

`defapplication` update functions receive the application state (not a
raw plist). Read values with `state-ref`:

```lisp
(state-ref state :count 0)        ; read :count with default 0
(state-ref state :user :name)     ; nested path
```

Return changes as patches in `make-update-result`:

```lisp
(make-update-result
 :patches `(((:count) ,(1+ current-count))
            ((:status) :ready))
 :commands (list (cmd-async ...)))
```

Each patch is `(PATH NEW-VALUE)` where PATH is a list of keys.

## Effects and commands

Update functions should not perform I/O directly. Return commands as
data and let the runtime execute them:

```lisp
(elmtui.core.async:cmd-async #'fetch-data
  :args '("query")
  :on-complete (lambda (result) `(:data-arrived :data ,result))
  :on-error    (lambda (condition) `(:data-failed :err ,condition))
  :timeout     10)
```

Completion and error results re-enter the message loop. See the
[widgets and patterns](../longform/02-core-principles-widgets-and-patterns.md)
chapter for the complete effects API.

## Choosing between constructors

Use `deftea-app` when:

- Building a small tool or teaching example.
- The update function naturally returns a whole new model.
- You do not need component state, CLI configuration, or transaction
  semantics control.

Use `defapplication` when:

- Building a production application.
- You need patch-based updates, component wiring, or keymaps.
- You want selectable `:transactional` / `:strict-elm` commit semantics.
- You need CLI argument parsing or binary packaging.

Both constructors lower to the same runtime, so the transition from
`deftea-app` to `defapplication` is straightforward.

## Next steps

- [Foundations: Elm architecture in Common Lisp](../longform/01-foundations-and-elm-architecture.md)
- [Counter and async tutorial](../longform/03-hands-on-counter-and-async.md)
- [Widgets and patterns](../longform/02-core-principles-widgets-and-patterns.md)
- [Creating widgets](./creating-widgets.md)
