# cl-events API

This document summarizes the extended API surface added for migration from cleve-elm and for general library use. All APIs are optional and can be adopted incrementally.

## Protocols (optional message semantics)

These generics live in `cl-events.protocols` and default to NIL behavior unless specialized:

- `message-state` / `message-priority`
- `broadcast-p` / `capture-p` / `bubble-p`
- `stop-propagation`

Defaults are conservative: no broadcasting/capture/bubble and `stop-propagation` returns the message unchanged.

## Message struct extensions

`cl-events.types:message` supports optional `:state` and `:priority` via the public constructor:

```lisp
(make-message :type :foo :data 1 :state :new :priority :high)
```

Access with protocol generics:

```lisp
(message-state msg)
(message-priority msg)
```

## Channels (extended)

New channel features in `cl-events.channel`:

- `->` / `<-` aliases for `chan-put` / `chan-take`
- `no-wait` for non-blocking readiness
- `channel-put!` / `channel-take!`
- `select` for lightweight polling across channels
- `filtered-channel` and helpers:
  - `make-filtered-channel`
  - `channel-add-filter`
  - `channel-remove-filter`

Example:

```lisp
(let ((ch (make-filtered-channel
           :filters (list (lambda (v) (eql v :ok))))))
  (chan-put ch :bad) ; dropped
  (chan-put ch :ok)
  (<- ch)) ; => :ok
```

## Async tasks and promises

`cl-events.async` now includes a cleve-elm style promise/task model, while retaining the existing `spawn-task`/`future` APIs.

Promises:

```lisp
(let ((p (make-promise)))
  (resolve-promise p 42)
  (await p))
```

Async tasks:

```lisp
(let* ((t (new-task (lambda () 7)))
       (_ (async-exec t)))
  (await t))
```

Cancellation:

```lisp
(cancel some-task)
```

## Async combinators

Combinators accept promises or async-tasks:

- `chain`
- `all`
- `race`

Examples:

```lisp
(chain p (lambda (v) (+ v 1)))
(all (list p1 task2))
(race (list p1 task2))
```

## Messaging envelopes (optional)

The `cl-events.messaging` package provides a lightweight propagation-aware wrapper without forcing a message class.

Key types/functions:

- `message-envelope` with fields: `message`, `phase`, `stop-p`, `broadcast-p`, `capture-p`, `bubble-p`
- `message-phases` (returns phases for a message)
- `message->envelope`
- `expand-message` (message -> envelopes)
- `envelope->messages` (envelopes -> messages)

Example:

```lisp
(expand-message msg) ; => list of envelopes for :capture/:target/:bubble
```

## Notes

- All features are opt-in; existing code continues to work.
- Protocols let you introduce richer message semantics without tying cl-events to a specific message representation.
