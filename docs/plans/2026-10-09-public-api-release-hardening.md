# Public API and Examples Release Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the shipped public API reference and usage guidance accurate, and verify maintained examples through repeatable smoke and terminal end-to-end coverage.

**Architecture:** Keep live package exports as the source of truth. Strengthen the existing API reference qualifier instead of adding a parallel inventory, and keep example metadata aligned with `elmtui-examples.asd`, `examples/README.md`, and the smoke/PTY harnesses. Use the fake backend or private terminal harness for checks; gate real tmux/network integrations.

**Tech Stack:** Common Lisp (SBCL/ASDF/CLPM), FiveAM, Python `unittest`, private tmux/PTY harnesses, Markdown docs.

---

## File map

- `docs/api/generator.lisp`, `scripts/build-api-docs.sh`, and `scripts/qualify-api-reference.py` define and validate the generated API reference.
- `docs/api/generated/api.md`, `docs/api/generated/api.html`, and `website/reference.md` are checked-in API documentation outputs and landing-page claims.
- `src/api.lisp`, relevant `src/**/api.lisp` package definitions, and `tests/api-tests.lisp` define and test ElmTUI's API-facing package contracts.
- `docs/USER_GUIDE.md`, `docs/architecture/api-organization.md`, and `examples/README.md` describe current public usage and example entry points.
- `elmtui-examples.asd`, `tests/examples-smoke-tests.lisp`, `tests/e2e/extended-examples-pty.py`, and `scripts/test-terminal-apps.py` define the maintained example graph and its automated coverage.
- `elmtui-tests.asd` and `scripts/release-check.sh` connect the focused checks to the release gate.

### Task 1: Reconcile generated API reference and published coverage

**Files:**
- Modify: `scripts/qualify-api-reference.py`
- Modify: `website/reference.md`
- Regenerate: `docs/api/generated/api.md`, `docs/api/generated/api.html`
- Test: `tests/reference/test_qualifier.py`

- [ ] **Step 1: Run the current live-reference check**

Run: `python3 scripts/qualify-api-reference.py --structure-only`

Expected: `REFERENCE-STRUCTURE-PASS` reports the live entry count, documentation count, and missing count. Record those values; compare them with `website/reference.md`.

- [ ] **Step 2: Make the landing-page count part of qualification**

Add a unit test in `tests/reference/test_qualifier.py` that patches live entries and rejects a stale coverage statement, then update `qualify()` to compare the current live `documented`, `missing`, and `total` values with the coverage statement in `website/reference.md`. The check must retain the current generated Markdown/HTML identity, export, and cross-format checks.

- [ ] **Step 3: Regenerate and synchronize the reference**

Run: `scripts/build-api-docs.sh`

Update `website/reference.md` to report the regenerated counts and describe the release gate accurately. Keep support-library ownership explicit; do not narrow the generated reference silently.

- [ ] **Step 4: Verify the reference gate**

Run: `python3 tests/reference/test_qualifier.py`

Expected: the stale-coverage regression fails before the implementation and passes afterward. Once the pinned submodule systems are available, run `python3 scripts/qualify-api-reference.py --structure-only`; it must report counts matching the landing page. Run `scripts/check-docstrings.sh`; it must pass without increasing its allowed missing-docstring limit.

### Task 2: Repair stale consumer-facing API guidance and cover export visibility

**Files:**
- Modify: `docs/USER_GUIDE.md`
- Modify: `docs/architecture/api-organization.md`
- Modify: `src/app/api.lisp`
- Modify: `src/platform/driver.lisp`
- Modify: `tests/application-extension-tests.lisp`
- Modify: `exe` only if needed to stop advertising a removed examples system.

- [ ] **Step 1: Add a failing test for current driver options**

In `tests/application-extension-tests.lisp`, add a test that passes the options the live driver actually consumes—`:prefill-from-tmux`, `:tmux-prefill-mode`, `:use-alternate-screen`, and `:signal-keys-as-input`—to `elmtui.app.api:validate-platform-options` and expects acceptance. Add cases that reject the obsolete ignored `:timeout` option, malformed odd-length plists, non-boolean flags, and tmux modes other than `:pane`/`:screen`. The runtime validator currently recognizes a stale option set and has no call site.

- [ ] **Step 2: Verify the new validator test fails for the expected reason**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:load-system :elmtui-tests)' --eval '(5am:run! (quote elmtui.tests.application-extension::application-extension-tests))'`

Expected: fail because the currently documented validator rejects real runtime options and/or accepts malformed values.

- [ ] **Step 3: Fix and wire the runtime validator**

Update the whitelist and value checks in `src/app/api.lisp` to match only the documented, currently consumed platform options. Reject improper/odd property lists. Call the validator at the start of `run-app-platform` in `src/platform/driver.lisp`, before it resets globals, starts threads, or initializes a backend. Do not change the application update/view contracts or silently pass ignored options.

- [ ] **Step 4: Run focused validator tests**

Run the focused FiveAM command from Step 2. Expected: validator accepts all four valid runtime options and rejects unsupported keys, malformed plists, invalid booleans, and invalid tmux modes before driver side effects.

- [ ] **Step 5: Correct stale public usage and architecture guidance**

Compare every ASDF system, package, command, and example runner in `docs/USER_GUIDE.md` with `elmtui.asd`, `elmtui-examples.asd`, `elmtui-examples-fzy.asd`, `examples/README.md`, and actual source exports. Replace `:elmtui/examples` with `:elmtui-examples`; remove the removed `:elmtui/examples-legacy` system and legacy discovery command; point users at `./examples.sh list` / `run`. Describe view functions as receiving the model (the generated wrapper adds the root viewport). Rewrite the claims in `docs/architecture/api-organization.md` to match imports and ASDF loading order, and state the live platform-option validator behavior without claiming it is called until wired.

- [ ] **Step 6: Validate API and docs**

Run the focused FiveAM command from Step 2 and `python3 tests/reference/test_qualifier.py`. Check every changed Markdown command and package reference against the ASDF definitions and actual exports; do not reintroduce the removed legacy ASDF system.

### Task 3: Make maintained example inventory and smoke coverage agree

**Files:**
- Modify: `tests/examples-smoke-tests.lisp`
- Modify: `examples/README.md`
- Modify: `elmtui-examples.asd` only when the audit proves a maintained runnable file is missing from the default system.

- [ ] **Step 1: Compare the default ASDF component list, example files, and test inventory**

Compare `elmtui-examples.asd` components with files under `examples/`, the maintained/optional/support classifications in `examples/README.md`, and `*maintained-examples*` in `tests/examples-smoke-tests.lisp`. Record every unmatched file by classification. Do not load optional `fzy-picker.lisp` or call external services during this inventory.

- [ ] **Step 2: Add regression coverage for inventory drift**

Extend the examples smoke suite to assert that every default `elmtui-examples` component is accounted for as a maintained entry or an explicitly documented support-only file, and that every maintained runnable entry is represented by the smoke inventory. Preserve existing app-config/root-DSL checks; avoid treating optional or support files as runnable apps.

- [ ] **Step 3: Correct the example contract and classifications**

Update `examples/README.md` so every file is classified and each maintained runner matches the actual exported name and default system. Move a runnable example into `elmtui-examples.asd` only when its dependencies are available in the release bundle and its startup can be tested without an external mutation.

- [ ] **Step 4: Run the example smoke suite**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:load-system :elmtui-tests)' --eval '(5am:run! :elmtui.tests.examples-smoke:examples-smoke-tests)'`

Expected: all maintained default examples load, expose their documented entry points, and satisfy the current app-config/view contracts; the file-inventory assertion has no unmatched examples.

### Task 4: Qualify maintained interactive examples end to end

**Files:**
- Modify: `tests/e2e/extended-examples-pty.py`
- Modify: `scripts/test-terminal-apps.py` only as needed to add deterministic maintained-example scenarios to the existing private PTY harness.
- Modify: `tests/e2e/README.md`
- Modify: `examples/README.md`

- [ ] **Step 1: Run the existing extended-example PTY tests**

Run: `python3 tests/e2e/extended-examples-pty.py`

Expected: capture which tests pass, fail, or are marked `expectedFailure`; retain evidence under the harness's configured `/tmp` output path. Do not interpret an expected failure as successful qualification.

- [ ] **Step 2: Convert reproducible expected failures into ordinary regression tests**

For each expected failure in `tests/e2e/extended-examples-pty.py`, first reproduce it in isolation and identify the incorrect runner, visible-screen contract, or exit behavior. Add/adjust an assertion that fails on the current behavior, fix the smallest relevant app/test defect, then remove `expectedFailure` only after the isolated case passes. Keep integration cases that genuinely require tmux or optional dependencies explicitly gated.

- [ ] **Step 3: Cover each safe interactive default example**

Use the runner and controls in `examples/README.md` to add a private-PTY startup, visible-content, supported-exit, zero-exit-code, and terminal-restoration case for each interactive maintained example that can run without external integrations. Reuse the existing `TerminalApp` harness. For `wifi-menu`, retain the deterministic fake `nmcli` fixture; never invoke a real network mutation. For tmux-only examples, assert the no-tmux safe failure or retain a separately gated private-tmux case.

- [ ] **Step 4: Document exact local commands and prerequisites**

Update `tests/e2e/README.md` and `examples/README.md` with the focused commands, required tools, optional gates, artifact paths, and examples intentionally not run by the default suite.

- [ ] **Step 5: Run focused PTY coverage**

Run: `python3 tests/e2e/extended-examples-pty.py -v`

Expected: no unexpected failures or expected-failure markers among the default-safe cases; every test restores terminal attributes and exits with code 0. Run separately gated checks only when their stated prerequisites are present.

### Task 5: Run release validation and inspect final patch

**Files:**
- Validate: all files changed in Tasks 1–4.
- Modify: superproject gitlinks `cl-inputs` and `cl-state` if necessary to reference published, retrievable commits.

- [ ] **Step 1: Restore reachable submodule pins**

The current gitlinks point to commits absent from the corresponding GitHub repositories (`cl-inputs` `ea45ee1...`, `cl-state` `f95baab...`), so a clean recursive clone cannot initialize those systems. Once the local code/tests have been qualified against the proposed replacements, update only these two superproject gitlinks to the published branch commits `cl-inputs` `34114e50fb4cacd1a3aa35a537d3189493150db7` and `cl-state` `ee86e81ec2bfc65d54b349d291841db2cfc1469a`. Do not change `.gitmodules` or the other two already-retrievable pins. Verify `git submodule status` shows every submodule exactly at its superproject pin.

- [ ] **Step 2: Compile Lisp and run the full default test system**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:compile-system :elmtui-tests :force t)'`

Expected: no compilation errors or warnings attributable to the changes.

Run: `./rt.sh`

Expected: full test suite exits successfully.

- [ ] **Step 3: Run API, docs, example, and patch checks together**

Run: `scripts/build-api-docs.sh && python3 scripts/qualify-api-reference.py --structure-only && scripts/check-docstrings.sh && git diff --check`

Expected: generated output is unchanged after regeneration, published counts match, documentation debt stays within the existing ratchet, and no whitespace errors are reported.

- [ ] **Step 4: Run release checks when repository prerequisites are available**

Run: `scripts/release-check.sh`

Expected: release checks pass. If a pinned submodule, terminal emulator, or optional live integration is unavailable, report that exact prerequisite and keep the already-run focused checks as the verification evidence; do not weaken or skip the release gate.
