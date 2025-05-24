# Key Management Specification (key-management.md)

## 1. Introduction & Goals

*   **Purpose**: Define a robust and intuitive key management system for elmtui.
*   **Core Goals**:
    *   **Modularity & Encapsulation**: Widgets should define and manage their own keybindings independently.
    *   **Simplicity**: The DSL for defining keybindings should be clear, concise, and easy to use for widget authors.
    *   **Discoverability (Introspection)**: Provide mechanisms to query an application or specific widgets for their active keybindings.
    *   **Flexibility**: Support mapping keys to actions (direct function calls within the widget's context) or messages (to be processed by the widget's update function, Elm-style).
    *   **Conflict Resolution**: Define a clear strategy for handling keybinding conflicts (e.g., global vs. local, parent vs. child widget).
    *   **User Experience**: Ensure keybindings are predictable, consistent, and follow common UX patterns. Allow for user customization where appropriate (future goal).
*   **Elm Philosophy Alignment**:
    *   Key events are treated as incoming data.
    *   Widget state (including focus and active keymaps) determines how key events are processed.
    *   Keybinding definitions should be declarative.
    *   Actions triggered by keys should ideally result in messages that update the widget's model, leading to a new view.

## 2. Core Concepts

*   **Keymap**: A data structure (e.g., a hash table or an alist) that maps key definitions to actions or messages.
    *   `(:key "C-x C-s" :action 'save-action :description "Save the file")`
    *   `(:key "Enter" :message '(:submit-form) :description "Submit current form")`
*   **Key Definition**: A standardized way to represent key presses, including modifiers.
    *   Examples: `"C-x"`, `"S-Tab"`, `"Enter"`, `"F1"`, `"a"`.
    *   Should leverage the existing key parsing from `elmtui.core.input-events`.
*   **Action**:
    *   A symbol representing a function to be called directly. This function would typically operate within the widget's context (e.g., manipulate internal state not part of the Elm model, or trigger a side effect directly if absolutely necessary and well-contained).
    *   Could also be a lambda for very simple, localized actions.
*   **Message**:
    *   A data structure (often a list starting with a keyword) that is sent to the widget's `update` function, following the Elm architecture. This is the preferred way for most interactions.
*   **Keybinding Scope**:
    *   **Local/Widget-Specific**: Defined by and active for a particular widget instance, typically when it has focus.
    *   **Global**: Active throughout the application, regardless of focus (e.g., "C-q" to quit).
*   **Focus**: Crucial for determining which widget's keymap is currently active. The focus management system (`elmtui.core.focus`) will be central.

## 3. DSL Extension for Keybindings

*   **Proposal**: Introduce a new macro or a dedicated section within widget definitions for specifying keymaps.
*   **Widget Definition Example (Conceptual)**:
    ```lisp
    (define-widget my-input-widget (props state)
      (:view ...)
      (:update ...)
      (:keymap
        ;; Keymap for when the widget is focused
        (:focused
          ("Enter" :message '(:submit-value (current-input-value state)) :description "Submit input")
          ("C-a"   :action 'select-all-text :description "Select all text")
          ("Escape" :message '(:cancel-input) :description "Clear input and lose focus (example)"))
        ;; Keymap for global bindings specific to this widget's existence (less common)
        ;; (:global-widget ; Tentative idea, might be overly complex
        ;;   ("M-i" :message '(:toggle-my-input-widget-visibility) :description "Toggle this widget type globally"))
      )
    )
    ```
*   **Keymap Structure**:
    *   A list of keybinding definitions.
    *   Each definition is a list: `(key-string :action action-spec | :message message-spec [:description string])`.
    *   `:description` is crucial for introspection.
*   **Considerations**:
    *   How to handle different states within a widget (e.g., normal mode vs. insert mode in a text input)?
        *   Option 1: Multiple named keymaps within the widget `(:keymap (:normal (...)) (:insert (...)))` and the widget's state determines which is active.
        *   Option 2: Dynamically generate/modify the keymap in the widget's `view` or `init` based on its state. (More Elm-like, state drives the keymap).

## 4. Key Event Processing Flow

1.  **Input Event**: A key event is received from `elmtui.platform.input`.
2.  **Focus Check**: The focus manager identifies the currently focused widget.
3.  **Local Keymap Lookup**:
    *   The system attempts to find a match for the key event in the focused widget's active local keymap.
    *   If a match is found:
        *   If it's an `:action`, the action is executed.
        *   If it's a `:message`, the message is dispatched to the widget's `update` function.
        *   The event is considered "handled" and propagation stops (usually).
4.  **Parent/Global Keymap Lookup (Propagation)**:
    *   If no match in the focused widget, the event could propagate:
        *   **Option A (Bubbling)**: Check the focused widget's parent, then its parent, up to a global keymap. This allows parent components to define contextual shortcuts.
        *   **Option B (Global First/Last)**: Always check a global keymap either before or after the local keymap.
    *   **Strategy for Conflicts**:
        *   Local bindings generally override parent/global bindings.
        *   Explicit priority might be needed for certain global shortcuts (e.g., Quit).
5.  **Default Handling**: If no binding is found, the key event might have a default behavior (e.g., inserting a character in a text input if no other binding for 'a' exists).

## 5. Introspection API

*   **Goal**: Allow developers and potentially users (e.g., for a help screen) to discover active keybindings.
*   **Proposed Functions**:
    *   `(list-global-keybindings)`: Returns a list of all globally active keybindings.
        *   Each item: `(:key "C-q" :description "Quit application" :source :global)`
    *   `(list-widget-keybindings widget-instance)`: Returns keybindings specifically defined by `widget-instance`.
        *   Each item: `(:key "Enter" :description "Submit" :source widget-id :type :local/:focused)`
    *   `(list-active-keybindings &optional widget-instance)`:
        *   If `widget-instance` is provided (and focused), returns all keybindings currently active for it (local + applicable globals/parent bindings).
        *   If no `widget-instance`, returns globals + keybindings for the currently focused widget.
        *   This function would need to understand the propagation and conflict resolution logic.
*   **Data Structure for Keybinding Info**:
    *   A plist or struct for each binding: `(:key "string" :description "string" :type (:action | :message) :target (symbol | message-data) :scope (:local | :global | :parent) :source (widget-id | :global | parent-widget-id))`
*   **Implementation**:
    *   Widgets, when defining keymaps, will also register their keybinding metadata (key, description, type) in a way that's accessible to these introspection functions.
    *   This might involve a central keybinding registry or a protocol that widgets implement.

## 6. Implementation Details & Considerations

*   **Keymap Storage**:
    *   Each widget instance could store its compiled keymap(s) (e.g., hash tables for efficient lookup) as part of its internal state or derived from its props/model.
*   **Key Normalization**: Ensure that key strings like "Ctrl-A", "control-a", "C-a" are normalized to a canonical form for reliable matching.
*   **Performance**: Key lookup should be efficient, especially for frequently pressed keys.
*   **Extensibility**: The system should be extensible for future features like user-defined keybindings or modal key C-x C-s.
*   **Integration with `elmtui.core.loop`**: The main event loop will need to incorporate the key event processing logic.
*   **Documentation**: Clear documentation for widget authors on how to define and use keymaps.

## 7. UX Best Practices

*   **Consistency**: Use common shortcuts for common actions (e.g., "Enter" for submit, "Escape" for cancel).
*   **Feedback**: Provide clear feedback when a key action is performed (though this is generally handled by the widget's `update` and `view`).
*   **Avoid Conflicts**: Minimize conflicts between common global shortcuts and widget-specific ones.
*   **Discoverability**: The introspection API is the first step. Future: a built-in help screen showing active bindings.
*   **Modifier Usage**:
    *   `Ctrl`: Typically for actions/commands.
    *   `Alt` (Meta): Often for alternative actions or menu access.
    *   `Shift`: For modifying character input or actions (e.g., `Tab` vs. `S-Tab`).

## 8. Phased Rollout (Potential Steps)

1.  **Phase 1: Core Local Keymaps**:
    *   Implement DSL for focused widget keymaps mapping to messages.
    *   Basic key processing in the event loop for focused widgets.
    *   Initial introspection for focused widget's defined bindings.
2.  **Phase 2: Actions & Global Keymaps**:
    *   Add support for `:action` in keymaps.
    *   Implement a global keymap.
    *   Define conflict resolution (local overrides global).
3.  **Phase 3: Advanced Introspection & Propagation**:
    *   Implement `list-active-keybindings`.
    *   Refine propagation logic (e.g., bubbling to parent widgets).
4.  **Phase 4: Advanced Features (Future)**:
    *   Modal keymaps within widgets.
    *   User customization of keybindings.
