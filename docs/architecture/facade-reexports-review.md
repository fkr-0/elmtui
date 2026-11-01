# ElmTUI 0.2.0 — exhaustive package re-export compatibility inventory

Audit: 2026-10-09. Canonical architecture OCP task: `ELMTUI-CLPM-02-ARCHITECTURE-R020-HARDEN-20261009`.

## Reproducible scope

`docs/architecture/facade-reexports.tsv` contains **every symbol identity exported
from a loaded ElmTUI, cl-events, cl-inputs, cl-state, or cl-styles package
whose `SYMBOL-PACKAGE` differs from its exporting package**. Rows are
deterministically sorted and include the exporting package, home package,
symbol name, home-package visibility, exact identity, and review state.

Reproduce or qualify with `python3 scripts/audit-facade-exports.py`.
The default command reads the committed manifest and **fails on any drift**,
including an added/retracted alias, a home-package change, or a change in
origin visibility. After an *independent, compatibility-aware review*, use
`--refresh` to write a new candidate inventory for diff review.

| Classification | Count | Interim decision |
|---|---:|---|
| `public-alias-retain` | 1063 | Public originating symbols: preserve under 0.2.x ABI; semantic rationale per binding still needs owner review. |
| `private-origin-compat-review` | 7 | Exports originating from an internal symbol. Preserve existing alias to avoid breakage; individual cases below require contract-owner decision before 0.3/1.0 API reduction. |
| `legacy-standard-restart` | 1 | `CL:USE-VALUE` is a standardized restart name, not a framework function; preserve existing export aliases until a deliberately announced deprecation. |
| **Total** | **1071** | **No symbol-identity mismatches and no `SB-*` private symbol exports.** |

The **1070** re-exports with a project-owned home are therefore partitioned
into 1063 external-origin/public aliases and 7 internal-origin compatibility
exceptions. This is a *complete mechanical origin/identity inventory*, not a
claim that every function's semantics and reason for publication were independently
reviewed. The CI ratchet preserves the entire compatibility shape until that
review happens.

## 0.3.2 refresh

ELMTUI.STATE and ELMTUI.STATE.API used UIOP `:REEXPORT`, which exports by
name only: they exported fresh, unbound symbols instead of the listed
packages' symbols, invisible to this audit because their home was the
exporter itself. Switching to `:USE-REEXPORT` added 113 rows (ELMTUI.STATE now
aliases ELMTUI.STATE.MODEL/MSG/UPDATE and CL-STATE.CORE symbols;
ELMTUI.STATE.API aliases 14 ELMTUI.STATE.UPDATE symbols) and removed 14 rows
for the old fresh symbols. ELMTUI.APP:DEFAPPLICATION is now the
ELMTUI.APP.API symbol, and ELMTUI.STATE re-exports the 17 `<VARIANT>-APPMSG-P`
predicates DEFMSG defines, which it now exports. See `scripts/audit-api-bindings.lisp` for unbound
exports.

## 0.4.0 refresh

The root ELMTUI package is now a curated facade: it imports and exports 13
application-level framework symbols (DEFAPPLICATION, DEFTEA-APP,
MAKE-UPDATE-RESULT, STATE-REF, KEY-PRESSED-P, QUIT-REQUESTED-P, the KEY-EVENT
accessors and the two theme presets) instead of 127 fresh, unbound names, and
no longer re-exports CL:USE-VALUE. The never-implemented exports elsewhere
(including DEFMSG's undefined `<variant>-p` names and STATECHANGEMSG) were
removed; `scripts/audit-api-bindings.lisp` reports none.

## Seven private-origin compatibility exceptions

| Exporter | Origin | Symbol | Reason and disposition |
|---|---|---|---|
| `ELMTUI.APP` | `ELMTUI.APP.API` | `MAKE-APP-CONFIG` | Imported constructor exposed by app facade despite being internal in source API. Existing client name remains supported; app API owner should publish at origin or document intentional facade-only status. |
| `ELMTUI.CORE.GLOBALS` | `ELMTUI.STATE.MSG` | `*MESSAGE-SCHEMAS*` | Shared mutable message schema registry deliberately imported into globals. Do not duplicate registry or silently change symbol identity; assess whether public mutation should be supported. |
| `ELMTUI.VIEW.LAYOUT` | `ELMTUI.VIEW.API` | `LAYOUT-NODE` | Generic layout protocol imported and exposed by layout facade; validate its public call contract before changing its origin visibility. |
| `ELMTUI.VIEW.STYLED` | `CL-STYLES.API` | `STYLES` | **Highest-priority exception:** runtime exposes this symbol, but it currently has **no function, macro, variable or class binding** in a freshly loaded system. Do not claim it is a callable accessor. Determine intended contract with cl-styles owner, then either implement a supported accessor with behavioral tests or deprecate this phantom alias in the next permitted API-breaking release. |
| `ELMTUI.VIEW.STYLED` | `ELMTUI.VIEW.API` | `STYLED-UI-NODE` | UI node representation imported for typed style application; avoid deleting client-visible alias. |
| `ELMTUI.VIEW.STYLED` | `ELMTUI.VIEW.API` | `UI-NODE-CHILDREN` | View tree reader forwarded from origin; owner should verify mutability/structure contract. |
| `ELMTUI.VIEW.STYLED` | `ELMTUI.VIEW.API` | `UI-NODE-PROPS` | Property reader forwarded from origin; owner should document mutation and ownership semantics. |

Runtime binding qualification of the seven exceptions found six meaningful bindings: `MAKE-APP-CONFIG`, `LAYOUT-NODE`, `UI-NODE-CHILDREN`, and `UI-NODE-PROPS` are functions; `*MESSAGE-SCHEMAS*` is a bound variable; `STYLED-UI-NODE` names a class. The seventh, `STYLES`, is **unbound** and has been escalated as a compatibility/design defect. No alias was deleted or rebound.

These are **compatibility exceptions**, not automatic permissions to increase
the set of public-internal symbol exposures. Each requires an explicit
decision before it can be marked *intentional* or removed. The API audit
test separately enforces the two standard-library exceptions.

## Risk and recommended sequencing

1. Preserve the exact symbol identity and origin relationship now, and
   enforce it in fresh-process CI. A source package adding explicit exports is
   a compatible *addition* but requires an intentional manifest review.
2. Document the seven private-origin contracts and check their direct
   callers before an API-major refactor. Do not replace a re-export with
   `INTERN`/copied functions: that breaks `EQ` identity and downstream
   type-specialization semantics.
3. Divide the other 941 aliases by actual originating support library and
   owning facade. Revalidate side effects, initialization dependencies,
   conditions, restarts, and return values, then mark genuinely supported
   stable API names in a reviewed per-binding compatibility policy.
4. Coordinate with the separate documentation OCP task. Documentation
   coverage and export-identity inventory have different denominators:
   re-export aliases count once **per exporting package**, while the existing
   docstring ratchet counts unique bound symbols.
5. In a subsequent major-version proposal, narrow only aliases whose owners
   approve removal, with clear migration aliases/deprecation documentation,
   API reference updates, and downstream integration tests.

No public exports were deleted or rebound by this audit.
