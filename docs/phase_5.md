# Phase 5: Async Infrastructure Integration

This phase focuses on integrating the existing asynchronous infrastructure from `clevelib` with the Elm architecture to create a cohesive, efficient event loop and command system.

## Objectives

1. Leverage existing async primitives for the main event loop
2. Create channel-based message passing system
3. Implement promise-based command execution

## Tasks

### 1. Channel-Based Message System

1. **Message Channels**
   - Implement `app-channel` for main message passing
   - Create topic-specific channels for component messages
   - Support priority-based message processing

2. **Message Routing**
   - Implement intelligent message routing via channels
   - Create subscription mechanism for components
   - Support filtering and transformation of messages

3. **Channel Selection**
   - Use `select` operation for multi-channel processing
   - Implement timeout-based message handling
   - Support non-blocking operations

### 2. Promise-Based Command System

1. **Command Execution**
   - Use promises to track command completion
   - Implement command chaining
   - Support cancellation and timeout

2. **Command Results**
   - Create standard result handling pattern
   - Implement error propagation
   - Support recovery strategies

3. **Command Scheduling**
   - Support delayed command execution
   - Implement priority-based scheduling
   - Create recurring command patterns

### 3. Main Event Loop Optimization

1. **Event Loop Structure**
   - Reimplement main loop using `clevelib` primitives
   - Optimize for efficient event processing
   - Support graceful shutdown

2. **Task Prioritization**
   - Create priority-based task execution
   - Balance rendering and input processing
   - Implement intelligent throttling

3. **Performance Monitoring**
   - Add instrumentation for event loop performance
   - Create debugging tools for async operations
   - Implement profiling for message handling

## Leveraging Existing Infrastructure

The existing async infrastructure provides several components that can be directly integrated:

1. **Async Tasks**
   - `async-task` structure for background operations
   - Task execution with `async-exec`
   - Result handling with `poll-result` and `await`

2. **Channels**
   - `channel` class for message passing
   - Send/receive operations with `->` and `<-`
   - Channel selection with `select`

3. **Promises**
   - `promise` structure for future values
   - Resolution with `resolve-promise` and `reject-promise`
   - Awaiting results with `await`

## Integration Pattern

```lisp
;; Main loop using channels
(defun run-app (initial-state view-fn update-fn)
  (let ((app-state initial-state)
        (app-channel (make-channel))
        (event-channel (make-channel))
        (command-channel (make-channel))
        (render-needed (make-promise)))
    
    ;; Message processing thread
    (go
      (loop
        (let ((msg (<- app-channel)))
          (with-transaction (app-state)
            (let ((commands (funcall update-fn app-state msg)))
              (-> command-channel commands)
              (resolve-promise render-needed t))))))
    
    ;; Command processing thread
    (go
      (loop
        (let ((commands (<- command-channel)))
          (process-commands commands app-channel))))
    
    ;; Event processing thread
    (go
      (loop
        (let ((event (<- event-channel)))
          (let ((msgs (event->messages event)))
            (dolist (msg msgs)
              (-> app-channel msg))))))
    
    ;; Rendering thread
    (go
      (loop
        (await render-needed)
        (let ((view (funcall view-fn app-state)))
          (render-view view))
        (make-promise render-needed)))
    
    ;; Input thread
    (go
      (loop
        (let ((input (read-input)))
          (-> event-channel input))))))
```

## Expected Outcomes

After completing Phase 5:

- Efficient, channel-based message system
- Promise-based command execution
- Optimized main event loop
- Clear async operation patterns

## Migration Notes

- Direct event handling code needs updates
- Command execution patterns require adaptation
- Any custom event loops need review
