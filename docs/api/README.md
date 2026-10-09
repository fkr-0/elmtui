# ElmTUI 0.2.0 public API documentation

The authoritative API surface is the set of **runtime-exported Common Lisp
bindings**. The checked-in `generated/api.md` and `generated/api.html` are
generated from `DOCUMENTATION` metadata; they are not independent API
specifications. Do not manually edit generated entries.

## Refresh and verify

Run these commands from the ElmTUI repository root:

```sh
scripts/build-api-docs.sh
python3 -m unittest discover -s tests/reference -p 'test_*.py' -v
python3 scripts/qualify-api-reference.py --structure-only
scripts/check-docstrings.sh
git diff --exit-code -- docs/api/generated/api.md docs/api/generated/api.html
```

The structural qualifier compares the ordered Markdown and HTML entries with
actual exports loaded by SBCL. It detects invented names, stale output,
duplicate headings, incorrect kinds, and differing Markdown/HTML content.
Its **`--structure-only` mode does not require full docstring coverage**.
Without that flag it also rejects every undocumented entry.

The docstring audit counts **unique, exported, live bindings**, once even when
re-exported through facade packages. It considers a symbol documented when
*at least one* relevant binding kind (function/macro, variable, or type)
has a docstring: it does **not** prove that every applicable kind is documented
or that the text is semantically correct. The current default missing-count maximum is specified in
`scripts/check-docstrings.sh`; set `ELMTUI_DOCSTRING_MAX_MISSING` explicitly for
a tighter local ratchet. `ELMTUI_DOCSTRING_STRICT=1` requires zero missing entries.

At the initial 2026-10-09 documentation checkpoint, the root audit found
**1,819 unique bindings, 587 missing (67.7% documented)**. Later same-day
remediation passes may reduce the missing count; always rerun the audit before
reporting current coverage. The generated reference
reported **1,822 entries, 587 missing (67.8% documented)** under its
separate `elmtui-docs` load context. These denominators are not directly
interchangeable. The remaining 587 missing entries are genuine debt, not
an approved blanket allowlist.

## Source-verified API contracts

The following contracts were checked against source implementations during the
0.2.0 documentation remediation. These notes clarify cases where the generated
reference's individual accessor entries are terse.

### Terminal style model

Package: `ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING`
(file: `src/platform/backend/common/ansi-styling.lisp`).

* `MAKE-TERMINAL-COLOR` constructs a record of RGB channels, simple keyword
  color, optional 256-color index, and background flag; it does **not**
  normalize a color expression. `FUZZ-COLOR` is the conversion helper.
* `MAKE-TERMINAL-STYLE` constructs a mutable record of two colors and
  independently stored style flags. Color accessors return the underlying
  descriptors. `TERMINAL-STYLE-FG-COLOR-VAL` and
  `TERMINAL-STYLE-BG-COLOR-VAL` extract a raw RGB list, palette index,
  keyword, or `NIL`.
* `UPDATE-STYLE!` mutates an existing terminal-style and returns a list
  of changed `(keyword value)` pairs. A `NIL` destination creates a
  fresh style; a raw plist destination is *not* mutated (returns `NIL`).
* `ANSI-SEQS` emits SGR strings for requested style attributes. The
  `TERMINAL-STYLE` method respects requested order; the `NIL` method
  returns `NIL`, and the list-specialized method interprets explicit
  style entries. Unknown attribute keys can signal errors.
* `EXEC-SEQUENCE` accepts a lockable object, binary output stream, and
  a string, writes character codes as bytes while holding the lock,
  and flushes the stream. It does not transcode Unicode text to UTF-8.

### Typed pipeline trees and contract conditions

Package: `ELMTUI.CONTRACTS` (file: `src/contracts.lisp`).

* `MAKE-DSL-TREE`, `MAKE-RAW-TREE`, `MAKE-STYLED-TREE`,
  `MAKE-ATOMIC-TREE`, and `MAKE-LAID-OUT-TREE` are structure
  constructors for successive `:ROOT`-bearing pipeline stages; they do
  not execute those stages.
* `CONTRACT-VIOLATION` records function name, expected type, actual
  value and optional context. Its update, view, subscription and message
  specializations preserve these readers.
* `PIPELINE-CONTRACT-VIOLATION` records stage, expected type, offending
  object, and optional stack trace in its own condition family. The
  `VIOLATION-*` readers apply to this condition; the `CV-*` readers
  apply to `CONTRACT-VIOLATION`. Neither set of readers should be
  assumed interchangeable.

### Terminal instance snapshot

Package: `ELMTUI.PLATFORM.BACKEND.TERMINAL`
(file: `src/platform/backend/terminal/terminal.lisp`).

`TERMINAL-INSTANCE-WIDTH` and `TERMINAL-INSTANCE-HEIGHT` reflect
the instance's tracked dimensions (initially 80×24).
`TERMINAL-INSTANCE-CURSOR-ROW`, `-COL`, and
`-VISIBLE-P` return tracked state (initial row/column zero, cursor
visible). They are *not* independent terminal queries.

## Regression test expectations

`tests/api-tests.lisp` checks that all 50 specifically remediated public
bindings retain their documentation under the correct binding kind, including
one source-specific semantic fragment per binding. To run its suite separately:

```sh
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --eval '(asdf:load-system :elmtui-tests)' \
  --eval "(fiveam:run! 'elmtui-tests.api:api-suite)"
```

For the complete warning-clean integration suite run
`scripts/run-tests-warning-clean.sh`. This protects the improvement against accidental source/package
refactors. It is a focused compatibility test, not proof that all
1,822 generated entries have high-quality prose.

`tests/reference/test_qualifier.py` exercises failure cases for stale
names, duplicate headings, truncated/mismatched HTML, fake headings inside
literal documentation, and missing-documentation markers. The generated
reference and its qualifier are already part of hosted CI.

When editing support libraries, update docstrings in their **standalone**
source-of-truth repositories and then update ElmTUI's pinned submodule
revision through the proper release process; do not silently fork the
historical ElmTUI copy.
