# Design: Replace Static Registries with CLOS Polymorphism

**Date:** 2026-02-17
**Status:** Approved
**Author:** Claude (assisted)

## Overview

Eliminate static hash-table registries (`*dsl-type-to-component-class*`, `*widgets*`) in favor of CLOS generic functions and class metadata.

### Goals
- **a)** Eliminate explicit registration (reduce boilerplate)
- **c)** Better type safety and compile-time checking

### Current State
- Global hash-table maps `:label` → `'label` class
- `register-dsl-component-type` called manually in `dsl-type-registry.lisp`
- `get-component-class-for-dsl-type` generic for lookup
- Separate widget registry for metadata

### New State
- Single generic function `dsl-type` handles all resolution
- `defcomponent` automatically defines `dsl-type` method
- DSL type inferred from class name
- Variants via overriding `dsl-type` methods
- Metadata stored in class metaobject

---

## 1. Core Generic Function

```lisp
(defgeneric dsl-type (type &optional props)
  (:documentation "Resolve DSL TYPE to a class symbol.
Returns (values class props) - CLASS is the component class to instantiate,
PROPS are any accumulated/default properties."))
```

**Default termination method:**
```lisp
(defmethod dsl-type ((type symbol) &optional props)
  "TYPE is a class symbol - terminate recursion."
  (values type props))
```

**List handling (prop injection):**
```lisp
(defmethod dsl-type ((type list) &optional props)
  "TYPE is a list - first element is the real type, rest are extra props."
  (dsl-type (first type) (append (rest type) props)))
```

---

## 2. Updated `defcomponent` Macro

**Automatic DSL type inference:**
- `my-button` → `:my-button`
- `ui.widgets:label` → `:label` (package stripped)

**Macro expansion includes:**
```lisp
(defcomponent my-button (button)
  (:metadata ...)
  (:state ...)
  (:init ...)
  (:update ...)
  (:view ...))

;; Expands to include:
(defmethod dsl-type ((type (eql :my-button)) &optional props)
  (values 'my-button props))
```

**Explicit DSL type (override):**
```lisp
(defcomponent my-button (button)
  (:dsl-type :btn)  ; Explicit DSL type
  ...)
```

---

## 3. Variants and Aliases

**Creating variants with default props:**
```lisp
(defmethod dsl-type ((type (eql :primary-button)) &optional props)
  "A blue button variant."
  (values 'my-button (append props '(:color :blue))))
```

**Creating aliases:**
```lisp
(defmethod dsl-type ((type (eql :btn)) &optional props)
  "Short alias for button."
  (dsl-type :button props))
```

**Chaining variants:**
```lisp
(defmethod dsl-type ((type (eql :large-primary-button)) &optional props)
  (dsl-type :primary-button (append props '(:size :large))))
```

---

## 4. Metadata System

**Custom metaclass:**
```lisp
(defclass component-class (standard-class)
  ((metadata :initarg :metadata :accessor class-metadata))
  (:documentation "Metaclass storing component metadata."))
```

**Component with metadata:**
```lisp
(defcomponent my-button (button)
  (:metaclass component-class)
  (:metadata
    (:props ((:label string t :doc "Button text")
             (:on-click function nil :doc "Click handler")))
    (:documentation "A clickable button")
    (:examples ("(my-button :label \"Click\")")))
  (:state ...))
```

**Accessing metadata:**
```lisp
(class-metadata (find-class 'my-button))
(widget-metadata 'my-button)  ; Convenience wrapper
```

---

## 5. DSL Resolution Process

**Recursive resolution algorithm:**
```lisp
(defun resolve-dsl-type (item &optional props)
  "Resolve ITEM to a component class with accumulated PROPS.
Returns (values class final-props)."
  (etypecase item
    ;; List: first element is type, rest are additional props
    (list (resolve-dsl-type (first item) (append (rest item) props)))
    ;; Keyword: look up via dsl-type generic (recurse)
    (keyword (dsl-type item props))
    ;; Symbol: terminate - it's a class
    (symbol (values item props))))
```

**Example trace:**
```lisp
(resolve-dsl-type '(:large-primary-button :text "Hi"))
→ :large-primary-button with props '((:text "Hi"))
→ :primary-button with props '((:size :large) (:text "Hi"))
→ :button with props '((:color :blue) (:size :large) (:text "Hi"))
→ (values 'button '((:color :blue) (:size :large) (:text "Hi")))
```

---

## 6. Application Changes

**Simplified - no registry management:**
- Remove `*dsl-type-to-component-class*` manipulation
- Remove `with-temporary-dsl-component-registry`
- Remove `clear-dsl-component-registry`

**DSL processing works via generic dispatch:**
```lisp
(defview my-app-view (model)
  `(:my-layout
     (:my-button :text "Click")
     (:label :text "Hello")))

;; Each keyword resolved via dsl-type generic
```

---

## 7. Files to Modify

**DELETE:**
- `src/app/dsl-type-registry.lisp`
- `src/ui/widget-registry.lisp`

**MODIFY:**
- `src/api.lisp` - Replace `get-component-class-for-dsl-type` with `dsl-type`
- `src/app/api.lisp` - Remove registry exports
- `src/ui/api.lisp` - Update instantiation to use `resolve-dsl-type`
- `src/ui/defcomponent.lisp` - Add auto-generated methods, metadata support
- `src/app/application.lisp` - Remove registry management
- `src/view/dsl.lisp` - Use `resolve-dsl-type`
- `elmtui.asd` - Update build

**CREATE:**
- `src/ui/component-metaclass.lisp` - The metaclass
- `src/ui/dsl-resolution.lisp` - Resolution logic
- `tests/dsl-resolution-tests.lisp` - TDD tests

---

## 8. Testing Strategy

**Phase 1: TDD for new system**
- Test `resolve-dsl-type` with keywords, lists, class symbols
- Test variant prop injection
- Test chaining

**Phase 2: Regression tests**
- Keep all existing `defcomponent` tests
- Verify components still work after migration

**Phase 3: Integration tests**
- Test DSL resolution with real components
- Verify metadata accessibility

---

## 9. Implementation Order

1. Create new infrastructure (TDD)
   - `src/ui/component-metaclass.lisp`
   - `src/ui/dsl-resolution.lisp`
   - `tests/dsl-resolution-tests.lisp`

2. Update core APIs
   - `src/api.lisp`
   - `src/ui/api.lisp`

3. Update `defcomponent` macro
   - Auto-generated `dsl-type` method
   - Metadata support
   - DSL type inference

4. Migrate existing components
   - Update all `defcomponent` forms
   - Verify tests pass

5. Update `defapplication`
   - Remove registry management

6. Update DSL processing
   - `src/view/dsl.lisp`

7. Clean up
   - Delete obsolete files
   - Update `elmtui.asd`
