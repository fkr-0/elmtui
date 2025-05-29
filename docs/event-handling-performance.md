# Event Handling Performance in ELMTUI

This document provides comprehensive guidelines for optimizing event handling performance in ELMTUI applications, particularly when dealing with high-frequency events and complex event processing logic.

## Common Performance Challenges

### 1. High-Frequency Events

Some events occur at very high frequencies and can overwhelm the event processing system:
- Mouse movement events (potentially hundreds per second)
- Window resize events during resizing (dozens per second)
- Key repeat events during key holding (10-30 per second)
- Input field changes for real-time filtering/search
- Data streaming from external sources
- Animation frame updates

### 2. Heavy Processing in Event Handlers

Event handlers that perform complex operations can cause UI lag:
- Layout recalculations
- Heavy data processing
- Network requests
- File operations
- Complex rendering updates
- Large data structure traversals or transformations

## Event Flow Architecture

ELMTUI uses a channel-based event core that ensures all events are processed in a strictly sequential manner, following the TEA (The Elm Architecture) pattern:

```
Event Sources → *main-event-channel* → Consumer Thread → app-update-handler → State Update → View Update → Render
```

All events and messages that trigger state updates are sent through a central channel (`*main-event-channel*`) which is processed by a dedicated consumer thread. This ensures that:

1. The main application's update function is never invoked concurrently
2. Event processing happens in a predictable, sequential manner
3. The application state remains consistent

## Throttling and Debouncing

ELMTUI provides two primary mechanisms to control the rate of event processing: throttling and debouncing. Both help limit how often a function executes, but they work differently.

### Throttling

**What it does**: Executes a function at most once per specified time period.

**When to use it**:
- For actions that should happen at a regular interval during continuous events
- When you need a steady stream of updates, but at a reduced frequency
- For progress indicators, animations, or UI updates during dragging operations

**Example using `elmtui.dev.event-throttler:throttle`:**

```lisp
;; Original handler - would be called for every mouse movement
(defun update-position (event)
  (set-state! app-state :cursor-position (mouse-event-position event)))

;; Throttled version - will run at most once every 100ms
(defun setup-mouse-movement-handling ()
  (let ((throttled-handler 
         (elmtui.dev.event-throttler:throttle #'update-position 100)))
    (elmtui.core.loop:subscribe :mouse-move throttled-handler)))
```

### Debouncing

**What it does**: Delays function execution until after a period of inactivity.

**When to use it**:
- When you want to execute only after the "final" event in a series
- For actions that are expensive and should only happen once after user input is complete
- For search inputs, form validation, or auto-saving

**Example using `elmtui.dev.event-throttler:debounce`:**

```lisp
;; Original handler - would be called for every keystroke
(defun search-data (query)
  (set-state! app-state :search-results 
              (perform-expensive-search query)))

;; Debounced version - will only run 300ms after typing stops
(defun setup-search-input ()
  (let ((debounced-handler 
         (elmtui.dev.event-throttler:debounce #'search-data 300)))
    (elmtui.core.loop:subscribe :input-change debounced-handler)))
```

### Advanced Options

#### Leading vs Trailing Edge (for Debounce)

```lisp
;; Trigger on the leading edge (immediately on first call)
(elmtui.dev.event-throttler:debounce #'fn 300 :leading t :trailing nil)

;; Trigger on both leading and trailing edge (default is trailing only)
(elmtui.dev.event-throttler:debounce #'fn 300 :leading t :trailing t)
```

#### Maximum Wait Time (for Debounce)

If user keeps triggering events continuously:

```lisp
;; Will call function at least every 2000ms even if events keep occurring
(elmtui.dev.event-throttler:debounce #'fn 300 :max-wait 2000)
```

#### Rate Limiting

For more advanced control patterns:

```lisp
;; Allow at most 5 function calls per second
(elmtui.dev.event-throttler:rate-limit #'fn 5 1.0)
```

## Implementation Patterns

### 1. Source-Level Throttling

Apply throttling at the event source level before events enter the main event loop:

```lisp
;; In platform/input.lisp
(defun setup-mouse-move-handler ()
  (let ((throttled-handler 
         (elmtui.dev.event-throttler:throttle 
           (lambda (raw-event)
             (elmtui.core.loop:enqueue-event 
               (normalize-mouse-move raw-event)))
           50)))
    (add-platform-input-handler :mouse-move throttled-handler)))
```

### 2. Subscription-Level Throttling

Apply throttling when subscribing to events:

```lisp
(defun initialize-component ()
  (elmtui.core.loop:subscribe 
    :window-resize
    (elmtui.dev.event-throttler:throttle 
      #'handle-window-resize 
      100)))
```

### 3. Event Grouping

Batch related events together:

```lisp
(defvar *pending-updates* nil)
(defvar *update-timer* nil)

(defun schedule-update (update)
  (push update *pending-updates*)
  (unless *update-timer*
    (setf *update-timer* 
          (elmtui.core.async:set-timeout 
            (lambda ()
              (process-updates *pending-updates*)
              (setf *pending-updates* nil
                    *update-timer* nil))
            50))))
```

### 4. Event Processing Strategies

For different event types, consider these specialized strategies:

#### Mouse Movement

```lisp
;; Throttle mouse move events to 30fps (about 33ms)
(elmtui.dev.event-throttler:throttle #'handle-mouse-move 33)

;; Different throttle rates for different UI states
(let ((handler-fn (if (state-ref app-state :dragging)
                      ;; Higher rate during drag operations
                      (elmtui.dev.event-throttler:throttle #'handle-mouse-move 16)
                      ;; Lower rate for normal mouse movement
                      (elmtui.dev.event-throttler:throttle #'handle-mouse-move 50))))
  (funcall handler-fn event))
```

#### Window Resizing

```lisp
;; Throttle during active resize, then do final update
(let ((resize-handler
       (elmtui.dev.event-throttler:throttle
         ;; Light update during resize
         (lambda (event)
           (handle-resize event :lightweight t))
         50))
      (final-handler
       (elmtui.dev.event-throttler:debounce
         ;; Full update when resize is complete
         (lambda (event)
           (handle-resize event :full t))
         250 :leading nil :trailing t)))
  (elmtui.core.loop:subscribe :window-resize
                            (lambda (event)
                              (funcall resize-handler event)
                              (funcall final-handler event))))
```

#### Search Input

```lisp
;; Progressive enhancement pattern for search
(let ((instant-feedback
       ;; Show "searching..." immediately
       (elmtui.dev.event-throttler:debounce
         (lambda (query)
           (set-state! app-state :search-status :searching))
         50 :leading t :trailing nil))
      (search-handler
       ;; Actual search with delay
       (elmtui.dev.event-throttler:debounce
         (lambda (query)
           (perform-search query)
           (set-state! app-state :search-status :completed))
         300 :leading nil :trailing t)))
  (elmtui.core.loop:subscribe :input-change
                            (lambda (event)
                              (let ((query (extract-query event)))
                                (funcall instant-feedback query)
                                (funcall search-handler query)))))
```

## Channel-Based Event Core Performance

The central `*main-event-channel*` serves as the backbone for ELMTUI's event processing. Here are guidelines to ensure optimal performance:

### 1. Buffer Management

The channel has a limited buffer size. If producers generate events faster than the consumer can process them, backpressure will build up. Monitor queue lengths with:

```lisp
(elmtui.core.loop:get-event-queue-length)
```

### 2. Consumer Thread Health

The consumer thread processes events sequentially. If any event handler blocks for too long, it can delay processing of subsequent events.

Strategies to maintain consumer thread health:
- Keep event handlers lightweight
- Move heavy processing to separate threads
- Use async commands for long-running operations
- Monitor with `elmtui.dev.event-monitor:get-event-loop-metrics`

### 3. Event Prioritization

When events from multiple sources must be processed in order of importance:

```lisp
;; Create a priority handler function
(defun process-by-priority (events)
  (let* ((grouped (group-by #'event-type events))
         ;; Process in this priority order
         (priority-order '(:user-input :command :render-update :analytics)))
    (loop for priority in priority-order
          for priority-events = (getf grouped priority)
          when priority-events
          do (process-events priority-events))))
```

## Async Operations and Event Integration

For long-running operations that shouldn't block the event loop:

```lisp
;; Define an asynchronous command
(defun fetch-data-command (query)
  (elmtui.core.async:cmd-async
   (lambda (promise)
     ;; This runs in a separate thread
     (let ((data (fetch-remote-data query)))
       (elmtui.clevelib.async:resolve-promise promise data)))
   ;; Options
   :timeout 5.0 ; 5 second timeout
   :on-complete (lambda (result) 
                  (list :data-loaded query result))
   :on-error (lambda (error)
               (list :data-load-failed query error))))

;; Use in your update function
(defun my-update (event app-state)
  (case (first event)
    (:fetch-data
     (elmtui.core.async:interpret-cmd 
      (fetch-data-command (second event))))
    (:data-loaded
     (update-state-with-data app-state (third event)))))
```

## Monitoring Event Performance

ELMTUI provides tools to help you identify performance bottlenecks:

### 1. Event Dashboard

```lisp
;; Start a real-time dashboard
(elmtui.dev.event-dashboard:start-event-dashboard)
```

This shows real-time metrics including:
- Event queue length
- Events/second processing rate
- Average and max event processing time
- Top events by frequency
- Slowest event handlers
- Identified bottlenecks

### 2. Event Monitoring with Timing

```lisp
;; Enable detailed timing analysis
(elmtui.dev.event-monitor:enable-timing-analysis)

;; Log events that take longer than 16ms (potentially causing frame drops)
(elmtui.dev.event-monitor:log-slow-events :threshold 16)

;; Generate a performance report
(elmtui.dev.event-monitor:analyze-event-performance)
```

### 3. Bottleneck Detection

```lisp
;; Find performance bottlenecks
(elmtui.dev.event-dashboard:detect-event-bottlenecks)

;; Visualize event flow
(elmtui.dev.event-dashboard:generate-event-flow-diagram)
```

### 4. System Health Analysis

```lisp
;; Get overall system health report
(elmtui.dev.event-dashboard:analyze-event-system-health)
```

## Best Practices

### 1. Choose Appropriate Control Mechanisms

- **Throttle for continuous updates**:
  - Mouse movement: 30-60ms (16-33fps)
  - Progress indicators: 100-200ms (5-10fps)
  - Animation controls: 16-33ms (30-60fps)

- **Debounce for completion-based updates**:
  - Text input: 250-500ms
  - Search queries: 300-800ms
  - Window resize: 250-500ms
  - Validation: 500-1000ms

### 2. Performance Targets

For smooth terminal UI performance:
- Process most events in under 16ms (~60fps)
- Never block the main event loop for more than 100ms
- Keep the event queue length below 10 events during normal operation
- Ensure critical user input (keyboard/mouse clicks) is processed within 50ms

### 3. Optimize Common Patterns

| Event Type | Best Practice |
|------------|---------------|
| Mouse move | Throttle at 30-50ms |
| Resize | Throttle at 50ms with debounced final update |
| Key press | Process immediately, debounce effects |
| Data loading | Use async commands with progress updates |
| Animations | Fixed interval with rate limiting |

### 4. Error Handling

Always wrap event handlers with proper error handling:

```lisp
(elmtui.dev.event-throttler:throttle
  (lambda (event)
    (handler-case
        (process-event event)
      (error (c)
        (log:error "Error in throttled handler: ~A" c)
        (set-state! app-state :error-message (format nil "~A" c)))))
  100)
```

## Advanced Techniques

### 1. Event Filtering

Reduce event processing by filtering unnecessary events:

```lisp
(defun significant-change-p (new-value old-value)
  (> (abs (- new-value old-value)) 5))

(let ((last-value 0))
  (elmtui.core.loop:subscribe
   :sensor-update
   (lambda (event)
     (let ((current-value (getf event :value)))
       (when (significant-change-p current-value last-value)
         (process-sensor-update event)
         (setf last-value current-value))))))
```

### 2. Event Coalescing

Combine multiple events into a single update:

```lisp
(defun coalesce-updates (events)
  (let ((result (copy-list (car events))))
    (dolist (event (cdr events))
      ;; Merge each event into result according to specific rules
      (setf (getf result :count) 
            (+ (getf result :count) (getf event :count)))
      ;; Take the most recent timestamp
      (when (> (getf event :timestamp) (getf result :timestamp))
        (setf (getf result :timestamp) (getf event :timestamp))))
    result))
```

### 3. Progressive Rendering

Break up large rendering operations:

```lisp
(defun render-large-dataset (dataset)
  (let ((chunks (split-into-chunks dataset 100))
        (current-chunk 0))
    (labels ((render-next-chunk ()
               (when (< current-chunk (length chunks))
                 (render-chunk (nth current-chunk chunks))
                 (incf current-chunk)
                 (elmtui.core.async:set-timeout #'render-next-chunk 16))))
      (render-next-chunk))))
```

### 4. Event Source Management

Dynamically adjust event sources based on application state:

```lisp
(defun update-mouse-tracking (app-state)
  (cond
    ;; Full tracking during drag operations
    ((state-ref app-state :dragging)
     (enable-mouse-tracking :throttle 16))
    
    ;; Reduced tracking during normal operation
    ((state-ref app-state :mouse-sensitive-view-visible)
     (enable-mouse-tracking :throttle 50))
    
    ;; No tracking when mouse interaction isn't needed
    (t
     (disable-mouse-tracking))))
```

## Example: Complete Mouse Tracking Implementation

```lisp
;; In your component initialization
(defun initialize-mouse-tracking (component)
  ;; Fast movement tracking (throttled)
  (let ((movement-handler
         (elmtui.dev.event-throttler:throttle
           (lambda (event)
             (handle-mouse-movement component event))
           33))) ; ~30fps
    
    ;; Subscribe to mouse movement events
    (elmtui.core.loop:subscribe :mouse-move movement-handler)
    
    ;; Mouse enter/leave don't need throttling (they're discrete)
    (elmtui.core.loop:subscribe :mouse-enter 
                              (lambda (event)
                                (handle-mouse-enter component event)))
    
    ;; For release on component destruction
    (setf (component-event-handlers component)
          (list movement-handler))))
```

## Diagnostic Workflow

If you encounter performance issues with event handling, follow this diagnostic workflow:

1. **Identify Symptoms**: Lagging UI, delayed responses, event queue buildup.
2. **Profile with Dashboard**: `(elmtui.dev.event-dashboard:start-event-dashboard)` 
3. **Identify Bottlenecks**: Look for handlers with high average times
4. **Apply Control Mechanisms**: Add throttling, debouncing, or filtering
5. **Measure Improvement**: Re-run the dashboard to confirm optimization effects
6. **Refine**: Adjust timing parameters based on user experience

By following these guidelines and using the provided tools, you can ensure your ELMTUI applications maintain responsive, efficient event handling even under high load.
