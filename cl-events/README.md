# cl-events

`cl-events` is ElmTUI's reusable event/concurrency library. It has no dependency on ElmTUI and can be loaded and tested as an ordinary Common Lisp system.

## Release status

The current in-tree candidate version is **0.2.0** for both `cl-events` and
`cl-events-tests`. This is release-candidate metadata only: the library has not
been published to Quicklisp, Ultralisp, CLPM, or a separate source repository.

The qualified implementation boundary is SBCL on the repository's POSIX/Linux
CLPM environment. Other Common Lisp implementations and non-POSIX platforms
have not yet been qualified.

## What it provides

- bounded channels, mailboxes, filtered channels, and select-style receive helpers;
- typed event/message/command structures;
- topic-based publish/subscribe;
- event-to-message dispatch protocols;
- futures, promises, timers, tasks, and cancellation;
- message propagation envelopes;
- a generic TEA-oriented application-loop shell;
- `poll-until`, the canonical cooperative polling/deadline primitive used by ElmTUI.

The public convenience package is `cl-events.api`; expert APIs are available from the focused `cl-events.*` packages.

## Loading

With ASDF on a checkout containing this directory:

```lisp
(asdf:load-system "cl-events")
```

With this directory as the current directory, the local CLPM bundle is self-contained:

```sh
CLPM_HOME=.cache/clpm clpm bundle install
CLPM_HOME=.cache/clpm clpm bundle exec --with-client sbcl -- \
  --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:load-system "cl-events")'
```

## Example

```lisp
(let ((channel (cl-events.channel:make-channel :capacity 4)))
  (cl-events.channel:chan-put channel :ready)
  (cl-events.channel:chan-take channel))
;; => :READY
```

For deterministic waiting, prefer `cl-events.loop:poll-until` instead of open-coded sleep/deadline loops.

## Testing

The test system is independent and is wired to the primary ASDF test operation:

```sh
CLPM_HOME=.cache/clpm clpm bundle exec --with-client sbcl -- \
  --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:test-system "cl-events")'
```

The ElmTUI release gate also runs this test operation separately before loading the framework integration suite.

## Dependencies

Runtime: Alexandria, Bordeaux Threads, and UIOP/ASDF. FiveAM is test-only.

## Versioning

`cl-events` follows semantic versioning independently of ElmTUI. Because the API is pre-1.0, incompatible public API changes increment the minor version.

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT; see [LICENSE](LICENSE).
