# Development environment setup

## Prerequisites

- **SBCL** (Steel Bank Common Lisp). ElmTUI is qualified on SBCL; other
  implementations are not yet supported because parts of the toolkit use
  `sb-posix` and `sb-mop`.
- **[CLPM](https://www.clpm.dev/)** — the Common Lisp Package Manager.
  ElmTUI uses CLPM for its locked dependency workflow.
- **Git** — the four `cl-*` libraries are real Git submodules.
- **A POSIX terminal** with ANSI support. tmux is optional but
  recommended for the overlay examples.

### Recommended editor

- **Emacs with SLY** — ElmTUI's own development uses SLY/Slynk. The
  `dev/clpmfile` contains the Slynk dependency.
- **VS Code with Alive** — a workable alternative.

## Clone and install

```sh
git clone --recurse-submodules https://github.com/fkr-0/elmtui.git
cd elmtui
clpm bundle install
```

The `--recurse-submodules` flag is required. The four `cl-events`,
`cl-inputs`, `cl-state`, and `cl-styles` libraries are Git submodules
pinned to specific commits. Without them, ASDF cannot find the support
systems.

If you already cloned without submodules:

```sh
git submodule update --init --recursive
clpm bundle install
```

## Load ElmTUI

Run all commands from the repository root so CLPM's bundle context is
active:

```sh
clpm bundle exec --with-client sbcl -- --noinform \
  --eval '(require :asdf)' \
  --eval '(asdf:load-system "elmtui")'
```

## Run examples

```sh
scripts/examples.sh list
scripts/examples.sh run neon-tetris
scripts/examples.sh run repl
```

From a Lisp REPL:

```lisp
(asdf:load-system "elmtui-examples")
(elmtui.examples.minimal:run-minimal)
```

See [examples/README.md](../../examples/README.md) for the full catalog
and entry points.

## Run tests

Root integration suite:

```sh
clpm bundle exec --with-client sbcl -- \
  --noinform --load scripts/run-tests-clpm.lisp
```

Every reusable subsystem independently:

```sh
scripts/test-subsystems.sh
```

Complete release gate:

```sh
scripts/release-check.sh
```

## Development with SLY

SLY/Slynk is kept in a separate `dev/clpmfile` so the main lock contains
no editor-server packages. Install it with:

```sh
cd dev && clpm bundle install && cd ..
```

Then start SBCL with the development bundle and connect SLY.

## Troubleshooting

- **System not found** — make sure you cloned with `--recurse-submodules`
  and ran `clpm bundle install`.
- **Dependency missing** — run `clpm bundle install` again. Check that
  `clpmfile.lock` is present.
- **Submodule empty** — run `git submodule update --init --recursive`.

See [troubleshooting.md](./troubleshooting.md) for more.
