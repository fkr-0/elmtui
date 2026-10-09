# ElmTUI API Reference

Generated from live Common Lisp DOCUMENTATION metadata.

**Scope:** exported, live bindings in ElmTUI and its CL-EVENTS, CL-STATE, CL-INPUTS, CL-STYLES support packages. Re-exports appear once; each qualified name uses an exporting package.

**Coverage:** 1378 of 1822 bindings documented; 444 have no metadata (75.6% documented). Missing entries are intentionally shown, not silently omitted.

## CL-EVENTS.ASYNC:ALL

Kinds: function

```text
Create a composite asynchronous operation that waits for all supplied promises.
```

## CL-EVENTS.ASYNC:ASYNC-EXEC

Kinds: function

```text
Execute work asynchronously and return a handle to its completion.
```

## CL-EVENTS.ASYNC:ASYNC-RUN

Kinds: function

```text
Run asynchronous work using the asynchronous task machinery.
```

## CL-EVENTS.ASYNC:ASYNC-TASK

Kinds: type

```text
Public async task type used to represent structured terminal events and commands.
```

## CL-EVENTS.ASYNC:ASYNC-TASK-ERROR

Kinds: function

```text
Return the error recorded in the async task representation.
```

## CL-EVENTS.ASYNC:ASYNC-TASK-FINISHED-P

Kinds: function

```text
Return true when the supplied value satisfies the async task finished type predicate.
```

## CL-EVENTS.ASYNC:ASYNC-TASK-PROMISE

Kinds: function

```text
Return the promise recorded in the async task representation.
```

## CL-EVENTS.ASYNC:ASYNC-TASK-RESULT

Kinds: function

```text
Return the result recorded in the async task representation.
```

## CL-EVENTS.ASYNC:ASYNC-TASK-STATUS

Kinds: function

```text
Return the status recorded in the async task representation.
```

## CL-EVENTS.ASYNC:AWAIT

Kinds: function

```text
Wait for the supplied asynchronous promise and obtain its completed outcome.
```

## CL-EVENTS.ASYNC:CANCEL

Kinds: function

```text
Request cancellation of asynchronous work through its supported cancellation protocol.
```

## CL-EVENTS.ASYNC:CHAIN

Kinds: function

```text
Sequence asynchronous computations so the next operation receives the prior outcome.
```

## CL-EVENTS.ASYNC:FUTURE

Kinds: function

```text
Schedule computation and obtain a future handle for its eventual outcome.
```

## CL-EVENTS.ASYNC:MAKE-PROMISE

Kinds: function

```text
Allocate a pending promise for a value or condition delivered later.
```

## CL-EVENTS.ASYNC:MAKE-TASK-SCOPE

Kinds: function

```text
Create an OPEN structured task scope, optionally owned by PARENT.
```

## CL-EVENTS.ASYNC:NEW-TASK

Kinds: function

```text
Allocate a task record for asynchronous work before scheduling it.
```

## CL-EVENTS.ASYNC:PROMISE

Kinds: type

```text
Public promise type used to represent structured terminal events and commands.
```

## CL-EVENTS.ASYNC:PROMISE-CANCEL

Kinds: function

```text
Request cancellation of the given asynchronous promise.
```

## CL-EVENTS.ASYNC:PROMISE-CANCELLED

Kinds: function

```text
Return the cancelled recorded in the promise representation.
```

## CL-EVENTS.ASYNC:PROMISE-CANCELLED-P

Kinds: function

```text
Return true when the supplied value satisfies the promise cancelled type predicate.
```

## CL-EVENTS.ASYNC:PROMISE-ERROR

Kinds: function

```text
Return the error recorded in the promise representation.
```

## CL-EVENTS.ASYNC:PROMISE-RESOLVED

Kinds: function

```text
Return the resolved recorded in the promise representation.
```

## CL-EVENTS.ASYNC:PROMISE-STATE

Kinds: function

```text
Return the state recorded in the promise representation.
```

## CL-EVENTS.ASYNC:PROMISE-VALUE

Kinds: function

```text
Return the value recorded in the promise representation.
```

## CL-EVENTS.ASYNC:RACE

Kinds: function

```text
Create a composite asynchronous operation resolved by the first completed child.
```

## CL-EVENTS.ASYNC:REJECT-PROMISE

Kinds: function

```text
Mark a pending promise rejected with the supplied error outcome.
```

## CL-EVENTS.ASYNC:RESOLVE-PROMISE

Kinds: function

```text
Mark a pending promise resolved with the supplied successful value.
```

## CL-EVENTS.ASYNC:SCHEDULE-AFTER

Kinds: function

```text
Schedule a callback to execute after the requested delay.
```

## CL-EVENTS.ASYNC:SCHEDULE-EVERY

Kinds: function

```text
Schedule a recurring callback at the requested interval.
```

## CL-EVENTS.ASYNC:SCOPE-CANCEL

Kinds: function

```text
Cancel SCOPE and every currently owned child scope/task. Idempotent.
```

## CL-EVENTS.ASYNC:SCOPE-JOIN

Kinds: function

```text
Join owned work with one deadline; timeout cancels and reaps remaining workers.
```

## CL-EVENTS.ASYNC:SCOPE-SCHEDULE-AFTER

Kinds: function

```text
Run FUNCTION once after SECONDS as work owned by SCOPE.
```

## CL-EVENTS.ASYNC:SCOPE-SCHEDULE-EVERY

Kinds: function

```text
Run FUNCTION repeatedly every SECONDS until SCOPE is cancelled.
```

## CL-EVENTS.ASYNC:SCOPE-SPAWN

Kinds: function

```text
Register and start one ASYNC-TASK owned by SCOPE.
```

## CL-EVENTS.ASYNC:SPAWN-TASK

Kinds: function

```text
Start a task with the asynchronous executor and return its task handle.
```

## CL-EVENTS.ASYNC:TASK-SCOPE

Kinds: type

```text
Public task scope type used to represent structured terminal events and commands.
```

## CL-EVENTS.ASYNC:TASK-SCOPE-ERROR

Kinds: function

```text
Return the error recorded in the task scope representation.
```

## CL-EVENTS.ASYNC:TASK-SCOPE-STATE

Kinds: function

```text
Return the state recorded in the task scope representation.
```

## CL-EVENTS.BUS:EVENT-BUS

Kinds: type

_No documentation metadata._

## CL-EVENTS.BUS:EVENT-BUS-METRICS

Kinds: function

```text
Return a lock-consistent snapshot of bus counters and active subscription count.
```

## CL-EVENTS.BUS:MAKE-EVENT-BUS

Kinds: function

```text
Create a bounded event bus. :BLOCK preserves legacy backpressure semantics.
```

## CL-EVENTS.BUS:PUBLISH-EVENT

Kinds: function

```text
Publish EVENT in stable subscription order under the configured delivery policies.
```

## CL-EVENTS.BUS:SUBSCRIBE

Kinds: function

```text
Compatibility API returning only the channel of a new independent subscription.
```

## CL-EVENTS.BUS:SUBSCRIBE-HANDLE

Kinds: function

```text
Create one independent subscription handle. Duplicate topic subscriptions are allowed.
```

## CL-EVENTS.BUS:SUBSCRIPTION

Kinds: type

_No documentation metadata._

## CL-EVENTS.BUS:SUBSCRIPTION-ACTIVE-P

Kinds: function

_No documentation metadata._

## CL-EVENTS.BUS:SUBSCRIPTION-CHANNEL

Kinds: function

_No documentation metadata._

## CL-EVENTS.BUS:SUBSCRIPTION-METRICS

Kinds: function

```text
Return a snapshot without holding the bus lock while acquiring the channel lock.
```

## CL-EVENTS.BUS:SUBSCRIPTION-TOPIC

Kinds: function

_No documentation metadata._

## CL-EVENTS.BUS:UNSUBSCRIBE

Kinds: function

```text
Compatibility unsubscribe. The removed subscription channel is closed to wake waiters.
```

## CL-EVENTS.BUS:UNSUBSCRIBE-HANDLE

Kinds: function

```text
End HANDLE once, remove it from the bus, and close its owned channel.
```

## CL-EVENTS.BUS:WITH-SUBSCRIPTION

Kinds: macro

_No documentation metadata._

## CL-EVENTS.CHANNEL:->

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:<-

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:CHAN-CLOSE

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:CHAN-PUT

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:CHAN-TAKE

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:CHANNEL

Kinds: type

_No documentation metadata._

## CL-EVENTS.CHANNEL:CHANNEL-ADD-FILTER

Kinds: function

```text
Add FILTER to filtered channel CH. FILTER must be callable.
```

## CL-EVENTS.CHANNEL:CHANNEL-LENGTH

Kinds: function

```text
Return the current queue length of CH.
```

## CL-EVENTS.CHANNEL:CHANNEL-PUT!

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:CHANNEL-REMOVE-FILTER

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:CHANNEL-STATE

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:CHANNEL-TAKE!

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:FILTERED-CHANNEL

Kinds: type

_No documentation metadata._

## CL-EVENTS.CHANNEL:MAILBOX

Kinds: type

_No documentation metadata._

## CL-EVENTS.CHANNEL:MAILBOX-STATE

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:MAKE-CHANNEL

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:MAKE-FILTERED-CHANNEL

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:MAKE-MAILBOX

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:MB-CLOSE

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:MB-EMPTY-P

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:MB-PUT

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:MB-TAKE

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:NO-WAIT

Kinds: function

_No documentation metadata._

## CL-EVENTS.CHANNEL:SELECT

Kinds: macro

```text
Select channel operations. Clause order is the deterministic tie breaker.
```

## CL-EVENTS.CHANNEL:TRY-PUT

Kinds: function

```text
Atomically enqueue ITEM without waiting and return success plus status.
```

## CL-EVENTS.DISPATCHER:DISPATCH-EVENT

Kinds: function

_No documentation metadata._

## CL-EVENTS.DISPATCHER:DISPATCH-MESSAGE-BATCH

Kinds: function

```text
Apply messages in order; return (values new-state commands)
```

## CL-EVENTS.DISPATCHER:EXECUTE-COMMANDS

Kinds: function

```text
Run effects; effects may publish further events.
```

## CL-EVENTS.LIFECYCLE:CANCELLATION-REASON

Kinds: function

```text
Return the cancellation reason recorded on TOKEN.
```

## CL-EVENTS.LIFECYCLE:CANCELLATION-REQUESTED-P

Kinds: function

```text
Return whether TOKEN has been cancelled.
```

## CL-EVENTS.LIFECYCLE:CANCELLATION-TOKEN

Kinds: type

_No documentation metadata._

## CL-EVENTS.LIFECYCLE:DEADLINE-BUDGET

Kinds: type

_No documentation metadata._

## CL-EVENTS.LIFECYCLE:DEADLINE-BUDGET-EXPIRED-P

Kinds: function

```text
Return true when BUDGET has a deadline and that deadline has been reached.
```

## CL-EVENTS.LIFECYCLE:DEADLINE-BUDGET-REMAINING-SECONDS

Kinds: function

```text
Return remaining seconds, NIL for an unbounded budget, or zero when expired.
```

## CL-EVENTS.LIFECYCLE:MAKE-CANCELLATION-TOKEN

Kinds: function

```text
Create an independently cancellable lifecycle token.
```

## CL-EVENTS.LIFECYCLE:MAKE-DEADLINE-BUDGET

Kinds: function

```text
Create one monotonic timeout budget. NIL means no deadline.
```

## CL-EVENTS.LIFECYCLE:REQUEST-CANCELLATION

Kinds: function

```text
Cancel TOKEN once, wake its waiters, and return the resulting lifecycle state.
```

## CL-EVENTS.LOOP:+DEFAULT-POLL-INTERVAL-SECONDS+

Kinds: variable

```text
Default cooperative pause between unsuccessful polling probes.
```

## CL-EVENTS.LOOP:+DEFAULT-POLL-TIMEOUT-SECONDS+

Kinds: variable

```text
Default timeout (seconds) for poll-based event loops.
```

## CL-EVENTS.LOOP:APP-CONTEXT

Kinds: type

_No documentation metadata._

## CL-EVENTS.LOOP:APP-CONTEXT-LOOP-TASK

Kinds: function

_No documentation metadata._

## CL-EVENTS.LOOP:DEADLINE-EXPIRED-P

Kinds: function

```text
Return true when NOW-FN has reached or passed DEADLINE.
```

## CL-EVENTS.LOOP:DEFAULT-RUNTIME-ERROR-POLICY

Kinds: function

```text
Default runtime error policy; currently always stops the loop.
```

## CL-EVENTS.LOOP:JOIN-APP-LOOP

Kinds: function

```text
Wait for the owned app-loop task and return its value plus lifecycle status.
```

## CL-EVENTS.LOOP:MAKE-APP-CONTEXT

Kinds: function

_No documentation metadata._

## CL-EVENTS.LOOP:MAKE-JOIN-DEADLINE

Kinds: function

```text
Return an internal-time deadline SECONDS from NOW-FN.
```

## CL-EVENTS.LOOP:POLL-RUNTIME-EVENT

Kinds: function

```text
Poll CHANNELS through WAIT-FN using the shared runtime timeout contract.

WAIT-FN is called as (WAIT-FN CHANNELS :TIMEOUT TIMEOUT) and its multiple values
are returned unchanged.  Implementations that need repeated non-blocking probes
should use POLL-UNTIL rather than introducing an independent sleep/deadline
loop.  This function performs no mutation itself and propagates conditions from
WAIT-FN unchanged.
```

## CL-EVENTS.LOOP:POLL-UNTIL

Kinds: function

```text
Run PROBE-FN until it succeeds, STOP-P requests cancellation, or TIMEOUT expires.

PROBE-FN may return multiple values.  Its first value is the success value; when
that value is non-NIL all values are returned unchanged.  A NIL first value
means that no result is ready yet.

TIMEOUT is measured in seconds.  NIL means wait indefinitely, zero means perform
exactly one probe, and a positive value bounds the total wait.  STOP-P, when
non-NIL, is called before every probe and can end an otherwise unbounded wait.
INTERVAL is the cooperative sleep between unsuccessful probes and must be a
non-negative real.  A finite timeout clamps each sleep to the remaining budget,
and no retry begins after that budget expires.

The optional SLEEP-FN and NOW-FN hooks make timing deterministic in tests.
Polling itself performs no mutation other than whatever PROBE-FN, STOP-P, or the
injected timing functions perform.  Conditions signaled by those functions are
not swallowed; callers can inspect them or establish handlers/restarts.
```

## CL-EVENTS.LOOP:RESOLVE-RUNTIME-ERROR-ACTION

Kinds: function

```text
Resolve POLICY to a concrete runtime error action (:stop or :restart).
POLICY can be a keyword action or a function of ERROR.
```

## CL-EVENTS.LOOP:RUN-APP-LOOP

Kinds: function

_No documentation metadata._

## CL-EVENTS.LOOP:RUN-CONSUMER-LOOP-SHELL

Kinds: function

```text
Reusable consumer lifecycle shell.
Loops until STOP-P is true or STEP-FN requests stop/restart.
When CHANNELS-FN returns NIL, ON-IDLE is called.
STEP-FN should return an action keyword; :stop and :restart are handled explicitly.
```

## CL-EVENTS.LOOP:RUNTIME-CONSUME-ONCE

Kinds: function

```text
Execute one runtime consume iteration with policy hooks.
Returns one of :stop, :event, :idle, :continue, :restart, or :error.
```

## CL-EVENTS.LOOP:SELECT-PRIMARY-CHANNEL

Kinds: function

```text
Select channel from CHANNELS by DESIRED-NAME using NAME-FN, fallback to first.
```

## CL-EVENTS.LOOP:STOP-APP-LOOP

Kinds: function

```text
Request app-loop shutdown without waiting for worker termination.
```

## CL-EVENTS.MESSAGING:ENVELOPE->MESSAGES

Kinds: function

_No documentation metadata._

## CL-EVENTS.MESSAGING:EXPAND-MESSAGE

Kinds: function

_No documentation metadata._

## CL-EVENTS.MESSAGING:MAKE-MESSAGE-ENVELOPE

Kinds: function

_No documentation metadata._

## CL-EVENTS.MESSAGING:MESSAGE->ENVELOPE

Kinds: function

_No documentation metadata._

## CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE

Kinds: type

_No documentation metadata._

## CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-BROADCAST-P

Kinds: function

_No documentation metadata._

## CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-BUBBLE-P

Kinds: function

_No documentation metadata._

## CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-CAPTURE-P

Kinds: function

_No documentation metadata._

## CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-MESSAGE

Kinds: function

_No documentation metadata._

## CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-PHASE

Kinds: function

_No documentation metadata._

## CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-STOP-P

Kinds: function

_No documentation metadata._

## CL-EVENTS.MESSAGING:MESSAGE-PHASES

Kinds: function

_No documentation metadata._

## CL-EVENTS.PROTOCOLS:APP-UPDATE

Kinds: function

```text
Pure update. Returns NEW-STATE and a list of COMMANDs.
```

## CL-EVENTS.PROTOCOLS:APP-VIEW

Kinds: function

```text
Pure view function producing a renderable tree.
```

## CL-EVENTS.PROTOCOLS:BROADCAST-P

Kinds: function

_No documentation metadata._

## CL-EVENTS.PROTOCOLS:BUBBLE-P

Kinds: function

_No documentation metadata._

## CL-EVENTS.PROTOCOLS:CAPTURE-P

Kinds: function

_No documentation metadata._

## CL-EVENTS.PROTOCOLS:EVENT-PAYLOAD

Kinds: function

_No documentation metadata._

## CL-EVENTS.PROTOCOLS:EVENT-TIMESTAMP

Kinds: function

_No documentation metadata._

## CL-EVENTS.PROTOCOLS:EVENT-TOPIC

Kinds: function

_No documentation metadata._

## CL-EVENTS.PROTOCOLS:MESSAGE-PRIORITY

Kinds: function

_No documentation metadata._

## CL-EVENTS.PROTOCOLS:MESSAGE-STATE

Kinds: function

_No documentation metadata._

## CL-EVENTS.PROTOCOLS:PERFORM-COMMAND

Kinds: function

```text
Run effect; may publish events back to the bus.
```

## CL-EVENTS.PROTOCOLS:PERFORM-RENDER

Kinds: function

```text
Render VIEW-MODEL. May consult APP-STATE for metrics.
```

## CL-EVENTS.PROTOCOLS:STOP-PROPAGATION

Kinds: function

_No documentation metadata._

## CL-EVENTS.PROTOCOLS:TRANSLATE-EVENT->MESSAGES

Kinds: function

```text
Return a list of MESSAGES produced by EVENT.
```

## CL-EVENTS.SYSTEM-EVENTS:MAKE-APP-SHUTDOWN-EVENT

Kinds: function

```text
Construct a normalized app shutdown event payload.
```

## CL-EVENTS.SYSTEM-EVENTS:MAKE-CURSOR-POSITION-EVENT

Kinds: function

```text
Construct a normalized cursor position event payload.
```

## CL-EVENTS.SYSTEM-EVENTS:MAKE-TERMINAL-RESIZED-EVENT

Kinds: function

```text
Construct a normalized terminal resize event payload.
```

## CL-EVENTS.TYPES:COMMAND

Kinds: type

```text
Public command type used to represent structured terminal events and commands.
```

## CL-EVENTS.TYPES:COMMAND-ARGS

Kinds: function

```text
Return the args recorded in the command representation.
```

## CL-EVENTS.TYPES:COMMAND-TYPE

Kinds: function

```text
Return the type recorded in the command representation.
```

## CL-EVENTS.TYPES:CONSUME-EVENT

Kinds: function

```text
Mark an event as consumed to prevent further processing.
```

## CL-EVENTS.TYPES:EVENT

Kinds: type

```text
Public event type used to represent structured terminal events and commands.
```

## CL-EVENTS.TYPES:EVENT-DATA

Kinds: function

```text
Return the payload data stored in EVENT.
```

## CL-EVENTS.TYPES:EVENT-TYPE

Kinds: function

```text
Return the event type stored in EVENT.
```

## CL-EVENTS.TYPES:EVENT-WHEN

Kinds: function

```text
Return the timestamp stored in EVENT.
```

## CL-EVENTS.TYPES:FOCUS-EVENT

Kinds: type

```text
Public focus event type used to represent structured terminal events and commands.
```

## CL-EVENTS.TYPES:FOCUS-EVENT-CONSUMED-P

Kinds: function

```text
Report whether this focus event has been marked consumed by an event handler.
```

## CL-EVENTS.TYPES:FOCUS-EVENT-P

Kinds: function

```text
Return true when the supplied value satisfies the focus event type predicate.
```

## CL-EVENTS.TYPES:FOCUS-EVENT-SOURCE

Kinds: function

```text
Return the source recorded in the focus event representation.
```

## CL-EVENTS.TYPES:FOCUS-EVENT-TARGET

Kinds: function

```text
Return the target recorded in the focus event representation.
```

## CL-EVENTS.TYPES:FOCUS-EVENT-TIMESTAMP

Kinds: function

```text
Return the timestamp recorded in the focus event representation.
```

## CL-EVENTS.TYPES:FOCUS-EVENT-TYPE

Kinds: function

```text
Return the type recorded in the focus event representation.
```

## CL-EVENTS.TYPES:HAS-MODIFIER-P

Kinds: function

```text
Checks if an event has a specific modifier.
```

## CL-EVENTS.TYPES:KEY-EVENT

Kinds: type

```text
Public key event type used to represent structured terminal events and commands.
```

## CL-EVENTS.TYPES:KEY-EVENT-CHAR

Kinds: function

```text
Return the char recorded in the key event representation.
```

## CL-EVENTS.TYPES:KEY-EVENT-CODE

Kinds: function

```text
Return the code recorded in the key event representation.
```

## CL-EVENTS.TYPES:KEY-EVENT-CONSUMED-P

Kinds: function

```text
Report whether this key event has been marked consumed by an event handler.
```

## CL-EVENTS.TYPES:KEY-EVENT-KEY

Kinds: function

```text
Return the key recorded in the key event representation.
```

## CL-EVENTS.TYPES:KEY-EVENT-MODIFIERS

Kinds: function

```text
Return the modifiers recorded in the key event representation.
```

## CL-EVENTS.TYPES:KEY-EVENT-P

Kinds: function

```text
Return true when the supplied value satisfies the key event type predicate.
```

## CL-EVENTS.TYPES:KEY-EVENT-TIMESTAMP

Kinds: function

```text
Return the timestamp recorded in the key event representation.
```

## CL-EVENTS.TYPES:KEY-EVENT-TYPE

Kinds: function

```text
Return the type recorded in the key event representation.
```

## CL-EVENTS.TYPES:MAKE-COMMAND

Kinds: function

```text
Construct a COMMAND from TYPE and ARGS.
```

## CL-EVENTS.TYPES:MAKE-EVENT

Kinds: function

```text
Construct an EVENT from TYPE, DATA, and WHEN fields.
```

## CL-EVENTS.TYPES:MAKE-FOCUS-EVENT

Kinds: function

```text
Construct a focus event structure from its provided initialization fields.
```

## CL-EVENTS.TYPES:MAKE-KEY-EVENT

Kinds: function

```text
Construct a key event structure from its provided initialization fields.
```

## CL-EVENTS.TYPES:MAKE-MESSAGE

Kinds: function

```text
Construct a MESSAGE carrying TYPE, DATA, STATE, and PRIORITY metadata.
```

## CL-EVENTS.TYPES:MAKE-MOUSE-EVENT

Kinds: function

```text
Construct a mouse event structure from its provided initialization fields.
```

## CL-EVENTS.TYPES:MAKE-UI-EVENT

Kinds: function

```text
Construct a ui event structure from its provided initialization fields.
```

## CL-EVENTS.TYPES:MESSAGE

Kinds: type

```text
Public message type used to represent structured terminal events and commands.
```

## CL-EVENTS.TYPES:MESSAGE-DATA

Kinds: function

```text
Return the payload data stored in MESSAGE.
```

## CL-EVENTS.TYPES:MESSAGE-TYPE

Kinds: function

```text
Return the message type stored in MESSAGE.
```

## CL-EVENTS.TYPES:MOUSE-EVENT

Kinds: type

```text
Public mouse event type used to represent structured terminal events and commands.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-BUTTON

Kinds: function

```text
Return the button recorded in the mouse event representation.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-CLICK-COUNT

Kinds: function

```text
Return the click count recorded in the mouse event representation.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-CONSUMED-P

Kinds: function

```text
Report whether this mouse event has been marked consumed by an event handler.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-DELTA-X

Kinds: function

```text
Return the delta x recorded in the mouse event representation.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-DELTA-Y

Kinds: function

```text
Return the delta y recorded in the mouse event representation.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-MODIFIERS

Kinds: function

```text
Return the modifiers recorded in the mouse event representation.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-P

Kinds: function

```text
Return true when the supplied value satisfies the mouse event type predicate.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-TIMESTAMP

Kinds: function

```text
Return the timestamp recorded in the mouse event representation.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-TYPE

Kinds: function

```text
Return the type recorded in the mouse event representation.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-X

Kinds: function

```text
Return the x recorded in the mouse event representation.
```

## CL-EVENTS.TYPES:MOUSE-EVENT-Y

Kinds: function

```text
Return the y recorded in the mouse event representation.
```

## CL-EVENTS.TYPES:PREVENT-DEFAULT

Kinds: function

```text
Marks event as having its default behavior prevented.
```

## CL-EVENTS.TYPES:STOP-PROPAGATION*

Kinds: function

```text
Generic function to stop event propagation.
```

## CL-EVENTS.TYPES:UI-EVENT

Kinds: type

```text
Public ui event type used to represent structured terminal events and commands.
```

## CL-EVENTS.TYPES:UI-EVENT-CONSUMED-P

Kinds: function

```text
Report whether this ui event has been marked consumed by an event handler.
```

## CL-EVENTS.TYPES:UI-EVENT-ORIGINAL-EVENT

Kinds: function

```text
Return the original event recorded in the ui event representation.
```

## CL-EVENTS.TYPES:UI-EVENT-P

Kinds: function

```text
Return true when the supplied value satisfies the ui event type predicate.
```

## CL-EVENTS.TYPES:UI-EVENT-TARGET

Kinds: function

```text
Return the target recorded in the ui event representation.
```

## CL-EVENTS.TYPES:UI-EVENT-TIMESTAMP

Kinds: function

```text
Return the timestamp recorded in the ui event representation.
```

## CL-EVENTS.TYPES:UI-EVENT-TYPE

Kinds: function

```text
Return the type recorded in the ui event representation.
```

## CL-INPUTS.ADAPTERS:TOKEN->NORMALIZED-EVENT

Kinds: function

```text
Convert a cl-inputs token into a normalized event plist.
Returns NIL when TOKEN kind is unsupported.
```

## CL-INPUTS.API:MAKE-READY-INPUT-SOURCE

Kinds: function

```text
Return an owned input source; lifecycle setup is centralized in MAKE-INPUT-SOURCE.
```

## CL-INPUTS.API:READ-TOKENS

Kinds: function

```text
Read all available tokens from DEV until TIMEOUT seconds elapse.

Arguments:
  DEV     -- device object supporting input
  TIMEOUT -- maximum seconds to wait for input (type: real, default: 5)

Return Value:
  List of tokens read from DEV.

Side Effects:
  Closes the input source after reading.
```

## CL-INPUTS.API:SET-TERMINAL-MODES

Kinds: function

```text
Convenience: toggle device terminal modes via device-set-modes.
```

## CL-INPUTS.API:WITH-ASYNC-SIGNAL

Kinds: macro

```text
Run BODY in a background thread, allowing interruption and result retrieval.
RETURN-VAR is a symbol bound to NIL and can be set within BODY to track progress or result.
Defines a SIGNAL-FN function that interrupts the thread and returns the current value of RETURN-VAR.
Returns (values thread signal-fn device).
```

## CL-INPUTS.API:WITH-INPUT-SOURCE

Kinds: macro

```text
Bind VAR to a ready input-source around BODY; cleans up on exit.
```

## CL-INPUTS.API:WITH-RAW-INPUT

Kinds: macro

```text
Own DEV for BODY: open once, enter raw-char mode once, and restore/close once.
```

## CL-INPUTS.DECODER:DECODE-CHUNK

Kinds: function

```text
Incrementally decode OCTET-VECTOR into semantic input tokens.

Chunk boundaries do not change semantic output. NOW, when supplied, is monotonic
seconds used only for externally controlled ambiguity-deadline evaluation.
```

## CL-INPUTS.DECODER:DECODER-BUFFERED-BYTE-COUNT

Kinds: function

```text
Return the number of bytes retained across decode calls.
```

## CL-INPUTS.DECODER:DECODER-NEXT-DEADLINE

Kinds: function

```text
Return the pending ESC ambiguity deadline in monotonic seconds, or NIL.
```

## CL-INPUTS.DECODER:DECODER-STATE

Kinds: function

```text
Return a diagnostic snapshot of DECODER's raw parser state.
```

## CL-INPUTS.DECODER:FINISH-DECODER

Kinds: function

```text
Finish DECODER at end-of-stream and return final tokens plus reset state.
```

## CL-INPUTS.DECODER:MAKE-DECODER

Kinds: function

```text
Create a semantic decoder with explicit raw-protocol bounds and ESC policy.
```

## CL-INPUTS.DEVICE.API:ACQUIRE-LOCK

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.API:CLOSE-DEVICE

Kinds: function

```text
Idempotently release backend-owned resources. Concrete terminal devices
must restore any raw state they still own before their descriptors disappear.
```

## CL-INPUTS.DEVICE.API:DEVICE-CAPABILITIES

Kinds: function

```text
Return a plist describing negotiated/known features, e.g.:
    (:truecolor t
     :mouse :sgr             ; :x10 | :urxvt | :sgr
     :focus-events t
     :bracketed-paste t
     :winch t                ; supports reporting resize
     :term ("xterm-256color"))
```

## CL-INPUTS.DEVICE.API:DEVICE-ERROR

Kinds: type

```text
Generic device error condition for device API failures.
```

## CL-INPUTS.DEVICE.API:DEVICE-FD

Kinds: function

```text
Return the underlying file descriptor for DEV, or NIL if not supported.
```

## CL-INPUTS.DEVICE.API:DEVICE-INPUT-STREAM

Kinds: function

```text
Return the underlying binary input stream for DEV, or NIL if not available.
```

## CL-INPUTS.DEVICE.API:DEVICE-KIND

Kinds: function

```text
Return a keyword like :tty, :faketerm, :urxvt.
```

## CL-INPUTS.DEVICE.API:DEVICE-OUTPUT-STREAM

Kinds: function

```text
Return the underlying binary output stream for DEV, or NIL if not available.
```

## CL-INPUTS.DEVICE.API:DEVICE-READ-BYTES

Kinds: function

```text
Perform at most one read attempt into BUFFER[START,END). Return a positive
byte count, 0 for a zero-length request, :EOF for terminal end, :WOULD-BLOCK for
EAGAIN/EWOULDBLOCK, or :INTERRUPTED for EINTR. The caller owns retry/deadline
policy; implementations must not hide retry loops or fixed readiness sleeps.
```

## CL-INPUTS.DEVICE.API:DEVICE-SET-MODES

Kinds: function

```text
Enable terminal modes (mouse tracking, bracketed paste, focus in/out).
    MODES is a plist, e.g. (:mouse :sgr :paste t :focus t).
```

## CL-INPUTS.DEVICE.API:DEVICE-SET-NONBLOCKING

Kinds: function

```text
Enable/disable O_NONBLOCK; return FLAG actually set.
```

## CL-INPUTS.DEVICE.API:DEVICE-WAIT-READABLE

Kinds: function

```text
Wait at most TIMEOUT-MS (a non-negative real, or NIL) for readability.
Return T if readable, NIL on timeout, or :INTERRUPTED for EINTR. The caller is
responsible for recomputing its remaining deadline budget before retrying.
```

## CL-INPUTS.DEVICE.API:DEVICE-WRITE-BYTES

Kinds: function

```text
Optional; return bytes written.
```

## CL-INPUTS.DEVICE.API:DISABLE-RAW-CHAR-MODE

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.API:DISABLE-RAW-MODE

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.API:ENABLE-RAW-CHAR-MODE

Kinds: function

```text
Enter raw character mode; SHOULD be idempotent and nestable.
```

## CL-INPUTS.DEVICE.API:ENABLE-RAW-MODE

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.API:LOCK-OF

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.API:LOCKABLE

Kinds: type

_No documentation metadata._

## CL-INPUTS.DEVICE.API:MAKE-DEVICE

Kinds: function

```text
Construct a device instance for BACKEND (a keyword or descriptor).
    No global singletons; return a self-contained handle.
```

## CL-INPUTS.DEVICE.API:OPEN-DEVICE

Kinds: function

```text
Acquire DEV resources idempotently and return DEV. A backend that acquires
multiple resources must clean up already-acquired resources if opening fails.
```

## CL-INPUTS.DEVICE.API:RAW-MODE-ERROR

Kinds: type

```text
Condition signaled when raw mode operations fail.
```

## CL-INPUTS.DEVICE.API:RELEASE-LOCK

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.API:WITH-LOCK

Kinds: macro

```text
Execute BODY with the lock of LOCKABLE L acquired.
This macro ensures that the lock is acquired before executing BODY,
and released afterwards, even if an error occurs during execution.
It uses `acquire-lock` and `release-lock` methods to manage the lock.
This is useful for ensuring thread safety when accessing shared resources.
```

## CL-INPUTS.DEVICE.API:WITH-RAW-CHAR-MODE

Kinds: macro

```text
Portable wrapper that enables raw char mode before BODY and restores it after,
   relying on device methods. Idempotent and safe to nest.
```

## CL-INPUTS.DEVICE.API:WITH-TERMINAL-LOCK

Kinds: macro

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-CAPTURED

Kinds: function

```text
Return all octets captured in the output queue of DEV.
```

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-CLOSE-COUNT

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-CLOSED-P

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-HEIGHT

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-NONBLOCKING-P

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-OPEN-P

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-P

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-RAW-DEPTH

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-READ-COUNT

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-WAIT-COUNT

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-WIDTH

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-INJECT!

Kinds: function

```text
Inject OCTETS into the input queue of DEV.
```

## CL-INPUTS.DEVICE.FAKETERM:FAKETERM-SCREEN-LINES

Kinds: function

```text
Return the fake screen contents as a list of strings.
```

## CL-INPUTS.DEVICE.TTY:MAKE-TTY-DEVICE

Kinds: function

_No documentation metadata._

## CL-INPUTS.DEVICE.TTY:TTY-DEVICE

Kinds: type

_No documentation metadata._

## CL-INPUTS.DEVICE.TTY:TTY-DEVICE-PATH

Kinds: function

_No documentation metadata._

## CL-INPUTS.ESCAPE:CSI-FINAL-BYTE-P

Kinds: function

```text
Return T if BYTE is an ECMA-48 final byte (0x40..0x7E), NIL otherwise.
```

## CL-INPUTS.ESCAPE:DECODE-CSI-TO-TOKEN

Kinds: function

```text
Attempt to map a full CSI/ESC sequence (OCTETS) to a token.
Return NIL to let the generic path try SGR mouse or fallback handling.
Override this function to provide custom escape sequence decoding.
```

## CL-INPUTS.KEYMAP:*DEFAULT-KEYMAP*

Kinds: variable

```text
Default keymap: maps common escape sequences to symbolic key names.
Extend this table to support additional keys or custom layouts.
```

## CL-INPUTS.KEYMAP:CANONICALIZE-KEY

Kinds: function

```text
Return a stable keyword for CHAR and its modifier flags.

Modifiers use the conventional C-/M-/S- prefixes, in that order.  For
example, Control+Alt+Shift+A becomes :C-M-S-A.
```

## CL-INPUTS.KEYMAP:LOOKUP-SEQ

Kinds: function

```text
Look up OCTETS (vector of char codes) in TABLE and return the mapped key symbol.
Returns NIL if no match is found.
```

## CL-INPUTS.LOOP:CANCEL-INPUT-SOURCE

Kinds: function

```text
Idempotently cancel SRC and wait for its active bounded read to unwind.
```

## CL-INPUTS.LOOP:CLOSE-INPUT-SOURCE

Kinds: function

```text
Idempotently close SRC after any active bounded read returns.
```

## CL-INPUTS.LOOP:EXPECT-TERMINAL-RESPONSE

Kinds: function

```text
Register RESPONSE-TYPE on SRC without writing terminal bytes.

This is the correlation seam for protocol extensions. Register before emitting a
custom query so a fast response cannot race ahead of its correlation.
```

## CL-INPUTS.LOOP:INPUT-LOOP

Kinds: type

```text
State for a running input loop.

Fields:
  DEV            -- device handle (type: device object)
  SINK           -- sink function or object for token delivery (type: function or sink object)
  DECODER        -- decoder state object (type: decoder)
  THREAD         -- thread running the loop (if async) (type: thread or null)
  STOP?          -- flag to request loop termination (type: boolean)
  CONDITION      -- condition variable for sync/notify (type: condition-variable or null)
  CONDITION-LOCK -- lock for condition variable (type: lock or null)
  LAST-OUTPUT    -- last token delivered (type: token or null)

All fields are required except THREAD, CONDITION, CONDITION-LOCK, and LAST-OUTPUT, which may be NIL if not used.
```

## CL-INPUTS.LOOP:INPUT-SOURCE-OWNS-DEVICE-P

Kinds: function

_No documentation metadata._

## CL-INPUTS.LOOP:INPUT-SOURCE-RESPONSE-ROUTER

Kinds: function

_No documentation metadata._

## CL-INPUTS.LOOP:INPUT-SOURCE-STATE

Kinds: function

_No documentation metadata._

## CL-INPUTS.LOOP:INPUT-SOURCE-TERMINAL-OUTCOME

Kinds: function

_No documentation metadata._

## CL-INPUTS.LOOP:MAKE-INPUT-SOURCE

Kinds: function

```text
Create an explicit source lifecycle around DEVICE and DECODER.

When OWNS-DEVICE-P is true (the default), this function opens DEVICE, enables
nonblocking reads and raw-character mode, and the returned source is responsible
for restoring raw mode and closing the device exactly once. Partial-open or
raw-mode failure is cleaned up before the original condition is re-signaled.
When OWNS-DEVICE-P is false, the caller retains ownership and must keep DEVICE
open, raw-configured, and nonblocking for the source lifetime; the source never
changes or closes that borrowed device.
```

## CL-INPUTS.LOOP:NEXT-TOKEN

Kinds: function

```text
Return the next token, NIL on timeout/end, and preserve source terminal state.

TIMEOUT is a non-negative number of seconds or NIL for an indefinite logical
wait. Even an indefinite wait uses finite readiness slices so concurrent
close/cancel is observed. EINTR retries consume the caller's original budget;
EAGAIN/would-block returns to readiness waiting rather than spinning. The
Phase-A decoder ESC deadline participates in the same deadline calculation.
```

## CL-INPUTS.LOOP:SEND-TERMINAL-QUERY

Kinds: function

```text
Register and emit a supported read-only terminal protocol QUERY.

The correlation is installed before bytes are written. A short/failed write
cancels the correlation and signals rather than leaving an unfulfillable live
request. QUERY describes protocol negotiation only; it carries no rendering
policy.
```

## CL-INPUTS.LOOP:START-INPUT-LOOP

Kinds: function

```text
Start an input loop. MODE can be :async (default) or :sync.
```

## CL-INPUTS.LOOP:STOP-INPUT-LOOP

Kinds: function

```text
Request loop cancellation. Active reads are bounded by the source wait slice.
```

## CL-INPUTS.LOOP:TAKE-INPUT-PROTOCOL-DIAGNOSTIC

Kinds: function

```text
Return the oldest malformed/unknown protocol token retained by SRC.
```

## CL-INPUTS.LOOP:TAKE-UNMATCHED-TERMINAL-RESPONSE

Kinds: function

```text
Return the oldest valid terminal reply that had no live correlation.
```

## CL-INPUTS.LOOP:WAIT-TERMINAL-RESPONSE

Kinds: function

```text
Pump SRC until CORRELATION matches/expires, without consuming user input.

User-input tokens observed while waiting remain queued for NEXT-TOKEN in their
original order. TIMEOUT bounds this wait only; the correlation keeps its own
absolute deadline and may remain :PENDING if this call returns earlier.
```

## CL-INPUTS.PROTOCOL:+DEFAULT-ESCAPE-TIMEOUT+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.PROTOCOL:+DEFAULT-MAX-BUFFER-BYTES+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.PROTOCOL:+DEFAULT-MAX-PASTE-BYTES+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.PROTOCOL:+DEFAULT-MAX-SEQUENCE-BYTES+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.PROTOCOL:DECODE-UTF-8-OCTETS

Kinds: function

```text
Decode OCTETS, replacing malformed bytes deterministically.
Return string, validity, and number of replacement events.
```

## CL-INPUTS.PROTOCOL:FINISH-PROTOCOL

Kinds: function

```text
Finish a byte stream and convert retained incomplete input to typed events.
```

## CL-INPUTS.PROTOCOL:MAKE-PROTOCOL-PARSER

Kinds: function

```text
Create a bounded incremental terminal-protocol recognizer.

CLOCK returns monotonic seconds. ESCAPE-TIMEOUT resolves only standalone Escape
ambiguity; the parser never sleeps. Sequence, paste, and aggregate retained
state are constrained by explicit hard limits.
```

## CL-INPUTS.PROTOCOL:PROTOCOL-BUFFERED-BYTE-COUNT

Kinds: function

_No documentation metadata._

## CL-INPUTS.PROTOCOL:PROTOCOL-EVENT

Kinds: type

_No documentation metadata._

## CL-INPUTS.PROTOCOL:PROTOCOL-EVENT-CATEGORY

Kinds: function

_No documentation metadata._

## CL-INPUTS.PROTOCOL:PROTOCOL-EVENT-METADATA

Kinds: function

_No documentation metadata._

## CL-INPUTS.PROTOCOL:PROTOCOL-EVENT-PAYLOAD

Kinds: function

_No documentation metadata._

## CL-INPUTS.PROTOCOL:PROTOCOL-EVENT-RAW

Kinds: function

_No documentation metadata._

## CL-INPUTS.PROTOCOL:PROTOCOL-EVENT-REASON

Kinds: function

_No documentation metadata._

## CL-INPUTS.PROTOCOL:PROTOCOL-NEXT-DEADLINE

Kinds: function

_No documentation metadata._

## CL-INPUTS.PROTOCOL:PROTOCOL-PARSER-STATE

Kinds: function

```text
Return a diagnostic snapshot with copies of retained protocol bytes only.
```

## CL-INPUTS.PROTOCOL:RECOGNIZE-CHUNK

Kinds: function

```text
Consume OCTET-VECTOR, returning raw events and a fresh parser state.

NOW is a monotonic timestamp in seconds. If omitted, the injected parser clock
is called once. Retained parser state is copied so the supplied PARSER remains
unchanged.
```

## CL-INPUTS.ROUTING:+DEFAULT-MAX-PROTOCOL-BACKLOG+

Kinds: variable

```text
Maximum unmatched replies or protocol diagnostics retained per router queue.
```

## CL-INPUTS.ROUTING:+DEFAULT-MAX-RESPONSE-CORRELATIONS+

Kinds: variable

```text
Maximum simultaneously pending response correlations per input source.
```

## CL-INPUTS.ROUTING:CANCEL-RESPONSE-CORRELATION

Kinds: function

```text
Idempotently cancel CORRELATION unless it already reached a terminal state.
```

## CL-INPUTS.ROUTING:EXPIRE-RESPONSE-CORRELATIONS

Kinds: function

```text
Expire all pending correlations whose absolute deadlines are due.
```

## CL-INPUTS.ROUTING:MAKE-RESPONSE-ROUTER

Kinds: function

```text
Create a bounded response router with an injectable monotonic CLOCK.
```

## CL-INPUTS.ROUTING:REGISTER-RESPONSE-CORRELATION

Kinds: function

```text
Register an expected RESPONSE-TYPE before emitting its terminal query.

TIMEOUT is relative to ROUTER's monotonic clock. DEADLINE, when supplied, is an
absolute monotonic timestamp and is mutually exclusive with a non-default
TIMEOUT argument in intent; callers should normally use one or the other. The
router has a hard bound and rejects registration rather than evicting a live
request. Correlations are FIFO among requests for the same response type.
```

## CL-INPUTS.ROUTING:RESPONSE-CORRELATION

Kinds: type

```text
One terminal query/reply correlation with an absolute monotonic deadline.
```

## CL-INPUTS.ROUTING:RESPONSE-CORRELATION-DEADLINE

Kinds: function

_No documentation metadata._

## CL-INPUTS.ROUTING:RESPONSE-CORRELATION-ID

Kinds: function

_No documentation metadata._

## CL-INPUTS.ROUTING:RESPONSE-CORRELATION-RESPONSE

Kinds: function

```text
Return the matched terminal-response token, or NIL when none matched.
```

## CL-INPUTS.ROUTING:RESPONSE-CORRELATION-RESPONSE-TYPE

Kinds: function

_No documentation metadata._

## CL-INPUTS.ROUTING:RESPONSE-CORRELATION-STATE

Kinds: function

```text
Return CORRELATION lifecycle state, expiring a due pending request.

States are :PENDING, :MATCHED, :EXPIRED, and :CANCELLED. Deadline comparison is
inclusive: a reply observed at or after the absolute deadline cannot match.
```

## CL-INPUTS.ROUTING:RESPONSE-ROUTER-NEXT-DEADLINE

Kinds: function

```text
Return the earliest pending correlation deadline, or NIL.
```

## CL-INPUTS.ROUTING:ROUTE-TOKEN

Kinds: function

```text
Route TOKEN and return two values: route keyword and matched correlation.

A valid terminal response is consumed only by a live matching correlation.
Unmatched or stale replies are retained in the bounded unmatched queue and are
never reinterpreted as user input. Protocol diagnostics are likewise retained
separately.
```

## CL-INPUTS.ROUTING:TAKE-PROTOCOL-DIAGNOSTIC

Kinds: function

```text
Remove and return the oldest protocol diagnostic, or NIL.
```

## CL-INPUTS.ROUTING:TAKE-UNMATCHED-RESPONSE

Kinds: function

```text
Remove and return the oldest unmatched terminal response, or NIL.
```

## CL-INPUTS.ROUTING:TERMINAL-QUERY-BYTES

Kinds: function

```text
Return a fresh octet vector for a supported read-only terminal QUERY.
```

## CL-INPUTS.ROUTING:TERMINAL-QUERY-RESPONSE-TYPE

Kinds: function

```text
Return the response type expected for a supported protocol QUERY.
```

## CL-INPUTS.ROUTING:TERMINAL-RESPONSE-TYPE

Kinds: function

```text
Return TOKEN's declared terminal response type, or NIL.
```

## CL-INPUTS.ROUTING:TOKEN-ROUTE

Kinds: function

```text
Classify TOKEN without mutating routing state.

Only established user-input token kinds enter :USER-INPUT. Terminal replies and
protocol diagnostics remain on separate paths; unknown future kinds fail closed
to :PROTOCOL rather than silently becoming user input.
```

## CL-INPUTS.SINK:ACCEPT-TOKEN

Kinds: function

```text
Deliver TOKEN to SINK. The default method is a no-op.
```

## CL-INPUTS.SINK:FN-SINK

Kinds: function

```text
Adapt FN to a token sink function.
```

## CL-INPUTS.SINK:ON-CTRL-C

Kinds: function

```text
Handle a :ctrl-c token.
```

## CL-INPUTS.SINK:ON-FOCUS

Kinds: function

```text
Handle a :focus token.
```

## CL-INPUTS.SINK:ON-KEY

Kinds: function

```text
Handle a :key token.
```

## CL-INPUTS.SINK:ON-MOUSE

Kinds: function

```text
Handle a :mouse token.
```

## CL-INPUTS.SINK:ON-PASTE

Kinds: function

```text
Handle a :paste token.
```

## CL-INPUTS.SINK:ON-RESIZE

Kinds: function

```text
Handle a :resize token.
```

## CL-INPUTS.SINK:TEE-SINK

Kinds: function

```text
Return a sink function that fans each token out to SINKS in order.
```

## CL-INPUTS.TERMINAL.ANSII:*ANSI-KEYS*

Kinds: variable

```text
Alist mapping key symbols to their ANSI escape sequence definitions.
   Each definition is a list starting with the introducer type (e.g., :CSI, :SS3)
   followed by the characters/codes that make up the rest of the sequence.
   Some keys might have multiple possible sequences (e.g., :HOME).
```

## CL-INPUTS.TERMINAL.ANSII:*INTRODUCERS*

Kinds: variable

```text
A list of ANSI escape sequence introducers. Each entry is a list of:
  (Description Name Esc-Char-Suffix Esc-Char-Code-List).
  The Esc-Char-Code-List is (ESC-Code Actual-Char-Code).
```

## CL-INPUTS.TERMINAL.ANSII:+ANSI-ESCAPE-SEQUENCES+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:+ANSI-ESCAPE-SEQUENCES-LOOKUP+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:+ANSI-ESCAPE-SEQUENCES-RESET-LOOKUP+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:ANSI-ATTR-SEQ

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:ANSI-BG-COLOR-SEQ

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:ANSI-FG-COLOR-SEQ

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:ANSI-SEQUENCE

Kinds: type

```text
Ansi Escape Sequence to be sent to the terminal.
```

## CL-INPUTS.TERMINAL.ANSII:COLLECT-CSI-PARAMS

Kinds: function

```text
Parses a list of character codes (after ESC [) into CSI parameters, intermediates, and the final byte.
   Returns (VALUES PARAM-LIST INTERMEDIATE-CHARS FINAL-BYTE-CHAR-CODE).
```

## CL-INPUTS.TERMINAL.ANSII:DEFAULT-ARGS

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:DESCRIPTION

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:GET-RESET-SEQUENCE

Kinds: function

```text
Return the reset escape sequence id for IDENTIFIER.
```

## CL-INPUTS.TERMINAL.ANSII:GET-SEQUENCE

Kinds: function

```text
Return the escape sequence object for IDENTIFIER.
```

## CL-INPUTS.TERMINAL.ANSII:IDENTIFIER

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER

Kinds: type

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER-CODE

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER-DESC

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC-CHAR

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC-DEC

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC-HEX

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC-OCT

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC-STR

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER-KEY

Kinds: function

```text
Given a byte that follows an ESC (0x1B) character, returns the keyword
   identifier for the introducer type (e.g., :CSI, :SS3, :OSC).
```

## CL-INPUTS.TERMINAL.ANSII:INTRODUCER-NAME

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:IS-CSI-FINAL-BYTE?

Kinds: function

```text
Checks if the character code is a CSI final byte (ASCII 64-126).
```

## CL-INPUTS.TERMINAL.ANSII:LOOKUP-SEQUENCE

Kinds: function

```text
Lookup the sequence for IDENTIFIER (can be keyword or string rep).
```

## CL-INPUTS.TERMINAL.ANSII:MAKE-ANSI-SEQUENCE

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:MAKE-INTRODUCER

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:NUMBER-OF-ARGUMENTS

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:PARSE-CSI-SEQUENCE

Kinds: function

```text
Parses a CSI sequence (list of char codes after ESC [) and returns a structured representation.
   Returns a list like (:type :cursor-up :params (1)) or (:type :sgr :changes ((:bold t) (:fg-color :red))).
```

## CL-INPUTS.TERMINAL.ANSII:PARSE-PARAMETERS

Kinds: function

```text
Parses a list of parameter characters (digits and ';', ':') into a list of integers.
```

## CL-INPUTS.TERMINAL.ANSII:PARSE-SGR-PARAMETERS

Kinds: function

```text
Parses a list of SGR numeric parameters and returns a list of style changes.
   Example: (0) -> '((:reset t))
            (1) -> '((:bold t))
            (31) -> '((:fg-color :red))
            (38 5 200) -> '((:fg-color (:type :xterm :value 200)))
            (38 2 100 150 200) -> '((:fg-color (:type :rgb :r 100 :g 150 :b 200)))
```

## CL-INPUTS.TERMINAL.ANSII:PRERENDER

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:READ-ESCAPE-BYTES

Kinds: function

```text
Reads bytes from STREAM following an ESC and an introducer (like '[', 'O').
   Tries to match the sequence against *ANSI-KEYS*.
   STREAM: The input stream to read from.
   INTRODUCER-TYPE: The keyword for the introducer (e.g., :CSI, :SS3).
   Returns (VALUES KEY-SYMBOL REMAINING-BYTES) or (VALUES NIL ALL-READ-BYTES) if no match.
   REMAINING-BYTES are bytes read that didn't form a known key sequence.
   ALL-READ-BYTES are all bytes read if no specific key was matched.
```

## CL-INPUTS.TERMINAL.ANSII:RENDER-SEQ

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:RESET-SEQUENCE

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:RESPONSE-TYPE

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:SEQ

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.ANSII:SPLIT-SEQ-IF

Kinds: function

```text
Split STRING into a list of substrings based on characters that match PREDICATE.
```

## CL-INPUTS.TERMINAL.API:%EMIT-ANSI

Kinds: function

```text
Format an ANSI control sequence and write it to TARGET via DEVICE-WRITE-BYTES.
```

## CL-INPUTS.TERMINAL.API:%STYLE->SGR-STRING

Kinds: function

```text
Return an SGR fragment (without final 'm') for STYLE plist or NIL.
```

## CL-INPUTS.TERMINAL.API:+ESC+

Kinds: variable

```text
ESC character as a string literal.
```

## CL-INPUTS.TERMINAL.API:APPLY-STYLE

Kinds: function

```text
Apply STYLE as the current terminal attributes.
```

## CL-INPUTS.TERMINAL.API:CLEAR-AREA

Kinds: function

```text
Clear a rectangular region starting at ROW/COL with HEIGHT x WIDTH.
```

## CL-INPUTS.TERMINAL.API:CLEAR-SCREEN

Kinds: function

```text
Clear the full terminal content and home the cursor.
```

## CL-INPUTS.TERMINAL.API:DRAW-CHAR-AT

Kinds: function

```text
Draw CHAR with optional STYLE at ROW/COL.
```

## CL-INPUTS.TERMINAL.API:DRAW-TEXT-AT

Kinds: function

```text
Draw TEXT with optional STYLE at ROW/COL.
```

## CL-INPUTS.TERMINAL.API:FILL-RECTANGLE

Kinds: function

```text
Fill rectangle with CHAR (defaults to space) using STYLE.
```

## CL-INPUTS.TERMINAL.API:FLUSH-OUTPUT

Kinds: function

```text
Ensure buffered terminal output for TARGET is flushed.
```

## CL-INPUTS.TERMINAL.API:GET-CURSOR-POSITION

Kinds: function

```text
Return cursor ROW and COL (0-based) if known, NIL otherwise.
```

## CL-INPUTS.TERMINAL.API:GET-TERMINAL-SIZE

Kinds: function

```text
Return WIDTH and HEIGHT as two values when known, or NIL and NIL otherwise.
```

## CL-INPUTS.TERMINAL.API:HIDE-CURSOR

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.API:RESET-STYLE

Kinds: function

```text
Reset terminal attributes to defaults.
```

## CL-INPUTS.TERMINAL.API:SCROLL-LINES

Kinds: function

```text
Scroll the display by COUNT lines (positive = up, negative = down).
```

## CL-INPUTS.TERMINAL.API:SET-CURSOR-POSITION

Kinds: function

```text
Move cursor to ROW/COL (0-based).
```

## CL-INPUTS.TERMINAL.API:SHOW-CURSOR

Kinds: function

_No documentation metadata._

## CL-INPUTS.TERMINAL.API:WITH-STYLED-OUTPUT

Kinds: macro

```text
Emit STYLE before BODY and reset attributes afterwards.

Args
  - ~target~: The output destination (e.g., a stream or buffer).
  - ~style~: A style specification, typically a plist or object that ~%style->sgr-string~ can convert to an ANSI SGR string.
  - ~body~: Forms to execute with the style applied.


*Style Evaluation*: The macro evaluates ~style~ and, if non-nil, converts it to an ANSI SGR string using ~%style->sgr-string~.
*Emit Style*: If a style string is produced, it emits the ANSI code to the ~target~ using ~%emit-ansi~.
*Body Execution*: Executes the ~body~ forms.
*Reset Style*: After the body, emits the ANSI reset code (~[0m~) to the ~target~, ensuring styles do not leak.
*No Style Case*: If ~style~ is nil, simply executes the body with no styling.

Example Usage:
  (with-styled-output (my-terminal '(:fg :red :attrs (:bold :underline)))
    (draw-text-at my-terminal 10 5 "Hello, World!") ;; => Draws bold, underlined red text at row 10, column 5.

```

## CL-INPUTS.TOKENS:+K-FOCUS+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.TOKENS:+K-KEY+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.TOKENS:+K-MOUSE+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.TOKENS:+K-PASTE+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.TOKENS:+K-PROTOCOL+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.TOKENS:+K-RESIZE+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.TOKENS:+K-TERMINAL-RESPONSE+

Kinds: variable

_No documentation metadata._

## CL-INPUTS.TOKENS:INPUT-TOKEN

Kinds: type

```text
A token representing a single input event.

Fields:
  KIND -- event kind (type: keyword, one of the +k-*+ constants)
  DATA -- event data (type: plist, e.g., (:code :enter :mods (:ctrl)))
  TS   -- timestamp (type: universal-time or monotonic integer)

All fields are required.
```

## CL-INPUTS.TOKENS:INPUT-TOKEN-DATA

Kinds: function

_No documentation metadata._

## CL-INPUTS.TOKENS:INPUT-TOKEN-KIND

Kinds: function

_No documentation metadata._

## CL-INPUTS.TOKENS:INPUT-TOKEN-TS

Kinds: function

_No documentation metadata._

## CL-INPUTS.TOKENS:MAKE-TOKEN

Kinds: function

```text
Construct an input-token of KIND with DATA and optional TS (timestamp).
If TS is not provided, uses the current universal time.
```

## CL-INPUTS.UTIL:AS-UTF-8-BYTES

Kinds: macro

```text
Call WRITER for every byte in the UTF-8 encoding of CHAR.

Arguments:
  CHAR   -- a character to encode (type: character)
  WRITER -- a function or macro accepting a single byte (type: (function (unsigned-byte) *))

Side Effects:
  Calls WRITER for each byte of the UTF-8 encoding of CHAR. WRITER may have side effects.

Return Value:
  None (macro expands to a series of WRITER calls).
```

## CL-INPUTS.UTIL:STRING-TO-UTF-8-BYTES

Kinds: function

```text
Convert STR to a freshly allocated (unsigned-byte 8) vector holding its UTF-8 bytes.

Arguments:
  STR -- a string to encode (type: string)

Return Value:
  A vector of (unsigned-byte 8) containing the UTF-8 encoding of STR. The vector
  is adjustable with a fill pointer so callers can re-use it if desired.

Side Effects:
  None.
```

## CL-INPUTS.UTIL:WRITE-OUTPUT

Kinds: function

```text
Write output to the terminal
This method should be implemented by subclasses of low-level-terminal.
```

## CL-STATE.API:APPLICATION-STATE-DATA

Kinds: function

```text
Deprecated compatibility read returning an owned logical STATE snapshot.

This public façade no longer exposes the live backing container. Prefer
STATE-REF for a borrowed path read, STATE-VALUE for an owned path read, or
STATE-SNAPSHOT for the whole logical model. Framework internals that genuinely
need representation access must name CL-STATE.CORE:APPLICATION-STATE-DATA
explicitly.
```

## CL-STATE.API:APPLICATION-STATE-LOG

Kinds: function

```text
Return an owned compatibility view of STATE's mutation log.

Opaque internal missing/deletion markers are projected to :NOT-PRESENT and
:ELMTUI-DELETE-PATH.  Internal transaction/undo code continues to use
CL-STATE.CORE:APPLICATION-STATE-LOG directly so rollback identity is not lost.
```

## CL-STATE.CORE:*STATE-MUTATION-POLICY*

Kinds: variable

```text
Dynamic policy for APPLICATION-STATE mutation through the CL-STATE API.

:ALLOW permits mutation. :FORBID signals STATE-MUTATION-FORBIDDEN before a
supported mutator changes logical state. ElmTUI binds :FORBID while executing
strict-Elm user decision/view/subscription code, then restores :ALLOW for the
internal fresh-state commit.
```

## CL-STATE.CORE:*TRANSACTION-ACTIVE*

Kinds: variable

```text
True while a CL-STATE transaction boundary is active.
```

## CL-STATE.CORE:APPLICATION-STATE

Kinds: type

_No documentation metadata._

## CL-STATE.CORE:APPLICATION-STATE-BACKEND

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:APPLICATION-STATE-DATA

Kinds: function

```text
Low-level representation accessor for APPLICATION-STATE.

This accessor exposes the live backing container and is intentionally confined
to CL-STATE.CORE. Application code should use STATE-REF for a borrowed path
read, STATE-VALUE for an owned path value, or STATE-SNAPSHOT for an owned whole
model. Destructive mutation through this representation accessor bypasses state
locking, versioning, observers, history, and strict snapshot guarantees.
```

## CL-STATE.CORE:APPLICATION-STATE-HISTORY

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:APPLICATION-STATE-LOCK

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:APPLICATION-STATE-LOG

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:APPLICATION-STATE-OBSERVERS

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:APPLICATION-STATE-P

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:APPLICATION-STATE-PLIST

Kinds: function

```text
Return an owned plist representation of STATE's logical model.
```

## CL-STATE.CORE:APPLICATION-STATE-REVISION

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:APPLICATION-STATE-UNDONE

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:APPLICATION-STATE-VERSION

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:ASSERT-STATE-MUTATION-ALLOWED

Kinds: function

```text
Signal STATE-MUTATION-FORBIDDEN when STATE is frozen or dynamically read-only.
```

## CL-STATE.CORE:ASSERT-STATE-REVISION

Kinds: function

```text
Atomically require STATE to have EXPECTED-REVISION or signal STATE-REVISION-CONFLICT.
```

## CL-STATE.CORE:ASSERT-VALID-STATE-PATH

Kinds: function

```text
Return PATH or signal INVALID-STATE-PATH with the rejected value.
```

## CL-STATE.CORE:COPY-STATE-VALUE

Kinds: function

```text
Return an owned logical copy of VALUE for crossing a state ownership boundary.

Built-in hash tables, cons trees, and vectors are copied recursively. Immutable
atoms are returned as-is. Custom mutable leaf types should specialize this
generic and return an independent value.
```

## CL-STATE.CORE:DEEP-COPY-APPLICATION-STATE

Kinds: function

```text
Return an independent mutable state copied from one stable managed view.

Built-in container spines are detached while APP is locked; extensible
COPY-STATE-VALUE methods run only after that lock has been released.
```

## CL-STATE.CORE:DEEP-COPY-DATA

Kinds: function

```text
Compatibility alias for COPY-STATE-VALUE.

New state-boundary code should call COPY-STATE-VALUE explicitly so custom leaf
specializations participate in ownership transfer.
```

## CL-STATE.CORE:FREEZE-STATE-VALUE

Kinds: function

```text
Return VALUE in a representation suitable for persistent structural sharing.

Built-in containers are recursively copied. Custom mutable leaf types should
specialize this generic to return an immutable/persistent representation when
strict snapshot semantics require more than COPY-STATE-VALUE.
```

## CL-STATE.CORE:GET-COMPONENT-BY-PATH

Kinds: function

```text
Retrieve a component instance from APP-STATE using its ID path.
```

## CL-STATE.CORE:GET-STATE

Kinds: function

```text
Convenience wrapper for state-ref.
```

## CL-STATE.CORE:INVALID-STATE-PATH

Kinds: type

```text
Signaled when a CL-STATE operation receives an invalid logical path.
```

## CL-STATE.CORE:INVALID-STATE-PATH-PATH

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:MAKE-APPLICATION-STATE

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:MAKE-STATE

Kinds: function

```text
Create an application state object.

Arguments:
+ ~:initial~ — The initial data to populate the state. This can be any data structure compatible with the chosen backend.
+ ~:backend~ — The backend type for storing the state: ~:hash-table~ (default) or ~:plist~.

Returns:
+ A new application state object created by ~make-application-state~, initialized with the given data and backend.

Usage:
  (make-state :initial '(:foo 42 :bar 99))
  (make-state :initial '(:foo 42) :backend :plist)

Notes:
+ All arguments are keyword arguments; you must use ~:initial~ and ~:backend~ when calling the function.
+ Supported mutable containers in ~:initial~ are recursively copied before storage, so the new state owns its container graph.
+ The function expects that ~%normalize-backend~ and ~%coerce-initial~ are defined elsewhere and handle backend normalization and data coercion.

See Also:
+ ~%normalize-backend~
+ ~%coerce-initial~
+ ~make-application-state~

```

## CL-STATE.CORE:PERSISTENT-STATE-VALUE-P

Kinds: function

```text
Return true when VALUE is known safe for persistent sharing under the state contract.

The predicate is diagnostic rather than an admission gate: unknown custom leaf
types return NIL for compatibility, while applications can specialize it after
providing COPY-STATE-VALUE/FREEZE-STATE-VALUE methods.
```

## CL-STATE.CORE:SET-APPLICATION-STATE-BACKEND

Kinds: function

```text
Convert STATE's physical representation without changing logical revision.
```

## CL-STATE.CORE:STATE-CONFLICT

Kinds: type

```text
Base condition for optimistic/concurrent managed-state access conflicts.
```

## CL-STATE.CORE:STATE-CONFLICT-OPERATION

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:STATE-CONFLICT-STATE

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:STATE-FROZEN-P

Kinds: function

```text
Return true when STATE is a frozen APPLICATION-STATE snapshot.
```

## CL-STATE.CORE:STATE-MUTATION-FORBIDDEN

Kinds: type

```text
Condition signaled when supported state mutation is forbidden by the current dynamic policy.
```

## CL-STATE.CORE:STATE-MUTATION-FORBIDDEN-OPERATION

Kinds: function

```text
Return the operation keyword describing the rejected state mutation.
```

## CL-STATE.CORE:STATE-MUTATION-FORBIDDEN-PATH

Kinds: function

```text
Return the state path associated with a rejected mutation, or NIL when not path-specific.
```

## CL-STATE.CORE:STATE-MUTATION-FORBIDDEN-STATE

Kinds: function

```text
Return the APPLICATION-STATE whose mutation was rejected.
```

## CL-STATE.CORE:STATE-REF

Kinds: function

```text
Return the logical value at KEY without copying it.

For APPLICATION-STATE this is a borrowed read: container values may be shared
with strict snapshots and must not be destructively modified. Use STATE-VALUE
when the caller needs an owned mutable copy.
```

## CL-STATE.CORE:STATE-REVISION

Kinds: function

```text
Return STATE's monotonic logical commit revision.
```

## CL-STATE.CORE:STATE-REVISION-CONFLICT

Kinds: type

```text
Signaled before mutation when an optimistic revision precondition is stale.
```

## CL-STATE.CORE:STATE-REVISION-CONFLICT-ACTUAL-REVISION

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:STATE-REVISION-CONFLICT-EXPECTED-REVISION

Kinds: function

_No documentation metadata._

## CL-STATE.CORE:STATE-SET

Kinds: function

```text
Set VALUE at KEY through the supported STATE-REF mutation path.

For APPLICATION-STATE this mutates logical state, appends a log entry, increments
VERSION, and increments REVISION for a direct commit. Transaction-local writes
leave REVISION unchanged until their outer transaction commits. Observers run
after the state lock is released; callback failure does not undo a direct
mutation. Strict or frozen application states reject before mutation.
```

## CL-STATE.CORE:STATE-SET-IF-REVISION

Kinds: function

```text
Atomically set KEY only when STATE still has EXPECTED-REVISION.

A stale precondition signals STATE-REVISION-CONFLICT before logical state,
version, revision, log/history, or observer delivery changes. On success return
VALUE and the resulting revision as two values.
```

## CL-STATE.CORE:STATE-SNAPSHOT

Kinds: function

```text
Return an owned copy of STATE's complete logical model.

Managed APPLICATION-STATE snapshots detach their built-in container graph under
the state lock and reject a foreign in-progress transaction. Extensible
COPY-STATE-VALUE methods then run after that lock is released. Runtime metadata
such as locks, observers, history, and undo stacks is not part of this value.
Raw hash-table/list inputs are copied directly.
```

## CL-STATE.CORE:STATE-TRANSACTION-CONFLICT

Kinds: type

```text
Signaled when a managed operation requires a stable state owned by another transaction.
```

## CL-STATE.CORE:STATE-VALUE

Kinds: function

```text
Return an owned logical copy of the value at KEY in STATE.

For APPLICATION-STATE the lookup and ownership copy occur under one internal
lock and reject a foreign in-progress transaction. Raw containers retain their
historical direct-copy behavior.
```

## CL-STATE.CORE:STATE-VALUE-AT-REVISION

Kinds: function

```text
Atomically return an owned KEY value and STATE's committed REVISION.

Unlike separate STATE-VALUE and STATE-REVISION calls, the two values describe
one lock-protected observation. If another transaction currently owns STATE,
STATE-TRANSACTION-CONFLICT is signaled rather than exposing an in-progress value
paired with the last committed revision. Extensible COPY-STATE-VALUE methods run
after the internal state lock is released.
```

## CL-STATE.CORE:VALID-STATE-PATH-P

Kinds: function

```text
Return true when PATH is a symbol or a proper list of non-NIL symbols.
```

## CL-STATE.OBSERVER:ADD-OBSERVER

Kinds: function

```text
Register runtime observer FN for KEY in APP.

Observer registration is runtime metadata, not logical model mutation. It is
therefore allowed on frozen snapshots, does not increment model VERSION or
REVISION, and is copied into a descendant strict snapshot only when that
descendant is committed.
```

## CL-STATE.OBSERVER:NOTIFY-OBSERVERS

Kinds: function

```text
Notify APP observers for KEY in registration order.

The observer list is captured while APP's internal lock is held, then the lock
is released before any callback executes. Observers fail fast by default. An
arbitrary callback error is wrapped in OBSERVER-NOTIFICATION-ERROR with the
callback, values, phase, and original cause. A handler may explicitly invoke
CONTINUE-OBSERVER-NOTIFICATION to skip that failed callback and continue with
later observers. Notification never rolls back logical state.
```

## CL-STATE.OBSERVER:OBSERVER-NOTIFICATION-ERROR

Kinds: type

```text
Inspect an observer callback failure without hiding the original cause.
```

## CL-STATE.OBSERVER:OBSERVER-NOTIFICATION-ERROR-CAUSE

Kinds: function

_No documentation metadata._

## CL-STATE.OBSERVER:OBSERVER-NOTIFICATION-ERROR-KEY

Kinds: function

_No documentation metadata._

## CL-STATE.OBSERVER:OBSERVER-NOTIFICATION-ERROR-NEW-VALUE

Kinds: function

_No documentation metadata._

## CL-STATE.OBSERVER:OBSERVER-NOTIFICATION-ERROR-OBSERVER

Kinds: function

_No documentation metadata._

## CL-STATE.OBSERVER:OBSERVER-NOTIFICATION-ERROR-OLD-VALUE

Kinds: function

_No documentation metadata._

## CL-STATE.OBSERVER:OBSERVER-NOTIFICATION-ERROR-PHASE

Kinds: function

_No documentation metadata._

## CL-STATE.OBSERVER:OBSERVER-NOTIFICATION-ERROR-STATE

Kinds: function

_No documentation metadata._

## CL-STATE.OBSERVER:REMOVE-OBSERVER

Kinds: function

```text
Remove runtime observer FN for KEY from APP.

This metadata operation is allowed on frozen snapshots and does not change the
logical model/version/revision/history. Returns true only when FN was registered
and removed.
```

## CL-STATE.PATCH:APPLY-PATCH

Kinds: function

```text
Apply P to a raw container or APPLICATION-STATE.

APPLICATION-STATE operations mutate the supported logical model path and use the
same log/version/observer policy as STATE-SET. A remove patch records a deletion
only when the path exists. Example: APPLY-PATCH with a SET patch at :COUNT and
value 3 changes :COUNT to 3.
```

## CL-STATE.PATCH:APPLY-PATCHES

Kinds: function

```text
Apply PATCHES in order.

For raw containers this is a direct reduction. For APPLICATION-STATE values,
the whole batch joins an existing transaction for STATE or otherwise creates
one undoable transaction. Example: setting (:USER :NAME) to Ada and removing
:STALE in one PATCHES list commits both mutations atomically.
```

## CL-STATE.PATCH:APPLY-PATCHES-PERSISTENT

Kinds: function

```text
Return the post-PATCHES state without mutating STATE.

APPLICATION-STATE values are deeply copied across the supported CL-STATE
container graph before the transactional patch engine runs against the fresh
copy. The returned state has normal log/version/history/observer semantics while
the caller's previous state remains observationally unchanged. Raw list/hash-
table containers are also copied before patch application.

This function is the commit primitive used by ElmTUI's :STRICT-ELM application
mode. For example, setting :COUNT on the returned state never changes :COUNT on
STATE. Observer failure is reported for the fresh committed state and does not
mutate or roll back the source STATE.

Custom mutable leaf objects are treated atomically by DEEP-COPY-DATA because
Common Lisp has no portable universal object-copy protocol. Such leaves must be
application-immutable or copied before insertion when strict value semantics are
required.
```

## CL-STATE.PATCH:DIFF-STATES

Kinds: function

```text
Return shorthand patches whose sequential application transforms OLD into NEW.
```

## CL-STATE.PATCH:INVALID-PATCH-FORMAT

Kinds: type

_No documentation metadata._

## CL-STATE.PATCH:INVALID-PATCH-OPERATION

Kinds: type

_No documentation metadata._

## CL-STATE.PATCH:INVALID-PATCH-OPERATION-OPERATION

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:INVALID-PATCH-PATH

Kinds: type

_No documentation metadata._

## CL-STATE.PATCH:INVALID-PATCH-PATH-PATH

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:INVALID-PATCH-VALUE

Kinds: type

_No documentation metadata._

## CL-STATE.PATCH:INVALID-PATCH-VALUE-OPERATION

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:INVALID-PATCH-VALUE-VALUE

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:MAKE-PATCH

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:MERGE-PATCH

Kinds: function

```text
Merge one shorthand patch into STATE and return the modified state.
```

## CL-STATE.PATCH:MERGE-PATCHES

Kinds: function

```text
Merge a list of PATCHES into STATE.
Returns the modified STATE (functional API).
```

## CL-STATE.PATCH:NORMALIZE-PATCHES

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:PATCH

Kinds: type

_No documentation metadata._

## CL-STATE.PATCH:PATCH-OP

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:PATCH-P

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:PATCH-PATH

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:PATCH-VALIDATION-ERROR

Kinds: type

_No documentation metadata._

## CL-STATE.PATCH:PATCH-VALIDATION-ERROR-INPUT

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:PATCH-VALIDATION-ERROR-REASON

Kinds: function

_No documentation metadata._

## CL-STATE.PATCH:PATCH-VALUE

Kinds: function

_No documentation metadata._

## CL-STATE.SCHEMA:DEFINE-TYPE-PREDICATE

Kinds: macro

```text
Define and register a type predicate
```

## CL-STATE.SCHEMA:FINITE-NUMBER-P

Kinds: function

_No documentation metadata._

## CL-STATE.SCHEMA:KEYWORD-SYMBOL-P

Kinds: function

_No documentation metadata._

## CL-STATE.SCHEMA:LIST-REGISTERED-TYPES

Kinds: function

```text
List all registered type predicates
```

## CL-STATE.SCHEMA:LOOKUP-TYPE-PREDICATE

Kinds: function

```text
Get a predicate for a type
```

## CL-STATE.SCHEMA:MAKE-ENUM-PREDICATE

Kinds: function

```text
Create a predicate that validates against an enumeration of values
```

## CL-STATE.SCHEMA:NON-EMPTY-STRING-P

Kinds: function

_No documentation metadata._

## CL-STATE.SCHEMA:NON-NEGATIVE-INTEGER-P

Kinds: function

_No documentation metadata._

## CL-STATE.SCHEMA:POSITIVE-INTEGER-P

Kinds: function

_No documentation metadata._

## CL-STATE.SCHEMA:REGISTER-ENUM-TYPE

Kinds: function

```text
Register an enum type with the allowed values
```

## CL-STATE.SCHEMA:REGISTER-TYPE-PREDICATE

Kinds: function

```text
Register a predicate for a type
```

## CL-STATE.SCHEMA:VALIDATE-TYPE

Kinds: function

```text
Validate that a value satisfies a type predicate
```

## CL-STATE.TX:MAKE-TX

Kinds: function

_No documentation metadata._

## CL-STATE.TX:REDO

Kinds: function

```text
Redo the last undone transaction without observer delivery. Successful replay advances REVISION exactly once while retaining the historical compatibility rule that VERSION does not change.
```

## CL-STATE.TX:TX

Kinds: type

_No documentation metadata._

## CL-STATE.TX:TX-CHANGES

Kinds: function

_No documentation metadata._

## CL-STATE.TX:TX-ID

Kinds: function

_No documentation metadata._

## CL-STATE.TX:TX-NAME

Kinds: function

_No documentation metadata._

## CL-STATE.TX:TX-P

Kinds: function

_No documentation metadata._

## CL-STATE.TX:UNDO

Kinds: function

```text
Undo the last committed transaction without observer delivery. Successful replay advances REVISION exactly once while retaining the historical compatibility rule that VERSION does not change.
```

## CL-STATE.TX:WITH-TRANSACTION

Kinds: macro

```text
Execute BODY as one reserved logical-state transaction on APP.

EXPECTED-REVISION is an optimistic precondition checked atomically before APP is
reserved. Same-state nesting joins the outer transaction and may repeat the
same revision precondition; it is not a savepoint. Other supported writers are
rejected with STATE-TRANSACTION-CONFLICT while the outer body is active.
Rollback restores logical values, VERSION, log, history, and redo metadata;
REVISION advances exactly once only after a successful outer commit. Observer
callbacks run after reservation is released and after all internal locks are
released.
```

## CL-STATE.UNDO:HISTORY

Kinds: type

_No documentation metadata._

## CL-STATE.UNDO:HISTORY-FUTURE

Kinds: function

_No documentation metadata._

## CL-STATE.UNDO:HISTORY-PAST

Kinds: function

_No documentation metadata._

## CL-STATE.UNDO:HISTORY-REDO

Kinds: function

```text
Redo to next state. Returns the redone state (moved back to past).
```

## CL-STATE.UNDO:HISTORY-UNDO

Kinds: function

```text
Undo to previous state. Returns the previous state, or nil if at beginning.
```

## CL-STATE.UNDO:MAKE-HISTORY

Kinds: function

_No documentation metadata._

## CL-STATE.UNDO:PUSH-SNAPSHOT

Kinds: function

```text
Push STATE as the current snapshot. Clears future stack if STATE differs from current.
```

## CL-STATE.UTILS:COERCE-DATA

Kinds: function

```text
Coerce DATA to BACKEND (:hash-table or :plist) when possible.
```

## CL-STATE.UTILS:GET-PATH

Kinds: function

```text
Read value at PATH inside DATA; return DEFAULT when missing.
```

## CL-STATE.UTILS:HASH-TABLE->PLIST

Kinds: function

```text
Convert a hash-table to a plist. Recursively converts nested hash-tables.
```

## CL-STATE.UTILS:PLIST->HASH-TABLE

Kinds: function

```text
Convert a plist to a hash-table. Recursively converts nested plist-like lists.
```

## CL-STATE.UTILS:REMOVE-PATH

Kinds: function

```text
Delete item at PATH. Returns two values: NEW-DATA, REMOVEDP.
```

## CL-STATE.UTILS:SET-PATH

Kinds: function

```text
Store VALUE at PATH inside DATA, creating intermediate nodes when CREATEP.
```

## CL-STATE.VALIDATION:DEFINE-VALIDATOR

Kinds: macro

```text
Define NAME as a validator whose BODY returns T or an error message.
```

## CL-STATE.VALIDATION:MAKE-VALIDATOR

Kinds: function

```text
Create a validator function from PREDICATE and ERROR-MESSAGE.
```

## CL-STATE.VALIDATION:REGISTER-TYPE-VALIDATOR

Kinds: function

```text
Compatibility name for REGISTER-TYPE-PREDICATE.
```

## CL-STATE.VALIDATION:TYPE-PREDICATE

Kinds: function

```text
Return the predicate registered for TYPE-NAME.
```

## CL-STATE.VALIDATION:VALIDATE-FIELD

Kinds: function

```text
Validate VALUE against TYPE and signal VALIDATION-ERROR on mismatch.
```

## CL-STATE.VALIDATION:VALIDATE-MODEL-SCHEMA

Kinds: function

```text
Validate MODEL using SCHEMA or an embedded SCHEMA slot.

When MODEL also has a DATA slot, the embedded schema describes that data
container rather than the wrapper object itself.
```

## CL-STATE.VALIDATION:VALIDATE-NESTED

Kinds: function

```text
Validate OBJECT fields according to SCHEMA entries (FIELD TYPE).
```

## CL-STATE.VALIDATION:VALIDATION-ERROR

Kinds: type

_No documentation metadata._

## CL-STATE.VALIDATION:VALIDATION-ERROR-MESSAGE

Kinds: function

_No documentation metadata._

## CL-STATE.VALIDATION:VALIDATION-ERROR-PATH

Kinds: function

_No documentation metadata._

## CL-STATE.VALIDATION:VALIDATION-ERROR-VALUE

Kinds: function

_No documentation metadata._

## CL-STATE.VALIDATION:WITH-VALIDATION

Kinds: macro

```text
Run BODY while reporting validation failures before they unwind normally.
```

## CL-STYLES.ADAPTERS:NORMALIZE-TUI-DECLARATIONS

Kinds: function

```text
Normalize ElmTUI compatibility declarations without weakening core validation.

Legacy TUI spellings are translated once at style ingress.  The reusable
property engine can therefore stay strict while render/layout code receives a
canonical declaration vocabulary.
```

## CL-STYLES.ADAPTERS:NORMALIZE-TUI-STYLE-PLIST

Kinds: function

```text
Extract terminal colors/attributes from PLIST without rebuilding declarations.

This function sits on the per-node render hot path.  Declaration compatibility
normalization belongs at style ingress in NORMALIZE-TUI-DECLARATIONS; rendering
only needs a small alias-aware projection.
```

## CL-STYLES.ENGINE:*CASCADE-SEMANTICS-REVISION*

Kinds: variable

_No documentation metadata._

## CL-STYLES.ENGINE:APPLY-STYLESHEET

Kinds: function

```text
Apply SHEET to a flat list of OBJECTS, returning either :patches or :objects.

If :patches, return a list of style-patch structs with the path to the object and its computed style.
If :objects, return a list of the objects themselves with their computed styles set.

Objects must implement the cl-styles.protocols interface.

Arguments:
 SHEET    A cl-styles.sheet:stylesheet object.
 OBJECTS  A list of objects implementing cl-styles.protocols.
 RETURN   Either :patches (default) or :objects.

Returns:
 A list of style-patch structs or objects with computed styles set.

Example:
 (apply-stylesheet (make-stylesheet :rules ((defrule (type> :button) :color :red)))
                   (list (make-object :id :btn1 :type :button)
                        (make-object :id :lbl1 :type :label))
                   :return :patches)
 => (#<STYLE-PATCH path (:BY-KEY :BTN1) computed (:COLOR :RED)
      #<STYLE-PATCH path (:BY-KEY :LBL1) computed NIL)
or if :return :objects:
  => (#<OBJECT id :BTN1 type :BUTTON computed (:COLOR :RED)>
      #<OBJECT id :LBL1 type :LABEL computed NIL>)
```

## CL-STYLES.ENGINE:APPLY-STYLESHEET-TO-TREE

Kinds: function

```text
Apply SHEET to ROOT by full recomputation.
CACHE and PREVIOUS-SIGNATURE are accepted for source compatibility but ignored;
revision-safe caching is a separate contract and stale cached style is never reused.
```

## CL-STYLES.ENGINE:COMPUTE-STYLE

Kinds: function

```text
Compute OBJ style using defaults < inheritance < rules < inline precedence.
Rules sort by specificity and retain source order for ties; later tied rules win.
```

## CL-STYLES.ENGINE:COMPUTE-STYLE-RESULT

Kinds: function

```text
Return a first-class computed style result with an explicit cascade revision.
```

## CL-STYLES.ENGINE:COMPUTED-STYLE-RESULT

Kinds: type

_No documentation metadata._

## CL-STYLES.ENGINE:COMPUTED-STYLE-RESULT-DIAGNOSTICS

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:COMPUTED-STYLE-RESULT-REVISION

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:COMPUTED-STYLE-RESULT-STYLE

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:COMPUTED-STYLE-RESULT-TRACE

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:DECLARATION-TRACE

Kinds: type

_No documentation metadata._

## CL-STYLES.ENGINE:DECLARATION-TRACE-ORIGIN

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:DECLARATION-TRACE-PROPERTY

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:DECLARATION-TRACE-SELECTOR

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:DECLARATION-TRACE-SOURCE-DECLARATIONS

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:DECLARATION-TRACE-SOURCE-ORDER

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:DECLARATION-TRACE-SPECIFICITY

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:DECLARATION-TRACE-STATUS

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:DECLARATION-TRACE-VALUE

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:DECLARATION-TRACE-VARIABLE-EXPANSIONS

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:EXPLAIN-STYLE

Kinds: function

```text
Explain OBJ's cascade without mutating it.
The trace marks every candidate :WINNER or :OVERRIDDEN and records origin,
specificity, source order, source declarations, and variable expansion.
```

## CL-STYLES.ENGINE:INHERIT-PROPERTIES

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:MATCH-RULES

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:STYLE-PATCH

Kinds: type

_No documentation metadata._

## CL-STYLES.ENGINE:STYLE-PATCH-COMPUTED

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:STYLE-PATCH-PATH

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:STYLE-REVISION

Kinds: type

_No documentation metadata._

## CL-STYLES.ENGINE:STYLE-REVISION-CASCADE

Kinds: function

_No documentation metadata._

## CL-STYLES.ENGINE:STYLE-REVISION-STYLESHEET

Kinds: function

_No documentation metadata._

## CL-STYLES.PROPERTIES:DEFINE-GROUP

Kinds: function

_No documentation metadata._

## CL-STYLES.PROPERTIES:DEFPROPERTY

Kinds: macro

_No documentation metadata._

## CL-STYLES.PROPERTIES:ENSURE-DECLARATIONS

Kinds: function

_No documentation metadata._

## CL-STYLES.PROPERTIES:ENSURE-STATIC-DECLARATIONS

Kinds: function

```text
Validate static declaration shape, known properties, and literal values.
Variable references are type-checked after resolution; a literal fallback is checked now.
```

## CL-STYLES.PROPERTIES:EXPECTED

Kinds: function

_No documentation metadata._

## CL-STYLES.PROPERTIES:GOT

Kinds: function

_No documentation metadata._

## CL-STYLES.PROPERTIES:GROUPS-FOR-LAYOUT

Kinds: function

_No documentation metadata._

## CL-STYLES.PROPERTIES:NORMALIZE-DECLARATIONS

Kinds: function

```text
Normalize the keys and values in a property list (PLIST).

This function ensures that all keys in the property list are normalized
(using `%normalize-key`) and that their corresponding values are also normalized
(using `%normalize-value`). The original keys are replaced with their normalized
versions, and duplicate keys are avoided.

Arguments:
- PLIST: A property list where keys and values may need normalization.

Returns:
- A new property list with normalized keys and values.

Example:
  (normalize-declarations '(:MARGIN-LEFT 10 :MARGIN-RIGHT 10 :MARGIN-BOTTOM 5 :MARGIN-TOP 5
                           :PADDING-LEFT 10 :PADDING-BOTTOM 10 :PADDING-RIGHT 10 :PADDING-TOP 10
                           :COLOR :BLUE :PADDING 10 :MARGIN (5 10) :FONT-FAMILY "Arial"))
  ;; Returns: (:MARGIN-LEFT 10 :MARGIN-RIGHT 10 :MARGIN-BOTTOM 5 :MARGIN-TOP 5
  ;;           :PADDING-LEFT 10 :PADDING-BOTTOM 10 :PADDING-RIGHT 10 :PADDING-TOP 10
  ;;           :COLOR :BLUE :PADDING 10 :MARGIN (5 10) :FONT-FAMILY "Arial")
```

## CL-STYLES.PROPERTIES:PROPERTIES-FOR-GROUP

Kinds: function

_No documentation metadata._

## CL-STYLES.PROPERTIES:PROPERTIES-FOR-LAYOUT

Kinds: function

_No documentation metadata._

## CL-STYLES.PROPERTIES:PROPERTY-DEFAULT

Kinds: function

```text
Return a property's explicit default and whether a default was supplied.
```

## CL-STYLES.PROPERTIES:PROPERTY-DEFAULTS

Kinds: function

```text
Return a deterministic plist of explicitly declared property defaults.
```

## CL-STYLES.PROPERTIES:PROPERTY-DEFINITION

Kinds: function

_No documentation metadata._

## CL-STYLES.PROPERTIES:REGISTER-PROPERTY

Kinds: function

_No documentation metadata._

## CL-STYLES.PROPERTIES:REGISTER-PROPERTY-ALIAS

Kinds: function

```text
Register ALIAS as an alternate spelling for CANONICAL-NAME.
```

## CL-STYLES.PROPERTIES:STYLE-CONTRACT-VIOLATION

Kinds: type

_No documentation metadata._

## CL-STYLES.PROPERTIES:VALIDATE-DECLARATIONS

Kinds: function

```text
Validate the types of values in a property list (PLIST) against their definitions.
This function checks each key-value pair in the property list to ensure that
the value conforms to the expected type defined for that property. If a value
does not match the expected type, a `style-contract-violation` error is raised.

Arguments:
- PLIST: A property list where keys are property names and values are the corresponding values to validate.
Returns:
- The original property list if all values are valid.
Raises:
- `style-contract-violation`: If any value does not conform to the expected type for its property.
```

## CL-STYLES.PROPERTIES:WHERE

Kinds: function

_No documentation metadata._

## CL-STYLES.PROTOCOLS:GET-COMPUTED-STYLE

Kinds: function

```text
Return previously computed style plist or NIL.
```

## CL-STYLES.PROTOCOLS:SET-COMPUTED-STYLE

Kinds: function

```text
Attach computed style. In TEA return a PATCH or a NEW-OBJ (pure).
```

## CL-STYLES.PROTOCOLS:STYLABLE-ATTRIBUTES

Kinds: function

```text
Arbitrary attributes for [attr=value] selectors. Return plist/alist.
```

## CL-STYLES.PROTOCOLS:STYLABLE-CHILDREN

Kinds: function

```text
Return sequence of children (list/vector).
```

## CL-STYLES.PROTOCOLS:STYLABLE-CLASSES

Kinds: function

```text
List of classes for .class selectors. Return list of keyword/string.
```

## CL-STYLES.PROTOCOLS:STYLABLE-ID

Kinds: function

```text
Stable identifier for #id selectors. Return keyword/string or NIL.
```

## CL-STYLES.PROTOCOLS:STYLABLE-INDEX

Kinds: function

```text
0-based index among siblings (for nth/first/last).
```

## CL-STYLES.PROTOCOLS:STYLABLE-INLINE-STYLE

Kinds: function

```text
Inline style plist (highest priority before !important).
```

## CL-STYLES.PROTOCOLS:STYLABLE-KEY

Kinds: function

_No documentation metadata._

## CL-STYLES.PROTOCOLS:STYLABLE-NAMESPACE

Kinds: function

_No documentation metadata._

## CL-STYLES.PROTOCOLS:STYLABLE-PARENT

Kinds: function

```text
Return parent or NIL.
```

## CL-STYLES.PROTOCOLS:STYLABLE-STATE

Kinds: function

```text
State flags for pseudo-classes (e.g., :focus :disabled). Return plist/list.
```

## CL-STYLES.PROTOCOLS:STYLABLE-THEME

Kinds: function

_No documentation metadata._

## CL-STYLES.PROTOCOLS:STYLABLE-TYPE

Kinds: function

```text
Node/tag type for type selectors. Return keyword/symbol.
```

## CL-STYLES.RULE:DEFRULE

Kinds: macro

```text
Create a rule. Declarations are a property list of property/value pairs.

This macro processes the declarations to ensure that list literals starting
with a number or keyword (e.g., (1 1 0) for :flex or (0 1) for :padding) are
wrapped in `(list ...)` so they are treated as data, not function calls.
Values starting with a symbol (e.g., (rgb ...)) are left as-is to evaluate.

Arguments:
- SELECTOR: A CSS-like selector to which the rule applies.
- DECLARATIONS: A property list of property/value pairs.

Returns:
- A `make-rule` form with the processed selector, declarations, and specificity.

Example:
  (defrule ".example"
    :color (rgb 255 0 0)
    :padding (10 20))
  ;; Expands to:
  ;; (make-rule
  ;;  :selector (cl-styles.selector:compile-selector ".example")
  ;;  :declarations (list :color (rgb 255 0 0) :padding (list 10 20))
  ;;  :specificity (cl-styles.selector:selector-specificity ".example"))
```

## CL-STYLES.RULE:EXPAND-SHORTHANDS

Kinds: function

```text
Expand common CSS-like shorthands into longhands.
Supports: :padding, :margin, :gap → (:row-gap :column-gap). Longhands win.
```

## CL-STYLES.RULE:INVALID-RULE

Kinds: type

_No documentation metadata._

## CL-STYLES.RULE:INVALID-RULE-REASON

Kinds: function

_No documentation metadata._

## CL-STYLES.RULE:INVALID-RULE-RULE

Kinds: function

_No documentation metadata._

## CL-STYLES.RULE:MAKE-RULE

Kinds: function

```text
Construct a validated style rule with TUI compatibility normalized at ingress.
```

## CL-STYLES.RULE:RULE

Kinds: type

_No documentation metadata._

## CL-STYLES.RULE:RULE-DECLARATIONS

Kinds: function

_No documentation metadata._

## CL-STYLES.RULE:RULE-SELECTOR

Kinds: function

_No documentation metadata._

## CL-STYLES.RULE:RULE-SPECIFICITY

Kinds: function

_No documentation metadata._

## CL-STYLES.RULE:VALIDATE-RULE

Kinds: function

```text
Validate a constructed rule and return it.
```

## CL-STYLES.SELECTOR:ATTR>

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:CHILD>

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:CLS>

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:COMPILE-SELECTOR

Kinds: function

```text
Validate and return the selector S-expression used by the matcher.
```

## CL-STYLES.SELECTOR:DESCENDANT>

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:FIRST-CHILD

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:HAS

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:ID>

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:INVALID-SELECTOR

Kinds: type

_No documentation metadata._

## CL-STYLES.SELECTOR:INVALID-SELECTOR-PATH

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:INVALID-SELECTOR-REASON

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:INVALID-SELECTOR-SELECTOR

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:LAST-CHILD

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:MATCH-SELECTOR-P

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:NTH-CHILD

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:SEL-AND

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:SEL-NOT

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:SEL-OR

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:SELECTOR-SPECIFICITY

Kinds: function

```text
Return the deterministic CSS-like specificity triple (ID CLASS TYPE) for SEL.
```

## CL-STYLES.SELECTOR:STATE>

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:TYPE>

Kinds: function

_No documentation metadata._

## CL-STYLES.SELECTOR:VALIDATE-SELECTOR

Kinds: function

```text
Validate SELECTOR shape recursively and return it, or signal INVALID-SELECTOR.
```

## CL-STYLES.SHEET:ADD-RULE

Kinds: function

```text
Add a rule to the stylesheet.

WARNING: This mutates the stylesheet in-place. For functional/immutable
operations (preferred in TEA architecture), create a new stylesheet with
make-stylesheet instead.
```

## CL-STYLES.SHEET:DEFSTYLESHEET

Kinds: macro

```text
Define a stylesheet with the given rules.
```

## CL-STYLES.SHEET:MAKE-STYLESHEET

Kinds: function

```text
Create and validate a stylesheet instance with revision zero.
```

## CL-STYLES.SHEET:REMOVE-RULE

Kinds: function

```text
Remove a rule from the stylesheet.

WARNING: This mutates the stylesheet in-place. For functional/immutable
operations (preferred in TEA architecture), create a new stylesheet with
make-stylesheet instead.
```

## CL-STYLES.SHEET:STYLE-ENGINE

Kinds: type

```text
Stateful styling engine for advanced use cases like caching and batch operations.
Currently unused - the functional API (apply-stylesheet, apply-stylesheet-to-tree) is preferred.
Reserved for future optimizations like selector compilation caching or computed style caching.
```

## CL-STYLES.SHEET:STYLE-ENGINE-DIRTY

Kinds: function

_No documentation metadata._

## CL-STYLES.SHEET:STYLE-ENGINE-PATCHES

Kinds: function

_No documentation metadata._

## CL-STYLES.SHEET:STYLE-ENGINE-STYLESHEET

Kinds: function

_No documentation metadata._

## CL-STYLES.SHEET:STYLESHEET

Kinds: type

_No documentation metadata._

## CL-STYLES.SHEET:STYLESHEET-NAMESPACE

Kinds: function

_No documentation metadata._

## CL-STYLES.SHEET:STYLESHEET-REVISION

Kinds: function

_No documentation metadata._

## CL-STYLES.SHEET:STYLESHEET-RULES

Kinds: function

_No documentation metadata._

## CL-STYLES.SHEET:STYLESHEET-VARIABLES

Kinds: function

_No documentation metadata._

## CL-STYLES.SHEET:VALIDATE-STYLESHEET

Kinds: function

```text
Validate rules and variables for SHEET and return it.
```

## CL-STYLES.TOKENS:CH

Kinds: function

```text
Construct a character-cell relative length token for style resolution.
```

## CL-STYLES.TOKENS:COLOR-P

Kinds: function

```text
Report whether the supplied style value is a supported color token.
```

## CL-STYLES.TOKENS:EM

Kinds: function

```text
Construct an em-relative length token for style resolution.
```

## CL-STYLES.TOKENS:HSL

Kinds: function

```text
Construct an HSL color token for the styling engine.
```

## CL-STYLES.TOKENS:LEN

Kinds: function

```text
Construct a normalized length token from the supplied value and unit.
```

## CL-STYLES.TOKENS:LENGTH-P

Kinds: function

```text
Report whether the supplied value is a normalized length token.
```

## CL-STYLES.TOKENS:MISSING-STYLE-VARIABLE

Kinds: type

```text
Public missing style variable type used to represent structured asynchronous tasks, styles or UI elements.
```

## CL-STYLES.TOKENS:PERCENT

Kinds: function

```text
Construct a percentage length token for relative layout or styling.
```

## CL-STYLES.TOKENS:PX

Kinds: function

```text
Construct a pixel or terminal-cell length token used by the styling layer.
```

## CL-STYLES.TOKENS:RESOLVE-VARIABLE-VALUE

Kinds: function

```text
Resolve VALUE recursively against VARS and return VALUE plus expansion records.
Missing variables and cycles signal typed conditions unless the reference supplies a fallback.
```

## CL-STYLES.TOKENS:RESOLVE-VARIABLES

Kinds: function

```text
Resolve top-level variable references in PLIST recursively.
Returns two values: the resolved plist and VARIABLE-EXPANSION records.
A missing variable or cycle signals a typed condition unless a VAR fallback recovers it.
```

## CL-STYLES.TOKENS:RGB

Kinds: function

```text
Construct an RGB color token from red, green and blue components.
```

## CL-STYLES.TOKENS:RGBA

Kinds: function

```text
Construct an RGBA color token including alpha.
```

## CL-STYLES.TOKENS:ROOT-EM

Kinds: function

```text
Construct a root-em-relative length token for style resolution.
```

## CL-STYLES.TOKENS:STYLE-VARIABLE-CHAIN

Kinds: function

```text
Return the chain recorded in the style variable representation.
```

## CL-STYLES.TOKENS:STYLE-VARIABLE-CYCLE

Kinds: type

```text
Public style variable cycle type used to represent structured asynchronous tasks, styles or UI elements.
```

## CL-STYLES.TOKENS:STYLE-VARIABLE-NAME

Kinds: function

```text
Return the name recorded in the style variable representation.
```

## CL-STYLES.TOKENS:STYLE-VARIABLE-RESOLUTION-ERROR

Kinds: type

```text
Public style variable resolution error type used to represent structured asynchronous tasks, styles or UI elements.
```

## CL-STYLES.TOKENS:VALIDATE-VARIABLE-ENVIRONMENT

Kinds: function

```text
Resolve every defined variable once so cycles and missing dependencies fail early.
```

## CL-STYLES.TOKENS:VAR

Kinds: function

```text
Construct a style variable reference, optionally with a fallback value.
```

## CL-STYLES.TOKENS:VARIABLE-EXPANSION

Kinds: type

```text
Public variable expansion type used to represent structured asynchronous tasks, styles or UI elements.
```

## CL-STYLES.TOKENS:VARIABLE-EXPANSION-CHAIN

Kinds: function

```text
Return the chain recorded in the variable expansion representation.
```

## CL-STYLES.TOKENS:VARIABLE-EXPANSION-FALLBACK-USED-P

Kinds: function

```text
Return true when the supplied value satisfies the variable expansion fallback used type predicate.
```

## CL-STYLES.TOKENS:VARIABLE-EXPANSION-NAME

Kinds: function

```text
Return the name recorded in the variable expansion representation.
```

## CL-STYLES.TOKENS:VARIABLE-EXPANSION-PROPERTY

Kinds: function

```text
Return the property recorded in the variable expansion representation.
```

## CL-STYLES.TOKENS:VARIABLE-EXPANSION-VALUE

Kinds: function

```text
Return the value recorded in the variable expansion representation.
```

## CL-STYLES.TOKENS:VARIABLE-REF-P

Kinds: function

```text
Report whether a style value refers to a stylesheet variable.
```

## ELMTUI:DEV-MAIN

Kinds: function

```text
Minimal development entrypoint placeholder.

Keep this silent so loading or smoke-running the top-level system does not leak
accidental debug text into automated test output.
```

## ELMTUI:USE-VALUE

Kinds: function

```text
Transfer control and VALUE to a restart named USE-VALUE, or
return NIL if none exists.
```

## ELMTUI.API:DSL-TYPE

Kinds: function

```text
Resolve DSL TYPE to a component class.
This generic function is the core of the polymorphic DSL resolution system.

Methods are defined per component or variant:
- Keywords resolve to classes
- Lists inject extra props
- Symbols terminate (are classes)

Returns (values class props).
```

## ELMTUI.APP:DEFAPPLICATION

Kinds: macro

```text
Define the normative full-featured ElmTUI application called NAME.

DEFAPPLICATION is the application constructor selected for the next stable major
version. It owns the production application surface: CL-STATE initialization,
component/root-viewport wiring, context/patch updates, subscriptions, CLI and
binary configuration, keymaps, generated runners, and selectable
:TRANSACTIONAL/:STRICT-ELM commit semantics. ELMTUI.APP.TEA-CORE:DEFTEA-APP
remains a supported minimal direct-transition adapter for small or pedagogical
TEA programs; both constructors lower to MAKE-RUNTIME-APP-SPEC and therefore
share the same INIT/TRANSITION/VIEW/SUBSCRIPTIONS runtime vocabulary.

Arguments:
  NAME is a non-keyword application symbol. ARGS is the DEFAPPLICATION keyword
  plist. :ROOT-VIEWPORT-ID and :ROOT-COMPONENT-DSL are required. Optional keys
  include :INITIAL-STATE-PLIST/:INITIAL-STATE-FN, :UPDATE-FN, :VIEW-FN,
  :SUBSCRIPTIONS-FN, :COMMAND-PROCESSOR-FN, :STATE-SEMANTICS, CLI/binary
  configuration, and platform options.

Returns:
  Macro expansion defining application helpers, configuration, and RUN-NAME;
  the expansion itself yields NAME.

Mutation:
  Macro expansion registers application configuration and generated functions.
  Runtime mutation follows :STATE-SEMANTICS: :TRANSACTIONAL commits through the
  state transaction machinery; :STRICT-ELM installs frozen replacement
  snapshots with structural sharing.

Conditions:
  Macro expansion signals an error for missing required keys, unsupported state
  semantics, or invalid function/configuration designators. Runtime conditions
  from generated update/view/subscription code remain inspectable through their
  owning framework boundaries.

Example:
  (defapplication counter
    :root-viewport-id :root
    :root-component-dsl '(:root-viewport :id :root :children ())
    :initial-state-plist '(:count 0)
    :update-fn #'counter-update
    :view-fn #'counter-view
    :subscriptions-fn #'counter-subscriptions
    :state-semantics :strict-elm)
```

## ELMTUI.APP:DEFINE-WIDGET-KEYMAP

Kinds: macro

```text
DSL = DEFINE-KEYMAP + automatic registration + context.
```

## ELMTUI.APP:MAKE-APP-CONFIG

Kinds: function

_No documentation metadata._

## ELMTUI.APP:REGISTER-MESSAGE-BINDING

Kinds: function

```text
Sugar: add a :message binding that emits MSG list.
```

## ELMTUI.APP.API:APP-CONFIG

Kinds: type

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-BINARY-OPTIONS

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-CLI-OPTIONS

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-COMMAND-PROCESSOR-FN

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-CONFIGURE-FN

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-INITIAL-STATE-PLIST

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-MESSAGE-QUEUE

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-NAME

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-RENDERER-FN

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-ROOT-COMPONENT-DSL

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-STATE-SEMANTICS

Kinds: function

```text
Return the application's state commit semantics, either :TRANSACTIONAL or :STRICT-ELM.
```

## ELMTUI.APP.API:APP-CONFIG-SUBSCRIPTIONS-FN-FORM

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-UPDATE-FN-SYM

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:APP-CONFIG-VIEW-FN-SYM

Kinds: function

_No documentation metadata._

## ELMTUI.APP.API:GET-CLI-ARG

Kinds: function

```text
Read CLI argument KEY from STATE at (:cli KEY), returning DEFAULT when absent.
```

## ELMTUI.APP.API:GET-COMPONENT-INSTANCE

Kinds: function

```text
Resolve a component ID path against an APPLICATION-STATE.
ID-PATH accepts a scalar keyword, symbol or string, or a list of segments;
:COMPONENTS is an optional leading path segment. Invalid states signal TYPE-ERROR.
```

## ELMTUI.APP.API:MAKE-RUNTIME-APP-SPEC

Kinds: function

```text
Build the canonical runtime application specification.

The normative runtime vocabulary is INIT and TRANSITION:

  INIT :: () -> (values MODEL COMMANDS)
  TRANSITION :: (MESSAGE MODEL) -> (values NEXT-MODEL COMMANDS)
  VIEW :: MODEL -> DSL
  SUBSCRIPTIONS :: MODEL -> SUBSCRIPTIONS

DEFAPPLICATION, the normative full application constructor for the next stable
major version, adapts its context/patch update callback into TRANSITION.
DEFTEA-APP remains the supported minimal direct-transition adapter for small and
pedagogical applications. Both lower through this function. The returned plist
retains the legacy internal :UPDATE-FN key because the platform driver consumes
that key, but new framework code should construct specs through this function
and speak in terms of transitions.

STATE-SEMANTICS must be :TRANSACTIONAL or :STRICT-ELM. A NIL SUBSCRIPTIONS value
is normalized to an empty subscription function.
```

## ELMTUI.APP.API:PROCESS-COMMAND-DEFAULT

Kinds: function

```text
Default command processing function. Can be overridden by specific applications.
```

## ELMTUI.APP.API:READ-EVENT-DEFAULT

Kinds: function

```text
Default event reading function. Can be overridden by specific applications.
```

## ELMTUI.APP.API:RENDER-VIEW-DEFAULT

Kinds: function

```text
Default view rendering function. Can be overridden by specific applications.
```

## ELMTUI.APP.API:RUN-APPLICATION

Kinds: function

```text
Run the application with the given app-spec and platform options.
```

## ELMTUI.APP.API:VALIDATE-PLATFORM-OPTIONS

Kinds: function

```text
Validate a proper PLATFORM-OPTIONS keyword/value plist for PLATFORM.
```

## ELMTUI.APP.EXTENSION:EXTRACT-PLATFORM-OPTIONS

Kinds: function

```text
Select options marked with :platform-option from PARSED-VALUES.
```

## ELMTUI.APP.EXTENSION:MERGE-CLI-OPTION-SPECS

Kinds: function

```text
Merge :cli-options and :args into one validated option spec list.
```

## ELMTUI.APP.EXTENSION:NORMALIZE-BINARY-OPTIONS

Kinds: function

```text
Normalize :binary setting into a plist, or NIL when disabled.
```

## ELMTUI.APP.EXTENSION:NORMALIZE-SIMPLE-ARGS-SPECS

Kinds: function

```text
Normalize :args simple specs into internal CLI option specs.
```

## ELMTUI.APP.EXTENSION:PARSE-CLI-OPTIONS

Kinds: function

```text
Parse ARGV according to SPECS and return a plist keyed by :name.
```

## ELMTUI.APP.EXTENSION:VALIDATE-CLI-OPTION-SPECS

Kinds: function

```text
Validate CLI option SPECS and return them unchanged.
```

## ELMTUI.APP.TEA-CORE:DEFTEA-APP

Kinds: macro

```text
Define a supported minimal direct-transition TEA application and RUN-NAME.

DEFTEA-APP is intentionally the small/pedagogical constructor, not the normative
full application constructor for the next stable major version. Use
ELMTUI.APP:DEFAPPLICATION for production application composition, component and
root-viewport initialization, CL-STATE patch/context updates, CLI/binary
configuration, keymaps, and selectable transaction semantics. DEFTEA-APP remains
compatible for direct model-replacement programs and lowers through the same
MAKE-RUNTIME-APP-SPEC INIT/TRANSITION/VIEW/SUBSCRIPTIONS vocabulary.

Syntax:

  (deftea-app NAME
    :init       INIT-FN
    :transition TRANSITION-FN
    :view       VIEW-FN
    &key
      :subscriptions      SUBS-FN
      :command-processor  CMD-FN
      :root-viewport-id   ROOT-ID)

Required arguments:

  NAME
    A non-keyword symbol naming the application. This is used to derive:

      * *NAME-APP-SPEC* — a DEFparameter holding the app spec plist
      * RUN-NAME        — a function that hands the spec to RUN-APPLICATION

  :INIT
    A function designator (symbol or lambda) called with no arguments:

      INIT-FN :: () -> (values MODEL COMMANDS)

    MODEL
      Arbitrary application model object (often a plist or hash table).
    COMMANDS
      A list of "commands" understood by the command processor,
      or NIL if there are no startup side-effects.

  :TRANSITION
    The canonical direct transition function designator called for each message:

      TRANSITION-FN :: (MSG MODEL) -> (values NEXT-MODEL COMMANDS)

    :UPDATE is retained as a legacy compatibility alias for :TRANSITION. Do not
    specify both; new code should use :TRANSITION.

    MSG
      An arbitrary message object (often a keyword or small list).
    MODEL / NEXT-MODEL
      The current / next model. NEXT-MODEL must be suitable for
      subsequent calls to TRANSITION and VIEW.
    COMMANDS
      A list of commands to execute after the update, or NIL.

  :VIEW
    A function designator that renders the current model into a DSL tree:

      VIEW-FN :: MODEL -> DSL-TREE

    DSL-TREE
      A tree of view nodes understood by the rendering pipeline.
      In a typical setup the root node is a ROOT-VIEWPORT widget,
      often of the form:

        (:root-viewport :id ROOT-ID ...)

    where ROOT-ID matches the :ROOT-VIEWPORT-ID argument below.

Optional keywords:

  :SUBSCRIPTIONS
    A function designator

      SUBS-FN :: MODEL -> LIST-OF-SUBSCRIPTIONS

    or NIL.  If NIL, it is replaced with a function that always
    returns NIL.  This function is passed to the driver in the
    :SUBSCRIPTIONS-FN slot of the app spec and may be used by the
    event loop to (re-)establish subscriptions after each update.

  :COMMAND-PROCESSOR
    A function designator

      CMD-FN :: (CMD QUEUE MODEL APP-CONFIG) -> *

    or NIL.  If non-NIL, the driver calls it for each command
    produced by TRANSITION, passing:

      CMD        — the command object
      QUEUE      — the app's message queue (for enqueuing new MSGs)
      MODEL      — the current model *after* the update
      APP-CONFIG — optional configuration object (may be NIL)

    For a minimal TEA app you can omit this entirely.

  :ROOT-VIEWPORT-ID
    A symbol, keyword, or string naming the logical root viewport.
    It is converted to a keyword via a small helper and passed as
    :ROOT-VIEWPORT-ID in the app spec.  The platform driver uses this
    to compute the root component path.

    If omitted, defaults to :ROOT-VIEWPORT.

Expansion / side effects:

  (deftea-app NAME ...) expands to:

    - A DEFparameter

        *NAME-APP-SPEC*

      containing a plist with at least:

        :name                NAME
        :init-fn             INIT-FN
        :update-fn           TRANSITION-FN  ; legacy internal runtime key
        :view-fn             VIEW-FN
        :subscriptions-fn    SUBS-FN-OR-DEFAULT
        :command-processor-fn COMMAND-PROCESSOR
        :message-queue       (MAKE-MESSAGE-CHANNEL :CAPACITY 20)
        :root-viewport-id    ROOT-ID-KEYWORD

    - A function

        (defun RUN-NAME (&key (platform :terminal) platform-options &allow-other-keys)
          ...)

      which simply calls ELMTUI.APP.API:RUN-APPLICATION with the
      constructed spec and the given backend options.

Contracts / validation:

  * NAME must be a non-keyword symbol.
  * :INIT, :VIEW, and one of canonical :TRANSITION or legacy :UPDATE must be
    non-NIL and suitable as FUNCALL arguments (symbol or lambda).
  * :ROOT-VIEWPORT-ID must resolve to a keyword; an error is signaled
    at macro-expansion time for unsupported types.

  If the ELMTUI.CONTRACTS package is loaded and provides the function
  VALIDATE-ELM-APPLICATION, a sanity check is run once at load-time:

    (validate-elm-application UPDATE-FN VIEW-FN SUBS-FN)

  using a synthetic test model.  If this check fails, an error is
  signaled during load, so application contracts fail fast.
```

## ELMTUI.BACKEND.FAKETERM:FAKETERM-ENQUEUE-INPUT

Kinds: function

```text
Append EVENT to INSTANCE's deterministic fake input queue.
```

## ELMTUI.BACKEND.FAKETERM:FAKETERM-INSTANCE

Kinds: type

_No documentation metadata._

## ELMTUI.BACKEND.FAKETERM:FAKETERM-LOG-LINES

Kinds: function

```text
Return the current faketerm operation log as deterministic strings.
```

## ELMTUI.BACKEND.FAKETERM:FAKETERM-RUN-TO-QUIESCENCE

Kinds: function

```text
Drive INSTANCE with STEP-FN until deterministic quiescence.

STEP-FN is called as (STEP-FN INSTANCE STEP), with STEP starting at 1.
The runner never sleeps: it stops when INSTANCE has no queued input and the
screen snapshot is unchanged across a step, or when UNTIL returns true.  If no
condition is reached within MAX-STEPS, signal an error with the latest screen
and queue state in the message.
```

## ELMTUI.BACKEND.FAKETERM:FAKETERM-SCREEN-LINES

Kinds: function

```text
Return a deterministic row-major snapshot of the fake terminal screen as strings.

Each string has exactly the faketerm width. The returned list has exactly
faketerm height entries, making it suitable for non-interactive assertions
against rendered TUI state.
```

## ELMTUI.BACKEND.FAKETERM:GET-CELL-STYLE-FAKETERM

Kinds: function

```text
Returns the style plist at the given row and col from the screen buffer.
```

## ELMTUI.BACKEND.FAKETERM:GET-CHAR-AT-FAKETERM

Kinds: function

```text
Returns the character at the given row and col from the screen buffer.
```

## ELMTUI.CL-STATE.MESSAGE-NORMALIZATION:CANONICALIZE-MESSAGE-VARIANT

Kinds: function

```text
Delegating boundary module for message variant canonicalization.
```

## ELMTUI.CL-STATE.MESSAGE-NORMALIZATION:MESSAGE-VARIANT-P

Kinds: function

```text
Delegating boundary module for message variant checks used by state/contracts.
```

## ELMTUI.CL-STATE.MESSAGE-NORMALIZATION:VALIDATE-MESSAGE-INSTANCE

Kinds: function

```text
Validate MESSAGE-INSTANCE against DEFMSG schema for MESSAGE-TYPE.
Returns two values:
  1) canonicalized message instance on success, NIL on failure
  2) failure reason string on failure, NIL on success.
```

## ELMTUI.CL-STATE.PATH-CONTEXT:COMPOSE-STATE-PATH

Kinds: function

```text
Compose PATH onto BASE-PATH for state access/update contexts.
```

## ELMTUI.CONTRACTS:ANALYZE-MESSAGE-USAGE

Kinds: function

```text
Analyzes message usage patterns from update execution log
```

## ELMTUI.CONTRACTS:APP-CONTEXT

Kinds: type

```text
Global application context for the pipeline.

   Arguments:
     STATE          -- (plist) Application model.
     VIEWPORT-RECT  -- (object) Geometry rectangle.
     DSL-TREE       -- (dsl-tree) DSL tree struct.
     RAW-TREE       -- (raw-tree) Raw tree struct.
     STYLED-TREE    -- (styled-tree) Styled tree struct.
     VIEW-FN        -- (function) View function.
     ATOMIC-TREE    -- (atomic-tree) Atomic tree struct.
     LAID-OUT-TREE  -- (laid-out-tree) Laid-out tree struct.
     FRONT-BUFFER   -- (object) Front buffer.
     BACKEND        -- (object) Backend instance.

   Returns:
     An APP-CONTEXT struct holding all pipeline stages and frame state.

   Example:
     (make-app-context :state '(:foo 1) :dsl-tree (make-dsl-tree :root ...))

   (plist, ...) => app-context (pure, no side-effects)

```

## ELMTUI.CONTRACTS:ATOMIC-TREE

Kinds: type

```text
Atomic tree: visibility/overflow resolved.
```

## ELMTUI.CONTRACTS:CONTRACT-SUMMARY

Kinds: function

```text
Returns summary of contract executions for debugging
```

## ELMTUI.CONTRACTS:CONTRACT-VIOLATION

Kinds: type

```text
Base condition for a failed ElmTUI contract. Records FUNCTION-NAME, EXPECTED-TYPE, ACTUAL-VALUE, and optional CONTEXT; its report prints these fields.
```

## ELMTUI.CONTRACTS:CTX-ATOMIC-TREE

Kinds: function

```text
Return the ATOMIC-TREE stage with visibility and overflow decisions resolved.
```

## ELMTUI.CONTRACTS:CTX-BACK-BUFFER

Kinds: function

```text
Return the back buffer used to assemble the next frame.
```

## ELMTUI.CONTRACTS:CTX-BACKEND

Kinds: function

```text
Return the rendering backend associated with APP-CONTEXT.
```

## ELMTUI.CONTRACTS:CTX-DSL-TREE

Kinds: function

```text
Return the DSL-TREE stage currently stored in APP-CONTEXT.
```

## ELMTUI.CONTRACTS:CTX-FRONT-BUFFER

Kinds: function

```text
Return the front buffer representing the previously presented frame.
```

## ELMTUI.CONTRACTS:CTX-LAID-OUT-TREE

Kinds: function

```text
Return the LAID-OUT-TREE stage containing resolved geometry.
```

## ELMTUI.CONTRACTS:CTX-RAW-TREE

Kinds: function

```text
Return the RAW-TREE stage currently stored in APP-CONTEXT.
```

## ELMTUI.CONTRACTS:CTX-STATE

Kinds: function

```text
Return the application model stored in APP-CONTEXT.
```

## ELMTUI.CONTRACTS:CTX-STYLED-TREE

Kinds: function

```text
Return the STYLED-TREE stage currently stored in APP-CONTEXT.
```

## ELMTUI.CONTRACTS:CTX-STYLESHEET

Kinds: function

```text
Return the stylesheet used by the styling stage of APP-CONTEXT.
```

## ELMTUI.CONTRACTS:CTX-VIEW-FN

Kinds: function

```text
Return the view function stored in APP-CONTEXT.
```

## ELMTUI.CONTRACTS:CTX-VIEWPORT-RECT

Kinds: function

```text
Return the viewport rectangle associated with APP-CONTEXT.
```

## ELMTUI.CONTRACTS:CV-ACTUAL-VALUE

Kinds: function

```text
Return the actual offending value recorded in a CONTRACT-VIOLATION condition.
```

## ELMTUI.CONTRACTS:CV-CONTEXT

Kinds: function

```text
Return optional contextual information for a CONTRACT-VIOLATION, or NIL when no context was supplied.
```

## ELMTUI.CONTRACTS:CV-EXPECTED-TYPE

Kinds: function

```text
Return the expected type descriptor recorded in a CONTRACT-VIOLATION condition.
```

## ELMTUI.CONTRACTS:CV-FUNCTION-NAME

Kinds: function

```text
Return the function name recorded in a CONTRACT-VIOLATION condition, identifying the rejected contract boundary.
```

## ELMTUI.CONTRACTS:DEFINE-PIPELINE

Kinds: macro

```text
Compose STAGE-FNS into a single function that threads a context through them.

Each stage must be a function of one argument (the context), and will be
called in the order provided. The declared :pipeline/in-type and
:pipeline/out-type metadata from DEFINE-STAGE can be used by tooling or
validation code, but are not enforced here directly.
```

## ELMTUI.CONTRACTS:DEFINE-STAGE

Kinds: macro

```text
Define a pipeline stage NAME with input/OUTPUT type contracts.

IN-TYPE and OUT-TYPE are type designators used for:
  - A CHECK-TYPE precondition on the input.
  - A TYPEP-based postcondition on the result.

Any non-Elmtui ERROR signaled inside BODY is wrapped in a
PIPELINE-CONTRACT-VIOLATION. Errors that already belong to the
Elmtui error hierarchy (ELMTUI-ERROR and subclasses like DSL-ERROR)
are allowed to propagate unchanged, preserving their rich context.
```

## ELMTUI.CONTRACTS:DEFSUBSCRIPTIONS

Kinds: macro

```text
Defines a subscriptions function with contract enforcement.
```

## ELMTUI.CONTRACTS:DEFTRANSFORM

Kinds: macro

```text
Define a pure transformer and an App-Context plumbing stage.
```

## ELMTUI.CONTRACTS:DEFTRANSFORMER

Kinds: macro

```text
Define a pure (tree &key …) → tree function and an APP-CONTEXT stage.

   Example:

     (deftransformer raw→styled (raw-tree) (styled-tree)
       (raw-tree &key stylesheet theme)
       ...)

   The wrapper extracts :STYLESHEET and :THEME from CTX via CTX-STYLESHEET,
   CTX-THEME accessors and calls RAW→STYLED with them.
```

## ELMTUI.CONTRACTS:DEFUPDATE-CTR

Kinds: macro

```text
Defines an update function with flexible message validation (backward compatible).
   This is equivalent to defupdate-flexible.
```

## ELMTUI.CONTRACTS:DEFUPDATE-FLEXIBLE

Kinds: macro

```text
Defines an update function with flexible message validation.
   Accepts any message format - useful for prototyping and migration.

   Contract: update(message, model) => (values new-model commands)
   - model: Current application state (immutable, property list)
   - message: Any message format (flexible validation)
   - new-model: Updated state or nil (no change)
   - commands: List of side-effects to execute or nil
```

## ELMTUI.CONTRACTS:DEFUPDATE-HYBRID

Kinds: macro

```text
Define an UPDATE function that works with *either* typed or flexible
   messages.

   Usage
   -----
     (defupdate-hybrid <function-name> (message model)
       [:MESSAGE-TYPE <symbol>]   ;; preferred defmsg schema
       [:PREFER-TYPED  <boolean>] ;; warn on untyped msg when non-NIL
       [doc-string]               ;; optional
       body-forms…)

   Contract: (update message model) -> (values new-model commands)
```

## ELMTUI.CONTRACTS:DEFUPDATE-TYPED

Kinds: macro

```text
Defines an update function with strict message type validation.
   Only accepts messages that conform to the specified defmsg schema.

   Contract: update(typed-message, model) => (values new-model commands)
   - model: Current application state (immutable, property list)
   - message: Must be valid variant of message-type (strict validation)
   - message-type: Symbol naming the defmsg schema (e.g., 'AppMsg)
   - new-model: Updated state or nil (no change)
   - commands: List of side-effects to execute or nil

   Example:
   (defupdate-typed counter-update (message model) AppMsg
     (case (first message)
       (:increment (values (list :count (1+ (getf model :count 0))) nil))
       (:decrement (values (list :count (1- (getf model :count 0))) nil))
       (t (values nil nil))))
```

## ELMTUI.CONTRACTS:DEFVIEW

Kinds: macro

```text
Defines a view function with strict contract enforcement.

   Arguments:
     NAME        -- (symbol) Name of the view function.
     MODEL-PARAM -- (symbol) Model parameter name.
     BODY        -- (forms) Body of the view function.

   Returns:
     Defines a function that validates input, executes BODY, and validates output as a DSL tree.

   Example:
     (defview my-view (model)
       (list :container :children ...))

   (symbol, symbol, forms) => macro-expansion (side-effect: defines function)

   Side-effects:
     - Defines a function.
     - Signals errors on contract violation.
     - May log execution if debugging enabled.

   Purity: impure (macro, global definition, error signaling)

```

## ELMTUI.CONTRACTS:DSL-TREE

Kinds: type

```text
DSL tree: holds the nested DSL list.

   Arguments:
     ROOT -- (list) The nested DSL list.

   Returns:
     A DSL-TREE struct.

   Example:
     (make-dsl-tree :root '(:container ...))

   (list) => dsl-tree (pure, no side-effects)

```

## ELMTUI.CONTRACTS:ENABLE-CONTRACT-DEBUGGING

Kinds: function

```text
Enable/disable contract debugging
```

## ELMTUI.CONTRACTS:LAID-OUT-TREE

Kinds: type

```text
Laid-out tree: geometry resolved.
```

## ELMTUI.CONTRACTS:MAKE-APP-CONTEXT

Kinds: function

```text
Construct an APP-CONTEXT from the supplied pipeline state, tree stages, buffers, viewport, stylesheet, view function, and backend. The constructor only packages references; it does not render or mutate application state.
```

## ELMTUI.CONTRACTS:MAKE-ATOMIC-TREE

Kinds: function

```text
Construct an ATOMIC-TREE with ROOT holding the tree after visibility and overflow decisions.
```

## ELMTUI.CONTRACTS:MAKE-DSL-TREE

Kinds: function

```text
Construct a DSL-TREE with ROOT holding a nested declarative DSL list before conversion to UI nodes.
```

## ELMTUI.CONTRACTS:MAKE-LAID-OUT-TREE

Kinds: function

```text
Construct a LAID-OUT-TREE with ROOT holding the tree after geometry has been resolved.
```

## ELMTUI.CONTRACTS:MAKE-RAW-TREE

Kinds: function

```text
Construct a RAW-TREE whose ROOT holds the generated UI-node tree before stylesheet application.
```

## ELMTUI.CONTRACTS:MAKE-STYLED-TREE

Kinds: function

```text
Construct a STYLED-TREE with ROOT holding the UI-node tree after styles have been applied.
```

## ELMTUI.CONTRACTS:MAKE-SUBSCRIPTION

Kinds: function

```text
Construct a SUBSCRIPTION descriptor with TYPE, CONFIG plist, and MESSAGE-FN for converting incoming event data into an application message.
```

## ELMTUI.CONTRACTS:MESSAGE-CONTRACT-VIOLATION

Kinds: type

```text
Specialized CONTRACT-VIOLATION for a message rejected by its schema or required validation mode.
```

## ELMTUI.CONTRACTS:PIPELINE-CONTRACT-VIOLATION

Kinds: type

```text
Pipeline error condition recording STAGE, EXPECTED-TYPE, GOT-OBJECT, and optional STACK-TRACE; signaled for failed pipeline type contracts.
```

## ELMTUI.CONTRACTS:RAW-TREE

Kinds: type

```text
Raw tree: UI-node tree before styling.

   Arguments:
     ROOT -- (object) The root UI-node.

   Returns:
     A RAW-TREE struct.

   Example:
     (make-raw-tree :root ...)

   (object) => raw-tree (pure, no side-effects)

```

## ELMTUI.CONTRACTS:ROOT

Kinds: function

```text
Returns the root node of a tree structure.
```

## ELMTUI.CONTRACTS:STYLED-TREE

Kinds: type

```text
Styled tree: after stylesheet application.
```

## ELMTUI.CONTRACTS:SUBSCRIPTION

Kinds: type

```text
Subscription descriptor for Elm Architecture
```

## ELMTUI.CONTRACTS:SUBSCRIPTION-CONTRACT-VIOLATION

Kinds: type

```text
Specialized CONTRACT-VIOLATION for subscription generation or validation failures.
```

## ELMTUI.CONTRACTS:SUBSCRIPTION-P

Kinds: function

```text
Return true when OBJECT is a SUBSCRIPTION structure produced by the framework subscription constructor; otherwise return NIL.
```

## ELMTUI.CONTRACTS:SUGGEST-MESSAGE-SCHEMA

Kinds: function

```text
Suggests a defmsg schema based on observed message patterns
```

## ELMTUI.CONTRACTS:TRACE-CONTRACTS

Kinds: function

```text
Return tracing status text for selected contract types.

When STREAM is supplied, also write the generated text there. This keeps
non-interactive callers silent by default while preserving an explicit
interactive diagnostic path.
```

## ELMTUI.CONTRACTS:UPDATE-CONTRACT-VIOLATION

Kinds: type

```text
Specialized CONTRACT-VIOLATION signaled for invalid update input, update execution, or update result contracts.
```

## ELMTUI.CONTRACTS:VALIDATE-COMMANDS

Kinds: function

```text
Validates that commands list is properly structured
```

## ELMTUI.CONTRACTS:VALIDATE-DSL

Kinds: function

```text
Validates that DSL is a valid DSL structure.

   Arguments:
     DSL           -- (any) The DSL value to validate.
     FUNCTION-NAME -- (symbol) Name of the calling function.
     MODEL         -- (any) The model used for rendering.

   Returns:
     DSL if valid, otherwise signals a view-contract-violation error.

   Example:
     (validate-dsl '(:container :children ...) 'my-view '(:foo 1))

   (any, symbol, any) => any (side-effect: error signaling)

   Side-effects:
     - Signals error if DSL is invalid.

   Purity: impure (error signaling)

```

## ELMTUI.CONTRACTS:VALIDATE-ELM-APPLICATION

Kinds: function

```text
Validates that an Elm application's functions conform to contracts
```

## ELMTUI.CONTRACTS:VALIDATE-FLEXIBLE-MESSAGE

Kinds: function

```text
Validates message in flexible mode - accepts any message format
```

## ELMTUI.CONTRACTS:VALIDATE-HYBRID-MESSAGE

Kinds: function

```text
Validates message in hybrid mode - accepts both typed and flexible messages
```

## ELMTUI.CONTRACTS:VALIDATE-MESSAGE

Kinds: function

```text
Validates message according to specified validation mode.

   Validation modes:
   - :flexible  - Accept any message (current behavior)
   - :typed     - Enforce specific message type schema
   - :hybrid    - Accept both typed and flexible messages
   - :strict    - Only typed messages, no ad-hoc allowed
```

## ELMTUI.CONTRACTS:VALIDATE-MODEL

Kinds: function

```text
Validates that model follows proper structure
```

## ELMTUI.CONTRACTS:VALIDATE-STRICT-MESSAGE

Kinds: function

```text
Validates message in strict mode - only typed messages allowed
```

## ELMTUI.CONTRACTS:VALIDATE-SUBSCRIPTIONS

Kinds: function

```text
Validates subscriptions list structure
```

## ELMTUI.CONTRACTS:VALIDATE-TYPED-MESSAGE

Kinds: function

```text
Validates message against a specific defmsg schema
```

## ELMTUI.CONTRACTS:VALIDATE-UPDATE-RESULT

Kinds: function

```text
Validates the result of an update function
```

## ELMTUI.CONTRACTS:VIEW-CONTRACT-VIOLATION

Kinds: type

```text
Specialized CONTRACT-VIOLATION signaled when a view function fails validation or returns an invalid view.
```

## ELMTUI.CONTRACTS:VIOLATION-EXPECTED

Kinds: function

```text
Return the expected type descriptor recorded in a PIPELINE-CONTRACT-VIOLATION.
```

## ELMTUI.CONTRACTS:VIOLATION-GOT

Kinds: function

```text
Return the offending object recorded in a PIPELINE-CONTRACT-VIOLATION.
```

## ELMTUI.CONTRACTS:VIOLATION-STAGE

Kinds: function

```text
Return the stage identifier recorded in a PIPELINE-CONTRACT-VIOLATION.
```

## ELMTUI.CORE.ASYNC:*ASYNC-ERRORS*

Kinds: variable

```text
Async task errors.
```

## ELMTUI.CORE.ASYNC:*ASYNC-TASKS*

Kinds: variable

```text
Active async tasks.
```

## ELMTUI.CORE.ASYNC:AWAIT-CMD

Kinds: function

```text
Wait for CMD and return its completed result.

Arguments:
  CMD is an ElmTUI command structure. :ASYNC commands are awaited directly;
  :BATCH commands are awaited recursively; :DISPATCH returns NIL.

Returns:
  The async task result, a list of batch results, or NIL for non-awaitable
  command kinds.

Mutation:
  Waiting does not mutate application state, but the worker being awaited may
  already have performed its documented effects and promise transitions.

Conditions:
  Worker failures are translated to ASYNC-TASK-ERROR while preserving the
  original failure as the condition reason. Unknown command kinds are warned
  about and return NIL.

Restarts:
  WITH-ASYNC-RESTARTS establishes IGNORE-TASK, REPLACE-TASK, PROVIDE-RESULT,
  standard USE-VALUE, and RETRY while the await operation is active. RETRY may
  repeat an await and must not be confused with rerunning an arbitrary effect.

Example:
  (handler-bind
      ((elmtui.core.conditions:async-task-error
         (lambda (condition)
           (declare (ignore condition))
           (invoke-restart 'use-value :cached))))
    (await-cmd command))
```

## ELMTUI.CORE.ASYNC:CANCEL-CMD

Kinds: function

```text
Cancel CMD according to its command kind.

Arguments:
  CMD is an ElmTUI command structure. For :ASYNC commands the associated task
  and promise are cancelled; batches are traversed recursively where supported.

Returns:
  The command-kind-specific cancellation result, conventionally true/NIL.

Mutation:
  Mutates task/promise lifecycle state and the async task registry as required
  by the command implementation. It does not directly mutate the application
  model.

Conditions:
  Cancellation failures are exposed as ASYNC-TASK-ERROR. Unknown/non-cancellable
  commands may warn and return NIL.

Restarts:
  The standard async recovery restarts are active while cancellation runs.
  Retrying cancellation is intended to be safe only for cancellation backends
  whose operation is idempotent.

Example:
  (cancel-cmd command)
```

## ELMTUI.CORE.ASYNC:CANCEL-RECURRING-CMD

Kinds: function

```text
Cancel a recurring command.
```

## ELMTUI.CORE.ASYNC:CMD-ASYNC

Kinds: function

```text
Construct an asynchronous ElmTUI command around FUNCTION.

Arguments:
  FUNCTION receives a progress callback followed by ARGS. ON-COMPLETE maps a
  successful result to an application message; ON-ERROR maps a failure to an
  application message. TIMEOUT schedules promise cancellation after the given
  seconds. CANCELLATION-FN is optional best-effort cancellation cleanup.

Returns:
  A command plist beginning with :ASYNC and containing the task, generated task
  id, promise, and completion/error callbacks. Execution does not begin until
  INTERPRET-CMD processes the command.

Mutation:
  Allocates task/promise objects. Once interpreted, the worker resolves/rejects
  the promise and sends progress/completion/error messages through *APP-SENDER*.
  A timeout may invoke CANCELLATION-FN and cancel the promise.

Conditions:
  Construction errors are exposed through ASYNC-TASK-ERROR recovery. Worker
  errors reject the promise, optionally emit ON-ERROR output, and remain
  available when the task is awaited. CANCELLATION-FN failures are currently
  deliberately suppressed during timeout cleanup.

Restarts:
  Construction is wrapped by WITH-RECOVERY with IGNORE-TASK and RETRY. Retrying
  construction may allocate a new task/promise pair.

Example:
  (cmd-async (lambda (progress value)
               (funcall progress '(:phase :working))
               (1+ value))
             :args '(41)
             :on-complete
             (lambda (result)
               `(:lookup-succeeded :result ,result)))
```

## ELMTUI.CORE.ASYNC:CMD-ASYNC-WITH-RETRY

Kinds: function

```text
Construct a CMD that will run FUNCTION with ARGS asynchronously, retrying on failure.
   Parameters are the same as cmd-async with these additional options:
   - RETRY-ATTEMPTS: Number of retry attempts (default: 3)
   - RETRY-DELAY: Delay in seconds between retry attempts (default: 1.0)

   The function will retry automatically if it fails, up to RETRY-ATTEMPTS times
   with RETRY-DELAY seconds between attempts.
```

## ELMTUI.CORE.ASYNC:CMD-BATCH

Kinds: function

```text
Create a CMD that executes a batch of COMMANDS sequentially.
   Returns a list of results from each command in the batch.
```

## ELMTUI.CORE.ASYNC:CMD-RECURRING

Kinds: function

```text
Create a recurring command that runs periodically.
   Parameters:
   - INTERVAL-SECONDS: Time in seconds between executions
   - FUNCTION: The function to execute repeatedly
   - ARGS: Arguments to pass to the function
   - ON-MESSAGE: Function to create messages from function results
   - STOP-CONDITION: Function that returns true when the recurring task should stop
   - MAX-ITERATIONS: Maximum number of iterations (-1 for unlimited)

   Returns a command structure for a recurring task that can be cancelled.
```

## ELMTUI.CORE.ASYNC:INTERPRET-CMD

Kinds: function

```text
Interpret and execute one ElmTUI command.

Arguments:
  CMD begins with one of :ASYNC, :BATCH, :DISPATCH, or :RECURRING-TASK.
  *APP-SENDER* must name a callable application-message sink.

Returns:
  :ASYNC returns two values, its task and promise. :BATCH returns a list of
  recursively interpreted results. :DISPATCH sends its payload and returns NIL.
  :RECURRING-TASK starts its worker and returns its task id. Unknown command
  kinds return (:UNKNOWN KIND) after a warning.

Mutation:
  :ASYNC stores the task in *ASYNC-TASKS* and starts it. :DISPATCH sends a
  message. :RECURRING-TASK creates/stores a worker thread whose function may
  perform its documented effects and emit messages. The application model is
  changed only later through messages/update, not directly by this interpreter.

Conditions:
  Missing *APP-SENDER* is an error. Command execution failures are translated
  to ASYNC-TASK-ERROR with CMD in the task slot and the original condition in
  the reason slot.

Restarts:
  WITH-ASYNC-RESTARTS keeps the original ASYNC-TASK-ERROR inspectable while
  offering IGNORE-TASK, REPLACE-TASK, PROVIDE-RESULT, standard USE-VALUE, and
  RETRY. RETRY can repeat command side effects and is safe only when the command
  operation is idempotent or otherwise transactionally protected.

Example:
  (multiple-value-bind (task promise)
      (interpret-cmd
       (cmd-async (lambda (_progress) :ready)))
    (values task promise))
```

## ELMTUI.CORE.ASYNC:SPAWN-WORKER

Kinds: function

```text
Spawn a worker thread to execute TASK asynchronously.
```

## ELMTUI.CORE.ASYNC:WITH-ASYNC-RESTARTS

Kinds: macro

```text
Execute FORMS with async-task recovery restarts around the operation.

Arguments:
  CONDITION-VAR names an ELMTUI.CORE.CONDITIONS:ASYNC-TASK-ERROR while its
  handler is active. FORMS are the operation to execute.

Returns:
  The values of FORMS on success. IGNORE-TASK returns NIL, REPLACE-TASK returns
  the supplied replacement task, PROVIDE-RESULT returns the supplied result,
  and RETRY re-executes FORMS.

Mutation:
  The macro itself only logs signaled async-task conditions. FORMS controls
  application mutation. RETRY can repeat effects, so use it only around work
  whose retry semantics are safe, idempotent, or otherwise explicitly handled.

Conditions:
  ASYNC-TASK-ERROR is observed with HANDLER-BIND but is not reconstructed or
  re-signaled. If no handler/debugger invokes a restart, the original condition
  propagates normally with its identity and debugger context intact.

Restarts:
  IGNORE-TASK, REPLACE-TASK, PROVIDE-RESULT, the standard Common Lisp
  USE-VALUE, and RETRY are active while FORMS executes. USE-VALUE is the
  preferred programmatic value-substitution restart across package boundaries.

Example:
  (handler-bind
      ((elmtui.core.conditions:async-task-error
         (lambda (condition)
           (declare (ignore condition))
           (invoke-restart 'use-value :cached))))
    (with-async-restarts (_condition)
      (run-async-operation)))
```

## ELMTUI.CORE.CONDITIONS:ASYNC-TASK-ERROR

Kinds: type

```text
Asynchronous task failure retaining task and reason for handler inspection.
```

## ELMTUI.CORE.CONDITIONS:ASYNC-TASK-ERROR-REASON

Kinds: function

```text
Return the asynchronous task failure reason carried by CONDITION.
```

## ELMTUI.CORE.CONDITIONS:ASYNC-TASK-ERROR-TASK

Kinds: function

```text
Return the asynchronous task associated with CONDITION.
```

## ELMTUI.CORE.CONDITIONS:COMMAND-EXECUTION-ERROR

Kinds: type

```text
Failed command execution; preserves original command and diagnostic reason.
```

## ELMTUI.CORE.CONDITIONS:COMMAND-EXECUTION-ERROR-COMMAND

Kinds: function

```text
Return the command whose execution failed in CONDITION.
```

## ELMTUI.CORE.CONDITIONS:COMMAND-EXECUTION-ERROR-REASON

Kinds: function

```text
Return the command execution failure reason carried by CONDITION.
```

## ELMTUI.CORE.CONDITIONS:CONSTRAINT-VALIDATION-ERROR

Kinds: type

```text
Constraint validation failure preserving the violated rule designator.
```

## ELMTUI.CORE.CONDITIONS:CONSTRAINT-VALIDATION-ERROR-CONSTRAINT

Kinds: function

```text
Return the violated constraint designator.
```

## ELMTUI.CORE.CONDITIONS:ELMTUI-VALIDATION-ERROR

Kinds: type

```text
Validation base condition retaining the path, offending value and message.
```

## ELMTUI.CORE.CONDITIONS:EVENT-LOOP-DISPATCH-ERROR

Kinds: type

```text
Event dispatch failure; preserves dispatched event and error reason.
```

## ELMTUI.CORE.CONDITIONS:EVENT-LOOP-DISPATCH-ERROR-EVENT

Kinds: function

```text
Return the event whose dispatch failed in CONDITION.
```

## ELMTUI.CORE.CONDITIONS:EVENT-LOOP-DISPATCH-ERROR-REASON

Kinds: function

```text
Return the event dispatch failure reason carried by CONDITION.
```

## ELMTUI.CORE.CONDITIONS:EVENT-VALIDATION-ERROR

Kinds: type

```text
Event validation failure preserving failed event type and original value.
```

## ELMTUI.CORE.CONDITIONS:LOG-CONDITION

Kinds: function

```text
Log CONDITION with the given LEVEL.
```

## ELMTUI.CORE.CONDITIONS:MESSAGE-DESERIALIZATION-ERROR

Kinds: type

```text
Failed deserialization retaining serialized data and original cause condition.
```

## ELMTUI.CORE.CONDITIONS:MESSAGE-DESERIALIZATION-ERROR-DATA

Kinds: function

```text
Return the serialized message data that failed deserialization in CONDITION.
```

## ELMTUI.CORE.CONDITIONS:MESSAGE-DESERIALIZATION-ERROR-UNDERLYING-CONDITION

Kinds: function

```text
Return the underlying condition that caused message deserialization to fail.
```

## ELMTUI.CORE.CONDITIONS:MESSAGE-SERIALIZATION-ERROR

Kinds: type

```text
Failed serialization retaining message data and original cause condition.
```

## ELMTUI.CORE.CONDITIONS:MESSAGE-SERIALIZATION-ERROR-DATA

Kinds: function

```text
Return the message data that failed serialization in CONDITION.
```

## ELMTUI.CORE.CONDITIONS:MESSAGE-SERIALIZATION-ERROR-UNDERLYING-CONDITION

Kinds: function

```text
Return the underlying condition that caused message serialization to fail.
```

## ELMTUI.CORE.CONDITIONS:MESSAGE-VALIDATION-ERROR

Kinds: type

```text
Rejected application message; retains the message and failure reason via prefixed readers.
```

## ELMTUI.CORE.CONDITIONS:MESSAGE-VALIDATION-ERROR-MESSAGE

Kinds: function

```text
Return the message that failed validation in CONDITION.
```

## ELMTUI.CORE.CONDITIONS:MESSAGE-VALIDATION-ERROR-REASON

Kinds: function

```text
Return the validation failure reason carried by CONDITION.
```

## ELMTUI.CORE.CONDITIONS:PROPERTY-VALIDATION-ERROR

Kinds: type

```text
Property validation failure preserving the invalid property designator.
```

## ELMTUI.CORE.CONDITIONS:PROPERTY-VALIDATION-ERROR-PROPERTY

Kinds: function

```text
Return the rejected UI property name or designator.
```

## ELMTUI.CORE.CONDITIONS:RENDER-ERROR

Kinds: type

```text
Rendering failure carrying a diagnostic message and underlying reason.
```

## ELMTUI.CORE.CONDITIONS:RENDER-ERROR-MESSAGE

Kinds: function

```text
Return the render diagnostic message carried by CONDITION.
```

## ELMTUI.CORE.CONDITIONS:RENDER-ERROR-REASON

Kinds: function

```text
Return the render failure reason carried by CONDITION.
```

## ELMTUI.CORE.CONDITIONS:SIGNAL-SUBSCRIBER-ERROR

Kinds: type

```text
Failure of a signal subscriber retaining the delivered signal and reason. Reporting does not invoke CL:SIGNAL.
```

## ELMTUI.CORE.CONDITIONS:SIGNAL-SUBSCRIBER-ERROR-REASON

Kinds: function

```text
Return the signal subscriber failure reason carried by CONDITION.
```

## ELMTUI.CORE.CONDITIONS:SIGNAL-SUBSCRIBER-ERROR-SIGNAL

Kinds: function

```text
Return the signal being delivered when CONDITION was signaled.
```

## ELMTUI.CORE.CONDITIONS:STATE-UPDATE-ERROR

Kinds: type

```text
State update failure retaining the affected state and failure reason.
```

## ELMTUI.CORE.CONDITIONS:STATE-UPDATE-ERROR-REASON

Kinds: function

```text
Return the state update failure reason carried by CONDITION.
```

## ELMTUI.CORE.CONDITIONS:STATE-UPDATE-ERROR-STATE

Kinds: function

```text
Return the state associated with the failed update in CONDITION.
```

## ELMTUI.CORE.CONDITIONS:SUBSCRIBER-HANDLER-ERROR

Kinds: type

```text
Subscriber callback failure preserving input event, callback and failure reason.
```

## ELMTUI.CORE.CONDITIONS:SUBSCRIBER-HANDLER-ERROR-EVENT

Kinds: function

```text
Return the event being handled when CONDITION was signaled.
```

## ELMTUI.CORE.CONDITIONS:SUBSCRIBER-HANDLER-ERROR-HANDLER

Kinds: function

```text
Return the subscriber handler associated with CONDITION.
```

## ELMTUI.CORE.CONDITIONS:SUBSCRIBER-HANDLER-ERROR-REASON

Kinds: function

```text
Return the subscriber handler failure reason carried by CONDITION.
```

## ELMTUI.CORE.CONDITIONS:TYPE-VALIDATION-ERROR

Kinds: type

```text
Type validation failure retaining expected type, original value and path.
```

## ELMTUI.CORE.CONDITIONS:TYPE-VALIDATION-ERROR-EXPECTED-TYPE

Kinds: function

```text
Return the expected type designator used in validation.
```

## ELMTUI.CORE.CONDITIONS:VALIDATION-ERROR-MESSAGE

Kinds: function

```text
Return the framework-prefixed validation message carried by CONDITION.
```

## ELMTUI.CORE.CONDITIONS:VALIDATION-ERROR-PATH

Kinds: function

```text
Return the optional path locating the offending value.
```

## ELMTUI.CORE.CONDITIONS:VALIDATION-ERROR-VALUE

Kinds: function

```text
Return the original offending Lisp value, without coercion.
```

## ELMTUI.CORE.CONDITIONS:WITH-MESSAGE-RESTARTS

Kinds: macro

```text
Execute FORMS with message-specific restarts around validation failures.

While MESSAGE-VALIDATION-ERROR is active, SKIP-MESSAGE returns NIL,
REPLACE-MESSAGE returns a caller-supplied replacement, and RETRY re-executes
FORMS. CONDITION-VAR names the original condition for logging and inspection.

Mutation: only FORMS may mutate state; RETRY can repeat those effects.
Conditions: the original condition is logged but not re-signaled or swallowed;
handlers or the debugger may invoke the active restarts.
```

## ELMTUI.CORE.CONDITIONS:WITH-RECOVERY

Kinds: macro

```text
Execute BODY with inspectable CONDITION-TYPE recovery restarts.

ON-ERROR is called whenever CONDITION-TYPE is signaled. RESTARTS is a literal
or quoted list containing any of :RETRY, :SKIP, :IGNORE-TASK, :USE-VALUE, and
:ABORT. The selected restarts surround BODY, so handlers and the debugger can
inspect the original condition and invoke recovery without re-signaling it.

:RETRY re-executes BODY, :SKIP and :IGNORE-TASK return NIL, :USE-VALUE returns a
replacement supplied to the restart, and :ABORT propagates the original
condition as an error.

Mutation: the macro itself only records the most recently signaled condition;
BODY controls application mutation. Retrying BODY can repeat its side effects,
so callers should use :RETRY only around idempotent or transactional work.
Conditions: unhandled conditions propagate normally; nothing is swallowed.

Example:
  (handler-bind
      ((message-validation-error
         (lambda (condition)
           (declare (ignore condition))
           (invoke-restart 'use-value :replacement))))
    (with-recovery (message-validation-error :restarts '(:use-value :abort))
      (validate-message message)))
```

## ELMTUI.CORE.CONDITIONS:WITH-RENDER-RESTARTS

Kinds: macro

```text
Execute FORMS with render-specific recovery restarts.

While RENDER-ERROR is active, SKIP-FRAME returns NIL, FALLBACK-VIEW returns a
caller-supplied fallback value, and RETRY re-executes FORMS. CONDITION-VAR names
the original condition for logging and inspection.

Mutation: only FORMS may mutate state; RETRY can repeat those effects.
Conditions: the original condition is logged but remains available to handlers,
the debugger, and active restarts.
```

## ELMTUI.CORE.DEFAULTS:*DEFAULT-REGISTRY*

Kinds: variable

```text
Global registry of default values for all Elmtui components.
```

## ELMTUI.CORE.DEFAULTS:DEFAULT-SPEC

Kinds: type

```text
Specification for a default value with metadata.
```

## ELMTUI.CORE.DEFAULTS:GET-DEFAULT

Kinds: function

```text
Get a default value by key. If ERROR-P is true, signal error for missing defaults.
```

## ELMTUI.CORE.DEFAULTS:GET-DEFAULT-OR-ERROR

Kinds: function

```text
Get a default value, signaling an error if not found.
```

## ELMTUI.CORE.DEFAULTS:MAKE-DEFAULT-CONTEXT

Kinds: function

```text
Create a new default context, optionally inheriting from parent.
```

## ELMTUI.CORE.DEFAULTS:REGISTER-DEFAULT

Kinds: macro

```text
Macro version of register-default for compile-time type safety.

KEY: Symbol or keyword identifying the default
VALUE: The default value
TYPE: Expected type for type checking (evaluated at macroexpansion)
DOCUMENTATION: String describing the default
FALLBACK: Fallback value if primary value is invalid
VALIDATOR: Function to validate the value
CATEGORY: Keyword for grouping related defaults
SOURCE: Source file or system where this default originated
```

## ELMTUI.CORE.DEFAULTS:VALIDATE-DEFAULT-VALUE

Kinds: function

```text
Validate that a default specification is valid.
```

## ELMTUI.CORE.DEFAULTS:WITH-DEFAULTS

Kinds: macro

```text
Execute BODY with overridden defaults.
```

## ELMTUI.CORE.ERRORS:+DIAGNOSTIC-CONTEXT-KEYS+

Kinds: variable

```text
Canonical keys for structured ElmTUI diagnostic context.

The vocabulary is deliberately small and orthogonal: operation identifies the
action, component/state/backend keys identify ownership and location,
message/event identifies runtime input, offending-value and expected-type
explain validation failures, and underlying-condition preserves causal errors.
```

## ELMTUI.CORE.ERRORS:BACKEND-ERROR

Kinds: type

```text
Platform backend operation failure exposing backend type and attempted operation.
```

## ELMTUI.CORE.ERRORS:BACKEND-ERROR-OPERATION

Kinds: function

```text
Return the backend operation associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:BACKEND-ERROR-TYPE

Kinds: function

```text
Return the backend type associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:COMPONENT-ERROR

Kinds: type

```text
Component operation failure retaining component type, identifier and operation for recovery handling.
```

## ELMTUI.CORE.ERRORS:COMPONENT-ERROR-ID

Kinds: function

```text
Return the component identifier associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:COMPONENT-ERROR-OPERATION

Kinds: function

```text
Return the component operation associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:COMPONENT-ERROR-TYPE

Kinds: function

```text
Return the component type associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:DEFCOMPONENT-ERROR

Kinds: type

```text
Invalid component definition. Exposes rejected macro argument and validation category.
```

## ELMTUI.CORE.ERRORS:DEFCOMPONENT-ERROR-ARG

Kinds: function

```text
Return the DEFCOMPONENT argument associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:DEFCOMPONENT-ERROR-VALIDATION-TYPE

Kinds: function

```text
Return the DEFCOMPONENT validation category associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:DEVELOPMENT-MODE-P

Kinds: function

```text
Returns true if we're in development mode.
```

## ELMTUI.CORE.ERRORS:DIAGNOSTIC-CONTEXT-KEY-P

Kinds: function

```text
Return true when KEY belongs to the canonical diagnostic context vocabulary.
```

## ELMTUI.CORE.ERRORS:DSL-ERROR

Kinds: type

```text
Declarative UI form failure, preserving the offending DSL form and source position.
```

## ELMTUI.CORE.ERRORS:DSL-ERROR-FORM

Kinds: function

```text
Return the DSL form associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:DSL-ERROR-POSITION

Kinds: function

```text
Return the DSL source position associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:ELMTUI-CONDITION

Kinds: type

```text
Inspectable root for maintained ElmTUI framework conditions.

ELMTUI-INFORMATION, ELMTUI-WARNING, and ELMTUI-ERROR form the public severity
families. Subsystem conditions remain inspectable through their concrete type
while a handler on ELMTUI-CONDITION can observe the whole framework family.
```

## ELMTUI.CORE.ERRORS:ELMTUI-ERROR

Kinds: type

```text
Base error condition for ElmTUI failures.

Instances are intended to remain inspectable in the debugger: MESSAGE summarizes
the failure, CONTEXT carries machine-readable details, MODULE identifies the
subsystem, and SUGGESTIONS provides human-oriented remediation.  Signaling this
condition does not mutate application state; callers may establish handlers and
invoke restarts supplied around the signaling operation.
```

## ELMTUI.CORE.ERRORS:ELMTUI-ERROR-CONTEXT

Kinds: function

```text
Return the structured diagnostic context carried by CONDITION.
```

## ELMTUI.CORE.ERRORS:ELMTUI-ERROR-MESSAGE

Kinds: function

```text
Return the optional human-readable summary carried by CONDITION.
```

## ELMTUI.CORE.ERRORS:ELMTUI-ERROR-MODULE

Kinds: function

```text
Return the logical subsystem identifier carried by CONDITION.
```

## ELMTUI.CORE.ERRORS:ELMTUI-ERROR-SUGGESTIONS

Kinds: function

```text
Return the ordered recovery suggestions carried by CONDITION.
```

## ELMTUI.CORE.ERRORS:ELMTUI-INFORMATION

Kinds: type

```text
Base class for non-warning informational ElmTUI conditions.
```

## ELMTUI.CORE.ERRORS:ELMTUI-WARNING

Kinds: type

```text
Base class for ElmTUI warnings.
```

## ELMTUI.CORE.ERRORS:ERROR-WITH-CONTEXT

Kinds: function

```text
Signal an error with rich context information.
```

## ELMTUI.CORE.ERRORS:MAKE-ELMTUI-ERROR

Kinds: function

```text
Construct and return an inspectable ElmTUI condition of TYPE.

Arguments:
  TYPE is ELMTUI-ERROR or one of its subclasses. MESSAGE is an optional concise
  summary. CONTEXT is preserved as the caller supplied it, so structured
  plists/alists remain debugger-inspectable. SUGGESTIONS is normalized to a
  list. MODULE identifies the logical subsystem. Remaining keyword arguments
  are passed to MAKE-CONDITION for subclass-specific slots.

Returns:
  A condition object. The condition is not signaled by this function.

Mutation:
  None. Caller-owned CONTEXT and SUGGESTIONS are referenced, not modified.

Conditions:
  MAKE-CONDITION may signal an error when TYPE is unknown or required
  subclass initargs are missing. Those conditions propagate unchanged.

Example:
  (make-elmtui-error 'state-error
    :message "Counter state is invalid"
    :operation :update
    :path '(:counter :value)
    :state-type :plist
    :context '((:component-id . :counter)))
```

## ELMTUI.CORE.ERRORS:PLATFORM-ERROR

Kinds: type

```text
Base class for ElmTUI failures originating at a platform/backend boundary.
```

## ELMTUI.CORE.ERRORS:RUNTIME-ERROR

Kinds: type

```text
Base class for ElmTUI failures that occur during application/runtime execution.
```

## ELMTUI.CORE.ERRORS:STATE-ERROR

Kinds: type

```text
Runtime state access or mutation failure. Inspect STATE-ERROR-OPERATION, STATE-ERROR-PATH and STATE-ERROR-TYPE.
```

## ELMTUI.CORE.ERRORS:STATE-ERROR-OPERATION

Kinds: function

```text
Return the state operation associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:STATE-ERROR-PATH

Kinds: function

```text
Return the state path associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:STATE-ERROR-TYPE

Kinds: function

```text
Return the expected or observed state representation associated with CONDITION.
```

## ELMTUI.CORE.ERRORS:SUGGEST-FIXES

Kinds: function

```text
Create a list of suggested fixes for error messages.
```

## ELMTUI.CORE.ERRORS:WITH-ERROR-CONTEXT

Kinds: macro

```text
Annotate ElmTUI errors signaled by BODY without replacing the condition object.

CONTEXT, MODULE, OPERATION, COMPONENT-ID, and MACRO-ARG are evaluated once.  If
BODY signals ELMTUI-ERROR, the same condition object is enriched in place and
continues through the active condition machinery.  Preserving object identity
also preserves every subclass slot, debugger state, and restart association.

Existing structured context is retained.  Non-list context is wrapped as a
:CONTEXT entry before new entries are appended.  MODULE, when non-NIL, also
updates the condition's module slot.

Mutation: mutates only diagnostic slots of a signaled ELMTUI-ERROR; application
state is untouched.
Conditions: does not catch or suppress ELMTUI-ERROR.  The original condition
continues outward and remains available to HANDLER-BIND, the debugger, and
active restarts.

Example:
  (with-error-context (:module :renderer :operation :draw :component-id id)
    (render-component component))
```

## ELMTUI.CORE.EVENT-ASYNC:EVENT-PROMISE

Kinds: function

```text
Register a one-shot event handler on CHANNEL and return a small promise state.

This compatibility helper intentionally keeps the old API contract needed by
legacy regression tests: matching an event resolves once and unregisters the
handler from the channel. TIMEOUT is accepted for API compatibility; no timer is
started here because the current runtime no longer depends on this helper for
production async dispatch.
```

## ELMTUI.CORE.EVENT-CHANNELS:ADD-EVENT-FILTER

Kinds: function

```text
Add FN to CHAN's filter list and rebuild its underlying filtered channel; return CHAN.
```

## ELMTUI.CORE.EVENT-CHANNELS:CHANNEL-OF

Kinds: function

```text
Return the underlying CL-EVENTS channel owned by a typed EVENT-CHANNEL instance.
```

## ELMTUI.CORE.EVENT-CHANNELS:CHANNEL-PRIORITY

Kinds: function

```text
Return CHAN's :HIGH, :NORMAL, or :LOW priority.
```

## ELMTUI.CORE.EVENT-CHANNELS:COMMAND-CHANNEL

Kinds: type

```text
Command-Channel events.
```

## ELMTUI.CORE.EVENT-CHANNELS:EVENT-CHANNEL

Kinds: type

```text
Common superclass for all typed event channels.
```

## ELMTUI.CORE.EVENT-CHANNELS:FILTERS

Kinds: function

```text
Read or replace the channel wrapper's list of registered filter functions.
```

## ELMTUI.CORE.EVENT-CHANNELS:FOCUS-CHANNEL

Kinds: type

```text
Focus-Channel events.
```

## ELMTUI.CORE.EVENT-CHANNELS:HANDLERS

Kinds: function

```text
Read or replace the channel wrapper's registered handler list; handlers are not invoked automatically by RECEIVE-EVENT.
```

## ELMTUI.CORE.EVENT-CHANNELS:KEYBOARD-CHANNEL

Kinds: type

```text
Keyboard-Channel events.
```

## ELMTUI.CORE.EVENT-CHANNELS:MAKE-COMMAND-CHANNEL

Kinds: function

```text
Construct a typed command channel, forwarding keyword options such as :PRIORITY, :FILTERS and :CAPACITY.
```

## ELMTUI.CORE.EVENT-CHANNELS:MAKE-EVENT-CHANNEL

Kinds: function

```text
Low-level helper – CLASS is a subclass symbol of `event-channel'.
```

## ELMTUI.CORE.EVENT-CHANNELS:MAKE-FOCUS-CHANNEL

Kinds: function

```text
Construct a typed focus channel, forwarding keyword options such as :PRIORITY, :FILTERS and :CAPACITY.
```

## ELMTUI.CORE.EVENT-CHANNELS:MAKE-KEYBOARD-CHANNEL

Kinds: function

```text
Construct a typed keyboard channel, forwarding keyword options such as :PRIORITY, :FILTERS and :CAPACITY.
```

## ELMTUI.CORE.EVENT-CHANNELS:MAKE-MESSAGE-CHANNEL

Kinds: function

```text
Construct a typed message channel, forwarding keyword options such as :PRIORITY, :FILTERS and :CAPACITY.
```

## ELMTUI.CORE.EVENT-CHANNELS:MAKE-MOUSE-CHANNEL

Kinds: function

```text
Construct a typed mouse channel, forwarding keyword options such as :PRIORITY, :FILTERS and :CAPACITY.
```

## ELMTUI.CORE.EVENT-CHANNELS:MAKE-SYSTEM-CHANNEL

Kinds: function

```text
Construct a typed system channel, forwarding keyword options such as :PRIORITY, :FILTERS and :CAPACITY.
```

## ELMTUI.CORE.EVENT-CHANNELS:MAKE-UI-CHANNEL

Kinds: function

```text
Construct a typed UI channel, forwarding keyword options such as :PRIORITY, :FILTERS and :CAPACITY.
```

## ELMTUI.CORE.EVENT-CHANNELS:MESSAGE-CHANNEL

Kinds: type

```text
Message-Channel events.
```

## ELMTUI.CORE.EVENT-CHANNELS:MOUSE-CHANNEL

Kinds: type

```text
Mouse-Channel events.
```

## ELMTUI.CORE.EVENT-CHANNELS:NAME

Kinds: function

```text
Return the typed event channel's symbolic identifier.
```

## ELMTUI.CORE.EVENT-CHANNELS:PRIORITY

Kinds: function

```text
Read or replace the wrapper's dispatch priority, one of :HIGH, :NORMAL, or :LOW.
```

## ELMTUI.CORE.EVENT-CHANNELS:RECEIVE-EVENT

Kinds: function

```text
Receive an item from CHAN's underlying CL-EVENTS channel using the blocking receive operation.
```

## ELMTUI.CORE.EVENT-CHANNELS:REGISTER-EVENT-HANDLER

Kinds: function

```text
Push FN onto CHAN's registered handler list and return CHAN; this does not automatically dispatch received events.
```

## ELMTUI.CORE.EVENT-CHANNELS:REMOVE-EVENT-FILTER

Kinds: function

```text
Remove FN from CHAN's filter list and update the underlying filtered channel; return CHAN.
```

## ELMTUI.CORE.EVENT-CHANNELS:SEND-EVENT

Kinds: function

```text
Send EV into CHAN's underlying CL-EVENTS channel using its normal send operation.
```

## ELMTUI.CORE.EVENT-CHANNELS:SET-CHANNEL-PRIORITY

Kinds: function

```text
Set CHAN's symbolic priority to NEW and return the assigned value.
```

## ELMTUI.CORE.EVENT-CHANNELS:STANDARD-EVENT-CHANNELS

Kinds: function

```text
Return an alist (KEY . CHANNEL) for all built-ins.
```

## ELMTUI.CORE.EVENT-CHANNELS:SYSTEM-CHANNEL

Kinds: type

```text
System-Channel events.
```

## ELMTUI.CORE.EVENT-CHANNELS:TRY-RECEIVE-EVENT

Kinds: function

```text
Try to receive one event from CHAN, optionally waiting up to TIMEOUT seconds.

With NIL or zero TIMEOUT this performs exactly one non-blocking probe.  A
positive TIMEOUT repeatedly probes through CL-EVENTS.LOOP:POLL-UNTIL and returns
NIL when the deadline expires.  The event is consumed when returned.

Mutation: consumes at most one item from CHAN's underlying queue.
Conditions: channel/probe conditions are propagated unchanged; none are
silently converted to NIL.
```

## ELMTUI.CORE.EVENT-CHANNELS:UI-CHANNEL

Kinds: type

```text
Ui-Channel events.
```

## ELMTUI.CORE.EVENT-CHANNELS:UNREGISTER-EVENT-HANDLER

Kinds: function

```text
Remove FN from CHAN's registered handler list and return CHAN.
```

## ELMTUI.CORE.EVENT-CHANNELS:WAIT-FOR-EVENT

Kinds: function

```text
Wait for the first ready event from EVENT-CHANNELS.

Channels are stably ordered by PRIORITY before each wait: :HIGH, :NORMAL, then
:LOW.  Returns two values, EVENT and its EVENT-CHANNEL.  TIMEOUT is in seconds;
NIL waits indefinitely and zero performs one scan.

All repeated probing, deadline handling, and cooperative sleeping are delegated
to CL-EVENTS.LOOP:POLL-UNTIL so the runtime has one polling implementation.

Mutation: consumes exactly one queued event on success.
Conditions: channel/probe conditions propagate to the caller unchanged.
```

## ELMTUI.CORE.EVENT-PIPELINE:CONDITIONAL-PIPE

Kinds: type

```text
Pipe class selecting its THEN or ELSE nested pipe by calling the predicate in :CONDITION on each event.
```

## ELMTUI.CORE.EVENT-PIPELINE:FILTER-PIPE

Kinds: type

```text
Pipe class whose :FILTER function receives an event; a false value drops it and a true value retains the original event.
```

## ELMTUI.CORE.EVENT-PIPELINE:MAKE-PIPELINE

Kinds: function

```text
Construct a pipeline with an ordered list of PIPES and optional FALLTHROUGH flag, which defaults to true.
```

## ELMTUI.CORE.EVENT-PIPELINE:PIPE

Kinds: type

```text
Base class of event-processing pipes, specialized by filters, transformations, and conditional branches.
```

## ELMTUI.CORE.EVENT-PIPELINE:PIPELINE

Kinds: type

```text
An ordered event-processing pipeline with mutable PIPES and FALLTHROUGH slots.
```

## ELMTUI.CORE.EVENT-PIPELINE:PIPELINE-FALLTHROUGH

Kinds: function

```text
Read or set the pipeline's FALLTHROUGH flag controlling what happens when a stage returns NIL.
```

## ELMTUI.CORE.EVENT-PIPELINE:PIPELINE-PIPES

Kinds: function

```text
Read or set the ordered list of pipe objects processed by a pipeline.
```

## ELMTUI.CORE.EVENT-PIPELINE:PROCESS-EVENT

Kinds: function

```text
Run EVENT through each pipeline pipe in order. A stage returning NIL clears the event when FALLTHROUGH is true, otherwise processing returns NIL immediately.
```

## ELMTUI.CORE.EVENT-PIPELINE:TRANSFORM-PIPE

Kinds: type

```text
Pipe class whose :TRANSFORM function maps an incoming event to the next stage's value.
```

## ELMTUI.CORE.EVENT-TYPES:COMMAND-EVENT

Kinds: type

```text
Public command event type used to represent structured terminal events and commands.
```

## ELMTUI.CORE.EVENT-TYPES:COMMAND-EVENT-ARGS

Kinds: function

```text
Return the event args recorded in the command representation.
```

## ELMTUI.CORE.EVENT-TYPES:COMMAND-EVENT-NAME

Kinds: function

```text
Return the event name recorded in the command representation.
```

## ELMTUI.CORE.EVENT-TYPES:COMMAND-EVENT-P

Kinds: function

```text
Return true when the supplied value satisfies the command event type predicate.
```

## ELMTUI.CORE.EVENT-TYPES:COMMAND-EVENT-SOURCE

Kinds: function

```text
Return the event source recorded in the command representation.
```

## ELMTUI.CORE.EVENT-TYPES:COMMAND-EVENT-TIMESTAMP

Kinds: function

```text
Return the event timestamp recorded in the command representation.
```

## ELMTUI.CORE.EVENT-TYPES:CONVERT-LIST-TO-EVENT

Kinds: function

```text
Converts a list-format event to the appropriate struct format.
```

## ELMTUI.CORE.EVENT-TYPES:KEY-0

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: 0
```

## ELMTUI.CORE.EVENT-TYPES:KEY-1

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: 1
```

## ELMTUI.CORE.EVENT-TYPES:KEY-2

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: 2
```

## ELMTUI.CORE.EVENT-TYPES:KEY-3

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: 3
```

## ELMTUI.CORE.EVENT-TYPES:KEY-4

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: 4
```

## ELMTUI.CORE.EVENT-TYPES:KEY-5

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: 5
```

## ELMTUI.CORE.EVENT-TYPES:KEY-6

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: 6
```

## ELMTUI.CORE.EVENT-TYPES:KEY-7

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: 7
```

## ELMTUI.CORE.EVENT-TYPES:KEY-8

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: 8
```

## ELMTUI.CORE.EVENT-TYPES:KEY-9

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: 9
```

## ELMTUI.CORE.EVENT-TYPES:KEY-A

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: A
```

## ELMTUI.CORE.EVENT-TYPES:KEY-B

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: B
```

## ELMTUI.CORE.EVENT-TYPES:KEY-BACKSPACE

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: BACKSPACE
```

## ELMTUI.CORE.EVENT-TYPES:KEY-C

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: C
```

## ELMTUI.CORE.EVENT-TYPES:KEY-COMMA

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: COMMA
```

## ELMTUI.CORE.EVENT-TYPES:KEY-D

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: D
```

## ELMTUI.CORE.EVENT-TYPES:KEY-DELETE

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: DELETE
```

## ELMTUI.CORE.EVENT-TYPES:KEY-DOWN

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: ARROW-DOWN
```

## ELMTUI.CORE.EVENT-TYPES:KEY-E

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: E
```

## ELMTUI.CORE.EVENT-TYPES:KEY-END

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: END
```

## ELMTUI.CORE.EVENT-TYPES:KEY-ENTER

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: ENTER
```

## ELMTUI.CORE.EVENT-TYPES:KEY-EQUALS

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: EQUALS
```

## ELMTUI.CORE.EVENT-TYPES:KEY-ESCAPE

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: ESCAPE
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F1

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F1
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F10

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F10
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F11

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F11
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F12

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F12
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F2

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F2
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F3

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F3
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F4

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F4
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F5

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F5
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F6

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F6
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F7

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F7
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F8

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F8
```

## ELMTUI.CORE.EVENT-TYPES:KEY-F9

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: F9
```

## ELMTUI.CORE.EVENT-TYPES:KEY-G

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: G
```

## ELMTUI.CORE.EVENT-TYPES:KEY-H

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: H
```

## ELMTUI.CORE.EVENT-TYPES:KEY-HOME

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: HOME
```

## ELMTUI.CORE.EVENT-TYPES:KEY-I

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: I
```

## ELMTUI.CORE.EVENT-TYPES:KEY-INSERT

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: INSERT
```

## ELMTUI.CORE.EVENT-TYPES:KEY-J

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: J
```

## ELMTUI.CORE.EVENT-TYPES:KEY-K

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: K
```

## ELMTUI.CORE.EVENT-TYPES:KEY-L

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: L
```

## ELMTUI.CORE.EVENT-TYPES:KEY-LEFT

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: ARROW-LEFT
```

## ELMTUI.CORE.EVENT-TYPES:KEY-LEFT-BRACKET

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: LEFT-BRACKET
```

## ELMTUI.CORE.EVENT-TYPES:KEY-M

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: M
```

## ELMTUI.CORE.EVENT-TYPES:KEY-MINUS

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: MINUS
```

## ELMTUI.CORE.EVENT-TYPES:KEY-N

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: N
```

## ELMTUI.CORE.EVENT-TYPES:KEY-O

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: O
```

## ELMTUI.CORE.EVENT-TYPES:KEY-P

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: P
```

## ELMTUI.CORE.EVENT-TYPES:KEY-PAGE-DOWN

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: PAGE-DOWN
```

## ELMTUI.CORE.EVENT-TYPES:KEY-PAGE-UP

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: PAGE-UP
```

## ELMTUI.CORE.EVENT-TYPES:KEY-PERIOD

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: PERIOD
```

## ELMTUI.CORE.EVENT-TYPES:KEY-Q

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: Q
```

## ELMTUI.CORE.EVENT-TYPES:KEY-QUOTE

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: QUOTE
```

## ELMTUI.CORE.EVENT-TYPES:KEY-R

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: R
```

## ELMTUI.CORE.EVENT-TYPES:KEY-RIGHT

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: ARROW-RIGHT
```

## ELMTUI.CORE.EVENT-TYPES:KEY-RIGHT-BRACKET

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: RIGHT-BRACKET
```

## ELMTUI.CORE.EVENT-TYPES:KEY-S

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: S
```

## ELMTUI.CORE.EVENT-TYPES:KEY-SEMICOLON

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: SEMICOLON
```

## ELMTUI.CORE.EVENT-TYPES:KEY-SLASH

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: SLASH
```

## ELMTUI.CORE.EVENT-TYPES:KEY-SPACE

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: SPACE
```

## ELMTUI.CORE.EVENT-TYPES:KEY-T

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: T
```

## ELMTUI.CORE.EVENT-TYPES:KEY-TAB

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: TAB
```

## ELMTUI.CORE.EVENT-TYPES:KEY-U

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: U
```

## ELMTUI.CORE.EVENT-TYPES:KEY-UP

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: ARROW-UP
```

## ELMTUI.CORE.EVENT-TYPES:KEY-V

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: V
```

## ELMTUI.CORE.EVENT-TYPES:KEY-W

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: W
```

## ELMTUI.CORE.EVENT-TYPES:KEY-X

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: X
```

## ELMTUI.CORE.EVENT-TYPES:KEY-Y

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: Y
```

## ELMTUI.CORE.EVENT-TYPES:KEY-Z

Kinds: variable

```text
Key constant generated by DEFINE-KEY-CONSTANTS: Z
```

## ELMTUI.CORE.EVENT-TYPES:MAKE-COMMAND-EVENT

Kinds: function

```text
Construct a command event structure from its provided initialization fields.
```

## ELMTUI.CORE.EVENT-TYPES:MAKE-SYSTEM-EVENT

Kinds: function

```text
Construct a system event structure from its provided initialization fields.
```

## ELMTUI.CORE.EVENT-TYPES:MAKE-TIMER-EVENT

Kinds: function

```text
Construct a timer event structure from its provided initialization fields.
```

## ELMTUI.CORE.EVENT-TYPES:MAKE-WINDOW-EVENT

Kinds: function

```text
Construct a window event structure from its provided initialization fields.
```

## ELMTUI.CORE.EVENT-TYPES:NORMALIZE-FOCUS-EVENT

Kinds: function

```text
Converts platform-specific focus event to a standardized focus-event.
   PLATFORM-EVENT: The raw event from the platform layer.
```

## ELMTUI.CORE.EVENT-TYPES:NORMALIZE-KEY-EVENT

Kinds: function

```text
Converts platform-specific keyboard event to a standardized key-event.
   PLATFORM-EVENT: The raw event from the platform layer.
```

## ELMTUI.CORE.EVENT-TYPES:NORMALIZE-MOUSE-EVENT

Kinds: function

```text
Converts platform-specific mouse event to a standardized mouse-event.
   PLATFORM-EVENT: The raw event from the platform layer.
```

## ELMTUI.CORE.EVENT-TYPES:SYSTEM-EVENT

Kinds: type

```text
Public system event type used to represent structured terminal events and commands.
```

## ELMTUI.CORE.EVENT-TYPES:SYSTEM-EVENT-DATA

Kinds: function

```text
Return the data recorded in the system event representation.
```

## ELMTUI.CORE.EVENT-TYPES:SYSTEM-EVENT-P

Kinds: function

```text
Return true when the supplied value satisfies the system event type predicate.
```

## ELMTUI.CORE.EVENT-TYPES:SYSTEM-EVENT-TIMESTAMP

Kinds: function

```text
Return the timestamp recorded in the system event representation.
```

## ELMTUI.CORE.EVENT-TYPES:SYSTEM-EVENT-TYPE

Kinds: function

```text
Return the type recorded in the system event representation.
```

## ELMTUI.CORE.EVENT-TYPES:TIMER-EVENT

Kinds: type

```text
Public timer event type used to represent structured terminal events and commands.
```

## ELMTUI.CORE.EVENT-TYPES:TIMER-EVENT-ID

Kinds: function

```text
Return the id recorded in the timer event representation.
```

## ELMTUI.CORE.EVENT-TYPES:TIMER-EVENT-P

Kinds: function

```text
Return true when the supplied value satisfies the timer event type predicate.
```

## ELMTUI.CORE.EVENT-TYPES:TIMER-EVENT-TIMESTAMP

Kinds: function

```text
Return the timestamp recorded in the timer event representation.
```

## ELMTUI.CORE.EVENT-TYPES:TIMER-EVENT-USER-DATA

Kinds: function

```text
Return the user data recorded in the timer event representation.
```

## ELMTUI.CORE.EVENT-TYPES:VALID-KEY-EVENT-P

Kinds: function

```text
Returns true if EVENT is a valid key-event structure.
```

## ELMTUI.CORE.EVENT-TYPES:VALID-MOUSE-EVENT-P

Kinds: function

```text
Returns true if EVENT is a valid mouse-event structure.
```

## ELMTUI.CORE.EVENT-TYPES:WINDOW-EVENT

Kinds: type

```text
Public window event type used to represent structured terminal events and commands.
```

## ELMTUI.CORE.EVENT-TYPES:WINDOW-EVENT-HEIGHT

Kinds: function

```text
Return the height recorded in the window event representation.
```

## ELMTUI.CORE.EVENT-TYPES:WINDOW-EVENT-P

Kinds: function

```text
Return true when the supplied value satisfies the window event type predicate.
```

## ELMTUI.CORE.EVENT-TYPES:WINDOW-EVENT-TIMESTAMP

Kinds: function

```text
Return the timestamp recorded in the window event representation.
```

## ELMTUI.CORE.EVENT-TYPES:WINDOW-EVENT-TYPE

Kinds: function

```text
Return the type recorded in the window event representation.
```

## ELMTUI.CORE.EVENT-TYPES:WINDOW-EVENT-WIDTH

Kinds: function

```text
Return the width recorded in the window event representation.
```

## ELMTUI.CORE.EVENTS:*AFTER-SEND-MESSAGE-HOOKS*

Kinds: variable

```text
A list of functions to be called after a message has been processed by SEND-MESSAGE.
Each hook function should accept the target and the message as arguments.
```

## ELMTUI.CORE.EVENTS:*BEFORE-SEND-MESSAGE-HOOKS*

Kinds: variable

```text
A list of functions to be called before a message is sent via SEND-MESSAGE.
Each hook function should accept the target and the message as arguments.
```

## ELMTUI.CORE.EVENTS:*MESSAGE-CONTRACTS*

Kinds: variable

```text
Registry of message contracts for validation and documentation.
```

## ELMTUI.CORE.EVENTS:ADD-AFTER-SEND-MESSAGE-HOOK

Kinds: function

```text
Adds HOOK-FN to the list of hooks executed after sending a message.
```

## ELMTUI.CORE.EVENTS:ADD-BEFORE-SEND-MESSAGE-HOOK

Kinds: function

```text
Adds HOOK-FN to the list of hooks executed before sending a message.
```

## ELMTUI.CORE.EVENTS:CMD

Kinds: type

```text
A command for side-effects: (:async FUNCTION ARGS...) or (:batch [CMDS]).
   Contract: type ∈ :async|:batch|…; args ∈ list.
```

## ELMTUI.CORE.EVENTS:DESERIALIZE-MESSAGE

Kinds: function

```text
Deserializes a property list representation back into a message object.
   Expects a plist like '(:type <type> :data "<serialized-data-string>").
   Returns a new message object or NIL if deserialization fails and is not recovered.
```

## ELMTUI.CORE.EVENTS:LOG-MESSAGE

Kinds: function

```text
Log MSG with tracing for message flows.
```

## ELMTUI.CORE.EVENTS:MAKE-CMD

Kinds: function

_No documentation metadata._

## ELMTUI.CORE.EVENTS:PROPAGATION-STOPPED-P

Kinds: function

_No documentation metadata._

## ELMTUI.CORE.EVENTS:REGISTER-MESSAGE-CONTRACT

Kinds: macro

```text
Register CONTRACT-FN as the explicit validation contract for TYPE.
PRIORITY is deprecated and ignored for source compatibility. Message priority is
owned exclusively by CL-EVENTS.PROTOCOLS:MESSAGE-PRIORITY on message values.
```

## ELMTUI.CORE.EVENTS:REMOVE-AFTER-SEND-MESSAGE-HOOK

Kinds: function

```text
Removes HOOK-FN from the list of hooks executed after sending a message.
```

## ELMTUI.CORE.EVENTS:REMOVE-BEFORE-SEND-MESSAGE-HOOK

Kinds: function

```text
Removes HOOK-FN from the list of hooks executed before sending a message.
```

## ELMTUI.CORE.EVENTS:SEND-MESSAGE

Kinds: function

```text
Send MSG to TARGET using the on-message protocol.
   Validates, logs the message, and calls lifecycle hooks. Handles validation and dispatch errors.
```

## ELMTUI.CORE.EVENTS:SERIALIZE-MESSAGE

Kinds: function

```text
Serializes a message object into a property list.
   Focuses on :type and :data. Other slots (state, handles) are lost.
   Returns a plist like '(:type <type> :data "<serialized-data-string>") or NIL if serialization fails and is not recovered.
```

## ELMTUI.CORE.EVENTS:VALIDATE-MESSAGE

Kinds: function

```text
Validate MSG against its explicit contract or its schema from DEFMSG.
   Signals message-validation-error if invalid.
```

## ELMTUI.CORE.FOCUS:ACTIVATE-FOCUS-CONTEXT

Kinds: function

```text
Activate a focus context in the focus manager.
   Saves current focus to the outgoing context's last-focus.
   Restores focus from the incoming context's last-focus if available.
```

## ELMTUI.CORE.FOCUS:CLEAR-FOCUS

Kinds: function

```text
Clears the current focus.
```

## ELMTUI.CORE.FOCUS:COLLECT-FOCUSABLE-ELEMENTS

Kinds: function

```text
Traverses the UI tree and collects all elements that are focusable.
   Supports legacy plist nodes and Hiccup-style (type props . children) nodes.
```

## ELMTUI.CORE.FOCUS:COLLECT-FOCUSABLE-IDS

Kinds: function

```text
Traverses the UI tree and collects IDs of all elements that are focusable.
   Returns a list of element IDs that can receive focus.
```

## ELMTUI.CORE.FOCUS:FIND-COMPONENT-KEYMAP-CONTEXT

Kinds: function

```text
Find or create a keymap context for a component.
   CONTROLS keymap activation based on widget model keymap definitions.
```

## ELMTUI.CORE.FOCUS:FOCUS-MANAGER

Kinds: type

```text
Manages focus state and navigation in the application.
```

## ELMTUI.CORE.FOCUS:FOCUS-MANAGER-ACTIVE-FOCUS-CONTEXT

Kinds: function

```text
Return or set the identifier of the currently active focus context, or NIL.
```

## ELMTUI.CORE.FOCUS:FOCUS-MANAGER-CONTEXT-DATA

Kinds: function

```text
Return the focus manager's hash table mapping context identifiers to stored focus-context records.
```

## ELMTUI.CORE.FOCUS:FOCUS-MANAGER-CURRENT-FOCUS

Kinds: function

```text
Return or set the identifier of the currently focused widget, or NIL.
```

## ELMTUI.CORE.FOCUS:FOCUS-MANAGER-FOCUS-HISTORY

Kinds: function

```text
Return or replace the focus manager's stack of previously focused widget identifiers.
```

## ELMTUI.CORE.FOCUS:FOCUS-MANAGER-FOCUS-RING-DIRTY-P

Kinds: function

```text
Return or set whether the cached focusable widget ring must be recalculated.
```

## ELMTUI.CORE.FOCUS:FOCUS-MANAGER-FOCUSABLE-ELEMENTS

Kinds: function

```text
Return or set the ordered list of focusable widget identifiers used by focus traversal.
```

## ELMTUI.CORE.FOCUS:FOCUS-PREVIOUS-FROM-HISTORY

Kinds: function

```text
Sets focus to the previous element in the focus history.
```

## ELMTUI.CORE.FOCUS:GET-CONTEXT-LAST-FOCUS

Kinds: function

```text
Returns the last known focused element ID for the given context-id.
```

## ELMTUI.CORE.FOCUS:GET-CURRENT-FOCUS

Kinds: function

```text
Returns the ID of the currently focused element.
```

## ELMTUI.CORE.FOCUS:GET-NEXT-FOCUSABLE

Kinds: function

```text
Returns the ID of the next focusable element after CURRENT-ID.
   If CURRENT-ID is nil or not found, returns the first focusable element.
   Wraps around to the beginning if at the end.
```

## ELMTUI.CORE.FOCUS:GET-PREVIOUS-FOCUSABLE

Kinds: function

```text
Returns the ID of the previous focusable element before CURRENT-ID.
   If CURRENT-ID is nil or not found, returns the last focusable element.
   Wraps around to the end if at the beginning.
```

## ELMTUI.CORE.FOCUS:HANDLE-DEFAULT-NAVIGATION-KEYS

Kinds: function

```text
Handle standard navigation keys including arrows, tab, escape, etc.
   Provides a comprehensive set of default navigation behaviors.
   Returns T if the event was handled, NIL otherwise.
```

## ELMTUI.CORE.FOCUS:HANDLE-FOCUS-MESSAGE

Kinds: function

```text
Handles focus-related messages.
   Returns a plist describing the state changes to be made, or NIL if no changes.
   This function now operates directly on the focus-manager instance passed to it,
   and expects app-state for context when calling set-focus or other operations
   that might interact with the broader application state (e.g., component-gained/lost-focus hooks).
   It returns T if a message was handled and resulted in a change, NIL otherwise.
```

## ELMTUI.CORE.FOCUS:HANDLE-KEY-EVENT-FOR-COMPONENT

Kinds: function

```text
Handle a key event for a specific component.
   Returns T if the event was handled, NIL otherwise.
```

## ELMTUI.CORE.FOCUS:HANDLE-NAVIGATION-KEYS

Kinds: function

```text
Handle standard navigation keys like arrows, etc.
   UI-TREE is passed down for directional navigation.
```

## ELMTUI.CORE.FOCUS:HANDLE-TAB-NAVIGATION

Kinds: function

```text
Handles Tab and Shift+Tab navigation events.
```

## ELMTUI.CORE.FOCUS:LIST-ACTIVE-KEYBINDINGS

Kinds: function

```text
List all active keybindings for a component or globally.
   Returns a list of plists with :key, :description, :type and :source fields.
```

## ELMTUI.CORE.FOCUS:MAKE-FOCUS-MANAGER

Kinds: function

```text
Create a new focus manager.
   INITIAL-FOCUS: The ID of the element to focus initially.
   INITIAL-CONTEXT-IDS: A list of context IDs to register initially.
   INITIAL-ACTIVE-CONTEXT: The ID of the context to make active initially.
```

## ELMTUI.CORE.FOCUS:NAVIGATE-DOWN

Kinds: function

```text
Navigate focus downward.
```

## ELMTUI.CORE.FOCUS:NAVIGATE-LEFT

Kinds: function

```text
Navigate focus to the left.
```

## ELMTUI.CORE.FOCUS:NAVIGATE-RIGHT

Kinds: function

```text
Navigate focus to the right.
```

## ELMTUI.CORE.FOCUS:NAVIGATE-UP

Kinds: function

```text
Navigate focus upward.
```

## ELMTUI.CORE.FOCUS:RECALCULATE-FOCUSABLE-ELEMENTS

Kinds: function

```text
Recalculates the list of focusable elements based on the current UI tree.
   Returns the updated list. If preserve-focus is T, tries to maintain current focus.
   If the current focus is no longer valid, either clears focus or sets to the first element.
```

## ELMTUI.CORE.FOCUS:REGISTER-FOCUS-CONTEXT

Kinds: function

```text
Register a new focus context with the focus manager.
```

## ELMTUI.CORE.FOCUS:REQUEST-FOCUS

Kinds: function

```text
Requests focus for a specific element.
   When used with app-state, sets focus immediately.
```

## ELMTUI.CORE.FOCUS:SET-FOCUS

Kinds: function

```text
Set focus to ELEMENT-ID. Notifies the focused component and keymap system.
   Also updates the last-focus for the active context.
```

## ELMTUI.CORE.FOCUS:TAB-NAVIGATE

Kinds: function

```text
Navigate through focusable elements using Tab key.
   DIRECTION can be :forward or :backward.
```

## ELMTUI.CORE.GLOBALS:*APP-MESSAGE-PROCESSOR*

Kinds: variable

```text
Holds the function (message app-state) to process application messages.
```

## ELMTUI.CORE.GLOBALS:*APP-SENDER*

Kinds: variable

```text
Holds the function (e.g., #'elmtui.core.loop:publish) to send messages into the TEA loop.
```

## ELMTUI.CORE.GLOBALS:*APP-STATE*

Kinds: variable

```text
The current application state (ut.state:application-state instance).
```

## ELMTUI.CORE.GLOBALS:*APPLICATIONS*

Kinds: variable

```text
Hash table of registered applications, keyed by their names.
```

## ELMTUI.CORE.GLOBALS:*CONFIG*

Kinds: variable

```text
Global configuration settings.
```

## ELMTUI.CORE.GLOBALS:*CURRENT-BACKEND*

Kinds: variable

```text
The active platform backend instance.
```

## ELMTUI.CORE.GLOBALS:*CURRENT-PROGRAM*

Kinds: variable

```text
The top-level program or application object.
```

## ELMTUI.CORE.GLOBALS:*DEBUG-LAYOUT-OUTLINES*

Kinds: variable

```text
If T, enables layout outlines for debugging purposes.
   This is typically used to visualize widget boundaries and layout structures.
```

## ELMTUI.CORE.GLOBALS:*DEBUG-MODE*

Kinds: variable

```text
Enable extensive debugging output if T.
```

## ELMTUI.CORE.GLOBALS:*EVENT-LOOP*

Kinds: variable

```text
The main event loop instance (legacy).
```

## ELMTUI.CORE.GLOBALS:*FOCUS-MANAGER*

Kinds: variable

```text
The active focus manager instance.
```

## ELMTUI.CORE.GLOBALS:*KEYMAP-REGISTRY*

Kinds: variable

```text
The global keymap registry.
```

## ELMTUI.CORE.GLOBALS:*MAIN-EVENT-CHANNEL*

Kinds: variable

```text
The main channel for TEA-style event/message processing.
```

## ELMTUI.CORE.GLOBALS:*MESSAGE-SCHEMAS*

Kinds: variable

```text
Global registry for message types and their variants defined by defmsg.
```

## ELMTUI.CORE.GLOBALS:*STYLESHEETS*

Kinds: variable

_No documentation metadata._

## ELMTUI.CORE.GLOBALS:*SUBSCRIBERS*

Kinds: variable

```text
Hash table for legacy event subscribers.
```

## ELMTUI.CORE.GLOBALS:*THEME*

Kinds: variable

```text
Global theme settings.
```

## ELMTUI.CORE.LOGGING:SETUP-UI-LOGGERS

Kinds: function

```text
Create one logger per SUBSYSTEM and attach a dedicated FILE-APPENDER to each.

Arguments
---------
DIRECTORY   ― pathname designator for the log directory
SUBSYSTEMS  ― list of symbols naming logical UI areas
LEVEL       ― minimum sever­ity accepted by every subsystem logger
LAYOUT      ― `:simple` or `:pattern` (cf. LOG4CL manual)

Return value
------------
An alist of (SUBSYSTEM . LOGGER) pairs for convenient programmatic use.

Calling this function repeatedly REPLACES all appenders of already-existing
loggers, so you can reconfigure at runtime (e.g. switch on DEBUG).
```

## ELMTUI.CORE.LOGGING:SUBSYSTEM-LOGGER

Kinds: function

```text
Return the logger object for SUBSYSTEM (a keyword or string).

If the logger does not exist yet, it is *created on demand* **without**
any appenders.  Call `SETUP-UI-LOGGERS` first if you want automatic
file appenders.
```

## ELMTUI.CORE.LOGGING:WITH-SUBSYSTEM-LOGGER

Kinds: macro

````text
Execute BODY with *logger* rebound to the SUBSYSTEM logger.

Example
-------
```lisp
(with-subsystem-logger :rendering
  (log:debug "Drawing the main canvas"))
```
````

## ELMTUI.CORE.LOOP:*CONSUMER-THREAD*

Kinds: variable

```text
Thread for consuming events from *active-event-channels*
- consumer is the dequeuing events/messages and running the update function
as well as the view function for the application.
```

## ELMTUI.CORE.LOOP:AS-PLIST

Kinds: function

```text
Convert a style object to a property list.
```

## ELMTUI.CORE.LOOP:ELM-STOP-LOOP

Kinds: function

```text
Close the mailbox to wake blocked readers, then reap the consumer if external.
Safe after an earlier shutdown request and safe from the consumer itself.
```

## ELMTUI.CORE.LOOP:GET-EVENT-LOOP-STATUS

Kinds: function

```text
Get the current status of the event loop.
```

## ELMTUI.CORE.LOOP:GET-EVENT-QUEUE-LENGTH

Kinds: function

```text
Get the sum of approximate queue lengths of all active event channels.
```

## ELMTUI.CORE.LOOP:INSTRUMENT-EVENT-LOOP

Kinds: function

```text
Instrumentation hook for debugging/profiling.
```

## ELMTUI.CORE.LOOP:PUBLISH

Kinds: function

```text
Publish EVENT to TARGET-CHANNEL-NAME (keyword or string).
Returns T on success, NIL on drop. Safe after shutdown.
```

## ELMTUI.CORE.LOOP:START-LOOP

Kinds: function

```text
Initialize and start the main event loop using the channel-based system.
```

## ELMTUI.CORE.LOOP:SUBSCRIBE

Kinds: function

```text
Subscribe a HANDLER to a specific EVENT-TYPE.
   EVENT-TYPE should be a keyword matching a channel name.
```

## ELMTUI.CORE.SYSTEM-EVENTS:MAKE-APPSHUTDOWN-SYSTEMEVENT

Kinds: function

_No documentation metadata._

## ELMTUI.CORE.SYSTEM-EVENTS:MAKE-CURSORPOSITION-SYSTEMEVENT

Kinds: function

_No documentation metadata._

## ELMTUI.CORE.SYSTEM-EVENTS:MAKE-TERMINALRESIZED-SYSTEMEVENT

Kinds: function

_No documentation metadata._

## ELMTUI.CORE.THREADS:COND-MESSAGE

Kinds: function

```text
Get the message from a condition object.
```

## ELMTUI.CORE.THREADS:WITH-INTERRUPTABLE-SIGNAL

Kinds: macro

```text
Spawn a background thread running BODY.  RETURN-VAR is a user-supplied symbol,
initialized to NIL; you can (SETF RETURN-VAR …) anywhere in BODY to record progress
or final result.  Defines a global function SIGNAL-FN which, when called, will:

 1. interrupt the thread,
 2. throw a tag 'interrupt carrying the current RETURN-VAR,
 3. return that RETURN-VAR to the caller of SIGNAL-FN.

The macro expands to evaluating to the thread object itself.
```

## ELMTUI.CORE.TOPIC-REGISTRY:CLEAR-REGISTRY

Kinds: function

```text
Clear global topic and channel subscriptions, reset the subscription identifier counter, and return true.
```

## ELMTUI.CORE.TOPIC-REGISTRY:DISPATCH-TOPIC

Kinds: function

```text
Call all handlers matching TOPIC with MESSAGE; when APP-STATE is non-NIL, pass it as a second argument. Return collected handler results.
```

## ELMTUI.CORE.TOPIC-REGISTRY:FIND-HANDLERS-FOR-TOPIC

Kinds: function

```text
Return matching topic handler functions in their priority-sorted dispatch order.
```

## ELMTUI.CORE.TOPIC-REGISTRY:FIND-SUBSCRIPTIONS-FOR-TOPIC

Kinds: function

```text
Return matching subscription tokens for TOPIC-NAME, stably ordered with :HIGH first, then :NORMAL and :LOW.
```

## ELMTUI.CORE.TOPIC-REGISTRY:GET-ALL-SUBSCRIPTIONS

Kinds: function

```text
Return an alist mapping each subscribed topic pattern to its registered handler functions.
```

## ELMTUI.CORE.TOPIC-REGISTRY:GET-CHANNEL-SUBSCRIPTIONS

Kinds: function

```text
Return an alist of topic patterns and channel subscription objects for CHANNEL-ID.
```

## ELMTUI.CORE.TOPIC-REGISTRY:GET-TOPICS-WITH-SUBSCRIBERS

Kinds: function

```text
Return distinct topic patterns subscribed through either topic or channel registries, sorted by printed representation.
```

## ELMTUI.CORE.TOPIC-REGISTRY:LIST-SUBSCRIPTIONS

Kinds: function

```text
Return topic subscription tokens for PATTERN, or tokens for all patterns if PATTERN is NIL. Does not include channel subscriptions.
```

## ELMTUI.CORE.TOPIC-REGISTRY:PUBLISH

Kinds: function

```text
Publish MESSAGE to handlers matching TOPIC-NAME, collecting each handler's return value; alias of PUBLISH-TO-TOPIC.
```

## ELMTUI.CORE.TOPIC-REGISTRY:PUBLISH-TO-CHANNEL

Kinds: function

```text
Call active handlers for TOPIC matching CHANNEL-ID and collect their return values; channel identifiers compare with EQL.
```

## ELMTUI.CORE.TOPIC-REGISTRY:PUBLISH-TO-TOPIC

Kinds: function

```text
Call all topic handlers matching TOPIC-NAME in priority order, collecting and returning each result.
```

## ELMTUI.CORE.TOPIC-REGISTRY:SUBSCRIBE

Kinds: function

```text
Subscribe HANDLER to PATTERN and return an unsubscribe token.
```

## ELMTUI.CORE.TOPIC-REGISTRY:SUBSCRIBE-IF

Kinds: function

```text
Subscribe HANDLER to PATTERN, guarded by PREDICATE-FN.
```

## ELMTUI.CORE.TOPIC-REGISTRY:SUBSCRIBE-TO-TOPIC-ON-CHANNEL

Kinds: function

```text
Register HANDLER-FN for TOPIC and CHANNEL-ID; return a channel subscription object for later removal.
```

## ELMTUI.CORE.TOPIC-REGISTRY:SUBSCRIPTION-COUNT

Kinds: function

```text
Return the total number of registrations across the topic subscription and channel subscription tables.
```

## ELMTUI.CORE.TOPIC-REGISTRY:SUBSCRIPTION-INFO

Kinds: function

```text
Return plists with :ID, :PATTERN, and :PRIORITY for topic subscriptions, optionally filtered by PATTERN.
```

## ELMTUI.CORE.TOPIC-REGISTRY:UNSUBSCRIBE

Kinds: function

```text
Remove a topic subscription using the token returned by SUBSCRIBE and return true, including when already absent.
```

## ELMTUI.CORE.TOPIC-REGISTRY:UNSUBSCRIBE-FROM-CHANNEL

Kinds: function

```text
Remove the supplied channel subscription object from its topic and channel pair; return true.
```

## ELMTUI.CORE.TOPICS:FIND-TOPIC

Kinds: function

```text
Look up NAME in the process-wide topic registry and return the registered topic or NIL.
```

## ELMTUI.CORE.TOPICS:FIND-TOPICS-BY-PATTERN

Kinds: function

```text
Return registered topic objects whose segment paths match PATTERN, including wildcard segments.
```

## ELMTUI.CORE.TOPICS:LIST-TOPICS

Kinds: function

```text
Return the currently registered topic objects in hash-table traversal order; no ordering is guaranteed.
```

## ELMTUI.CORE.TOPICS:MAKE-TOPIC

Kinds: function

```text
Construct a topic with NAME, optional PARENT and DESCRIPTION. Also adds the new topic to its parent's children, but does not register it.
```

## ELMTUI.CORE.TOPICS:MAKE-TOPIC-SUBSCRIPTION

Kinds: function

```text
Construct a subscription holding PATTERN, HANDLER, and optional priority of :HIGH, :NORMAL, or :LOW.
```

## ELMTUI.CORE.TOPICS:REGISTER-TOPIC

Kinds: function

```text
Register TOPIC globally by its topic name, replacing any prior entry under that name, and return TOPIC.
```

## ELMTUI.CORE.TOPICS:TOPIC

Kinds: type

```text
Topic structure containing a symbol or string name, optional parent, child list, and optional description.
```

## ELMTUI.CORE.TOPICS:TOPIC-ANCESTORS

Kinds: function

```text
Return TOPIC's parents from nearest to farthest; return NIL for a root topic.
```

## ELMTUI.CORE.TOPICS:TOPIC-CHILDREN

Kinds: function

```text
Return the list of immediate child topics; making a topic with a parent adds to this list.
```

## ELMTUI.CORE.TOPICS:TOPIC-DESCENDANTS

Kinds: function

```text
Return all child topic objects recursively. Immediate children appear before recursively visited descendants.
```

## ELMTUI.CORE.TOPICS:TOPIC-DESCRIPTION

Kinds: function

```text
Return TOPIC's optional descriptive string, or NIL if no description was supplied.
```

## ELMTUI.CORE.TOPICS:TOPIC-MATCH-P

Kinds: function

```text
Return true if TOPIC1 is TOPIC2 or a descendant of TOPIC2, using object identity for ancestry.
```

## ELMTUI.CORE.TOPICS:TOPIC-NAME

Kinds: function

```text
Return the topic's original symbol or string name.
```

## ELMTUI.CORE.TOPICS:TOPIC-PARENT

Kinds: function

```text
Return TOPIC's parent topic object or NIL for a root.
```

## ELMTUI.CORE.TOPICS:TOPIC-PATH

Kinds: function

```text
Return topic name segments from the root through TOPIC. A root string containing slashes is split into path segments.
```

## ELMTUI.CORE.TOPICS:TOPIC-PATTERN-MATCH-P

Kinds: function

```text
Match PATTERN against TOPIC by case-insensitive path segments; * matches one segment and # matches the remaining suffix, including an empty suffix.
```

## ELMTUI.CORE.TOPICS:TOPIC-SUBSCRIPTION

Kinds: type

```text
Subscription structure containing a pattern, a handler function, and a :HIGH, :NORMAL, or :LOW priority.
```

## ELMTUI.CORE.TOPICS:TOPIC-SUBSCRIPTION-HANDLER

Kinds: function

```text
Return the handler function stored in a topic subscription.
```

## ELMTUI.CORE.TOPICS:TOPIC-SUBSCRIPTION-PATTERN

Kinds: function

```text
Return the string or symbol pattern matched by a topic subscription.
```

## ELMTUI.CORE.TOPICS:TOPIC-SUBSCRIPTION-PRIORITY

Kinds: function

```text
Return a subscription's dispatch priority, one of :HIGH, :NORMAL, or :LOW.
```

## ELMTUI.DEV:BUFFER->STRING

Kinds: function

```text
Return BUFFER as plain text without writing to *STANDARD-OUTPUT*.
```

## ELMTUI.DEV:DEV-MAIN

Kinds: function

```text
Print and return a current runtime snapshot.
```

## ELMTUI.DEV:FORMAT-ELEMENT-TREE

Kinds: function

```text
Render a compact textual view of a lowered BASE-ELEMENT tree.
ROOT may be one BASE-ELEMENT or a list of sibling elements.  Layout coordinates
are included when available; INCLUDE-STYLE adds the resolved style plist.
```

## ELMTUI.DEV:FORMAT-RUNTIME-SNAPSHOT

Kinds: function

```text
Format SNAPSHOT returned by RUNTIME-SNAPSHOT for interactive REPL use.
```

## ELMTUI.DEV:RUNTIME-SNAPSHOT

Kinds: function

```text
Return a side-effect-free snapshot of the maintained runtime diagnostics.
```

## ELMTUI.DEV:WITH-BUFFER-DUMP

Kinds: macro

```text
Run BODY and print BUFFER to *ERROR-OUTPUT* before entering the debugger on error.
```

## ELMTUI.DOCS:BUILD-API-DOCS

Kinds: function

```text
Write live-symbol Markdown and HTML references with public export paths.

Returns two values: API Markdown and HTML paths. The documents explicitly
report missing metadata, and document text is fenced/escaped as literal text.
```

## ELMTUI.DOCS:DOCSTRING-AUDIT

Kinds: function

```text
Return current public API documentation coverage.

Arguments:
  None.

Returns:
  Three values: total public bindings, bindings without documentation metadata,
  and a fresh alist mapping home package names to missing counts.

Mutation:
  None outside temporary result allocation.

Conditions:
  Propagates conditions from PUBLIC-API-BINDINGS.

Example:
  (multiple-value-bind (total missing packages) (docstring-audit)
    (format t "~D of ~D missing: ~S~%" missing total packages))
```

## ELMTUI.DOCS:PUBLIC-API-BINDINGS

Kinds: function

```text
Return canonical, exported, de-duplicated metadata for the live public API.

The :PACKAGE is always an actual exporting package, so PACKAGE:SYMBOL resolves
with the normal single-colon syntax. :HOME-PACKAGE records the defining
symbol's home when it differs. Re-exports are de-duplicated by identity.
```

## ELMTUI.KEYMAPS:*ACTIVE-CONTEXTS*

Kinds: variable

```text
Special variable holding the active contexts configuration or registry used by the keyboard dispatch subsystem.
```

## ELMTUI.KEYMAPS:*CONTEXTS*

Kinds: variable

```text
Special variable holding the contexts configuration or registry used by the keyboard dispatch subsystem.
```

## ELMTUI.KEYMAPS:*DIALOG-KEYMAP*

Kinds: variable

```text
Special variable holding the dialog keymap configuration or registry used by the keyboard dispatch subsystem.
```

## ELMTUI.KEYMAPS:*DISPATCH-FN*

Kinds: variable

```text
Dynamically bound function for dispatching messages from keybindings.
```

## ELMTUI.KEYMAPS:*EDITOR-KEYMAP*

Kinds: variable

```text
Special variable holding the editor keymap configuration or registry used by the keyboard dispatch subsystem.
```

## ELMTUI.KEYMAPS:*FORM-KEYMAP*

Kinds: variable

```text
Special variable holding the form keymap configuration or registry used by the keyboard dispatch subsystem.
```

## ELMTUI.KEYMAPS:*GLOBAL-KEYMAP-CONTEXT*

Kinds: variable

```text
The root keymap context.
```

## ELMTUI.KEYMAPS:*GLOBAL-NAVIGATION-KEYMAP*

Kinds: variable

```text
Special variable holding the global navigation keymap configuration or registry used by the keyboard dispatch subsystem.
```

## ELMTUI.KEYMAPS:*LIST-NAVIGATION-KEYMAP*

Kinds: variable

```text
Special variable holding the list navigation keymap configuration or registry used by the keyboard dispatch subsystem.
```

## ELMTUI.KEYMAPS:*REGISTRY*

Kinds: variable

```text
Special variable holding the registry configuration or registry used by the keyboard dispatch subsystem.
```

## ELMTUI.KEYMAPS:ACTIVATE-CONTEXT

Kinds: function

```text
Activate a named keymap context so its bindings participate in key dispatch.
```

## ELMTUI.KEYMAPS:ADD-KEYBINDING

Kinds: function

```text
Register a key specification and its target action or message in a keymap.
```

## ELMTUI.KEYMAPS:ADD-KEYMAP-TO-CONTEXT

Kinds: function

```text
Associate a keymap with a context for scoped keyboard lookup.
```

## ELMTUI.KEYMAPS:CURRENT-CONTEXT

Kinds: function

```text
Return the currently selected keyboard context, if one is active.
```

## ELMTUI.KEYMAPS:DEACTIVATE-CONTEXT

Kinds: function

```text
Deactivate a named keymap context, removing its bindings from active dispatch.
```

## ELMTUI.KEYMAPS:DEFINE-KEYMAP

Kinds: macro

```text
Define a keymap VAR with BINDINGS.

Binds a keymap object to the symbol VAR and DOES NOT register it in *registry*. The
keymap object is returned as the value of the macro.
WARNING: VAR is not quoted, it is a symbol to be defined.

*registry*: A global hash table mapping keymap names (symbols) to keymap objects.
This allows keymaps to be referenced by name in contexts.

BINDINGS is a list of (KEY-STRING . PLIST) pairs, where KEY-STRING is a
string like "C-x" or "Shift-F1", and PLIST contains:
  :type        - either :action or :message
  :target      - function symbol (for :action) or message payload (for :message
                 e.g., '(:quit
  :description - human-readable description for help overlays
Example:
  (define-keymap *my-keymap*
    ("C-x" :type :action  :target 'my-action      :description "Do something")
    ("F1"  :type :message :target '(:show-help)   :description "Show help")
    ("C-q" :type :message :target '(:quit)        :description "Quit application")
    ("C-c C-c" :type :message :target '(:copy)    :description "Copy selection")
    ("C-v" :type :message :target '(:paste)       :description "Paste from clipboard")
    ("Shift-Tab" :type :message :target '(:focus-prev) :description "Focus previous element")
    ("Tab" :type :message :target '(:focus-next)  :description "Focus next element")
    ("Up"  :type :message :target '(:move-up)     :description "Move up")
    ("Down":type :message :target '(:move-down)   :description "Move down")
    ("Enter":type :message :target '(:activate)   :description "Activate/Select"))
 Returns the created keymap object.
```

## ELMTUI.KEYMAPS:DEFINE-KEYMAP-CONTEXT

Kinds: function

```text
Creates and registers a keymap context.
- NAME: The keyword name for the context (e.g., :my-context).
- PARENT: The keyword name of the parent context (e.g., :global).
- KEYMAPS: A list of keymap names (e.g., '(:dialog :form)).
Returns the created context object.

  Example:
  (define-keymap-context :my-context
    :parent :global
    :keymaps '(:dialog :form))
If PARENT is not provided, the context will be a root context.
If KEYMAPS is not provided, the context will have no keymaps.
If a keymap name is not found in the registry, an error is raised.
```

## ELMTUI.KEYMAPS:FIND-CONTEXT

Kinds: function

```text
Locate the registered keymap context with the supplied identifier.
```

## ELMTUI.KEYMAPS:INITIALISE

Kinds: function

```text
Call once on application start.
```

## ELMTUI.KEYMAPS:KEY-EVENT->NORMALIZED-KEY

Kinds: function

```text
Convert a terminal key event into the normalized key and modifiers used by bindings.
```

## ELMTUI.KEYMAPS:KEYMAP!

Kinds: macro

```text
Define a keymap VAR with BINDINGS.

creates and returns a keymap object, does NOT bind it to VAR or register it.

*registry*: A global hash table mapping keymap names (symbols) to keymap objects.
This allows keymaps to be referenced by name in contexts.

BINDINGS is a list of (KEY-STRING . PLIST) pairs, where KEY-STRING is a
string like "C-x" or "Shift-F1", and PLIST contains:
  :type        - either :action or :message
  :target      - function symbol (for :action) or message payload (for :message
                 e.g., '(:quit
  :description - human-readable description for help overlays
Example:
  (keymap! :my-km
    ("C-x" :type :action  :target 'my-action      :description "Do something")
    ("F1"  :type :message :target '(:show-help)   :description "Show help")
    ("C-q" :type :message :target '(:quit)        :description "Quit application")
    ("C-c C-c" :type :message :target '(:copy)    :description "Copy selection")
    ("C-v" :type :message :target '(:paste)       :description "Paste from clipboard")
    ("Shift-Tab" :type :message :target '(:focus-prev) :description "Focus previous element")
    ("Tab" :type :message :target '(:focus-next)  :description "Focus next element")
    ("Up"  :type :message :target '(:move-up)     :description "Move up")
    ("Down":type :message :target '(:move-down)   :description "Move down")
    ("Enter":type :message :target '(:activate)   :description "Activate/Select"))
 Returns the created keymap object.
```

## ELMTUI.KEYMAPS:KEYMAP-BINDINGS

Kinds: function

```text
Return the bindings currently registered on the keymap.
```

## ELMTUI.KEYMAPS:KEYMAP-CONTEXT

Kinds: type

```text
Public keymap context type used to represent structured asynchronous tasks, styles or UI elements.
```

## ELMTUI.KEYMAPS:KEYMAP-CONTEXT-KEYMAPS

Kinds: function

```text
Return keymaps associated with this keymap context.
```

## ELMTUI.KEYMAPS:KEYMAP-CONTEXT-NAME

Kinds: function

```text
Return this keymap context's name.
```

## ELMTUI.KEYMAPS:KEYMAP-CONTEXT-PARENT

Kinds: function

```text
Return its parent context used in contextual key dispatch.
```

## ELMTUI.KEYMAPS:LIST-ACTIVE-KEYBINDINGS

Kinds: function

```text
Return list of plists {:key … :description … :source-keymap …}
```

## ELMTUI.KEYMAPS:LOOKUP

Kinds: function

```text
Return binding for KEY (NORMALIZED-KEY or KEY-SEQUENCE).
```

## ELMTUI.KEYMAPS:LOOKUP-BINDING

Kinds: function

```text
Resolve a normalized key against the active keymap contexts in precedence order.
```

## ELMTUI.KEYMAPS:LOOKUP-BINDING-IN

Kinds: function

```text
Lookup a binding starting at CONTEXT. If INCLUDE-PARENTS is true,
walk up parent contexts; otherwise only search CONTEXT's keymaps.
```

## ELMTUI.KEYMAPS:MAKE-KEYMAP-CONTEXT

Kinds: function

```text
Construct a keymap context with name, parent and contained keymaps.
```

## ELMTUI.KEYMAPS:NORMALIZED-KEY->STRING

Kinds: function

```text
Format a normalized key as a stable human-readable key specification.
```

## ELMTUI.KEYMAPS:NORMALIZED-KEY-KEY

Kinds: function

```text
Return the base key of a normalized keyboard input.
```

## ELMTUI.KEYMAPS:NORMALIZED-KEY-MODIFIERS

Kinds: function

```text
Return modifiers carried by a normalized keyboard input.
```

## ELMTUI.KEYMAPS:PARSE-KEY-STRING

Kinds: function

```text
Parse a textual key combination into its normalized key representation.
```

## ELMTUI.KEYMAPS:PROCESS-KEY-EVENT

Kinds: function

```text
Main dispatcher – converts EVT to NORMALIZED-KEY, runs registry lookup.
   Binds *dispatch-fn* to DISPATCH-FN for the duration of the call.
```

## ELMTUI.KEYMAPS:REMOVE-KEYBINDING

Kinds: function

```text
Remove a previously registered key binding from its keymap.
```

## ELMTUI.KEYMAPS:RESOLVE-KEYMAP-REFERENCE

Kinds: function

```text
Resolve an identifier or existing keymap reference to its registered keymap.
```

## ELMTUI.PIPELINE:*PRESERVE-UNDERLAY*

Kinds: variable

```text
When true, render-to-buffer starts from current front-buffer content and avoids clearing it.
```

## ELMTUI.PIPELINE:DISPLAY-BUFFER

Kinds: function

_No documentation metadata._

## ELMTUI.PIPELINE:FULL-VIEW-PIPELINE

Kinds: function

_No documentation metadata._

## ELMTUI.PIPELINE:GENERATE-DSL

Kinds: function

_No documentation metadata._

## ELMTUI.PIPELINE:PRE-RENDER-TERMINAL-PREP

Kinds: function

_No documentation metadata._

## ELMTUI.PIPELINE:PROCESS-TREE-STAGE

Kinds: function

_No documentation metadata._

## ELMTUI.PIPELINE:RENDER-PIPELINE-0-TO-5

Kinds: function

_No documentation metadata._

## ELMTUI.PIPELINE:RENDER-TO-BUFFER

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.API:ACQUIRE-LOCK

Kinds: function

```text
Acquire the synchronization lock associated with a lockable backend object.
```

## ELMTUI.PLATFORM.API:APPLY-STYLE

Kinds: function

```text
Apply a style specification through the selected terminal backend.
```

## ELMTUI.PLATFORM.API:BACKEND-INPUT-DEVICE

Kinds: function

```text
Return the underlying cl-inputs device used for reading input, or NIL if the backend does not expose one.
```

## ELMTUI.PLATFORM.API:BACKEND-INPUT-SOURCE

Kinds: function

```text
Return the cl-inputs input source that the backend created, if any.
```

## ELMTUI.PLATFORM.API:BACKEND-NAME

Kinds: function

```text
Return the implementation name of the active terminal backend.
```

## ELMTUI.PLATFORM.API:BACKEND-VERSION

Kinds: function

```text
Return the backend implementation version when available.
```

## ELMTUI.PLATFORM.API:CLEAR-AREA

Kinds: function

```text
Clear a rectangular screen region using backend-specific operations.
```

## ELMTUI.PLATFORM.API:CLEAR-BELOW-CURSOR

Kinds: function

```text
Clear all content from the cursor position to the end of the screen.
```

## ELMTUI.PLATFORM.API:CLEAR-SCREEN

Kinds: function

```text
Initialize the backend for the specified platform. If PUBLISH-FN is provided, it will be used to publish events.
```

## ELMTUI.PLATFORM.API:DEFAULT-BACKGROUND-COLOR

Kinds: function

```text
Return the backend default background color specification.
```

## ELMTUI.PLATFORM.API:DEFAULT-FOREGROUND-COLOR

Kinds: function

```text
Return the backend default foreground color specification.
```

## ELMTUI.PLATFORM.API:DISABLE-MOUSE-SUPPORT

Kinds: function

```text
Disable reporting of mouse events by the selected backend.
```

## ELMTUI.PLATFORM.API:DRAW-BOX-OUTLINE

Kinds: function

```text
Draw the outline of a rectangle using terminal drawing primitives.
```

## ELMTUI.PLATFORM.API:DRAW-CHAR-AT

Kinds: function

```text
Draw a single character at the requested terminal cell coordinate.
```

## ELMTUI.PLATFORM.API:DRAW-STYLED-BOX

Kinds: function

```text
Draw a rectangular box with the requested backend style.
```

## ELMTUI.PLATFORM.API:DRAW-TEXT-AT

Kinds: function

```text
Draw text at the requested terminal cell coordinates.
```

## ELMTUI.PLATFORM.API:ENABLE-MOUSE-SUPPORT

Kinds: function

```text
Enable mouse event reporting when the backend supports it.
```

## ELMTUI.PLATFORM.API:FILL-RECTANGLE

Kinds: function

```text
Fill a rectangular terminal region with the requested cell content.
```

## ELMTUI.PLATFORM.API:FLUSH-OUTPUT

Kinds: function

```text
Flush pending backend terminal writes to its output destination.
```

## ELMTUI.PLATFORM.API:GET-CURSOR-POSITION

Kinds: function

```text
Query the current terminal cursor row and column, if supported.
```

## ELMTUI.PLATFORM.API:GET-NATIVE-HANDLE

Kinds: function

```text
Return the backend's underlying platform handle.
```

## ELMTUI.PLATFORM.API:GET-SCREEN-DIMENSIONS

Kinds: function

```text
Query the terminal screen width and height in cells.
```

## ELMTUI.PLATFORM.API:HANDLE-BACKEND-RESIZE

Kinds: function

```text
Update backend state when terminal geometry changes.
```

## ELMTUI.PLATFORM.API:HIDE-CURSOR

Kinds: function

```text
Request that the terminal cursor become invisible.
```

## ELMTUI.PLATFORM.API:INITIALIZE-BACKEND

Kinds: function

```text
Initialize the backend for the specified platform. If PUBLISH-FN is provided, it will be used to publish events.
```

## ELMTUI.PLATFORM.API:LOCK-OF

Kinds: function

```text
Return the lock used to guard this lockable backend object.
```

## ELMTUI.PLATFORM.API:LOCKABLE

Kinds: type

```text
Protocol type for objects providing a synchronization lock.
```

## ELMTUI.PLATFORM.API:MAKE-COLOR

Kinds: function

```text
Construct a terminal color specification for the backend styling API.
```

## ELMTUI.PLATFORM.API:MAKE-STYLE

Kinds: function

```text
Construct a terminal style from the supplied attributes.
```

## ELMTUI.PLATFORM.API:MAX-COLORS

Kinds: function

```text
Return the maximum supported palette size for this backend.
```

## ELMTUI.PLATFORM.API:PEEK-INPUT-EVENT

Kinds: function

```text
Inspect the next backend input event without consuming it.
```

## ELMTUI.PLATFORM.API:POLL-INPUT-EVENT

Kinds: function

```text
Poll the next input event from the selected backend.
```

## ELMTUI.PLATFORM.API:QUERY-FEATURE

Kinds: function

```text
Query an optional terminal capability by feature identifier.
```

## ELMTUI.PLATFORM.API:RELEASE-LOCK

Kinds: function

```text
Release a previously acquired synchronization lock.
```

## ELMTUI.PLATFORM.API:SCROLL

Kinds: function

```text
Scroll the terminal display by N lines. Positive N scrolls down, negative N scrolls up.
```

## ELMTUI.PLATFORM.API:SCROLL-LINES

Kinds: function

```text
Scroll the requested terminal lines via the backend interface.
```

## ELMTUI.PLATFORM.API:SET-CELL-STYLE

Kinds: function

```text
Set styling attributes on a terminal cell through the backend.
```

## ELMTUI.PLATFORM.API:SET-CURSOR-POSITION

Kinds: function

```text
Set the cursor position to (X, Y) on the terminal.
```

## ELMTUI.PLATFORM.API:SET-CURSOR-VISIBILITY

Kinds: function

```text
Set cursor visibility using the backend protocol.
```

## ELMTUI.PLATFORM.API:SET-INPUT-MODE

Kinds: function

```text
Configure the terminal input mode through the backend.
```

## ELMTUI.PLATFORM.API:SHOW-CURSOR

Kinds: function

```text
Request that the terminal cursor become visible.
```

## ELMTUI.PLATFORM.API:SHUTDOWN-BACKEND

Kinds: function

```text
Cleanly shut down backend resources and restore terminal state.
```

## ELMTUI.PLATFORM.API:SUPPORTS-MOUSE-P

Kinds: function

```text
Report whether this backend can emit mouse input events.
```

## ELMTUI.PLATFORM.API:SUPPORTS-TRUECOLOR-P

Kinds: function

```text
Report whether this backend supports 24-bit color output.
```

## ELMTUI.PLATFORM.API:SUPPORTS-UNICODE-P

Kinds: function

```text
Report whether the backend supports Unicode cell rendering.
```

## ELMTUI.PLATFORM.API:TERM-H

Kinds: function

```text
Return the backend terminal height in cell rows.
```

## ELMTUI.PLATFORM.API:TERM-STREAM

Kinds: function

```text
Return the backend terminal output stream.
```

## ELMTUI.PLATFORM.API:TERM-STYLE

Kinds: function

```text
Return the backend terminal style settings.
```

## ELMTUI.PLATFORM.API:TERM-W

Kinds: function

```text
Return the backend terminal width in cell columns.
```

## ELMTUI.PLATFORM.API:WITH-LOCK

Kinds: macro

```text
Execute BODY with the lock of LOCKABLE L acquired.
This macro ensures that the lock is acquired before executing BODY,
and released afterwards, even if an error occurs during execution.
It uses `acquire-lock` and `release-lock` methods to manage the lock.
This is useful for ensuring thread safety when accessing shared resources.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:ANSI-SEQS

Kinds: function

```text
Return ANSI SGR control strings for requested ATTRS of a TERMINAL-STYLE in argument order. NIL styles return NIL; list styles are interpreted as explicit key/value entries.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:AS-PLIST

Kinds: function

```text
Convert STYLE to plist representation for terminal rendering.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:COPY-TERM-COLOR

Kinds: function

```text
Creates a deep copy of a terminal-color instance.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:COPY-TERM-STYLE

Kinds: function

```text
Creates a deep copy of a terminal-style instance.
   Returns NIL if style is NIL, otherwise always returns a terminal-style.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:DEEP-COPY-STYLE

Kinds: function

```text
Creates a deep copy of a style plist, including any nested lists like RGB values.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:EXEC-SEQUENCE

Kinds: function

```text
Write every character of string SEQ as a byte to FD while holding LOCKABLE, then flush FD. Extra ARGS are ignored; stream write errors propagate.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:FUZZ-COLOR

Kinds: function

```text
Convert various color representations to a terminal-color.
   Supported input formats:
   - terminal-color: returned as-is
   - (:rgb r g b): 24-bit RGB color
   - (:256 n): 256-color palette (n is 0-255)
   - (r g b): raw RGB list
   - (n): raw 256-color palette value
   - integer: 256-color palette value
   - keyword: simple color (:red, :blue, etc.)
   - string: hex color (#FF0000)
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:IS-TERM-STYLE

Kinds: function

```text
Checks if the given style S is a terminal style.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:MAKE-TERMCOLOR

Kinds: function

```text
Construct a TERMINAL-COLOR using shorthand R, G, B, SIMPLE, BG, and COLOR-256 keyword arguments; return the new color descriptor.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:MAKE-TERMINAL-COLOR

Kinds: function

```text
Construct a TERMINAL-COLOR with RED, GREEN, BLUE, SIMPLE, BG, and COLOR-256 keyword slots. Unspecified channels remain NIL; no color conversion occurs.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:MAKE-TERMINAL-STYLE

Kinds: function

```text
Construct a TERMINAL-STYLE with FG-COLOR and BG-COLOR descriptors and independent attribute flags. Every omitted slot starts as NIL.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:NO-COLOR-P

Kinds: function

```text
Return true if TERMINAL-COLOR has no RGB component, simple keyword, or 256-color index. The BG flag does not count as a color.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:STYLE-TO-TERMINAL-STYLE

Kinds: function

```text
Converts a style plist to a terminal-style instance, ensuring a valid
   terminal-style object is always returned.
   Args:
   - STYLE-PLIST: A property list containing style attributes.
   Returns:
   - A terminal-style instance with the specified attributes.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-COLOR

Kinds: type

```text
A terminal color descriptor holding optional RGB components, a simple color keyword, a 256-color index, and a background-selection flag.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-COLOR-BG

Kinds: function

```text
Return the BG flag stored in TERMINAL-COLOR; this flag selects background SGR encoding when no overriding BG argument is supplied.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-COLOR-SIMPLE

Kinds: function

```text
Return the SIMPLE color keyword stored in TERMINAL-COLOR, or NIL when its color representation is RGB, indexed, or unspecified.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE

Kinds: type

```text
A mutable terminal style descriptor with foreground and background colors plus bold, italic, underline, faint, blink, inverse, strike, and invisible attributes.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-BG-COLOR

Kinds: function

```text
Read the BG-COLOR slot of TERMINAL-STYLE. It may contain a TERMINAL-COLOR or NIL and may be changed through the SETF accessor.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-BG-COLOR-VAL

Kinds: function

```text
Extract STYLE background as an RGB integer list, 256-color palette index, or simple color keyword. Return NIL if the background is absent or unrecognized.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-BLINK

Kinds: function

```text
Read or, with SETF, change the BLINK attribute slot of TERMINAL-STYLE. NIL represents an unset or disabled attribute.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-BOLD

Kinds: function

```text
Read or, with SETF, change the BOLD attribute slot of TERMINAL-STYLE. NIL represents an unset or disabled attribute.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-FAINT

Kinds: function

```text
Read or, with SETF, change the FAINT attribute slot of TERMINAL-STYLE. NIL represents an unset or disabled attribute.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-FG-COLOR

Kinds: function

```text
Read the FG-COLOR slot of TERMINAL-STYLE. It may contain a TERMINAL-COLOR or NIL and may be changed through the SETF accessor.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-FG-COLOR-VAL

Kinds: function

```text
Extract STYLE foreground as an RGB integer list, 256-color palette index, or simple color keyword. Return NIL if the foreground is absent or unrecognized.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-INVERSE

Kinds: function

```text
Read or, with SETF, change the INVERSE attribute slot of TERMINAL-STYLE. NIL represents an unset or disabled attribute.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-INVISIBLE

Kinds: function

```text
Read or, with SETF, change the INVISIBLE attribute slot of TERMINAL-STYLE. NIL represents an unset or disabled attribute.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-ITALIC

Kinds: function

```text
Read or, with SETF, change the ITALIC attribute slot of TERMINAL-STYLE. NIL represents an unset or disabled attribute.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-KV

Kinds: function

```text
Update one TERMINAL-STYLE slot selected by K using V. Accepted keys are FG, BG, BOLD, ITALIC, UNDERLINE, FAINT, BLINK, INVERSE, STRIKE, and INVISIBLE; unknown keys signal an error.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-STRIKE

Kinds: function

```text
Read or, with SETF, change the STRIKE attribute slot of TERMINAL-STYLE. NIL represents an unset or disabled attribute.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE-UNDERLINE

Kinds: function

```text
Read or, with SETF, change the UNDERLINE attribute slot of TERMINAL-STYLE. NIL represents an unset or disabled attribute.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:UPDATE-STYLE!

Kinds: function

```text
Merge UPDATE-STYLE into mutable STYLE and return changed attribute key/value pairs. A NIL STYLE creates a fresh style; raw plist STYLE inputs are ignored and return NIL.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL

Kinds: type

```text
Represents a single cell in the virtual terminal buffer.
that is: at this point already a character with a style.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL-AT

Kinds: function

```text
Retrieves a *copy* of the cell at (ROW, COL).
Signals INVALID-BUFFER-COORDINATES-ERROR if out of bounds.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL-CHAR

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL-EQUAL-P

Kinds: function

```text
Compares two BUFFER-CELL instances for equality (char and style).
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL-STYLE

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELLS

Kinds: function

```text
Returns the raw 2D array of BUFFER-CELL objects.
   Use with caution; prefer cell-level APIs for modification to ensure thread-safety.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CHAR

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-ERROR

Kinds: type

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-HEIGHT

Kinds: function

```text
Returns the height of the BUFFER.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-LOCK

Kinds: function

```text
Returns the recursive lock associated with the BUFFER.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-STYLE

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-WIDTH

Kinds: function

```text
Returns the width of the BUFFER.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:CLEAR-BUFFER

Kinds: function

```text
Clears the entire buffer by filling it with CHAR and STYLE.
   Returns the modified BUFFER.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:COPY-BUFFER-CONTENTS

Kinds: function

```text
Copies the overlapping contents of SOURCE-BUFFER to TARGET-BUFFER.
  Assumes top-left alignment (0,0) for the copy in both buffers.
  Styles are deep-copied via `buffer-cell-at` and `set-buffer-cell-at`.
  Returns the modified TARGET-BUFFER.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:COPY-VIRTUAL-BUFFER

Kinds: function

```text
Creates a deep copy of the BUFFER, including a new `cells` array and new `buffer-cell` objects.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:DEFAULT-BUFFER-CELL

Kinds: function

```text
Returns a new buffer-cell with default character and specified style.
   If style is nil, no style is applied.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:FILL-BUFFER-REGION

Kinds: function

```text
Fills a rectangular region starting at (ROW, COL) with dimensions WIDTH x HEIGHT
with the specified CHAR and STYLE. Handles clipping to buffer boundaries.
The STYLE argument is passed to `set-buffer-cell-at` for each cell, which
handles conversion (e.g. plist to terminal-style) and copying.
Returns the modified BUFFER.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:INVALID-BUFFER-COORDINATES-ERROR

Kinds: type

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:INVALID-BUFFER-COORDINATES-ERROR-BUFFER

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:INVALID-BUFFER-COORDINATES-ERROR-COL

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:INVALID-BUFFER-COORDINATES-ERROR-ROW

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:MAKE-BUFFER-CELL

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:MAKE-VIRTUAL-BUFFER

Kinds: function

```text
Creates a new VIRTUAL-TERMINAL-BUFFER of specified WIDTH and HEIGHT.
   Initializes cells with initial-char and initial-style.
   The buffer's default-style is also set based on a processed version of initial-style.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:NEW-BUFFER

Kinds: function

```text
Creates a new VIRTUAL-TERMINAL-BUFFER of specified WIDTH and HEIGHT.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:PRINT-BUFFER-TO-STRING

Kinds: function

```text
Utility for debugging. Renders the buffer content to a string,
optionally including style information.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:RESIZE-BUFFER

Kinds: function

```text
Creates a *new* VIRTUAL-TERMINAL-BUFFER of NEW-WIDTH and NEW-HEIGHT.
Copies content from the old BUFFER that fits into the new dimensions.
Fills any new areas (due to expansion) with DEFAULT-CHAR and DEFAULT-STYLE.
Returns the new buffer.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:SET-BUFFER-CELL-AT

Kinds: function

```text
Modifies the cell at (ROW, COL) with CHAR and STYLE.
Signals INVALID-BUFFER-COORDINATES-ERROR if out of bounds.
Returns the modified BUFFER.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:VIRTUAL-TERMINAL-BUFFER

Kinds: type

```text
Represents a 2D grid of styled characters for the terminal screen.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:VIRTUAL-TERMINAL-BUFFER-CELLS

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:VIRTUAL-TERMINAL-BUFFER-HEIGHT

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:VIRTUAL-TERMINAL-BUFFER-LOCK

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:VIRTUAL-TERMINAL-BUFFER-WIDTH

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:WITH-VIRTUAL-BUFFER-LOCK

Kinds: macro

```text
Acquires the lock for BUFFER and executes BODY.
```

## ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:WRITE-STRING-TO-BUFFER

Kinds: function

```text
Writes STRING to the buffer starting at START-ROW, START-COL with STYLE.
  Optional MAX-WIDTH, MAX-HEIGHT for clipping/wrapping.
  If WRAP is true, text wraps within MAX-WIDTH.
  If STYLE is nil, the buffer's `default-style` is used if set, otherwise nil style.
  Returns the modified BUFFER.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:*TERMINAL-DEBUG-FRAME-ID*

Kinds: variable

```text
Current frame ID, bound dynamically during pipeline display.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:*TERMINAL-DEBUG-OWNED-REGION*

Kinds: variable

```text
Current owned region, bound dynamically during pipeline display.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:*TERMINAL-DEBUG-PHASE*

Kinds: variable

```text
Current rendering phase, bound dynamically during pipeline display.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:MAKE-TERMINAL-INSTANCE-FOR-DEVICE

Kinds: function

```text
Construct a terminal-instance around a cl-inputs DEVICE.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:RESET-TERMINAL-OUTPUT-STATISTICS

Kinds: function

```text
Reset only INSTANCE's output counters. Return an empty snapshot.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:SEND-SEQUENCE

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:STYLE-TO-TERMINAL-STYLE

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE

Kinds: type

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-BACK-BUFFER

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-CL-DEVICE

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-CURRENT-STYLE

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-CURSOR-COL

Kinds: function

```text
Return the integer cursor COLUMN tracked by TERMINAL-INSTANCE, initially zero.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-CURSOR-ROW

Kinds: function

```text
Return the integer cursor ROW tracked by TERMINAL-INSTANCE, initially zero.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-CURSOR-VISIBLE-P

Kinds: function

```text
Return the cursor visibility flag stored in TERMINAL-INSTANCE; it is initially true.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-FRONT-BUFFER

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-HEIGHT

Kinds: function

```text
Return the current integer HEIGHT stored in TERMINAL-INSTANCE; the default for a new instance is 24 rows.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-LOCK

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-STREAM

Kinds: function

```text
Return the optional STREAM slot of a TERMINAL-INSTANCE. It holds the terminal output stream when one is attached.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE-WIDTH

Kinds: function

```text
Return the current integer WIDTH stored in TERMINAL-INSTANCE; the default for a new instance is 80 columns.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-OUTPUT-STATISTICS

Kinds: function

```text
Return an independent snapshot of INSTANCE's successful output counters.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-OUTPUT-STATS-CHARS-WRITTEN

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-OUTPUT-STATS-CURSOR-MOVES-APPLIED

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-OUTPUT-STATS-FORCED-STYLE-RESETS

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-OUTPUT-STATS-OPS-PROCESSED

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-OUTPUT-STATS-STYLE-CHANGES-APPLIED

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:WITH-TERMINAL-LOCK

Kinds: macro

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:WRITE-OUTPUT

Kinds: function

```text
Write output to the terminal
This method should be implemented by subclasses of low-level-terminal.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL:WRITE-STYLE-RESET-TO-STREAM

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.BACKEND.TERMINAL:WRITE-STYLE-TO-STREAM

Kinds: function

```text
Write ANSI escape sequences for STYLE to STREAM. STYLE may be a style plist or a terminal-style instance.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL.DIFF-RENDERER:*COMPUTE-BUFFER-DIFF-FIRST-CALL*

Kinds: variable

```text
Obsolete first-frame compatibility flag; use :INITIAL-FRAME-P instead.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL.DIFF-RENDERER:APPLY-DIFF-TO-BACKEND

Kinds: function

```text
Apply a list of diff operations (DIFF-OPS) to BACKEND-INSTANCE.
DIFF-OPS rows/cols are relative to the canvas origin.
TERMINAL-OFFSET-ROW/COL shift the canvas so its (0,0) lands on the terminal.
```

## ELMTUI.PLATFORM.BACKEND.TERMINAL.DIFF-RENDERER:COMPUTE-BUFFER-DIFF

Kinds: function

```text
Delegate to pure frame diff. Return operations and per-call diff metrics;
no global diagnostics are read or updated.
```

## ELMTUI.PLATFORM.DRIVER:DRIVER-CONTEXT

Kinds: type

_No documentation metadata._

## ELMTUI.PLATFORM.DRIVER:DRIVER-CONTEXT-BACKEND

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.DRIVER:DRIVER-CONTEXT-DEVICE

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.DRIVER:DRIVER-CONTEXT-INPUT-SOURCE

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.DRIVER:DRIVER-CONTEXT-INPUT-THREAD

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.DRIVER:DRIVER-CONTEXT-PUBLISH-FN

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.DRIVER:DRIVER-CONTEXT-STOP-FLAG

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.DRIVER:EXECUTE-RENDER-COMMAND

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.DRIVER:MAKE-DRIVER-CONTEXT

Kinds: function

_No documentation metadata._

## ELMTUI.PLATFORM.DRIVER:RUN-APP-PLATFORM

Kinds: function

```text
Main entry point for running an application on the platform.
  Arguments:
    APP-SPEC (list): Application specification plist.
    BACKEND-TYPE (keyword): Backend type, e.g., :terminal.
    TTY-PATH (or string null): Path to TTY device, or NIL.
    [Other platform options may be passed via &allow-other-keys.]
  Returns:
    NIL
  Example:
    (run-app-platform my-app-spec :backend-type :terminal)
  Type: (list, &key keyword (or string null)) => nil
  Side-effects: Initializes backend, starts input thread, runs app loop, cleans up on shutdown.
```

## ELMTUI.PLATFORM.DRIVER:START-DRIVER-INPUT-LOOP

Kinds: function

```text
Begin the driver input thread; returns the thread object.
```

## ELMTUI.PLATFORM.DRIVER:STOP-DRIVER-INPUT-LOOP

Kinds: function

```text
Signal the driver input loop to stop and leave the stop flag set until teardown completes.
```

## ELMTUI.PLATFORM.INPUT:CL-INPUTS-TOKEN->EVENT

Kinds: function

```text
Convert a cl-inputs token to an elmtui event structure. Returns NIL when unsupported.
```

## ELMTUI.PLATFORM.INPUT:START-READER

Kinds: function

```text
Spawns a thread that continuously pulls cl-inputs tokens from BACKEND-INSTANCE
and publishes mapped events using the provided EVENT-HANDLER.

Args:
  backend-instance: The initialized backend (e.g., terminal-instance) to poll for input.
  event-handler: A function to call with the polled event.

Returns:
  Multiple values: the thread object and the symbol name of the function
  generated by `with-interruptable-signal` to stop this reader thread (e.g., 'interrupt-reader-fn').
```

## ELMTUI.PLATFORM.INPUT:STOP-READER

Kinds: function

```text
Stops the input reader thread.

Args:
  stop-signal-function: The function or symbol of the function generated by `with-interruptable-signal`
                        (e.g., 'interrupt-reader-fn) to signal the thread.
  thread-handle: Optional. The thread object returned by `start-reader`. If provided,
                 this function will attempt to join the thread after signaling.

Returns:
  T if the signal function was called, NIL otherwise.
```

## ELMTUI.PLATFORM.TMUX:CAPTURE-LINES

Kinds: function

```text
Capture tmux output and return a vector of lines.
```

## ELMTUI.PLATFORM.TMUX:CAPTURE-PANE-STRING

Kinds: function

```text
Capture the current tmux pane (MODE :pane or :screen) and return it as a string.
The -e flag ensures escape sequences are included for style preservation.
```

## ELMTUI.PLATFORM.TMUX:CAPTURE-SCREEN-STRING

Kinds: function

```text
Return ANSI-styled tmux pane content including scrollback via CAPTURE-PANE-STRING with MODE :SCREEN. Read-only; potentially larger than the visible pane.
```

## ELMTUI.PLATFORM.TMUX:CLEAR-SAVED-TMUX-CAPTURE

Kinds: function

```text
Clear the saved tmux capture.
```

## ELMTUI.PLATFORM.TMUX:HAS-SAVED-TMUX-CAPTURE

Kinds: function

```text
Check if there is a saved tmux capture available for restoration.
```

## ELMTUI.PLATFORM.TMUX:MAKE-BUFFER-FROM-TMUX

Kinds: function

```text
Create a virtual buffer populated from tmux output.
```

## ELMTUI.PLATFORM.TMUX:MAKE-BUFFER-FROM-TMUX-STYLED

Kinds: function

```text
Return a new WIDTH-by-HEIGHT styled visible-pane cell grid, or NIL outside tmux. Captures only; does not repaint cells or restore history.
```

## ELMTUI.PLATFORM.TMUX:PARSE-ANSI-SGR

Kinds: function

```text
Parse an ANSI SGR (Select Graphic Rendition) sequence into a style plist.
Returns NIL if the sequence is a reset, or a plist with :fg, :bg, :attrs keys.
```

## ELMTUI.PLATFORM.TMUX:PARSE-ANSI-STRING

Kinds: function

```text
Parse safe SGR style runs; non-SGR terminal controls are never replayed.
A combined reset/set such as ESC[0;31m clears old attributes first.
```

## ELMTUI.PLATFORM.TMUX:PREFILL-BACKEND-FROM-TMUX

Kinds: function

```text
Prefill BACKEND from styled visible tmux cells and return an independent cell snapshot. No full history is saved, so this does not guarantee resize-safe quit.
```

## ELMTUI.PLATFORM.TMUX:PREFILL-BACKEND-FROM-TMUX-STYLED

Kinds: function

```text
Fill terminal backend front/back buffers from visible pane SGR cells and return a separate styled snapshot. No scrollback history is replayed or protected from shrink.
```

## ELMTUI.PLATFORM.TMUX:PREFILL-BUFFER-FROM-STRING

Kinds: function

```text
Fill BUFFER (virtual-terminal-buffer) with CONTENT text.
```

## ELMTUI.PLATFORM.TMUX:PREFILL-BUFFER-FROM-STYLED-CONTENT

Kinds: function

```text
Fill BUFFER with the terminal-visible tail of styled RUNS, preserving SGR.
The two bounded passes count terminal rows then render only the last HEIGHT.
No scrollback-sized intermediate buffer or terminal I/O is required.
```

## ELMTUI.PLATFORM.TMUX:RESTORE-TO-TMUX-CAPTURE

Kinds: function

```text
Copy saved cell characters and styles into virtual BUFFER, returning BUFFER. No physical repaint, cursor restoration, or tmux scrollback recovery occurs here.
```

## ELMTUI.PLATFORM.TMUX:SAVE-TMUX-CAPTURE

Kinds: function

```text
Copy a bounded visible-pane cell BUFFER into the saved slot. This does not snapshot tmux scrollback or protect history from later resize-induced displacement.
```

## ELMTUI.PLATFORM.TMUX:SPLIT-BY-ANSI-SEQUENCES

Kinds: function

```text
Split CONTENT into segments separated by ANSI escape sequences.
Returns a list of alternating plain text and ANSI sequences.
Consecutive plain text segments are merged together.
```

## ELMTUI.PLATFORM.TMUX:TMUX-AVAILABLE-P

Kinds: function

```text
Return true when tmux is available and current process is running inside tmux.
```

## ELMTUI.PLATFORM.TREE-RENDERER:RENDER-LAID-OUT-TREE-TO-BUFFER

Kinds: function

_No documentation metadata._

## ELMTUI.RENDER.DIFF:BUFFERS-NOT-COMPATIBLE-ERROR

Kinds: type

```text
Condition signaled when two virtual terminal buffers cannot be compared during incremental diff generation.
```

## ELMTUI.RENDER.DIFF:BUFFERS-NOT-COMPATIBLE-ERROR-BACK

Kinds: function

```text
Return the destination buffer retained by a buffer-compatibility condition.
```

## ELMTUI.RENDER.DIFF:BUFFERS-NOT-COMPATIBLE-ERROR-FRONT

Kinds: function

```text
Return the prior rendered buffer retained by a buffer-compatibility condition.
```

## ELMTUI.RENDER.DIFF:BUFFERS-NOT-COMPATIBLE-ERROR-REASON

Kinds: function

```text
Return the explanation for a buffer-compatibility failure.
```

## ELMTUI.RENDER.DIFF:COMPUTE-BUFFER-DIFF

Kinds: function

```text
Compute (values operations metrics) without mutating either frame or globals.
INITIAL-FRAME-P is explicit: only styled/painted cells of BACK are emitted.
Incremental comparisons require compatible FRONT and BACK dimensions.
Operations carry zero-based frame coordinates and batched :WRITE-CHARS values.
```

## ELMTUI.RENDER.DIFF:DIFF-METRICS

Kinds: type

```text
Structure recording compared cells, changed cells, emitted batches, and full redraw count for one diff.
```

## ELMTUI.RENDER.DIFF:DIFF-METRICS-BATCHES

Kinds: function

```text
Return how many write batches were emitted by a buffer-diff computation.
```

## ELMTUI.RENDER.DIFF:DIFF-METRICS-CELLS-CHANGED

Kinds: function

```text
Return the number of terminal cells requiring output in a buffer-diff computation.
```

## ELMTUI.RENDER.DIFF:DIFF-METRICS-CELLS-COMPARED

Kinds: function

```text
Return the number of cells examined during a buffer-diff computation.
```

## ELMTUI.RENDER.DIFF:DIFF-METRICS-FULL-REDRAWS

Kinds: function

```text
Return how many full redraw frames were accounted for by a buffer-diff computation.
```

## ELMTUI.RENDER.PRESENTATION:CLEAR-RECORDINGS

Kinds: function

```text
Discard recorded presentations and return PRESENTER.
```

## ELMTUI.RENDER.PRESENTATION:COMPUTE-FRAME-OPERATIONS

Kinds: function

```text
Return pure (values operations metrics) for NEXT relative to PREVIOUS.
Missing front and incompatible sizes explicitly request initial-frame logic;
no global first-call flag, allocations of dummy front buffers or terminal I/O.
```

## ELMTUI.RENDER.PRESENTATION:MAKE-RECORDING-PRESENTER

Kinds: function

_No documentation metadata._

## ELMTUI.RENDER.PRESENTATION:PRESENT-DIFF

Kinds: function

```text
Apply OPERATIONS at the zero-based origin; return true only after success.
```

## ELMTUI.RENDER.PRESENTATION:PRESENT-FRAME

Kinds: function

```text
Present only changed cells. Return (values OPERATIONS T DIFF-METRICS).
Callers may commit their front frame only after successful acknowledgement.
No-operation frames never call PRESENT-DIFF and cannot write to the backend.
```

## ELMTUI.RENDER.PRESENTATION:PRESENTER-READY-P

Kinds: function

```text
Whether PRESENTER can accept a diff now. Unsupported presenters return NIL.
```

## ELMTUI.RENDER.PRESENTATION:RECORDED-PRESENTATIONS

Kinds: function

```text
Return recording entries in presentation order, without consuming the log.
```

## ELMTUI.RENDER.PRESENTATION:RECORDING-PRESENTER

Kinds: type

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:INVALIDATE-RUNTIME-CONTEXT

Kinds: function

```text
Invalidate CONTEXT so late async work can detect that its owning runtime has ended.
```

## ELMTUI.RUNTIME.CONTEXT:MAKE-RUNTIME-CONTEXT

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT

Kinds: type

```text
Per-application runtime ownership boundary. Compatibility globals may mirror these slots, but new runtime work should be scoped to this object.
```

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-ACTIVE-P

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-APP-SENDER

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-APP-SPEC

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-BACKEND

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-FOCUS-MANAGER

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-GENERATION

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-INPUT-CONTEXT

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-LAST-CONTEXT

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-MESSAGE-PROCESSOR

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-MODEL

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-PHASE

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-PREVIOUS-FRAME-BUFFER

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-ROOT-VIEWPORT-ID-PATH

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-SHUTDOWN-REQUESTED-P

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-SUBSCRIPTIONS

Kinds: function

_No documentation metadata._

## ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-VALID-GENERATION-P

Kinds: function

```text
Return true when GENERATION still identifies the active CONTEXT instance.
```

## ELMTUI.RUNTIME.EFFECTS:APPLY-UPDATE-EFFECTS

Kinds: function

```text
Apply command execution and subscription reconciliation for one update.

This function is the runtime effect-manager boundary used by the driver.
```

## ELMTUI.RUNTIME.EFFECTS:CLEAR-SUBSCRIPTION-REGISTRY

Kinds: function

```text
Cancel and clear all active subscription handles in ACTIVE-SUBSCRIPTIONS.
```

## ELMTUI.RUNTIME.EFFECTS:NORMALIZE-SUBSCRIPTIONS

Kinds: function

```text
Normalize SUBS to a list of recognized subscription descriptors.
```

## ELMTUI.RUNTIME.EFFECTS:RECONCILE-MODEL-SUBSCRIPTIONS

Kinds: function

```text
Reconcile ACTIVE-SUBSCRIPTIONS against SUBSCRIPTIONS-FN evaluated on MODEL.
```

## ELMTUI.RUNTIME.EFFECTS:RUN-COMMANDS-WITH-POLICY

Kinds: function

```text
Execute COMMANDS using runtime policy callbacks.

Render commands run synchronously through RENDER-COMMAND-FN before all
other commands. Non-render commands are executed through
COMMAND-PROCESSOR-FN when provided, otherwise through
FALLBACK-COMMAND-INTERPRETER.
```

## ELMTUI.RUNTIME.EFFECTS:SPLIT-RENDER-COMMANDS

Kinds: function

```text
Split COMMANDS into two values: render commands and non-render commands.
```

## ELMTUI.RUNTIME.PROTOCOL:DISPATCH-ROOT-MESSAGE

Kinds: function

```text
Deliver MSG to the component tree rooted at ROOT-ID.
Returns two values: PATCHES and COMMANDS.
```

## ELMTUI.STATE.API:*UPDATE-CONTRACTS*

Kinds: variable

```text
Registry of update function contracts for documentation and validation.
```

## ELMTUI.STATE.API:INVOKE-UPDATE

Kinds: function

```text
Invoke UPDATE-FN with an update context and return an UPDATE-RESULT.

Malformed return shapes consistently signal MALFORMED-UPDATE-RESULT-ERROR so
callers can inspect the function designator, reason, and original values.
```

## ELMTUI.STATE.API:MAKE-UPDATE-RESULT

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.API:PLIST-TO-APPLICATION-STATE

Kinds: function

```text
Convert a plist to an application-state with BACKEND.
```

## ELMTUI.STATE.API:PPRINC-APPLICATION-STATE

Kinds: function

```text
Pretty print the application state.
```

## ELMTUI.STATE.API:REMOVE-COMPONENT-AT-PATH

Kinds: function

```text
Remove COMPONENT-ID-PATH through the normal state transaction protocol.
```

## ELMTUI.STATE.API:SET-STATE-REF

Kinds: function

```text
Set VALUE at PATH in STATE.
```

## ELMTUI.STATE.API:STORE-COMPONENT-AT-PATH

Kinds: function

```text
Store VALUE at COMPONENT-ID-PATH through the normal state transaction protocol.
```

## ELMTUI.STATE.API:UPDATE-RESULT

Kinds: type

```text
Represents the result of an update operation, containing patches and commands.
```

## ELMTUI.STATE.API:UR-ADD-COMMAND

Kinds: function

```text
Adds a command to the update result.
```

## ELMTUI.STATE.API:UR-COMMANDS

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.API:UR-HANDLED

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.API:UR-HAS-COMMAND-P

Kinds: function

```text
Checks if the update result contains a specific command.
```

## ELMTUI.STATE.API:UR-PATCHES

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:*STATE-SCHEMAS*

Kinds: variable

```text
Registry of defined state schemas with their validation rules
```

## ELMTUI.STATE.MODEL:ADD-STATE-OBSERVER

Kinds: function

```text
Adds an observer function for a state model
```

## ELMTUI.STATE.MODEL:APPLY-STATE-PATCHES

Kinds: function

```text
Applies a list of state patches to a state, returning the new state
```

## ELMTUI.STATE.MODEL:DEFMODEL

Kinds: macro

```text
Backward compatible defmodel (delegates to defmodel-contracted)
```

## ELMTUI.STATE.MODEL:DEFMODEL-CONTRACTED

Kinds: macro

```text
Defines a contract-enforced state model with validation, transactions, and observers
```

## ELMTUI.STATE.MODEL:DEFPATCH

Kinds: macro

```text
Defines a named state patch operation with validation
```

## ELMTUI.STATE.MODEL:DEFTRANSACTION

Kinds: macro

```text
Defines a transactional state update with rollback capability
```

## ELMTUI.STATE.MODEL:DIFF-STATES

Kinds: function

```text
Computes the differences between two states
```

## ELMTUI.STATE.MODEL:FORM-STATE-EMAIL

Kinds: function

```text
Safely accesses EMAIL from FORM-STATE state
```

## ELMTUI.STATE.MODEL:FORM-STATE-FOCUS-MANAGER

Kinds: function

```text
Safely accesses FOCUS-MANAGER from FORM-STATE state
```

## ELMTUI.STATE.MODEL:FORM-STATE-LAST-MODIFIED

Kinds: function

```text
Safely accesses LAST-MODIFIED from FORM-STATE state
```

## ELMTUI.STATE.MODEL:FORM-STATE-MESSAGE

Kinds: function

```text
Safely accesses MESSAGE from FORM-STATE state
```

## ELMTUI.STATE.MODEL:FORM-STATE-NAME

Kinds: function

```text
Safely accesses NAME from FORM-STATE state
```

## ELMTUI.STATE.MODEL:FORM-STATE-SCHEMA

Kinds: variable

_No documentation metadata._

## ELMTUI.STATE.MODEL:FORM-STATE-SUBJECT

Kinds: function

```text
Safely accesses SUBJECT from FORM-STATE state
```

## ELMTUI.STATE.MODEL:FORM-STATE-SUBMITTED

Kinds: function

```text
Safely accesses SUBMITTED from FORM-STATE state
```

## ELMTUI.STATE.MODEL:FORM-STATE-VALIDATION-ERRORS

Kinds: function

```text
Safely accesses VALIDATION-ERRORS from FORM-STATE state
```

## ELMTUI.STATE.MODEL:GET-STATE-SCHEMA

Kinds: function

```text
Retrieves the schema for a state model
```

## ELMTUI.STATE.MODEL:GET-STATE-VALUE

Kinds: function

```text
Gets a value from state using a path (list of keywords)
```

## ELMTUI.STATE.MODEL:MAKE-FORM-STATE

Kinds: function

```text
Creates a new FORM-STATE instance with validation and proper defaults
```

## ELMTUI.STATE.MODEL:MAKE-STATE-PATCH

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:MAKE-TRANSACTION

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:MERGE-STATE-UPDATES

Kinds: function

```text
Merges multiple state updates into a new state
```

## ELMTUI.STATE.MODEL:NOTIFY-STATE-OBSERVERS

Kinds: function

```text
Notifies all observers of a state change
```

## ELMTUI.STATE.MODEL:REMOVE-STATE-OBSERVER

Kinds: function

```text
Removes an observer function for a state model
```

## ELMTUI.STATE.MODEL:SET-STATE-VALUE

Kinds: function

```text
Sets a value in state using a path (returns new state)
```

## ELMTUI.STATE.MODEL:STATE-PATCH

Kinds: type

```text
Represents a single atomic state change
```

## ELMTUI.STATE.MODEL:STATE-PATCH-P

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:TRANSACTION

Kinds: type

```text
Represents a group of state patches applied atomically
```

## ELMTUI.STATE.MODEL:TRANSACTION-DESCRIPTION

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:TRANSACTION-ID

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:TRANSACTION-P

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:TRANSACTION-PATCHES

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:TRANSACTION-POST-HOOKS

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:TRANSACTION-PRE-HOOKS

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:TRANSACTION-ROLLBACK

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:TRANSACTION-STATUS

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:TRANSACTION-TIMESTAMP

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.MODEL:UPDATE-FORM-STATE

Kinds: function

```text
Updates FORM-STATE state with validation
```

## ELMTUI.STATE.MODEL:UPDATE-STATE-VALUE

Kinds: function

```text
Updates a value in state using a function (returns new state)
```

## ELMTUI.STATE.MODEL:VALIDATE-FORM-STATE

Kinds: function

```text
Validates FORM-STATE state against its schema with detailed error reporting
```

## ELMTUI.STATE.MODEL:VALIDATE-STATE-INSTANCE

Kinds: function

```text
Validates a state instance against its schema
```

## ELMTUI.STATE.MODEL:VALIDATE-STATE-SCHEMA

Kinds: function

```text
Validates that a state schema is properly defined
```

## ELMTUI.STATE.MSG:ARG-DEF

Kinds: type

```text
Represents a single argument in a variant definition.
```

## ELMTUI.STATE.MSG:ARG-DEF-KEYWORD

Kinds: function

```text
Return the keyword naming an argument in a declared message variant.
```

## ELMTUI.STATE.MSG:ARG-DEF-TYPE

Kinds: function

```text
Return the type specifier required for an argument in a declared message variant.
```

## ELMTUI.STATE.MSG:CANONICALIZE-MESSAGE-VARIANT

Kinds: function

```text
Return MESSAGE-INSTANCE with canonical keyword variant head for MESSAGE-TYPE.
Accepts symbol heads from any package as long as their names match a declared variant.
Returns NIL when MESSAGE-INSTANCE is not a recognized variant for MESSAGE-TYPE.
```

## ELMTUI.STATE.MSG:DEFMSG

Kinds: macro

```text
Define a message type NAME with variants and auto-generated constructors.
```

## ELMTUI.STATE.MSG:MAKE-ACTIVATEUSER-APPMSG

Kinds: function

```text
Constructor for ACTIVATEUSER variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-ASYNCPROGRESSUPDATE-APPMSG

Kinds: function

```text
Constructor for ASYNCPROGRESSUPDATE variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-CURSORPOSITION-APPMSG

Kinds: function

```text
Constructor for CURSORPOSITION variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-DEACTIVATEUSER-APPMSG

Kinds: function

```text
Constructor for DEACTIVATEUSER variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-DECREMENTCOUNTER-APPMSG

Kinds: function

```text
Constructor for DECREMENTCOUNTER variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-FOCUSNEXT-APPMSG

Kinds: function

```text
Constructor for FOCUSNEXT variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-FOCUSPREVIOUS-APPMSG

Kinds: function

```text
Constructor for FOCUSPREVIOUS variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-INCREMENTCOUNTER-APPMSG

Kinds: function

```text
Constructor for INCREMENTCOUNTER variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-KEYEVENT-APPMSG

Kinds: function

```text
Constructor for KEYEVENT variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-MOUSEEVENT-APPMSG

Kinds: function

```text
Constructor for MOUSEEVENT variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-REQUESTFOCUS-APPMSG

Kinds: function

```text
Constructor for REQUESTFOCUS variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-SCROLL-APPMSG

Kinds: function

```text
Constructor for SCROLL variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-SETCOUNTERLABEL-APPMSG

Kinds: function

```text
Constructor for SETCOUNTERLABEL variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-SETTHEME-APPMSG

Kinds: function

```text
Constructor for SETTHEME variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-STATECHANGED-APPMSG

Kinds: function

```text
Constructor for STATECHANGED variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-UPDATEFOCUSABLEIDS-APPMSG

Kinds: function

```text
Constructor for UPDATEFOCUSABLEIDS variant of APPMSG.
```

## ELMTUI.STATE.MSG:MAKE-WINDOWRESIZE-APPMSG

Kinds: function

```text
Constructor for WINDOWRESIZE variant of APPMSG.
```

## ELMTUI.STATE.MSG:MESSAGE-SCHEMA

Kinds: type

```text
Represents the schema for a message type defined by defmsg.
```

## ELMTUI.STATE.MSG:MESSAGE-SCHEMA-DOCSTRING

Kinds: function

```text
Return the source docstring recorded for a declared message schema.
```

## ELMTUI.STATE.MSG:MESSAGE-SCHEMA-NAME

Kinds: function

```text
Return the symbol naming the message type represented by this schema.
```

## ELMTUI.STATE.MSG:MESSAGE-SCHEMA-VARIANTS

Kinds: function

```text
Return the list of declared variant definitions belonging to a message schema.
```

## ELMTUI.STATE.MSG:MESSAGE-VARIANT-P

Kinds: function

```text
Check whether MESSAGE-INSTANCE uses a registered variant keyword for MESSAGE-TYPE.
```

## ELMTUI.STATE.MSG:MSG-DATA

Kinds: function

```text
Return the data part of message MSG.
If KEY is provided, return the value for KEY in the plist (cdr MSG),
or DEFAULT if KEY is not present. If KEY is not provided, return the plist itself.
```

## ELMTUI.STATE.MSG:MSG-TYPE

Kinds: function

```text
Returns the type of the message MSG.
```

## ELMTUI.STATE.MSG:VARIANT-DEFINITION

Kinds: type

```text
Represents a single message variant definition.
```

## ELMTUI.STATE.MSG:VARIANT-DEFINITION-ARG-SPEC

Kinds: function

```text
Return the optional raw argument specification recorded for a message variant.
```

## ELMTUI.STATE.MSG:VARIANT-DEFINITION-ARGS

Kinds: function

```text
Return the ordered argument descriptors for a declared message variant.
```

## ELMTUI.STATE.MSG:VARIANT-DEFINITION-CONSTRUCTOR-NAME

Kinds: function

```text
Return the symbol naming the constructor generated for this message variant.
```

## ELMTUI.STATE.MSG:VARIANT-DEFINITION-NAME

Kinds: function

```text
Return the canonical keyword name of a declared message variant.
```

## ELMTUI.STATE.UPDATE:*LOG-UPDATE-RESULTS*

Kinds: variable

```text
When T, logs the patches and commands returned by update functions.
```

## ELMTUI.STATE.UPDATE:CMD

Kinds: function

```text
Alias for SEND-COMMAND.
```

## ELMTUI.STATE.UPDATE:CONTEXT-COMMANDS

Kinds: function

```text
Return recorded commands in original order.
```

## ELMTUI.STATE.UPDATE:CONTEXT-PATCHES

Kinds: function

```text
Return recorded patches in original order.
```

## ELMTUI.STATE.UPDATE:DEFUPDATE

Kinds: macro

```text
Define an Elm-style update function.
```

## ELMTUI.STATE.UPDATE:DISPATCH-TO-TOPIC

Kinds: function

```text
Create a command that dispatches a payload to a specific topic.
```

## ELMTUI.STATE.UPDATE:HANDLE-ASYNC-COMMAND

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.UPDATE:MAKE-UPDATE-CONTEXT

Kinds: function

```text
Create an update context with a mutation-isolated draft.

The draft is a deep copy of CL-STATE's supported container graph, not merely a
plist view. UPDATE code may therefore use SREF/SAPPLY/SDELETE destructively on
its draft without changing the model supplied by the runtime. Custom mutable
leaf objects remain application-owned atoms and must be treated as immutable or
copied by the application when strict value semantics are required.
```

## ELMTUI.STATE.UPDATE:MALFORMED-UPDATE-RESULT-ERROR

Kinds: type

```text
Describe an invalid update return without discarding the original values or function designator.
```

## ELMTUI.STATE.UPDATE:MALFORMED-UPDATE-RESULT-FN-NAME

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.UPDATE:MALFORMED-UPDATE-RESULT-REASON

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.UPDATE:MALFORMED-UPDATE-RESULT-VALUES

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.UPDATE:PROCESS-UPDATE-RESULT

Kinds: function

```text
Validate and process values returned by an update function.
```

## ELMTUI.STATE.UPDATE:SAPPLY

Kinds: function

```text
Apply FN to the current value at PATH and store the result.
```

## ELMTUI.STATE.UPDATE:SDELETE

Kinds: function

```text
Delete PATH in the update context.
```

## ELMTUI.STATE.UPDATE:SEND-COMMAND

Kinds: function

```text
Record a command in the update context.
```

## ELMTUI.STATE.UPDATE:SREF

Kinds: function

_No documentation metadata._

## ELMTUI.STATE.UPDATE:UPDATE-CONTEXT

Kinds: type

_No documentation metadata._

## ELMTUI.STYLE.MANAGER:COMPUTE-ACTIVE-STYLESHEET

Kinds: function

```text
Build the effective stylesheet for this frame from STATE.
   Sources (priority high→low):
   - state :current-stylesheet if it is a cl-styles sheet
   - otherwise a default empty sheet
   Variables can be provided at (:style-variables ...) in STATE.
```

## ELMTUI.STYLE.MANAGER:DEFAULT-STYLESHEET

Kinds: function

_No documentation metadata._

## ELMTUI.STYLE.PRESETS:DARK-THEME

Kinds: variable

```text
Predefined dark theme style rules.
```

## ELMTUI.STYLE.PRESETS:LIGHT-THEME

Kinds: variable

```text
Predefined light theme style rules.
```

## ELMTUI.UI.API:+COMPONENT-STATE-ROOT+

Kinds: variable

```text
Canonical root path for component state in app-state.
```

## ELMTUI.UI.API:COMPONENT

Kinds: type

```text
Base class for UI components.
    Arguments:
      ID -- (list) Path list uniquely identifying this component instance.
    Returns:
      COMPONENT instance.
    Example:
      (make-instance 'component :id '(:my-app :main-layout :submit-button))
    (list) => component (pure, no side-effects)
    Side-effects: none (must be pure)
```

## ELMTUI.UI.API:COMPONENT-CHILDREN

Kinds: function

```text
Returns a list of child component *IDs* or *instances*.
   Reads from the :children key in the component's state map in app-state,
   located at (append '(:components) id-path '(:children)).
```

## ELMTUI.UI.API:COMPONENT-HEIGHT

Kinds: function

```text
Returns the height of the component.
   Reads from the :height key in the component's state map in app-state,
   located at (append '(:components) id-path '(:height)).
```

## ELMTUI.UI.API:COMPONENT-ID

Kinds: function

_No documentation metadata._

## ELMTUI.UI.API:COMPONENT-STATE-MAP-PATH

Kinds: function

```text
Generates a path list for accessing the entire state map of a component.
   `id-path`: The path to the component's state within the :components map (e.g., '(:my-comp)).
   Path: '(:components . id-path)

   Arguments:
    `id-path`: A list of keywords/symbols representing the unique path to this component's state map within the `(:components ...)` section of the app-state.
   Returns:
    A list representing the path to the component's state map, starting with '(:components . id-path).

   Example:
    (component-state-map-path '(:my-app :main-layout :submit-button))
    => '(:components :my-app :main-layout :submit-button
```

## ELMTUI.UI.API:COMPONENT-STATE-PATH

Kinds: function

```text
Generates a path list for accessing/updating a specific component property within app-state.

   Arguments:
     ID-PATH      -- (list) Path to the component's state within the :components map.
     PROPERTY-KEY -- (keyword) The key for the specific property.

   Returns:
     (list) Path to the component's property, starting with '(:components . id-path) and ending with the property-key.

   Example:
     (component-state-path '(:my-app :main-layout :submit-button) :label)
     ;; => '(:components :my-app :main-layout :submit-button :label)

   (list, keyword) => list (pure, no side-effects)
   Side-effects: none (must be pure)

```

## ELMTUI.UI.API:COMPONENT-TYPE

Kinds: function

```text
Returns a symbol representing the type of the component.

   Arguments:
     COMPONENT -- (component) The component instance.

   Returns:
     (symbol) The type of the component, used for namespacing state and type-specific logic.

   Example:
     (component-type my-component) ; => :button

   (component) => symbol (pure, no side-effects)
   Side-effects: none (must be pure)

```

## ELMTUI.UI.API:COMPONENT-WIDTH

Kinds: function

```text
Returns the width of the component.
   Reads from the :width key in the component's state map in app-state,
   located at (append '(:components) id-path '(:width)).
```

## ELMTUI.UI.API:DESTROY

Kinds: function

```text
Prepares patches and commands to remove a component and its children from the app-state.
   Returns (values patches commands).
```

## ELMTUI.UI.API:GET-COMPONENT-PROPERTY

Kinds: function

```text
Retrieves a specific property for a component from its namespaced state in global app-state.
   `app-state`: The global application state.
   `id-path`: The path to the component's state within the :components map.
   `property-key`: The key for the specific property.
   Returns the value or default-value.
```

## ELMTUI.UI.API:ID

Kinds: function

```text
Returns the ID of a component or UI node.

   Arguments:
     OBJECT -- (component or ui-node) The object to query.

   Returns:
     (list) The ID path of the object.

   Example:
     (id my-component) ; => '(:my-app :main-layout :submit-button)

   (component|ui-node) => list (pure, no side-effects)
   Side-effects: none (must be pure)

```

## ELMTUI.UI.API:ID-FROM-PATH

Kinds: function

```text
Extracts the last ID from a path list.
   Assumes the last element is the ID keyword or symbol.
```

## ELMTUI.UI.API:INIT

Kinds: function

```text
Initializes a component instance after it has been created.
   This method is responsible for setting up the component's own behavioral state
   in the global application state and for initializing any child components it manages.
   `component`: The component instance (already created by make-instance).
   `id-path`: A list of keywords/symbols representing the unique path to this component's
              state map within the `(:components ...)` section of the app-state.
              Example: '(:my-app :main-layout :submit-button)
   `initargs`: Other initargs passed during component creation.
   Returns (values component patches commands).

   Example usage:
   (init my-component :id-path '(:my-app :main-layout :submit-button)
         :dsl '(:button :label "Submit" :on-click #'submit-handler))
```

## ELMTUI.UI.API:INITIALIZE-COMPONENTS-FROM-DSL

Kinds: function

```text
Recursively traverses a component DSL, instantiates components,
   and returns the accumulated patches and commands.
```

## ELMTUI.UI.API:INSTANTIATE-COMPONENT-FROM-DSL

Kinds: function

_No documentation metadata._

## ELMTUI.UI.API:MAKE-STATE-PATCH

Kinds: function

```text
Creates a single entry for a state patch list: (list path value).
```

## ELMTUI.UI.API:NORMALIZE-UPDATE-ARGS

Kinds: function

```text
Normalize UPDATE arguments so callers may pass either (msg app-state) or (app-state msg).
```

## ELMTUI.UI.API:RESOLVE-COMPONENT-NODE

Kinds: function

```text
Resolves a component into a concrete UI node for layout and rendering.
```

## ELMTUI.UI.API:UPDATE

Kinds: function

```text
Processes a message for a component instance. Returns an `update-result` struct.
```

## ELMTUI.UI.API:VIEW

Kinds: function

```text
Generates a view representation (DSL spec) for a component instance.
```

## ELMTUI.UI.API:WITH-UPDATE-PATCH

Kinds: macro

_No documentation metadata._

## ELMTUI.UI.COMPONENT-METACLASS:CLASS-METADATA

Kinds: function

_No documentation metadata._

## ELMTUI.UI.COMPONENT-METACLASS:COMPONENT-CLASS

Kinds: type

```text
Metaclass for component classes that stores metadata
                   in the class metaobject itself instead of a static registry.
```

## ELMTUI.UI.COMPONENT-METACLASS:MAKE-METADATA

Kinds: function

```text
Create a metadata structure for component classes.

   Arguments:
     PROPS        -- A plist of component properties (e.g., '(:label "Button" :width 100))
     DOCUMENTATION -- A string describing the component
     EXAMPLES     -- A list of example DSL forms showing usage

   Returns:
     A plist containing the metadata fields.

   Example:
     (make-metadata
       :props '(:text "Click me"
                 :on-click handle-click)
       :documentation "A clickable button component"
       :examples '((:button :text "Submit"
                           :on-click submit-form)))
```

## ELMTUI.UI.DEFCOMPONENT:CCLASS-NAME

Kinds: function

```text
Returns a keyword symbol representing the component class type, e.g., :my-button.
```

## ELMTUI.UI.DEFCOMPONENT:DEFCOMPONENT

Kinds: macro

```text
Defines a new UI component class with declarative state, init, update, and view logic.

SYNTAX:
(defcomponent component-name (superclass1 superclass2 ...)
  (:state (slot1-name initial-value1 &key type doc)
          (slot2-name initial-value2 &key type doc)
          ...)

  (:init (props self-id-path)
    (values '(:slot1-name val1) nil))

  (:update (msg state app-state id-path)
    (:increment (amount)
      (values `(:count ,(+ (getf state :count 0) amount)) nil)))

  (:view (local-state-map app-state self-id-path)
    `(:label :id (elmtui.ui.api:id-from-path self-id-path)
             :text (getf local-state-map :text "Default Text View")))

  ...other-class-options...)

```

## ELMTUI.UI.DSL-RESOLUTION:RESOLVE-DSL-TYPE

Kinds: function

```text
Resolve ITEM to a component class with accumulated PROPS.

Returns (values class final-props).

ITEM can be:
- a keyword  : look up via dsl-type generic (recurses)
- a list     : (car list) is the type, (cdr list) are extra props
- a symbol   : it's a class (terminates)

This is the main entry point for DSL resolution. It handles the
initial dispatch based on the type of ITEM.

Examples:
  (resolve-dsl-type 'my-widget)              => MY-WIDGET, NIL
  (resolve-dsl-type :my-variant)             => (via dsl-type method), props
  (resolve-dsl-type '(:my-variant :x 1))     => (via dsl-type method), (:x 1 . props)

When chaining, props are accumulated from right to left:
  (resolve-dsl-type '(:outer :inner)) calls
  (dsl-type :inner) then appends (:outer) to result
```

## ELMTUI.UI.WIDGETS.BUTTON:BUTTON

Kinds: type

```text
A clickable button widget, refactored to the new defcomponent style.
```

## ELMTUI.UI.WIDGETS.COUNTER:COUNTER

Kinds: type

```text
A simple counter widget that can be incremented, decremented, and reset using the new defcomponent style.
```

## ELMTUI.UI.WIDGETS.DRAWABLE-CONTENT:DRAWABLE-CONTENT

Kinds: type

```text
A component that represents directly renderable content, like a string of text.
Its state (content, style) is stored in the application state.
```

## ELMTUI.UI.WIDGETS.DRAWABLE-CONTENT:MAKE-DRAWABLE-CONTENT

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.DRAWABLE-CONTENT:MSG-SET-DRAWABLE-CONTENT

Kinds: variable

_No documentation metadata._

## ELMTUI.UI.WIDGETS.DRAWABLE-CONTENT:MSG-SET-DRAWABLE-STYLE

Kinds: variable

_No documentation metadata._

## ELMTUI.UI.WIDGETS.LABEL:LABEL

Kinds: type

```text
A text label widget, refactored to the new defcomponent style.
```

## ELMTUI.UI.WIDGETS.LAYOUT:LAYOUT

Kinds: type

```text
A versatile component that arranges child components using flexbox or grid layouts, controlled by the :display property.
```

## ELMTUI.UI.WIDGETS.LISTBOX:INIT-LISTBOX

Kinds: function

```text
Initializes a new listbox model.
   Returns (values listbox-model initial-command).
```

## ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL

Kinds: type

```text
Model for a listbox widget.
   ID: Unique identifier.
   ITEMS: List of items to display.
   SELECTED-INDEX: Index of the currently selected item.
   SCROLL-OFFSET: Index of first visible item.
   HEIGHT: Number of visible items.
   ON-SELECT: Message to dispatch when item selected.
```

## ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-HEIGHT

Kinds: function

```text
Return or set the number of visible listbox rows used for paging and scroll calculations.
```

## ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-ID

Kinds: function

```text
Return the identity used to associate this listbox model with its UI widget.
```

## ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-ITEMS

Kinds: function

```text
Return or set the ordered list of items displayed by the listbox.
```

## ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-ON-SELECT

Kinds: function

```text
Return or set the message template dispatched by the listbox when selection changes.
```

## ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-SCROLL-OFFSET

Kinds: function

```text
Return or set the zero-based index of the first visible listbox item.
```

## ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-SELECTED-INDEX

Kinds: function

```text
Return or set the selected zero-based item index, or NIL for no selection.
```

## ELMTUI.UI.WIDGETS.LISTBOX:MSG-LISTBOX-KEY-PRESS

Kinds: variable

```text
Message-type constant :LISTBOX-KEY-PRESS; accepts a :KEY field for Up, Down, Home, End and paging navigation.
```

## ELMTUI.UI.WIDGETS.LISTBOX:MSG-LISTBOX-SCROLL-DOWN

Kinds: variable

```text
Message-type constant :LISTBOX-SCROLL-DOWN; the optional :AMOUNT determines downward scroll steps.
```

## ELMTUI.UI.WIDGETS.LISTBOX:MSG-LISTBOX-SCROLL-UP

Kinds: variable

```text
Message-type constant :LISTBOX-SCROLL-UP; the optional :AMOUNT determines upward scroll steps.
```

## ELMTUI.UI.WIDGETS.LISTBOX:MSG-LISTBOX-SELECT-INDEX

Kinds: variable

```text
Message-type constant :LISTBOX-SELECT-INDEX; supply :INDEX to select an item directly.
```

## ELMTUI.UI.WIDGETS.LISTBOX:MSG-LISTBOX-SET-ITEMS

Kinds: variable

```text
Message-type constant :LISTBOX-SET-ITEMS; supply :ITEMS to replace the list and clamp selection and scroll offset.
```

## ELMTUI.UI.WIDGETS.LISTBOX:UPDATE-LISTBOX

Kinds: function

```text
Updates the listbox model based on a message.
   Returns (values new-listbox-model command-list).
```

## ELMTUI.UI.WIDGETS.LISTBOX:VIEW-LISTBOX

Kinds: function

```text
Creates a UI representation of a listbox.
   APP-STATE: The application state.
   WIDGET-ID: The unique ID for this listbox (required).
   ITEMS: List of items to display. Each item can be a string or a plist with :label.
   HEIGHT: Number of items to display at once.
   SELECTED-INDEX: Index of the currently selected item.
   ON-SELECT: Message to dispatch when an item is selected.
   EMPTY-TEXT: Text to display when the list is empty.
   TOOLTIP: Optional tooltip text to display on hover.
   ARIA-LABEL: Accessibility label for screen readers.
   CLASS: Additional CSS classes to apply.
   WIDTH: Width in columns.

Usage:
   (view-listbox app-state
                   :widget-id :my-listbox
                   :items '("Item 1" "Item 2" "Item 3")
                   :height 5
                   :selected-index 1
                   :on-select (list :msg-type :item-selected)
                   :empty-text "No items available"
                   :tooltip "Select an item"
                   :aria-label "List of items"
                   :class "custom-listbox"
                   :width 20)
```

## ELMTUI.UI.WIDGETS.MODAL-DIALOG:MODAL-DIALOG

Kinds: type

_No documentation metadata._

## ELMTUI.UI.WIDGETS.MODAL-DIALOG:MODAL-DIALOG-INPUT

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.MODAL-DIALOG:MODAL-DIALOG-KIND

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.MODAL-DIALOG:MODAL-DIALOG-LINES

Kinds: function

```text
Return five printable, bounded rows. Designed to work even without z-index
or compositor-level overlays; can replace five host content rows.
```

## ELMTUI.UI.WIDGETS.MODAL-DIALOG:MODAL-DIALOG-P

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.MODAL-DIALOG:MODAL-DIALOG-RETURN-FOCUS

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.MODAL-DIALOG:MODAL-DIALOG-VIEW

Kinds: function

```text
Return five :TEXT DSL nodes for rendering in a normal host layout.
Use the parent update to trap events; these nodes intentionally do not
claim a compositor overlay or implicit focus manager integration.
```

## ELMTUI.UI.WIDGETS.MODAL-DIALOG:MODAL-HANDLE-KEY

Kinds: function

```text
Return (values updated-dialog result). RESULT is NIL while editing,
otherwise a plist with :ACTION, :VALUE and :RETURN-FOCUS.
The parent must not dispatch this key to the application if DIALOG exists.
```

## ELMTUI.UI.WIDGETS.MODAL-DIALOG:OPEN-MODAL-DIALOG

Kinds: function

```text
Create an independent modal session. CHOICES is ((character . action) ...).
A prompt resolves as :ACCEPT with the typed string. Enter on confirmation
resolves as :CANCEL. The parent must route keys here while modal is active.
```

## ELMTUI.UI.WIDGETS.ROOT-VIEWPORT:COMPUTE-VIEW-SIZE

Kinds: function

```text
Return three values:
   1) width - available width for the viewport
   2) height - available height for the viewport
   3) offset-y - vertical offset from top of terminal

```

## ELMTUI.UI.WIDGETS.ROOT-VIEWPORT:MAKE-ROOT-VIEWPORT

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.ROOT-VIEWPORT:ROOT-VIEWPORT

Kinds: type

```text
Stateless root viewport: keeps all runtime in external state via patches.
```

## ELMTUI.UI.WIDGETS.SCROLL-PANEL:MAKE-SCROLL-PANEL

Kinds: function

```text
Create a scroll-panel component instance.

  Parameters:
    ID - Keyword identifier for the component
    INITARGS - Initialization arguments (width, height, content-height, etc.)
```

## ELMTUI.UI.WIDGETS.SCROLL-PANEL:SCROLL-PANEL

Kinds: type

```text
A panel with virtual scrolling - content moves, terminal doesn't scroll.
```

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:INIT-SCROLLABLE-CONTAINER

Kinds: function

```text
Initializes a new scrollable container model.
   Returns (values scrollable-container-model initial-command).
```

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:MSG-SCROLL-CONTAINER-KEY-PRESS

Kinds: variable

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:MSG-SCROLL-CONTAINER-SCROLL

Kinds: variable

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:MSG-SCROLL-CONTAINER-SET-SCROLL

Kinds: variable

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:MSG-SCROLL-CONTAINER-UPDATE-DIMENSIONS

Kinds: variable

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL

Kinds: type

```text
Model for a scrollable container widget.
   ID: Unique identifier.
   SCROLL-TOP: Vertical scroll position.
   SCROLL-LEFT: Horizontal scroll position.
   VIEWPORT-WIDTH: Visible width of the container.
   VIEWPORT-HEIGHT: Visible height of the container.
   CONTENT-WIDTH: Total width of the content.
   CONTENT-HEIGHT: Total height of the content.
   DISABLED: Whether scrolling is disabled.
   SHOW-SCROLLBAR-X: When to show horizontal scrollbar (:auto, :always, :never).
   SHOW-SCROLLBAR-Y: When to show vertical scrollbar (:auto, :always, :never).
   ON-SCROLL: Message to send when scroll position changes.
```

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-CONTENT-HEIGHT

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-CONTENT-WIDTH

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-DISABLED

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-ID

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-ON-SCROLL

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-SCROLL-LEFT

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-SCROLL-TOP

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-SHOW-SCROLLBAR-X

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-SHOW-SCROLLBAR-Y

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-VIEWPORT-HEIGHT

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-VIEWPORT-WIDTH

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:UPDATE-SCROLLABLE-CONTAINER

Kinds: function

```text
Updates the scrollable container model based on a message.
   MSG: The message to process.
   MODEL: The current scrollable-container-model instance.
   Returns (values new-model command-list).
```

## ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:VIEW-SCROLLABLE-CONTAINER

Kinds: function

```text
Creates a UI representation of a scrollable container.
   APP-STATE: The application state.
   WIDGET-ID: The unique ID for this container (required).
   SCROLL-TOP: Vertical scroll position.
   SCROLL-LEFT: Horizontal scroll position.
   VIEWPORT-WIDTH: Visible width of the container.
   VIEWPORT-HEIGHT: Visible height of the container.
   CONTENT-WIDTH: Total width of the content.
   CONTENT-HEIGHT: Total height of the content.
   SHOW-SCROLLBAR-X: When to show horizontal scrollbar (:auto, :always, :never).
   SHOW-SCROLLBAR-Y: When to show vertical scrollbar (:auto, :always, :never).
   DISABLED: Whether scrolling is disabled.
   ON-SCROLL: Message to send when scroll position changes.
   TOOLTIP: Optional tooltip text to display on hover.
   ARIA-LABEL: Accessibility label for screen readers.
   CLASS: Additional CSS classes to apply.
   CHILDREN: Content to be scrolled.
```

## ELMTUI.UI.WIDGETS.TEXTINPUT:MAKE-TEXTINPUT

Kinds: function

```text
Creates a new textinput component instance. ID is for direct use, but in DSL, it's derived.
```

## ELMTUI.UI.WIDGETS.TEXTINPUT:MSG-TEXTINPUT-KEY-PRESS

Kinds: variable

_No documentation metadata._

## ELMTUI.UI.WIDGETS.TEXTINPUT:MSG-TEXTINPUT-SET-VALUE

Kinds: variable

_No documentation metadata._

## ELMTUI.UI.WIDGETS.TEXTINPUT:MSG-TEXTINPUT-SUBMIT

Kinds: variable

_No documentation metadata._

## ELMTUI.UI.WIDGETS.TEXTINPUT:TEXTINPUT

Kinds: type

```text
A text input widget that manages its state (value, cursor position, etc.) externally in the application state.
```

## ELMTUI.UI.WIDGETS.UTILS:DEFWIDGET-VIEW

Kinds: macro

```text
Define a standardized widget view function.

   Arguments:
   - NAME: The name of the view function to define.
   - APP-STATE-VAR: Symbol to bind to the application state.
   - WIDGET-ID-VAR: Symbol to bind to the widget ID (defaults to 'widget-id).
   - MODEL-VAR: Symbol to bind to the model (defaults to 'model).
   - MODEL-PATH: Optional path within app-state to locate the model.
   - ADD-ARGS: Additional arguments to include in the function signature.
   - DOCUMENTATION: Documentation string for the function.
   - BODY: The body of the view function.

   Example:
   (defwidget-view view-button (app-state :model-path 'buttons
                                        :add-args (&key label disabled)
                                        :documentation "Render a button widget.")
     (make-styled-node :type :button
                      :props (list :id widget-id
                                  :label (or label (button-model-label model))
                                  :disabled disabled
                                  :focused is-focused)))
```

## ELMTUI.UI.WIDGETS.UTILS:GET-WIDGET-MODEL

Kinds: function

```text
Retrieves the model for a widget from application state.
   APP-STATE: The application state.
   WIDGET-ID: The ID of the widget to retrieve.
   MODEL-PATH: Optional path to navigate within the app-state.

   Returns the widget model or nil if not found.
```

## ELMTUI.UI.WIDGETS.UTILS:WIDGET-FOCUSED-P

Kinds: function

```text
Determines if a widget currently has focus.
   APP-STATE: The application state.
   WIDGET-ID: The ID of the widget to check.

   Returns t if the widget has focus, nil otherwise.
```

## ELMTUI.UI.WIDGETS.UTILS:WITH-WIDGET-MODEL

Kinds: macro

```text
Binds VAR to the widget model retrieved from app-state and executes BODY.
   Also binds is-focused to whether the widget has focus.

   Example:
     (with-widget-model (button-model app-state widget-id)
       (make-styled-node :type :button :props (list :label (button-model-label button-model))))
```

## ELMTUI.UI.WIDGETS.VIEWPORT:MAKE-VIEWPORT

Kinds: function

_No documentation metadata._

## ELMTUI.UI.WIDGETS.VIEWPORT:VIEWPORT

Kinds: type

```text
A component that manages a scrollable view of a single child component.
Its behavioral state (offsets, dimensions) is in app-state.
It stores the ID of its child component in app-state under :child.
```

## ELMTUI.UTILS:AS

Kinds: function

```text
Convert OBJECT to ENFORCED-TYPE, or return DEFAULT.
```

## ELMTUI.UTILS:BLANK-STRING-P

Kinds: function

```text
Return true when VALUE is NIL, empty, or contains only whitespace.
```

## ELMTUI.UTILS:COERCE-FN

Kinds: function

```text
Quote a symbolic or lambda function designator for macro expansion.
```

## ELMTUI.UTILS:COPY-HASH-TABLE

Kinds: function

```text
Return a shallow copy of TABLE that preserves its hash-table policy.
```

## ELMTUI.UTILS:ENSURE-KEYWORD

Kinds: function

```text
Return VALUE as an uppercase keyword.
```

## ELMTUI.UTILS:ENSURE-LIST

Kinds: function

```text
Return VALUE as a list; NIL remains NIL.
```

## ELMTUI.UTILS:FORMAT-DURATION

Kinds: function

```text
Format SECONDS as a compact human-readable duration.
```

## ELMTUI.UTILS:FORMAT-PERCENTAGE

Kinds: function

```text
Format VALUE as a percentage of TOTAL.
```

## ELMTUI.UTILS:GET-PATH

Kinds: function

```text
Read PATH from DATA through cl-state's canonical path API.
```

## ELMTUI.UTILS:HEX-STR-TO-RGB

Kinds: function

```text
Parse a #RRGGBB string and return (R G B), or NIL for invalid input.
```

## ELMTUI.UTILS:PARSE-PLIST-AND-CHILDREN

Kinds: function

```text
Compatibility alias for SPLIT-PROPS/CHILDREN.
```

## ELMTUI.UTILS:REMOVE-PATH

Kinds: function

```text
Remove PATH through cl-state and return UPDATED-DATA, REMOVEDP.
```

## ELMTUI.UTILS:SET-PATH

Kinds: function

```text
Store VALUE at PATH using cl-state's canonical path implementation.

For an APPLICATION-STATE, update its data slot and return the state.  For raw
containers, return the updated container.
```

## ELMTUI.UTILS:SPLIT-PROPS/CHILDREN

Kinds: function

```text
Split leading keyword/value pairs from positional child forms.

An explicit :CHILDREN property replaces positional children, including when its
value is NIL.
```

## ELMTUI.UTILS:SPLIT-STRING-LITERAL

Kinds: function

```text
Split VALUE on literal SEPARATOR, optionally limiting the number of fields.

LIMIT follows CL-STR's field-count convention: a limit of three performs at
most two splits. Empty fields, including a trailing field, are preserved unless
OMIT-EMPTY is true.
```

## ELMTUI.UTILS:STRING-PREFIX-P

Kinds: function

```text
Return true when VALUE starts with PREFIX according to TEST.
```

## ELMTUI.UTILS:STRUCT->PLIST

Kinds: function

```text
Return OBJECT's effective slots and values as a property list.
```

## ELMTUI.UTILS:TRIM-STRING

Kinds: function

```text
Remove surrounding whitespace from VALUE, preserving NIL.
```

## ELMTUI.VIEW.API:APPLY-DIFF

Kinds: function

```text
Apply DIFF-OPS to the physical terminal via BACKEND.

   Arguments:
     BACKEND         -- (object) Backend instance responsible for IO.
     DIFF-OPS        -- (list) Result of DIFF-BUFFER.
     TERMINAL-ORIGIN -- (list) (x y) top-left corner offset when drawing.

   Returns:
     Implementation-defined (often NIL).

   Example:
     (apply-diff backend diff-ops '(0 0))
     ;; => NIL

   (object, list, list) => any (side-effect: terminal IO)

   Side-effects:
     - May write to terminal or device.

   Purity: impure (performs IO)

```

## ELMTUI.VIEW.API:APPLY-STYLE

Kinds: function

```text
Normalise and merge style information for a tree of UI nodes.

   Arguments:
     RICH-TREE -- (list) Tree produced by RENDER-VIEW.

   Returns:
     Tree of STYLED-UI-NODE objects whose STYLE-MAP slot is complete.
     Must not change tree topology.

   Example:
     (apply-style rich-tree)
     ;; => (STYLED-UI-NODE ...)

   (list) => list[styled-ui-node] (pure, no side-effects)

   Side-effects: none (must be pure)

```

## ELMTUI.VIEW.API:DIFF-BUFFER

Kinds: function

```text
Compute minimal diff operations to transform PREV-BUFFER into CURR-BUFFER.

   Arguments:
     PREV-BUFFER -- (object) Previous back-buffer state.
     CURR-BUFFER -- (object) Current back-buffer state.

   Returns:
     A list or stream of diff operations understood by APPLY-DIFF.

   Example:
     (diff-buffer prev curr)
     ;; => ((:replace ...))

   (object, object) => list[diff-op] (pure, no side-effects)

   Side-effects: none (must be pure)

```

## ELMTUI.VIEW.API:RENDER-TO-BUFFER

Kinds: function

```text
Emit drawing commands into BACKBUFFER from a fully laid-out UI tree.

   Arguments:
     LAID-OUT-TREE -- (list) Fully laid-out tree from LAYOUT-VIEW.
     BACKBUFFER    -- (object) Mutable device-buffer object.

   Returns:
     Implementation-defined (usually BACKBUFFER or NIL).

   Example:
     (render-to-buffer laid-out-tree my-backbuffer)
     ;; => my-backbuffer

   (list, object) => object (side-effect: modifies BACKBUFFER)

   Side-effects:
     - BACKBUFFER contents are updated in-place.

   Purity: impure (mutates BACKBUFFER)

```

## ELMTUI.VIEW.API:RENDER-VIEW

Kinds: function

```text
High-level entry point of the View-pipeline.

   Arguments:
     APP-STATE -- (object) The current application state/model.

   Returns:
     A tree of UI-NODE instances in their rich form (labels, list-boxes, etc).

   Example:
     (render-view my-app-state)
     ;; => (UI-NODE ...)

   (object) => list[ui-node] (pure, no side-effects)

   Side-effects: none (must be pure)

```

## ELMTUI.VIEW.BASE-ELEMENTS:BASE-DSL-ERROR

Kinds: type

```text
Public base dsl error type used to represent structured asynchronous tasks, styles or UI elements.
```

## ELMTUI.VIEW.BASE-ELEMENTS:BASE-DSL-P

Kinds: function

```text
Report whether a value is a valid base declarative UI expression.
```

## ELMTUI.VIEW.BASE-ELEMENTS:BASE-ELEMENT

Kinds: type

```text
Abstract *stateless* layout element.  Concrete
  subclasses add their own slots but never mutate them after
  initialisation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:BASE-ELEMENT-P

Kinds: function

```text
Report whether an object is an ElmTUI base UI element.
```

## ELMTUI.VIEW.BASE-ELEMENTS:COMPUTE-LAYOUT

Kinds: function

```text
Idempotent layout: if the resulting rect matches, return NODE; else return LAID.
```

## ELMTUI.VIEW.BASE-ELEMENTS:CONTAINER-ELEMENT

Kinds: type

```text
Generic layout container holding *children*.  All
  sizing / spacing attributes are purely declarative.
```

## ELMTUI.VIEW.BASE-ELEMENTS:COPY-ELEMENT

Kinds: function

```text
Create a copy of a UI element, preserving its declared properties.
```

## ELMTUI.VIEW.BASE-ELEMENTS:DESCRIBE-ELEMENT-TYPE

Kinds: function

```text
Return descriptive metadata for an element type in the UI DSL.
```

## ELMTUI.VIEW.BASE-ELEMENTS:DSL->OBJECTS

Kinds: function

```text
Translate an Elm-TUI style DSL (a plist/tree of keywords) into
   concrete instances of BASE-ELEMENT subclasses.

   • strings / numbers are left untouched
   • a list that begins with a keyword denotes *one* element
   • a proper list whose first item is *not* a keyword is treated
     as a sequence of sibling elements
```

## ELMTUI.VIEW.BASE-ELEMENTS:DSL-CHILDREN

Kinds: function

```text
Return child DSL forms belonging to the supplied element declaration.
```

## ELMTUI.VIEW.BASE-ELEMENTS:DSL-ELEMENT-TYPE

Kinds: function

```text
Return the element-type keyword encoded in a DSL form.
```

## ELMTUI.VIEW.BASE-ELEMENTS:DSL-PROPERTIES

Kinds: function

```text
Return the property list encoded in a DSL element declaration.
```

## ELMTUI.VIEW.BASE-ELEMENTS:DSL-STATISTICS

Kinds: function

```text
Summarize element kinds and counts in a DSL tree.
```

## ELMTUI.VIEW.BASE-ELEMENTS:ELEMENT-CHILDREN

Kinds: function

```text
Return the children recorded in the element representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:ELEMENT-CLASS

Kinds: function

```text
Return the concrete CLOS class that implements TYPE, or NIL.
```

## ELMTUI.VIEW.BASE-ELEMENTS:ELEMENT-CONTENT-MODEL

Kinds: function

```text
Return the content model recorded in the element representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:ELEMENT-ID

Kinds: function

```text
Return the id recorded in the element representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:ELEMENT-LAYOUT

Kinds: function

```text
Return the layout recorded in the element representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:ELEMENT-LAYOUT-RECT

Kinds: function

```text
Return the layout rect recorded in the element representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:ELEMENT-SIZE

Kinds: function

```text
Return the size recorded in the element representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:ELEMENT-STYLE

Kinds: function

```text
Return the style recorded in the element representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:ELEMENT-TYPE-P

Kinds: function

```text
Report whether the given element has the expected type.
```

## ELMTUI.VIEW.BASE-ELEMENTS:EXPAND-BASE-DSL

Kinds: function

```text
Expand a base DSL declaration into element data for the rendering tree.
```

## ELMTUI.VIEW.BASE-ELEMENTS:EXPAND-DSL-ELEMENT

Kinds: function

```text
Expand a single DSL element and its child declarations.
```

## ELMTUI.VIEW.BASE-ELEMENTS:FIND-ELEMENT-BY-ID

Kinds: function

```text
Find an element with the requested identifier in a descendant tree.
```

## ELMTUI.VIEW.BASE-ELEMENTS:FIND-ELEMENTS-BY-TYPE

Kinds: function

```text
Find descendant elements of the requested element type.
```

## ELMTUI.VIEW.BASE-ELEMENTS:MAKE-DSL-ELEMENT

Kinds: function

```text
Construct a declarative UI element from its type and properties.
```

## ELMTUI.VIEW.BASE-ELEMENTS:MAP-DSL-ELEMENTS

Kinds: function

```text
Recursively apply FUNCTION to each node in the DSL tree, transforming it.
   Returns a new, transformed tree.
```

## ELMTUI.VIEW.BASE-ELEMENTS:MAP-ELEMENTS

Kinds: function

```text
Apply FN to ELEMENT and recurse into CHILDREN (depth-first).
```

## ELMTUI.VIEW.BASE-ELEMENTS:NORMALIZE-BASE-DSL

Kinds: function

```text
Normalize a base UI DSL form to its canonical representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:RECT=

Kinds: function

```text
Return true when rectangles A and B are equal within EPSILON tolerance.
```

## ELMTUI.VIEW.BASE-ELEMENTS:SEPARATOR-ELEMENT

Kinds: type

```text
Visual line used to divide regions.
```

## ELMTUI.VIEW.BASE-ELEMENTS:SEPARATOR-ORIENTATION

Kinds: function

```text
Return the orientation recorded in the separator representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:SEPARATOR-THICKNESS

Kinds: function

```text
Return the thickness recorded in the separator representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:SET-ELEMENT-LAYOUT

Kinds: function

```text
Assign computed layout information to a rendered UI element.
```

## ELMTUI.VIEW.BASE-ELEMENTS:SPACER-ELEMENT

Kinds: type

```text
Empty area for fine-grained layout control.
```

## ELMTUI.VIEW.BASE-ELEMENTS:SPACER-HEIGHT

Kinds: function

```text
Return the height recorded in the spacer representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:SPACER-WIDTH

Kinds: function

```text
Return the width recorded in the spacer representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:TEXT-ALIGN

Kinds: function

```text
Return the align recorded in the text representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:TEXT-COLOR

Kinds: function

```text
Return the color recorded in the text representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:TEXT-CONTENT

Kinds: function

```text
Return the content recorded in the text representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:TEXT-ELEMENT

Kinds: type

```text
Plain text node.
```

## ELMTUI.VIEW.BASE-ELEMENTS:TEXT-WRAP

Kinds: function

```text
Return the wrap recorded in the text representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:TO-DSL

Kinds: function

```text
Render ELEMENT back to the canonical DSL plist
  representation (keywords + properties). Useful for debugging or
  when external code still assumes the old representation.
```

## ELMTUI.VIEW.BASE-ELEMENTS:UPDATE-DSL-ELEMENT

Kinds: function

```text
Update a declarative element with the supplied changed properties.
```

## ELMTUI.VIEW.BASE-ELEMENTS:VALID-PROPERTY-P

Kinds: function

```text
Checks if PROPERTY is a valid initarg for the class corresponding to ELEMENT-TYPE.
```

## ELMTUI.VIEW.BASE-ELEMENTS:VALIDATE-BASE-DSL

Kinds: function

```text
Validate class-backed base DSL nodes (objects or keyword-form elements).
```

## ELMTUI.VIEW.BASE-ELEMENTS:VALIDATE-CHILDREN

Kinds: function

```text
Validate whether the supplied child elements satisfy their parent model.
```

## ELMTUI.VIEW.BASE-ELEMENTS:VALIDATE-CONTENT-MODEL

Kinds: function

```text
Validate an element's allowed content model and constraints.
```

## ELMTUI.VIEW.BASE-ELEMENTS:VALIDATE-DSL-ELEMENT

Kinds: function

```text
Validate one keyword-form DSL element.
```

## ELMTUI.VIEW.BASE-ELEMENTS:VALIDATE-DSL-TREE

Kinds: function

```text
Validate structural correctness of a nested declarative UI tree.
```

## ELMTUI.VIEW.CORE:APPLY-DIFF

Kinds: function

```text
Apply a view diff to a node.
```

## ELMTUI.VIEW.CORE:DEFVIEW

Kinds: macro

```text
Define a pure view function: Model → UiTree.
   Contract: view returns a tree of ui-node objects.
```

## ELMTUI.VIEW.CORE:VIEW-DIFF

Kinds: function

```text
Calculate the minimal set of changes between views.
   Returns a function that can transform old-node into new-node.
```

## ELMTUI.VIEW.CORE:WITH-ARIA

Kinds: macro

```text
Add ARIA attributes to NODE.
```

## ELMTUI.VIEW.CORE:WITH-CHILDREN

Kinds: macro

```text
Set children of NODE.
```

## ELMTUI.VIEW.CORE:WITH-PROPS

Kinds: macro

```text
Add or override properties on NODE.
```

## ELMTUI.VIEW.CORE:WITH-VIEW-CONTEXT

Kinds: macro

```text
Establish a view context with default properties.
```

## ELMTUI.VIEW.DSL:DEFCOMPONENT-DSL

Kinds: macro

```text
Register a new DSL component type and define a helper function for node creation.

DSL-TYPE is a keyword representing the component type (e.g., :root-viewport).
CLASS-NAME is the symbol naming the class associated with this component.

This macro:
+ Defines a dsl-type method for DSL-TYPE that returns CLASS-NAME.
+ Defines a helper function named DSL-TYPE-VIEW (e.g., ROOT-VIEWPORT-VIEW) that constructs a DSL node of this type.
+ Exports the helper function from the current package.

The generated helper function has the signature:
  (DSL-TYPE-VIEW id &rest args &key &allow-other-keys)
where:
  id   -- the identifier for the DSL node
  args -- additional keyword arguments for the node

Example:
  (defcomponent-dsl :root-viewport elmtui.view.base-elements:RootViewport)
  (ROOT-VIEWPORT-VIEW "main" :width 800 :height 600)
  ;; => (:ROOT-VIEWPORT :ID "main" :WIDTH 800 :HEIGHT 600)

This macro is useful for building extensible DSLs, especially for UI or data structure construction.
```

## ELMTUI.VIEW.DSL:DSL->UI-NODE

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.DSL:RENDER-DSL-TO-RESOLVED-TREE

Kinds: function

```text
Resolve DSL to a tree. Only recurse into *children*. Prop values are opaque data.
   Treat a list as a DSL node only if its head keyword is a *known* DSL tag.
```

## ELMTUI.VIEW.ELEMENT:EL/CHILDREN

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:EL/CONTENT

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:EL/DISPLAY

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:EL/ID

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:EL/LAYOUT-RECT

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:EL/PROPS

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:EL/SIZE

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:EL/STYLES

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:EL/STYLES-OF

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:EL/TYPE

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:ELEMENT-P

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.ELEMENT:ENSURE-ELEMENT

Kinds: function

```text
Return X if element-p, otherwise try to adapt or error.
```

## ELMTUI.VIEW.ELEMENT:INTRINSIC-SIZE-OF

Kinds: function

```text
Return a SIZE for NODE based on its content (text length, etc.).
```

## ELMTUI.VIEW.ELEMENT:WITH-ELEMENT

Kinds: macro

```text
Assert OBJ is an element (via protocol); bind VAR to OBJ for BODY.
```

## ELMTUI.VIEW.GEO:=?

Kinds: function

```text
Generic equality check. Adapts behavior based on type.
```

## ELMTUI.VIEW.GEO:AREA

Kinds: function

```text
AREA (OBJ)
Arguments: OBJ -- a size or rectangle
Returns: Area as integer
Example: (area (make-size :w 3 :h 4)) ; => 12
Type: (size|rectangle) => integer
Side-effects: None
Calculate the area of the object (size or rectangle).
```

## ELMTUI.VIEW.GEO:AREA<

Kinds: function

```text
Check if the area of obj1 is less than the area of obj2.
```

## ELMTUI.VIEW.GEO:BORDER

Kinds: function

```text
Return a list of border rectangles within RECTANGLE, optionally selecting :TOP, :BOTTOM, :LEFT or :RIGHT and WIDTH. The :ALL case excludes NIL intersections; invalid side signals an error.
```

## ELMTUI.VIEW.GEO:CLAMP

Kinds: function

```text
Clamps VALUE to be within the range [MIN, MAX].
```

## ELMTUI.VIEW.GEO:CONTAINS-P

Kinds: function

```text
Test whether a rectangle contains a position, two-element (x y) list, or another rectangle. Point right/bottom bounds are exclusive; a contained rectangle uses its full extents.
```

## ELMTUI.VIEW.GEO:CORNER

Kinds: function

```text
Return a new POS at the selected rectangle corner :TOP-LEFT, :TOP-RIGHT, :BOTTOM-LEFT or :BOTTOM-RIGHT. Invalid corner signals an error.
```

## ELMTUI.VIEW.GEO:DIM

Kinds: function

```text
DIM (OBJ DIMENSION)
Arguments: OBJ -- pos, size, or rectangle; DIMENSION -- :x, :y, :w, :h, 0, or 1
Returns: Value of the specified dimension
Type: (pos|size|rectangle, keyword|integer) => integer
Side-effects: None
Get the value of a specific dimension for pos, size, or rectangle.
```

## ELMTUI.VIEW.GEO:DIM-LENGTH

Kinds: function

```text
DIM-LENGTH (RECTANGLE DIMENSION)
Arguments: RECTANGLE -- rectangle, DIMENSION -- :w or :h
Returns: Value of the length component
Type: (rectangle, keyword|integer) => integer
Side-effects: None
Get the length component (:w or :h) of a rectangle's dimension.
```

## ELMTUI.VIEW.GEO:DIM-POS

Kinds: function

```text
DIM-POS (RECTANGLE DIMENSION)
Arguments: RECTANGLE -- rectangle, DIMENSION -- :x or :y
Returns: Value of the position component
Type: (rectangle, keyword|integer) => integer
Side-effects: None
Get the position component (:x or :y) of a rectangle's dimension.
```

## ELMTUI.VIEW.GEO:GROW-VIEW!

Kinds: function

```text
Mutate RECTANGLE using RESIZE-DIMENSION! with positive AMOUNT on SIDE. The actual edge adjustment follows RESIZE-DIMENSION!; inspect :LEFT/:TOP semantics rather than assuming an outward move.
```

## ELMTUI.VIEW.GEO:H

Kinds: function

```text
H (OBJ)
Arguments: OBJ -- a size or rectangle
Returns: Height as integer
Type: (size|rectangle) => integer
Side-effects: None
Get the height of the object (size or rectangle).
```

## ELMTUI.VIEW.GEO:LINE

Kinds: function

```text
Return a one-cell-thick bounding rectangle through two POS endpoints, including both endpoints. Diagonal points signal an error.
```

## ELMTUI.VIEW.GEO:MAKE-POS

Kinds: function

```text
Construct a POS with :X and :Y coordinates, defaulting both to zero. Coordinates use nonnegative integer slots.
```

## ELMTUI.VIEW.GEO:MAKE-RECTANGLE

Kinds: function

```text
Construct a RECTANGLE with :POS and :SIZE slots. Each defaults to the corresponding zero-valued structure.
```

## ELMTUI.VIEW.GEO:MAKE-SIZE

Kinds: function

```text
Construct a SIZE with nonnegative integer :W width and :H height slots, defaulting to zero.
```

## ELMTUI.VIEW.GEO:MOVE!

Kinds: function

```text
Move the object to absolute (x, y) then by relative (dx, dy) (mutating).
```

## ELMTUI.VIEW.GEO:NORMALIZE!

Kinds: function

```text
Adjust a rectangle with negative width or height by shifting its origin and negating the affected dimension; return the mutated rectangle.
```

## ELMTUI.VIEW.GEO:OVERLAP

Kinds: function

```text
Return a newly constructed rectangle for the positive-area intersection of R1 and R2, or NIL if their interiors do not intersect.
```

## ELMTUI.VIEW.GEO:POS

Kinds: function, type

```text
POS (OBJ)
Arguments: OBJ -- a rectangle
Returns: The pos struct of the rectangle
Type: (rectangle) => pos
Side-effects: None
Get the pos struct of the object (rectangle).
```

## ELMTUI.VIEW.GEO:POS-X

Kinds: function

```text
Read the X coordinate of a POS. Its nonnegative integer slot may be updated through (SETF POS-X) .
```

## ELMTUI.VIEW.GEO:POS-Y

Kinds: function

```text
Read the Y coordinate of a POS. Its nonnegative integer slot may be updated through (SETF POS-Y) .
```

## ELMTUI.VIEW.GEO:RECT-DIFF

Kinds: function

```text
Return zero to four rectangles covering the area of R1 outside its intersection with R2. Without overlap, return a list containing R1.
```

## ELMTUI.VIEW.GEO:RECTANGLE

Kinds: type

```text
A RECTANGLE struct represents a rectangle in 2D space.
Arguments: SIZE, POS
Fields:
  SIZE -- A size struct (width/height)
  POS -- A pos struct (x/y)
Example: (make-rectangle :pos (make-pos :x 1 :y 2) :size (make-size :w 3 :h 4))
Type: (rectangle)
Side-effects: None
```

## ELMTUI.VIEW.GEO:RECTANGLE-POS

Kinds: function

```text
Read the POS structure owned by a RECTANGLE. Mutating its slots changes the rectangle origin.
```

## ELMTUI.VIEW.GEO:RECTANGLE-SIZE

Kinds: function

```text
Read the SIZE structure owned by a RECTANGLE. Mutating its slots changes the rectangle dimensions.
```

## ELMTUI.VIEW.GEO:RECTANGLE-UNION

Kinds: function

```text
Return a new bounding rectangle enclosing two input rectangles; this is a bounding box, not a disjoint-region union.
```

## ELMTUI.VIEW.GEO:RECTANGLE-UNION-LIST

Kinds: function

```text
Calculate the union of a list of rectangles.
```

## ELMTUI.VIEW.GEO:RESIZE-DIMENSION!

Kinds: function

```text
Mutate a rectangle edge selected by :SIDE and :AMOUNT. :RIGHT/:BOTTOM add amount to width/height; :LEFT/:TOP shift the origin by amount and subtract it from width/height. Negative resulting dimensions signal an error.
```

## ELMTUI.VIEW.GEO:SHRINK-VIEW!

Kinds: function

```text
Call RESIZE-DIMENSION! with negated AMOUNT on the selected side and return the same rectangle, mutated.
```

## ELMTUI.VIEW.GEO:SIZE

Kinds: function, type

```text
SIZE (OBJ)
Arguments: OBJ -- a rectangle
Returns: The size struct of the rectangle
Type: (rectangle) => size
Side-effects: None
Get the size struct of the object (rectangle).
```

## ELMTUI.VIEW.GEO:VALID-P

Kinds: function

```text
Check if the object (size or rectangle) is valid (non-negative dimensions).
```

## ELMTUI.VIEW.GEO:W

Kinds: function

```text
W (OBJ)
Arguments: OBJ -- a size or rectangle
Returns: Width as integer
Type: (size|rectangle) => integer
Side-effects: None
Get the width of the object (size or rectangle).
```

## ELMTUI.VIEW.GEO:X

Kinds: function

```text
X (OBJ)
Arguments: OBJ -- a pos or rectangle
Returns: X coordinate as integer
Type: (pos|rectangle) => integer
Side-effects: None
Get the x-coordinate of the object (pos or rectangle).
```

## ELMTUI.VIEW.GEO:X2

Kinds: function

```text
X2 (RECTANGLE)
Arguments: RECTANGLE -- rectangle
Returns: X2 coordinate (x + width)
Type: (rectangle) => integer
Side-effects: None
Get the x2 coordinate (x + width) of the rectangle.
```

## ELMTUI.VIEW.GEO:Y

Kinds: function

```text
Y (OBJ)
Arguments: OBJ -- a pos or rectangle
Returns: Y coordinate as integer
Type: (pos|rectangle) => integer
Side-effects: None
Get the y-coordinate of the object (pos or rectangle).
```

## ELMTUI.VIEW.GEO:Y2

Kinds: function

```text
Y2 (RECTANGLE)
Arguments: RECTANGLE -- rectangle
Returns: Y2 coordinate (y + height)
Type: (rectangle) => integer
Side-effects: None
Get the y2 coordinate (y + height) of the rectangle.
```

## ELMTUI.VIEW.LAYOUT:DISPATCH-LAYOUT

Kinds: function

```text
Dispatches to the appropriate layout algorithm based on display type.

  DISPLAY is a keyword (e.g., :grid, :flex) or NIL for block fallback.
  NODE is the element to layout.
  AVAILABLE-RECT is the rectangle available for NODE.
  PARENT-STYLES is the style plist of the parent element, if needed for layout
  algorithms.
```

## ELMTUI.VIEW.LAYOUT:LAYOUT-NODE

Kinds: function

```text
Compute layout for NODE within AVAILABLE-RECT.
```

## ELMTUI.VIEW.LAYOUT:STYLE-VALUE

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.LAYOUT.FLEX:COMPUTE-FLEX-LAYOUT

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.LAYOUT.FLEX:CONTENT-BOX

Kinds: function

```text
Content box = outer minus border and paddings (margins are external).
```

## ELMTUI.VIEW.LAYOUT.GRID:COMPUTE-GRID-LAYOUT

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.LAYOUT.SIZE-UTILS:COMPUTE-LAYOUT

Kinds: function

```text
Compute the layout for a node based on its style and available rect.
   Returns the node with its layout rect set.
```

## ELMTUI.VIEW.LAYOUT.SIZE-UTILS:COMPUTE-SIZE

Kinds: function

```text
Compute border-box size for EL under optional parent CONTENT size (size struct).
```

## ELMTUI.VIEW.LAYOUT.SIZE-UTILS:CONTENT-RECT-OF

Kinds: function

```text
Return ELEMENT’s content box rectangle given its OUTER-RECT.
  OUTER-RECT is a border-box; this subtracts paddings and borders from OUTER-RECT
  and returns the inner content rectangle used for child layout. Does not perform
  any measurement; purely geometric.
```

## ELMTUI.VIEW.LAYOUT.SIZE-UTILS:MEASURE-NODE-INTRINSIC-SIZE

Kinds: function

```text
Return 4 values: (minw maxw minh maxh). Never NIL.
   Rules:
   - number         → that number (clamped)
   - "NN%"        → NN% of container axis (clamped), non-numeric container ⇒ 0
   - :auto | :fill → min-content (min-width/min-height)
   - text           → width≈string length (or wrapped to container-w); height≥1
```

## ELMTUI.VIEW.MEMO:CLEAR-MEMOIZATION-CACHE

Kinds: function

```text
Clear the entire memoization cache or just for a specific function
```

## ELMTUI.VIEW.MEMO:DEFINE-MEMOIZED-COMPONENT

Kinds: macro

```text
Define a memoized component
```

## ELMTUI.VIEW.MEMO:DEFMEMO

Kinds: macro

```text
Define a memoized function
```

## ELMTUI.VIEW.MEMO:MEMO

Kinds: function

```text
Create a memoized version of a function, with customizable keying and cache behavior.

Arguments:
+ ~fn~ :: function
  The function to be memoized. Should accept any number of arguments.
+ ~:key~ :: function (default: ~identity~)
  Function applied to the argument list to produce a cache key. Should accept a list of arguments and return a hashable key.
+ ~:test~ :: function (default: ~equal~)
  Function used to compare cache keys in the hash table.

Return:
+ Returns a function that behaves like ~fn~, but caches results based on the computed key.

Side-effects:
+ Creates a hash table for caching results (local to the returned function).
+ Updates global ~*cache-stats*~ hash table with statistics for ~fn~.
+ Increments cache hit/miss counters in the stats object.
+ Reads global variable ~*memoization-enabled*~ to determine whether to use memoization.

Globals:
+ ~*cache-stats*~ :: hash table mapping functions to their statistics objects.
+ ~*memoization-enabled*~ :: boolean flag controlling whether memoization is enabled.

Behavior:
1. When called, the returned function checks ~*memoization-enabled*~.
2. If enabled, it computes a cache key using ~key~ and looks up the result in the cache.
3. If found, returns the cached value and increments the hit counter.
4. If not found, computes the result, stores it in the cache, increments the miss counter, and returns the result.
5. If memoization is disabled, simply calls ~fn~ with the arguments.

Examples:

;; Example: Memoizing a recursive Fibonacci function
(defun fib (n)
  (if (< n 2) n
      (+ (fib (- n 1)) (fib (- n 2)))))

(setq *memoization-enabled* t)
(setq *cache-stats* (make-hash-table))
(defun make-cache-stats (&key function)
  (list :function function :hits 0 :misses 0))
(defun cache-stats-hits (stats) (getf stats :hits))
(defun cache-stats-misses (stats) (getf stats :misses))

(let ((memo-fib (memo #'fib :key #'identity :test #'eql)))
  (funcall memo-fib 10)) ; => 55

;; Check statistics
(gethash #'fib *cache-stats*) ; => (:function #'fib :hits ... :misses ...)

;; Example: Custom key function for argument normalization
(defun slow-add (a b)
  (sleep 1)
  (+ a b))

(let ((memo-add (memo #'slow-add :key (lambda (args) (sort args #'<)))))
  (funcall memo-add 2 3) ; computes and caches
  (funcall memo-add 3 2)) ; returns cached result (same key)

```

## ELMTUI.VIEW.MEMO:MEMOIZE

Kinds: function

```text
Memoize a component with given props
```

## ELMTUI.VIEW.MEMO:MEMOIZE-COMPONENT

Kinds: function

```text
Create a memoized version of a component
```

## ELMTUI.VIEW.MEMO:WITH-MEMO-STATS

Kinds: macro

```text
Execute BODY and optionally report memoization statistics
```

## ELMTUI.VIEW.MEMO:WITH-MEMOIZATION

Kinds: macro

```text
Execute BODY with memoization enabled
```

## ELMTUI.VIEW.POSITION:COPY-ELEMENT-GRID-COORDINATES

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:COPY-ELEMENT-POSITION

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:DIRECTION-TO-POSITION

Kinds: function

```text
Determines the primary direction from one position to another.
Returns one of :up, :down, :left, :right, or nil if positions are identical.
```

## ELMTUI.VIEW.POSITION:ELEMENT-GRID-COORDINATES

Kinds: function, type

```text
Get the grid coordinates for a UI element.
Returns an element-grid-coordinates struct or nil if grid position is not available.
```

## ELMTUI.VIEW.POSITION:ELEMENT-GRID-COORDINATES-COL

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:ELEMENT-GRID-COORDINATES-COL-SPAN

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:ELEMENT-GRID-COORDINATES-ROW

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:ELEMENT-GRID-COORDINATES-ROW-SPAN

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:ELEMENT-POSITION

Kinds: function, type

```text
Get the position data for a UI element.
Returns an element-position struct or nil if position is not available.
```

## ELMTUI.VIEW.POSITION:ELEMENT-POSITION-BOTTOM

Kinds: function

```text
Get the bottom edge y-coordinate of the element position.
```

## ELMTUI.VIEW.POSITION:ELEMENT-POSITION-CENTER-X

Kinds: function

```text
Get the horizontal center coordinate of the element position.
```

## ELMTUI.VIEW.POSITION:ELEMENT-POSITION-CENTER-Y

Kinds: function

```text
Get the vertical center coordinate of the element position.
```

## ELMTUI.VIEW.POSITION:ELEMENT-POSITION-HEIGHT

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:ELEMENT-POSITION-RIGHT

Kinds: function

```text
Get the right edge x-coordinate of the element position.
```

## ELMTUI.VIEW.POSITION:ELEMENT-POSITION-WIDTH

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:ELEMENT-POSITION-X

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:ELEMENT-POSITION-Y

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:FIND-NEAREST-IN-DIRECTION

Kinds: function

```text
Finds the nearest element in the given direction from the from-element.
elements: List of UI elements with position information
from-element: The reference element
direction: One of :up, :down, :left, :right
Returns: The nearest element in that direction or nil if none found
```

## ELMTUI.VIEW.POSITION:MAKE-ELEMENT-GRID-COORDINATES

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:MAKE-ELEMENT-POSITION

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.POSITION:POSITION-CONTAINS-P

Kinds: function

```text
Returns true if container-pos fully contains element-pos.
```

## ELMTUI.VIEW.POSITION:POSITION-DISTANCE

Kinds: function

```text
Calculates the Euclidean distance between the centers of two positions.
```

## ELMTUI.VIEW.POSITION:POSITIONS-OVERLAP-P

Kinds: function

```text
Returns true if the two positions overlap.
```

## ELMTUI.VIEW.REACTIVE:BOUNCE

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.REACTIVE:CREATE-ANIMATION

Kinds: function

```text
Creates and registers a new animation.

   DURATION: Duration in seconds.
   UPDATE-FN: Function called on each frame with progress (0.0-1.0).
   EASING-FN: Optional easing function to transform progress.
   COMPLETE-FN: Optional function called when animation completes.

   Returns the animation structure.
```

## ELMTUI.VIEW.REACTIVE:CREATE-REACTIVE-VIEW

Kinds: function

```text
Creates a new reactive view that updates when its dependencies change.

   ID: Unique identifier for the view.
   APP-STATE: The application state to observe.
   RENDER-FN: Function that renders the view (app-state -> ui-node).

   Returns the reactive-view instance.
```

## ELMTUI.VIEW.REACTIVE:EASE-IN

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.REACTIVE:EASE-IN-OUT

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.REACTIVE:EASE-OUT

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.REACTIVE:ELASTIC

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.REACTIVE:INVALIDATE-VIEW

Kinds: function

```text
Mark VIEW invalid and enqueue one debounced render request.

Observer callbacks call this function directly, outside the Elm command
interpreter.  The debounce therefore uses CL-EVENTS.ASYNC:SCHEDULE-AFTER rather
than constructing a CMD-ASYNC value that nobody would execute.

Returns the active debounce thread when one is pending, otherwise NIL.
```

## ELMTUI.VIEW.REACTIVE:LINEAR-EASING

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.REACTIVE:MAKE-VIEW-TASK

Kinds: function

```text
Creates a task function that handles rendering for a reactive view.

   VIEW: The reactive-view instance.
   DISPATCH-FN: Function to dispatch messages from the view.

   Returns a function that can be run in a worker thread.
```

## ELMTUI.VIEW.REACTIVE:NEXT-FRAME-CMD

Kinds: function

```text
Return a command that asynchronously sleeps for 1/FPS seconds, then emits MESSAGE.
   Use via (nconc commands (list (reactive:next-frame-cmd :fps 60 :message :tick))).
```

## ELMTUI.VIEW.REACTIVE:PROCESS-ANIMATIONS

Kinds: function

```text
Processes all active animations, updating their progress.
   Should be called on each frame with the time elapsed since the last frame.
```

## ELMTUI.VIEW.REACTIVE:REGISTER-VIEW-DEPENDENCY

Kinds: function

```text
Registers a state path that the view depends on.
   When the state at this path changes, the view will be invalidated.

   VIEW: The reactive-view instance.
   STATE-PATH: A keyword, symbol, or list representing the path in the app-state.
```

## ELMTUI.VIEW.REACTIVE:VIEW-INVALIDATED-P

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.REACTIVE:WITH-REACTIVE-RENDERING

Kinds: macro

```text
Executes body with a reactive view that updates when its dependencies change.

   VIEW-VAR: Symbol to bind to the reactive view instance.
   APP-STATE: The application state to observe.
   RENDER-FN: Function that renders the view (app-state -> ui-node).
   DISPATCH-FN: Function to dispatch messages from the view.
   DEPENDENCIES: List of state paths that the view depends on.

   Example:
     (with-reactive-rendering (counter-view app-state #'render-counter dispatch-fn
                                          :dependencies '(counter-model))
       (add-view-to-layout counter-view main-layout)
       (process-events))
```

## ELMTUI.VIEW.STYLED:APPLY-STYLESHEET-TO-TREE

Kinds: function

```text
Recursively applies styles from STYLESHEET to NODE and its descendants.
    Returns a NEW tree of styled-ui-nodes with styles computed.
    PARENT is the already processed parent for the current NODE.
```

## ELMTUI.VIEW.STYLED:STYLED-UI-NODE

Kinds: type

```text
UI node after stylesheet cascade expansion and normalisation.
```

## ELMTUI.VIEW.STYLED:UI-NODE-CHILDREN

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.STYLED:UI-NODE-PROPS

Kinds: function

_No documentation metadata._

## ELMTUI.VIEW.TREE-TRANSFORMS:LAYOUT-TREE-TOP-DOWN

Kinds: function

```text
Top-down layout: lay out NODE in PARENT-RECT; recurse passing each CHILD'S OWN rect.
   Critical: each child receives its own computed rect, not the parent's rect. If a child
   rect is missing, fall back to the parent's content box once.
```

## ELMTUI.VIEW.TREE-TRANSFORMS:PROCESS-TREE

Kinds: function

```text
Pipeline: resolve → expand styles → measure(top-down) → layout(top-down) → mark-dirty.

   Return the fully processed tree or NIL if resolution failed.

   ARGS:
     ROOT - root node of the tree to process
     :CTX - application context (elmtui.contracts:app-context)
     :ROOT-RECT - rectangle to use as the root layout rectangle; if NIL,
                  ctx.viewport-rect is used.

   STEPS:
     1) Resolve components: convert DSL to base-element instances
     2) Expand element styles: normalize style plists
     3) Measure tree top-down: compute intrinsic sizes
     4) Layout tree top-down: compute layout rects
     5) Mark dirty nodes: flag nodes that changed during processing

   NOTES:
     - If a stylesheet is present in CTX, apply it after style expansion.
     - If ROOT-RECT is not provided, CTX's viewport rectangle is used.
     - If component resolution fails (returns NIL), the entire process aborts
       and NIL is returned.

   RETURNS:
     The fully processed tree with layout information, or NIL if resolution failed.
```

## ELMTUI.VIEW.TREE-TRANSFORMS:RESOLVE-COMPONENTS

Kinds: function

```text
Normalize NODE to object tree: if it's already a base-element tree, return it;
   if it's DSL, resolve components and convert to objects.
```
