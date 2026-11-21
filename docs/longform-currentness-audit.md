# ElmTUI long-form documentation currentness audit — 2026-10-09

## Scope and verdict

Reviewed the maintained three-chapter long-form sequence against current ElmTUI TEA application constructs, public text nodes, state semantics, runtime subscriptions, and the evolving Workbench integration.

**Status: usable and mostly aligned conceptually; not fully release-qualified.** The first six executable Common Lisp blocks in the hands-on counter tutorial were extracted in order and executed through CLPM/SBCL with the ElmTUI system loaded. They passed. This is a verified minimum, not a claim that every example or all public symbols have passed.

## Concrete corrections

- `docs/longform/02-core-principles-widgets-and-patterns.md`, counter View example: changed the text-node property from `:value` to `:content`. The actual text-element constructor exposes `:content` as a required property (see `src/view/base-elements.lisp`).
- `docs/longform/03-hands-on-counter-and-async.md`, counter View example: made the same `:value` → `:content` correction. Extracted and executed its first six Lisp examples through the actual `deftea-app` constructor.
- These chapters distinguish strict model replacement from transactional state and describe `defapplication` vs `deftea-app` consistently with the runtime API; the conceptual distinction is not a reason to rewrite them wholesale.
- The public Workbench guide is separately being edited and qualified by the active W5/W6 owners. Its feature claims must follow verified PTY results, not only a design specification.

## Outstanding work before publishing

1. Generate API docs from a clean released dependency vector; check that referenced exported symbols still exist, and avoid treating an existing docstring debt-ratchet as full documentation coverage.
2. Run every runnable Lisp sample in all three long-form chapters (including async command stubs and conditions/restarts), using isolated image tests where needed; distinguish complete programs from intentional fragments.
3. Add real terminal acceptance tests for layout, input, focus, Unicode display cells, resize, alternatescreen/scrollback and restoration, and the Workbench; there are still active fixes in these areas.
4. Reconcile `README.org` and ASDF metadata with the old `v0.2.0` tag and proposed public 0.1.0 version before release; do not rewrite historical tags.
5. Use the maintained example catalog rather than claiming every widget is stable; update the widget inventory from shipped exports and test results.
6. Refresh staged site copies with `python3 scripts/prepare-site.py` before each docs build, and verify a strict MkDocs build.

## Reproducible evidence

    python3 scripts/prepare-site.py
    python3 -m mkdocs build --strict

Tutorial smoke extraction (six initial Lisp snippets) followed by:

    clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(require :asdf)' --eval '(asdf:load-system "elmtui")' --load /tmp/elmtui-doc-counter-quickstart.lisp

Result observed: `DOC_COUNTER_LISP_PASS`, exit 0. Log4CL generics produced preexisting redefining warnings; this is not a warning-clean release attestation.

The Game of Life example was repaired separately with timer subscriptions, normalized keyboard input and a real PTY test. Its test can be run with:

    python3 tests/e2e/game-of-life-pty.py -v
