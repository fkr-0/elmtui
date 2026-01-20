# cl-state

A state management library for Common Lisp inspired by Elm Architecture and Redux patterns. Provides state containers, patches, transactions, undo/redo, and observers.

## Features

- **State Container**: Thread-safe application state with hash-table or plist backends
- **Patch System**: Apply changes to state using a declarative patch format
- **Transactions**: Atomic state updates with automatic change tracking
- **Undo/Redo**: Full undo/redo support for transactions and standalone history
- **Observers**: React to state changes with observer pattern
- **Functional API**: Pure functions for state manipulation

## Installation

### Using CLPM

```bash
cd /path/to/cl-state
clpm bundle install
clpm bundle exec sbcl --load run-tests-clpm-state.lisp
```

### Using Quicklisp

Add `cl-state` to your Quicklisp local-projects directory:

```bash
ln -s /path/to/cl-state ~/quicklisp/local-projects/cl-state
```

Then in your Lisp:

```lisp
(ql:quickload :cl-state)
(use-package :cl-state.api)
```

## Quick Start

```lisp
;; Create a new state
(defparameter *app-state* (make-state))

;; Set some values
(state-set *app-state* :user :name "Alice")
(state-set *app-state* :user :age 30)

;; Get values
(get-state *app-state* '(:user :name)) ; => "Alice"

;; Use transactions for atomic updates
(with-transaction (*app-state* :name :update-user)
  (state-set *app-state* :user :name "Bob")
  (state-set *app-state* :user :age 31))

;; Undo the transaction
(undo *app-state*)

;; Redo the transaction
(redo *app-state*)

;; Add observers
(add-observer *app-state* :user
  (lambda (old new)
    (format t "User changed from ~A to ~A~%" old new)))
```

## API Reference

### Core State Operations

#### `make-state` (&key initial backend)
Create a new application state.

```lisp
(make-state)
(make-state :initial '((:foo . 42)) :backend :plist)
```

#### `state-ref` (state key &optional default)
Access a value in the state by path.

```lisp
(state-ref *app-state* '(:user :name))
(state-ref *app-state* '(:missing) :default-value)
```

#### `state-set` (state key value)
Set a value in the state by path.

```lisp
(state-set *app-state* '(:user :name) "Alice")
```

### Patch Operations

#### `make-patch` (&key path op value)
Create a patch structure.

```lisp
(make-patch :path '(:user :name) :op :set :value "Alice")
```

#### `apply-patch` (state patch)
Apply a single patch to state.

```lisp
(apply-patch *app-state* (make-patch :path '(:foo) :op :set :value 42))
```

#### `merge-patch` (state patch)
Merge a patch into state (functional API - returns modified state).

```lisp
(setf *app-state*
      (merge-patch *app-state* '((:user :name) "Alice")))
```

#### `merge-patches` (state patches)
Merge multiple patches into state (functional API - returns modified state).

```lisp
(setf *app-state*
      (merge-patches *app-state* '(((user :age) 30)
                                 ((settings :theme) :dark))))
```

### Transaction Operations

#### `with-transaction` ((app &key name) &body body)
Execute state updates in a transaction.

```lisp
(with-transaction (*app-state* :name :update-user)
  (state-set *app-state* :user :name "Bob")
  (state-set *app-state* :user :age 31))
```

#### `undo` (app)
Undo the last transaction (works on application-state).

```lisp
(undo *app-state*)
```

#### `redo` (app)
Redo the last undone transaction (works on application-state).

```lisp
(redo *app-state*)
```

### History Operations

#### `make-history` ()
Create a new history structure.

```lisp
(defparameter *hist* (make-history))
```

#### `push-snapshot` (hist state)
Push a state snapshot to history.

```lisp
(push-snapshot *hist* *current-state*)
```

#### `history-undo` (hist)
Undo to previous state in history.

```lisp
(history-undo *hist*)
```

#### `history-redo` (hist)
Redo to next state in history.

```lisp
(history-redo *hist*)
```

### Observer Operations

#### `add-observer` (state key fn)
Add an observer for state changes at key.

```lisp
(add-observer *app-state* :user
  (lambda (old new)
    (format t "User changed: ~A -> ~A~%" old new)))
```

#### `remove-observer` (state key fn)
Remove an observer.

```lisp
(remove-observer *app-state* :user *observer-fn*)
```

## Testing

Run the test suite:

```bash
./rt-state.sh
```

Or programmatically:

```lisp
(asdf:test-system :cl-state)
```

## Dependencies

- `alexandria` - Common utilities
- `uiop` - Portable Operating System Interface
- `bordeaux-threads` - Threading support

## Development

### Project Structure

```
cl-state/
├── src/state/          # Source files
│   ├── packages.lisp   # Package definitions
│   ├── utils.lisp      # Utility functions
│   ├── core.lisp       # Core state operations
│   ├── patch.lisp      # Patch system
│   ├── tx.lisp         # Transaction support
│   ├── undo.lisp       # Undo/redo history
│   ├── observer.lisp   # Observer pattern
│   └── api.lisp        # Public API re-exports
├── tests/              # Test files
├── cl-state.asd        # ASDF system definition
├── clpmfile            # CLPM bundle configuration
├── rt-state.sh         # Test runner script
└── run-tests-clpm-state.lisp  # Test entry point
```

### Code Style

- Follow Common Lisp conventions
- Use descriptive variable and function names
- Document public APIs with docstrings
- Write tests for all new features

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

## Documentation

For detailed API documentation and examples, see the inline documentation in the source files or generate documentation using your preferred Common Lisp documentation tool (e.g., `cl-doc`).

## Common Lisp Documentation Tools

If you're looking for documentation generation tools for Common Lisp, here are some popular options:

- **[SphinxCL](https://github.com/symbolic/sphinxcl)** - Sphinx-based documentation generator for Common Lisp
- **[cl-doc](https://github.com/Shinmera/cl-doc)** - Documentation generator from docstrings
- **[ documenting-common-lisp ](https://gigamonkeys.com/documentation/)** - Guide to documenting Common Lisp code

## Acknowledgments

Inspired by:
- Elm Architecture (The Elm Architecture)
- Redux (JavaScript state management)
- re-frame (ClojureScript framework)

## Contact

For issues, questions, or contributions, please visit the project repository or contact the maintainers.
