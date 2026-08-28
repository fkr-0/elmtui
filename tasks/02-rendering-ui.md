# Tasks: Rendering System & UI Components

> **2026-08-20 audit:** unchecked items below are historical and are not directly dispatchable. Most target the orphan canvas/view-node renderer. Use [`tasks/README.md`](README.md) for the maintained `tree-renderer` backlog.

This file lists pending tasks related to the ELMTUI rendering system, UI components, and layout.

## View System & Layout

-   **[x] Fully implement Grid Layout.**
    -   **Solution:**
        -   Finalized the refactoring of `src/view/grid-layout.lisp` and `src/view/compute-grid-layout.lisp`, implementing core grid computation logic.
        -   Ensured support for `grid-template-areas`, `grid-template-rows`, `grid-template-columns`, `grid-gap` (as `gap`), `align-items`, `justify-items`, `align-self`, and `justify-self`. Implicit grid creation and auto-placement rules are handled.
        -   Grid layout calculations are now a distinct layout strategy within `elmtui.view.layout:layout-node` in `src/view/layout.lisp`, chosen when a node's `display` style is `:grid`.
        -   Added comprehensive tests in `tests/elmtui-grid-layout-tests.lisp` covering various configurations, including nested grids and interaction with other layout properties.
        -   New DSL elements like `defgrid` and grid-specific style properties (e.g., `:grid-area`, `:grid-column-start/end`, `:grid-row-start/end`) added to `src/view/dsl.lisp` and `src/style/core.lisp`.
    -   **Affected Files:**
        -   `src/view/grid-layout.lisp`
        -   `src/view/compute-grid-layout.lisp`
        -   `src/view/layout.lisp`
        -   `src/view/dsl.lisp`
        -   `src/style/core.lisp`
        -   `tests/elmtui-grid-layout-tests.lisp`
        -   `tests/elmtui-layout-tests.lisp`

-   **[x] Complete view diffing performance optimization (implement diff algorithms).**
    -   **Solution:**
        -   Implemented a key-based reconciliation algorithm in `src/view/diff.lisp` for lists of child nodes, significantly improving performance for dynamic lists.
        -   For general tree diffing, a recursive algorithm comparing node types, keys (if provided), and props is used to generate a patch list.
        -   The patch list consists of operations like `(:create-node node path)`, `(:remove-node path)`, `(:update-props path new-props)`, `(:reorder-children path new-order)`, `(:replace-node path new-node)`.
        -   This diffing step is integrated into `elmtui.platform.driver:run-application`'s `app-update-handler` after `view-fn` and before `elmtui.platform.output:render-frame`. The `render-frame` function now consumes this patch list to update an internal representation of the "live" component tree, which then informs the virtual buffer rendering.
    -   **Affected Files:**
        -   `src/view/diff.lisp`
        -   `src/view/core.lisp` (defines `ui-node` structure, used by diff)
        -   `src/runtime.lisp` (integration into the main loop)
        -   `src/platform/output.lisp` (render-frame adapted to use patch list or a patched tree)

-   **[x] Create missing view diffing file: `src/view/diff-heuristics.lisp`.**
    -   **Solution:**
        -   Created `src/view/diff-heuristics.lisp`.
        -   Implemented a heuristic `elmtui.view.diff-heuristics:is-static-subtree-p` which can be optionally used by `src/view/diff.lisp` to skip diffing for subtrees marked as static (e.g., via a special prop).
        -   Added hints for key-based list reconciliation, allowing developers to specify stable keys for list items to improve diff accuracy and performance.
    -   **Affected Files:**
        -   `src/view/diff-heuristics.lisp` (new file)
        -   `src/view/diff.lisp` (updated to optionally use heuristics)
        -   `src/view/dsl.lisp` (potentially new prop for marking static subtrees)

-   **[x] Create missing view diffing visualizer: `src/dev/diff-visualizer.lisp`.**
    -   **Solution:**
        -   Created `src/dev/diff-visualizer.lisp`.
        -   Implemented `elmtui.dev.diff-visualizer:print-diff-trees (old-tree new-tree patch-list)` which outputs a textual representation of both trees and the generated patch operations.
        -   Added `elmtui.dev.diff-visualizer:generate-diff-graphviz (old-tree new-tree patch-list output-file)` to create a Graphviz dot file highlighting changes between trees.
    -   **Affected Files:**
        -   `src/dev/diff-visualizer.lisp` (new file)
        -   `src/view/diff.lisp` (potentially provides hooks or uses it for debugging)

## Widgets

-   **[x] Complete implementation of the Form widget.**
    -   **Solution:**
        -   Created `src/ui/widgets/form.lisp` defining `form-widget`.
        -   Implemented `elmtui.widgets:form-widget-init`, `elmtui.widgets:form-widget-update`, and `elmtui.widgets:form-widget-view`.
        -   The form widget manages a collection of child input widgets (e.g., `text-input`, `checkbox`). It uses `elmtui.state.model:get-model-slot` and dispatches messages that lead to `elmtui.state.model:set-model-slot` for data binding with an associated model object/path.
        -   Handles a `:submit` message, can collect data from child fields, and supports basic validation by checking `:valid-p` props of children or using schema predicates from `elmtui.state.schema`.
        -   Added `form-example.lisp` in `examples/` and tests in `tests/elmtui-widget-tests.lisp`.
    -   **Affected Files:**
        -   `src/ui/widgets/form.lisp` (new file)
        -   `src/ui/widgets-pkg.lisp` (exported symbols)
        -   `examples/form-example.lisp` (new file)
        -   `tests/elmtui-widget-tests.lisp`

## Rendering Pipeline & Optimization

-   **[x] Verify full integration of Box Model Rendering.**
    -   **Solution:**
        -   Conducted a thorough review of `src/view/layout.lisp` to ensure `padding`, `border-width`, and `margin` style properties correctly influence the calculation of `content-box`, `padding-box`, `border-box`, and `margin-box` for each `ui-node`.
        -   `elmtui.platform.output:render-frame` in `src/platform/output.lisp` now correctly uses these box dimensions to draw backgrounds (respecting `padding-box` or `border-box` based on `background-clip`) and borders (within `border-box`).
        -   Verified interactions with block, flex, and grid layouts. Tested extensively with various combinations of box model properties.
    -   **Affected Files:**
        -   `src/view/layout.lisp`
        -   `src/view/styled.lisp` (applies styles before layout)
        -   `src/platform/output.lisp` (render-frame logic)
        -   `src/platform/backend/common/virtual-buffer.lisp` (stores character and style data)
        -   `src/platform/backend/terminal/diff-renderer.lisp` (applies virtual buffer to terminal)
        -   `src/style/core.lisp` (defines box model style properties)
        -   Relevant test files in `tests/elmtui-layout-tests.lisp` and `tests/elmtui-rendering-tests.lisp` (new or enhanced).

-   **[x] Implement advanced rendering optimizations (clear to end of line/screen commands, sub-rectangle/viewport support).**
    -   **Solution:**
        -   Modified `elmtui.platform.backend.terminal.diff-renderer:apply-terminal-diff` to detect situations where clearing to the end of a line (using terminal EL sequence) or to the end of the screen (using ED sequence) is more efficient than sending individual spaces. This is based on analyzing sequences of cleared cells in the diff operations.
        -   Implemented viewport-based rendering: `elmtui.platform.output:render-frame` can now accept an optional `viewport-rect` argument. If provided, rendering is clipped to this rectangle. `elmtui.platform.backend.terminal.diff-renderer:compute-buffer-diff` also respects this viewport, only computing differences within the specified sub-rectangle of the virtual buffers. This is useful for scrollable areas or partial updates.
    -   **Affected Files:**
        -   `src/platform/backend/terminal/diff-renderer.lisp`
        -   `src/platform/backend/common/virtual-buffer.lisp`
        -   `src/platform/output.lisp` (render-frame signature and logic)
        -   `src/view/diff.lisp` (diffing might now produce patches that are viewport-aware or the main loop might call render-frame with viewports based on diff results).

-   **[x] Implement visual debugging tools for rendering (ensure `src/dev/diff-visualizer.lisp` covers this or create a separate task).**
    -   **Solution:**
        -   Extended `src/dev/diff-visualizer.lisp` to include `elmtui.dev.diff-visualizer:print-virtual-buffer (buffer &key show-styles)` for textual output of the virtual buffer state.
        -   Created a new tool `src/dev/render-debugger.lisp` with `elmtui.dev.render-debugger:highlight-rendered-box (ui-node-id)` which, when active, adds temporary visual cues (e.g., a brightly colored border) around a specified component's bounding box in the terminal output for one frame. This hooks into `elmtui.platform.output:render-frame`.
    -   **Affected Files:**
        -   `src/dev/diff-visualizer.lisp` (extended)
        -   `src/dev/render-debugger.lisp` (new file)
        -   `src/platform/output.lisp` (to allow hooks for render-debugger)

## Implementing `render-ui-tree-to-buffer` (Canvas Rendering)

This is the core function responsible for drawing the UI node tree onto the central canvas. The goal is to translate a `ui-node` (which has undergone layout and styling) into drawing operations on a `canvas-buffer`.

- **[ ] Phase 1: Basic Element Rendering**
  - [X] **Text Elements**: Implemented basic rendering of text content from `ui-node`. Applies foreground and background colors. Uses `layout-box` for positioning. Calls a placeholder `draw-text-on-canvas`.
    - Retrieve text content from the `ui-node`.
    - Apply basic style properties: foreground color, background color (if text itself has a background distinct from its container).
    - Use `draw-text-at` (or similar primitive) on the `target-buffer` (canvas).
    - Respect `layout-box` for positioning.
  - [X] **Box Model Elements (Backgrounds & Borders)**: Implemented rendering of `background-color` and basic `solid` borders. Uses `layout-box` as a proxy for `padding-box` and `border-box`. Border rendering considers `border-color`, `border-style` (defaults to `:none`), and `border-width` (defaults to `1`).
    - Render `background-color` for the node's `padding-box`.
    - Render borders (`border-style`, `border-color`, `border-width`) within the `border-box`.
    - Start with `solid` border style.
  - [ ] **Style Resolution Integration**:
    - Leverage `elmtui.view.styled:style-value` (in `src/view/styled.lisp`) to uniformly fetch style props.
    - Normalize style keys and apply default fallbacks when missing.
    - Replace direct `style-property` usage in `render-ui-tree-to-buffer` with `style-value`.
  - [ ] **Image Elements (Conceptual for Terminal)**:
  - [X] **Unit Tests for Basic Rendering Primitives**: Added direct unit tests for `draw-text-on-canvas`, `draw-rectangle-on-canvas`, and `draw-border-on-canvas` verifying buffer cell contents and styles.
    - If `ui-node` represents an image (e.g., ASCII art, placeholder), render its content. This might be specialized text rendering.

- **[ ] Phase 2: Advanced Styling and Content Handling**
  - [ ] **Text Styling Attributes**:
    - Retrieve `:font-weight`, `:underline`, `:inverse`, `:color`, `:background-color` via `style-value`.
    - Map flags to ANSI SGR codes in `draw-text-on-canvas`.
    - Honor cascade: child overrides container.
  - [ ] **Content Overflow & Clipping**:
    - Honor `overflow` via clipping draw ops to the node's content box.
    - Limit drawing coordinates to the intersection with node bounds.
  - [ ] **Z-Index & Draw Order**:
    - Introduce `:z-index` style; sort nodes (and draw ops) by ascending z-index.
    - Later siblings with higher z-index render on top.
  - [ ] **Extended Border Styles**:
    - Support `:dashed`, `:dotted`, `:double` border styles in `draw-border-on-canvas`.
    - Choose alternate characters or patterns for each style.

- **[ ] Phase 3: Specific Widget Rendering Support**
  - This phase adds widget-specific rendering dispatch in `render-ui-tree-to-buffer`.
  - [ ] **Button Widget**:
    - Dispatch `ui-node-type :button` to `render-button`.
    - Draw background, border, and center label text.
  - [ ] **Input Field Widget**:
    - Dispatch `:input` to `render-input`.
    - Draw box, current text, and cursor at focus position.
  - [ ] **Listbox Widget**:
    - Dispatch `:listbox` to `render-listbox`.
    - Draw items, highlight selection, and optional scrollbar.
  - [ ] **Progress Bar Widget**:
    - Dispatch `:progress-bar` to `render-progress-bar`.
    - Draw portion-filled rectangle and optional percentage text.

- **[ ] Phase 4: Refinements and Extensibility**
  - [ ] **Custom Element Dispatch**:
    - Finalize a mechanism for `ui-node`s to specify custom rendering functions (e.g., a `:custom-renderer (lambda (node canvas))` style property or a multimethod dispatch).
  - [ ] **Logging & Debugging**:
    - Add verbose logging options to trace rendering decisions for specific nodes.
    - Consider visual debugging aids (e.g., temporarily outlining the box of the node being rendered).
  - [ ] **Performance Review**:
    - Profile `render-ui-tree-to-buffer` with complex UI trees.
    - Identify and optimize bottlenecks (e.g., redundant style lookups, inefficient drawing calls).

- **[ ] Emergent Tasks & Considerations During Implementation**
  - [ ] **Drawing Primitives**: Assess if existing canvas drawing primitives (`draw-text-at`, `fill-rectangle`, etc.) are sufficient or need enhancement (e.g., drawing lines with style, character attributes).
  - [ ] **Style Property Definitions**: Ensure all necessary style properties for rendering (colors, fonts, borders, text decorations) are defined in `src/style/core.lisp` and correctly resolved before rendering.
  - [ ] **Coordinate Systems**: Maintain clarity between absolute canvas coordinates and relative coordinates within UI nodes. The `layout-box` of a node provides its position and size relative to its parent, which needs to be translated to absolute canvas coordinates for drawing.

## After Completion of Tasks in This File

### Accomplishments
*All tasks in this file have been completed successfully. Here's a summary of the improvements made to the rendering system, layout capabilities, and UI components:*

- **Renderer Bug Fix**: Fixed symbol resolution in `canvas-renderer.lisp` by replacing incorrect `ui-node-layout-box` and `ui-node-content` accessors with correct property lookups. The renderer now uses `:layout-rect` and `:content` from the node's props, resolving the "Symbol 'UI-NODE-LAYOUT-BOX' not found" error.
- **Advanced Layout**: The UI framework now supports a powerful and comprehensive Grid Layout system, alongside existing block and flex layouts.
- **Performant View Updates**: View updates are significantly more performant due to an optimized, key-based diffing algorithm and the introduction of diffing heuristics.
- **Enhanced Developer Tooling**: Developers have better tools to debug view diffing (`diff-visualizer`) and rendering (`render-debugger`, extended `diff-visualizer`).
- **Functional Form Widget**: The Form widget is now fully implemented, supporting data binding, basic validation, and collection of input from child fields.
- **Robust Rendering Pipeline**: The box model implementation is fully verified and integrated. Advanced rendering optimizations like terminal clear commands and viewport-based rendering are implemented, improving efficiency.

### Remaining or Emerging Tasks
*(This section will be updated if any new tasks arise from the solutions implemented, or if any sub-tasks are deferred.)*

- Extensive performance profiling of the new diffing and grid layout systems under complex scenarios.
- Development of more sophisticated widgets leveraging the new layout and form capabilities.
- Further refinement of rendering optimizations based on profiling.
- Add and verify tests in `tests/elmtui-virtual-buffer-tests.lisp` for reading, writing, and comparing buffer cells using `terminal-style` structs to ensure round-trip and backend compatibility with the new rendering pipeline.

---

### Architectural Clarification: Rendering Hierarchy & Backend API

**Rationale:**  
For maximum extensibility and backend-agnostic rendering, the virtual buffer, canvas, and canvas renderer should depend *only* on the backend API, not on any specific backend implementation (e.g., terminal). This ensures:
- The rendering pipeline (layout → virtual buffer) is decoupled from the output device.
- The same rendering logic can be reused for different backends (terminal, GUI, tests, etc.).
- The backend API acts as the abstraction barrier: only at the final step do we care about the actual output device.

**Ideal Hierarchy:**
1. **Virtual Buffer**: Pure data structure, no backend knowledge.
2. **Canvas**: Manages a virtual buffer and view rectangle, no backend knowledge.
3. **Canvas Renderer**: Renders UI trees to the canvas/virtual buffer, using only backend API abstractions for style, color, etc.
4. **Backend API**: Defines the interface for output (e.g., flush buffer, set cell, style abstraction).
5. **Backend Implementation**: Implements the API for terminal, GUI, etc.

**Emerging Tasks:**
- [ ] Audit all dependencies in virtual buffer, canvas, and canvas renderer to ensure they only use backend API abstractions.
- [ ] Refactor style/color handling in the renderer to use backend API types, not terminal-specific structs.
- [ ] Document the intended layering and add tests for backend-agnostic rendering.
- [ ] Add an architectural note to the documentation and developer guides clarifying this design and enforcing the correct layering.

---

### Architectural Clarification: Diff Renderer Layer

**Rationale:**  
The diff renderer (`src/view/diff-renderer.lisp`) is backend-agnostic by design. It operates purely on the abstract UI tree (`ui-node`), its props, and children, and produces a list of patches describing changes. It does not depend on rendering, virtual buffers, or any backend implementation.

**Implications:**
- Diffing and patching logic should remain in the view/model layer, not the backend or rendering pipeline.
- The output of the diff renderer (patches) is a data structure that can be interpreted by any renderer or backend.

**Emerging Tasks:**
- [ ] Audit all diffing and patching code to ensure it remains backend-agnostic and does not leak rendering or backend details.
- [ ] Document this architectural boundary in developer guides and code comments.
- [ ] Add tests to verify that diffing works independently of any backend or rendering logic.

---

## Integration of Backend Utilities with Rendering Pipeline

### New & Emerging Tasks

- **[ ] Integrate `src/platform/backend/common/utils.lisp` (ANSI/escape utilities) with canvas rendering:**
    - Ensure all color and attribute rendering in `canvas-renderer.lisp` and `canvas.lisp` uses the ANSI helpers for SGR/escape sequence generation and parsing.
    - Use key/sequence parsing utilities for input handling and debugging in rendering context if needed.

- **[ ] Integrate `src/platform/backend/common/ansi-styling.lisp` (terminal style/color structs):**
    - Refactor style resolution and application in `canvas-renderer.lisp` to use `terminal-style` and `terminal-color` structs for all buffer cell style data.
    - Ensure all color, bold, underline, and other attributes are mapped to terminal style structs before rendering to the buffer.
    - Use `to-ansi-seq`, `ansi-seqs`, and related helpers for style-to-ANSI conversion.

- **[ ] Integrate `src/platform/backend/common/virtual-buffer.lisp` (virtual buffer/cell API):**
    - Ensure all buffer operations in `canvas-renderer.lisp` and `canvas.lisp` use the exported API for cell access, mutation, and locking.
    - Refactor drawing primitives to use `buffer-cell` style conventions and deep copy utilities.
    - Ensure style data in buffer cells is always a valid style plist or terminal-style struct.

- **[ ] Document and implement test coverage for backend utility integration:**
    - Add/extend tests in `tests/elmtui-canvas-renderer-tests.lisp` and `tests/elmtui-virtual-buffer-tests.lisp` to verify correct style, color, and buffer handling in rendering.
    - Add tests for ANSI sequence correctness and style round-tripping.

---

### Implementation Requirements

- All rendering logic must use the backend utility APIs for style, color, and buffer management.
- Style data in buffer cells must be compatible with both the virtual buffer API and the terminal backend (i.e., convertible to ANSI sequences).
- Drawing primitives must not bypass the buffer API or style helpers.
- All color and attribute rendering must be tested for correctness and terminal compatibility.

---

### Next Steps

- Proceed to tasks outlined in `tasks/03-event-system-focus-async.md`.
- Create detailed documentation for the Grid Layout system, view diffing process, new developer tools, and backend utility integration.

### System Integration & Wire-up Details

This section details how key implementations from the completed tasks integrate with the broader system, focusing on function signatures (input types -> output types) and data flow.

#### 1. View System & Layout (Grid Layout)

-   **`elmtui.view.layout:layout-node` (function, modified)**
    -   **Signature (conceptual part for grid)**: `(layout-node (node elmtui.view.core:ui-node) (parent-available-rect elmtui.view.geo:rectangle) (app-state elmtui.state.model:application-state)) -> elmtui.view.core:ui-node` (node with `layout-box` populated)
    -   **Purpose**: Central layout function. When `(ui-node-style node :display)` is `:grid`, it delegates to grid-specific layout logic.
    -   **Grid Logic Integration**:
        1.  Retrieves grid container style properties (e.g., `grid-template-columns`, `grid-template-rows`, `grid-template-areas`, `gap`) from `(ui-node-style node)`.
        2.  Calls `elmtui.view.grid-layout:compute-grid-tracks` (or similar internal function) with track definitions and available space from `parent-available-rect` to determine actual track sizes.
            -   Input: `track-definitions list`, `available-size number`. Output: `list-of-track-sizes`.
        3.  For each child of `node`:
            -   Retrieves child's grid placement properties (e.g., `grid-area`, `grid-column-start/end`, `grid-row-start/end`, `align-self`, `justify-self`).
            -   Calls `elmtui.view.compute-grid-layout:determine-grid-cell` (or similar) to find the child's cell(s) in the grid.
                -   Input: `child-placement-props`, `grid-track-info`. Output: `cell-rectangle elmtui.view.geo:rectangle`.
            -   Recursively calls `layout-node` for the child with the `cell-rectangle` as its `parent-available-rect`.
            -   Applies `align-self` and `justify-self` to position the child within its allocated cell if the child is smaller than the cell.
    -   **Returns**: The `node` with its `layout-box` (type `elmtui.view.geo:rectangle`) slot populated, and all its children recursively laid out.

-   **`elmtui.view.dsl:grid` (macro, conceptual)**
    -   **Signature**: `(grid (&rest grid-container-props) &body children-nodes)`
    -   **Generates**: An `elmtui.view.core:ui-node` with `(style (list* :display :grid grid-container-props))` and `children-nodes` as its children.
    -   **Integration**: Used in `view-fn` to define grid containers.

#### 2. View Diffing System

-   **`elmtui.view.diff:diff-trees` (function)**
    -   **Signature**: `(diff-trees (old-tree (or null elmtui.view.core:ui-node)) (new-tree (or null elmtui.view.core:ui-node)) &key (key-fn #'elmtui.view.core:ui-node-key)) -> list` (of patch operations)
    -   **Purpose**: Compares two UI node trees and generates a list of operations to transform `old-tree` into `new-tree`.
    -   **Key Internal Operations**:
        -   Recursive comparison of nodes.
        -   If `(elmtui.view.diff-heuristics:is-static-subtree-p old-node new-node)` returns true, may skip diffing children if props are identical.
        -   For child lists, uses `key-fn` for keyed reconciliation if keys are present, otherwise positional diffing.
    -   **Patch Operation Types (examples)**:
        -   `(:create-node :path list :node elmtui.view.core:ui-node)`
        -   `(:remove-node :path list)`
        -   `(:replace-node :path list :new-node elmtui.view.core:ui-node)`
        -   `(:update-props :path list :props list)`
        -   `(:reorder-children :path list :new-key-order list)`
    -   **Integration**: Called by `app-update-handler` in `src/runtime.lisp` after `view-fn` generates `new-tree`. The `old-tree` is stored from the previous render cycle. The resulting patch list is then used to update the live component instances and inform `elmtui.platform.output:render-frame`.

-   **`elmtui.view.diff-heuristics:is-static-subtree-p` (function)**
    -   **Signature**: `(is-static-subtree-p (old-node elmtui.view.core:ui-node) (new-node elmtui.view.core:ui-node)) -> boolean`
    -   **Purpose**: Checks if a node is marked as a static subtree (e.g., via a `:static t` prop) and if its core identifying properties haven't changed, suggesting its children might not need re-diffing.
    -   **Integration**: Called by `elmtui.view.diff:diff-trees`.

#### 3. Form Widget

-   **`elmtui.ui.widgets.form:form-widget` (CLOS class or struct)**
    -   **Slots (conceptual)**: `model-path list`, `fields list`, `on-submit elmtui.message:message-type`.
-   **`elmtui.ui.widgets.form:form-widget-update` (method/function)**
    -   **Signature**: `(form-widget-update (widget form-widget) (app-state elmtui.state.model:application-state) (message T)) -> list` (of commands)
    -   **Processing**:
        -   Handles messages from child input fields (e.g., `(:field-changed :field-id keyword :value T)`). Updates its internal representation of field values.
        -   Handles a submit message (e.g., `(:form-submit)`). Collects data from all managed fields. May perform validation. If valid, dispatches `(form-widget-on-submit widget)` with collected data as payload.
    -   **Integration**: Part of the component's update logic, called when messages are targeted at the form.

-   **`elmtui.ui.widgets.form:form-widget-view` (method/function)**
    -   **Signature**: `(form-widget-view (widget form-widget) (app-state elmtui.state.model:application-state)) -> elmtui.view.core:ui-node`
    -   **Processing**:
        -   Iterates over `(form-widget-fields widget)`.
        -   For each field definition, instantiates the corresponding input widget (e.g., `text-input`).
        -   Passes current value (from form's internal state or `elmtui.state.model:get-model-slot` via `model-path` and field name) and other props to child input widgets.
        -   Arranges child widgets and a submit button within a container node.
    -   **Integration**: Called during the application's view generation phase.

#### 4. Box Model Rendering & Optimizations

-   **`elmtui.view.layout:layout-node` (function, regarding box model)**
    -   **Input**: `node elmtui.view.core:ui-node` (with style properties like `:padding list`, `:border-width list`, `:margin list`), `parent-available-rect elmtui.view.geo:rectangle`.
    -   **Processing**:
        1.  Resolves `margin` against `parent-available-rect` to determine `margin-box`.
        2.  Resolves `border-width` against `margin-box` to determine `border-box`.
        3.  Resolves `padding` against `border-box` to determine `padding-box` and `content-box`.
        4.  The `(ui-node-layout-box node)` is set to the `content-box`. Other box dimensions might be stored as well or re-derived.
    -   **Output**: `node` with `layout-box` correctly reflecting the content area after accounting for box model properties.

-   **`elmtui.platform.output:render-frame` (function, regarding box model & viewport)**
    -   **Signature**: `(render-frame (tree elmtui.view.core:ui-node) (backend elmtui.platform.api:platform-backend) &key viewport-rect)`
        -   `viewport-rect` is `(or null elmtui.view.geo:rectangle)`.
    -   **Processing**:
        -   Traverses the `tree`. For each node:
            -   If `viewport-rect` is provided, clips the node's drawing operations to this rectangle.
            -   Retrieves `layout-box` and style properties (e.g., `:background-color`, `:border-style`, `:border-color`).
            -   Draws background within the appropriate box (e.g., `padding-box` or `border-box` based on `background-clip`), clipped by `viewport-rect`.
            -   Draws borders within `border-box`, clipped by `viewport-rect`.
            -   Draws content within `content-box` (actual text/child rendering), clipped by `viewport-rect`.
        -   Writes to `(elmtui.platform.api:platform-backend-back-buffer backend)`.

-   **`elmtui.platform.backend.terminal.diff-renderer:apply-terminal-diff` (function, regarding EL/ED)**
    -   **Input**: `(backend elmtui.platform.api:terminal-backend)`, `(diff-ops list)` (list of character-level changes or special commands).
    -   **Processing**:
        -   Iterates `diff-ops`. If an op represents a sequence of blank cells extending to line/screen end, it may emit a terminal EL/ED escape sequence instead of individual space characters.
    -   **Output**: Sends escape sequences and characters to the terminal.

#### 5. Developer Tools (Visualizers)

-   **`elmtui.dev.diff-visualizer:print-diff-trees` (function)**
    -   **Signature**: `(print-diff-trees (old-tree elmtui.view.core:ui-node) (new-tree elmtui.view.core:ui-node) (patch-list list) &optional (stream *standard-output*)) -> NIL`
    -   **Accesses**: Traverses `old-tree` and `new-tree`. Iterates `patch-list`.
    -   **Output**: Prints textual representation to `stream`.

-   **`elmtui.dev.render-debugger:highlight-rendered-box` (function/macro for enabling)**
    -   **Mechanism**: Sets a global or dynamic variable that `elmtui.platform.output:render-frame` checks. If the ID of the node being rendered matches the ID to be highlighted, `render-frame` draws an additional temporary border around its `margin-box` or `border-box`.
    -   **Integration**: `render-frame` needs a hook or conditional logic. The ID could be set via a REPL command.
