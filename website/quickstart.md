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
./examples.sh list
./examples.sh run minimal-app
./examples.sh run neon-pong
```

The complete executable and keybinding catalog is in [Examples](examples.md). Some examples require external executables (such as NetworkManager's `nmcli`) or wider terminal dimensions.

## Your first TEA application

The key contract is:

```text
init  -> model
view  <- model
msg   -> update(model, msg) -> new model + commands
commands -> results as messages -> update
```

ElmTUI supports two application constructors:

| Constructor | When to use |
|---|---|
| `elmtui.app:defapplication` | Full application DSL, viewport and configurable state engine |
| `elmtui.app.tea-core:deftea-app` | Small teaching applications using direct model replacement |

The [counter and async tutorial](guide/tutorial.md) walks through the direct-model API and the [foundations](guide/foundations.md) explain the distinction between strict immutable snapshots and transactional patches.

You can load the main framework in the checked-in CLPM context:

```sh
clpm bundle exec --with-client sbcl -- \
  --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:load-system "elmtui")'
```

## Explore the Workbench

The flagship [Common Lisp Workbench](workbench.md) is a separately loadable terminal IDE / REPL. Its 0.1.0 release qualification is still underway.

```sh
clpm bundle exec --with-client sbcl -- \
  --noinform --non-interactive \
  --load examples/workbench.lisp
```

The actual launcher must be exercised in a real PTY before release; see [release status](release.md).
