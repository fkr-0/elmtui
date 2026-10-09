# ElmTUI post-release multi-agent dispatch plan

Generated: 2026-07-12  
Base ref: `v0.2.0`  
Base commit: `2d317acc987a33a663ffe3c2bf33c77d61774b2d`  
Dispatch state: **prepared, no agents launched**

## Executive decision

Keep publication on hold. The local `v0.2.0` tag has not been pushed, no remote is configured, and the audit confirmed post-tag P1/P2 defects. Agents must not modify the tag. A dedicated integrator will recommend either replacing the unpublished tag or preserving it and preparing `v0.2.1`; the maintainer makes and executes that decision.

The tracked release tree remains clean. This audit created only the untracked dispatch artifacts:

- `docs/plans/2026-07-12-post-release-multi-agent-dispatch.md`
- `tasks/post-release-dispatch.json`

## Confirmed findings

1. **P1 — experimental enhanced label can reference an unbound `STYLE-PROPS`.** The experimental system compiles with a real undefined-variable warning.
2. **P1 — automatically active default keymaps expose actions that only log.** F1, F10, Escape, and Enter can appear handled without application behavior.
3. **P2 — message priority has two apparent owners.** ElmTUI's registry is written but never read; `cl-events` already owns the priority protocol.
4. **P2 — core ASDF loads CLI tools.** Packager and examples runner are command-line concerns but are included in `elmtui` itself.
5. **P2 — coverage succeeds with compiler warnings.** `PARSE-FLOAT` is reported undefined/reserved and a declaration is malformed, while the command still exits successfully.
6. **P3 — active cl-inputs files are over half commented historical implementations.** This is source-maintenance debt, not a current behavioral failure.
7. **P2 investigation — 17 tracked source files are outside every maintained ASDF system.** They require classification before deletion or reintegration.
8. **P2 — optional/legacy example packaging is inconsistent.** Missing `cl-fzy` yields a raw backtrace; `dirlister_poc` is undiscoverable and has an incomplete entry point.
9. **P3 investigation — 113 untracked files and a nested Git repository remain in the checkout.** They are excluded from release but hazardous for future automation.

## Dispatch rules

- Create an isolated Git worktree and branch from v0.2.0; never work directly in the release checkout.
- Do not modify, delete, move, sign, or recreate v0.2.0. Do not configure or push remotes.
- Do not modify generated release artifacts under dist/.
- Do not absorb unrelated untracked files from the release checkout.
- For every Lisp edit, follow CLAUDE.md and the sexp-manipulator structural-editing workflow; validate every edited S-expression file.
- Run focused tests first and scripts/release-check.sh before handoff unless the task is explicitly investigation-only.
- Keep changes limited to the task allow-list; request integrator review before touching shared manifest or release files outside that list.
- Report exact commands, test results, warnings, changed files, and any unresolved design decision in the handoff.

## Worktree bootstrap

For each task, create its worktree from the immutable base ref. Example:

```sh
git worktree add ../elmtui-post-001 -b post/experimental-widgets v0.2.0
```

Do not create worktrees inside the release checkout. Do not copy untracked files into them.

## Wave and dependency graph

**Wave 1 — parallel:** POST-001, POST-002, POST-003, POST-004, POST-005, POST-006, POST-007, POST-009.  
**Wave 2 — after POST-004 and POST-007:** POST-008.  
**Wave 3 — single integrator:** POST-INT after approved task handoffs.  
**Wave 4 — maintainer only:** publication/signing.

| Task | Priority | Type | Assignment | Dependencies |
|---|---:|---|---|---|
| ELMTUI-POST-001 | P1 | implementation | Repair experimental enhanced-widget compilation | — |
| ELMTUI-POST-002 | P1 | implementation | Replace default keymap no-op actions with honest behavior | — |
| ELMTUI-POST-003 | P2 | implementation | Consolidate message contract and priority ownership | — |
| ELMTUI-POST-004 | P2 | implementation | Split command-line tools out of the core ASDF system | — |
| ELMTUI-POST-005 | P2 | implementation | Make the coverage workflow warning-clean and fail-fast | — |
| ELMTUI-POST-006 | P3 | implementation | Remove historical duplicate implementations from cl-inputs | — |
| ELMTUI-POST-007 | P2 | investigation | Classify tracked source files outside all maintained ASDF systems | — |
| ELMTUI-POST-008 | P2 | implementation | Normalize optional and legacy example packaging | ELMTUI-POST-004, ELMTUI-POST-007 |
| ELMTUI-POST-009 | P3 | investigation | Inventory and quarantine untracked workspace material | — |
| ELMTUI-POST-INT | P1 | integration | Integrate post-release fixes and decide release versioning | ELMTUI-POST-001, ELMTUI-POST-002, ELMTUI-POST-003, ELMTUI-POST-004, ELMTUI-POST-005, ELMTUI-POST-006, ELMTUI-POST-007, ELMTUI-POST-008, ELMTUI-POST-009 |
| ELMTUI-PUB-001 | manual | maintainer-only | Maintainer publication and signing | ELMTUI-POST-INT |

## Task briefs

### ELMTUI-POST-001 — Repair experimental enhanced-widget compilation

**Priority/type:** P1 / implementation  
**Branch:** `post/experimental-widgets`  
**Suggested worktree:** `../elmtui-post-001`  
**Depends on:** none

**Problem.** The experimental enhanced-widget system loads with an undefined STYLE-PROPS variable in label-enhanced and generated unused-variable warnings in button-enhanced. The label warning crosses a lexical scope boundary and can become a runtime failure.

**Evidence**

- src/ui/widgets/label-enhanced.lisp:199-217 binds STYLE-PROPS inside a LET that ends before :style uses it at line 228.
- Loading elmtui-widgets-enhanced/experimental reports undefined variable ELMTUI.UI.WIDGETS.LABEL-ENHANCED::STYLE-PROPS.
- src/ui/widgets/button-enhanced.lisp contract expansion reports unused VALUE and HAS-VALUE-P variables for the :ACTION field.

**Allowed scope**

- `src/ui/widgets/label-enhanced.lisp`
- `src/ui/widgets/button-enhanced.lisp`
- `tests/ or a dedicated experimental-widget test system when needed`
- `elmtui-widgets-enhanced.asd only when required to add a focused warning-clean test operation`

**Acceptance criteria**

- elmtui-widgets-enhanced/experimental compiles and loads without project-originated WARNING or STYLE-WARNING conditions.
- The enhanced label view returns DSL whose :style value is the computed style property list.
- The button contract change preserves validation semantics and eliminates generated unused bindings rather than merely muffling warnings.
- Focused regression tests cover the label style path and button action field.

**Verification**

- `python3 /home/user/.codex/skills/sexp-manipulator/scripts/sexp_utils.py validate <edited-lisp-files>`
- `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(require :asdf)' --eval '(asdf:load-system "elmtui-widgets-enhanced/experimental")'`
- `scripts/release-check.sh`

The standalone dispatch prompt is stored in `tasks/post-release-dispatch.json` under `ELMTUI-POST-001`.

### ELMTUI-POST-002 — Replace default keymap no-op actions with honest behavior

**Priority/type:** P1 / implementation  
**Branch:** `post/keymap-actions`  
**Suggested worktree:** `../elmtui-post-002`  
**Depends on:** none

**Problem.** ElmTUI automatically activates default keymaps whose F1, F10, Escape, and Enter action targets only log words. These public bindings appear functional but silently perform no application action.

**Evidence**

- src/core/keymaps.lisp:506 labels the section 'Default Keymaps & Actions (stubs)'.
- src/core/keymaps.lisp:517-520 action-cancel/action-confirm/action-help/action-menu only call LOG-INFO.
- src/core/keymaps.lisp:522-530 binds those actions to live default keys.
- src/core/keymaps.lisp:557-566 registers the maps and activates the global context automatically.

**Allowed scope**

- `src/core/keymaps.lisp`
- `src/core/focus.lisp only if required by the selected dispatch contract`
- `tests/keymaps-tests.lisp`
- `additional focused keymap tests under tests/`
- `documentation describing default key behavior when public behavior changes`

**Acceptance criteria**

- No automatically active default binding targets a function that only logs and returns.
- Choose and document one coherent contract: dispatch canonical messages through *dispatch-fn*, remove misleading defaults, or make actions explicitly user-supplied.
- F1/F10/Escape/Enter behavior is covered by tests including the no-dispatch-function case.
- Existing multi-key and context precedence tests remain green.

**Verification**

- `python3 /home/user/.codex/skills/sexp-manipulator/scripts/sexp_utils.py validate <edited-lisp-files>`
- `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:load-system :elmtui-tests)' --eval "(fiveam:run! 'elmtui.keymaps.tests::keymaps-suite)"`
- `scripts/release-check.sh`

**Additional guidance.** Prefer canonical message dispatch over framework-owned application semantics. Do not invent a global help/menu UI inside the keymap layer.

The standalone dispatch prompt is stored in `tasks/post-release-dispatch.json` under `ELMTUI-POST-002`.

### ELMTUI-POST-003 — Consolidate message contract and priority ownership

**Priority/type:** P2 / implementation  
**Branch:** `post/message-priority-ownership`  
**Suggested worktree:** `../elmtui-post-003`  
**Depends on:** none

**Problem.** ElmTUI carries a message-priority registry that register-message-contract writes but no runtime code reads. cl-events already defines the message-priority protocol, leaving two apparent ownership models and one dead source of truth.

**Evidence**

- src/core/events.lisp exports *MESSAGE-PRIORITIES* and REGISTER-MESSAGE-CONTRACT.
- src/core/events.lisp:168 calls the priority registry a stub.
- The only active references to *MESSAGE-PRIORITIES* are export, definition, and the macro write; there is no read path.
- cl-events/src/events/protocols.lisp and types.lisp already own MESSAGE-PRIORITY semantics and tests.

**Allowed scope**

- `src/core/events.lisp`
- `src/contracts.lisp when necessary to preserve validation ownership`
- `tests/elmtui-tests.lisp and focused event-contract tests`
- `compatibility/deprecation documentation when public symbols change`

**Acceptance criteria**

- There is one documented source of truth for message priority.
- The dead registry and misleading optional priority argument are removed, deprecated, or wired through the cl-events protocol with tests.
- Explicit message-contract validation continues to work.
- Public compatibility impact is documented and covered by tests.

**Verification**

- `python3 /home/user/.codex/skills/sexp-manipulator/scripts/sexp_utils.py validate <edited-lisp-files>`
- `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load run-tests-clpm.lisp`
- `scripts/release-check.sh`

The standalone dispatch prompt is stored in `tasks/post-release-dispatch.json` under `ELMTUI-POST-003`.

### ELMTUI-POST-004 — Split command-line tools out of the core ASDF system

**Priority/type:** P2 / implementation  
**Branch:** `post/tool-system-boundaries`  
**Suggested worktree:** `../elmtui-post-004`  
**Depends on:** none

**Problem.** The core elmtui system loads the packager and example runner even though they are command-line concerns. A separate packager system already exists, and the example runner has no external core references. This increases core load surface and duplicates ownership.

**Evidence**

- elmtui.asd:173-174 includes tools/packager and tools/examples-runner in the core system.
- elmtui-packager.asd separately loads src/tools/packager.lisp and depends on elmtui.
- No tracked code outside src/tools/examples-runner.lisp references package elmtui.examples.runner.
- elmtui-packager.asd remains version 0.1.0 while the release family is 0.2.0.

**Allowed scope**

- `elmtui.asd`
- `elmtui-packager.asd`
- `a new dedicated examples CLI ASD when justified`
- `elmtui-tests.asd`
- `tests/packager-tests.lisp`
- `tests/tools-tests.lisp`
- `bridge.yml and examples.sh only when needed to preserve supported commands`
- `README.org and docs/USER_GUIDE.md for changed load commands`
- `clpmfile and clpmfile.lock only when a new local ASD must enter the supported bundle`

**Acceptance criteria**

- Loading elmtui alone does not intern/load ELMTUI.PACKAGER or ELMTUI.EXAMPLES.RUNNER.
- The packager and example CLI remain loadable through dedicated, documented ASDF systems.
- Tool tests load their owning systems explicitly rather than relying on core side effects.
- System versions and CLPM local-ASD entries are internally consistent.
- The release gate remains green and a focused system-load audit demonstrates the boundary.

**Verification**

- `python3 /home/user/.codex/skills/sexp-manipulator/scripts/sexp_utils.py validate <edited-lisp-files>`
- `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(require :asdf)' --eval '(asdf:load-system "elmtui")' --eval '(assert (null (find-package :elmtui.packager)))' --eval '(assert (null (find-package :elmtui.examples.runner)))'`
- `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:load-system "elmtui-packager")'`
- `scripts/release-check.sh`

The standalone dispatch prompt is stored in `tasks/post-release-dispatch.json` under `ELMTUI-POST-004`.

### ELMTUI-POST-005 — Make the coverage workflow warning-clean and fail-fast

**Priority/type:** P2 / implementation  
**Branch:** `post/coverage-cleanup`  
**Suggested worktree:** `../elmtui-post-005`  
**Depends on:** none

**Problem.** coverage.lisp completes and writes an HTML report, but compiles with a reserved undefined PARSE-FLOAT warning and a DECLAIM/DECLARE style warning. The coverage bridge command accepts those warnings, so the workflow can regress silently.

**Evidence**

- coverage.lisp:14 switches into package CL.
- coverage.lisp:23,99,103 uses DECLAIM in ways that trigger 'DECLAIM where DECLARE was probably intended'.
- PARSE-NUMBER calls PARSE-FLOAT before its definition; SBCL reports the reserved function name as undefined/non-portable.
- The command still reports 2179 pass, 6 skip, 0 fail and generates coverage/cover-index.html.

**Allowed scope**

- `coverage.lisp`
- `bridge.yml coverage command`
- `a focused shell verification script under scripts/ when useful`
- `.gitignore only for generated coverage outputs`
- `documentation for coverage invocation`

**Acceptance criteria**

- coverage.lisp is package-safe and defines helpers before use with portable names.
- A cold coverage run exits zero, produces coverage/cover-index.html, and emits no project-originated WARNING or STYLE-WARNING.
- The coverage command exits nonzero on test failure, coverage generation failure, or newly introduced warning markers.
- The normal release gate remains unchanged and green.

**Verification**

- `python3 /home/user/.codex/skills/sexp-manipulator/scripts/sexp_utils.py validate <edited-lisp-files>`
- `rm -rf coverage && timeout 180s clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load coverage.lisp`
- `test -s coverage/cover-index.html`
- `scripts/release-check.sh`

The standalone dispatch prompt is stored in `tasks/post-release-dispatch.json` under `ELMTUI-POST-005`.

### ELMTUI-POST-006 — Remove historical duplicate implementations from cl-inputs

**Priority/type:** P3 / implementation  
**Branch:** `post/cl-inputs-source-cleanup`  
**Suggested worktree:** `../elmtui-post-006`  
**Depends on:** none

**Problem.** Two active cl-inputs implementation files are over half historical commented code, obscuring the production implementation and contradicting the post-release source-cleanliness goal.

**Evidence**

- cl-inputs/src/input/loop.lisp: 588 lines, 307 comment lines (52%).
- cl-inputs/src/input/decoder.lisp: 288 lines, 155 comment lines (54%).
- decoder.lisp begins by describing the file as a reference/stub despite containing the loaded production implementation later in the file.

**Allowed scope**

- `cl-inputs/src/input/loop.lisp`
- `cl-inputs/src/input/decoder.lisp`
- `cl-inputs/docs/ or history notes when genuinely useful`
- `cl-inputs/tests/ only for regressions uncovered during cleanup`

**Acceptance criteria**

- Historical commented implementations are removed or moved into concise design/history documentation.
- Public APIs and runtime behavior are unchanged.
- Both files have accurate top-level documentation describing the active implementation.
- cl-inputs independent tests pass warning-clean.

**Verification**

- `python3 /home/user/.codex/skills/sexp-manipulator/scripts/sexp_utils.py validate <edited-lisp-files>`
- `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:test-system "cl-inputs")'`
- `scripts/release-check.sh`

The standalone dispatch prompt is stored in `tasks/post-release-dispatch.json` under `ELMTUI-POST-006`.

### ELMTUI-POST-007 — Classify tracked source files outside all maintained ASDF systems

**Priority/type:** P2 / investigation  
**Branch:** `post/orphan-source-audit`  
**Suggested worktree:** `../elmtui-post-007`  
**Depends on:** none

**Problem.** Seventeen tracked Lisp source files are not loaded by any maintained ASDF system. Some are likely obsolete, some are developer tools, and some may be unfinished alternate implementations. Blind deletion or inclusion would be unsafe.

**Evidence**

- ASDF inventory found 108 loaded source files and 17 tracked src/**/*.lisp files absent from elmtui, examples, packager, and enhanced-widget systems.
- The set includes src/dev/* tools, canvas-renderer, profiler, observers, transaction-controls, diff/layout-debug/named-area/props/view-diff-render.
- Several absent files contain explicit stubs/TODOs, including layout-debug JSON export and event-dashboard metrics.

**Allowed scope**

- `All 17 orphan source files for read-only analysis`
- `ASD files for dependency/ownership analysis`
- `tests and docs for reference search`
- `docs/plans/orphan-source-classification.md as the primary deliverable`

**Acceptance criteria**

- Every orphan file receives one disposition: delete as obsolete, archive as historical, move into a named optional system, merge into an owner, or retain with explicit rationale.
- Each disposition includes reference evidence, dependency risks, test requirements, and a proposed owner/task ID.
- The report identifies mutually dependent groups and files unsafe for parallel edits.
- No source behavior changes are made.

**Verification**

- `git grep and ASDF component inventory commands documented in the report`
- `scripts/release-check.sh (to prove investigation introduced no runtime change)`

The standalone dispatch prompt is stored in `tasks/post-release-dispatch.json` under `ELMTUI-POST-007`.

### ELMTUI-POST-008 — Normalize optional and legacy example packaging

**Priority/type:** P2 / implementation  
**Branch:** `post/example-packaging`  
**Suggested worktree:** `../elmtui-post-008`  
**Depends on:** ELMTUI-POST-004, ELMTUI-POST-007

**Problem.** Optional example packaging is inconsistent: elmtui-examples-fzy directly fails with a raw missing-system backtrace when cl-fzy is absent, while the tracked dirlister_poc ASD is undiscoverable through the supported CLPM bundle and contains an incomplete entry-point form.

**Evidence**

- elmtui-examples-fzy.asd:7 directly depends on cl-fzy; direct ASDF load in the root bundle fails with a raw CLPM missing-system backtrace.
- The examples runner has a clear cl-fzy error only when loading the file manually, not when loading the optional system.
- examples/dirlister_poc/dirlister_poc.asd is tracked but absent from clpmfile and cannot be discovered in the supported bundle.
- dirlister_poc.asd:12 contains ':entry-point );"dirlister_poc:start-dirlister-poc")'.

**Allowed scope**

- `elmtui-examples-fzy.asd`
- `examples/dirlister_poc/dirlister_poc.asd and its source`
- `examples/README.md`
- `src/tools/examples-runner.lisp or its dedicated system after ELMTUI-POST-004`
- `clpmfile and lock only for a maintained local example ASD`
- `focused example smoke tests`

**Acceptance criteria**

- A maintainer-facing decision is implemented and documented for dirlister_poc: maintained and discoverable, or explicitly archived/removed from release-facing systems.
- Any maintained program system has a valid entry point and a smoke-tested load/build path.
- Missing cl-fzy produces a concise, intentional diagnostic in the documented optional workflow without machine-specific paths.
- Base examples remain independent of cl-fzy.

**Verification**

- `python3 /home/user/.codex/skills/sexp-manipulator/scripts/sexp_utils.py validate <edited-lisp-files>`
- `focused ASDF load/build checks for every maintained example system`
- `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:load-system "elmtui-examples")'`
- `scripts/release-check.sh`

The standalone dispatch prompt is stored in `tasks/post-release-dispatch.json` under `ELMTUI-POST-008`.

### ELMTUI-POST-009 — Inventory and quarantine untracked workspace material

**Priority/type:** P3 / investigation  
**Branch:** `post/workspace-hygiene-audit`  
**Suggested worktree:** `../elmtui-post-009`  
**Depends on:** none

**Problem.** The release checkout contains 113 untracked files, including generated artifacts, debug scripts, old design notes, local editor/agent state, and a nested untracked Git repository. They are excluded from the release but make future automated work and human review hazardous.

**Evidence**

- git status -uall reports 113 untracked files.
- The untracked set includes dist/, dozens of debug-*.lisp scripts, local tool directories, old-statelib, prof.lisp, and multiple issue/review files.
- find detects a nested Git repository at actiwat/.git.

**Allowed scope**

- `Read-only inventory of all untracked paths`
- `.gitignore for analysis only`
- `docs/plans/workspace-hygiene-classification.md as the deliverable`

**Acceptance criteria**

- Every untracked top-level item is classified into keep local, add to .gitignore, move to separate repository, consider adding, archive, or delete-after-approval.
- Potentially valuable source/debug artifacts are distinguished from generated junk.
- A safe ordered cleanup command plan is provided but not executed.
- Nested repositories and any irreversible action are prominently flagged for maintainer approval.

**Verification**

- `git status --porcelain=v1 -uall`
- `find . -mindepth 2 -maxdepth 4 -type d -name .git -print`
- `scripts/release-check.sh (no runtime changes expected)`

The standalone dispatch prompt is stored in `tasks/post-release-dispatch.json` under `ELMTUI-POST-009`.

### ELMTUI-POST-INT — Integrate post-release fixes and decide release versioning

**Priority/type:** P1 / integration  
**Branch:** `post/integration`  
**Suggested worktree:** `../elmtui-post-int`  
**Depends on:** ELMTUI-POST-001, ELMTUI-POST-002, ELMTUI-POST-003, ELMTUI-POST-004, ELMTUI-POST-005, ELMTUI-POST-006, ELMTUI-POST-007, ELMTUI-POST-008, ELMTUI-POST-009

**Problem.** Combine approved implementation branches, reconcile shared manifest edits, rerun cold-tree and archive-level verification, and recommend whether the unpublished local v0.2.0 tag should be replaced or the fixes should ship as v0.2.1.

**Evidence**

- The current local v0.2.0 tag is unsigned and no remote exists, so publication has not occurred.
- P1/P2 issues were found after tagging, including an experimental widget undefined variable and live no-op keymap defaults.
- The release commit and tag currently both resolve to 2d317acc987a33a663ffe3c2bf33c77d61774b2d.

**Allowed scope**

- `Approved task branches and their commits`
- `ASD/CLPM manifests during conflict resolution`
- `tests, docs, release scripts, and changelog on a new integration branch`
- `a release decision report under docs/plans/`

**Acceptance criteria**

- All approved implementation branches are merged in dependency order with conflicts resolved intentionally.
- Every maintained ASDF system loads in a fresh process; experimental systems have no project warnings.
- scripts/release-check.sh passes from the exact Git index in a detached clean worktree.
- A newly generated source archive passes the subsystem and warning-clean integration gates in a fresh CLPM home.
- The report recommends one release policy: replace unpublished v0.2.0, or preserve it and release v0.2.1; the integrator does not execute the tag decision.

**Verification**

- `scripts/release-check.sh`
- `fresh-process ASDF load audit for every maintained system`
- `detached-index clean-worktree release check`
- `fresh-CLPM extracted-archive verification`

The standalone dispatch prompt is stored in `tasks/post-release-dispatch.json` under `ELMTUI-POST-INT`.

## Integration and conflict policy

- POST-004 owns core/tool ASDF boundaries and must land before POST-008.
- POST-007 and POST-009 are investigation-only; their recommendations are not automatically merged into runtime code.
- POST-001, POST-002, POST-003, POST-005, and POST-006 have disjoint primary implementation paths and can run in parallel.
- The integrator owns final edits to shared manifests, CLPM locks, release notes, and aggregate verification.
- Any branch that changes paths outside its allow-list must stop and request re-scoping rather than broadening its patch.

Recommended implementation merge order:

1. ELMTUI-POST-001 — experimental widgets
2. ELMTUI-POST-002 — keymap semantics
3. ELMTUI-POST-003 — event priority ownership
4. ELMTUI-POST-005 — coverage workflow
5. ELMTUI-POST-006 — cl-inputs cleanup
6. ELMTUI-POST-004 — tool-system split
7. ELMTUI-POST-008 — example packaging
8. ELMTUI-POST-INT — aggregate integration

## Final integration gates

- focused tests from every implementation branch;
- `scripts/release-check.sh` from the integrated checkout;
- fresh-process loads of every maintained ASDF system;
- warning-clean experimental-widget load;
- detached clean-worktree execution against the exact Git index;
- source archive extraction and verification using a fresh CLPM home;
- a written recommendation for unpublished `v0.2.0` replacement versus `v0.2.1`.

## Publication task — maintainer only

`ELMTUI-PUB-001` remains blocked. Agents must not sign tags, configure remotes, push branches/tags, publish releases, or replace `v0.2.0`. After integration review, the maintainer chooses the versioning path, regenerates artifacts from the final tag, verifies checksums, and publishes.
