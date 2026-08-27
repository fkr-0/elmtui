# TASKS: cl-styles Integration, Anchoring, and Cleanup

Status legend: [ ] pending, [~] in progress, [x] done

## 1. Startup + First Render
- [x] Render only after first :terminal-resized event (real term size)
  - Files: src/platform/driver.lisp
  - Changes: wait for :terminal-resized; set *current-app-model* at init; record *last-cursor-pos* on cursor events; first render sets *last-ctx* and *previous-frame-buffer*.
- [x] Record last cursor position for anchoring
  - Files: src/platform/driver.lisp (`*last-cursor-pos*`)

## 2. Root Viewport Anchoring Mechanics
- [x] Normalize anchor tokens + compute offsets
  - Files: src/ui/widgets/root-viewport.lisp
  - New: normalize-anchor; extended anchor-type (:tl/:tc/:tr/:ml/:mc/:mr/:bl/:bc/:br, :below-cursor-row/:above-cursor-row)
  - Updated: compute-anchor-offset, compute-view-size
- [x] Support overflow policy & pending scroll
  - Files: src/ui/widgets/root-viewport.lisp
  - State: :overflow-policy (:scroll|:truncate), :pending-scroll '(:down lines)
  - Logic: if :below-cursor and rows-remaining < height, set :pending-scroll or adjust :height
- [x] Backend helpers to act on :pending-scroll prior to render
  - Files: src/platform/api.lisp (new generics), src/platform/backend/terminal/terminal.lisp (bridge methods), src/pipeline.lisp (pre-render-terminal-prep stage)
  - Status: Generics added (:scroll-lines, :clear-below-cursor); terminal backend methods implemented via existing scroll-up/scroll-down/send-sequence; Stage pre-render-terminal-prep detects :pending-scroll and calls helpers.
  - [x] Clear :pending-scroll after applying scroll (state patched in pre-render stage). Added initial mocked backend test.

## 3. cl-styles Facilities + Tests
- [x] Export fixes (cl-reexport); macro wrapping for shorthands
  - Files: cl-styles/cl-styles.asd, cl-styles/src/packages.lisp, cl-styles/src/rule.lisp
- [x] Property validation improvements
  - Files: cl-styles/src/properties.lisp
  - Lambda types handled; synonyms hash-checked; groups flattened; layout groups flattened
- [~] cl-styles tests > 70% coverage
  - Files: cl-styles/tests/* (smoke, properties, selector, engine)
  - Add: additional selector (nested combinators), engine (variable overlays), properties (invalid enums/types)

## 4. Migrate presets & examples to cl-styles
- [x] Presets to cl-styles (defstylesheet/defrule)
  - Files: src/style/presets.lisp
- [ ] Sweep examples and archives for elmtui.style-lib usage
  - Files: examples/*, tests/archive/*, src/* (search for `elmtui.style-lib`)
  - Replace with cl-styles.api where applicable

## 5. Remove legacy view/style-lib
- [ ] Drop module after references are gone
  - Files: elmtui.asd, src/view/style-lib/* (delete), any reexports

## 6. App-level style enhancements (elmtui presets)
- [ ] Add borders/color/text decorations/grid+flex presets using cl-styles
  - Files: src/style/presets.lisp

## 7. Anchoring implementation details (next phase)
- [ ] Backend clear/scroll helpers integration
  - Files: elmtui.platform.api + renderer/pipeline stages
  - Add: detect :pending-scroll in root viewport state and call :scroll-lines and :clear-below-cursor pre-render
- [ ] Track app-scrolls in root viewport state and reverse on exit
  - Files: src/ui/widgets/root-viewport.lisp, shutdown logic in src/platform/driver.lisp
- [ ] Anchoring unit tests (placement + overflow)
  - Files: tests/root-viewport-anchoring-tests.lisp — expand with full scenarios including overflow-policy (:truncate vs :scroll)

## 8. Refactoring roadmap (sketch)
- [ ] DSL layers: richer macros with static checks, better error messages
- [ ] Librarize TEA state management (separate package), terminal input, event/async handling
- [ ] Standardized subscription/event-bus APIs with contracts and test fakes

## Progress Notes
- 2025-08-23: Initial cl-styles project created, presets ported, driver updated for ctx-stylesheet, process-tree applies cl-styles; defrule shorthand wrapping added; properties validation stabilized; selector specificity implemented.
- 2025-08-23: Anchoring normalization and overflow policy state added to root-viewport; tests scaffolded for offsets/dynamic size; platform API generics for scroll/clear introduced; pre-render stage invokes helpers.
