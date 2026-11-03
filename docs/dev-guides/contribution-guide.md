# Contributing to ElmTUI

Contributions are welcome — bug reports, documentation improvements, new
features, examples, and test coverage.

## Getting started

1. **Set up your environment.** Follow the [setup guide](./setup.md).
2. **Fork the repository** on
   [GitHub](https://github.com/fkr-0/elmtui).
3. **Create a branch** for your changes:
   ```sh
   git checkout -b feature/my-change
   ```
4. **Familiarise yourself with the architecture:**
   - [Foundations: Elm architecture in Common Lisp](../longform/01-foundations-and-elm-architecture.md)
   - [Library boundaries](../architecture/library-boundaries.md)
   - [API documentation and verification](../api/README.md)

## Making changes

### Code

- The four `cl-*` libraries are independent Git submodules. Changes to
  their source go to their own repositories; ElmTUI pins them to a
  specific commit.
- Prefer the framework's existing packages and conventions. The
  [library boundaries](../architecture/library-boundaries.md) doc
  explains which package owns what.
- Keep the distinction between reusable `cl-*` mechanics and ElmTUI UI
  policy in `src/`.

### Tests

- For bug fixes, add a test that reproduces the bug.
- For new features, write tests covering the new functionality.
- Ensure all tests pass before submitting.

Run the suites:

```sh
# Root integration suite
clpm bundle exec --with-client sbcl -- --noinform --load scripts/run-tests-clpm.lisp

# Integration suite with unexpected compiler/runtime warnings rejected
scripts/run-tests-warning-clean.sh

# Every reusable subsystem
scripts/test-subsystems.sh

# Complete release gate
scripts/release-check.sh
```

The release gate checks repository topology, the tracked release
manifest, whitespace, all four subsystem suites, the warning-clean full
ElmTUI suite, documentation freshness, and API binding coverage.

The non-interactive runner exits with the suite result. It routes `log4cl`
application logging to `test-output/elmtui-tests.log`; the warning-clean
wrapper retains stdout and stderr under `test-output/` for diagnosis.

Terminal integration checks use a private tmux server, so they do not depend
on or change an existing session. The simulated terminal checks in
`tests/faketerm-tests.lisp` use `faketerm-run-to-quiescence` to drain input
and wait for a stable screen; real terminal checks remain part of the
complete release gate.

### Documentation

- Docstrings are executable API metadata. Generated API references are
  derived from live `DOCUMENTATION` calls; do not maintain a second
  handwritten API source.
- Run `scripts/check-docstrings.sh` to verify documentation coverage
  does not regress.
- Run `scripts/build-api-docs.sh` to regenerate
  `docs/api/generated/api.md`.

### Examples

New examples should satisfy the [example contract](../../examples/README.md#example-contract):
listed in an ASDF system, compilable during tests, stable runner export,
no checked-in binaries, public APIs only.

## Submitting a pull request

1. Keep your branch up to date:
   ```sh
   git fetch origin
   git rebase origin/main
   ```
2. Push and open a PR against `main`.
3. Provide a clear description of the changes and link to related
   issues.
4. The CI runs `scripts/release-check.sh`; ensure it passes locally
   first.

## Code review

Maintainers review PRs for correctness, style, and adherence to the
project's architectural conventions. Address feedback and iterate.

## Reporting issues

File issues at
[github.com/fkr-0/elmtui/issues](https://github.com/fkr-0/elmtui/issues)
with steps to reproduce, expected vs. actual behavior, and environment
details (SBCL version, OS, terminal).
