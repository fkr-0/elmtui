# ElmTUI 0.3.0 release checklist

## 2026-10-27 E5 release gate (supersedes earlier readiness assertions)

The release is **on HOLD**. E5 now supplies scripts/release-matrix-test.py and an expanded scripts/release-check.sh. A complete release qualification requires a clean, frozen superproject + four dependency Git SHA vector, successful exact-public-pin fetches, a dependency-complete source archive, independently isolated CLPM install from that archive, and the full warning-clean/coverage/Workbench/Neon/PTy/docs matrix with path/exit receipts. Local helper smoke results against committed HEAD do not qualify active dirty E1–E4 changes.

- **RESOLVED (site aligned to 0.2.0):** the website previously announced 0.1.0 while ASDF, the changelog and the immutable local `v0.2.0` tag say 0.2.0. Confirm 0.2.0 is the intended version before publishing; the existing tag points at an older commit and must not be moved.
- **PARTLY RESOLVED (2026-10-31):** all four dependency `main` heads are pushed to their public GitHub remotes (`cl-events` `798cb3b`, `cl-inputs` `10c75b3a`, `cl-state` `91a29b7`, `cl-styles` `e4d64c5`) and the elmtui checkouts are on exactly those commits. Their canonical development repositories now live beside elmtui (`../cl-*`); the in-tree checkouts are plain submodule clones. **Still BLOCKED** until the root commit recording these gitlinks is reviewed, committed and pushed.
- **RESOLVED (2026-10-31):** CI executes the canonical `scripts/release-check.sh` (`release-matrix-test.py contract`: 0 failures). The matrix now also runs the normal-screen tmux contracts, the all-examples shutdown sweep and the packager-tool executable test.
- **PASS, narrow scope only:** 7 adversarial archive/contract tests; an immutable-Git-object archive including all dependency trees; a fresh XDG-isolated CLPM/SBCL load of that historical HEAD archive.
- **NO RELEASE:** no tag, push, deploy, or publication. See docs/reviews/final-release-gate-20261027.md for the exact SHA vector, probes, receipts and outstanding owners.

## Automated gate

Run from the repository root:

```sh
scripts/release-check.sh
```

The command must complete with exit status zero and prove:

- both staged and unstaged patches contain no whitespace errors;
- all four reusable systems are pinned, initialized Git submodules at their exact superproject gitlinks;
- root release-critical files are tracked and the four submodules are initialized at their pins (the gate does **not** yet produce or install a bundled source archive; a plain Git archive omits submodule contents, see Publication);
- both the release/test and optional development CLPM bundles contain no
  machine-specific absolute paths;
- `cl-events` passes independently;
- `cl-inputs` passes independently;
- `cl-state` passes independently;
- `cl-styles` passes independently;
- the full ElmTUI suite passes;
- compiler/runtime stderr contains no warning or undefined-symbol markers;
- generated API reference is current, the Python qualification guards pass (documentation staging, coverage gate/badge, API reference), and Neon passes;
- the documentation site builds with `mkdocs build --strict` after `scripts/prepare-site.py`;
- Workbench independent and real-PTY checks pass, measured primary coverage meets its floor, and the packaged executable starts in a real PTY;
- the root and all four dependency trees are clean both before and after the checks. A development checkout may set `ELMTUI_RELEASE_ALLOW_DIRTY=1` for a dry run; such a run is **not** a release qualification and its result must not be cited.

`.github/workflows/ci.yml` executes `scripts/release-check.sh` itself, so CI and a maintainer's local run share one definition of the matrix (`scripts/release-matrix-test.py contract` rejects drift). `pages.yml` still builds the site independently for deployment. The hosted run is unvalidated until the exact revision and its dependency pins are pushed: the `public_pins` gate is expected to fail until then.

The tmux capture integration tests are part of that gate, not an extra one: they
start and remove their own private tmux server, so they run identically inside
or outside tmux. They require the `tmux` binary and fail (never skip) without it.

## Metadata and licensing

- [x] Root ASDF version is `0.3.0`.
- [x] Current root ASDF metadata and `LICENSE` identify **MIT**; all four reusable libraries are also MIT. Historic GPL-3.0-only ElmTUI revisions keep their earlier grants. Source/provenance/third-party attribution review remains a separate publication gate.
- [x] Reusable library license identifiers are `MIT`.
- [x] Placeholder author and maintainer values are removed.
- [x] The fake source-control URL is removed.
- [x] Root and reusable-library license texts are present.
- [x] `CHANGELOG.md` contains a `0.3.0` release section.
- [ ] Replace `Unreleased` with the publication date.
- [x] Root `origin` points to the public `fkr-0/elmtui` GitHub repository.
- [ ] Verify final source-control/homepage metadata and every submodule gitlink from an independent public clone; pinned `cl-inputs` `ea45ee1b` and `cl-state` `f95baab3` are **not yet available** from their public upstreams.

## Architecture

- [x] Every `cl-*` system can load and test without loading `elmtui`.
- [x] All four `cl-*` systems are independently versioned Git submodules.
- [ ] Qualify a clean recursive clone and source distribution containing all four pinned submodules. **Blocked:** GitHub Actions run `37947086203` failed `actions/checkout@v4` with `upload-pack: not our ref ea45ee1b…` (`cl-inputs`); `cl-state` pin `f95baab3…` also does not resolve on public GitHub. Publish the exact reviewed commits through their release owners first.
- [x] The default examples and release tests do not require the optional sibling
      integration `cl-fzy`.
- [x] SLY/Slynk is isolated in `dev/clpmfile` and absent from the release/test
      dependency graph.
- [x] Generic path traversal is owned by `cl-state`.
- [x] Generic channels/filtering are owned by `cl-events`.
- [x] Terminal byte/key decoding is owned by `cl-inputs`.
- [x] Selector/cascade/property normalization is owned by `cl-styles`.
- [x] ElmTUI adapters are documented.
- [x] Orphaned duplicate event/topic compatibility implementations are removed.
- [ ] Review any newly added source file that is absent from an ASDF graph.

## Documentation and examples

- [x] README describes the actual supported platform.
- [x] README does not claim Quicklisp availability before publication.
- [x] Setup and test commands are executable from the repository root.
- [x] Maintained examples are catalogued in `examples/README.md`.
- [x] Architectural ownership is documented.
- [x] Nine representative maintained application scenarios passed under **private tmux (9/9)** and **urxvt/Xvfb (9/9)**: minimal, focus, keymap, scroll, Game of Life, Wi-Fi.
- [ ] Complete hover/slider/cursor inspector and remaining example testing (the Game of Life pause/step/reset/resume sweep case now asserts the rendered `◉ PAUSED` / `GEN 0000` format and passes under tmux), normal-screen scrollback/no-idle-write/shutdown checks. **Mini text editor now passes 7/7 real-tmux cases** (2026-10-27; the earlier Ctrl+S / dirty Ctrl+Q failures no longer reproduce). The two former P0 physical-terminal contracts now **pass as ordinary release gates** (2026-10-31): B2 paints the actual pane coordinates, and history survives 120x40 to 80x24 and the reverse with exact SGR (see `docs/tmux-normal-screen-contract.md`; unit regressions in `tests/normal-screen-overlay-tests.lisp`). **Never use alternate-screen mode.**
- [x] Workbench genuine CLPM/SBCL PTY smoke passed in **80x24 / 120x40 / 160x50**, and 30/30 independent live Workbench validation scenarios passed, including bracketed multiline paste. Independent review and example-specific terminal qualification are still open.
- [x] Historical (2026-10-09, when tmux integration was an opt-in via the since-removed `ELMTUI_RUN_TMUX_INTEGRATION=1`; it now always runs against a private server): tmux integration was exercised **inside a real private tmux session**: **8,060 checks passed, zero skipped or failed** (2026-10-09). The compiler-warning cleanliness gate still fails.
- [x] Shutdown restores cursor visibility, normal-screen scrollback, and terminal mode for **all maintained examples** — automated real-tmux sweep `tests/e2e/all-examples-shutdown-restoration.py` over every `scripts/examples.sh list` entry (2026-10-31; excluded with reasons: `repl`, covered by Workbench PTY; `fzy-picker`, needs optional `cl-fzy`). The sweep found and fixed two defects: `tmux-hover-demo` failed to load through the launcher, and `wifi-inline` blanked one history row when launched on the last pane row.
- [x] The packager produces and starts a clean executable — `tests/e2e/packager-executable.py` builds `elmtui-packager`, dumps the minimal example, runs it from an empty directory without CLPM/ASDF environment, and checks quit, stty, cursor and history (2026-10-31).

## Repository hygiene

- [x] Release-critical untracked files are covered by the automated manifest gate.
- [ ] Review `git status` and exclude unrelated local/debug artifacts from the
      release commit.
- [ ] Ensure no generated executable, FASL, log, coverage, cache, archive, or
      editor backup is committed.
- [ ] Confirm all deleted source files are absent from documentation indexes or
      mark historical indexes as archived.
- [ ] Create the release from a clean checkout, not the development workspace.

## Publication

The public `origin` is already configured at `git@github.com:fkr-0/elmtui.git`. The repository's current remote `main` is older than the local documentation qualification, and the pinned submodule commit vector is not fully available remotely. Publication is **not approved**.

- [x] Configure the canonical public repository URL (`fkr-0/elmtui`).
- [ ] Push the reviewed release commit.
- [ ] Establish next-version/tag policy: an annotated `v0.2.0` already exists locally; **do not recreate or force-move** it. Qualify the eventual immutable release SHA.
- [ ] Sign the tag or release artifacts if signing is part of the project policy.
- [ ] Publish a source distribution bundling the exact Git-pinned submodule contents (plain `git archive` is insufficient).
- [ ] Verify the distribution contains all root and library ASDF files, CLPM metadata, and license texts.
- [ ] Test installation from the archive in a fresh ASDF/CLPM environment.
- [ ] Publish release notes derived from `CHANGELOG.md`.

## Post-release

- [ ] Add the final repository URL to ASDF metadata and README.
- [ ] Decide whether and when to submit systems to Quicklisp or another registry.
- [ ] Open portability work for non-SBCL implementations.
- [x] GitHub CI (`.github/workflows/ci.yml`) and Pages (`.github/workflows/pages.yml`) definitions exist on the public repository.
- [ ] Obtain a **green** CI checkout and release matrix after publishing exact submodule pins; previous CI run `37947086203` failed before tests. The warning-cleanliness failure previously recorded here (`tests/api-tests.lisp:40`) is superseded by the 2026-10-26 reviews; confirm it from the final-revision run rather than from this note.
- [ ] Qualify GitHub Pages delivery: isolated **strict MkDocs Material build passed** (63 output files), but `https://elmtui.fkr.dev/` returned HTTP 404 and no Pages workflow runs were recorded. Verify HTTPS enforcement and deployed assets independently.
