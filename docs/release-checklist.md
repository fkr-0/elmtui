# ElmTUI 0.2.0 release checklist

## Automated gate

Run from the repository root:

```sh
scripts/release-check.sh
```

The command must complete with exit status zero and prove:

- both staged and unstaged patches contain no whitespace errors;
- all four reusable systems are pinned, initialized Git submodules at their exact superproject gitlinks;
- root release-critical files are tracked, and submodule contents are bundled explicitly (a plain Git archive omits submodule contents);
- both the release/test and optional development CLPM bundles contain no
  machine-specific absolute paths;
- `cl-events` passes independently;
- `cl-inputs` passes independently;
- `cl-state` passes independently;
- `cl-styles` passes independently;
- the full ElmTUI suite passes;
- compiler/runtime stderr contains no warning or undefined-symbol markers.

Live tmux tests are an additional environment-specific gate:

```sh
ELMTUI_RUN_TMUX_INTEGRATION=1 scripts/release-check.sh
```

Run that command from inside a tmux session.

## Metadata and licensing

- [x] Root ASDF version is `0.2.0`.
- [x] Current root ASDF metadata and `LICENSE` identify **MIT**; all four reusable libraries are also MIT. Historic GPL-3.0-only ElmTUI revisions keep their earlier grants. Source/provenance/third-party attribution review remains a separate publication gate.
- [x] Reusable library license identifiers are `MIT`.
- [x] Placeholder author and maintainer values are removed.
- [x] The fake source-control URL is removed.
- [x] Root and reusable-library license texts are present.
- [x] `CHANGELOG.md` contains a `0.2.0` release section.
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
- [ ] Complete hover/slider/cursor inspector and remaining example testing, normal-screen scrollback/no-idle-write/shutdown checks. **Mini text editor remains RED: 7/7 real-tmux cases failed** (Ctrl+S save/Save As and dirty Ctrl+Q confirmation failures; evidence `/tmp/mini-editor-e2e-e8_wkz2r`). **Never use alternate-screen mode.**
- [x] Workbench genuine CLPM/SBCL PTY smoke passed in **80x24 / 120x40 / 160x50**, and 30/30 independent live Workbench validation scenarios passed, including bracketed multiline paste. Independent review and example-specific terminal qualification are still open.
- [x] Optional tmux integration was exercised **inside a real private tmux session** using `ELMTUI_RUN_TMUX_INTEGRATION=1`: **8,060 checks passed, zero skipped or failed** (2026-10-09). The compiler-warning cleanliness gate still fails.
- [ ] Manually verify shutdown restores cursor visibility, normal-screen scrollback, and terminal mode for **all maintained examples**, not only Workbench.
- [ ] Manually verify the packager produces and starts a clean executable.

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
- [ ] Obtain a **green** CI checkout and release matrix after publishing exact submodule pins; previous CI run `37947086203` failed before tests. Local `scripts/release-check.sh` currently fails only at warning cleanliness: `tests/api-tests.lisp:40` causes an SBCL type-related compiler warning despite zero failed FiveAM tests.
- [ ] Qualify GitHub Pages delivery: isolated **strict MkDocs Material build passed** (63 output files), but `https://elmtui.fkr.dev/` returned HTTP 404 and no Pages workflow runs were recorded. Verify HTTPS enforcement and deployed assets independently.
