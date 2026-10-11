# Public API ownership and organization

ElmTUI's public API is defined by the exported symbols in its packages and the
runtime behavior behind those symbols. The ASDF definition is the source of
truth for load order; package source files and focused tests are the source of
truth for individual contracts. API packages do not all follow a single
interface/implementation-file pattern, and type declarations or input checks
are applied where the implementation needs them rather than universally.

## Package responsibilities

- `elmtui.api` owns the `dsl-type` generic. `elmtui.ui.dsl-resolution` imports
  that symbol and supplies the default resolution methods; UI packages re-export
  it for component authors.
- `elmtui.app.api` defines application configuration and platform-option
  validation. It depends on application globals, event channels, UI DSL
  resolution, ElmTUI state helpers, and `cl-state` application-state types.
- `elmtui.state.api` re-exports the shared `cl-state.api` and ElmTUI update
  interfaces, then adds component-state and update-result helpers.
- `elmtui.ui.api` exposes component lifecycle and DSL helpers and depends on
  state, utility, DSL-resolution, and component-metaclass packages.
- `elmtui.view.api` defines view/layout contracts. Concrete DSL, layout, and
  rendering behavior is implemented in the view pipeline.
- `elmtui.platform.api` exposes backend operations; `elmtui.platform.driver`
  coordinates input, rendering, lifecycle, and terminal cleanup.

Support-library APIs remain owned by `cl-events`, `cl-state`, `cl-inputs`, and
`cl-styles`; the generated reference identifies the exporting package and does
not transfer that ownership to ElmTUI.

## ASDF load order

The current top-level order in `elmtui.asd` is:

1. Shared utilities, state message/path foundations, core contracts and
   globals, then `elmtui.api`.
2. ElmTUI state update/API/model code, followed by view geometry, position, and
   API contracts.
3. Core event, keymap, loop, and focus code.
4. UI component metaclass, DSL resolution, `elmtui.ui.api`, and
   `elmtui.platform.api`.
5. View runtime and layout implementation, UI components/widgets, and built-in
   DSL aliases.
6. Application API and runtime, style implementation, platform backends, render
   presentation, pipeline, driver, and development entry points.

Update this summary when the ASDF component sequence or package ownership
changes; do not infer load order solely from API package names.

## Platform options

`elmtui.app.api:validate-platform-options` is called at the start of
`elmtui.platform.driver:run-app-platform`, before driver state or platform
resources are initialized. The `:platform-options` property list accepts:

- `:prefill-from-tmux` — boolean; capture the tmux pane before drawing.
- `:tmux-prefill-mode` — `:pane` or `:screen`.
- `:use-alternate-screen` — only `NIL` is supported; a true value is rejected
  to preserve normal scrollback.
- `:signal-keys-as-input` — boolean; deliver signal keys as input events.

The validator also still accepts the legacy option keys
(`:initial-terminal-dimensions`, `:initial-cursor-position`, `:input-mode`,
`:enable-mouse-support`, `:disable-mouse-support`, `:timeout`,
`:motion-events-p`) for compatibility with older callers.

The validator rejects unsupported keys, odd-length or circular option lists,
non-boolean flags, and unsupported tmux modes. Backend selection
(`:backend-type`) and the terminal device path (`:tty-path`) are separate
`run-app-platform` keyword arguments, not members of `:platform-options`.
Keep this list aligned with options actually consumed by the driver.

## Component Instance Lookup

`elmtui.app.api:get-component-instance` accepts an ID path as a keyword,
symbol, string, or list of path segments. List segments are normalized to
keywords consistently with scalar lookups, and the leading `:components` root
is optional. The state argument must be a `cl-state.core:application-state`;
invalid state objects signal `TYPE-ERROR` rather than recursively
redispatching.

## API maintenance

- Add public bindings to their owning package export list and document their
  supported contract.
- Add tests for package visibility, accepted inputs, error behavior, and
  runtime effects at the owning API boundary.
- Keep errors explicit; do not silently ignore misspelled or unsupported
  platform options.
- Regenerate and qualify `docs/api/generated/api.md` and `api.html` after
  public documentation metadata changes.
- Update this document when package dependencies or ASDF load order change.
