# Replace Static Registries with CLOS Polymorphism - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace static hash-table registries (*dsl-type-to-component-class*, *widgets*) with CLOS generic functions and class metadata.

**Architecture:** Single `dsl-type` generic function handles all DSL type resolution. `defcomponent` auto-generates methods. Metadata stored in class metaobject via custom metaclass. Recursive resolution enables variants and aliases.

**Tech Stack:** Common Lisp CLOS (MOP), FiveAM testing framework

---

## Task 1: Create Component Metaclass

**Files:**
- Create: `src/ui/component-metaclass.lisp`
- Test: `tests/component-metaclass-tests.lisp`

**Step 1: Write the failing test**

```lisp
;; tests/component-metaclass-tests.lisp
(uiop:define-package :elmtui-tests.component-metaclass
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.component-metaclass
                #:component-class
                #:class-metadata
                #:make-metadata))

(in-package :elmtui-tests.component-metaclass)

(def-suite component-metaclass-suite
  :description "Tests for component metaclass")

(in-suite component-metaclass-suite)

(test component-class-metaclass-creation
  "Creating a class with component-class metaclass"
  (defclass test-component ()
    ((slot1 :initarg :slot1))
    (:metaclass component-class))
  (is (typep (find-class 'test-component) 'component-class)))

(test class-metadata-storage
  "Storing and retrieving metadata from class"
  (defclass test-component-2 ()
    ()
    (:metaclass component-class)
    (:metadata :test-metadata))
  (is (eql :test-metadata (class-metadata (find-class 'test-component-2)))))
```

**Step 2: Run test to verify it fails**

Run: `sbcl --load run-tests-clpm.lisp --eval '(fiveam:run! :elmtui-tests.component-metaclass)'`
Expected: FAIL with "component-class metaclass not defined"

**Step 3: Write minimal implementation**

```lisp
;; src/ui/component-metaclass.lisp
(uiop:define-package :elmtui.ui.component-metaclass
  (:use :cl)
  (:import-from :closer-mop #:defclass #:direct-slot-definition-class)
  (:export #:component-class
           #:class-metadata
           #:make-metadata))

(in-package :elmtui.ui.component-metaclass)

;; Define the metaclass
(defclass component-class (standard-class)
  ((%metadata :initarg :metadata :accessor class-metadata :initform nil))
  (:documentation "Metaclass for UI components that stores metadata."))

;; Ensure metadata is properly initialized
(defmethod initialize-instance :after ((class component-class) &key metadata)
  (setf (class-metadata class) metadata))

;; Helper for creating metadata structures
(defun make-metadata (&key props documentation examples)
  "Create a metadata structure for component documentation."
  (list :props props
        :documentation documentation
        :examples examples))
```

**Step 4: Update elmtui.asd**

Add to `elmtui.asd` in the ui module:
```lisp
(:file "component-metaclass")
```

**Step 5: Run test to verify it passes**

Run: `sbcl --load run-tests-clpm.lisp --eval '(fiveam:run! :elmtui-tests.component-metaclass)'`
Expected: PASS

**Step 6: Commit**

```bash
git add src/ui/component-metaclass.lisp tests/component-metaclass-tests.lisp elmtui.asd
git commit -m "feat: add component metaclass for metadata storage"
```

---

## Task 2: Create DSL Resolution System

**Files:**
- Create: `src/ui/dsl-resolution.lisp`
- Test: `tests/dsl-resolution-tests.lisp`

**Step 1: Write the failing test**

```lisp
;; tests/dsl-resolution-tests.lisp
(uiop:define-package :elmtui-tests.dsl-resolution
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.dsl-resolution
                #:dsl-type
                #:resolve-dsl-type))

(in-package :elmtui-tests.dsl-resolution)

(def-suite dsl-resolution-suite
  :description "Tests for DSL type resolution")

(in-suite dsl-resolution-suite)

(test resolve-dsl-type-symbol-terminates
  "Direct class symbol terminates recursion"
  (multiple-value-bind (class props)
      (resolve-dsl-type 'test-widget)
    (is (eq class 'test-widget))
    (is (null props))))

(test resolve-dsl-type-list-injects-props
  "List form injects extra props"
  (defmethod dsl-type ((type (eql :base)) &optional props)
    (values 'base-widget props))
  (multiple-value-bind (class props)
      (resolve-dsl-type '(:base :extra "data"))
    (is (eq class 'base-widget))
    (is (equal (getf props :extra) "data"))))

(test dsl-type-variant-adds-default-props
  "Variant adds default props"
  (defmethod dsl-type ((type (eql :variant)) &optional props)
    (values 'base-widget '(:default "value")))
  (multiple-value-bind (class props)
      (dsl-type :variant)
    (is (eq class 'base-widget))
    (is (equal (getf props :default) "value"))))

(test dsl-type-chaining
  "Variants can chain to other variants"
  (defmethod dsl-type ((type (eql :chained)) &optional props)
    (dsl-type :base (append props '(:added :value))))
  (multiple-value-bind (class props)
      (dsl-type :chained)
    (is (eq class 'base-widget))
    (is (equal (getf props :added) :value))))
```

**Step 2: Run test to verify it fails**

Run: `sbcl --load run-tests-clpm.lisp --eval '(fiveam:run! :elmtui-tests.dsl-resolution)'`
Expected: FAIL with "dsl-resolution package not found"

**Step 3: Write minimal implementation**

```lisp
;; src/ui/dsl-resolution.lisp
(uiop:define-package :elmtui.ui.dsl-resolution
  (:use :cl)
  (:export #:dsl-type
           #:resolve-dsl-type))

(in-package :elmtui.ui.dsl-resolution)

;; Core generic function for DSL type resolution
(defgeneric dsl-type (type &optional props)
  (:documentation "Resolve DSL TYPE to a component class.
Returns (values class props) where CLASS is the component class symbol
and PROPS are accumulated/default properties."))

;; Default termination: when TYPE is a class symbol, return it
(defmethod dsl-type ((type symbol) &optional props)
  "TYPE is a class symbol - terminate recursion."
  (values type props))

;; List handling: first element is type, rest are extra props
(defmethod dsl-type ((type list) &optional props)
  "TYPE is a list - first element is the real type, rest are extra props."
  (dsl-type (first type) (append (rest type) props)))

;; Recursive resolution function
(defun resolve-dsl-type (item &optional props)
  "Resolve ITEM to a component class with accumulated PROPS.
Returns (values class final-props).

ITEM can be:
- a keyword  : look up via dsl-type generic (recurses)
- a list     : (car list) is the type, (cdr list) are extra props
- a symbol   : it's a class (terminates)"
  (etypecase item
    ;; List: first element is type, rest are additional props
    (list (resolve-dsl-type (first item) (append (rest item) props)))
    ;; Keyword: look up via dsl-type generic (recurse)
    (keyword (dsl-type item props))
    ;; Symbol: terminate - it's a class
    (symbol (values item props))))
```

**Step 4: Update elmtui.asd**

Add to `elmtui.asd` in the ui module:
```lisp
(:file "dsl-resolution")
```

**Step 5: Run test to verify it passes**

Run: `sbcl --load run-tests-clpm.lisp --eval '(fiveam:run! :elmtui-tests.dsl-resolution)'`
Expected: PASS

**Step 6: Commit**

```bash
git add src/ui/dsl-resolution.lisp tests/dsl-resolution-tests.lisp elmtui.asd
git commit -m "feat: add DSL resolution system with recursive type lookup"
```

---

## Task 3: Update Core API

**Files:**
- Modify: `src/api.lisp`
- Test: `tests/api-tests.lisp`

**Step 1: Write the failing test**

```lisp
;; tests/api-tests.lisp - Add to existing tests
(test dsl-type-generic-exported
  "dsl-type generic is exported from elmtui.api"
  (is (fboundp 'elmtui.api:dsl-type))
  (is (symbol-package 'elmtui.api:dsl-type)))
```

**Step 2: Run test to verify it fails**

Run: `sbcl --load run-tests-clpm.lisp --eval '(fiveam:run! :elmtui-tests.api)'`
Expected: FAIL with "dsl-type not exported from elmtui.api"

**Step 3: Modify src/api.lisp**

Replace entire content with:

```lisp
(uiop:define-package #:elmtui.api
  (:use :cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-info)
  (:export #:dsl-type))

(in-package :elmtui.api)

;; Import dsl-type from ui.dsl-resolution
(defgeneric dsl-type (type &optional props)
  (:documentation "Resolve DSL TYPE to a component class.
This generic function is the core of the polymorphic DSL resolution system.

Methods are defined per component or variant:
- Keywords resolve to classes
- Lists inject extra props
- Symbols terminate (are classes)

Returns (values class props)."))
```

**Step 4: Run test to verify it passes**

Run: `sbcl --load run-tests-clpm.lisp --eval '(fiveam:run! :elmtui-tests.api)'`
Expected: PASS

**Step 5: Commit**

```bash
git add src/api.lisp tests/api-tests.lisp
git commit -m "refactor: replace get-component-class-for-dsl-type with dsl-type generic"
```

---

## Task 4: Update elmtui.ui.api for New Resolution

**Files:**
- Modify: `src/ui/api.lisp`
- Modify: `src/app/api.lisp`

**Step 1: Update src/ui/api.lisp imports**

Modify package definition to import from new modules:

```lisp
(uiop:define-package :elmtui.ui.api
  (:use :cl #:log4cl)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.utils #:ensure-keyword #:get-path)
  (:import-from :elmtui.ui.dsl-resolution #:dsl-type #:resolve-dsl-type)
  (:import-from :elmtui.ui.component-metaclass #:component-class #:class-metadata)
  (:export
   ;; Component Class & Generics
   #:initialize-components-from-dsl
   #:instantiate-component-from-dsl
   #:component #:component-id #:component-type
   #:init #:update #:view #:destroy ;; Core lifecycle
   #:component-children #:component-width #:component-height
   #:resolve-component-node
   #:layout-node
   #:id-from-path #:get-path
   ;; State Helpers
   #:+component-state-root+
   #:component-state-path #:get-component-property #:make-state-patch #:component-state-map-path
   ;; Update Macro and its local functions
   #:with-update-patch #:add-patch #:add-command #:get-property
   #:normalize-update-args
   ;; DSL Resolution
   #:dsl-type #:resolve-dsl-type
   ;; Metadata
   #:class-metadata #:widget-metadata
   ;; Note: elmtui.state:update-result is the return type for update methods
   #:id ; Export the new generic function
   #:make-update-result
   ))
```

**Step 2: Update instantiate-component-from-dsl**

Replace `get-component-class-for-dsl-type` with `resolve-dsl-type`:

```lisp
;; Find old implementation in src/ui/api.lisp (around line 160)
;; Replace with:

(defmethod instantiate-component-from-dsl ((dsl-form list) &key parent-id)
  "Instantiate a component from DSL form using polymorphic resolution.

DSL-FORM is a list like (:my-component :prop1 val1 :prop2 val2)
PARENT-ID is the parent component's id path."
  (log-debug "instantiate-component-from-dsl: ~S" dsl-form)
  (unless dsl-form
    (error "Cannot instantiate from empty DSL form"))

  ;; Resolve the DSL type to class and accumulated props
  (multiple-value-bind (component-class default-props)
      (resolve-dsl-type (first dsl-form))
    (log-debug "  Resolved ~S to class ~S with default props: ~S"
               (first dsl-form) component-class default-props)

    ;; Merge props: default props from resolution, then explicit props from DSL
    (let* ((explicit-props (extract-props-from-dsl (rest dsl-form)))
           (merged-props (merge-props default-props explicit-props))
           (component-id (or (getf explicit-props :id)
                            (compute-id parent-id (first dsl-form)))))

      (log-debug "  Creating instance of ~S with id ~S and props ~S"
                 component-class component-id merged-props)

      ;; Create the component instance
      (apply #'make-instance component-class
             :id component-id
             :props merged-props
             (flatten-prop-plist merged-props)))))
```

**Step 3: Update src/app/api.lisp**

Remove registry-related imports and exports:

```lisp
;; Remove these lines:
;; (:import-from :elmtui.core.globals #:*dsl-type-to-component-class*)
;; (:import-from :elmtui.api #:get-component-class-for-dsl-type)

;; Remove these from exports:
;; #:register-dsl-component-type #:get-component-class-for-dsl-type
;; #:with-temporary-dsl-component-registry
;; #:clear-dsl-component-registry
```

**Step 4: Run tests**

Run: `./rt.sh`
Expected: Existing tests should still pass (we haven't changed behavior yet)

**Step 5: Commit**

```bash
git add src/ui/api.lisp src/app/api.lisp
git commit -m "refactor: update ui.api and app.api for polymorphic DSL resolution"
```

---

## Task 5: Update defcomponent Macro - Auto-generate dsl-type Methods

**Files:**
- Modify: `src/ui/defcomponent.lisp`

**Step 1: Add DSL type inference helper**

Add to `src/ui/defcomponent.lisp`:

```lisp
;; Helper to infer DSL type from class name
(defun infer-dsl-type-from-class-name (class-name)
  "Infer DSL keyword from class name.
- my-button => :my-button
- ui.widgets:label => :label (strips package)
- my-component => :my-component"
  (let ((name (symbol-name class-name)))
    ;; Find the last colon if present (package qualifier)
    (let ((colon-pos (position #\: name :from-end t)))
      (if colon-pos
          ;; Strip package prefix
          (make-keyword (subseq name (1+ colon-pos)))
          ;; No package, just keyword-ize
          (make-keyword name)))))
```

**Step 2: Update defcomponent macro expansion**

Find the macro expansion in `defcomponent` and add the `dsl-type` method generation:

```lisp
;; In the macro expansion, after the class definition, add:

;; Auto-generate dsl-type method for this component
(let* ((inferred-dsl-type (infer-dsl-type-from-class-name component-class-name))
       (explicit-dsl-type (getf options :dsl-type))
       (dsl-type-to-use (or explicit-dsl-type inferred-dsl-type)))
  `(defmethod elmtui.api:dsl-type ((type (eql ,dsl-type-to-use)) &optional props)
     (values ',component-class-name props)))
```

**Step 3: Add test for auto-generation**

```lisp
;; tests/defcomponent-tests.lisp
(test defcomponent-auto-generates-dsl-type-method
  "defcomponent automatically generates dsl-type method"
  (defcomponent test-auto-widget (component))
  (multiple-value-bind (class props)
      (elmtui.api:dsl-type :test-auto-widget)
    (is (eq class 'test-auto-widget))
    (is (null props))))
```

**Step 4: Run tests**

Run: `sbcl --load run-tests-clpm.lisp --eval '(fiveam:run! :elmtui-tests.defcomponent)'`
Expected: PASS

**Step 5: Commit**

```bash
git add src/ui/defcomponent.lisp tests/defcomponent-tests.lisp
git commit -m "feat: defcomponent auto-generates dsl-type methods"
```

---

## Task 6: Add Metadata Support to defcomponent

**Files:**
- Modify: `src/ui/defcomponent.lisp`

**Step 1: Update defcomponent to handle :metadata option**

Modify the macro to extract and pass metadata:

```lisp
;; In defcomponent macro, extract metadata from options
(let* ((metadata-option (getf options :metadata))
       (has-metadata-p metadata-option)
       (metaclass (if has-metadata-p
                      'elmtui.ui.component-metaclass:component-class
                      'standard-class)))
  ;; Update class definition to use metaclass
  `(defclass ,component-class-name ,effective-superclasses
     ,slots
     (:metaclass ,metaclass)
     ,@other-class-options
     ,@(when has-metadata-p
         `((:metadata ,metadata-option))))))
```

**Step 2: Add test for metadata storage**

```lisp
;; tests/defcomponent-tests.lisp
(test defcomponent-metadata-storage
  "defcomponent with :metadata option stores metadata in class"
  (defcomponent test-meta-widget (component)
    (:metadata (:props ((:label string t)) :doc "Test widget")))
  (let ((metadata (elmtui.ui.component-metaclass:class-metadata
                   (find-class 'test-meta-widget))))
    (is (not (null metadata)))
    (is (equal (getf metadata :doc) "Test widget"))))
```

**Step 3: Run tests**

Run: `sbcl --load run-tests-clpm.lisp --eval '(fiveam:run! :elmtui-tests.defcomponent)'`
Expected: PASS

**Step 4: Commit**

```bash
git add src/ui/defcomponent.lisp tests/defcomponent-tests.lisp
git commit -m "feat: defcomponent supports metadata via class metaclass"
```

---

## Task 7: Migrate Existing Components

**Files:**
- Modify: All `defcomponent` forms in `src/ui/widgets/`

**Step 1: Update label component**

Modify `src/ui/widgets/label.lisp`:

```lisp
;; Before:
(defcomponent label (component)
  ...)

;; After - add metadata:
(defcomponent label (component)
  (:metadata
    (:props ((:text string nil :doc "Text to display")
             (:style list nil :doc "Style list")))
    (:documentation "A text label component")
    (:examples ("(label :text \"Hello\")")))
  ...)
```

**Step 2: Run label tests**

Run: `sbcl --load run-tests-clpm.lisp --eval '(fiveam:run! :elmtui-tests.label)'`
Expected: PASS

**Step 3: Update button component (if exists)**

Similar pattern - add metadata.

**Step 4: Update viewport component**

Modify `src/ui/widgets/viewport.lisp`:

```lisp
(defcomponent viewport (component)
  (:metadata
    (:props ((:children list nil :doc "Child components")))
    (:documentation "A viewport container")))
  ...)
```

**Step 5: Run all widget tests**

Run: `./rt.sh`
Expected: All existing widget tests still pass

**Step 6: Commit**

```bash
git add src/ui/widgets/
git commit -m "refactor: add metadata to existing components"
```

---

## Task 8: Update defapplication - Remove Registry

**Files:**
- Modify: `src/app/application.lisp`

**Step 1: Remove registry management from defapplication**

Find and remove these lines from the macro expansion:
- `with-temporary-dsl-component-registry`
- `clear-dsl-component-registry`
- Any `*dsl-type-to-component-class*` manipulation

**Step 2: Simplify app-config struct**

Remove registry-related slots if present.

**Step 3: Test application still works**

Create a minimal test app:
```lisp
(defapplication test-app
  :root-component-dsl '(:label :text "Test")
  :initial-state '()
  :update-fn #'test-update
  :view-fn #'test-view)
```

Run test application.

**Step 4: Commit**

```bash
git add src/app/application.lisp
git commit -m "refactor: remove registry management from defapplication"
```

---

## Task 9: Update DSL Processing

**Files:**
- Modify: `src/view/dsl.lisp`

**Step 1: Replace get-component-class-for-dsl-type with resolve-dsl-type**

Find all occurrences of `get-component-class-for-dsl-type` and replace with `resolve-dsl-type`.

**Step 2: Run DSL tests**

Run: `sbcl --load run-tests-clpm.lisp --eval '(fiveam:run! :elmtui-tests.dsl)'`
Expected: PASS

**Step 3: Commit**

```bash
git add src/view/dsl.lisp
git commit -m "refactor: use resolve-dsl-type in DSL processing"
```

---

## Task 10: Delete Obsolete Registry Files

**Files:**
- Delete: `src/app/dsl-type-registry.lisp`
- Delete: `src/ui/widget-registry.lisp`

**Step 1: Verify nothing references these files**

```bash
grep -r "dsl-type-registry" src/
grep -r "widget-registry" src/
```

Expected: No results (or only in comments)

**Step 2: Delete files**

```bash
rm src/app/dsl-type-registry.lisp
rm src/ui/widget-registry.lisp
```

**Step 3: Update elmtui.asd**

Remove these files from the `elmtui.asd` definition:
```lisp
;; Remove these lines:
;; (:file "app/dsl-type-registry")
;; (:file "ui/widget-registry")
```

**Step 4: Run full test suite**

Run: `./rt.sh`
Expected: All tests pass

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: remove obsolete registry files"
```

---

## Task 11: Add Variant Examples

**Files:**
- Create: `examples/variants.lisp`

**Step 1: Create example variants**

```lisp
;; examples/variants.lisp
(uiop:define-package :examples.variants
  (:use :cl)
  (:import-from :elmtui.api #:dsl-type))

(in-package :examples.variants)

;; Create a primary button variant
(defmethod dsl-type ((type (eql :primary-button)) &optional props)
  "A blue primary button variant."
  (values 'elmtui.ui.widgets.button:button
          (append props '(:color :blue))))

;; Create a large button variant that chains
(defmethod dsl-type ((type (eql :large-primary-button)) &optional props)
  "A large primary button."
  (dsl-type :primary-button (append props '(:size :large))))

;; Create a short alias
(defmethod dsl-type ((type (eql :btn)) &optional props)
  "Short alias for button."
  (dsl-type :button props))
```

**Step 2: Test variants work**

```lisp
;; tests/variant-tests.lisp
(test variant-resolution
  "Variants resolve correctly"
  (multiple-value-bind (class props)
      (elmtui.api:dsl-type :primary-button)
    (is (equal (getf props :color) :blue)))

(test variant-chaining
  "Variants can chain"
  (multiple-value-bind (class props)
      (elmtui.api:dsl-type :large-primary-button)
    (is (equal (getf props :color) :blue))
    (is (equal (getf props :size) :large))))
```

**Step 3: Commit**

```bash
git add examples/variants.lisp tests/variant-tests.lisp
git commit -m "feat: add DSL variant examples"
```

---

## Task 12: Update Documentation

**Files:**
- Modify: `docs/basic.md`
- Create: `docs/dsl-variants.md`

**Step 1: Update basic documentation**

Document the new approach in `docs/basic.md`.

**Step 2: Create variants guide**

Create `docs/dsl-variants.md` explaining how to create variants and aliases.

**Step 3: Commit**

```bash
git add docs/
git commit -m "docs: document polymorphic DSL resolution and variants"
```

---

## Summary

This implementation plan follows TDD principles with bite-sized tasks:

1. **Create infrastructure** (metaclass, DSL resolution) with tests first
2. **Update core APIs** to use new system
3. **Enhance defcomponent** to auto-generate methods and support metadata
4. **Migrate existing components** preserving functionality
5. **Clean up** obsolete registry code
6. **Add examples and documentation**

Each step includes:
- Failing test
- Implementation
- Passing test
- Commit

Estimated: 12 tasks × ~15 minutes each = ~3 hours of focused work.
