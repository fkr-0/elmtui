# Widget System Migration Guide

This guide explains how to migrate from the legacy widget system to the new standardized widget pattern implemented in Phase 3 of the ELMTUI refactoring.

## Migration Overview

The new standardized widget pattern brings several improvements:

1. **Consistent API** - All widgets follow the same signature pattern for view functions
2. **App-state Integration** - Widgets work directly with application state 
3. **Enhanced Composability** - Better integration with the view DSL
4. **Improved Type Safety** - Consistent typing and parameter handling
5. **Better Performance** - Optimized rendering with diff-based updates

## Core Changes

### 1. Widget Function Signature Changes

**Legacy Pattern:**
```lisp
(defun view-widget (model &key is-focused dispatch-fn ...)
  ...)
```

**New Pattern:**
```lisp
(defun view-widget (app-state &key widget-id ...)
  ...)
```

### 2. Widget Initialization and Registration

**Legacy Pattern:**
```lisp
;; Initialize a widget
(let ((button-model (make-button-model :id 'my-button :label "Click Me")))
  ;; Use the model directly
  (view-button button-model :is-focused t :dispatch-fn #'my-dispatch))
```

**New Pattern:**
```lisp
;; Initialize and store in app-state during init phase
(multiple-value-bind (button-model _)
    (init-button "my-button" :label "Click Me" :on-click :button-clicked)
  (setf (state-ref app-state "my-button") button-model))

;; In view phase, just use the stored ID
(view-button app-state :widget-id "my-button")
```

### 3. Event Handling

**Legacy Pattern:**
```lisp
;; Explicit dispatch function passing
(view-button button-model :dispatch-fn (lambda (msg)
                                         (handle-message msg)))
```

**New Pattern:**
```lisp
;; Message handler directly attached to widget
(init-button "my-button" :on-click '(:button-clicked :id "my-button"))

;; Access in update function
(case (first msg)
  (:button-clicked
   (let ((button-id (getf (rest msg) :id)))
     ;; Handle button click
     )))
```

## Migration Steps

### Step 1: Update Widget Models

For each legacy widget in your application:

1. Review the corresponding `` widget model and accessors
2. Create initialization code that uses the new `init-widget` functions
3. Store widget models in your application state

### Step 2: Update View Functions

1. Replace legacy view function calls with new `` variants
2. Use `:widget-id` to reference your widget models
3. Update any custom view code to pass `app-state` to widgets

### Step 3: Update Event Handlers

1. Convert message handlers to work with the new widget event pattern
2. Use the widget update functions (e.g., `update-button`) when needed

### Step 4: Test Thoroughly

1. Verify that all widgets render correctly
2. Check that event handling works as expected
3. Ensure focus management is correct

## Standardized Widget List

The following widgets have been standardized:

| Legacy Widget | Standardized Widget | Key Improvements |
|---------------|---------------------|------------------|
| `view-button` | `view-button` | Added tooltip, aria-label support, more styling options |
| `view-label` | `view-label` | Better integration with form controls, styling improvements |
| `view-textinput` | `view-textinput` | Added disabled state, placeholder support, simplified event model |
| `view-listbox` | `view-listbox` | Better keyboard navigation, empty-state handling, selection improvements |
| `view-scrollable-container` | `view-scrollable-container` | Enhanced scrollbar visibility control, better focus handling |

## Using the DSL with New Widgets

The new View DSL (v2) integrates seamlessly with standardized widgets:

```lisp
(define-view my-form-view (app-state dispatch)
  (:div :class "form"
    (:label :widget-id "name-label")
    (:textinput :widget-id "name-input" 
               :placeholder "Enter your name")
    (:button :widget-id "submit-button")))
```

## Temporary Backward Compatibility

Each standardized widget provides a backward-compatibility function with the original function name. These will display deprecation warnings but allow for gradual migration.

## Need Help?

Refer to the following documentation for more details:
- `widget-authoring.md` - Guide to creating standardized widgets
- `view-dsl-reference.md` - Comprehensive guide to the view DSL
- Examples in `examples/comprehensive-widgets-demo.lisp`
