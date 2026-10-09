# terminal debug instrumentation review

## status

The first patch captures the right hook points and overall structure.
It is a good basis for debugging terminal ownership, cleanup, and tmux restore behavior.

## concrete findings

### 1. `initial-clear` is logged after being declared ignored

In `make-terminal-instance-for-device`, the patch logs `initial-clear` inside the `:backend-init` event, but the function still contains:

```lisp
(declare (ignore initial-clear))
```

That should be removed if `initial-clear` is part of the debug payload.

### 2. the backend/tmux dependency is coherent only if both hunks land together

`src/platform/tmux-capture.lisp` imports `log-terminal-event` from `elmtui.platform.backend.terminal`.
That is fine, but it means the terminal package export and function definition must land at the same time as the tmux hunk.

### 3. event accumulation is unbounded

That is acceptable for a short debugging phase, but for long-lived sessions it may grow too much.
If needed later, cap the event ring or expose a `*terminal-debug-max-events*` setting.

### 4. phase context is only half the story without orchestration bindings

The patch adds `*terminal-debug-phase*`, `*terminal-debug-owned-region*`, and `*terminal-debug-frame-id*`.
That is good, but they will stay at defaults unless the frame/session owner binds them around init, render, resize, and shutdown.

## recommendation

Apply the terminal backend hunk first, then tmux, then add phase/frame/owned-region bindings at the render/session owner.

## v2 change

The v2 patch removes the stale `(declare (ignore initial-clear))` conflict while keeping the rest of the instrumentation shape the same.
