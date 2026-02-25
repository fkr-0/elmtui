# Keymap Archive Replacement Review

## Scope
This review compares removed archive modules (`src/core/keymap-archive/**`) against the active keymap system in `src/core/keymaps.lisp`, and checks whether archived facilities are replaced idiomatically.

## Facility Mapping
1. `base-keymap.lisp` (normalized keys, parsing, keymap lookup)
- Replacement: `elmtui.keymaps` normalized-key API (`parse-key-string`, `normalized-key->string`, `lookup`, `add-keybinding`).
- Status: replaced.

2. `sequence.lisp` (multi-key sequences, prefix/complete detection, sequence state)
- Replacement: integrated sequence model in `elmtui.keymaps` (`key-sequence`, `sequence-state`, `seq=`, `seq-prefix-p`, `%maybe-handle-sequence`).
- Status: replaced.

3. `registry.lisp` (registry/context stack, active context lookup)
- Replacement: integrated registry/context API in `elmtui.keymaps` (`*registry*`, `*contexts*`, `*active-contexts*`, `define-keymap-context`, `activate-context`, `lookup-binding`).
- Status: replaced.

4. `event-integration.lisp` (key event adaptation + dispatch)
- Replacement: integrated event dispatcher in `elmtui.keymaps:process-key-event` with dynamic `*dispatch-fn*` and context lookup.
- Status: replaced.

5. `defaults.lisp` / `keymap-system.lisp` (default maps + bootstrap)
- Replacement: `elmtui.keymaps:initialise` and built-in default keymaps/context registration.
- Status: replaced.

## Idiomatic Architecture Assessment
1. Better layering
- The modern keymap implementation removes cross-package runtime probing and keeps key handling in one cohesive module.

2. Explicit API surface
- Keymap bootstrap, parsing, lookup, context activation, and dispatch are exported from one package (`elmtui.keymaps`) and used directly.

3. Reduced hidden state complexity
- Archived split modules used extra registries and callback-style sequence timeout handling; modern code centralizes this to one runtime path.

## Noted Behavioral Difference
1. Sequence timeout semantics
- Archive implementation used timer callbacks for timeout expiration.
- Modern implementation checks expiration on next key event using timestamps.
- This is acceptable and simpler for deterministic TUI loops, but it is a behavior change (no asynchronous timeout callback side effects).

## Conclusion
Archived keymap facilities are functionally replaced by `src/core/keymaps.lisp` in a more cohesive and idiomatic architecture for current pre-1.0 cleanup goals.
