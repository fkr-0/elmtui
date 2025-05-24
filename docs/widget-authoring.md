# ElmTUI Widget Authoring Guidelines

This document provides guidelines for creating new widgets and integrating them effectively within the ElmTUI framework, with a particular focus on focus management and styling.

## Making a Widget Focusable

To make your custom widget participate in focus navigation (e.g., using Tab/Shift-Tab), you need to indicate that it is focusable.

1.  **Set `:focusable t` in Props:**
    In your widget's `view` function, when constructing the primary `ui-node` that represents your widget, include the `:focusable t` property in its `:props` list.

    ```lisp
    (defun view-my-widget (model)
      (make-ui-node :type :my-widget
                    :props (list :id (my-widget-id model)
                                 :value (my-widget-text model)
                                 :focusable t ; Make this widget focusable
                                 ;; ... other props
                                 )
                    :children nil))
    ```

2.  **Ensure a Unique `:id`:**
    The focus system relies on unique IDs. Ensure the `:id` you provide in the props is unique within the currently rendered view.

The ElmTUI runtime, after each view update, collects all nodes with `:focusable t` and a valid `:id` into a `:focusable-elements` list in the application state. The focus management logic in `elmtui.core.focus` uses this list for Tab navigation.

## Handling Focus Changes within a Widget

Widgets often need to change their appearance or behavior when they gain or lose focus. For example, a text input might show a cursor when focused, or a listbox might highlight its border.

While the global application state tracks `current-focus-id`, it's often cleaner for widgets to react to explicit messages about focus changes rather than constantly checking if their ID matches the global focus ID.

**Recommended Pattern:**

1.  **Application-Level Focus Messages:**
    The main application's `update` function, after processing base-focus changes from `elmtui.core.base-focus:handle-base-focus-message`, can dispatch more specific messages to the widgets that just gained or lost base-focus.

    *   When `prev-focus-id` is not nil and different from `current-focus-id`, the widget identified by `prev-focus-id` has lost focus. The app can send it a message like `(:widget-lost-focus (prev-focus-id model))`.
    *   When `current-focus-id` is not nil and different from `prev-focus-id`, the widget identified by `current-focus-id` has gained focus. The app can send it a message like `(:widget-gained-focus (current-focus-id model))`.

    Example snippet for the main application's `update` function:

    ```lisp
    ;; In your main app update function, after calling handle-base-focus-message
    (let* ((old-focus (prev-focus-id model))
           (new-focus (current-focus-id model))
           (cmds nil))
      (when (and old-focus (not (eq old-focus new-focus)))
        (push (send-message-to-widget old-focus '(:widget-lost-focus)) cmds)
        ;; Potentially update the old widget's model directly if it stores focus state
        ;; (setf model (update-widget-focus-state model old-focus nil))
        )
      (when (and new-focus (not (eq new-focus old-focus)))
        (push (send-message-to-widget new-focus '(:widget-gained-focus)) cmds)
        ;; (setf model (update-widget-focus-state model new-focus t))
        )
      ;; ... return (values model (apply #'append commands cmds)))
    )
    ```
    *(Note: `send-message-to-widget` is a conceptual helper; you'd typically pattern match on the widget ID or type to route the message to the correct sub-update function).*

2.  **Widget's `update` Function:**
    Your widget's `update` function should then handle these `(:widget-gained-focus)` and `(:widget-lost-focus)` messages to update its own internal model. This might involve setting an `is-focused?` flag within the widget's model.

    ```lisp
    ;; In your widget's update function
    (defun update-my-widget (msg model)
      (case (car msg)
        (:widget-gained-focus
         (values (setf (my-widget-is-focused model) t) nil))
        (:widget-lost-focus
         (values (setf (my-widget-is-focused model) nil) nil))
        ;; ... other messages
        (otherwise (values model nil))))
    ```

3.  **Widget's `view` Function:**
    The widget's `view` function can then use this internal `is-focused?` flag to conditionally apply focus-specific styles (e.g., by adding a class like `"my-widget-focused"`) or change its rendered output.

    ```lisp
    (defun view-my-widget (model)
      (make-ui-node :type :my-widget
                    :props (list :id (my-widget-id model)
                                 :focusable t
                                 :classes (when (my-widget-is-focused model)
                                            '("my-widget-focused"))
                                 ;; ...
                                 )
                    ;; ...
                    ))
    ```

    Your stylesheet can then define rules for `.my-widget-focused`.

## Requesting Focus Programmatically

A widget can request that base-focus be moved to itself or another widget by dispatching a `(:request-base-focus :widget-id <target-widget-id>)` message. The main application's `update` function should pass this message to `elmtui.core.base-focus:handle-base-focus-message`.

Example: A button widget, when clicked, might request focus for a specific text input field.

```lisp
;; In the button's update function, handling a :click message
(defun update-button (msg model)
  (case (car msg)
    (:click
     (values model (list (cmd-dispatch '(:request-focus :widget-id "my-text-input")))))
    ;; ...
    ))
```

This pattern keeps focus logic centralized while allowing widgets to react to and request focus changes in a clean way.