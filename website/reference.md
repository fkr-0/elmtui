# API and documentation

ElmTUI publishes its API definitions in the source and can generate Markdown/HTML reference material from live Common Lisp documentation strings.

## Browse the generated reference

**[Complete exported-symbol API reference](guide/generated-api.md)** — every
live public binding owned by ElmTUI and its supporting libraries CL-EVENTS,
CL-STATE, CL-INPUTS, and CL-STYLES. Qualified names use a public, single-colon
package export, with missing documentation explicitly marked rather than
silently omitted.

**Current audited coverage: 1,643/1,822 (90.2%).** The reference has passed the
structural live-export and Markdown/HTML equivalence checks; 179 public bindings
lack documentation. The current ratchet threshold is set in
`scripts/check-docstrings.sh`, and subsequent documentation passes may further
reduce the debt. Passing this gate does not mean the API is fully documented.
For source-verified contracts and audit interpretation, consult
`docs/api/README.md` in the source repository.

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
    The reference is structurally qualified, but not fully documented. The
    debt ratchet passes at the documented checkpoint; check the audit's current
    output and configured threshold after further remediation. Do not relax or
    bypass this gate merely to publish.
    The strict verifier (without --structure-only) still fails until all
    public bindings have documentation metadata.
