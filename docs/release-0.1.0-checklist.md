# ElmTUI 0.2.0 — release qualification checklist

**State:** NOT RELEASE-APPROVED. Evidence checked 2026-10-09 in the live, shared ElmTUI checkout; no tag/push/publication authorized. Retained filename `release-0.1.0-checklist.md` for link compatibility.

## Verified local checks

- [x] Main `elmtui.asd` and `elmtui-examples.asd` identify version **0.2.0**; the local `v0.2.0` tag already exists. The separate `elmtui-workbench.asd` declares **0.1.0**.
- [x] Root FiveAM was re-run **inside a private live tmux session** using `ELMTUI_RUN_TMUX_INTEGRATION=1 clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load run-tests-clpm.lisp`: **8,060 passed / 0 skipped / 0 failed** (2026-10-09). The previous non-tmux baseline was **4,743 passed / 6 skipped / 0 failed**. Test success does **not** waive compiler warning-clean or final frozen-commit checks.
- [x] `scripts/check-docstrings.sh`: non-regression gate passed; **1,819 unique exported bindings, 587 missing, 67.7% documented**. This is a ratchet pass, **not** complete public API documentation.
- [x] README `defapplication` declaration and the standalone counter/async tutorial definitions smoke-loaded using the repository CLPM/SBCL bundle. This does not establish PTY/UI e2e.
- [x] **Strict local site build passed** using an isolated `git archive HEAD` staging tree, `python3 scripts/prepare-site.py`, and `uv run --no-project --with 'mkdocs-material>=9.5,<10' python -m mkdocs build --strict`; exit 0, 63 generated files. MkDocs is still absent from the system Python; no permanent dependency installation was needed. Build success does **not** qualify remote Pages deployment.
- [x] Four subsystem suites passed independently via `scripts/test-subsystems.sh`, including the Workbench matrix dependency oracle (zero failures).
- [x] `scripts/test-terminal-apps.py` passed **9/9 cases in private tmux**, and independently **9/9 cases under urxvt/Xvfb**, covering minimal/focus/keymap/scroll navigation, Game of Life, and Wi-Fi keyboard/menu interactions. `scripts/test-startup-output.py -q` passed 2/2. Artifacts: `test-output/terminal-e2e-23053526` (tmux) and `test-output/terminal-e2e-d15bfb27` (urxvt).
- [x] Workbench current private PTY smoke passed at **80x24, 120x40 and 160x50** with no alternate-screen transitions. `tests/workbench/validation/runner.py` passed **30/30 application cases** including literal multiline bracketed paste (evidence: `tests/workbench/validation/artifacts/run-c32d70c30e/result.json`, HEAD `7797e831`). Independent review is still required.
- [x] Regenerated `docs/api/generated/api.md` and `api.html` under CLPM/SBCL; `python3 scripts/qualify-api-reference.py --structure-only` passed (**1,822 reference entries; 1,235 documented, 587 missing; 67.8% per-entry coverage**). Four reference qualifier regression tests passed. This per-entry denominator differs from the 1,819 unique-binding docstring ratchet.

## Remaining mandatory release blockers

- [ ] **Version/tag policy.** A `v0.2.0` tag exists locally; do not force-move it. Decide whether this work qualifies as an existing 0.2.0 release fix or needs a new version/tag. Reconcile the separately versioned Workbench and freeze exact SHA/submodule dependencies.
- [ ] **License/provenance and assets.** MIT is stated in root and subsystem metadata; independently finish predecessor/authorship, third-party dependencies, bundled images/fonts, screenshots, NOTICE and security/secret-history review before public publication. Historical GPL grants are not retroactively relicensed.
- [ ] **Clean public checkout — BLOCKED BY UNPUBLISHED SUBMODULE COMMITS.** GitHub reports ElmTUI and all four `cl-*` repositories as public. The pinned `cl-events` (`d4399c08`) and `cl-styles` (`0ca5efcc`) commits exist remotely, but GitHub's commit lookup returns 422 for pinned `cl-inputs` `ea45ee1b6a4359380c7112743149bedb33c637e0` and `cl-state` `f95baab3be20d3161bbe193766737880d9a00672`. Their local main branches are respectively 2 and 8 commits ahead of local `origin/main` projections. Publish/reconcile these commits through their authorized release owners before a fresh public recursive clone can pass; do not substitute arbitrary earlier SHAs.
- [ ] **Workbench independent approval and terminal coverage.** Earlier W5 startup failures are superseded by the **passing 3-size PTY smoke and 30/30 live matrix on 2026-10-09**. Obtain independent reviewer sign-off and separate tmux/real-terminal scrollback and resize coverage for the frozen release commit. Three optional independent tests remain skipped without `ELMTUI_WORKBENCH_TEST_CMD`; they do not negate the separately executed PTY matrix. **Never use alternate-screen mode** as a substitute.
- [ ] **Maintained examples — PARTIAL; mini editor FAILS.** The general application harness passes **9/9 private tmux** and **9/9 urxvt/Xvfb** cases (minimal, focus, keymap, scroll, Game of Life, Wi-Fi). However, `python3 scripts/test-mini-text-editor.py --timeout 20` fails **7/7** real-tmux editor cases: `Ctrl+S` save and Save As dialogs do not appear, while dirty `Ctrl+Q` can exit without unsaved-change confirmation. Evidence: `/tmp/mini-editor-e2e-e8_wkz2r`. Route to the editor/runtime owner; no source files were changed here. Cursor inspector/hover/slider, rainbow, Pong, key-tester and remaining no-idle-write/scrollback checks still need qualification.
- [ ] **Published Pages and visual review — BLOCKED.** The isolated **strict MkDocs build now passes**. DNS CNAME for `elmtui.fkr.dev` resolves to `fkr-0.github.io`, but `https://elmtui.fkr.dev/` returned **HTTP 404**; GitHub Pages reports `https_enforced=false`, and the Pages workflow had **no recorded runs** at this check. Stage the build in reviewed CI, deploy after the necessary permissions/approval, verify TLS, navigation, mobile width, contrast, media alt text and any warning about unlisted `assets/README.md`.
- [ ] **CI and warning-clean release gate — BLOCKED.** The most recent remote `ElmTUI verification` run (GitHub Actions run `37947086203`, commit `620c1431`) failed at `actions/checkout@v4`: **upload-pack: not our ref ea45ee1b…** in `cl-inputs`, before any tests could execute. The local `scripts/release-check.sh` passed topology, docstring ratchet, independent subproject bundles and four subsystem suites, but failed the **warning-clean** gate: SBCL warns in `tests/api-tests.lisp:40` that constant `:INVALID` conflicts with asserted type `LIST` in `validate-platform-options`; local FiveAM printed **8,043 passed, 6 skipped, 0 failed**, but this warning is a release failure, not a green gate. Fix/qualify that test in an authorized code task, re-run release-check, verify new clean CI and packaging smoke.
- [ ] **Release assets.** Produce and review `website/assets/workbench-hero.webp`, `website/assets/terminal-slider.gif`, curated examples screenshots, alt text and privacy/attribution review. Asset filenames alone do not satisfy the gate.
- [ ] **Publication approval.** Review release notes, recursive-clone instructions, source provenance, test matrix and artifacts; create no new annotated tag or GitHub release before approval.

## Documentation qualification

- [x] Three longform chapters exist, use `:text :content` in live view examples, and distinguish `deftea-app` direct replacement from default transactional `defapplication`. Runnable declarations and selected test/effect forms were checked against the current exports.
- [ ] Re-run the complete docs smoke against the frozen release revision with unchanged dependencies, including illustrative examples that require adapters/fixtures, plus a real terminal smoke. Explanatory `...` source excerpts and intentionally bad patterns are **not** standalone executable programs.
- [ ] Grow documentation beyond the current **67.7% unique-binding ratchet**. The generated reference was refreshed and passed the **1,822-entry structural qualifier** (67.8% per-entry coverage), but widget/focus/keymap semantics, packaged reproducibility, and clean-CI reference freshness still require independent qualification.
- [ ] Validate website, Workbench screenshots and PDF-independent MkDocs output in the actual publish environment.

## Reproduction

    clpm bundle install
    clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load run-tests-clpm.lisp
    scripts/test-subsystems.sh
    scripts/check-docstrings.sh
    scripts/build-api-docs.sh
    python3 scripts/prepare-site.py
    uv run --no-project --with 'mkdocs-material>=9.5,<10' python -m mkdocs build --strict
    python3 scripts/test-terminal-apps.py --terminal tmux
    python3 scripts/test-terminal-apps.py --terminal urxvt
    python3 scripts/test-mini-text-editor.py --timeout 20
    python3 tests/workbench/validation/runner.py
    python3 tests/workbench/pty-workbench.py
    python3 -m unittest discover -s tests/workbench/independent -p 'test_*.py' -v

**Do not equate a clean local unit suite with public release readiness.** Keep evidence tied to the exact eventual release commit and submodule SHAs.
