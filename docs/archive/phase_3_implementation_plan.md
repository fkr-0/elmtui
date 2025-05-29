# Phase 3 Implementation Plan

This document outlines the implementation steps for Phase 3 of the ELMTUI refactoring, focusing on the View System.

## 1. Widget System Standardization ✅

### 1.1. Create Widget Function Template ✅

Created a standardized template for widget functions with the new signature and utility macros:

```lisp
(defwidget-view view-widget (app-state :widget-id-var widget-id :model-var model)
  "Render the widget based on the application state.
   APP-STATE: The application state.
   WIDGET-ID: Unique identifier for this widget instance."
  ;; Widget implementation...
  )
```

Implemented in `src/ui/widgets/utils.lisp`.

### 1.2. Refactor Existing Widgets ✅

Converted key widgets to use the new standardized signature with `` suffix:

1. ✅ Button widget (`src/ui/widgets/button.lisp`)
2. ✅ Label widget (`src/ui/widgets/label.lisp`) 
3. ✅ Text Input widget (`src/ui/widgets/textinput.lisp`)
4. ✅ Listbox widget (`src/ui/widgets/listbox.lisp`)
5. ⏳ Form widget (pending)
6. ✅ Scrollable Container widget (`src/ui/widgets/scrollable-container.lisp`)

Added backward compatibility wrappers to ease transition.

### 1.3. Update Widget Documentation ✅

1. ✅ Created comprehensive documentation in `docs/widget-authoring.md`
2. ✅ Documented standardized patterns and best practices
3. ✅ Created migration guide in `docs/widget-migration-guide.md`

### 1.4. Create Widget Test Suite ⏳

1. ✅ Added examples in `examples/comprehensive-widgets-demo.lisp`
2. ⏳ Need to implement standard tests for each widget
3. ⏳ Integration tests need to be updated

## 2. View DSL Enhancement ✅

### 2.1 Update Element Mapping ✅

1. ✅ Extended `*dsl-element-map*` with all standardized widgets in `src/view/dsl.lisp`
2. ✅ Created documentation in `docs/view-dsl-reference.md`
3. ✅ Ensured mapped functions follow the standardized signature

### 2.2 Enhance Widget Argument Processing ✅

Updated the `%expand-element` function in `dsl.lisp` to:
1. ✅ Extract `:widget-id` from props or generate one if not provided
2. ✅ Pass `app-state` as first argument to widget view functions
3. ✅ Pass remaining props as keyword arguments with proper type conversion

### 2.3 Improve DSL Error Handling and Debugging ✅

1. ✅ Added detailed error messages for malformed DSL expressions
2. ✅ Implemented debug mode for macro expansion with `*dsl-debug*` variable
3. ✅ Added validation for common widget properties

### 2.4 Add Support for Component Composition ✅

1. ✅ Created utilities for widget composition in `utils.lisp`
2. ✅ Documented composition patterns in `view-dsl-reference.md`

## 3. Rendering System Improvements ⏳

### 3.1 Enhance View Diffing ✅

1. ✅ Implemented robust diff algorithm in `src/view/diff-renderer.lisp`
2. ✅ Optimized for terminal UIs with minimal update strategy
3. ✅ Added debugging output for view diffing

### 3.2 Layout System Debugging ✅

1. ✅ Created layout debugging mode in `src/view/layout-debug.lisp`
2. ✅ Implemented visual indicators for margins, borders, and padding
3. ✅ Added detailed logging for layout decisions

### 3.3 Complete Grid Layout ⏳

1. ⏳ Implementation of CSS Grid layout features in progress
2. ⏳ Support for named grid areas partially implemented
3. ⏳ Tests for grid layout scenarios needed

### 3.4 Platform Abstraction Cleanup ✅

1. ✅ Ensured clean separation between view and rendering
2. ✅ Documented platform requirements in code comments
3. ✅ Created utility functions for platform-specific optimizations

## 4. Integration with Async Infrastructure ⏳

### 4.1 Connect View Updates to State Changes ✅

1. ✅ Created observer hooks in `src/view/reactive.lisp`
2. ✅ Implemented view invalidation based on state changes
3. ✅ Added debouncing mechanism for frequent updates

### 4.2 Background Rendering ⏳

1. ✅ Set up worker thread infrastructure
2. ⏳ Message passing for render results partially implemented
3. ⏳ Priority handling for critical updates needs more work

### 4.3 Animation Framework Foundation ⏳

1. ✅ Created basic animation primitives in `src/view/reactive.lisp`
2. ⏳ Timer-based animation updates in progress
3. ⏳ Animation system documentation needed

## Implementation Progress

| Component | Status | Completion |
|-----------|--------|------------|
| Widget System Standardization | ✅ | 90% |
| Widget Documentation | ✅ | 100% |
| Widget Testing | ⏳ | 50% |
| View DSL Enhancement | ✅ | 100% |
| Rendering Improvements | ✅ | 80% |
| Layout System | ⏳ | 60% |
| Async Infrastructure | ⏳ | 70% |

## Deliverables

1. ✅ Updated widget files with standardized signatures
   - Created button.lisp, label.lisp, textinput.lisp, listbox.lisp, and scrollable-container.lisp
   - Created utils.lisp with helper functions and macros

2. ✅ Enhanced DSL implementation 
   - Implemented dsl.lisp with better element mapping
   - Added improved error handling and debugging

3. ✅ Improved rendering with debugging capabilities
   - Created diff-renderer.lisp for optimized updates
   - Implemented layout-debug.lisp for visual debugging

4. ⏳ Async view update integration
   - Created reactive.lisp foundation
   - Background rendering in progress

5. ✅ Comprehensive documentation
   - Created widget-authoring.md
   - Created view-dsl-reference.md 
   - Added widget-migration-guide.md

6. ⏳ Test suite for new functionality
   - Added comprehensive-widgets-demo.lisp
   - Need more specific test cases

## Next Steps

1. Complete the remaining widgets (form)
2. Finish implementation of the grid layout system
3. Complete the animation framework
4. Create comprehensive tests for all widgets
5. Update the migration guide with more examples
6. Create automated tests for backward compatibility
