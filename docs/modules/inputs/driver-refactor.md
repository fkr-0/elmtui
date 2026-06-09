## Platform Driver Simplification Notes

### Current Pain Points
- `src/platform/driver.lisp` mixes backend lifecycle, input event translation, TEA dispatch, and pipeline orchestration in one thread entry point (~600 lines).
- The driver still contains raw terminal handling branches (manual timeouts, `sb-thread` primitives) that duplicate what `cl-inputs` now offers.
- Error handling, shutdown hooks, and focus/paste handling are scattered through `driver.lisp`, `platform/input.lisp`, and backend files, making it hard to reason about who owns the loops.

### Proposed Layering
1. **Device Adapter (cl-inputs)**  
   - Sole owner of raw fd/termios, emits `cl-inputs` tokens.  
   - Provides a reusable `start-input-loop`/`make-input-source` handle for all backends.
2. **Terminal Backend (per type)**  
   - Responsible only for double-buffering, ANSI/stateful rendering, capability negotiation, resize + signal handling.  
   - Consumes events already converted to `elmtui.core.event-types`.
3. **Driver Coordinator**  
   - Tracks running input loop handle, backend instance, and app message bus.  
   - Translates `cl-inputs` tokens to `elmtui` messages via a tiny adapter (e.g., `cl-inputs-token->event`), then publishes to the existing TEA pipelines.  
   - Contains no knowledge of raw streams or termios.

### Immediate Steps
- Replace the custom reader thread in `driver.lisp` with one that simply waits on `cl-inputs.loop:next-token` and dispatches the converted event.
- Move the backend-specific capability toggles (`enable-mouse`, focus notifications, paste) into `cl-inputs` device methods so the driver only sets high-level flags.
- Extract a small `driver/context` struct (backend, cl-inputs loop, publish-fn, resize-hook) to avoid passing dozens of keyword args through helper functions.

### Testing Strategy
- Extend the existing faketerm-based tests so the driver can be exercised with an in-memory device (cl-inputs faketerm + TEA pipeline).
- Keep `./rt.sh` as the integration gate: as long as it runs the app test suites via ASDF, we know the driver wiring still works.
