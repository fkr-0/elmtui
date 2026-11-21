# cl-events Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the custom message-bus/event-channel layers with a thin cl-events-based registry and update the event loop accordingly.

**Architecture:** Keep cl-events.channel as the single runtime primitive. Replace `event-channel` objects with a registry mapping `name -> cl-events channel` plus optional metadata (priority) in a plain plist. The loop will select from raw channels, dispatching to handlers by name.

**Tech Stack:** Common Lisp, cl-events, FiveAM (tests), ASDF

### Task 1: Add a cl-events channel registry

**Files:**
- Create: `src/core/channel-registry.lisp`
- Test: `tests/channel-registry-tests.lisp`
- Modify: `elmtui.asd`

**Step 1: Write the failing test**

```lisp
(defpackage :elmtui.channel-registry.tests
  (:use :cl :fiveam)
  (:import-from :elmtui.core.channel-registry
    #:make-standard-channels
    #:channel-by-name
    #:send-event
    #:receive-event))

(in-package :elmtui.channel-registry.tests)

(def-suite :channel-registry)
(in-suite :channel-registry)

(test basic-send-receive
  (let* ((registry (make-standard-channels))
         (ch (channel-by-name registry :ui)))
    (send-event ch :hello)
    (is (eql (receive-event ch) :hello))))
```

**Step 2: Run test to verify it fails**

Run: `clpm bundle exec -- sbcl --script run-tests-clpm.lisp`
Expected: FAIL with missing package `elmtui.core.channel-registry` or undefined functions.

**Step 3: Write minimal implementation**

```lisp
(uiop:define-package :elmtui.core.channel-registry
  (:use :cl)
  (:import-from :cl-events.channel #:make-channel #:<- #:->)
  (:export #:make-standard-channels
           #:channel-by-name
           #:send-event
           #:receive-event))

(in-package :elmtui.core.channel-registry)

(defun make-standard-channels ()
  (list (cons :keyboard (make-channel))
        (cons :mouse (make-channel))
        (cons :system (make-channel))
        (cons :ui (make-channel))
        (cons :command (make-channel))
        (cons :focus (make-channel))
        (cons :message (make-channel))))

(defun channel-by-name (registry name)
  (cdr (assoc name registry)))

(defun send-event (chan ev) (-> chan ev))
(defun receive-event (chan) (<- chan))
```

**Step 4: Run test to verify it passes**

Run: `clpm bundle exec -- sbcl --script run-tests-clpm.lisp`
Expected: PASS for `:channel-registry` suite.

**Step 5: Commit**

```bash
git add src/core/channel-registry.lisp tests/channel-registry-tests.lisp elmtui.asd
git commit -m "feat: add cl-events channel registry"
```

### Task 2: Update the event loop to use the cl-events registry

**Files:**
- Modify: `src/core/loop.lisp`
- Modify: `src/core/event-async.lisp`
- Modify: `src/app/application.lisp`
- Modify: `src/platform/driver.lisp`
- Test: `tests/driver-tests.lisp`

**Step 1: Write the failing test**

```lisp
(in-package :elmtui.driver.tests)

(test loop-publishes-ui-events
  (let ((events (with-faketerm-context
                  (send-event (elmtui.core.channel-registry:channel-by-name
                               elmtui.core.loop:*active-event-channels*
                               :ui)
                              :ui-ping)
                  (sleep 0.05))))
    (is (find :ui-ping events :test #'eql))))
```

**Step 2: Run test to verify it fails**

Run: `clpm bundle exec -- sbcl --script run-tests-clpm.lisp`
Expected: FAIL because `*active-event-channels*` is still a list of wrapper objects.

**Step 3: Write minimal implementation**

```lisp
;; In core/loop.lisp
(setf *active-event-channels* (elmtui.core.channel-registry:make-standard-channels))

;; Use channel-by-name and cl-events.channel:select to wait on raw channels
```

**Step 4: Run test to verify it passes**

Run: `clpm bundle exec -- sbcl --script run-tests-clpm.lisp`
Expected: PASS for the new driver test.

**Step 5: Commit**

```bash
git add src/core/loop.lisp src/core/event-async.lisp src/app/application.lisp src/platform/driver.lisp tests/driver-tests.lisp
git commit -m "refactor: loop uses cl-events channel registry"
```

### Task 3: Remove custom message-bus/event-channel layers

**Files:**
- Delete: `src/core/event-channels.lisp`
- Delete: `src/core/message-bus.lisp`
- Delete: `src/core/topic-subscription.lisp`
- Modify: `elmtui.asd`
- Modify: `src/app/tea-core.lisp`
- Modify: `src/app/application.lisp`

**Step 1: Write the failing test**

```lisp
(in-package :elmtui.driver.tests)

(test no-event-channel-deps
  (is-true (null (find-package :cleve-elm.core.event-channels))))
```

**Step 2: Run test to verify it fails**

Run: `clpm bundle exec -- sbcl --script run-tests-clpm.lisp`
Expected: FAIL because the package still loads via ASDF.

**Step 3: Write minimal implementation**

```lisp
;; Remove ASDF components and imports that reference event-channels/message-bus
```

**Step 4: Run test to verify it passes**

Run: `clpm bundle exec -- sbcl --script run-tests-clpm.lisp`
Expected: PASS for `no-event-channel-deps`.

**Step 5: Commit**

```bash
git add elmtui.asd src/app/tea-core.lisp src/app/application.lisp
git rm src/core/event-channels.lisp src/core/message-bus.lisp src/core/topic-subscription.lisp
git commit -m "chore: remove custom message bus and event channels"
```

### Task 4: Clean up remaining event compatibility layers

**Files:**
- Delete: `src/core/event-compat.lisp`
- Delete: `src/core/event-filter.lisp`
- Delete: `src/core/event-pipeline.lisp`
- Modify: `elmtui.asd`
- Test: `tests/pipeline-contract-tests.lisp`

**Step 1: Write the failing test**

```lisp
(in-package :elmtui.pipeline.tests)

(test no-legacy-event-compat
  (is-true (null (find-package :elmtui.core.event-compat))))
```

**Step 2: Run test to verify it fails**

Run: `clpm bundle exec -- sbcl --script run-tests-clpm.lisp`
Expected: FAIL because the package still loads via ASDF.

**Step 3: Write minimal implementation**

```lisp
;; Remove ASDF components and any remaining imports.
```

**Step 4: Run test to verify it passes**

Run: `clpm bundle exec -- sbcl --script run-tests-clpm.lisp`
Expected: PASS for `no-legacy-event-compat`.

**Step 5: Commit**

```bash
git add elmtui.asd tests/pipeline-contract-tests.lisp
git rm src/core/event-compat.lisp src/core/event-filter.lisp src/core/event-pipeline.lisp
git commit -m "chore: drop legacy event compatibility layers"
```

### Task 5: Consolidate cl-inputs usage in platform modules

**Files:**
- Modify: `src/platform/input.lisp`
- Modify: `src/platform/driver.lisp`
- Modify: `src/platform/backend/terminal/terminal.lisp`
- Modify: `src/platform/backend/terminal/diff-renderer.lisp`
- Modify: `src/platform/backend/faketerm/faketerm.lisp`
- Modify: `src/platform/backend/urxvt/urxvt.lisp`
- Test: `tests/driver-tests.lisp`

**Step 1: Write the failing test**

```lisp
(in-package :elmtui.driver.tests)

(test input-loop-uses-single-cl-inputs-entrypoint
  (let ((events (with-faketerm-context
                  (cl-inputs.device.faketerm:faketerm-inject!
                   (driver-context-device ctx)
                   (cl-inputs.util:string-to-utf-8-bytes "a"))
                  (sleep 0.05))))
    (is (plusp (length events)))))
```

**Step 2: Run test to verify it fails**

Run: `clpm bundle exec -- sbcl --script run-tests-clpm.lisp`
Expected: FAIL until the input loop and backends consistently use cl-inputs entrypoints.

**Step 3: Write minimal implementation**

```lisp
;; Standardize on cl-inputs.* APIs for device creation, tokenization, and IO:
;; - input.lisp owns token->event conversion
;; - terminal backend owns device lifecycle and IO
;; - driver owns the input loop and event publish path
;; Remove ad-hoc or duplicated helper paths, but keep cl-inputs throughout.
```

**Step 4: Run test to verify it passes**

Run: `clpm bundle exec -- sbcl --script run-tests-clpm.lisp`
Expected: PASS for `input-loop-uses-single-cl-inputs-entrypoint`.

**Step 5: Commit**

```bash
git add src/platform/input.lisp src/platform/driver.lisp \
  src/platform/backend/terminal/terminal.lisp \
  src/platform/backend/terminal/diff-renderer.lisp \
  src/platform/backend/faketerm/faketerm.lisp \
  src/platform/backend/urxvt/urxvt.lisp tests/driver-tests.lisp
git commit -m "refactor: consolidate cl-inputs usage in platform layer"
```
