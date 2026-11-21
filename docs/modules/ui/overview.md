---
# AI Metadata Tags
ai_keywords: [UI Module, Components, Widgets, defcomponent, Component Lifecycle, Widget Library, Props, Local State, Event Handling, UI Building Blocks]
ai_contexts: [architecture, development, usage]
ai_relations: [
  "./implementation.md",
  "../app/overview.md",
  "../core/overview.md",
  "../state/overview.md",
  "../view/overview.md",
  "../platform/overview.md",
  "../../architecture/system-overview.md",
  "../../architecture/core-concepts.md",
  "../../architecture/module-dependencies.md",
  "../../dev-guides/creating-widgets.md"
]
---

# UI Module Overview

<!-- AI-IMPORTANCE:level=critical -->
## Core Functionality

The `ui` module provides the component system and widget library for Elmtui applications. It implements the [`defcomponent`](src/ui/defcomponent.lisp:1) macro for creating reusable UI components and includes a comprehensive set of standard widgets. This module bridges the gap between abstract view descriptions and concrete UI elements, handling component lifecycle, props management, and local state.

## Main Features

- **Component System:** [`defcomponent`](src/ui/defcomponent.lisp:1) macro for creating self-contained UI components
- **Widget Library:** Pre-built standard widgets (buttons, labels, inputs, layouts, etc.)
- **Component Lifecycle:** Init, update, view, and cleanup lifecycle methods
- **Props Management:** Property passing and validation system
- **Local State:** Component-specific state management independent of global state
- **Event Handling:** Component-level event processing and message emission
- **Metaclass Metadata:** Per-component metadata (`:props`, docs, examples) stored on class metaobjects
- **DSL Integration:** All components store their originating DSL form in state under `:dsl` key

<!-- AI-CONTEXT-START:type=architecture -->
## Architectural Design

The `ui` module implements a component-based architecture where UI elements are self-contained, reusable units that manage their own state and behavior.

### Key Components
- **Component Definition ([`src/ui/defcomponent.lisp`](src/ui/defcomponent.lisp:1)):** Macro for defining new UI components
- **Component Metaclass ([`src/ui/component-metaclass.lisp`](src/ui/component-metaclass.lisp:1)):** Stores component metadata directly on classes
- **Widget Library ([`src/ui/widgets/`](src/ui/widgets/:1)):** Collection of standard UI elements
- **Component API ([`src/ui/api.lisp`](src/ui/api.lisp:1)):** Public interface for component operations

### Component Structure
Every component defined with `defcomponent` includes:
- **Props:** External data passed from parent components
- **Local State:** Component-specific state managed independently
- **Lifecycle Methods:** Init, update, view, and optional cleanup/event handlers
- **DSL Form Storage:** Original DSL form automatically stored in state under `:dsl` key

### Standard Widgets
- **Layout Widgets:** [`viewport`](src/ui/widgets/viewport.lisp:1), [`root-viewport`](src/ui/widgets/root-viewport.lisp:1), [`grid-container`](src/ui/widgets/grid-container.lisp:1)
- **Input Widgets:** [`button`](src/ui/widgets/button.lisp:1), [`textinput`](src/ui/widgets/textinput.lisp:1)
- **Display Widgets:** [`label`](src/ui/widgets/label.lisp:1), [`drawable-content`](src/ui/widgets/drawable-content.lisp:1)
- **Container Widgets:** [`listbox`](src/ui/widgets/listbox.lisp:1), [`scrollable-container`](src/ui/widgets/scrollable-container.lisp:1), [`scroll-panel`](src/ui/widgets/scroll-panel.lisp:1)
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
## How to Use

### Creating Components

```lisp
;; Basic component definition
(defcomponent counter (props state)
  (:init (initial-props)
    ;; Return initial local state
    (list :count 0 :step (getf initial-props :step 1)))
  
  (:update (msg local-state)
    ;; Handle messages and update local state
    (case msg
      (:increment 
       (values (plist-replace local-state :count 
                             (+ (getf local-state :count) 
                                (getf local-state :step)))
               nil))
      (:decrement
       (values (plist-replace local-state :count 
                             (- (getf local-state :count) 
                                (getf local-state :step)))
               nil))
      (:reset
       (values (list :count 0 :step (getf local-state :step))
               nil))))
  
  (:view (props local-state)
    ;; Return view structure using view DSL
    `(elmtui.view:vertical-layout ()
       (elmtui.view:label () ,(format nil "Count: ~A" (getf local-state :count)))
       (elmtui.view:horizontal-layout ()
         (elmtui.view:button (:on-click ,(lambda () (send-message self :increment)))
                            "Increment")
         (elmtui.view:button (:on-click ,(lambda () (send-message self :decrement)))
                            "Decrement")
         (elmtui.view:button (:on-click ,(lambda () (send-message self :reset)))
                            "Reset")))))
```

### Using Standard Widgets

```lisp
;; Button widget
(elmtui.ui:button 
  (:text "Click Me"
   :on-click (lambda () (handle-button-click))
   :style '(:background :blue :foreground :white))
  "Button Label")

;; Text input widget
(elmtui.ui:textinput
  (:value current-text
   :placeholder "Enter text here..."
   :on-change (lambda (new-text) (update-text new-text))
   :max-length 100))

```

### Component Composition

```lisp
;; Parent component using child components
(defcomponent todo-app (props state)
  (:init (initial-props)
    (list :todos (list) :current-input ""))
  
  (:view (props local-state)
    `(elmtui.view:vertical-layout (:gap 1)
       (elmtui.view:label (:style '(:bold t)) "Todo Application")
       
       ;; Input form for new todos
       (elmtui.view:horizontal-layout ()
         (elmtui.ui:textinput 
           (:value ,(getf local-state :current-input)
            :placeholder "Add new todo..."
            :on-change ,(lambda (text) (send-message self (list :update-input text)))))
         (elmtui.ui:button
           (:on-click ,(lambda () (send-message self :add-todo)))
           "Add"))
       
       ;; Todo list
       (elmtui.view:vertical-layout ()
         ,@(mapcar (lambda (todo) 
                     `(todo-item (:todo ,todo 
                                  :on-toggle ,(lambda () (send-message self (list :toggle-todo todo))))))
                   (getf local-state :todos))))))
```

### Component Metadata

```lisp
;; Declare metadata in defcomponent
(defcomponent my-widget ()
  (:state
   (label "Hello" :type string))
  (:metadata
   (:props ((:label string t :doc "Label text")))
   (:documentation "Demo widget")
   (:examples ((:my-widget :label "Hi")))))

;; Read metadata from class metaobject
(let ((class (find-class 'my-widget)))
  (elmtui.ui.component-metaclass:class-metadata class))
```
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=usage -->
## Component Lifecycle

### Initialization
- **`:init` method:** Called when component is first created
- **Props Processing:** Initial props are validated and processed
- **State Setup:** Initial local state is established
- **DSL Storage:** Original DSL form automatically stored under `:dsl` key

### Updates
- **`:update` method:** Called when component receives messages
- **State Transitions:** Local state is updated based on message content
- **Command Generation:** Optional commands can be returned for side effects
- **Re-rendering:** View is automatically re-rendered after state changes

### View Generation
- **`:view` method:** Called whenever component needs to render
- **Props and State Access:** Current props and local state are available
- **DSL Generation:** Returns view structure using [`view`](../view/overview.md) DSL
- **Child Components:** Can instantiate and compose other components

### Cleanup (Optional)
- **`:cleanup` method:** Called when component is being destroyed
- **Resource Management:** Clean up timers, subscriptions, or other resources
- **State Persistence:** Optional state saving before destruction
<!-- AI-CONTEXT-END -->

## Related Resources

- [Implementation Details](./implementation.md)
- [Creating Widgets Guide](../../dev-guides/creating-widgets.md)
- [App Module Overview](../app/overview.md)
- [Core Module Overview](../core/overview.md)
- [State Module Overview](../state/overview.md)
- [View Module Overview](../view/overview.md)
- [Component Architecture](../../architecture/core-concepts.md#3-component-based-architecture)
- [System Architecture Overview](../../architecture/system-overview.md)
- [Module Dependencies](../../architecture/module-dependencies.md)
