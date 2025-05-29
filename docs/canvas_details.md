# Terminal Canvas Abstraction Layer (`src/platform/canvas.lisp`)

## 1. Concept

The `canvas.lisp` module in elmtui provides a crucial abstraction layer responsible for managing a dedicated drawing area within the terminal. Its primary purpose is to decouple the layout and rendering of UI elements from the direct manipulation of the terminal, thereby minimizing screen updates and providing a more structured approach to UI rendering.

**Key Concepts:**

*   **Virtual Drawing Surface:** The canvas acts as a virtual drawing surface where UI elements are conceptually rendered before being flushed to the actual terminal. This allows for more complex positioning and sizing logic without immediate side effects on the terminal display.
*   **View vs. Content:**
    *   `view-rectangle`: Represents the entire available area of the terminal window.
    *   `content-rectangle`: Represents the specific portion of the `view-rectangle` where the canvas will actually draw its content. The content is always a subset of the view.
*   **Positioning and Sizing:** The canvas offers flexible strategies for positioning (e.g., below cursor, centered, fixed) and anchoring (e.g., top-left, bottom-right) to control how and where it appears on the screen and how it behaves when its size changes.
*   **Backend Agnostic:** While it interacts with a terminal `backend` (e.g., urxvt, a generic terminal), the canvas itself aims to provide a consistent API for drawing operations.
*   **Virtual Buffer:** Each canvas maintains its own `virtual-terminal-buffer`. This buffer stores the character and style information for each cell within the canvas's `content-rectangle`. This allows elmtui to build up the desired screen state in memory before transferring it to the terminal, enabling efficient diffing and partial updates.

**Role in elmtui:**

The canvas sits between the higher-level UI layout engine and the lower-level terminal backend.
1.  The **layout engine** determines the size and relative positions of UI elements.
2.  These elements are then "drawn" onto one or more **canvases**.
3.  The canvas manages its own position and size on the screen based on its configuration (strategy, anchor).
4.  Finally, the content of the canvas's virtual buffer is applied to a main **back-buffer** (representing the entire terminal screen), which is then rendered to the actual **terminal** by the backend, often using optimized diffing techniques to only update changed portions.

This abstraction helps in:
*   Managing pop-ups, dropdowns, or floating UI elements.
*   Constraining UI rendering to specific regions.
*   Optimizing terminal updates by drawing to an off-screen buffer first.

## 2. Implementation Details

### 2.1. Core Data Structure: `canvas`

The central piece is the `canvas` struct:

```lisp
(defstruct canvas
  (backend nil :type (or null t) :read-only t)
  (position-strategy +position-strategy-below-cursor+ :type keyword)
  (anchor-point +anchor-top-left+ :type keyword)
  (fixed-position nil :type (or null pos))
  (initial-cursor-position nil :type (or null pos))
  (current-cursor-position nil :type (or null pos))
  (lines-added 0 :type integer)
  (view-rectangle nil :type (or null rectangle))
  (content-rectangle nil :type (or null rectangle))
  (max-size nil :type (or null size))
  (visible-p t :type boolean)
  (initial-terminal-content nil :type (or null string)) ; Potentially for restoring screen content, though not fully utilized in the provided snippet for this.
  (buffer nil :type (or null virtual-terminal-buffer) :read-only t)) ; The canvas's own character buffer
```

*   `backend`: A reference to the terminal backend instance used for operations like getting cursor position or terminal dimensions.
*   `position-strategy`: A keyword defining how the canvas is initially positioned (e.g., `:below-cursor`, `:center-screen`).
*   `anchor-point`: A keyword defining the fixed point of the canvas when its size changes (e.g., `:top-left`, `:center`).
*   `fixed-position`: A `pos` object (x, y coordinates) used when `position-strategy` is `:fixed`.
*   `initial-cursor-position`: The terminal cursor position when the canvas was initialized.
*   `current-cursor-position`: The tracked cursor position after rendering operations on the canvas.
*   `lines-added`: Tracks how many lines might have been scrolled or added to the terminal output due to the canvas's presence, used for restoring cursor position.
*   `view-rectangle`: A `rectangle` object defining the total available terminal area.
*   `content-rectangle`: A `rectangle` object defining the actual area within `view-rectangle` where the canvas content is drawn. Its size and position are determined by the strategy, anchor, and content.
*   `max-size`: An optional `size` object constraining the maximum dimensions of the `content-rectangle`.
*   `visible-p`: A boolean indicating if the canvas is currently visible and should be rendered.
*   `buffer`: A `virtual-terminal-buffer` instance associated with this canvas. UI elements render into this buffer.

### 2.2. Position Strategies

Constants define how the canvas is initially placed:

*   `+position-strategy-below-cursor+`: Places the canvas starting at the line below the current cursor, spanning the available width or a specified initial width.
*   `+position-strategy-above-cursor+`: Places the canvas above the current cursor.
*   `+position-strategy-center-screen+`: Centers the canvas horizontally and vertically on the terminal screen.
*   `+position-strategy-fixed+`: Places the canvas at an absolute `fixed-position`.

### 2.3. Anchor Points

Constants define which part of the canvas remains fixed when its size is updated:

*   `+anchor-top+`, `+anchor-bottom+`, `+anchor-left+`, `+anchor-right+`
*   `+anchor-center+`
*   `+anchor-top-left+` (default), `+anchor-top-right+`, `+anchor-bottom-left+`, `+anchor-bottom-right+`

When `update-canvas-size` is called, the `content-rectangle`'s position is adjusted based on the anchor point to make it appear as if it's growing or shrinking from that anchor.

### 2.4. Key Functions

*   **`initialize-canvas (backend &key ...)`**:
    *   Creates and returns a new `canvas` instance.
    *   Captures the `initial-cursor-position` from the `backend`.
    *   Determines terminal dimensions (`term-w`, `term-h`).
    *   Calculates the initial `content-rectangle` based on the `position-strategy`, `initial-size`, and terminal dimensions.
    *   Creates a `virtual-terminal-buffer` sized to the `content-rectangle`.

*   **`update-canvas-size (canvas new-width new-height)`**:
    *   Resizes the `content-rectangle` of the canvas.
    *   Adjusts the position (`x`, `y`) of the `content-rectangle` based on the `anchor-point` to give the effect of resizing from that anchor.
    *   Enforces `max-size` constraints.
    *   **Note:** This function updates the `content-rectangle` dimensions but does *not* automatically resize the underlying `virtual-terminal-buffer`. The buffer is typically created with the initial content size and rendering operations should respect these bounds. If the buffer needs to be larger, it would imply re-initialization or a separate buffer resize mechanism (not explicitly shown for the canvas's own buffer in this file, but `virtual-buffer` itself might have resizing capabilities or a new one would be made).

*   **`clear-canvas (canvas)`**:
    *   If the canvas is visible, it clears the terminal area defined by its `content-rectangle` using the backend's `clear-area` function.
    *   Updates `lines-added` to track the vertical space cleared.

*   **`prepare-canvas-for-rendering (canvas)`**:
    *   Calls `clear-canvas` to wipe the area.
    *   Sets the terminal cursor to the top-left corner of the canvas's `content-rectangle` using `set-cursor-position`.
    *   Updates `canvas-current-cursor-position`.

*   **`finalize-canvas-after-rendering (canvas)`**:
    *   Called after content has been drawn to the canvas (i.e., terminal operations have occurred).
    *   Gets the new terminal cursor position.
    *   Updates `canvas-current-cursor-position`.
    *   Updates `lines-added` based on the difference between the initial cursor row and the current cursor row.

*   **`restore-terminal-state (canvas)`**:
    *   Moves the terminal cursor back to its original column (`x` of `initial-cursor-position`) but at a row adjusted by `lines-added`. This is intended to place the cursor logically after the canvas content, accommodating any new lines that were effectively "pushed down".

*   **`apply-canvas-to-buffer (canvas back-buffer)`**:
    *   This is a critical function for integrating the canvas's content into the main rendering pipeline.
    *   It takes the canvas's own `virtual-terminal-buffer` (source) and a `back-buffer` (destination, typically representing the entire terminal screen or a larger drawing area).
    *   It copies the character and style data from each cell of the canvas's buffer into the `back-buffer` at the correct offset, determined by the `content-rectangle`'s position (`x`, `y`).
    *   It performs bounds checking to ensure it only writes within the `back-buffer`'s dimensions.
    *   Both the canvas buffer and the back-buffer are locked during this operation to ensure thread safety.

*   **`get-canvas-viewport (canvas)`**:
    *   A simple accessor that returns the `content-rectangle` of the canvas. This rectangle defines the area where rendering operations targeted at this canvas should occur.

*   **Accessors for Dimensions**:
    *   `content-w (canvas)`, `content-h (canvas)`: Get width/height of the `content-rectangle`.
    *   `view-w (canvas)`, `view-h (canvas)`: Get width/height of the `view-rectangle`.
    *   Generic functions `w (canvas)` and `h (canvas)` are also defined, aliasing to content width/height.

## 3. Program Flow & Wiring

The canvas is integrated into the elmtui rendering lifecycle as follows:

1.  **Initialization**:
    *   When a UI component that requires its own drawing surface is created (e.g., a dropdown, a modal dialog, or even the main application window), `initialize-canvas` is called.
    *   The appropriate `position-strategy`, `anchor-point`, `initial-size`, and `max-size` are provided based on the UI component's requirements.
    *   This creates a `canvas` object with its own `virtual-terminal-buffer`.

2.  **Layout Phase**:
    *   The elmtui layout engine determines the required size for the content that will be displayed within the canvas.
    *   If the required size differs from the canvas's current `content-rectangle` size, `update-canvas-size` might be called to adjust it. The layout engine would calculate `new-width` and `new-height`.

3.  **Rendering Phase (Conceptual)**:
    *   UI elements that are part of this canvas draw themselves. "Drawing" in this context means writing character and style data into the canvas's `virtual-terminal-buffer` at appropriate relative coordinates (0,0 being the top-left of the canvas content area).
    *   The actual terminal operations for cursor positioning and printing characters are usually managed by higher-level rendering functions that use the canvas's buffer as a target.

4.  **Pre-Terminal Update**:
    *   Before rendering to the actual terminal, `prepare-canvas-for-rendering` can be called if direct terminal operations are to be performed within the canvas area (though the primary model seems to be rendering to the canvas's virtual buffer first). This function clears the physical terminal area corresponding to the canvas and positions the cursor.

5.  **Composition (Applying to Back-Buffer)**:
    *   The core step for integrating the canvas into the main display is `apply-canvas-to-buffer`.
    *   A global `virtual-terminal-buffer` (the "back-buffer") representing the entire terminal screen is maintained by the rendering system.
    *   The content of the canvas's `buffer` is "blitted" or copied onto this main `back-buffer` at the position defined by the canvas's `content-rectangle`.
    *   This allows multiple canvases (e.g., background, pop-ups) to be composed together in the back-buffer before a single, optimized update is sent to the terminal.

6.  **Terminal Update**:
    *   After all relevant canvases have had their content applied to the main back-buffer, the rendering system (e.g., `diff-renderer.lisp`) compares this back-buffer with the previous state of the terminal (or another buffer representing the current terminal display).
    *   Only the differences are sent to the terminal as actual print commands, cursor movements, and style changes. This minimizes flicker and improves performance.

7.  **Post-Terminal Update**:
    *   `finalize-canvas-after-rendering` is called to update the canvas's internal state regarding cursor position and lines added, if direct terminal rendering related to this canvas occurred.

8.  **Cleanup/Hiding**:
    *   When a canvas is no longer needed or is hidden:
        *   `(setf (canvas-visible-p canvas) nil)` can be used to prevent it from being rendered.
        *   `clear-canvas` can be called to explicitly erase its content from the terminal.
        *   `restore-terminal-state` is called to attempt to return the cursor to a sensible position after the canvas is removed or done with.

**Interaction with Layout Engine:**

*   The layout engine calculates the desired `width` and `height` for a piece of UI.
*   This size is then used to either initialize a canvas (`initial-size`) or update an existing one (`update-canvas-size`).
*   The canvas's `content-rectangle` (obtained via `get-canvas-viewport` or `content-w`/`content-h`) then provides the bounds within which the layout engine's child elements should be arranged and rendered into the canvas's `virtual-buffer`.

**Interaction with Terminal Backend:**

*   The canvas uses the `backend` for:
    *   Getting initial terminal dimensions (`term-w`, `term-h`).
    *   Getting/setting cursor position (`get-cursor-position`, `set-cursor-position`).
    *   Clearing areas of the screen (`clear-area`).
*   The actual rendering of characters from the (composed) `virtual-terminal-buffer` to the terminal is handled by other parts of the platform, likely within the backend itself or a renderer that uses the backend's low-level functions.

This system allows elmtui to manage complex UIs with multiple, potentially overlapping, drawing regions efficiently by abstracting the details of terminal manipulation behind the canvas and its virtual buffer.
