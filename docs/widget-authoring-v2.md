# ElmTUI Widget Authoring Guidelines - v2

This document provides a standardized approach for creating widgets in ElmTUI following the pure functional Elm Architecture pattern. It supersedes previous widget authoring guidelines.

## Widget Component Structure

Each widget should be defined in its own package within `src/ui/widgets/` and follow this consistent structure:

### 1. Model Definition

Define a model structure to represent the widget's state:

```lisp
(defstruct widget-model
  (id nil :type t :read-only t)
  ;; Widget-specific fields
  (value nil :type t)
  (disabled nil :type boolean))
```

### 2. Message Types

Define the message types the widget can handle, typically as keywords:

```lisp
;; Example messages: :click, :change, :focus
;; Can be used directly or wrapped in more complex message structures
```

### 3. Core Functions (TEA Pattern)

#### Init Function

```lisp
(defun init-widget (id &key initial-value disabled)
  "Initialize a widget model with the given parameters.
   Returns (values initial-model initial-command)"
  (values (make-widget-model :id id 
                            :value initial-value 
                            :disabled disabled)
          nil))
```

#### Update Function

```lisp
(defun update-widget (msg model)
  "Update widget model based on a message.
   Returns (values updated-model commands)"
  (case msg
    (:click (values (handle-click model) commands))
    (otherwise (values model nil))))
```

#### View Function (NEW STANDARDIZED FORMAT)

```lisp
(defun view-widget (app-state &key widget-id custom-prop1 custom-prop2)
  "Render a widget based on app-state.
   APP-STATE: The application state containing widget model.
   WIDGET-ID: ID to use for the widget (required).
   
   Returns a styled-ui-node representing the widget."
  (let* ((model (state-ref app-state widget-id))
         (is-focused (eq widget-id (focus-id app-state))))
    (make-styled-node 
      :type :widget-type
      :props (list :id widget-id
                   :focusable t  ; If the widget is focusable
                   :value (widget-model-value model)
                   :custom-prop1 custom-prop1
                   ;; Additional properties
                   )
      :children nil)))
```

## Property Guidelines

### Standard Properties

All widgets should handle these common properties:

* `:id` - Unique identifier for the widget
* `:focusable` - Whether the widget can receive focus
* `:disabled` - Whether the widget is disabled
* `:class` - CSS-like class names for styling
* `:style` - Inline styles (should defer to stylesheet when possible)

### Widget-Specific Properties

Document widget-specific properties clearly:

```lisp
(defun view-button (app-state &key widget-id label on-click)
  "Render a button widget.
   APP-STATE: Application state.
   WIDGET-ID: Unique ID for this button (required).
   LABEL: Text to display on button.
   ON-CLICK: Message or function to execute when clicked."
  ;; Implementation
  )
```

## Composition Patterns

### Widget Composition

Compose widgets by including one widget inside another:

```lisp
(defun view-form (app-state &key widget-id fields submit-button)
  (let ((button-id (format nil "~A-submit" widget-id)))
    (make-styled-node
      :type :form
      :props (list :id widget-id)
      :children
        (list
          ;; Fields
          (view-button app-state
                      :widget-id button-id
                      :label "Submit"
                      :on-click submit-action)))))
```

### ARIA Accessibility

Include ARIA attributes for accessibility:

```lisp
(make-styled-node
  :type :button
  :props (list :id widget-id
               :aria-role "button"
               :aria-disabled (if disabled "true" "false")
               ;; Other ARIA attributes
               ))
```

## Widget Testing

Test widgets in isolation:

```lisp
(test button-widget-test
  (let* ((app-state (make-application-state))
         (button (view-button app-state :widget-id "test-button" :label "Click Me")))
    ;; Assert expected properties
    (is (eq (prop button :type) :button))
    (is (string= (prop button :label) "Click Me"))))
```

## Transition Notes

This new widget function signature represents a change from previous patterns:

* Previously: `(defun view-widget (model &key is-focused dispatch-fn) ...)`
* New: `(defun view-widget (app-state &key widget-id ...) ...)`

The new pattern centralizes state access through the app-state parameter and enforces consistent widget identification.
