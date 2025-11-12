---
ai_keywords: [Elmtui, Component, Lifecycle, defcomponent, Inheritance, State Management, Cleanup, UI, Documentation]
ai_contexts: [development, implementation, guide]
ai_relations: [
  "../../ai-index/overview.md",
  "../../architecture/app-creation-configuration.md",
  "../tea-state/state-transactions.md",
  "../app/application-patterns.md",
  "../../dev-guides/creating-applications.md"
]
---
# Elmtui Component Lifecycle and Management

This document details the complete lifecycle of Elmtui components, including their creation, rendering, updates, and the crucial cleanup phase. It also covers component inheritance patterns and how state is managed within and across components.

<!-- AI-IMPORTANCE:level=critical -->
## 1. Component Lifecycle Phases

Elmtui components (`defcomponent`) progress through several distinct phases, each offering hooks for developers to manage resources and behavior.

### 1.1. Initialization (`:initform` and `initialize-instance`)

When a component is created (e.g., via `make-instance` or implicitly by `defapplication`), its slots are initialized. The `initialize-instance` method can be specialized for more complex setup logic.

### 1.2. Mounting (Implicit)

Components are implicitly "mounted" when they become part of the active component tree, typically when rendered by a parent component or set as the root component of an application. There isn't an explicit `mount` hook, but `render` often serves as the first point of activity.

### 1.3. Rendering (`render` method)

The `render` method is the core of a component, responsible for generating the visual representation (a `view` DSL form) based on its current state and properties. This method is called whenever the component needs to be redrawn, often triggered by state changes.

```lisp
(defmethod elmtui.component:render ((component my-component) &key parent-data)
  ;; ... logic to generate view based on component's state and parent-data
  (elmtui.view:text (format nil "Hello from ~a" (getf (elmtui.component:state component) :name))))
```

### 1.4. Updating (`handle-message` and state changes)

Components react to messages via the `handle-message` generic function. Messages can originate from user input, other components, or the application itself. Handling a message often involves updating the component's local state or dispatching further messages.

```lisp
(defmethod elmtui.component:handle-message ((component my-component) (message (eql :increment)))
  (let ((current-count (getf (elmtui.component:state component) :count 0)))
    (setf (getf (elmtui.component:state component) :count) (1+ current-count))
    ;; Return T to indicate message was handled, NIL to propagate
    t))
```

### 1.5. Cleanup/Unmounting (`cleanup` method)

<!-- AI-IMPORTANCE:level=critical -->
The `cleanup` method is invoked when a component is removed from the active component tree or when the application is shutting down. This phase is crucial for releasing resources, such as:
*   Removing observers from global models.
*   Closing file handles or network connections.
*   Deregistering event handlers.

**It is a critical documentation gap that this phase was previously incomplete.** Proper cleanup prevents memory leaks and ensures application stability.

```lisp
(defmethod elmtui.component:cleanup ((component my-component))
  (format t "~&Cleaning up resources for ~a~%" component)
  ;; Example: Remove an observer if the component was observing a model
  (when (slot-boundp component 'my-observer)
    (elmtui.state:remove-observer *app-model* (slot-value component 'my-observer))))
```

## 2. Component Inheritance Patterns

Elmtui components can inherit from other components, allowing for code reuse and the creation of specialized UI elements.

### 2.1. Simple Inheritance

Components can inherit slots and methods from parent components using standard Common Lisp object-oriented programming (CLOS) mechanisms.

```lisp
(defcomponent base-button ()
  ((label :initarg :label :accessor button-label)
   (on-click :initarg :on-click :accessor button-on-click)))

(defmethod elmtui.component:render ((component base-button) &key)
  (elmtui.view:button (button-label component) (button-on-click component)))

(defcomponent primary-button (base-button)
  ()) ; Inherits label and on-click, can specialize render/handle-message

(defmethod elmtui.component:render ((component primary-button) &key)
  (elmtui.view:with-style (:background :blue :foreground :white)
    (call-next-method))) ; Call parent's render method and apply style
```

### 2.2. Mixin Patterns

For reusable behaviors, mixin classes can be defined and included in component definitions.

```lisp
(defclass focusable-mixin ()
  ((focused :initform nil :accessor focusedp)))

(defmethod elmtui.component:handle-message :around ((component focusable-mixin) message)
  (cond
    ((eq message :focus) (setf (focusedp component) t))
    ((eq message :blur) (setf (focusedp component) nil))
    (t (call-next-method))))

(defcomponent input-field (focusable-mixin)
  ((value :initform "" :accessor input-value)))
```

## 3. Component State Management

Components manage both local and global state.

### 3.1. Local State

Each component instance can hold its own private state, typically in a plist accessible via `elmtui.component:state`. This state is specific to the component instance and is not directly shared with other components unless explicitly passed down.

```lisp
(defcomponent counter-component ()
  ((state :initform '(:count 0))))

(defmethod elmtui.component:handle-message ((component counter-component) (message (eql :increment)))
  (setf (getf (elmtui.component:state component) :count)
        (1+ (getf (elmtui.component:state component) :count)))
  t)
```

### 3.2. Global State (via `defmodel`)

Components often interact with the application's global state, managed by `defmodel` instances. Components can observe changes in the global model and re-render accordingly.

```lisp
;; Assuming *app-model* is a defmodel instance
(defcomponent display-global-counter ()
  ((observer :initform nil)))

(defmethod elmtui.component:initialize-instance :after ((component display-global-counter) &rest initargs)
  (declare (ignore initargs))
  (setf (slot-value component 'observer)
        (elmtui.state:add-observer *app-model* :counter
                                  (lambda (new-value old-value)
                                    (declare (ignore old-value))
                                    (format t "~&Global counter changed to: ~a~%" new-value)
                                    ;; Trigger re-render or update local state
                                    ))))

(defmethod elmtui.component:cleanup ((component display-global-counter))
  (when (slot-value component 'observer)
    (elmtui.state:remove-observer *app-model* (slot-value component 'observer)))
  (call-next-method)) ; Ensure parent cleanup methods are called
```

## Related Resources

*   [App Creation and Configuration Architecture Guide](../../architecture/app-creation-configuration.md)
*   [State Transactions Guide](../tea-state/state-transactions.md)
*   [Application Patterns Documentation](../app/application-patterns.md)
*   [Creating Applications Developer Guide](../../dev-guides/creating-applications.md)