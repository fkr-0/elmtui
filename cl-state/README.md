# cl-state

A state management library for Common Lisp inspired by Elm Architecture and Redux patterns. Provides state containers, patches, transactions, undo/redo, and observers.

## Release status

The current in-tree candidate version is **0.2.0** for both `cl-state` and
`cl-state-tests`. This is release-candidate metadata only: the library has not
been published to Quicklisp, Ultralisp, CLPM, or a separate source repository.

The qualified implementation boundary is SBCL on the repository's POSIX/Linux
CLPM environment. Other Common Lisp implementations and non-POSIX platforms
have not yet been qualified. The primary public convenience package is
`cl-state.api`; focused packages such as `cl-state.core`, `cl-state.patch`, and
`cl-state.tx` expose lower-level contracts.

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
clpm bundle exec --with-client sbcl -- \
  --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:load-system "cl-state")'
```

### Using a Quicklisp local-project checkout

This describes local ASDF discovery only; it does not imply registry
publication.

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

;; Set nested values by passing a path as the KEY argument
(state-set *app-state* '(:user :name) "Alice")
(state-set *app-state* '(:user :age) 30)

;; Get values
(get-state *app-state* '(:user :name)) ; => "Alice"

;; Use transactions for atomic updates
(with-transaction (*app-state* :name :update-user)
  (state-set *app-state* '(:user :name) "Bob")
  (state-set *app-state* '(:user :age) 31))

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
  (state-set *app-state* '(:user :name) "Bob")
  (state-set *app-state* '(:user :age) 31))
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

## Mutation, Transaction, and Observer Policy

`state-set`, `apply-patch`, and `apply-patches` are the supported mutating APIs for an `application-state`. A successful direct mutation changes the logical model first, appends its log entry, increments the model version, and then invokes observers. Observers for one key run in registration order. If an observer signals an error, notification stops immediately and CL-STATE re-signals it as `observer-notification-error`, which exposes the state, key, callback, old/new values, notification phase, and original cause. A direct mutation is not rolled back merely because a post-mutation observer failed.

`with-transaction` delays observer delivery until the outermost transaction for that same state commits. Same-state nested transactions join the outer boundary; they are not savepoints and do not create extra history entries. If the transaction body exits by error or another non-local transfer before commit, CL-STATE restores the affected logical values plus version, transaction-local log entries, history, and redo metadata. Rollback does not invoke observers. On success, one history entry is committed and changes are observed in mutation order; observers registered for each changed key run in registration order. An observer failure during this post-commit delivery is inspectable but does not undo the committed transaction.

Transactions are scoped per `application-state`: a nested transaction on another state owns that state independently, while mutations to an already-active outer state remain part of its outer transaction. `undo` and `redo` replay committed history and intentionally retain their historical compatibility behavior: they do not create observer notifications or increment the model version.

Hash-table and plist application-state backends have the same supported path, patch, transaction, rollback, undo/redo, and observer guarantees. Their physical representation and iteration/key order are not semantic guarantees.

Strict Elm mode and frozen snapshots reject supported logical-state mutation before it occurs. Observer registration/removal is runtime metadata and remains allowed on frozen snapshots. The public `cl-state.api:application-state-data` facade returns an owned snapshot; it is not the mutable representation. `cl-state.core:application-state-data` remains the explicit low-level live-representation escape hatch and therefore bypasses the supported mutation, transaction, observer, and strict-mode policy.

## Testing

Run the test suite:

```bash
clpm bundle exec --with-client sbcl -- \
  --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:test-system "cl-state")'
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
│   ├── value-protocol.lisp # Value ownership/copy protocol
│   ├── persistent.lisp # Persistent patch application
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

`cl-state` is maintained in-tree with ElmTUI; it is not currently a separate
published repository. Contributions to this library should preserve that
one-way ownership boundary.

When preparing changes:

1. Add tests for new functionality.
2. Ensure `asdf:test-system "cl-state"` passes from the library CLPM bundle.
3. Run the ElmTUI integration release gate before treating the change as a
   release candidate.

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
