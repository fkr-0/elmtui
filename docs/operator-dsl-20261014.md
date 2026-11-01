# ElmTUI DSL resolver: bounded list-form validation (2026-10-14)

## Scope

This lane changes only `elmtui.ui.dsl-resolution:resolve-dsl-type` and the default list-specialized `dsl-type` method. Both public entrypoints reject repeated CAR identities and excessive nested type depth (512 list nodes) with `invalid-dsl-form`; circular CDR spines are rejected independently. Other component creation, render-tree normalization, view dispatch, and application initialization retain their existing owners.

## Grammar and observable precedence

- Scalar symbols other than NIL terminate resolution as class designators.
- Keywords delegate to the existing `dsl-type` CLOS method, retaining keyword aliases and base-element NIL returns.
- A nonempty proper list is `(TYPE . PROPS)`; its TYPE can itself be another list.
- Each outer list's PROPS are prepended to the incoming property sequence. A nested inner TYPE consequently has its own properties first, followed by outer properties, then caller props.
- Duplicate property keys are retained, **not** silently discarded; ordinary `getf` interprets the first matching key as authoritative. Explicit NIL remains different from a missing key in the raw sequence.
- The resolver does not mutate caller-owned form/props lists, using `append` to construct accumulated list spines.

## Examples

| Input | Resolution |
|---|---|
| `(resolve-dsl-type 'widget)` | `widget`, NIL |
| `(resolve-dsl-type :text)` | built-in label class and props |
| `(resolve-dsl-type '((widget :a nil) :a 1) '(:a 9))` | `widget` with `(:a nil :a 1 :a 9)` |
| `(resolve-dsl-type nil)` | structured `invalid-dsl-form` condition (`:empty-type`) |
| `(resolve-dsl-type '(:text . :bad))` | structured `invalid-dsl-form` condition (`:empty-or-improper-list`) |
| TYPE recursively contains itself | structured `invalid-dsl-form` condition (`:cyclic-type-chain`) |

## Diagnostics and limitations

`elmtui.ui.dsl-resolution::invalid-dsl-form` carries `form` and `reason` readers. The reporter intentionally omits printing a potentially cyclic form. This guard validates the **type-list chain** and finite list spines; arbitrary custom `dsl-type` methods invoking each other are user-defined CLOS behavior, not intercepted here. Property-list *semantic* validation and flattening into component constructor keywords remain separate from this resolver's legacy append contract.

## Gap ledger

| Contract | Before | Severity | Repair | Evidence |
|---|---|---|---|---|
| Empty type/list | recursive NIL / type error | Medium | typed diagnostic | malformed DSL regression |
| Improper or circular list spine | unbounded traversal or late error | High | finite proper-list predicate | malformed DSL regression |
| Circular TYPE nesting | unbounded recursive walk | High | active-form identity set | malformed DSL regression |
| Explicit NIL, duplicate keys | implicit ordering needed documentation | Medium | stable accumulation unchanged | precedence regression |
| Caller data sharing | append contract implicit | Medium | preserve nonmutation and test | precedence regression |

Shared ASDF manifest registration, arbitrary method-to-method alias-cycle policy, constructor validation, live PTY/CI and independent review require separate verification by their owners where applicable.
