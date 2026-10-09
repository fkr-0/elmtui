# ElmTUI 0.2.0 — release qualification checklist

**State:** NOT RELEASE-APPROVED. Evidence checked 2026-10-09 in the live, shared ElmTUI checkout; no tag/push/publication authorized. Retained filename `release-0.1.0-checklist.md` for link compatibility.

## Verified local checks

- [x] Main `elmtui.asd` and `elmtui-examples.asd` identify version **0.2.0**; the local `v0.2.0` tag already exists. The separate `elmtui-workbench.asd` declares **0.1.0**.
- [x] Full root FiveAM run via `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load run-tests-clpm.lisp`: **4,743 passed / 6 intentionally skipped / 0 failed** (2026-10-09). All six skips require explicitly enabled live tmux integration. Re-run at release commit.
- [x] `scripts/check-docstrings.sh`: non-regression gate passed; **1,819 unique exported bindings, 637 missing, 65.0% documented**. This is a ratchet pass, **not** complete public API documentation.
- [x] README `defapplication` declaration and the standalone counter/async tutorial definitions smoke-loaded using the repository CLPM/SBCL bundle. This does not establish PTY/UI e2e.
- [x] Site source layout and `mkdocs.yml` are present. This is source readiness only, **not** a successful site build.

## Remaining mandatory release blockers

- [ ] **Version/tag policy.** A `v0.2.0` tag exists locally; do not force-move it. Decide whether this work qualifies as an existing 0.2.0 release fix or needs a new version/tag. Reconcile the separately versioned Workbench and freeze exact SHA/submodule dependencies.
- [ ] **License/provenance and assets.** MIT is stated in root and subsystem metadata; independently finish predecessor/authorship, third-party dependencies, bundled images/fonts, screenshots, NOTICE and security/secret-history review before public publication. Historical GPL grants are not retroactively relicensed.
- [ ] **Clean public checkout.** Independently verify public visibility of ElmTUI and `cl-events`, `cl-inputs`, `cl-state`, `cl-styles`; confirm each pinned submodule commit is public and a fresh `git clone --recurse-submodules` loads and tests. Shared checkout changes/untracked files must not enter a release by accident.
- [ ] **Workbench real PTY.** Recorded 2026-10-09 W5 failures included no startup frame in 80×24, 120×40 and 160×50 sessions. Obtain independent passing startup/evaluation/completion/docs/inspector/resize/input/interrupt/EOF/termios and normal-screen scrollback/cleanup evidence. **Never substitute alternate-screen mode** for the required normal-screen behavior.
- [ ] **Maintained examples.** Complete current cursor inspector/hover/slider, rainbow, Pong, Wi-Fi, key-tester and other example regressions with genuine PTY/tmux, resize, no-idle-write and exit/scrollback checks. A green root FiveAM run does not waive these.
- [ ] **Site strict build and review.** `python3 -m mkdocs build --strict` is **unavailable locally** (No module named `mkdocs`). Provision MkDocs Material, run `python3 scripts/prepare-site.py` then strict build, check navigation/links, mobile/contrast and content curation. Verify hosted Pages deployment/HTTPS, not merely the YAML workflow.
- [ ] **CI and packaging.** Verify actual GitHub Actions `ci.yml` and `pages.yml` runs from a clean commit. Complete independent support-library suites, Workbench PTY and packager smoke; collect warnings, skips, logs, dependency SHA and release artifact checksums.
- [ ] **Release assets.** Produce and review `website/assets/workbench-hero.webp`, `website/assets/terminal-slider.gif`, curated examples screenshots, alt text and privacy/attribution review. Asset filenames alone do not satisfy the gate.
- [ ] **Publication approval.** Review release notes, recursive-clone instructions, source provenance, test matrix and artifacts; create no new annotated tag or GitHub release before approval.

## Documentation qualification

- [x] Three longform chapters exist, use `:text :content` in live view examples, and distinguish `deftea-app` direct replacement from default transactional `defapplication`. Runnable declarations and selected test/effect forms were checked against the current exports.
- [ ] Re-run the complete docs smoke against the frozen release revision with unchanged dependencies, including illustrative examples that require adapters/fixtures, plus a real terminal smoke. Explanatory `...` source excerpts and intentionally bad patterns are **not** standalone executable programs.
- [ ] Grow docstring coverage beyond the current 65.0% ratchet and regenerate the public API reference (`scripts/build-api-docs.sh`); review exported widget contracts, focus/keymap behavior and edge cases. Concurrent documentation agents may change this baseline.
- [ ] Validate website, Workbench screenshots and PDF-independent MkDocs output in the actual publish environment.

## Reproduction

    clpm bundle install
    clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load run-tests-clpm.lisp
    scripts/test-subsystems.sh
    scripts/check-docstrings.sh
    scripts/build-api-docs.sh
    python3 scripts/prepare-site.py
    python3 -m mkdocs build --strict
    python3 tests/workbench/pty-workbench.py
    python3 -m unittest discover -s tests/workbench/independent -p 'test_*.py' -v

**Do not equate a clean local unit suite with public release readiness.** Keep evidence tied to the exact eventual release commit and submodule SHAs.
