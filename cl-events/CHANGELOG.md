# Changelog

All notable changes to `cl-events` are recorded here. The library follows semantic versioning independently of ElmTUI.

## Unreleased

### Added

- Cooperative `poll-until` polling/deadline primitive with injectable clock and sleep functions.
- Runtime consumer-loop helpers, primary-channel selection, deadline helpers, and explicit runtime error policy hooks.
- Message propagation envelopes and richer event/message semantics.
- Independent ASDF test operation and local CLPM bundle metadata.

### Changed

- Centralized repeated runtime polling so consumers no longer need duplicate sleep/deadline loops.
- Kept the reusable event runtime independent of ElmTUI UI/rendering policy.

## 0.1.0

- Initial reusable event bus, channels, async tasks, dispatcher, and TEA-oriented app loop.
