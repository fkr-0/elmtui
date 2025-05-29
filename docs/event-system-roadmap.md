# Event System Enhancement Roadmap

This document outlines the planned enhancements to the ELMTUI event system, based on the analysis of the current implementation and identified gaps.

## 1. Event System Architecture

### Current Status

The ELMTUI event system currently has several components that work together:

1. **Event Definitions** (`src/core/event-types.lisp`):
   - Defines canonical event structures
   - Provides constructors for different event types
   - Includes normalization functions for platform-specific input

2. **Event Loop** (`src/core/loop.lisp`):
   - Implements a publish-subscribe mechanism
   - Routes events based on type

3. **Event Propagation** (`src/core/event-propagation.lisp`):
   - Implements DOM-like event propagation through UI tree
   - Supports capture, target, and bubble phases

4. **Event Async** (`src/core/event-async.lisp`):
   - Manages asynchronous event processing
   - Uses category-specific channels

5. **Topic Registry** (`src/core/topic-registry.lisp`):
   - Manages topic subscriptions
   - Handles basic pattern matching for topics

### Remaining Gaps

1. **Hierarchical Topic Routing**:
   - Current topic system lacks full hierarchical routing capabilities
   - Pattern matching is basic and needs enhancement
   - No support for wildcards in multi-level topics

2. **Event Performance**:
   - ✅ Throttling and debouncing mechanisms implemented in `src/dev/event-throttler.lisp`
   - ✅ Performance benchmarking tools created in `src/dev/event-benchmark.lisp`
   - ⚠️ Further optimization of core event loop pending

3. **Developer Tools**:
   - ✅ Event monitoring system implemented in `src/dev/event-monitor.lisp`
   - ✅ Visualization tools added (Graphviz-based event flow diagrams)
   - ✅ Performance analysis tools implemented (throughput, propagation, handler benchmarks)
   - ⚠️ Interactive debugging tools still need enhancement

## 2. Planned Enhancements

### 2.1 Topic-Based Message System

#### Enhanced Topic Registry

1. **Hierarchical Topic Structure**:
   - Implement a tree-based topic registry
   - Support for multi-level topics (e.g., `ui/components/button/click`)
   - Efficient lookup of subscribers for a given topic

2. **Advanced Pattern Matching**:
   - Support for single-level wildcards (e.g., `ui/+/click`)
   - Support for multi-level wildcards (e.g., `ui/#`)
   - Support for topic filters with multiple patterns

3. **Subscription Management**:
   - Priority-based subscription handling
   - Subscription lifetime management
   - Automatic cleanup of stale subscriptions

#### Implementation Plan

1. **Phase 1: Core Structure**
   - Enhance the `topic` class to support hierarchical relationships
   - Implement efficient topic tree traversal
   - Create pattern matching engine for topic lookups

2. **Phase 2: Subscription Enhancements**
   - Add priority levels to subscriptions
   - Implement subscription ordering based on priority
   - Add subscription metadata (creation time, last used)

3. **Phase 3: Performance Optimization**
   - Optimize pattern matching for common cases
   - Implement caching for frequent topic lookups
   - Add metrics for subscription performance

### 2.2 Event Throttling and Debouncing

#### Throttling Implementation

1. **Basic Throttling**:
   - Implement `throttle` function that limits event frequency
   - Support for trailing calls (last event after throttle period)
   - Configurable time interval

2. **Advanced Features**:
   - Support for leading and trailing options
   - Context preservation across throttled calls
   - Integration with topic subscriptions

#### Debouncing Implementation

1. **Basic Debouncing**:
   - Implement `debounce` function that waits for quiet period
   - Support for immediate execution option
   - Configurable debounce interval

2. **Advanced Features**:
   - Cancellation support for pending debounced calls
   - Maximum wait time option
   - Context preservation across debounced calls

#### Integration with Event System

1. **Topic-Based Throttling**:
   - Ability to throttle entire topics
   - Configurable throttling per subscription
   - Dynamic adjustment of throttling parameters

2. **Message Type Throttling**:
   - Throttle specific message types
   - Different throttling for different message subtypes
   - Conditional throttling based on message content

### 2.3 Performance Monitoring and Optimization

#### Event Benchmarking

1. **Throughput Testing**:
   - Measure events processed per second
   - Identify bottlenecks in event processing
   - Compare different event routing strategies

2. **Latency Testing**:
   - Measure end-to-end event processing time
   - Track latency at different stages of event flow
   - Identify high-latency components

3. **Memory Usage Analysis**:
   - Track memory allocation during event processing
   - Identify memory leaks in event handlers
   - Optimize for lower memory footprint

#### Optimization Strategies

1. **Event Batching**:
   - Group similar events for more efficient processing
   - Batch update notifications
   - Optimize for common event patterns

2. **Handler Optimization**:
   - Profile handler execution time
   - Optimize frequently called handlers
   - Lazy initialization of event handlers

3. **Subscription Optimization**:
   - Optimize topic lookup for common topics
   - Reduce subscription overhead
   - Optimize pattern matching for wildcards

### 2.4 Developer Tools and Debugging

#### Enhanced Event Monitor

1. **Real-Time Visualization**:
   - Interactive event flow diagram
   - Live updates of event processing
   - Filtering and search capabilities

2. **Event Inspector**:
   - Detailed inspection of event properties
   - Tracking event transformations
   - Comparison of similar events

3. **Performance Dashboard**:
   - Real-time metrics on event throughput
   - Latency visualization
   - Topic activity monitoring

#### Integration with Application Debugging

1. **State Change Correlation**:
   - Link events to state changes
   - Visualize event impact on application state
   - Track causality between events

2. **Event Replay**:
   - Record and replay event sequences
   - Modify events for testing
   - Simulate event conditions

3. **Selective Debugging**:
   - Debug specific event types or topics
   - Conditional breakpoints based on event properties
   - Step-through event propagation

## 3. Implementation Timeline

### Phase 1: Core Enhancements (1-2 weeks)

1. **Complete Topic System**:
   - Implement hierarchical topic structure
   - Add advanced pattern matching
   - Support wildcards in topic subscriptions

2. **Event Throttling**:
   - Implement basic throttling functionality
   - Add debouncing support
   - Integrate with topic subscriptions

### Phase 2: Performance Optimization (1-2 weeks)

1. **Benchmarking Tools**:
   - Create throughput testing utilities
   - Implement latency measurement
   - Set up memory usage tracking

2. **Optimization**:
   - Apply batching strategies
   - Optimize handler execution
   - Improve subscription performance

### Phase 3: Developer Tools (1-2 weeks)

1. **Enhanced Monitoring**:
   - Complete real-time visualization
   - Build interactive event inspector
   - Create performance dashboard

2. **Integration**:
   - Connect with state management
   - Implement event replay
   - Add selective debugging

## 4. Expected Outcomes

1. **Performance Improvements**:
   - Higher event throughput
   - Lower latency for event processing
   - Reduced memory footprint

2. **Developer Experience**:
   - Better visibility into event flow
   - Easier debugging of event-related issues
   - More robust event handling

3. **Application Robustness**:
   - More predictable event behavior
   - Better handling of high-frequency events
   - Improved error detection and reporting

## 5. Risks and Mitigations

1. **Backward Compatibility**:
   - **Risk**: Changes to event system could break existing code
   - **Mitigation**: Maintain compatibility layer, extensive testing

2. **Performance Trade-offs**:
   - **Risk**: Some enhancements might impact performance
   - **Mitigation**: Benchmark before and after, optimize critical paths

3. **Complexity**:
   - **Risk**: More sophisticated event system could be harder to understand
   - **Mitigation**: Comprehensive documentation, simple APIs, developer tools
