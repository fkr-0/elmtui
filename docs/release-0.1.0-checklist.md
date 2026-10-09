# ElmTUI 0.1.0 — release checklist and documentation audit

**State:** candidate preparation; NO release/tag approval. Audit date: 2026-10-09.

## P0 — release blockers

- [ ] **Version/history policy.** Current ASDF/README describe 0.2.0, and the local tagged release `v0.2.0` predates this planned 0.1.0. Do not overwrite that tag or silently renumber semver history. Decide whether 0.1.0 is a documented public-reset version or choose a higher version.
- [ ] **Licensing and provenance.** Root `LICENSE`, tracked unclaimed ASDF metadata, README and changelog have been migrated to MIT; `NOTICE.md` records the maintainer-owned predecessor `uncharming-tui` and historical GPL grants. The four supporting libraries have MIT license files. The concurrently claimed `elmtui-examples.asd` must also change its `:license` from GPL to MIT before release; check the optional Workbench ASDF metadata and any other newly authored systems. Verify third-party contributions and all public attribution before checking off this gate.
- [ ] **Workbench W5 PTY.** Recorded 2026-10-09 attempts failed to render a real startup frame at 80×24, 120×40 and 160×50. Fix and independently verify startup, real evaluation and output capture, completion above caret, delayed docs, inspector, resize, real key decoding, Ctrl+C/D and clean alternate-screen/termios restoration.
- [ ] **Example regressions.** Finish existing operator tasks for cursor inspector/tmux, rainbow styling, Pong height, Wi-Fi sizing/scrolling, key tester, connector, and all other maintained examples. PTY e2e is mandatory, especially scrollback clean exit and zero idle terminal writes.
- [ ] **Clean release unit.** Public GitHub repositories `fkr-0/cl-events`, `fkr-0/cl-inputs`, `fkr-0/cl-state`, `fkr-0/cl-styles` now exist and contain their currently pinned ElmTUI submodule HEAD commits on `main`. Untracked workbench and modified cl-inputs/cl-state submodules still cannot be silently omitted from a tagged release. Freeze exact commits of all five repositories after reconciling local standalone-vs-submodule histories; verify fresh public recursive clones.
- [ ] **Security/publication audit.** Review tracked source, history and screenshots for credentials/private paths. Confirm binaries and generated logs do not enter the published tree.

## P1 — accurate, extensive documentation

- [ ] Reconcile `README.org` version text, include the flagship Workbench and hero screenshot after asset delivery, provide a quickstart verified from a clean clone.
- [ ] Test all code snippets against release ASDF APIs. Specifically: `defapplication` versus `deftea-app` state semantics, exported package names, constructor arguments, file save promises, root viewport flags and subscriptions/effects.
- [ ] Publish TEA fundamentals; app lifecycle; effects/commands; state ownership; focus/keymaps; terminal input; styles; rendering/diff/idle; layouts/viewports; widget authoring; async testing; packaging; troubleshooting; Workbench.
- [ ] Inventory real exported widgets and documented contracts. `src/ui/widgets/` contains widgets, but supporting 'extensive widget library' requires an auditable list of stable widgets with examples and verification, not just files.
- [ ] Distinguish supported SBCL/POSIX terminals from hypothetical portable implementations; don't claim fully immutable states in transactional mode, universal modified-key support, enforced Ctrl+C preemption of arbitrary Lisp or Slynk as a mandatory dependency.
- [ ] Regenerate API reference via `scripts/build-api-docs.sh` and run `scripts/check-docstrings.sh`. The existing ratchet permits hundreds of missing descriptions; treat public API documentation as outstanding, not complete.
- [ ] Build curated site in strict mode, check navigation/crosslinks, contrast and mobile width, provide title/alt/captions. Do not publish internal review logs, patch payloads or draft designs as public docs by accident.

## P1 — CI, website and release

- [ ] Confirm GitHub Actions `ci.yml` passes clean SBCL/CLPM FiveAM, generated API docs and Workbench PTY. Add neon PTY, packaging smoke and platform matrix after bootstrap is proven.
- [ ] Confirm `pages.yml` builds with strict MkDocs and deploys from reviewed `main`. Protect `github-pages` environment and test content in a PR.
- [ ] Check DNS for `elmtui.fkr.dev`, set CNAME to the actual GitHub Pages hostname, configure the GitHub Pages custom domain and verify live HTTPS/TLS, not just DNS.
- [ ] Create visual assets: `website/assets/workbench-hero.webp` (dominant, wide image with completion/inspector); `website/assets/terminal-slider.gif` (small tasteful loop); screenshot gallery of Neon Pong/Tetris, widgets, editor.
- [ ] Produce release evidence: commits, dependency hashes, tests/skips, reference-generation results, screenshots privacy checks, license decision, artifact hashes, release notes, tested install instructions. Annotated tag only after sign-off.

## Evidence behind this plan

- Main HEAD initially: `edd02121922712335c9bed78892bc19d99fa7119`; local `v0.2.0` tag; initially no Git remote.
- `docs/workbench-stress-findings.md` reports **4473 pass, 6 intentional skips** in the root suite, but the **Workbench real terminal startup independently FAILED**. These are different evidence classes.
- `docs/workbench-user-guide.md` accurately warns of prototype limitations; `docs/repl-workbench-architecture.md` is a design baseline, not a verified feature record.
- `docs/longform/01…03` are the current long-form foundation; `examples/README.md` catalogues many example apps; generated API docs may be stale until built at a release commit.
- `website/` stages only curated public chapters and provides screenshot/GIF slots. Workbench imagery cannot substitute for passing independent PTY qualification.

## Verification commands

    python3 scripts/prepare-site.py
    python3 -m mkdocs build --strict
    clpm bundle install
    clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load run-tests-clpm.lisp
    python3 tests/workbench/pty-workbench.py
    python3 -m unittest discover -s tests/workbench/independent -p 'test_*.py' -v
    scripts/build-api-docs.sh
    scripts/check-docstrings.sh

The release is blocked if any mandatory gate fails. No tag or GitHub Release is authorized by this checklist.
