# ElmTUI 0.2.0 — independent review of remaining public API qualification

**Review date:** 2026-10-10 (Europe/Berlin)

**Reviewed Git HEAD:** `17bd8e9c2070fc4cda463881e7800f0c2f0d192c`

**Scope:** root ElmTUI and support-library package exports, unbound facade names, `docs/architecture/facade-reexports.tsv`, documentation audit and injected public-doc metadata

**Verdict:** **REQUEST CHANGES** before describing the entire 0.2.x public API as fully qualified. Mechanical alias identity and existing local release checks are accepted **only within their tested scope**.

This is an independent, **review-only** qualification. The worktree contained unrelated concurrent tmux/render edits; no production Lisp modules, active release docs, submodules, or owned worker files were changed. Current numbers are a reproducible SBCL/CLPM snapshot and need revalidation after further parallel documentation changes. The canonical OCP task may remain `running`; this report does not fabricate a workflow verdict.

## Review evidence

The review loaded `(asdf:load-system :elmtui)` in a fresh SBCL process through the CLPM bundle and examined public symbols of all `ELMTUI*`, `CL-EVENTS*`, `CL-STATE*`, `CL-INPUTS*`, and `CL-STYLES*` packages.

| Artifact | Rows | Meaning |
|---|---:|---|
| `elmtui-api-remainder-unbound-20261010.tsv` | **352** | Public symbol occurrences with no function, macro, bound variable, or class binding |
| `elmtui-api-remainder-shadow-candidates-20261010.tsv` | **215** | Subset of unbound occurrences whose symbol name has a usable binding in another project package; matching names alone do **not** prove identical intended contracts |
| `elmtui-api-remainder-missing-20261010.tsv` | **179** | Unique **bound** public symbols with no Common Lisp documentation metadata |
| `docs/architecture/facade-reexports.tsv` | **950** | Existing same-symbol identity/visibility manifest for imported/re-exported symbols |

The unbound count is **352 exporting-package occurrences / 333 distinct symbol identities**, **not** 352 proven callable API bugs. Legitimate symbolic restart names, names intentionally reserved for a later platform, and conditional API surfaces require separate disposition. Crucially, the documentation ratchet excludes symbols without any binding; its 90.2% figure does **not** describe this unbound surface.

### F1 — High: root and state facades export shadow/unbound counterparts

**Source:** `src/elmtui.lisp`, `src/state/state.lisp`, `src/state/api.lisp`.

In the `ELMTUI` package, **126** exported symbols have no observed binding, and **105** match a usable same-named project symbol. In `ELMTUI.STATE`, **113** exported symbol occurrences have no binding (including **98** symbols homed in `ELMTUI.STATE` itself); **91** match usable same-named project symbols. Another **14** matches occur in `ELMTUI.STATE.API`.

**Runtime-confirmed examples:**

| Advertised exported symbol | Observed status | Real exported implementation |
|---|---|---|
| `ELMTUI:BUFFER-CELL` | No class binding | `ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL` is a structure class |
| `ELMTUI:BUFFER-CELL-AT` | Not `FBOUNDP` | `ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL-AT` is callable |
| `ELMTUI.STATE:CMD` | Not `FBOUNDP` | `ELMTUI.STATE.UPDATE:CMD` is callable; intermediate `ELMTUI.STATE.API:CMD` is not |
| `ELMTUI.STATE:MAKE-STATE-PATCH` | Not `FBOUNDP` | `ELMTUI.STATE.MODEL:MAKE-STATE-PATCH` is callable |

The root package uses `(:reexport ...)` with `(:use :cl :elmtui.style.presets)`; the state facades re-export packages without equivalently importing all of their symbol identities. Those package declarations are consistent with this break. **Do not repair by blind `:use` imports or mass re-interning**: detect name collisions, preserve the canonical `EQ` symbol identity, and test individual public contracts. The diagnostic examples above can be asserted without triggering application effects using `FBOUNDP`, `FIND-CLASS`, `FIND-SYMBOL` and `EQ`.

**Acceptance:** After the source-package owners settle the intended 0.2.x surface, the root and state facades must resolve documented public names to the canonical bound symbol. Add fresh-image API assertions for representative constructors, functions, macros, variables and classes. Existing clients depending on the historical local symbols require migration analysis; simply `UNINTERN`ing them may be source incompatible.

### F2 — High: the existing 950-alias ratchet passes while public names are broken

The existing `scripts/audit-facade-exports.py` compares only symbols whose home package differs from the exporter. It is a valid **identity/drift** ratchet within that restricted set, but does not inspect `ELMTUI:BUFFER-CELL-AT` (a locally homed phantom export).

Of the 950 tracked aliases, **20** have no observed runtime binding: **19** `public-alias-retain` and **one** `private-origin-compat-review`. The 19 include **15** aliases in `ELMTUI.STATE` that originated in `ELMTUI.STATE.API`, **two** declared CL-INPUTS FD decoding names, and **two** appearances of `CONTINUE-OBSERVER-NOTIFICATION` (a restart name, potentially intentionally non-callable). Do not treat all 20 as defects. The private-origin case is `ELMTUI.VIEW.STYLED:STYLES`, whose source symbol `CL-STYLES.API::STYLES` has no function, macro, bound variable or class binding. This specific case was identified by the previous review and remains unresolved.

**Acceptance:** Preserve the 950-row identity manifest but add a separate capability/contract validation: intentional symbolic exports distinguished from documented callable/type/variable APIs, tests of root and state facades, and an owner-approved disposition of the unbound styling symbol and FD decoder declarations.

### F3 — High: public documentation includes semantically misleading synthetic descriptions

**Source:** `src/core/public-api-docstrings.lisp`.

Runtime documentation is injected through `UNLESS (DOCUMENTATION ...)` forms. This raises coverage but the current check only establishes that a docstring exists for at least one binding kind; it does not verify source truth or standalone library qualification.

Concrete source-verified inconsistencies:

- `CL-STYLES.TOKENS:MISSING-STYLE-VARIABLE` is a **condition subtype** of `STYLE-VARIABLE-RESOLUTION-ERROR` (`cl-styles/src/tokens.lisp:30`). Its injected type description says it represents "structured asynchronous tasks, styles or UI elements." That does **not** describe its role.
- `CL-EVENTS.ASYNC:ASYNC-TASK` is described as representing "structured terminal events and commands", even though it belongs to a reusable **general asynchronous task/promise** library.
- At least **20** injected type descriptions match the template `Public ... type used to represent`, **14** include the phrase "structured terminal events and commands", and **6** include "structured asynchronous tasks, styles or UI elements". These are **review candidates**, not 20 conclusively wrong definitions.
- Another **71** descriptions match a generic "Return the ... recorded in the ... representation" pattern. Their content requires per-accessor verification; do not automatically mark them invalid.

**Acceptance:** Replace demonstrably misleading descriptions with owner-confirmed type, input/output, lifecycle, mutation, error and restart contracts; audit the templated entries and strengthen tests beyond nonempty wording. Avoid using one generic description for unrelated packages.

### F4 — Medium: 179 genuinely undocumented bound exports remain

The current `scripts/check-docstrings.sh` ratchet reports **1,819** unique bound public symbols, **179** without documentation, **90.2%** coverage. This is a real reduction from 587 but is **not** completeness. The 179 unqualified entries break down as follows:

| Kind | Missing |
|---|---:|
| Function | **143** |
| Type | **19** |
| Variable | **13** |
| Macro | **4** |

By home namespace: **83 ElmTUI**, **30 cl-inputs**, **22 cl-events**, **18 cl-styles**, **26 cl-state**.

Most concentrated packages are `ELMTUI.PLATFORM.BACKEND.TERMINAL` (15), `CL-INPUTS.TOKENS` (10), `CL-EVENTS.PROTOCOLS` (9), `ELMTUI.PLATFORM.DRIVER` (9), and `CL-INPUTS.DEVICE.API` (8). The TSV records *all 179 individual symbols* so documentation owners can divide them without re-inventory.

**Acceptance:** Write source-grounded documentation in owned packages, regenerate Markdown/HTML API references, and tighten the ratchet only after successful qualification. `ELMTUI_DOCSTRING_STRICT=1` cannot pass with 179 missing. The existing root bundle also injects subproject docs that need promoting into their standalone libraries; root coverage is not evidence for isolated subproject loading.

### F5 — Medium: review and coverage are not equivalent to release approval

The prior full regression and `scripts/release-check.sh` pass are credible evidence for current behavior, not for the broken facade names above. Existing export checks and generated references center on **bound** symbols and on re-export **identity**. No current CI gate comprehensively rejects public name shadowing where the name belongs to a *different locally interned unbound symbol*.

The worktree had unrelated concurrently edited `src/platform/driver.lisp`, terminal diff renderer and tmux test files. This review neither qualifies those changes nor attributes them to the API work.

## Suggested repair order and handoff

1. **API facade owner:** Resolve F1 and F2, starting with `ELMTUI:BUFFER-CELL-AT`, `ELMTUI:BUFFER-CELL`, `ELMTUI.STATE:CMD`, and `ELMTUI.STATE:MAKE-STATE-PATCH`. Separate legitimate restart-name exports from false callable API claims, then add binding-and-identity tests in CI.
2. **Support-library owners:** Decide whether the `STYLES` phantom and CL-INPUTS FD exports are intentional reserved names, conditioned implementations, or errors. Preserve compatibility deliberately.
3. **Documentation owners:** Correct F3 template inaccuracies, then complete F4's 179 exact entries and qualify docs in standalone libraries.
4. **Independent reviewer:** Re-run fresh-image SBCL export inventory after remediation, verify `EQ` with canonical symbols, rerun full unit/integration and API reference generation, and update the 950-row manifest only when an intentional compatibility change has been approved.

**Current disposition:** `request_changes` for **full public-API completeness**; the previously green runtime tests and 950-alias identity ratchet remain acknowledged. No blanket claim that all 941 public-origin aliases have individually qualified semantics is made.
