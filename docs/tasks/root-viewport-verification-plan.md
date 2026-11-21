# Plan for `root-viewport` Verification Test

The goal is to create a thorough verification test for `src/ui/widgets/root-viewport.lisp`. This involves:
1.  Creating an example application that demonstrates moving the `root-viewport` (displaying a simple rectangle) using cursor keys.
2.  Adding FiveAM unit tests to verify the `root-viewport`'s functionality, particularly its positioning logic.

## Phase 1: Create the Interactive Example Application

This application will allow the user to move a small, fixed-size `root-viewport` around the terminal using arrow keys. The `root-viewport` will contain a simple colored rectangle as its child. Movement will be achieved by directly updating `offset-x` and `offset-y` in the application state.

**1.1. Define a new example file:**
    *   Location: `examples/root-viewport-test-app.lisp`
    *   Package: `elmtui.examples.root-viewport-test-app`

**1.2. Application State (`app-init`):**
    *   The state will need to store:
        *   Current `root-viewport` `offset-x` and `offset-y`.
        *   Dimensions of the simple rectangle child (e.g., `width: 10`, `height: 5`).
        *   Color of the simple rectangle.
        *   Terminal dimensions (to ensure the viewport doesn't go out of bounds).

**1.3. Update Logic (`app-update`):**
    *   Handle `key-event` messages for arrow keys:
        *   `Up Arrow`: Decrement viewport `offset-y`.
        *   `Down Arrow`: Increment viewport `offset-y`.
        *   `Left Arrow`: Decrement viewport `offset-x`.
        *   `Right Arrow`: Increment viewport `offset-x`.
    *   Ensure the viewport offsets keep the viewport within terminal boundaries.
    *   The application's `update-fn` will receive key events, calculate new `offset-x`/`offset-y` for the `root-viewport`, and return patches for these in the application state (under the `root-viewport-id`'s state).

**1.4. View Logic (`app-view`):**
    *   The application's main `view-fn` is responsible for generating the DSL for the *child* of the `root-viewport`.
    *   The child will be a simple styled `:container` representing the rectangle.
        *   Example child DSL:
            ```lisp
            (make-styled-node
             :type :container
             :props (list :id :moving-rect
                          :style (list :width 10 :height 5 :bg-color (elmtui.style-lib.styles:rgb '(0 255 0)))))
            ```
    *   The `root-viewport`'s properties (like its effective `offset-x`, `offset-y`, `width`, `height`, and `anchor` – likely fixed to `:top-left` for direct offset control) will be managed in the application state under the `root-viewport-id`.

**1.5. Application Definition (`defapplication`):**
    *   Use `defapplication`.
    *   Specify `root-viewport-id`, `initial-state-plist`, `root-component-dsl` (the simple rectangle), `update-fn`, and `view-fn`.
    *   The `root-viewport` itself is implicitly created by `defapplication`. Its `:anchor` will likely be set to `:top-left` in the initial state for the `root-viewport` component.

**1.6. Running the Example:**
    *   Provide a `main` function to run the application.

## Phase 2: Add FiveAM Unit Tests

These tests will verify `compute-anchor-offset`, `compute-view-size`, and the `init`, `update`, and `get-cleanup-info` methods of `root-viewport`.

**2.1. Define a new test file:**
    *   Location: `tests/root-viewport-tests.lisp`
    *   Package: `elmtui.tests.root-viewport`
    *   Suite: `root-viewport-tests`

**2.2. Test `compute-anchor-offset`:**
    *   Test cases for each `anchor-type`.
    *   Vary `viewport-width`, `viewport-height`, `term-cols`, `term-rows`, `cursor-row`, `cursor-col`.
    *   Assert correct `offset-y` and `offset-x`.

**2.3. Test `compute-view-size`:**
    *   Test cases for anchors like `:below-cursor`, `:above-cursor`, and full-screen anchors.
    *   Vary `term-cols`, `term-rows`, `cursor-row`.
    *   Assert correct `width`, `height`, `offset-y`.

**2.4. Test `root-viewport` `init` method:**
    *   Instantiate `root-viewport` with different `anchor` and `initial-cursor-pos`.
    *   Call `init`.
    *   Verify generated patches: `:type`, `:id`, and `:state` plist values (`:width`, `:height`, `:offset-x`, `:offset-y`, `:anchor`, `:initial-cursor-row`, `:initial-cursor-col`).
    *   Verify child spec patch if `initial-child-spec` is provided.

**2.5. Test `root-viewport` `update` method:**
    *   **`:terminal-resized` message:**
        *   Set up initial state.
        *   Send `:terminal-resized` message.
        *   Verify patches correctly update `:width`, `:height`, `:offset-x`, `:offset-y`.
    *   **Other messages (delegation):**
        *   Set up `root-viewport` with a child.
        *   Send a generic message.
        *   Verify the child's `update` method is called (e.g., using a test-specific child that records calls or produces distinct patches).

**2.6. Test `get-cleanup-info`:**
    *   Test with valid `app-state` (state exists): Verify correct `:initial-cursor-row` and `:anchor`.
    *   Test with `app-state` (state missing): Verify `nil` return and warning log.
    *   Test with state having default values if keys are missing.

## Diagram: Simplified Application Flow for Example

```mermaid
graph TD
    A[User Presses Arrow Key] --> B{Elmtui Event Loop};
    B --> C{Application's update-fn};
    C -- Updates RVP offset-x/y in App State --> D[Application State];
    D -- Patches RVP state --> D;
    C -- Generates Patches --> B;
    B -- Triggers Re-render --> E{Application's view-fn (for RVP child)};
    E -- Reads App State --> D;
    E --> F[Generates View DSL for RVP Child];
    F --> G{root-viewport view method};
    G -- Reads RVP State from App State --> D;
    G --> H[Constructs :root-viewport View Node with Child];
    H --> I[Renderer];
    I --> J[Terminal Display];