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
  (:import-from :elmtui
                #:defapplication #:make-update-result #:state-ref
                #:key-pressed-p #:quit-requested-p)
  (:export #:run-counter))
(in-package :counter)

(defun initial-state ()
  (list :count 0 :should-quit nil))

(defun update (message state)
  "Return the state changes MESSAGE causes, as patches."
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
- `update` receives each message and the current state. It never changes the state itself; it returns `make-update-result` with *patches* (pairs of a state path and a new value), which the runtime applies. `key-pressed-p` matches key presses (by `:char`, `:key` such as `:up`, and `:modifiers`); `quit-requested-p` recognises Ctrl-C. Setting `:should-quit` ends the application.
- `view` is a pure function from state to a declarative UI tree (`:container`, `:text`, …) with CSS-like styles.
- `defapplication` wires them together and defines `run-counter`. The root viewport is drawn below the cursor and needs an explicit `:height`. Framework logging is off while the application runs; pass `:log-file "counter.log"` to `run-counter` to keep it.

The key contract is:

```text
init  -> model
view  <- model
msg   -> update(model, msg) -> patches + commands
commands -> results as messages -> update
```

The root `elmtui` package exports the application API used here. `defapplication` is the full application constructor; `deftea-app` is a smaller constructor for programs whose update function returns a whole new model instead of patches; it expands into `defapplication`.

The [foundations](guide/foundations.md) chapter explains the architecture, and the [counter and async tutorial](guide/tutorial.md) shows how to test update functions without a terminal.

## Explore the Workbench

The flagship [Common Lisp Workbench](workbench.md) is a separately loadable terminal IDE / REPL built with ElmTUI:

```sh
scripts/examples.sh run repl
```
