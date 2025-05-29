# ELMTUI Test Suite Organization

This document provides an overview of the ELMTUI test suite organization and how to run tests.

## Test Categories

The test suite is organized into the following categories:

1. **Core Tests**: Core functionality of the ELMTUI system
   - Event system
   - Keyboard and focus management
   - Keymap integration
   - Event propagation

2. **State Tests**: State management and Elm architecture
   - Transaction system
   - Model definition
   - State updates
   - Undo/redo functionality

3. **UI Tests**: User interface components and layout
   - View system
   - Grid layout
   - Style library
   - Widget functionality

4. **Platform Tests**: Backend and rendering implementation
   - Virtual buffer
   - Diff renderer
   - Backend utilities
   - Terminal integration

5. **Developer Tools Tests**: Development and debugging tools
   - Event monitoring
   - Event throttling and debouncing
   - Performance benchmarking

6. **Integration Tests**: End-to-end tests of the complete system

## Running Tests

### Running All Tests

To run all tests, use:

```lisp
(elmtui.tests:run-all-elmtui-tests)
```

### Running Specific Categories

To run specific categories of tests:

```lisp
;; Core functionality tests
(elmtui.tests:run-core-tests)

;; State management tests
(elmtui.tests:run-state-tests)

;; UI component and layout tests
(elmtui.tests:run-ui-tests)

;; Platform and rendering tests
(elmtui.tests:run-platform-tests)

;; Developer tools tests
(elmtui.tests:run-dev-tools-tests)
```

### Running with Priority Filtering

Each test is assigned a priority (`:critical`, `:high`, `:medium`, or `:low`).
You can filter tests by priority using the `:priority` keyword parameter:

```lisp
;; Run only critical tests
(elmtui.tests:run-all-elmtui-tests :priority :critical)

;; Run critical and high priority tests in the UI category
(elmtui.tests:run-ui-tests :priority :high)
```

## Test Files Organization

The test files follow a consistent naming convention:

- `elmtui-<component>-tests.lisp`: Tests for a specific component
- `elmtui-test-runner.lisp`: Central test runner with registry

## Adding New Tests

To add new tests:

1. Create a test file with appropriate naming
2. Define a test suite with `def-suite`
3. Add tests with `test` macro
4. Register the test suite in `elmtui-test-runner.lisp`
5. Add the file to `elmtui-tests.asd`

Example of registering a new test suite:

```lisp
;; In elmtui-test-runner.lisp
(:category . ((:suite . "MY-NEW-TESTS")
              (:package . "ELMTUI-MY-NEW-TESTS")
              (:description . "My New Test Suite")
              (:priority . :high)))
```

## Test Reports

Test reports include:
- Test suite name
- Pass/fail status
- Duration information
- Error details for failed tests

## Continuous Integration

The test system is designed to work with CI pipelines. When running in CI:

```lisp
;; Load the system and run tests with proper exit code
(load "run-tests.lisp")
```

The `run-tests.lisp` file will exit with status code 0 on success or 1 on failure.
