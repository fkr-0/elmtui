# Elmtui Architecture: Staged Rendering Pipeline (TEA + 7-Stage View)

This document explains the fundamental architecture and operation of Elmtui, which strictly follows The Elm Architecture (TEA) principles for building reliable, maintainable terminal user interfaces.

## Core TEA Principles in Elmtui

### 1. **Single Source of Truth**
All application state resides in a single, centralized `application-state` object. Components do not store behavioral state in their instance variables.

### 2. **Unidirectional Data Flow**
```
State → View → Events → Messages → Update → State
```

### 3. **Pure Functions**
- **View functions** are pure: `(state) → DSL data`
- **Update functions** are pure: `(state, message) → (patches, commands)`

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ Application     │    │ View Functions   │    │ View Pipeline    │    │ Terminal         │
│ State           │───▶│ (Pure)           │───▶│ Processing       │───▶│ Display          │
│ (Centralized)   │    │ Returns DSL Data │    │ DSL→Styled→Layout│    │                  │
└─────────────────┘    └──────────────────┘    └──────────────────┘    └──────────────────┘
         ▲                                                                       │
         │               ┌──────────────────┐    ┌──────────────────┐           │
         │               │ Update Functions │    │ Event System     │           │
         └───────────────│ (Pure)           │◀───│ Input Handling   │◀──────────┘
                         │ Returns Patches  │    │ Message Creation │
                         └──────────────────┘    └──────────────────┘
```

## Component Architecture

### Components are Lightweight Dispatch Targets

```lisp
;; ✅ CORRECT: Component classes have NO behavioral state slots
(defclass my-button (component)
  ()  ;; No state slots!
  (:documentation "Button component. State stored in app-state."))
```

### State Management via Patches

```lisp
;; State stored at: (:components :my-button-id :text) in app-state
(defmethod init ((component my-button) &key id-path initial-text &allow-other-keys)
  (values component
          ;; Patches: list of (path new-value) pairs
          (list (make-state-patch `(:components ,(id-from-path id-path) :text) 
                                  (or initial-text "Click Me")))
          nil)) ; No commands

(defmethod update ((component my-button) app-state message &key id-path)
  (case (car message)
    (:set-text 
     (make-update-result 
      :patches (list (make-state-patch `(:components ,(id-from-path id-path) :text) 
                                       (cdr message)))))
    (t (make-update-result)))) ; No changes

(defmethod view ((component my-button) app-state &key id-path)
  ;; ✅ Returns PURE DSL DATA, not objects
  (let ((text (get-component-property app-state id-path :text "Click Me")))
    `(:button :id ,(id-from-path id-path) :text ,text)))
```

## View Pipeline: Pure Data Transformation

### 1. Application View Function
```lisp
(defun app-view (app-state)
  "Application's main view function - returns pure DSL data"
  `(:container 
    :id :main-app
    :style (:width :fill :height :fill)
    :children ((:text :id :header :content "Welcome")
               (:button :id :submit :text "Submit")
               (:layout :id :main-layout 
                :display :flex 
                :children (...)))))
```

### 2. Pipeline Stages

```
Stage 1: Pure DSL Data
┌─────────────────────────────────────────────────────┐
│ (:container :id :main                               │
│   :style (:width :fill :height :fill)              │
│   :children ((:text :content "Hello")              │
│             (:button :text "Click")))              │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
Stage 2: UI Node Objects (ui-node)
┌─────────────────────────────────────────────────────┐
│ #<UI-NODE type: :container                          │
│           props: (:id :main :style (...))          │
│           children: (#<UI-NODE ...> #<UI-NODE ...>)│
└─────────────────────────────────────────────────────┘
                        │
                        ▼
Stage 3: Styled Nodes (styled-ui-node)
┌─────────────────────────────────────────────────────┐
│ #<STYLED-UI-NODE type: :container                   │
│                  style-map: (:bg-color #x000000...) │
│                  children: (...)>                   │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
Stage 4: Layout Calculation (laid-out-ui-node)
┌─────────────────────────────────────────────────────┐
│ #<LAID-OUT-UI-NODE layout-rect: (0 0 80 24)        │
│                    children with positions>         │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
Stage 5: Terminal Rendering
┌─────────────────────────────────────────────────────┐
│ ANSI escape sequences sent to terminal              │
└─────────────────────────────────────────────────────┘
```

## Layout Component Example

The layout component demonstrates perfect TEA compliance:

### Layout Component Definition
```lisp
(defcomponent layout ()
  ()  ;; No CLOS slots for state
  (:state
   ;; State schema - stored in app-state, not instance slots
   (display :flex :type keyword :documentation "Display mode")
   (flex-direction :column :type keyword)
   (children-ids nil :type list :documentation "Child component IDs")
   (width nil :type (or null integer string))
   (height nil :type (or null integer string))
   ;; ... more layout properties
   )
  
  (:view (local-state app-state self-id-path)
    ;; Pure function: reads state, returns DSL data
    (let* ((children-ids (getf local-state :children-ids))
           (display-mode (getf local-state :display :flex))
           (style-properties nil))
      
      ;; Build style properties based on layout mode
      (case display-mode
        (:flex 
         (setf (getf style-properties :flex-direction) 
               (getf local-state :flex-direction :column))
         (setf (getf style-properties :gap) 
               (getf local-state :gap 0)))
        (:grid 
         (setf (getf style-properties :grid-template-columns) 
               (getf local-state :grid-template-columns '("1fr")))))
      
      ;; Return pure DSL data with recursive child views
      (list :ui-element
            :id (id-from-path self-id-path)
            :type :layout
            :style style-properties
            :children (mapcar
                       (lambda (child-id)
                         ;; Recursively call child view methods
                         (let* ((child-path (append self-id-path (list child-id)))
                                (child-type (get-path child-path app-state :type)))
                           (if child-type
                               (let ((child-instance (make-instance child-type)))
                                 ;; Child view also returns pure DSL data
                                 (view child-instance app-state :id-path child-path))
                               `(:error "Child not found: " ,child-id))))
                       children-ids)))))
```

### Layout View Call Flow
```
Application View Function
        │
        ▼
(:layout :id :main-layout :children (...))  ← Pure DSL
        │
        ▼
Layout Component :view method called
        │
        ├─ Reads layout state from app-state
        ├─ Gets children-ids: (:child1 :child2 :child3)
        ├─ Builds style properties for flex/grid
        │
        └─ For each child:
           ├─ child-path = (:main-layout :child1)
           ├─ child-type = (get-path child-path app-state :type)
           ├─ child-instance = (make-instance child-type)
           └─ (view child-instance app-state :id-path child-path)
                    │
                    ▼
                Returns more pure DSL data
```

## Example Applications

### 1. Simple Button App
```lisp
(defapplication simple-button-app
  :initial-state-plist (list :should-quit nil)
  :root-component-dsl `(:button :id :main-button :text "Click to Quit")
  :update-fn (lambda (app-state message)
               (when (and (listp message) (eq (car message) :button-clicked))
                 (make-update-result :patches '((:should-quit t)))))
  :view-fn (lambda (app-state)
             `(:button :id :main-button :text "Click to Quit")))
```

### 2. Rainbow Stripes App (Idiomatic, with Root Viewport)
```lisp
(defun rainbow-content-view (app-state)
  "Returns pure DSL data for rainbow stripes, wrapped in a root viewport."
  (declare (ignore app-state))
  ;; ✅ CORRECT: Top-level is a root-viewport widget, anchoring below the cursor.
  `(elmtui.ui.widgets.root-viewport:root-viewport
    :id :rainbow-root-vp
    :props (:anchor :below-cursor)
    :children
      ((:container
        :id :rainbow-main-container
        :direction :row
        :height :fill
        :width :fill
        :style (:bg-color ,(rgb '(10 10 10)))
        :children
          ,(loop for (color-name class-name rgb-val) in *rainbow-colors*
                  collect `(:container
                            :id ,(intern (format nil "STRIPE-~A" (string color-name)) :keyword)
                            :classes ,(if (stringp class-name)
                                           class-name
                                           (string-downcase (symbol-name class-name)))
                            :children nil))))))
```

> **Note:** The root viewport ensures the rainbow container is anchored below the cursor, and all stripes are styled via classes and stylesheet.

### 3. Directory Listing App (Already Correct)
```lisp
:view-fn
(lambda (app-state)
  ;; ✅ Uses vbox and text DSL functions (pure data)
  (vbox :id :dirli-app-root 
        :style '(:width (:percent 100) :height (:percent 100))
        (text :value (format nil "Current Path: ~A" current-path))
        (view-listbox app-state :widget-id :main-listbox)  ; Delegates to component
        (text :value status-message)
        (text :value "Press C-q to quit.")))
```

## Common Anti-Patterns (What NOT to Do)

### ❌ WRONG: Creating Objects in View Functions
```lisp
(defun bad-view (app-state)
  ;; DON'T DO THIS - creates objects, not pure data
  (make-styled-node 
   :type :container
   :props (list :id :main)
   :children (list (make-styled-node ...))))
```

### ❌ WRONG: Storing State in Component Slots
```lisp
(defclass bad-component (component)
  ((text :accessor component-text :initform "")  ; DON'T DO THIS
   (enabled :accessor enabled-p :initform t)))   ; DON'T DO THIS
```

### ❌ WRONG: Mutating State Directly
```lisp
(defmethod update ((comp bad-component) app-state message)
  ;; DON'T DO THIS - direct mutation
  (setf (component-text comp) "new text")
  (make-update-result))
```

## Correct Patterns Summary

### ✅ Components as Dispatch Targets Only
```lisp
(defclass my-component (component)
  ()  ;; No behavioral state in slots
  (:documentation "All state in app-state"))
```

### ✅ View Functions Return Pure Data
```lisp
(defmethod view ((comp my-component) app-state &key id-path)
  `(:container :id ,(id-from-path id-path) 
               :children (...)))  ; Pure hiccup-like DSL
```

### ✅ State Changes via Patches
```lisp
(defmethod update ((comp my-component) app-state message &key id-path)
  (make-update-result 
   :patches (list (make-state-patch path new-value))
   :commands (list command)))
```

### ✅ Recursive Child View Calls
```lisp
;; Layout calls child views, each returns more pure DSL data
(mapcar (lambda (child-id)
          (view child-instance app-state :id-path child-path))
        children-ids)
```

## Benefits of This Architecture

1. **Predictable**: State changes only through well-defined update functions
2. **Debuggable**: All state centralized and observable
3. **Testable**: Pure functions are easy to unit test
4. **Maintainable**: Clear separation of concerns
5. **Reliable**: No hidden state mutations or side effects in views

## Development Workflow

1. **Define Components**: Use `defcomponent` with `:state` schema
2. **Implement `:init`**: Return patches for initial state setup
3. **Implement `:update`**: Handle messages, return patches and commands
4. **Implement `:view`**: Read state, return pure DSL data
5. **Compose in Application**: Use `defapplication` to wire everything together

This architecture ensures that Elmtui applications are robust, maintainable, and follow proven functional programming principles for UI development.
