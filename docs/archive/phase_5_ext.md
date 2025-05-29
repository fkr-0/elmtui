# Phase 5 Extended: Event System and Async Infrastructure Integration

This extended phase combines the originally planned Phase 4 (Event Handling Refactoring) and Phase 5 (Async Infrastructure Integration) to create a cohesive approach that prevents redundant refactoring of async operations. The goal is to fully leverage the existing asynchronous infrastructure from `clevelib` while implementing a standardized event system, focus management, and keyboard handling.

## Objectives

1. Standardize event handling with async infrastructure integration
2. Implement robust focus management using async primitives
3. Create a comprehensive keyboard event system
4. Optimize the main event loop using channel-based communication

## Critical Remaining Tasks from Previous Phases

Before fully implementing the new event and async systems, these critical tasks must be addressed:

1. **Schema Validation Enhancement**
   - Complete validation utilities for complex model structures
     * `/src/state/validation.lisp`: Create new validation functions for nested data structures
     * `/src/state/model.lisp`: Enhance `defmodel` macro to support nested validation
     * `/src/state/schema.lisp`: Add comprehensive type predicate registry
   - Ensure runtime type checking for state modifications
     * `/src/state/transactions.lisp`: Add runtime type checks in `set-slot`
     * `/src/state/model.lisp`: Implement validation interceptors for state changes
     * `/src/core/conditions.lisp`: Add specific error types for validation failures

2. **Widget Pattern Consistency**
   - Finalize conversion of remaining class-based widgets to functional approach
     * `/src/ui/widgets/panel.lisp`: Convert `panel` class to functional component
     * `/src/ui/widgets/table.lisp`: Convert `table` class to functional component
     * `/src/ui/widgets/legacy-compat.lisp`: Create compatibility layer for legacy widget usage
   - Standardize widget property patterns and validation
     * `/src/view/props.lisp`: Implement property validation framework
     * `/src/ui/widget-registry.lisp`: Create centralized widget property documentation
     * `/src/core/conditions.lisp`: Add specific error types for property validation failures

3. **Rendering Performance Optimization**
   - Complete view memoization for complex UI trees
     * `/src/view/memo.lisp`: Implement component memoization system
     * `/src/view/dsl.lisp`: Add memoization support to view DSL
     * `/src/platform/profiler.lisp`: Create tools for identifying memoization candidates
   - Finalize the diffing algorithm optimizations
     * `/src/view/diff.lisp`: Optimize key-based reconciliation algorithm
     * `/src/view/diff-heuristics.lisp`: Implement intelligent subtree comparison
     * `/src/dev/diff-visualizer.lisp`: Create visual debugging tool for diff operations

## Core Integration Tasks

### 1. Unified Event and Message Channel System

1. **Channel-Based Event Propagation**
   - Implement dedicated channels for different event types (keyboard, mouse, system)
     * `/src/clevelib/channel.lisp`: Enhance channel implementation with filtering capabilities
     * `/src/clevelib/messaging.lisp`: Create specialized messaging channels for different event types
     * `/src/core/event-channels.lisp`: Define standard event channel types and creation utilities
   - Create a unified message bus with priority handling
     * `/src/clevelib/message.lisp`: Add priority field to message structure
     * `/src/clevelib/queue.lisp`: Implement priority queue for message ordering
     * `/src/core/message-bus.lisp`: Create central message dispatcher with priority support
   - Support filtering and transformation of events
     * `/src/core/event-filter.lisp`: Implement filter predicates and transformers
     * `/src/core/event-pipeline.lisp`: Create pipeline for event preprocessing
     * `/src/dev/event-monitor.lisp`: Add debugging tools for event flow visualization

2. **Event Type Definition and Normalization**
   - Finalize standard event structures:
     ```lisp
     (defstruct (key-event (:constructor make-key-event))
       (type (error "Type required") :type keyword) ; :key-down, :key-up
       (key nil :type (or null character keyword)) ; e.g., #\a, :enter, :f1
       (code nil :type (or null integer)) ; platform-specific keycode
       (modifiers nil :type list) ; e.g., (:control :shift)
       (timestamp (get-internal-real-time) :type integer)
       (consumed-p nil :type boolean))
     
     (defstruct (mouse-event (:constructor make-mouse-event))
       (type (error "Type required") :type keyword) ; :mouse-down, :mouse-up, etc.
       (x 0 :type integer)
       (y 0 :type integer)
       (button nil :type (or null keyword))
       (modifiers nil :type list)
       (timestamp (get-internal-real-time) :type integer)
       (consumed-p nil :type boolean))
     ```
     * `/src/core/events.lisp`: Define comprehensive event type hierarchy
     * `/src/core/event-constructors.lisp`: Create utility functions for event creation
     * `/src/core/event-predicates.lisp`: Implement type checking and classification functions
   - Implement consistent platform event translation
     * `/src/platform/ncurses/events.lisp`: Implement curses-specific event translation
     * `/src/platform/termbox/events.lisp`: Implement termbox-specific event translation
     * `/src/platform/event-translation.lisp`: Create generic event normalization layer
   - Create validation and normalization utilities
     * `/src/core/event-validation.lisp`: Implement validation for event structures
     * `/src/core/event-normalization.lisp`: Create standardization utilities for platform events
     * `/src/dev/event-inspector.lisp`: Add tools for event introspection and debugging

3. **Message Routing and Subscription**
   - Implement intelligent message routing via channels
     * `/src/clevelib/relay.lisp`: Enhance relay system for complex routing topologies
     * `/src/clevelib/target.lisp`: Improve targeting mechanism for message delivery
     * `/src/core/router.lisp`: Implement specialized router for UI component hierarchy
   - Create selective subscription mechanism for components
     * `/src/core/subscriptions.lisp`: Implement subscription registry and management
     * `/src/view/component-messaging.lisp`: Add subscription hooks for functional components
     * `/src/ui/message-aware-component.lisp`: Create base component with subscription capabilities
   - Support topic-based event filtering
     * `/src/core/topics.lisp`: Implement topic hierarchy and matching algorithm
     * `/src/core/topic-registry.lisp`: Create central registry for known topics
     * `/src/core/topic-subscription.lisp`: Add pattern matching for topic subscriptions

### 2. Promise-Based Async Event Processing

1. **Promise-Based Command Execution**
   - Use promises to track command completion
     * `/src/clevelib/async.lisp`: Enhance promise implementation with progress tracking
     * `/src/core/commands.lisp`: Implement promise-returning command framework
     * `/src/core/command-registry.lisp`: Create registry for application commands
   - Implement command chaining and composition
     * `/src/clevelib/async.lisp`: Add `chain`, `all`, and `race` promise combinators
     * `/src/core/command-composition.lisp`: Create utilities for building command pipelines
     * `/src/core/command-patterns.lisp`: Implement common command composition patterns
   - Support cancellation and timeout for long-running operations
     * `/src/clevelib/async.lisp`: Add cancellation tokens and timeout support
     * `/src/core/timeouts.lisp`: Implement configurable timeout system
     * `/src/core/command-progress.lisp`: Add progress reporting for long-running commands

2. **Asynchronous Event Handlers**
   - Allow event handlers to return promises for async operations
     * `/src/core/event-handlers.lisp`: Update handler protocol to support promise return
     * `/src/view/async-component.lisp`: Create component wrapper for async operations
     * `/src/ui/async-action.lisp`: Implement utility for async action handling in widgets
   - Implement proper error handling and recovery
     * `/src/core/conditions.lisp`: Add specialized condition types for async failures
     * `/src/core/error-boundary.lisp`: Implement error boundaries for UI components
     * `/src/dev/error-reporter.lisp`: Create error reporting and diagnostic tools
   - Create patterns for handling concurrent event processing
     * `/src/core/concurrency-patterns.lisp`: Implement common concurrency patterns
     * `/src/core/race-protection.lisp`: Add protection against race conditions
     * `/src/core/transaction-safety.lisp`: Ensure thread-safe state mutations

3. **Event Scheduling System**
   - Implement debouncing and throttling utilities
     * `/src/core/event-timing.lisp`: Create debounce and throttle implementations
     * `/src/core/timing-utils.lisp`: Add timing utility functions
     * `/src/ui/responsive-action.lisp`: Implement auto-debouncing for UI actions
   - Create delayed event dispatching with cancellation support
     * `/src/core/timer.lisp`: Implement cancelable timer system
     * `/src/core/delayed-dispatch.lisp`: Create utilities for delayed event processing
     * `/src/core/event-queue.lisp`: Add support for delayed and scheduled events
   - Build recurring event patterns for animations and polling
     * `/src/core/recurring-events.lisp`: Implement recurring event scheduler
     * `/src/ui/animation/scheduler.lisp`: Create animation frame scheduler
     * `/src/ui/polling.lisp`: Add utilities for data polling with configurable intervals

### 3. Enhanced Focus Management

1. **Channel-Based Focus Management**
   - Implement focus manager with async notification channels
     * `/src/core/focus/manager.lisp`: Create async focus manager implementation
     * `/src/core/focus/channels.lisp`: Implement specialized channels for focus events
     * `/src/core/focus/lifecycle.lisp`: Define focus lifecycle events and handling
   - Create focus request and response patterns
     * `/src/core/focus/requests.lisp`: Implement asynchronous focus request system
     * `/src/core/focus/response.lisp`: Create standardized focus response patterns
     * `/src/ui/focus-requestor.lisp`: Add component mixin for focus requesting
   - Support priorities for focus acquisition
     * `/src/core/focus/priority.lisp`: Implement priority-based focus arbitration
     * `/src/core/focus/rules.lisp`: Create configurable rules for focus resolution
     * `/src/ui/modal.lisp`: Add priority focus handling for modal dialogs

2. **Focus Traversal and Navigation**
   - Complete tab navigation with proper ordering
     * `/src/core/focus/tab-order.lisp`: Implement configurable tab order system
     * `/src/core/focus/tab-index.lisp`: Add tab index calculation and normalization
     * `/src/ui/tab-navigation.lisp`: Create components for tab navigation control
   - Implement directional (arrow key) navigation
     * `/src/core/focus/directional.lisp`: Add spatial focus navigation algorithm
     * `/src/core/focus/grid-navigation.lisp`: Implement grid-aware navigation
     * `/src/ui/arrow-navigation.lisp`: Create navigation utilities for custom widgets
   - Add support for focus groups and containers
     * `/src/core/focus/group.lisp`: Implement focus group management
     * `/src/core/focus/containment.lisp`: Create focus containment rules
     * `/src/ui/focus-boundary.lisp`: Add components for defining focus boundaries

3. **Focus History and Restoration**
   - Implement robust focus history stack
     * `/src/core/focus/history.lisp`: Create focus history tracking system
     * `/src/core/focus/stack.lisp`: Implement undo/redo for focus changes
     * `/src/dev/focus-visualizer.lisp`: Add tools for visualizing focus history
   - Create focus restoration after UI updates
     * `/src/core/focus/persistence.lisp`: Implement focus state persistence
     * `/src/core/focus/restoration.lisp`: Create focus restoration strategies
     * `/src/view/focus-aware-render.lisp`: Add focus preservation during re-rendering
   - Support focus memory across view changes
     * `/src/core/focus/context.lisp`: Implement view-specific focus context
     * `/src/core/focus/memory.lisp`: Create focus memory system for views
     * `/src/ui/focus-memory-provider.lisp`: Add component for managing focus memory

### 4. Comprehensive Keyboard Event System

1. **Keymap Registry with Context Support**
   - Create a centralized keymap registry
     * `/src/core/keymap/registry.lisp`: Implement global keymap registry
     * `/src/core/keymap/lookup.lisp`: Create efficient keymap lookup system
     * `/src/dev/keymap-inspector.lisp`: Add tools for inspecting active keymaps
   - Implement context-sensitive keymap activation
     * `/src/core/keymap/context.lisp`: Define context-based keymap activation
     * `/src/core/keymap/scope.lisp`: Implement keymap scoping for UI components
     * `/src/ui/keymap-provider.lisp`: Create component for keymap context provision
   - Support keymap inheritance and overrides
     * `/src/core/keymap/inheritance.lisp`: Implement keymap inheritance hierarchy
     * `/src/core/keymap/resolution.lisp`: Create conflict resolution strategies
     * `/src/core/keymap/override.lisp`: Add override mechanisms for keybindings

2. **Key Combination and Sequence Support**
   - Implement support for modifier keys and combinations
     * `/src/core/keymap/modifiers.lisp`: Add comprehensive modifier key support
     * `/src/core/keymap/chord.lisp`: Implement key chord detection
     * `/src/core/keymap/hotkey.lisp`: Create hotkey definition utilities
   - Add multi-key sequence detection (e.g., Emacs/Vim-style)
     * `/src/core/keymap/sequence.lisp`: Implement key sequence detection
     * `/src/core/keymap/timeout.lisp`: Add configurable timeouts for sequences
     * `/src/ui/key-sequence-listener.lisp`: Create component for sequence handling
   - Create visual feedback for partial key sequences
     * `/src/ui/key-hint.lisp`: Implement key hint display component
     * `/src/ui/key-sequence-indicator.lisp`: Create visual indicator for sequences
     * `/src/ui/keystroke-display.lisp`: Add component for visualizing keystrokes

3. **Default Key Handlers and Integration**
   - Implement standard navigation and editing keybindings
     * `/src/core/keymap/defaults.lisp`: Create standard keymap definitions
     * `/src/core/keymap/navigation.lisp`: Implement navigation key handlers
     * `/src/ui/standard-keymaps.lisp`: Add ready-to-use keymap collections
   - Create form submission and dialog interaction patterns
     * `/src/ui/form-keymap.lisp`: Implement form-specific key handlers
     * `/src/ui/dialog-keymap.lisp`: Create dialog navigation keybindings
     * `/src/ui/wizard-keymap.lisp`: Add multi-step form navigation
   - Add clipboard integration where applicable
     * `/src/platform/clipboard.lisp`: Implement clipboard abstraction layer
     * `/src/core/keymap/clipboard.lisp`: Create clipboard-related keybindings
     * `/src/ui/clipboard-aware.lisp`: Add component mixin for clipboard support

### 5. Optimized Main Event Loop

1. **Channel-Based Main Loop**
   - Reimplement main loop using `clevelib` channel primitives
     * `/src/core/loop.lisp`: Implement channel-based main event loop
     * `/src/clevelib/event-loop.lisp`: Enhance event loop with channel integration
     * `/src/core/loop-lifecycle.lisp`: Create lifecycle hooks for event loop
   - Create efficient event selection and dispatching
     * `/src/core/event-dispatcher.lisp`: Implement efficient event dispatcher
     * `/src/core/selector.lisp`: Create channel selector for event sources
     * `/src/core/dispatch-rules.lisp`: Define event dispatch priority rules
   - Support graceful startup and shutdown procedures
     * `/src/core/startup.lisp`: Implement graceful application startup sequence
     * `/src/core/shutdown.lisp`: Create orderly shutdown procedures
     * `/src/core/resource-management.lisp`: Add resource cleanup during shutdown

2. **Task Prioritization and Scheduling**
   - Implement priority-based task execution
     * `/src/core/task-queue.lisp`: Create priority-based task queue
     * `/src/core/scheduler.lisp`: Implement scheduling with priority support
     * `/src/core/task-priority.lisp`: Define task priority levels and policies
   - Balance rendering, input processing, and background tasks
     * `/src/core/workload-balancer.lisp`: Create workload balancing algorithm
     * `/src/core/fairness.lisp`: Implement fairness policies for task types
     * `/src/core/resource-allocation.lisp`: Add resource allocation strategies
   - Create intelligent throttling for high-frequency events
     * `/src/core/throttling.lisp`: Implement configurable event throttling
     * `/src/core/rate-limiter.lisp`: Create rate limiting for event sources
     * `/src/ui/responsive-updates.lisp`: Add intelligent UI update batching

3. **Performance and Debugging Tools**
   - Add instrumentation for event loop performance
     * `/src/dev/loop-profiler.lisp`: Implement event loop performance profiling
     * `/src/dev/metrics.lisp`: Create metrics collection for event processing
     * `/src/dev/performance-monitor.lisp`: Add real-time performance monitoring
   - Create visual debugging tools for async operations
     * `/src/dev/async-visualizer.lisp`: Create visualization for async operations
     * `/src/dev/promise-inspector.lisp`: Implement promise inspection tools
     * `/src/dev/channel-monitor.lisp`: Add monitoring for channel activity
   - Implement profiling for message and event handling
     * `/src/dev/event-profiler.lisp`: Create profiling for event handlers
     * `/src/dev/message-tracer.lisp`: Implement message flow tracing
     * `/src/dev/bottleneck-detector.lisp`: Add bottleneck detection in event processing

## Implementation Examples

### Event Processing with Channels

```lisp
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
    
    ;; Process events and commands
    (loop
      (select
        ((event-ready? event-source) (-> event-channel (read-event event-source)))
        ((command-result-ready? command-channel) (process-command-result))))))
```

### Focus Management with Async Support

```lisp
(defun request-focus (element focus-manager)
  (let ((request-promise (make-promise)))
    (-> (focus-manager-channel focus-manager)
        (list :request-focus element request-promise))
    (await request-promise)))

(defun focus-manager-process-requests (focus-manager)
  (go
    (loop
      (let ((request (<- (focus-manager-channel focus-manager))))
        (ecase (first request)
          (:request-focus
           (destructuring-bind (cmd element promise) request
             (let ((result (try-set-focus element focus-manager)))
               (resolve-promise promise result))))
          (:tab-navigate
           (destructuring-bind (cmd direction promise) request
             (let ((result (tab-navigate direction focus-manager)))
               (resolve-promise promise result)))))))))
```

### Event Debouncing Implementation

```lisp
(defun debounce (function delay)
  (let ((timer nil)
        (result-promise nil))
    (lambda (&rest args)
      (when timer
        (cancel-timer timer)
        (reject-promise result-promise :superseded))
      (setf result-promise (make-promise))
      (setf timer 
            (schedule-timer 
             (lambda ()
               (apply function args)
               (resolve-promise result-promise t))
             delay))
      result-promise)))
```

## Expected Outcomes

After completing Phase 5 Extended:

- Fully integrated event system with async infrastructure
- Efficient, channel-based message and event processing
- Robust focus management with keyboard navigation
- Optimized main event loop with priority handling
- Clear patterns for asynchronous UI operations

## Migration Path

- Progressive migration from direct event handling to channel-based approach
- Phased introduction of async patterns in UI components
- Backward compatibility layer during transition

## Further Work

These tasks, while important, can be addressed after the core event and async systems are in place:

### From Phase 1-2

- **Advanced Undo/Redo**
  - Implement selective undo/redo for complex state changes
    * `/src/state/undo-manager.lisp`: Enhance undo manager with selective undo capabilities
    * `/src/state/transaction-history.lisp`: Add metadata for selective undo
    * `/src/ui/undo-selector.lisp`: Create UI for selective transaction restoration
  - Add visual indicators for undoable/redoable states
    * `/src/ui/undo-indicator.lisp`: Implement indicator component for undo status
    * `/src/ui/history-navigator.lisp`: Create UI for browsing transaction history
    * `/src/ui/action-history.lisp`: Add component for visualizing available actions

- **Transaction History Visualization**
  - Create tools for visualizing state change history
    * `/src/dev/history-viewer.lisp`: Implement transaction history visualization
    * `/src/dev/state-timeline.lisp`: Create timeline view of state changes
    * `/src/dev/change-inspector.lisp`: Add detailed inspection of state changes
  - Implement debugging utilities for transaction tracing
    * `/src/dev/transaction-tracer.lisp`: Add transaction tracing capabilities
    * `/src/dev/transaction-log.lisp`: Create transaction logging system
    * `/src/dev/transaction-replay.lisp`: Implement transaction replay functionality

### From Phase 3

- **Animation Extensions**
  - Add more easing functions and complex animation patterns
    * `/src/ui/animation/easing.lisp`: Expand library of easing functions
    * `/src/ui/animation/patterns.lisp`: Implement reusable animation patterns
    * `/src/ui/animation/presets.lisp`: Create library of animation presets
  - Create animation composition and sequencing tools
    * `/src/ui/animation/sequence.lisp`: Implement animation sequencing
    * `/src/ui/animation/parallel.lisp`: Add parallel animation support
    * `/src/ui/animation/chain.lisp`: Create animation chaining utilities
  - Implement animation debugging and timeline visualization
    * `/src/dev/animation-debugger.lisp`: Create animation debugging tools
    * `/src/dev/animation-timeline.lisp`: Implement timeline visualization
    * `/src/dev/animation-inspector.lisp`: Add detailed animation inspection

- **Advanced Layout Features**
  - Add automatic grid placement algorithms
    * `/src/view/grid-placement.lisp`: Implement automatic grid placement
    * `/src/view/grid-packing.lisp`: Create packing algorithms for grid items
    * `/src/ui/auto-grid.lisp`: Add auto-placement grid component
  - Implement min/max constraints for layout elements
    * `/src/view/constraints.lisp`: Add min/max constraint system
    * `/src/view/size-policies.lisp`: Create size policy framework
    * `/src/view/layout-constraints.lisp`: Implement constraint-based layouts
  - Create responsive breakpoints based on terminal size
    * `/src/view/breakpoints.lisp`: Implement terminal size breakpoints
    * `/src/view/responsive-layout.lisp`: Create responsive layout engine
    * `/src/ui/responsive-container.lisp`: Add responsive container component

### Accessibility and Usability

- **Screen Reader Support**
  - Add accessibility metadata for TUI elements
    * `/src/core/accessibility/metadata.lisp`: Create accessibility metadata system
    * `/src/core/accessibility/roles.lisp`: Define ARIA-like roles for TUI elements
    * `/src/ui/accessible-component.lisp`: Add accessiblity mixin for components
  - Implement screen reader announcements for dynamic content
    * `/src/core/accessibility/announcer.lisp`: Create screen reader announcement system
    * `/src/core/accessibility/live-regions.lisp`: Implement live region updates
    * `/src/ui/announcement-provider.lisp`: Add announcement provider component

- **International Keyboard Support**
  - Add comprehensive handling for non-US keyboard layouts
    * `/src/platform/keyboard-layouts.lisp`: Implement keyboard layout detection
    * `/src/core/keymap/intl-mapping.lisp`: Create international key mapping
    * `/src/core/keymap/layout-aware.lisp`: Add layout awareness to keymap system
  - Implement input method editor (IME) support where applicable
    * `/src/platform/ime-support.lisp`: Create IME abstraction layer
    * `/src/core/text-input/ime.lisp`: Implement IME integration
    * `/src/ui/ime-indicator.lisp`: Add IME status indicator component

- **User Preference System**
  - Create a system for storing and applying user preferences
    * `/src/core/preferences/store.lisp`: Implement preference storage system
    * `/src/core/preferences/schema.lisp`: Create preference schema validation
    * `/src/core/preferences/defaults.lisp`: Define default preference values
  - Support customization of keyboard shortcuts and themes
    * `/src/core/preferences/keymap-customizer.lisp`: Add keymap customization
    * `/src/core/preferences/theme-manager.lisp`: Create theme management system
    * `/src/ui/preferences-editor.lisp`: Implement preferences editor component
  - Implement preference migration during upgrades
    * `/src/core/preferences/migration.lisp`: Create preference migration system
    * `/src/core/preferences/versioning.lisp`: Implement preference versioning
    * `/src/core/preferences/upgrader.lisp`: Add preference upgrader for compatibility

## Implementation Timeline

The implementation of Phase 5 Extended is planned over a 12-week period, divided into three major milestones:

### Milestone 1: Foundation (Weeks 1-4)

- Complete critical remaining tasks from previous phases
- Implement unified event and message channel system
- Create basic focus management infrastructure
- Build initial keymap registry

### Milestone 2: Core Systems (Weeks 5-8)

- Implement promise-based async event processing
- Complete focus traversal and navigation systems
- Build key combination and sequence support
- Create optimized main event loop

### Milestone 3: Integration and Polish (Weeks 9-12)

- Implement advanced focus history and restoration
- Complete default key handlers and integration
- Build performance and debugging tools
- Create migration path and backwards compatibility layer

## Testing Strategy

The testing approach for Phase 5 Extended will focus on ensuring robust and reliable event handling. The strategy includes:

### Unit Tests

- Test individual components of the event system
- Verify promise-based operations function correctly
- Validate focus management in isolation

### Integration Tests

- Test event flow through the entire processing pipeline
- Verify focus traversal across complex component hierarchies
- Validate keyboard event handling in realistic scenarios

### Performance Tests

- Benchmark event throughput and latency
- Measure focus management efficiency
- Assess keyboard event processing overhead

## Conclusion

Phase 5 Extended represents a critical evolution of the elmtui framework, providing robust asynchronous event handling integrated with the existing reactive state management system. By combining the event system refactoring with async infrastructure integration, this phase ensures a cohesive approach that minimizes redundant work and creates a solid foundation for advanced TUI applications.

The implementation of channel-based communication, promise-based async operations, and comprehensive focus and keyboard management will enable elmtui to handle complex interaction patterns while maintaining high performance and responsiveness. These improvements will significantly enhance the developer experience and enable more sophisticated terminal user interfaces.

Upon completion of Phase 5 Extended, elmtui will offer a comprehensive, high-performance framework for building complex terminal user interfaces with modern patterns familiar to web developers while leveraging the unique capabilities of the Common Lisp ecosystem.
