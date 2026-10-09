# API and documentation

ElmTUI publishes its API definitions in the source and can generate Markdown/HTML reference material from live Common Lisp documentation strings.

## Browse the generated reference

**[Complete exported-symbol API reference](guide/generated-api.md)** — every
live public binding in ElmTUI and the four supporting libraries. Qualified names
use a public, single-colon package export, with missing documentation explicitly
marked rather than silently omitted.

**Current audited coverage: 952/1,822 (52.3%).** The reference has passed the
structural live-export and Markdown/HTML equivalence checks; the release-grade
docstring coverage gate still fails (870 public bindings lack documentation,
versus the existing allowed debt of 782).

## Generate and qualify the reference from the source tree

```sh
clpm bundle install
scripts/build-api-docs.sh
python3 scripts/qualify-api-reference.py --structure-only
scripts/check-docstrings.sh
```

The generator writes `docs/api/generated/api.md` and `docs/api/generated/api.html`. When available at site-build time the Markdown output is copied into the built website under `guide/generated-api.md`.

For conceptual usage see [TEA foundations](guide/foundations.md), [widgets and patterns](guide/widgets.md) and the [application tutorial](guide/tutorial.md). For implementation-specific symbols, the most authoritative source is the checked-in code and its exported public packages.

!!! note "Documentation debt"
    The reference is structurally qualified but not coverage-qualified. The existing docstring ratchet rejects 870 missing descriptions against a limit of 782; do not relax or bypass this gate merely to publish. The fully strict verifier (without --structure-only) also fails until all public bindings have documentation.
