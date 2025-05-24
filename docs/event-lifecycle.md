# Event System Documentation

## Overview

This document describes the standardized event system implemented in Phase 3/4 of the ELMTUI refactoring. The system provides a consistent approach to handling input events, managing focus, and processing keyboard interactions.

## 1. Event Types

### Base Event Structure

All events inherit from the base `ui-event` structure:

```lisp
(defstruct ui-event
  type                ; Keyword indicating event type (:key-down, :mouse-up, etc.)
  target              ; ID of target element
  timestamp           ; When the event occurred
  consumed-p          ; Whether event has been consumed
  original-event)     ; Original platform event if applicable
```

### Key Events

Keyboard events are represented using the `key-event` structure:

```lisp
(defstruct key-event
  type                ; :key-down, :key-up, :key-press
  key                 ; Character or keyword (:enter, :escape, etc.)
  code                ; Platform-specific keycode
  modifiers           ; List of modifier keywords (:control, :shift, etc.)
  timestamp           ; When the event occurred
  consumed-p)         ; Whether event has been consumed
```

### Mouse Events

Mouse events are represented using the `mouse-event` structure:

```lisp
(defstruct mouse-event
  type                ; :mouse-down, :mouse-up, :mouse-move, :mouse-wheel, etc.
  x                   ; X coordinate
  y                   ; Y coordinate
  button              ; :left, :middle, :right, or nil
  click-count         ; For detecting double/triple clicks
  delta-x             ; For scroll events
  delta-y             ; For scroll events
  modifiers           ; Keyboard modifiers during the event
  timestamp           ; When the event occurred
  consumed-p)         ; Whether event has been consumed
```

## 2. Event Propagation

Events in ELMTUI follow a standard propagation path similar to the DOM event model:

1. **Capturing Phase**: Events travel from the root node down to the target
2. **Target Phase**: Event is processed by the target element
3. **Bubbling Phase**: Events bubble up from the target to the root

### Propagation Control

Events can be controlled using:

```lisp
(stop-propagation event)      ; Stops further propagation
(prevent-default event)       ; Prevents default behavior
```

### Example

```lisp
;; Event handler for a button
(defmethod handle-event ((node button-node) (event key-event) (phase (eql :target)))
  (when (and (eq (key-event-type event) :key-down)
             (eq (key-event-key event) :enter))
    ;; Button activated by Enter key
    (activate-button node)
    ;; Stop event from propagating to parent elements
    (stop-propagation event)))
```

## 3. Focus Management

### Focus Model

The focus management system keeps track of:

- Currently focused element
- List of focusable elements in tab order
- Focus history for navigation

The focus state is stored in a `focus-manager` structure in the application state:

```lisp
(defstruct focus-manager
  current-focus       ; ID of currently focused widget
  focusable-elements  ; Ordered list of focusable IDs
  focus-history       ; Stack of previous focus IDs
  focus-ring-dirty-p) ; Whether focusable-elements needs recalculation
```

### Focus API

Common focus operations:

```lisp
(set-focus app-state widget-id)             ; Focus specific element
(get-current-focus app-state)               ; Get current focus ID
(get-next-focusable app-state current-id)   ; Get next element in tab order
(get-previous-focusable app-state current-id) ; Get previous element in tab order
(clear-focus app-state)                     ; Clear focus
(focus-previous-from-history app-state)     ; Return to previous focus
```

### Tab Navigation

Tab navigation is built into the focus system. When a `key-event` for Tab or Shift+Tab is received, the focus manager handles moving focus to the next or previous focusable element, respecting the established tab order.

## 4. Keymap System

The keymap system allows binding key combinations to actions.

### Key Mapping

Keys are normalized into a consistent format:

```lisp
(defstruct normalized-key
  key                 ; Character or keyword (:enter, :escape, etc.)
  modifiers)          ; List of modifier keywords (:ctrl, :alt, etc.)
```

### Keymap Definition

Keymaps are defined using:

```lisp
(define-keymap *my-keymap*
  ("C-s" :type :message :target '(:save-file) :description "Save file")
  ("C-x C-c" :type :action :target 'quit-app :description "Quit")
  (:escape :type :message :target '(:cancel) :description "Cancel"))
```

### Key Lookup

When a key event occurs, the system finds the appropriate action:

```lisp
(let* ((normalized-key (key-event->normalized-key key-event))
       (binding (lookup-keymap current-keymap normalized-key)))
  (when binding
    (execute-key-binding binding)))
```

## 5. Integration with Async Infrastructure

Events are processed asynchronously using channels and the worker thread infrastructure.

### Event Channels

Different types of events can be sent to specific channels:

```lisp
*main-event-channel*   ; Main channel for all events
*key-event-channel*    ; For keyboard events
*mouse-event-channel*  ; For mouse events
*ui-event-channel*     ; For UI-specific events
```

### Event Scheduling

The event system supports various scheduling patterns:

```lisp
(schedule-event event 1000)            ; Delay event by 1000ms
(schedule-repeating-event event 100 5) ; Repeat event 5 times, every 100ms
(debounce function 250)                ; Create a debounced function
(throttle function 100)                ; Create a throttled function
```

## 6. Animation Framework

The animation system is built on top of the event infrastructure and provides:

1. Simple animations with progress updates
2. Transitions between values
3. Sequencing and parallel animation
4. Various easing functions

### Creating Animations

```lisp
;; Simple animation
(create-animation 
 1.0                       ; Duration in seconds
 (lambda (progress)        ; Update function
   (setf (widget-opacity widget) progress))
 :easing-fn #'ease-in-out) ; Easing function

;; Value transition
(create-transition
 0 100 1.0                ; From 0 to 100 over 1 second
 (lambda (value)          ; Update function
   (setf (widget-position-x widget) value)))

;; Animation sequence
(create-sequence
 (list animation1 animation2 animation3))

;; Parallel animations
(create-parallel
 (list animation1 animation2 animation3))
```

## Best Practices

1. **Event Handlers**: Keep event handlers small and focused
2. **Focus Management**: Use the focus management API instead of direct manipulation
3. **Animation**: Use the animation framework for smooth transitions
4. **Throttling/Debouncing**: Apply to performance-intensive event handlers
5. **Tab Order**: Ensure sensible tab order for accessible interfaces
