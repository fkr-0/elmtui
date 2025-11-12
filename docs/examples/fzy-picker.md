---
# AI Metadata Tags
ai_keywords: [fzy-picker, cl-fzy, fuzzy search, defapplication, example application, state-ref, make-update-result, key events, terminal UI, picker interface]
ai_contexts: [usage, example, implementation]
ai_relations: [
  "./rainbow-app.md",
  "../modules/app/overview.md", 
  "../modules/app/implementation.md",
  "../modules/view/overview.md",
  "../modules/state/overview.md",
  "../USER_GUIDE.md"
]
---

# fzy-picker Example Application

<!-- AI-IMPORTANCE:level=high -->

## Overview

The fzy-picker example demonstrates how to build a fuzzy search interface using Elmtui and the cl-fzy library. It provides a terminal-based picker similar to fzf/fzy tools, showcasing proper [`defapplication`](../modules/app/overview.md) usage, state management patterns, and external library integration.

## Current Status

<!-- AI-IMPORTANCE:level=critical -->

**Current State:** Code structure fixes completed, but application has **known dependency and threading issues** that prevent full functionality.

### ✅ **Completed Fixes (2025-09-02)**

#### 1. **Application Structure Alignment**
- Fixed [`defapplication`](../modules/app/overview.md) pattern to match working examples
- Corrected root component DSL structure (`:container` vs `:layout`)
- Aligned view function with application framework patterns

#### 2. **State Management Corrections**
- Replaced direct `getf` calls with proper [`state-ref`](../modules/state/overview.md) API usage
- Fixed patch structure format throughout the application
- Corrected [`make-update-result`](../modules/state/overview.md) usage patterns

#### 3. **cl-fzy Integration Fixes**
- Replaced private API calls (`cl-fzy::`) with public functions
- Implemented proper cl-fzy object initialization and usage
- Added comprehensive key event handling

#### 4. **Critical Runtime Corrections**
- Fixed missing function call naming convention
- Added proper error handling and quit functionality
- Implemented navigation and selection features

### ❌ **Known Issues**

<!-- AI-CONTEXT-START:type=implementation -->
- **Dependency Issues**: cl-fzy library integration problems
- **Threading Issues**: Event loop and threading conflicts
- **Runtime Errors**: Application fails to start due to dependency resolution

**Note**: While the code structure has been significantly improved and now follows Elmtui patterns correctly, the application cannot run until these underlying issues are resolved.
<!-- AI-CONTEXT-END -->

## Key Features Demonstrated

- **Fuzzy Search Interface**: Interactive text filtering with cl-fzy
- **Keyboard Navigation**: Up/Down arrows, j/k keys, Enter selection
- **State Management**: Proper Elmtui TEA state patterns
- **External Library Integration**: cl-fzy library usage patterns
- **Terminal I/O**: stdin reading and stdout selection output

## Implementation Highlights

<!-- AI-CONTEXT-START:type=implementation -->

### Application Structure
```lisp
(defapplication fzy-picker
  :root-viewport-id :fzy-root
  :initial-state-plist (let ((init-state (initial-state)))
                         (list :choices (getf init-state :choices)
                               :query (getf init-state :query)
                               :height (getf init-state :height)
                               :selected-index (getf init-state :selected-index)
                               :should-quit nil))
  :root-component-dsl '(:container :id :fzy-widget)
  :update-fn 'fzy-update
  :view-fn 'fzy-view)
```

### State Management Pattern
- Uses [`state-ref`](../modules/state/overview.md) for safe state access
- Proper [`make-update-result`](../modules/state/overview.md) with `:patches` format
- Maintains search state, selection index, and UI dimensions

### Key Event Handling
- **Navigation**: `:up`, `:down`, `:j`, `:k` keys
- **Selection**: `:enter` key to choose current item
- **Query Editing**: Character input and `:backspace`
- **Quit Commands**: `:escape`, `Ctrl+C`, `q` key

### cl-fzy Integration
```lisp
(let* ((opts (make-instance 'options))
       (chs  (make-instance 'choices)))
  (choices-init chs opts)
  (choices-search chs query)
  (choices-get chs index))
```
<!-- AI-CONTEXT-END -->

## How to Run (Once Fixed)

<!-- AI-CONTEXT-START:type=usage -->

**Prerequisites (when dependency issues are resolved):**
1. cl-fzy library must be properly installed and available
2. Threading issues must be resolved

**Intended Usage:**
```bash
# Pipe input to the picker
echo -e "option1\noption2\noption3" | lisp-script fzy-picker
# Or use in REPL
(elmtui.examples.fzy-picker:run)
```

**Expected Behavior:**
- Read lines from stdin or provide test data
- Display interactive fuzzy search interface
- Allow navigation and filtering with keyboard
- Output selected item to stdout on Enter
<!-- AI-CONTEXT-END -->

## Architecture Lessons Learned

<!-- AI-IMPORTANCE:level=high -->

### Proper Elmtui Patterns Applied
1. **Application Definition**: Correct [`defapplication`](../modules/app/overview.md) macro usage
2. **State Access**: Consistent [`state-ref`](../modules/state/overview.md) API usage
3. **Update Results**: Proper [`make-update-result`](../modules/state/overview.md) patch format
4. **Component Structure**: Root component DSL alignment

### External Library Integration Patterns
1. **Public API Usage**: Avoid private symbol access (`package::symbol`)
2. **Object Lifecycle**: Proper initialization and state management
3. **Error Handling**: Graceful degradation for missing dependencies

### Event Handling Best Practices
1. **Comprehensive Key Mapping**: Multiple key bindings for common actions
2. **State Validation**: Check bounds and availability before operations
3. **Clear Event Classification**: Distinct handling for different event types

## Troubleshooting Guide

### Common Issues During Development

1. **`getf` vs `state-ref` Errors**
   - **Problem**: Direct property list access in state management
   - **Solution**: Use [`state-ref`](../modules/state/overview.md) API consistently

2. **Patch Format Errors**
   - **Problem**: Incorrect patch structure in [`make-update-result`](../modules/state/overview.md)
   - **Solution**: Use `(:patches '((:key value)))` format

3. **Component DSL Mismatch**
   - **Problem**: Root component structure doesn't match framework expectations
   - **Solution**: Align with working examples (`:container` pattern)

4. **Private API Dependencies**
   - **Problem**: Using `cl-fzy::` private symbols
   - **Solution**: Use only exported public functions

## Source Location

- [`examples/fzy-picker.lisp`](../../examples/fzy-picker.lisp)

## Related Documentation

- [App Module Overview](../modules/app/overview.md)
- [App Module Implementation](../modules/app/implementation.md)
- [State Module Overview](../modules/state/overview.md)
- [View Module Overview](../modules/view/overview.md)
- [Rainbow Example](./rainbow-app.md) - Working example for comparison
- [User Guide](../USER_GUIDE.md) - Running examples

## Future Work

1. **Resolve Dependency Issues**: Fix cl-fzy library integration
2. **Address Threading Problems**: Resolve event loop conflicts
3. **Add Error Recovery**: Graceful handling of missing dependencies
4. **Create Tests**: Unit tests for core functionality
5. **Documentation**: Usage examples once functional