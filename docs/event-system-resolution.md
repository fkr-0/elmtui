# Event Structure Resolution and Standardization

This document explains how the event structure consistency issues were resolved in the elmtui framework. The framework previously had multiple definitions of similar event structures across different packages, which led to confusion and potential bugs.

## Problem Overview

There were three different packages defining similar event structures:

1. `elmtui.core.events` - Defined comprehensive event structures like `key-event`, `mouse-event`, etc.
2. `elmtui.core.input-events` - Defined event structures specific to input handling
3. `elmtui.core.event-types` - Defined another set of event structures with some overlap

Different parts of the code were using different event definitions:
- `elmtui.core.focus-manager` was importing from `elmtui.core.event-types`
- `dirlister_poc` was using `elmtui.core.input-events:key-event`

## Solution

### 1. Event Compatibility Layer

We created a new file `src/core/event-compat.lisp` that provides compatibility functions to translate between different event formats. This serves as a transitional solution until all code can be updated to use a single canonical event format.

Key features:
- `normalize-event` function that can convert any event format to the canonical format
- Specific conversion functions for each event type
- Support for converting between list-based and struct-based event representations

### 2. Canonical Event Format

We chose `elmtui.core.events` as the canonical event format because it is the most comprehensive. This package defines:

```lisp
(defstruct (key-event (:constructor make-key-event))
  (type (error "Type required") :type keyword) ; :key-down, :key-up
  (key nil :type (or null character keyword)) ; e.g., #\a, :enter, :f1
  (code nil :type (or null integer)) ; platform-specific keycode
  (modifiers nil :type list) ; e.g., (:control :shift)
  (timestamp (get-internal-real-time) :type integer)
  (consumed-p nil :type boolean))
```

### 3. Application Updates

The `dirlister_poc` application was updated to:
- Import and use the event normalizer and canonical event types
- Use a consistent approach to handling events
- Replace dual-path event handling with a normalized approach

### 4. Test Updates

Tests were updated to verify that both list-based and struct-based events work correctly:
- Added tests for struct-based key events
- Verified that both formats produce the same results

## Update Policy

New code should:
1. Import event types from `elmtui.core.events`
2. Use the `normalize-event` function for any input events received
3. For backward compatibility, support both struct-based and list-based event formats

## Full State vs. Update Plist

In the dirlister_poc app (and the elmtui framework in general), we follow the "update plist" pattern:

- The update function returns a plist of changes to be applied to the application state (not the full state)
- This is similar to Elm's approach where update functions return commands and a modified model
- The runtime system applies these changes to the current state

Example:

```lisp
;; Return just the changes
(values '(:listbox-state new-listbox-model :current-path "/new/path") commands)

;; Not returning the full state
;; (values (list :listbox-state new-listbox-model 
;;              :current-path "/new/path"
;;              :terminal-width 80
;;              :terminal-height 24
;;              ...) commands)
```

This approach is more efficient as it avoids rebuilding the entire state for small changes and makes it clearer what parts of the state are being modified.
