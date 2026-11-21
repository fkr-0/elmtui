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
- [x] Root license identifier is `GPL-3.0-only`.
- [x] Reusable library license identifiers are `MIT`.
- [x] Placeholder author and maintainer values are removed.
- [x] The fake source-control URL is removed.
- [x] Root and reusable-library license texts are present.
- [x] `CHANGELOG.md` contains a `0.2.0` release section.
- [ ] Replace `Unreleased` with the publication date.
- [ ] Configure and verify the public Git remote.
- [ ] Add the final source-control/homepage metadata once the URL exists.

## Architecture

- [x] Every `cl-*` system can load and test without loading `elmtui`.
- [x] All four `cl-*` systems are independently versioned Git submodules.
- [ ] Qualify a clean recursive clone and source distribution containing all four pinned submodules.
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
- [ ] Manually run the minimal, focus, keymap, scroll-panel, and one animated
      example in a clean terminal.
- [ ] Manually verify shutdown restores cursor visibility and terminal mode.
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

The repository currently has no configured remote, so these remain manual:

- [ ] Choose and configure the canonical public repository URL.
- [ ] Push the reviewed release commit.
- [ ] Create an annotated `v0.2.0` tag.
- [ ] Sign the tag or release artifacts if signing is part of the project policy.
- [ ] Publish a source distribution bundling the exact Git-pinned submodule contents (plain `git archive` is insufficient).
- [ ] Verify the distribution contains all root and library ASDF files, CLPM metadata, and license texts.
- [ ] Test installation from the archive in a fresh ASDF/CLPM environment.
- [ ] Publish release notes derived from `CHANGELOG.md`.

## Post-release

- [ ] Add the final repository URL to ASDF metadata and README.
- [ ] Decide whether and when to submit systems to Quicklisp or another registry.
- [ ] Open portability work for non-SBCL implementations.
- [ ] Establish continuous integration on the public repository.
