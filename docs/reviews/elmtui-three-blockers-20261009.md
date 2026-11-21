# ElmTUI: three release blockers — implementation evidence (2026-10-09)

**Implementation revision:** `59bd09a9` (source commits below). These are local commits only. Independent approval, publication and tags remain separate requirements.

## 1. Tmux slider

- Commit `609f20ba` adds `examples/tmux-slider.lisp` and real isolated tmux/PT​Y verification.
- A captured styled tmux pane is treated as an immutable cell/glyph snapshot.
- The animation colors a moving eight-column band **in the existing pane**, saves/restores the cursor, and restores original glyphs and SGR styles on completion or quit.
- No alternate-screen switch, terminal clear, scrollback write or blank output fallback is used.
- Correctly re-encodes parsed 256-color and RGB style values on restoration.
- `python3 tests/e2e/example-overhaul-tmux-slider.py -v`: **5 passed**, including early-exit original history, style/70-marker restoration, paused zero writes, finite-frame cleanup, no-tmux fail-safe.
- `python3 tests/e2e/example-overhaul-tmux-slider-unit.py`: **1 passed**.

## 2. Dependency oracle

- Commit `80553588` adds `tests/workbench/validation/dependency_oracle.py` with positive/negative tests, and wires it into the canonical W6 runner.
- The independent subprocess runs `scripts/test-subsystems.sh` and executes each library's real ASDF test operation: `cl-events`, `cl-inputs`, `cl-state`, and `cl-styles`.
- Rejects a missing library run, zero checks, nonzero FiveAM failures or nonzero subprocess exit. One library may have multiple FiveAM suite summaries.
- `python3 -m unittest discover -s tests/workbench/validation -p test_dependency_oracle.py -v`: **5 passed**.
- `python3 tests/workbench/validation/runner.py`: **exit 0**, **30/30 application cases passed**, `dependency_oracle passed exit=0`. Evidence at `tests/workbench/validation/artifacts/run-fc6dea7a7c/result.json` (generated, ignored).
- An independent reviewer must still evaluate the evidence; passing the script does not self-approve a release.

## 3. API documentation coverage

- Commit `59bd09a9` adds `src/core/public-api-docstrings.lisp`, loaded by `elmtui.asd` after runtime symbol definitions.
- Attaches **231 additional** human-readable Common Lisp DOCUMENTATION strings to exported event, async, backend, keymap, UI and style bindings. Existing docstrings are not overwritten.
- Regenerated and committed `docs/api/generated/api.md` and `api.html`.
- `scripts/check-docstrings.sh`: **PASS**, 1,819 unique bindings, 639 undocumented, coverage **64.9%**; maintained non-strict debt threshold **782** was not relaxed.
- `python3 scripts/qualify-api-reference.py --structure-only`: **PASS**, 1,822 live exported API entries, 1,183 documented, 639 missing, Markdown/HTML structural parity.
- `python3 scripts/prepare-site.py` and `mkdocs build --strict`: **PASS**.
- **Scope distinction:** the non-strict release debt gate is now closed, **but 639 exported bindings still lack documentation**. Full 100% docstring coverage is not claimed. Strict zero-missing coverage remains an open quality enhancement.

## Repository-wide qualification caveat

A contemporaneous full root FiveAM run reached **4,704 passes, 6 opt-in skips, 1 failure** in `DRIVER-RESTORE-SAVED-CAPTURE-APPLIES-DIFF` because the restored buffer cell remained `#\\A` rather than `#\\B`. That test concerns ongoing **concurrently claimed** edits to `src/platform/driver.lisp` and `src/platform/tmux-capture.lisp` by other workers. This pass did not overwrite or commit those active edits. Do not describe the *entire* shared checkout as release-qualified until that regression is resolved and the suite is rerun.

Untracked historical artifacts remain untouched. No remote push, tag, publish or deployment was performed.
