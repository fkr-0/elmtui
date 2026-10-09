# API and documentation

ElmTUI publishes its API definitions in the source and can generate Markdown/HTML reference material from live Common Lisp documentation strings.

## Generate reference from the source tree

```sh
clpm bundle install
scripts/build-api-docs.sh
scripts/check-docstrings.sh
```

The generator writes `docs/api/generated/api.md` and `docs/api/generated/api.html`. When available at site-build time the Markdown output is copied into the built website under `guide/generated-api.md`.

For conceptual usage see [TEA foundations](guide/foundations.md), [widgets and patterns](guide/widgets.md) and the [application tutorial](guide/tutorial.md). For implementation-specific symbols, the most authoritative source is the checked-in code and its exported public packages.

!!! note "Documentation debt"
    The existing docstring check enforces a debt ratchet, not complete public API documentation. Closing missing public docstrings and producing a browsable, tested API reference are pre-release work.
