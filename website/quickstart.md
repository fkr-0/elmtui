# Quickstart

Build a Common Lisp terminal interface where **model**, **messages**, **update**, and **view** stay distinct.

!!! info "Supported development environment"
    ElmTUI is presently qualified for **SBCL on POSIX-like terminals**. The project uses CLPM for the locked dependency workflow. Mouse, extended keys and color depth depend on the terminal.

## Install dependencies

Clone the repository, including the four separate libraries:

```sh
git clone --recurse-submodules https://github.com/fkr-0/elmtui.git
cd elmtui
clpm bundle install
```

## Try an existing application

```sh
./scripts/examples.sh list
./scripts/examples.sh run minimal-app
./scripts/examples.sh run neon-pong
```

The complete executable and keybinding catalog is in [Examples](examples.md). Some examples require external executables (such as NetworkManager's `nmcli`) or wider terminal dimensions.

## Your first application

Save this as `counter.lisp`:

```lisp
(uiop:define-package :counter
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.core.event-types #:key-event #:key-event-char)
  (:export #:run-counter))
(in-package :counter)

;; ElmTUI logs through log4cl; keep log lines off the screen the app draws on.
(log4cl:remove-all-appenders log4cl:*root-logger*)

(defun initial-state ()
  (list :count 0 :should-quit nil))

(defun update (message state)
  "Return the state changes MESSAGE causes, as patches."
  (let ((char (and (typep message 'key-event) (key-event-char message)))
        (count (state-ref state :count 0)))
    (cond
      ((eql char #\+) (make-update-result :patches `(((:count) ,(1+ count)))))
      ((eql char #\-) (make-update-result :patches `(((:count) ,(1- count)))))
      ((or (eql char #\q)
           (and (consp message) (eq (first message) :app-quit-requested)))
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

(defapplication counter
  :root-component-dsl '(:root-viewport :id :counter-root
                        :anchor :below-cursor :height 3
                        :child-dsl-spec (:view nil))
  :root-viewport-id :counter-root
  :initial-state-fn #'initial-state
  :update-fn #'update
  :view-fn #'view)
```

Run it from the repository root:

```sh
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --eval '(require :asdf)' --eval '(asdf:load-system "elmtui")' \
  --load counter.lisp --eval '(counter:run-counter)'
```

Press `+` and `-` to change the count and `q` to quit. The terminal and its scrollback are restored when the application exits.

How it fits together:

- `initial-state` returns the model, a plist.
- `update` receives each message and the current state. It never changes the state itself; it returns `make-update-result` with *patches* (pairs of a state path and a new value), which the runtime applies. Key presses arrive as `key-event` objects; Ctrl-C arrives as `(:app-quit-requested)`, and setting `:should-quit` ends the application.
- `view` is a pure function from state to a declarative UI tree (`:container`, `:text`, …) with CSS-like styles.
- `defapplication` wires them together and defines `run-counter`. The root viewport is drawn below the cursor and needs an explicit `:height`.

The key contract is:

```text
init  -> model
view  <- model
msg   -> update(model, msg) -> patches + commands
commands -> results as messages -> update
```

`elmtui.app:defapplication` is the application constructor to use. `elmtui.app.tea-core:deftea-app`, a smaller direct-model-replacement constructor, is currently unable to run applications in a terminal (see the [API review](https://github.com/fkr-0/elmtui/blob/main/docs/reviews/api-review-20261101.md)).

The [foundations](guide/foundations.md) chapter explains the architecture, and the [counter and async tutorial](guide/tutorial.md) shows how to test update functions without a terminal.

## Explore the Workbench

The flagship [Common Lisp Workbench](workbench.md) is a separately loadable terminal IDE / REPL built with ElmTUI:

```sh
scripts/examples.sh run repl
```
