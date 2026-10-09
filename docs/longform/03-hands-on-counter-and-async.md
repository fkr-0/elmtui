# Hands-on ElmTUI: a pure counter, then an async lookup

This chapter starts with the smallest useful TEA application and then extends the same state-machine thinking to asynchronous I/O. It intentionally uses the supported minimal `deftea-app` adapter so the transition is visible without the full application configuration surface. For production/new next-major applications, `defapplication` is the normative constructor; the concepts and runtime transition contract taught here are the same.

The first goal is not a visually elaborate terminal. It is to make the application's semantics so obvious that update behavior can be tested before a terminal exists.

## 1. Build the counter as a state machine first

Start with ordinary Common Lisp functions.

```lisp
(uiop:define-package :examples.pure-counter
  (:use :cl)
  (:import-from :elmtui.app.tea-core
                #:deftea-app))

(in-package :examples.pure-counter)
```

The model is a plist:

```lisp
(defun init-counter ()
  (values '(:count 0) nil))
```

`INIT-COUNTER` returns two values because `deftea-app` expects:

```text
INIT-FN :: () -> (values MODEL COMMANDS)
```

There is no startup effect, so commands are `NIL`.

## 2. Write a replacement-based update

```lisp
(defun update-counter (message model)
  (let ((count (getf model :count 0)))
    (case message
      (:increment
       (values (list :count (1+ count)) nil))
      (:decrement
       (values (list :count (1- count)) nil))
      (:reset
       (values '(:count 0) nil))
      (otherwise
       (values model nil)))))
```

The important property is not the plist. It is that branches which change state create a fresh model.

Check that property immediately:

```lisp
(let ((before (list :count 10)))
  (multiple-value-bind (after commands)
      (update-counter :increment before)
    (assert (= 10 (getf before :count)))
    (assert (= 11 (getf after :count)))
    (assert (not (eq before after)))
    (assert (null commands))))
```

This is the cheapest and most valuable counter test. It proves the application decision without loading a terminal backend.

## 3. Add a view

A minimal TEA view returns ElmTUI DSL data. `deftea-app` expects the root viewport ID in the view tree to agree with the application declaration.

```lisp
(defun view-counter (model)
  `(:root-viewport
    :id :counter-root
    :children
    ((:text
      :id :counter-value
      :content ,(format nil "Count: ~D" (getf model :count 0))))))
```

The important architectural fact is:

```text
MODEL -> DSL-TREE
```

`VIEW-COUNTER` does not print. It does not read keys. It does not change the count. Rendering remains downstream.

## 4. Declare the application

```lisp
(deftea-app pure-counter
  :init #'init-counter
  :transition #'update-counter
  :view #'view-counter
  :root-viewport-id :counter-root)
```

The macro creates:

```text
*PURE-COUNTER-APP-SPEC*
RUN-PURE-COUNTER
```

The generated runner delegates to the normal ElmTUI application runtime. The default generated platform selector is `:tty`. `:transition` is the canonical spelling; legacy `:update` remains accepted only for compatibility.

For application code, keep `INIT-COUNTER`, `UPDATE-COUNTER`, and `VIEW-COUNTER` named and separately testable. The `deftea-app` form should remain a compact wiring declaration for this minimal path; move to `defapplication` when the application needs the production state/component/CLI/keymap surface.

## 5. Where do increment/decrement messages come from?

There are several reasonable sources:

```text
application keymap
component-local keymap
button component
synthetic test event
async/effect completion
```

The built-in `elmtui.ui.widgets.counter:counter` demonstrates component-local keyboard routing: `+`/`=` dispatch `:increment`, `-` dispatches `:decrement`, and Enter dispatches `:reset` to the component path.

For an application-level pure counter, keep the application update vocabulary the same and translate keys to those messages at the input/keymap boundary. Do not make the update function inspect raw terminal bytes.

A conceptual keymap is:

```text
+ / =  -> :increment
-      -> :decrement
0 / r  -> :reset
q      -> quit/shutdown message
```

The exact placement of those bindings depends on whether the counter is an application action or a focused component action.

## 6. The first useful tests

### Update semantics

```lisp
(test counter-increment-is-pure
  (let ((before (list :count 2)))
    (multiple-value-bind (after commands)
        (update-counter :increment before)
      (is (= 2 (getf before :count)))
      (is (= 3 (getf after :count)))
      (is-false (eq before after))
      (is (null commands)))))
```

### Unknown message is stable

```lisp
(test counter-ignores-unknown-message
  (let ((before (list :count 2)))
    (multiple-value-bind (after commands)
        (update-counter :something-else before)
      (is (eq before after))
      (is (null commands)))))
```

Returning the same object when no state changes is fine: strict TEA does not require allocating a new object for a no-op. It requires not destructively changing the old model.

### View reflects model

Call the view directly and inspect the returned DSL. You do not need a terminal to prove that the count appears in the view data.

## 7. From counter to async application: add an explicit state machine

A network query has more states than a counter. Model them rather than hiding them in a callback.

For a Wikipedia-style summary lookup:

```lisp
(defun init-search ()
  (values '(:query "Common Lisp"
            :status :idle
            :request-id 0
            :result nil
            :error nil)
          nil))
```

A robust status vocabulary is:

```text
:idle
:loading
:ready
:failed
```

Track a request ID. Without it, a slow response for an old query can overwrite a newer request.

## 8. Define message shapes before writing I/O

Use explicit data:

```lisp
'(:query-changed "Elm architecture")
:submit-query
'(:lookup-succeeded :request-id 4 :result "...")
'(:lookup-failed :request-id 4 :condition condition)
```

The effect lifecycle is now visible in the model and test suite.

## 9. Update emits a lookup command

A pure update can look like this:

```lisp
(defun update-search (message model)
  (case (if (consp message) (first message) message)
    (:query-changed
     (destructuring-bind (_ query) message
       (declare (ignore _))
       (values (list :query query
                     :status :idle
                     :request-id (getf model :request-id 0)
                     :result (getf model :result)
                     :error nil)
               nil)))

    (:submit-query
     (let* ((request-id (1+ (getf model :request-id 0)))
            (query (getf model :query "")))
       (values (list :query query
                     :status :loading
                     :request-id request-id
                     :result (getf model :result)
                     :error nil)
               (list (list :lookup-wikipedia query request-id)))))

    (:lookup-succeeded
     (destructuring-bind (_ &key request-id result) message
       (declare (ignore _))
       ;; Ignore stale completion from an older request.
       (if (= request-id (getf model :request-id))
           (values (list :query (getf model :query)
                         :status :ready
                         :request-id request-id
                         :result result
                         :error nil)
                   nil)
           (values model nil))))

    (:lookup-failed
     (destructuring-bind (_ &key request-id condition) message
       (declare (ignore _))
       (if (= request-id (getf model :request-id))
           (values (list :query (getf model :query)
                         :status :failed
                         :request-id request-id
                         :result (getf model :result)
                         :error condition)
                   nil)
           (values model nil))))

    (otherwise
     (values model nil))))
```

Notice what is absent: no HTTP client call.

`UPDATE-SEARCH` only emits:

```lisp
(:lookup-wikipedia query request-id)
```

That command can be asserted in a unit test.

## 10. Test the request transition without a network

```lisp
(test submit-produces-one-lookup-command
  (let ((before '(:query "Common Lisp"
                  :status :idle
                  :request-id 8
                  :result nil
                  :error nil)))
    (multiple-value-bind (after commands)
        (update-search :submit-query before)
      (is (eq :idle (getf before :status)))
      (is (eq :loading (getf after :status)))
      (is (= 9 (getf after :request-id)))
      (is (equal '((:lookup-wikipedia "Common Lisp" 9))
                 commands)))))
```

This test is deterministic and fast.

## 11. Test stale-response protection

```lisp
(test stale-result-does-not-replace-newer-request
  (let ((current '(:query "CLOS"
                   :status :loading
                   :request-id 12
                   :result nil
                   :error nil)))
    (multiple-value-bind (after commands)
        (update-search
         '(:lookup-succeeded :request-id 11 :result "old")
         current)
      (is (eq current after))
      (is (null commands)))))
```

This one small rule prevents a common async UI race.

## 12. Put the transport behind an adapter

ElmTUI should not require one HTTP library merely to express the application architecture. Define an injected operation:

```lisp
(defvar *fetch-summary-fn*
  (lambda (query)
    (error "No Wikipedia transport configured for ~S" query)))
```

Production code can bind/install a transport adapter. Tests replace it with a deterministic function:

```lisp
(let ((*fetch-summary-fn*
        (lambda (query)
          (format nil "Fake summary for ~A" query))))
  ...)
```

This is especially useful in Common Lisp because dynamic binding can make test adapters concise without introducing a global singleton dependency into application logic.

## 13. Build the effect using `cmd-async`

The current `elmtui.core.async:cmd-async` contract expects the task function to accept a progress callback as its first argument, followed by `:args`.

A lookup command can be translated into:

```lisp
(defun lookup-command->async (query request-id)
  (elmtui.core.async:cmd-async
   (lambda (progress query)
     (funcall progress `(:lookup-progress
                         :request-id ,request-id
                         :phase :requesting))
     (funcall *fetch-summary-fn* query))
   :args (list query)
   :on-complete
   (lambda (result)
     `(:lookup-succeeded
       :request-id ,request-id
       :result ,result))
   :on-error
   (lambda (condition)
     `(:lookup-failed
       :request-id ,request-id
       :condition ,condition))))
```

The important application contract remains:

```text
command -> effect -> result message -> update
```

The transport can change without changing the update state machine.

## 14. Keep progress optional and declarative

`cmd-async` supplies a progress callback. Progress messages can update a model field if useful:

```lisp
'(:lookup-progress :request-id 12 :phase :requesting)
'(:lookup-progress :request-id 12 :phase :parsing)
```

Do not emit progress updates at a frequency that makes rendering dominate useful work. The UI needs meaningful progress states, not telemetry spam.

## 15. Represent errors twice: user state and Lisp condition

A good failure has two representations with different jobs.

### User-visible model state

```text
status: failed
message: "Could not load the summary. Press r to retry."
```

### Inspectable condition

The condition should retain details such as:

```text
operation = :lookup-wikipedia
query = "Common Lisp"
request-id = 12
underlying-condition = socket/TLS/HTTP/parse failure
suggestions/recovery metadata
```

Do not stringify the underlying condition too early. A debugger or handler can do much more with the original object.

## 16. Offer recovery where it is semantically valid

Suppose the transport has a cached summary. A handler can select a `USE-VALUE` restart around the operation:

```lisp
(defun fetch-with-cache (query cached-value)
  (handler-bind
      ((elmtui.core.errors:elmtui-error
         (lambda (condition)
           (format *debug-io* "Live lookup failed: ~A~%" condition)
           (when cached-value
             (invoke-restart 'use-value cached-value)))))
    (elmtui.core.conditions:with-recovery
        (elmtui.core.errors:elmtui-error
         :restarts '(:retry :use-value :abort))
      (funcall *fetch-summary-fn* query))))
```

The framework's restart e2e now verifies the same important machinery: an outer handler sees the original condition object while `USE-VALUE` is active, and recovery returns the supplied value.

### When `RETRY` is safe

A read-only HTTP GET-like lookup is often safe to retry from the application's point of view, subject to transport/server semantics.

### When `RETRY` is not automatically safe

Do not apply the same policy blindly to:

```text
payments
writes
message sending
file replacement
remote commands
non-idempotent APIs
```

A restart name is not a transaction guarantee.

## 17. View the async state explicitly

A simple view can branch on status:

```lisp
(defun search-status-text (model)
  (ecase (getf model :status)
    (:idle "Type a topic and submit.")
    (:loading "Loading summary...")
    (:ready (or (getf model :result) "No summary."))
    (:failed "Lookup failed. Press r to retry.")))
```

Then the main view can display:

```text
query input
submit button / key hint
status line
result viewport
error/retry affordance
```

This is better UX than freezing the terminal until a network call returns.

## 18. Counter + async have the same architecture

The two applications look very different to a user, but their core is identical.

Counter:

```text
:increment
   -> update
   -> count + 1
   -> view
```

Async lookup:

```text
:submit-query
   -> update
   -> loading model + lookup command
   -> async effect
   -> :lookup-succeeded / :lookup-failed
   -> update
   -> ready/failed model
   -> view
```

The second system is not a different architecture. It is the first architecture with an effect cycle inserted.

## 19. A useful development sequence

When building a real ElmTUI screen, work in this order:

1. Write the model/state names.
2. Write the message vocabulary.
3. Write update transitions with no terminal/network I/O.
4. Test transitions, including no-op and stale-result cases.
5. Write view from the model.
6. Add commands as data.
7. Implement adapters/effects behind replaceable functions.
8. Test effect success/failure with fakes.
9. Add conditions and legitimate restarts.
10. Wire keys/components to messages.
11. Run faketerm/runtime e2e.
12. Only then use a real terminal/network integration test where the environment permits it.

This order keeps UI polish from hiding state-machine bugs.

## 20. What e2e should prove

A mature counter/async example should eventually have four e2e layers.

### Pure state e2e

```text
message sequence
-> expected models
-> old models unchanged where strict TEA requires it
```

### Effect e2e with fake transport

```text
submit
-> command
-> fake transport
-> success/failure message
-> resulting model
```

### Rendering e2e with faketerm

```text
synthetic input
-> route
-> update
-> command handling
-> view/render
-> stable fake screen
```

### Optional live integration

```text
real tty / real HTTP
```

Live integration should be opt-in when it depends on a controlling TTY, network, credentials, or external service. Deterministic correctness must not depend on it.

## 21. Final counter checklist

A first counter is complete when:

```text
[ ] init returns a model + commands
[ ] increment/decrement/reset are messages
[ ] update returns a replacement model for changes
[ ] tests prove the old model is unchanged
[ ] view only describes UI
[ ] keys/buttons route to messages
[ ] quit/shutdown follows runtime lifecycle
[ ] faketerm/runtime integration test renders the new count
```

## 22. Final async checklist

An async lookup is complete when:

```text
[ ] status is explicit: idle/loading/ready/failed
[ ] each request has an id
[ ] stale results are ignored
[ ] update emits command data, not network I/O
[ ] transport is injected/replaceable
[ ] completion/failure returns as messages
[ ] original conditions remain inspectable
[ ] retry/use-value exists only where semantically safe
[ ] user sees loading/error/retry state
[ ] deterministic fake-transport tests cover success and failure
[ ] real network test is optional
```

That is the practical path from “hello counter” to a responsive terminal application without giving up the simple reasoning model that makes TEA valuable.
