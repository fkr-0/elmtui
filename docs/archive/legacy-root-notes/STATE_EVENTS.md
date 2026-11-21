Alright, let’s carve this up cleanly. Below is a **drop-in scaffold** for three split subsystems with tidy protocols, packages, and working skeletons:

* **cl-events** — event bus + channels + async tasks + the TEA app loop (orchestrator).
* **cl-input** — terminal input (and optional output) decoding into semantic events; plugs into cl-events.
* **cl-state** — state container + patches + transactions + undo/redo + observers (+ optional SQLite journal hook).

Everything is small, pure where it matters, and thoroughly commented so you can wire to your existing files (`events.lisp`, `message-bus.lisp`, etc.) without drama.

---

# cl-events — Event system + TEA orchestrator

## Goals

* Single place for **events → messages → update → commands → effects**.
* Async primitives: channels, mailboxes, timers, worker pool.
* Thin thread abstraction (Bordeaux Threads), but you can swap it.
* App loop that you can own/replace; **update** and **view** remain application code.

## ASDF

```lisp
;;; cl-events.asd
(asdf:defsystem "cl-events"
  :description "Event bus, channels, async tasks, and TEA app loop."
  :license "MIT" :version "0.1.0"
  :depends-on (#:alexandria #:bordeaux-threads #:trivial-timers #:uiop)
  :components
  ((:file "src/events/packages")
   (:file "src/events/protocols")      ; client contracts
   (:file "src/events/types")          ; event/message structs
   (:file "src/events/channel")        ; channels/mailboxes
   (:file "src/events/bus")            ; pub-sub by topic
   (:file "src/events/dispatcher")     ; event→message, message→update
   (:file "src/events/async")          ; timers, tasks, futures
   (:file "src/events/loop")           ; TEA app loop
   (:file "src/events/api")))
```

## Packages

```lisp
;;; src/events/packages.lisp
(uiop:define-package :cl-events.protocols
  (:use :cl :alexandria)
  (:export
   ;; Object→topic/key extraction
   #:event-topic #:event-payload #:event-timestamp
   ;; Event→Message translation
   #:translate-event->messages
   ;; Update + View contracts (app supplies these)
   #:app-update #:app-view
   ;; Render side-effect hook
   #:perform-render
   ;; Command execution (effects)
   #:perform-command))

(uiop:define-package :cl-events.types
  (:use :cl :alexandria)
  (:export
   ;; Event
   #:event #:make-event #:event-type #:event-data #:event-when
   ;; Message (pure signal consumed by app update)
   #:message #:make-message #:message-type #:message-data
   ;; Command (effectful instruction emitted by update)
   #:command #:make-command #:command-type #:command-args))

(uiop:define-package :cl-events.channel
  (:use :cl :alexandria :bordeaux-threads)
  (:export
   #:channel #:make-channel #:chan-put #:chan-take #:chan-close
   #:mailbox #:make-mailbox #:mb-put #:mb-take #:mb-empty-p))

(uiop:define-package :cl-events.bus
  (:use :cl :alexandria :cl-events.channel :cl-events.protocols :cl-events.types)
  (:export
   #:event-bus #:make-event-bus #:publish-event #:subscribe #:unsubscribe
   #:with-subscription))

(uiop:define-package :cl-events.dispatcher
  (:use :cl :alexandria :cl-events.protocols :cl-events.types :cl-events.bus)
  (:export
   #:dispatch-event #:dispatch-message-batch #:execute-commands))

(uiop:define-package :cl-events.async
  (:use :cl :alexandria :bordeaux-threads :trivial-timers :cl-events.types :cl-events.bus)
  (:export
   #:spawn-task #:future #:await #:cancel
   #:schedule-after #:schedule-every))

(uiop:define-package :cl-events.loop
  (:use :cl :alexandria :cl-events.bus :cl-events.dispatcher :cl-events.protocols
        :cl-events.types :cl-events.channel :cl-events.async)
  (:export
   #:run-app-loop #:stop-app-loop
   #:app-context #:make-app-context))

(uiop:define-package :cl-events.api
  (:use :cl)
  (:reexport :cl-events.protocols :cl-events.types :cl-events.channel
             :cl-events.bus :cl-events.dispatcher :cl-events.async
             :cl-events.loop))
```

## Protocols (client must implement/update/view/commands; everything else is pluggable)

```lisp
;;; src/events/protocols.lisp
(in-package :cl-events.protocols)

;; Minimal info we require from an Event object (or adapter).
(defgeneric event-topic (event))      ; e.g., :input, :timer, :network/<id>
(defgeneric event-payload (event))    ; arbitrary payload
(defgeneric event-timestamp (event))  ; universal-time or monotonic

;; Translate an Event to 0..N Messages (pure).
(defgeneric translate-event->messages (event app-state)
  (:documentation "Return a list of MESSAGES produced by EVENT."))

;; App-provided update: (state msg) -> (values new-state commands)
(defgeneric app-update (state message)
  (:documentation "Pure update. Returns NEW-STATE and a list of COMMANDs."))

;; App-provided view: (state) -> view-model (your DSL or render tree)
(defgeneric app-view (state)
  (:documentation "Pure view function producing a renderable tree."))

;; The renderer side-effect hook. You can adapt this to your renderer.
(defgeneric perform-render (view-model app-state)
  (:documentation "Render VIEW-MODEL. May consult APP-STATE for metrics."))

;; Side-effects execution. Each command type is a pluggable effect.
(defgeneric perform-command (command app-context)
  (:documentation "Run effect; may publish events back to the bus."))
```

## Types

```lisp
;;; src/events/types.lisp
(in-package :cl-events.types)

(defstruct event   type data when)
(defun make-event (type data &optional (when (get-universal-time)))
  (make-event :type type :data data :when when))
(defun event-type (e) (event-type e))
(defun event-data (e) (event-data e))
(defun event-when (e) (event-when e))

(defstruct message type data)
(defun make-message (type &optional data) (make-message :type type :data data))

(defstruct command type args)
(defun make-command (type &rest args) (make-command :type type :args args))
```

## Channels & Mailboxes (bounded, blocking; you can swap in your existing ones)

```lisp
;;; src/events/channel.lisp
(in-package :cl-events.channel)

(defstruct channel queue lock not-empty not-full capacity closed-p)

(defun make-channel (&key (capacity 256))
  (make-channel :queue (make-array capacity :adjustable nil :fill-pointer 0)
                :lock (bt:make-lock "chan-lock")
                :not-empty (bt:make-condition-variable)
                :not-full  (bt:make-condition-variable)
                :capacity capacity))

(defun chan-put (ch item)
  (bt:with-lock-held ((channel-lock ch))
    (loop while (and (>= (fill-pointer (channel-queue ch)) (channel-capacity ch))
                     (not (channel-closed-p ch)))
          do (bt:condition-wait (channel-not-full ch) (channel-lock ch)))
    (when (channel-closed-p ch) (return-from chan-put nil))
    (vector-push-extend item (channel-queue ch))
    (bt:condition-notify (channel-not-empty ch))
    t))

(defun chan-take (ch)
  (bt:with-lock-held ((channel-lock ch))
    (loop while (and (zerop (fill-pointer (channel-queue ch)))
                     (not (channel-closed-p ch)))
          do (bt:condition-wait (channel-not-empty ch) (channel-lock ch)))
    (when (and (zerop (fill-pointer (channel-queue ch))) (channel-closed-p ch))
      (values nil :closed))
    (let* ((q (channel-queue ch))
           (item (aref q 0)))
      (replace q q :start1 0 :start2 1 :end2 (fill-pointer q))
      (decf (fill-pointer q))
      (bt:condition-notify (channel-not-full ch))
      item)))

(defun chan-close (ch)
  (bt:with-lock-held ((channel-lock ch))
    (setf (channel-closed-p ch) t)
    (bt:condition-broadcast (channel-not-empty ch))
    (bt:condition-broadcast (channel-not-full ch))
    t))

;;; Simple mailbox (single-slot, last-writer-wins)
(defstruct mailbox slot lock cv closed-p)

(defun make-mailbox () (make-mailbox :lock (bt:make-lock "mb") :cv (bt:make-condition-variable)))
(defun mb-put (mb item)
  (bt:with-lock-held ((mailbox-lock mb))
    (setf (mailbox-slot mb) item)
    (bt:condition-broadcast (mailbox-cv mb))
    t))
(defun mb-take (mb)
  (bt:with-lock-held ((mailbox-lock mb))
    (loop while (and (null (mailbox-slot mb)) (not (mailbox-closed-p mb)))
          do (bt:condition-wait (mailbox-cv mb) (mailbox-lock mb)))
    (prog1 (mailbox-slot mb) (setf (mailbox-slot mb) nil))))
(defun mb-empty-p (mb) (null (mailbox-slot mb)))
```

## Event Bus (topics with channel fanout)

```lisp
;;; src/events/bus.lisp
(in-package :cl-events.bus)

(defstruct subscriber topic ch)
(defstruct event-bus subs lock)

(defun make-event-bus () (make-event-bus :subs (make-hash-table :test 'equal)
                                         :lock (bt:make-lock "bus")))

(defun subscribe (bus topic)
  (let ((ch (cl-events.channel:make-channel)))
    (bt:with-lock-held ((event-bus-lock bus))
      (push (make-subscriber :topic topic :ch ch)
            (gethash topic (event-bus-subs bus))))
    ch))

(defun unsubscribe (bus topic ch)
  (bt:with-lock-held ((event-bus-lock bus))
    (setf (gethash topic (event-bus-subs bus))
          (remove ch (gethash topic (event-bus-subs bus))
                  :key #'subscriber-ch :test #'eq))))

(defmacro with-subscription ((ch bus topic) &body body)
  `(let ((,ch (subscribe ,bus ,topic)))
     (unwind-protect (progn ,@body)
       (unsubscribe ,bus ,topic ,ch))))

(defun publish-event (bus event)
  (let* ((topic (cl-events.protocols:event-topic event))
         (subs  (copy-list (gethash topic (event-bus-subs bus)))))
    (dolist (s subs)
      (cl-events.channel:chan-put (subscriber-ch s) event))
    t))
```

## Dispatcher (event→message→update, and commands execution)

```lisp
;;; src/events/dispatcher.lisp
(in-package :cl-events.dispatcher)

(defun dispatch-event (event bus state)
  (declare (ignore bus)) ; you can route back to bus inside perform-command
  (let ((msgs (cl-events.protocols:translate-event->messages event state)))
    (dispatch-message-batch msgs state)))

(defun dispatch-message-batch (messages state)
  "Apply messages in order; return (values new-state commands)"
  (let ((cmds '())
        (st state))
    (dolist (m messages)
      (multiple-value-bind (st2 c2)
          (cl-events.protocols:app-update st m)
        (setf st st2
              cmds (nconc cmds c2))))
    (values st cmds)))

(defun execute-commands (commands app-ctx)
  "Run effects; effects may publish further events."
  (dolist (cmd commands)
    (cl-events.protocols:perform-command cmd app-ctx)))
```

## Async utilities

```lisp
;;; src/events/async.lisp
(in-package :cl-events.async)

(defun spawn-task (fn &key name)
  (bt:make-thread fn :name (or name "task")))

(defun future (fn)
  (let ((mb (cl-events.channel:make-mailbox)))
    (spawn-task (lambda () (cl-events.channel:mb-put mb (funcall fn))))
    mb))

(defun await (mb) (cl-events.channel:mb-take mb))
(defun cancel (_task) (declare (ignore _task)) nil) ;; extend with your task handle

(defun schedule-after (seconds fn)
  (trivial-timers:make-timer fn seconds))

(defun schedule-every (seconds fn)
  (let ((t (trivial-timers:make-timer fn seconds :repeat t)))
    t))
```

## App loop (the orchestrator)

```lisp
;;; src/events/loop.lisp
(in-package :cl-events.loop)

(defstruct app-context
  bus          ;; event-bus
  event-ch     ;; merged input channel
  stop-flag    ;; mailbox or flag
  render-lock) ;; optional if renderer isn't thread-safe

(defun make-app-context (&key bus event-ch)
  (make-app-context :bus (or bus (cl-events.bus:make-event-bus))
                    :event-ch (or event-ch (cl-events.channel:make-channel))
                    :stop-flag (cl-events.channel:make-mailbox)
                    :render-lock (bt:make-lock "render")))

(defun run-app-loop (&key initial-state app-ctx)
  (let* ((ctx (or app-ctx (make-app-context)))
         (state initial-state)
         (bus (app-context-bus ctx))
         (ech (app-context-event-ch ctx)))
    (labels ((tick ()
               ;; 1) take next event
               (multiple-value-bind (ev status)
                   (cl-events.channel:chan-take ech)
                 (when (eq status :closed) (return-from tick))
                 ;; 2) dispatch event -> messages -> update
                 (multiple-value-bind (new-state cmds)
                     (cl-events.dispatcher:dispatch-event ev bus state)
                   (setf state new-state)
                   ;; 3) view + render (outside update, on main loop)
                   (let ((vm (cl-events.protocols:app-view state)))
                     (bt:with-lock-held ((app-context-render-lock ctx))
                       (cl-events.protocols:perform-render vm state)))
                   ;; 4) run side-effects
                   (cl-events.dispatcher:execute-commands cmds ctx))
                 (when (cl-events.channel:mb-take (app-context-stop-flag ctx))
                   (return-from tick))))
             (loop-body ()
               (loop do (tick))))
      (spawn-task #'loop-body :name "app-loop")
      ctx)))

(defun stop-app-loop (ctx)
  (cl-events.channel:mb-put (app-context-stop-flag ctx) t)
  (cl-events.channel:chan-close (app-context-event-ch ctx))
  t)
```

## API façade

```lisp
;;; src/events/api.lisp
(in-package :cl-events.api) ;; reexport-only package in packages.lisp
```

---

# cl-input — Terminal input (and optional output) → Events

## Goals

* Isolate all TTY specifics (termios, escape decoding) behind a tiny driver protocol.
* Emit **cl-events** `event`s with topic `:input` and structured payloads (`:key`, `:mouse`, `:resize`, etc.).
* (Optional) provide a small output driver for ANSI writes so you can split rendering too.

## ASDF

```lisp
;;; cl-input.asd
(asdf:defsystem "cl-input"
  :description "Terminal input decoding and device drivers."
  :license "MIT" :version "0.1.0"
  :depends-on (#:alexandria #:uiop #:cl-events #:trivial-utf-8)
  :components
  ((:file "src/input/packages")
   (:file "src/input/protocols")
   (:file "src/input/keymap")      ; maps escape sequences → semantic keys
   (:file "src/input/decoder")     ; parser for bytes → events
   (:file "src/input/driver")      ; default TTY driver (raw mode, read loop)
   (:file "src/input/api")))
```

## Packages + Protocol

```lisp
;;; src/input/packages.lisp
(uiop:define-package :cl-input.protocols
  (:use :cl :alexandria)
  (:export
   ;; Device abstraction
   #:open-device #:close-device #:device-read-bytes
   #:enable-raw-mode #:disable-raw-mode
   ;; Output (optional, for symmetry)
   #:device-write-bytes))

(uiop:define-package :cl-input.api
  (:use :cl :alexandria :cl-events.api :cl-input.protocols)
  (:export
   #:start-input-reader #:stop-input-reader
   #:default-keymap #:decode-bytes->event))
```

### Protocol generics (you can adapt your existing `driver.lisp`)

```lisp
;;; src/input/protocols.lisp
(in-package :cl-input.protocols)

(defgeneric open-device (&key stream) (:documentation "Return device handle."))
(defgeneric close-device (dev))
(defgeneric enable-raw-mode (dev))
(defgeneric disable-raw-mode (dev))
(defgeneric device-read-bytes (dev buffer start end) ; return n-bytes or :eof
(defgeneric device-write-bytes (dev buffer start end))
```

### Decoder & keymap (sketch)

```lisp
;;; src/input/keymap.lisp
(in-package :cl-input.api)

(defparameter *default-keymap*
  '((#.(list #\Esc #\[ #\A) (:key :up))
    (#.(list #\Esc #\[ #\B) (:key :down))
    ;; … add more …
    ))

(defun default-keymap () *default-keymap*)

(defun %match-seq (bytes)
  (loop for (seq event) in *default-keymap*
        when (alexandria:sequence-equal seq bytes :test #'=)
          do (return event)))

;;; src/input/decoder.lisp
(in-package :cl-input.api)

(defun decode-bytes->event (octets &key (timestamp (get-universal-time)))
  "Return an input EVENT or NIL if incomplete; keep a small buffer in caller."
  (let ((semantic (%match-seq octets)))
    (when semantic
      (cl-events.types:make-event :input (list :kind :key :data semantic) timestamp))))
```

### Reader loop that **publishes to cl-events bus**

```lisp
;;; src/input/driver.lisp
(in-package :cl-input.api)

(defstruct reader dev thread stop?)

(defun start-input-reader (bus &key (device (open-device)) (keymap (default-keymap)))
  (declare (ignore keymap)) ; wired into decode
  (enable-raw-mode device)
  (let ((r (make-reader :dev device)))
    (setf (reader-thread r)
          (bt:make-thread
           (lambda ()
             (let ((buf (make-array 8 :element-type '(unsigned-byte 8)))
                   (acc '()))
               (unwind-protect
                    (loop until (reader-stop? r) do
                      (let ((n (device-read-bytes device buf 0 8)))
                        (when (or (eql n :eof) (null n)) (return))
                        ;; naive: assume we read a complete key; in practice maintain ACC
                        (let* ((bytes (loop for i below n collect (aref buf i)))
                               (ev (decode-bytes->event bytes)))
                          (when ev (cl-events.bus:publish-event bus ev)))))
                 (disable-raw-mode device))))
           :name "input-reader"))
    r))

(defun stop-input-reader (reader)
  (setf (reader-stop? reader) t)
  (close-device (reader-dev reader))
  t)
```

---

# cl-state — State container, patches, transactions, undo/redo, observers

## Goals

* Keep TEA’s purity: `(update state msg) -> (values new-state commands)`
* A formal **patch** model; **transactions** with rollback; **undo/redo** stacks; **observers**; optional **SQLite journaling** hook.

## ASDF

```lisp
;;; cl-state.asd
(asdf:defsystem "cl-state"
  :description "State container, patches, transactions, undo/redo, observers."
  :license "MIT" :version "0.1.0"
  :depends-on (#:alexandria #:uiop #:cl-prevalence) ; or your sqlite layer later
  :components
  ((:file "src/state/packages")
   (:file "src/state/patch")
   (:file "src/state/tx")
   (:file "src/state/undo")
   (:file "src/state/observer")
   (:file "src/state/api")))
```

## Packages

```lisp
;;; src/state/packages.lisp
(uiop:define-package :cl-state.patch
  (:use :cl :alexandria)
  (:export
   #:patch #:make-patch #:patch-path #:patch-op #:patch-value
   #:apply-patch #:apply-patches #:diff-states))

(uiop:define-package :cl-state.tx
  (:use :cl :alexandria :cl-state.patch)
  (:export
   #:tx-context #:make-tx-context
   #:with-transaction #:tx-commit #:tx-rollback))

(uiop:define-package :cl-state.undo
  (:use :cl :alexandria :cl-state.patch)
  (:export
   #:undo-stack #:redo-stack #:push-snapshot #:undo #:redo))

(uiop:define-package :cl-state.observer
  (:use :cl :alexandria :cl-state.patch)
  (:export
   #:add-observer #:remove-observer #:notify-observers))

(uiop:define-package :cl-state.api
  (:use :cl)
  (:reexport :cl-state.patch :cl-state.tx :cl-state.undo :cl-state.observer))
```

## Patch model (path ops, pure)

```lisp
;;; src/state/patch.lisp
(in-package :cl-state.patch)

(defstruct patch path op value)
;; path: list designating a place in your state (e.g., (:components :main :count))
;; op  : :set | :update | :remove | :merge (extend as needed)
;; value: depends on op

(defun apply-patch (state p)
  (ecase (patch-op p)
    (:set    (alexandria:plist-tree:setf* state (patch-path p) (patch-value p)))
    (:remove (alexandria:plist-tree:remf* state (patch-path p)))
    (:merge  (let* ((cur (alexandria:plist-tree:getf* state (patch-path p)))
                    (new (alexandria:alist-plist (patch-value p))))
               (alexandria:plist-tree:setf* state (patch-path p) (append new cur))))
    (:update (let* ((cur (alexandria:plist-tree:getf* state (patch-path p)))
                    (fn (patch-value p)))
               (alexandria:plist-tree:setf* state (patch-path p) (funcall fn cur)))))
  state)

(defun apply-patches (state patches)
  (reduce #'apply-patch patches :initial-value state))

(defun diff-states (old new)
  "Very naive: returns :set patches where values differ."
  (declare (ignore old new)) ; implement your keyed diff as needed
  '())
```

*(If you already have your patch structure, keep it—just export your functions through `cl-state.api` for consistency.)*

## Transactions

```lisp
;;; src/state/tx.lisp
(in-package :cl-state.tx)

(defstruct tx-context base-state patches committed?)
(defun make-tx-context (state) (make-tx-context :base-state state :patches '()))

(defmacro with-transaction ((tx state) &body body)
  `(let ((,tx (make-tx-context ,state)))
     (unwind-protect
          (progn ,@body (tx-commit ,tx))
       (unless (tx-committed? ,tx) (tx-rollback ,tx)))))

(defun tx-commit (tx)
  (setf (tx-committed? tx) t)
  (values (cl-state.patch:apply-patches (tx-context-base-state tx) (tx-context-patches tx))
          (tx-context-patches tx)))

(defun tx-rollback (tx) (values (tx-context-base-state tx) nil))
```

## Undo/Redo (snapshot-based; swap to inverse-patches if you already have them)

```lisp
;;; src/state/undo.lisp
(in-package :cl-state.undo)

(defstruct history past future)

(defun push-snapshot (hist state)
  (push state (history-past hist)) (setf (history-future hist) nil) hist)

(defun undo (hist current)
  (when (history-past hist)
    (let ((prev (pop (history-past hist))))
      (push current (history-future hist))
      prev)))

(defun redo (hist current)
  (when (history-future hist)
    (let ((next (pop (history-future hist))))
      (push current (history-past hist))
      next)))
```

## Observers

```lisp
;;; src/state/observer.lisp
(in-package :cl-state.observer)
(defvar *observers* (make-hash-table :test 'eq))

(defun add-observer (key fn) (push fn (gethash key *observers*)) t)
(defun remove-observer (key fn)
  (setf (gethash key *observers*) (remove fn (gethash key *observers*))) t)

(defun notify-observers (key old new patches)
  (dolist (fn (gethash key *observers*)) (funcall fn old new patches)))
```

---

# How the three subsystems click together

* **cl-input** reads bytes → decodes to **cl-events** `event` with `:input` topic → `publish-event`.
* **cl-events** app loop **takes events**, calls your **translate-event->messages**, then **app-update**, then renders via **perform-render** and executes **commands** (which may publish new events).
* **cl-state** is used by your **app-update** implementation to generate **patches/transactions**, fill **undo/redo**, notify observers, etc.

**Event→Message translation** is your encapsulation point between “device-land” and “domain-land.” For example:

```lisp
(defmethod cl-events.protocols:translate-event->messages ((ev cl-events.types:event) state)
  (destructuring-bind (kw &rest data) (cl-events.types:event-data ev)
    (case kw
      (:key (list (cl-events.types:make-message :ui/key data)))
      (:resize (list (cl-events.types:make-message :ui/resize data)))
      (t nil))))
```

**Update** is pure and returns commands:

```lisp
(defmethod cl-events.protocols:app-update (state (msg cl-events.types:message))
  (case (cl-events.types:message-type msg)
    (:ui/key
     (let ((patch (cl-state.patch:make-patch :path '(:counter) :op :update
                                              :value (lambda (x) (1+ (or x 0))))))
       (values (cl-state.patch:apply-patches state (list patch))
               (list (cl-events.types:make-command :beep)))))
    (t (values state nil))))
```

**Commands** perform effects and can re-enter the bus:

```lisp
(defmethod cl-events.protocols:perform-command ((cmd cl-events.types:command) ctx)
  (ecase (cl-events.types:command-type cmd)
    (:beep (uiop:run-program '("printf" "\a") :ignore-error-status t))))
```

---

# Migration notes for your existing files

Map your current modules roughly like this:

* `events.lisp`, `event-types.lisp`, `message-bus.lisp`, `event-async.lisp`, `topics.lisp`, `threads.lisp`, `loop.lisp`
  → **cl-events** (`types`, `bus`, `async`, `protocols`, `loop`).

* `input.lisp`, `base-keymap.lisp`, terminal driver bits
  → **cl-input** (`keymap`, `decoder`, `driver`).

* Your **patch/transaction/undo logging** logic
  → **cl-state** (`patch`, `tx`, `undo`, `observer`), plus optional `cl-state-sqlite` later.

This split keeps the **Elm core contract** intact:

* **App** owns `update` and `view`.
* **cl-events** orchestrates, **cl-input** feeds, **cl-state** gives you robust state tools.

---

If you want, I can tailor the stubs to your exact patch type and your existing ANSI/terminal driver so it compiles in one go in your tree. Just say which pieces you want me to wire first (bus vs. loop vs. input).


Great instinct. You absolutely don’t want `cl-input` to depend on `cl-events`. The cleanest way is to make `cl-input` a **hexagonal/ports-and-adapters** module with:

* a **pure, functional core** (bytes → tokens),
* a tiny **device port** (termios/tty),
* an **output/sink port** that *you* control.

Then, any app can plug a sink that emits *whatever* it wants (messages, events, logs, stats), and you can ship optional adapters (e.g. `cl-input-adapters.events`) outside the core.

Below is a concrete, idiomatic design and API that hits your goals while staying TEA-friendly and fully decoupled.

---

# Recommendation (TL;DR)

1. **Keep `cl-input` pure + push/pull neutral**

   * **Pure decoder**: `(decode-chunk decoder bytes) → (values tokens new-decoder)`.
   * **Stateless tokens** (structs) with `:kind` `:data` `:ts`.
   * **No event/message types**—only input tokens.

2. **Expose two ports** (no third-party deps):

   * **Device Port** generics: open/close/read/write/raw-mode.
   * **Sink Port** generics: a single `accept-token` (+ optional `on-key`/`on-mouse` granularity).
     Default methods are no-ops; you can also pass a plain function as sink.

3. **Offer both Push *and* Pull modes**:

   * **Push**: `start-input-loop :sink <fn-or-sink>` reads, decodes, and pushes tokens to your sink(s).
   * **Pull**: `make-input-source` returns a source object with `next-token` (blocking or timed).

4. **Adapters live elsewhere**:

   * `cl-input-adapters.events` depends on `cl-input` + `cl-events` and implements a sink that publishes to the event bus.
   * `cl-input-adapters.channel` emits to your own channel/queue.
   * None of these contaminate `cl-input`.

This is a common, established pattern (hexagonal architecture + functional core + adapter sinks). It gives you maximal freedom and testability.

---

# `cl-input` — ASDF + packages

```lisp
;;; cl-input.asd
(asdf:defsystem "cl-input"
  :description "Terminal input decoding (pure), device port, and sink port."
  :license "MIT" :version "0.1.0"
  :depends-on (#:alexandria #:uiop #:trivial-utf-8)
  :components
  ((:file "src/input/packages")
   (:file "src/input/tokens")     ; token structs, helpers
   (:file "src/input/keymap")     ; escape→semantic mapping
   (:file "src/input/decoder")    ; pure state machine
   (:file "src/input/device")     ; device port (termios impl optional)
   (:file "src/input/sink")       ; sink port (accept-token & friends)
   (:file "src/input/loop")       ; push & pull runners
   (:file "src/input/api")))
```

```lisp
;;; src/input/packages.lisp
(uiop:define-package :cl-input.tokens
  (:use :cl :alexandria)
  (:export #:input-token #:make-token #:token-kind #:token-data #:token-ts
           ;; common :kind values
           +k-key+ +k-mouse+ +k-resize+ +k-paste+ +k-focus+))

(uiop:define-package :cl-input.keymap
  (:use :cl :alexandria)
  (:export #:*default-keymap* #:lookup-seq #:canonicalize-key))

(uiop:define-package :cl-input.decoder
  (:use :cl :alexandria :cl-input.tokens :cl-input.keymap)
  (:export
   ;; immutable decoder state (can be a plist/struct)
   #:make-decoder #:decoder-state
   ;; functional decoding step:
   #:decode-chunk))

(uiop:define-package :cl-input.device
  (:use :cl :alexandria)
  (:export
   ;; Device port (generics; default stub prints warnings)
   #:open-device #:close-device
   #:enable-raw-mode #:disable-raw-mode
   #:device-read-bytes #:device-write-bytes
   ;; Optional default TTY impl constructor:
   #:make-tty-device))

(uiop:define-package :cl-input.sink
  (:use :cl :alexandria :cl-input.tokens)
  (:export
   ;; Sink port (generics; defaults are NO-OP)
   #:accept-token #:on-key #:on-mouse #:on-resize #:on-paste #:on-focus
   ;; Helpers for composing sinks:
   #:tee-sink #:fn-sink))

(uiop:define-package :cl-input.api
  (:use :cl :alexandria :cl-input.tokens :cl-input.decoder :cl-input.device :cl-input.sink)
  (:export
   ;; Push mode
   #:start-input-loop #:stop-input-loop
   ;; Pull mode
   #:make-input-source #:next-token #:close-input-source
   ;; Quick one-shot read helpers
   #:read-tokens #:with-raw-input))
```

---

## Tokens (pure data)

```lisp
(in-package :cl-input.tokens)

(defparameter +k-key+    :key)
(defparameter +k-mouse+  :mouse)
(defparameter +k-resize+ :resize)
(defparameter +k-paste+  :paste)
(defparameter +k-focus+  :focus)

(defstruct input-token
  kind   ;; one of the +k-*+ keywords
  data   ;; plist describing the token (e.g., :code :enter :mods (:ctrl))
  ts)    ;; timestamp (universal-time or monotonic)

(defun make-token (kind data &optional ts)
  (make-input-token :kind kind :data data :ts (or ts (get-universal-time))))
```

---

## Keymap (pure lookup)

```lisp
(in-package :cl-input.keymap)

(defparameter *default-keymap*
  ;; minimal examples; extend with your full table
  `((,(list #\Esc #\[ #\A) :up)
    (,(list #\Esc #\[ #\B) :down)
    (,(list #\Esc #\[ #\C) :right)
    (,(list #\Esc #\[ #\D) :left)
    (,(list #\Return)      :enter)
    (,(list #\Tab)         :tab)
    (,(list #\Backspace)   :backspace)))

(defun lookup-seq (octets &optional (table *default-keymap*))
  (let ((match (find octets table
                     :test (lambda (seq entry)
                             (equal seq (first entry))))))
    (and match (second match))))

(defun canonicalize-key (char &key ctrl alt shift)
  ;; turn raw char + modifiers into a canonical key symbol/plist
  (cond
    ((and ctrl (<= (char-code char) 31)) :ctrl-<control-code>)
    (t (string-downcase (string char)))))
```

---

## Decoder (pure state machine)

```lisp
(in-package :cl-input.decoder)

;; You can keep the state as a plist to honor your “no mutable class slots” ethos.
(defun make-decoder (&key (buf #()) (paste-mode :off))
  (list :buf buf :paste paste-mode))

(defun decoder-state (dec) dec)

(defun %emit-key (code ts)
  (cl-input.tokens:make-token cl-input.tokens:+k-key+ `(:code ,code) ts))

(defun decode-chunk (decoder octet-vector &key (timestamp (get-universal-time)))
  "Pure step: consume OCTET-VECTOR, return (values tokens new-decoder).
   Keep incomplete escape sequences in decoder’s buffer."
  (let* ((buf (or (getf decoder :buf) #()))
         (bytes (concatenate '(vector (unsigned-byte 8)) buf octet-vector))
         (pos 0)
         (out '()))
    (labels ((take (n) (prog1 (subseq bytes pos (min (length bytes) (+ pos n)))
                          (incf pos n)))
             (remaining () (- (length bytes) pos))
             (peek (n) (subseq bytes pos (min (length bytes) (+ pos n)))))
      (loop while (< pos (length bytes)) do
        ;; extremely simplified: try fixed sequences first
        (let* ((window (peek 6)) ; enough to match common CSI seqs
               (match (cl-input.keymap:lookup-seq (coerce window 'list))))
          (cond
            (match
             ;; matched a full escape seq → emit semantic key
             (let ((len (length (first (find (coerce window 'list)
                                             cl-input.keymap:*default-keymap*
                                             :test (lambda (seq entry)
                                                     (equal seq (first entry))))))))
               (take len)
               (push (%emit-key match timestamp) out)))
            (t
             ;; fall back to single byte char
             (let ((b (aref bytes pos)))
               (incf pos)
               (cond
                 ((= b 27)
                  ;; partial ESC? stash back (naive; improve with timeouts)
                  (decf pos) (return))
                 (t
                  (push (%emit-key (code-char b) timestamp) out))))))))
      (values (nreverse out)
              (list :buf (subseq bytes pos) :paste (getf decoder :paste))))))
```

*(You’ll likely extend this with CSI parsing, mouse tracking, paste bracketed mode, focus in/out, etc. The form is the key: **pure** state in/state out.)*

---

## Device Port (defgenerics, default stubs)

```lisp
(in-package :cl-input.device)

(defgeneric open-device (&key stream)
  (:documentation "Return a device handle (whatever your impl wants)."))

(defgeneric close-device (dev))
(defgeneric enable-raw-mode (dev))
(defgeneric disable-raw-mode (dev))

(defgeneric device-read-bytes (dev buffer start end)
  (:documentation "Fill BUFFER[start..end). Return number of bytes or :eof."))

(defgeneric device-write-bytes (dev buffer start end)
  (:documentation "Optional; return bytes written."))

;;; Default fallbacks (do nothing) so the protocol is optional to implement
(defmethod open-device (&key stream) (or stream *standard-input*))
(defmethod close-device (dev) (declare (ignore dev)) t)
(defmethod enable-raw-mode (dev) (declare (ignore dev)) t)
(defmethod disable-raw-mode (dev) (declare (ignore dev)) t)
(defmethod device-read-bytes (dev buffer start end)
  ;; Portable but blocking character read; replace with a termios impl in your app.
  (declare (ignore buffer start end))
  (declare (ignore dev))
  :eof)
(defmethod device-write-bytes (dev buffer start end)
  (declare (ignore dev buffer start end)) 0)

;;; Optional constructor for your real termios impl
(defun make-tty-device (&key (path "/dev/tty")) (declare (ignore path)) '(:tty)))
```

---

## Sink Port (defgenerics, function sinks, tee sinks)

```lisp
(in-package :cl-input.sink)

(defgeneric accept-token (sink token)
  (:documentation "Main delivery method. Default: NO-OP."))

(defgeneric on-key (sink token))
(defgeneric on-mouse (sink token))
(defgeneric on-resize (sink token))
(defgeneric on-paste (sink token))
(defgeneric on-focus (sink token))

;; Defaults: do nothing
(defmethod accept-token ((sink t) (tok cl-input.tokens:input-token)) (declare (ignore sink tok)) nil)
(defmethod on-key   ((sink t) (tok cl-input.tokens:input-token)) (declare (ignore sink tok)) nil)
(defmethod on-mouse ((sink t) (tok cl-input.tokens:input-token)) (declare (ignore sink tok)) nil)
(defmethod on-resize((sink t) (tok cl-input.tokens:input-token)) (declare (ignore sink tok)) nil)
(defmethod on-paste ((sink t) (tok cl-input.tokens:input-token)) (declare (ignore sink tok)) nil)
(defmethod on-focus ((sink t) (tok cl-input.tokens:input-token)) (declare (ignore sink tok)) nil)

;; Convenience: if user passes a plain function, treat it as accept-token
(defun fn-sink (fn)
  (lambda (token) (funcall fn token)))

(defun tee-sink (&rest sinks)
  (lambda (token)
    (dolist (s sinks)
      (cond
        ((functionp s) (funcall s token))
        (t (accept-token s token)))))))
```

---

## Loop (push & pull)

```lisp
(in-package :cl-input.api)

(defstruct input-loop dev thread stop? decoder sink)

(defun %deliver (sink token)
  (cond
    ((functionp sink) (funcall sink token))
    (t
     (accept-token sink token)
     (ecase (cl-input.tokens:input-token-kind token)
       (:key    (on-key sink token))
       (:mouse  (on-mouse sink token))
       (:resize (on-resize sink token))
       (:paste  (on-paste sink token))
       (:focus  (on-focus sink token))))))

(defun start-input-loop (&key (device (cl-input.device:open-device))
                              (sink (fn-sink (lambda (_tok) (declare (ignore _tok)) nil)))
                              (decoder (cl-input.decoder:make-decoder)))
  "Reads from DEVICE, decodes via DECODER, pushes to SINK. Returns an INPUT-LOOP handle."
  (cl-input.device:enable-raw-mode device)
  (let ((loop (make-input-loop :dev device :sink sink :decoder decoder)))
    (setf (input-loop-thread loop)
          (bt:make-thread
           (lambda ()
             (let ((buf (make-array 64 :element-type '(unsigned-byte 8))))
               (unwind-protect
                    (loop until (input-loop-stop? loop) do
                      (let ((n (cl-input.device:device-read-bytes device buf 0 (length buf))))
                        (when (or (eql n :eof) (null n)) (return))
                        (multiple-value-bind (tokens dec2)
                            (cl-input.decoder:decode-chunk (input-loop-decoder loop)
                                                           (subseq buf 0 n))
                          (setf (input-loop-decoder loop) dec2)
                          (dolist (t tokens) (%deliver (input-loop-sink loop) t)))))
                 (cl-input.device:disable-raw-mode device)))))
           :name "cl-input-loop"))
    loop))

(defun stop-input-loop (loop)
  (setf (input-loop-stop? loop) t)
  (cl-input.device:close-device (input-loop-dev loop))
  t)

;;; Pull mode: a source object that yields tokens on demand
(defstruct input-source dev decoder buf)

(defun make-input-source (&key (device (cl-input.device:open-device))
                               (decoder (cl-input.decoder:make-decoder)))
  (cl-input.device:enable-raw-mode device)
  (make-input-source :dev device :decoder decoder :buf (make-array 64 :element-type '(unsigned-byte 8))))

(defun next-token (src &key (timeout nil))
  "Blocking read (or timed if DEVICE supports it). Returns a token or NIL on EOF."
  (declare (ignore timeout)) ; extend in your device impl
  (let* ((n (cl-input.device:device-read-bytes (input-source-dev src) (input-source-buf src) 0 64)))
    (cond
      ((or (eql n :eof) (null n)) nil)
      (t
       (multiple-value-bind (tokens dec2)
           (cl-input.decoder:decode-chunk (input-source-decoder src)
                                          (subseq (input-source-buf src) 0 n))
         (setf (input-source-decoder src) dec2)
         (first tokens))))))

(defun close-input-source (src)
  (cl-input.device:disable-raw-mode (input-source-dev src))
  (cl-input.device:close-device (input-source-dev src))
  t)

;;; Convenience helper
(defmacro with-raw-input ((dev) &body body)
  `(let ((,dev (cl-input.device:open-device)))
     (unwind-protect
          (progn (cl-input.device:enable-raw-mode ,dev) ,@body)
       (cl-input.device:disable-raw-mode ,dev)
       (cl-input.device:close-device ,dev))))
```

---

# Why this is superior (and widely used)

* **Dependency inversion**: `cl-input` depends on *no one*. Others depend on it.
* **Hexagonal/ports**: device + sink ports are small, explicit, testable.
* **Functional core**: the decoder is pure; it’s trivial to fuzz, snapshot, and golden-test.
* **Two integration styles**: push (observers/sinks) and pull (iterators/sources).
* **Optional adapters**: you keep “events”, “channels”, “renderers” in *separate* systems:

  * `cl-input-adapters.events` (depends on `cl-input` + `cl-events`)

    ```lisp
    (defclass events-sink () ((bus :initarg :bus :reader bus)))
    (defmethod accept-token ((s events-sink) tkn)
      ;; publish whatever structure you want on your bus…
      (publish-something (bus s) (token->your-message tkn)))
    ```
  * `cl-input-adapters.channels` (depends on your channel lib)

    ```lisp
    (defclass chan-sink () ((ch :initarg :ch :reader ch)))
    (defmethod accept-token ((s chan-sink) tkn) (chan-put (ch s) tkn))
    ```

No matter what the app’s message/event shape is, **`cl-input` doesn’t care**. It outputs **tokens**; your adapters care.

---

# If you prefer “only generics, no callbacks”

You can still keep it protocol-only:

* Require apps to provide a **sink object** implementing `accept-token` (and friends).
* Ship a default `null-sink` that discards tokens, and a `debug-sink` that prints.
* Keep `start-input-loop` accepting only **sink objects** (no function).
* If someone wants a function, they wrap it in `fn-sink`, which is just an object with a method.

The design above already supports both styles (function or generic), so you can pick one and keep the other as sugar.

---

# What about output (ANSI/terminal writes)?

Exactly the same pattern, but **in a different library** (e.g., `cl-term`):

* Device port generics you already have.
* A small **“writer”** API `(render-frame dev bytes)` with adapters for *your* renderer.
* Optional **capabilities** query (supports 256 colors? truecolor? mouse tracking?) as a device generic.

This keeps input and output independent, but they can share the same device instance if you want.

---

# Closing notes

* This aligns with your “no mutable class slots” preference: the decoder state is a *value* that comes out and goes back in.
* TEA friendliness: your app loop (in `cl-events` or elsewhere) simply chooses a sink that maps tokens → messages or directly invokes `update`.
* Testing is a breeze: feed byte arrays into `decode-chunk`, assert emitted tokens.

If you want, I can also drop in a **ready-made `cl-input-adapters.events`** mini-system that publishes your tokens to the event bus you already sketched—still keeping `cl-input` pure and dependency-free.
