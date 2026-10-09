# clevelib -> cl-events Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove clevelib usage from `elmtui.lisp/src` and migrate core event, channel, async, and messaging flows to cl-events-native APIs with no compatibility layer.

**Architecture:** Replace clevelib channel/async/event-loop/message abstractions with cl-events primitives plus optional messaging envelopes. Update core wrappers (event-channels, loop, async interpreter, message-bus/topic-subscription) to use cl-events directly and drop clevelib dependencies from packages and ASDF.

**Tech Stack:** Common Lisp, ASDF, cl-events (local), FiveAM (tests where feasible)

---

### Task 1: Inventory + test harness for migration

**Files:**
- Modify: `elmtui.lisp/elmtui.asd` (remove clevelib deps later)
- Create: `elmtui.lisp/tests/core-event-channels-tests.lisp`
- Create: `elmtui.lisp/tests/core-async-tests.lisp`

**Step 1: Write failing test for event-channel wait-for-event**

```lisp
(in-package :elmtui.tests)

(def-suite :elmtui/core-event-channels :in :elmtui/tests)
(in-suite :elmtui/core-event-channels)

(test wait-for-event-basic
  (let* ((ch (elmtui.core.event-channels:make-keyboard-channel))
         (_ (elmtui.core.event-channels:send-event ch :evt)))
    (multiple-value-bind (evt src)
        (elmtui.core.event-channels:wait-for-event (list ch) :timeout 0.1)
      (is (eql :evt evt))
      (is (eq ch src)))))
```

**Step 2: Run test to verify it fails**

Run: `clpm bundle exec --with-client sbcl -- --non-interactive --eval '(asdf:test-system :elmtui-tests)'`
Expected: FAIL (tests not yet wired or current implementation blocks/uses clevelib)

**Step 3: Write failing test for async cmd promise flow**

```lisp
(in-package :elmtui.tests)

(def-suite :elmtui/core-async :in :elmtui/tests)
(in-suite :elmtui/core-async)

(test async-cmd-resolves
  (let* ((cmd (elmtui.core.async:cmd-async (lambda (_cb) 42)))
         (promise (getf (cdr cmd) :promise)))
    ;; promise should resolve after task runs
    (elmtui.core.async:interpret-cmd cmd)
    (is (= 42 (cl-events.async:await promise)))))
```

**Step 4: Run test to verify it fails**

Run: `clpm bundle exec --with-client sbcl -- --non-interactive --eval '(asdf:test-system :elmtui-tests)'`
Expected: FAIL (clevelib-based promise/task mismatch)

**Step 5: Commit**

```bash
git add elmtui.lisp/tests/core-event-channels-tests.lisp elmtui.lisp/tests/core-async-tests.lisp
git commit -m "tests: add core migration characterization tests"
```

---

### Task 2: Replace clevelib channels in core event-channels

**Files:**
- Modify: `elmtui.lisp/src/core/event-channels.lisp`
- Test: `elmtui.lisp/tests/core-event-channels-tests.lisp`

**Step 1: Update package imports to cl-events**

Replace:
```lisp
(:import-from :cleve-elm.channel :make-channel :make-filtered-channel :channel-add-filter :-> :<- :select)
```
With:
```lisp
(:import-from :cl-events.channel :make-channel :make-filtered-channel :channel-add-filter :-> :<- :select :no-wait)
```

**Step 2: Remove name args to channel constructors**

In `initialize-instance`, update to:
```lisp
(setf (channel-of ec)
      (if ec-filters
          (make-filtered-channel :filters ec-filters :capacity ec-capacity)
          (make-channel :capacity ec-capacity)))
```

**Step 3: Replace cleve-elm.queue usage**

Remove `:cleve-elm.queue` dependency and any `make-priority-queue` references if unused.

**Step 4: Run tests**

Run: `clpm bundle exec --with-client sbcl -- --non-interactive --eval '(asdf:test-system :elmtui-tests)'`
Expected: core-event-channels tests pass.

**Step 5: Commit**

```bash
git add elmtui.lisp/src/core/event-channels.lisp
git commit -m "core: migrate event-channels to cl-events"
```

---

### Task 3: Replace clevelib async in core async interpreter

**Files:**
- Modify: `elmtui.lisp/src/core/async.lisp`
- Test: `elmtui.lisp/tests/core-async-tests.lisp`

**Step 1: Update package imports**

Replace clevelib async imports with cl-events:
```lisp
(:import-from :cl-events.async
 :async-task :new-task :async-exec :cancel
 :async-task-finished-p :async-task-result :async-task-status
 :async-task-error :promise-cancelled-p :promise-cancel
 :promise :make-promise :resolve-promise :reject-promise :await)
```

**Step 2: Replace promise construction + cancellation**

Update `cmd-async` to build a cl-events promise and handle timeout via `schedule-after`:
```lisp
(let* ((promise (make-promise))
       (timeout-thread (when timeout
                         (cl-events.async:schedule-after
                          timeout (lambda () (promise-cancel promise))))))
  ...)
```

**Step 3: Replace cleve-elm conditions**

Define a local condition for cancelled promises in `elmtui.core.async` and use it in error paths. Remove `promise-cancelled-condition` import.

**Step 4: Run tests**

Run: `clpm bundle exec --with-client sbcl -- --non-interactive --eval '(asdf:test-system :elmtui-tests)'`
Expected: `async-cmd-resolves` passes.

**Step 5: Commit**

```bash
git add elmtui.lisp/src/core/async.lisp
git commit -m "core: migrate async cmd interpreter to cl-events"
```

---

### Task 4: Replace clevelib channels in core loop

**Files:**
- Modify: `elmtui.lisp/src/core/loop.lisp`

**Step 1: Update package imports**

Replace clevelib channel imports with cl-events:
```lisp
(:import-from :cl-events.channel :-> :<- :chan-close :no-wait)
```

**Step 2: Replace channel-closed/length/queue usage**

Remove uses of `cleve-elm.channel:channel-closed`, `channel-queue`, `channel-length`. For shutdown, attempt `chan-close` and ignore errors. For stats, return `0` if unavailable.

**Step 3: Run tests**

Run: `clpm bundle exec --with-client sbcl -- --non-interactive --eval '(asdf:test-system :elmtui-tests)'`
Expected: all tests pass.

**Step 4: Commit**

```bash
git add elmtui.lisp/src/core/loop.lisp
git commit -m "core: migrate loop channel usage to cl-events"
```

---

### Task 5: Replace clevelib message-bus/topic-subscription/event-filter

**Files:**
- Modify: `elmtui.lisp/src/core/message-bus.lisp`
- Modify: `elmtui.lisp/src/core/topic-subscription.lisp`
- Modify: `elmtui.lisp/src/core/event-filter.lisp`

**Step 1: Update imports to cl-events.messaging and cl-events.channel**

Use `cl-events.messaging:expand-message` for propagation envelopes and `cl-events.channel` for channel ops.

**Step 2: Replace cleve-elm.message usage**

Where cleve-elm messages are constructed/inspected, switch to cl-events `message` or application-specific structs with protocol methods (`broadcast-p`, `capture-p`, `bubble-p`).

**Step 3: Run tests**

Add targeted tests if needed or rely on existing suites.

**Step 4: Commit**

```bash
git add elmtui.lisp/src/core/message-bus.lisp elmtui.lisp/src/core/topic-subscription.lisp elmtui.lisp/src/core/event-filter.lisp
git commit -m "core: migrate message bus/filter/subscription to cl-events"
```

---

### Task 6: Replace clevelib usage in app/view/platform

**Files:**
- Modify: `elmtui.lisp/src/app/application.lisp`
- Modify: `elmtui.lisp/src/app/tea-core.lisp`
- Modify: `elmtui.lisp/src/view/reactive.lisp`
- Modify: `elmtui.lisp/src/platform/driver.lisp`

**Step 1: Swap cleve-elm imports for cl-events**

For channel ops, use `cl-events.channel` (`->`, `<-`, `make-channel`).
For async, use `cl-events.async`.

**Step 2: Run tests**

Run: `clpm bundle exec --with-client sbcl -- --non-interactive --eval '(asdf:test-system :elmtui-tests)'`

**Step 3: Commit**

```bash
git add elmtui.lisp/src/app/application.lisp elmtui.lisp/src/app/tea-core.lisp elmtui.lisp/src/view/reactive.lisp elmtui.lisp/src/platform/driver.lisp
git commit -m "app: migrate clevelib usage to cl-events"
```

---

### Task 7: Remove clevelib from build

**Files:**
- Modify: `elmtui.lisp/elmtui.asd`
- Modify: `elmtui.lisp/src/clevelib/*.lisp` (delete)
- Modify: `elmtui.lisp/src/packages` as needed

**Step 1: Remove clevelib components from ASDF**

Delete `src/clevelib/*` components and dependencies.

**Step 2: Delete `src/clevelib/` directory**

```bash
rm -rf elmtui.lisp/src/clevelib
```

**Step 3: Run tests**

Run: `clpm bundle exec --with-client sbcl -- --non-interactive --eval '(asdf:test-system :elmtui-tests)'`

**Step 4: Commit**

```bash
git add -A elmtui.lisp/elmtui.asd elmtui.lisp/src/clevelib
git commit -m "core: remove clevelib from build"
```

---

### Task 8: Final migration verification

**Step 1: Run full test suite**

Run: `clpm bundle exec --with-client sbcl -- --non-interactive --eval '(asdf:test-system :elmtui-tests)'`
Expected: PASS

**Step 2: Smoke test example app (optional)**

Run: `clpm bundle exec --with-client sbcl -- --non-interactive --load run_clpm.lisp`
Expected: app launches, no clevelib errors.

**Step 3: Commit (if any last fixes)**

```bash
git add -A
git commit -m "core: finalize cl-events migration"
```
