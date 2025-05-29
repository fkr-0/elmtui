# Phase 1: Core Architecture Refactoring

This phase focuses on consolidating and standardizing the fundamental building blocks of the Elm architecture in ELMTUI. The goal is to resolve duplicate implementations and establish a consistent foundation for the rest of the refactoring.

## Objectives

1. Establish a single implementation for models
2. Standardize message formats and handling
3. Create consistent update function pattern

## Tasks

### 1. Model System Consolidation

1. **Standardize on the `model.lisp` plist-based approach**
   - Remove incomplete implementation in `elm.lisp`
   - Update any remaining references to hash-table based models
   - Verify model.lisp implementation fully supports:
     - Type checking with `:type` and `:validate` attributes
     - Default values with `:initform` attribute
     - Observer registration with `:observe t` attribute

2. **Documentation**
   - Update model API documentation
   - Add examples for proper model definition and usage

### 2. Message System Standardization

1. **Consolidate on `msg.lisp` implementation**
   - Remove redundant `defmsg` in `elm.lisp` 
   - Import and re-export from `elm.lisp` package
   - Ensure message constructors validate arguments
   - Standardize on typed message constructor pattern

2. **Message format consistency**
   - Update code to use the standard message formats:
     - Simple messages: keyword symbols (e.g., `:reset`)
     - Complex messages: lists with keyword and args (e.g., `(:increment 5)`)

### 3. Update Function Pattern

1. **Transaction consistency**
   - Ensure `defupdate` wraps update logic in transactions
   - Convert direct `set-state!` calls to use transactions
   - Document transaction boundaries

2. **Return value standardization**
   - Standardize on returning commands vector
   - Update any functions returning nil to return empty command vector
   - Document the command pattern

3. **Pattern matching**
   - Standardize on `ematch` for message dispatching
   - Update code using `case` statements to use `ematch`
   - Ensure consistent error handling for unknown messages

## Integration with Async Infrastructure

The channel and promise-based async infrastructure in `clevelib/async.lisp` and `clevelib/channel.lisp` provides a solid foundation for implementing:

1. **Command execution**
   - Commands can be issued through channels to ensure thread safety
   - Promises can be used for tracking command completion

2. **Message dispatch**
   - The channel system provides a clean way to implement message passing
   - The `select` operation allows for prioritizing different message sources

3. **Event integration**
   - Input events can be converted to messages via channels
   - The existing async task model supports background operations

## Expected Outcomes

After completing Phase 1:

- Single, well-defined model implementation
- Consistent message format throughout the codebase
- Uniform update function pattern with transaction support
- Foundation for integrating with the channel-based async system

## Migration Notes

- Older code using raw state access will need updates
- Test suite may need adjustments for the standardized patterns
- Documentation should include migration examples
