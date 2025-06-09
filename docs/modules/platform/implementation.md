---
# AI Metadata Tags
ai_keywords: [Platform Implementation, Backend Internals, Terminal Driver Code, Input Parsing, Output Rendering Logic, ANSI Sequences, Canvas Drawing, Termios Usage, Double Buffering]
ai_contexts: [implementation, development]
ai_relations: ["./overview.md", "../core/implementation.md", "../clevelib/implementation.md", "../view/implementation.md", "../../architecture/system-overview.md", "../../architecture/module-dependencies.md"]
---

# Platform Module Implementation Details

<!-- AI-IMPORTANCE:level=critical -->
## Technical Overview

The `platform` module's implementation centers around a driver pattern, where a generic `platform-driver` class or interface defines common terminal operations (see `src/platform/driver.lisp`). Specific subclasses then implement these operations for different terminal types or capabilities (e.g., `ansi-driver` in `src/platform/backend/terminal/terminal.lisp`, potentially a `canvas-driver`). This module often interfaces with `clevelib` for very low-level terminal control (e.g., `termios` via `src/clevelib/termios.lisp`). Helpers for ANSI styling can be found in `src/platform/backend/common/ansi-styling.lisp`.

<!-- AI-CONTEXT-START:type=implementation -->
## Core Implementation

### Platform Driver Class/Interface
```lisp
;; Hypothetical driver class
(defclass platform-driver ()
  ((input-stream :accessor driver-input-stream :initarg :input-stream)
   (output-stream :accessor driver-output-stream :initarg :output-stream)
   (original-termios :accessor driver-original-termios :initform nil))) ; For restoring terminal

;; Generic functions for the driver
(defgeneric initialize-terminal (driver)
  (:documentation "Sets up the terminal for TUI mode."))
(defgeneric cleanup-terminal (driver)
  (:documentation "Restores the terminal to its original state."))
(defgeneric read-terminal-input (driver)
  (:documentation "Reads and parses input, returning an event object or nil."))
(defgeneric render-to-terminal (driver view-buffer)
  (:documentation "Renders the abstract view buffer to the terminal."))
(defgeneric get-terminal-dimensions (driver)
  (:documentation "Returns (values rows columns)."))
```

### ANSI Backend (`ansi-driver`)
- **Initialization:** Uses `clevelib` (e.g., `termios` functions) to set raw mode, disable echo, etc. Saves original terminal settings.
- **Input Reading:** Reads byte sequences from `*terminal-io*` or a specific input stream.
- **Input Parsing:**
    - Translates ANSI escape sequences for keys (arrows, function keys) into Elmtui key events.
    - Parses mouse event sequences (e.g., XTerm mouse protocol).
- **Rendering:**
    - Translates Elmtui style attributes (colors, bold, underline) into ANSI escape codes (using helpers from `ansi-styling.lisp`).
    - Uses cursor positioning commands (`CSI <row>;<col>H`).
    - Implements screen clearing and line clearing commands.
    - May use a double-buffering technique: compares a new "virtual screen" to the previous one and only outputs differences to minimize flicker and optimize output.
    - `src/platform/backend/terminal/terminal.lisp` likely contains the main ANSI driver logic.

### Canvas Backend (`canvas-driver` - if applicable)
- **Initialization:** Similar to ANSI, but might also query for specific canvas capabilities.
- **Rendering:**
    - Instead of character-by-character output, might use special escape sequences or library calls to draw "pixels" or "braille characters" to simulate a canvas.
    - Manages a character-based or pixel-based buffer representing the canvas.
    - `src/platform/backend/canvas/*` would contain this logic.

### Input Processing Details
- Handling multi-byte UTF-8 characters.
- Timeout mechanisms for input reading to allow other events (e.g., timers) to be processed.
- Mapping raw key codes/sequences to Elmtui's internal key representation.

### Output Optimization
- **Diffing:** Comparing the current desired screen state with the last rendered state to send minimal updates.
- **Batching:** Grouping multiple ANSI commands together for a single write to the terminal.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
## Development Guide

### Key Internal APIs
*   `make-platform-driver (&key type)`: Factory function to create a specific driver instance.
*   Internal functions within each driver for specific tasks (e.g., `parse-ansi-key-sequence`, `render-cell-to-ansi`).

### Adding a New Backend
1.  Define a new driver class inheriting from `platform-driver` (or implementing its generic functions).
2.  Implement all required generic functions (`initialize-terminal`, `read-terminal-input`, etc.).
3.  Handle platform-specific initialization and cleanup.
4.  Implement input parsing for the new backend's event types.
5.  Implement rendering logic to translate Elmtui's abstract view into the backend's output format.
6.  Add tests for the new backend.

### Important Notes
*   Terminal behavior can be inconsistent. Test on various terminal emulators.
*   Properly restoring terminal state in `cleanup-terminal` is crucial, especially on errors. Use `unwind-protect`.
*   Performance of input parsing and output rendering is critical for a responsive TUI.
<!-- AI-CONTEXT-END -->

## Testing Strategy

*   **Mock Drivers:** Using a `mock-terminal-backend` that simulates I/O to test logic without actual terminal interaction.
    - Input can be fed from a list of predefined byte sequences.
    - Output can be captured into a buffer for verification.
*   Testing parsing of various ANSI escape sequences for keys and mouse.
*   Testing rendering of different styles, colors, and special characters.
*   Testing terminal initialization and restoration.
*   Testing dimension querying.

## Known Limitations

*   Support for advanced terminal features (e.g., true color, specific graphics protocols like Sixel or Kitty) might vary between backends.
*   Mouse support can be unreliable or differ across terminals.
*   Performance on very slow or high-latency terminal connections.

## Related Resources
- [Platform Module Overview](./overview.md)
- [Core Module Implementation Details](../core/implementation.md)
- [Clevelib Module Implementation Details](../clevelib/implementation.md)
- [View Module Implementation Details](../view/implementation.md)
- [System Overview](../../architecture/system-overview.md)
- [Module Dependencies](../../architecture/module-dependencies.md)