# ElmTUI public API and documentation review (2026-11-01, v0.3.1)

Scope: the exported ElmTUI packages of the primary `elmtui` system, the two
application constructors, and the documentation that teaches them (README,
website quickstart, long-form chapters 01 and 03, generated reference).
Support libraries (`cl-*`) were reviewed only where ElmTUI re-exports them.

Method: a fresh SBCL image loading `elmtui`; every exported symbol was
classified by binding (`scripts/audit-api-bindings.lisp`); documented code was
extracted and **run in a real terminal** (private tmux, the
`scripts/test-terminal-apps.py` harness), not only compiled.

## Verdict

The *intended* application API is small and coherent: `elmtui.app:defapplication`
with an `(message state) -> (make-update-result :patches … :commands …)` update
function, a pure DSL-returning view, and `elmtui.state.api:state-ref` for reads.
A first application written against it works end to end: it renders below the
cursor, receives key events, quits cleanly and restores scrollback exactly.

The *exported* API is not sound. A large fraction of the published surface is
unbound, several names exist twice with different identities, one of the two
documented constructors does not run, and the teaching documentation used
names and signatures that do not work. None of this is caught by the existing
gates, which check re-export identity, docstrings and examples, but not that
documented or exported names are callable.

## Findings

Severity: **P0** breaks documented or exported use; **P1** makes correct use
needlessly hard; **P2** quality.

### P0-1: `deftea-app` applications do not run

`elmtui.app.tea-core:deftea-app` is documented as a supported Application-level
constructor (support-levels table, quickstart, README, tutorial chapter 03).
Running the tutorial's own counter (`(run-pure-counter)`) in a terminal draws
nothing and, on Ctrl-C, exits with status 1:

```
The value of ELMTUI.APP.API::STATE is (:COUNT 0),
which is not of type CL-STATE.CORE:APPLICATION-STATE.
  0: (ELMTUI.APP.API:GET-COMPONENT-INSTANCE (:COMPONENTS :COUNTER-ROOT) (:COUNT 0))
  1: (ELMTUI.PLATFORM.DRIVER::SHUTDOWN-PLATFORM)
```

The driver keeps the direct-replacement model in `*current-app-model*`, but
rendering and shutdown assume the `application-state` with root-viewport
components that `defapplication` builds. `deftea-app` is tested only by
macroexpansion (`tests/runtime-e2e-tests.lisp`); nothing runs one.

### P0-2: 328 exported symbols are unbound, some shadowing working ones

`scripts/audit-api-bindings.lisp`: of 1,504 symbols exported from their own
home package across 86 ElmTUI packages, **328 (22%) in 27 packages have no
function, macro, variable, class or type binding**. Three patterns:

1. **Root facade shadowing.** `src/elmtui.lisp` builds the root `elmtui`
   package with `uiop:define-package … (:reexport …)` over packages that
   export overlapping names. UIOP resolves those conflicts by *shadowing*:
   it interns a fresh symbol in `ELMTUI` and exports it. 127 of the root
   package's 128 own exports are such fresh, unbound symbols:
   `elmtui:with-terminal-lock`, `elmtui:button`, `elmtui:vbox`,
   `elmtui:send-message`, `elmtui:cmd`, … are **not** the framework's
   symbols (`(eq 'elmtui:with-terminal-lock
   'elmtui.platform.backend.terminal:with-terminal-lock)` is false).
   No document or example uses the root package, which is why it went
   unnoticed.
2. **Split identities.** Working definitions exist under another package,
   and the "API" package exports a different, unbound symbol of the same
   name: `elmtui.app.api:defapplication` (works: `elmtui.app:defapplication`);
   `elmtui.state.api:{sapply sref sdelete defupdate cmd send-command
   make-update-context context-patches context-commands
   process-update-result dispatch-to-topic handle-async-command
   *log-update-results* update-context}` (work: `elmtui.state.update:…`).
3. **Never implemented or since removed.** `elmtui.state` exports 98 names,
   none bound (`defmsg`, `deftransaction`, `make-*-appmsg`, form-state and
   message-variant API); `elmtui.state.msg` 19 message predicates
   (`keyevent-p`, …); `elmtui.view.core` 13 node helpers (`vbox`, `hbox`,
   `text`, `get-prop`, …); `elmtui.pipeline` 9 stage names;
   `elmtui.view.geo` 8 shape constructors.

The facade re-export audit (`scripts/audit-facade-exports.py`) only inspects
symbols whose home differs from the exporting package, so it reports none of
these. The support-levels policy says historical symbols must not be
"silently unexported"; that protects callers of working names, but an unbound
name has no callers to protect.

### P1-1: no public key-matching helper

Every application has to recognise key presses. Under `defapplication` the
update function receives `elmtui.core.event-types:key-event` objects (system
messages such as `(:terminalresized …)`, `(:cursorposition …)` and
`(:appshutdown)` arrive as lists). There is no exported predicate for "this
message is key X". The README example matched two shapes (object and a
`(:keyevent …)` plist that `defapplication` does not deliver), and the neon
examples carry a private helper (`elmtui.examples.neon-kit:pressed-p`) that
every example re-imports.

### P1-2: framework logging draws over the application

Loading `elmtui` and running an application from a plain SBCL writes log4cl
INFO and WARN lines (driver startup, "presenter is not ready") to standard
output, i.e. onto the UI. The examples launcher silences this privately
(`%configure-binary-logging` in `src/tools/examples-runner.lisp`). There is no
public switch; users must call log4cl directly
(`(log4cl:remove-all-appenders log4cl:*root-logger*)`).

### P1-3: two update contracts taught as one

Application update functions are called as `(funcall update-fn message
state)` with the application state and return `make-update-result` patches.
Update *contexts* (`make-update-context`, `sapply`, `sref`) exist only for
component updates (`defcomponent`, viewports). Long-form chapter 01 showed an
application update `(defun update (message ctx) (sapply ctx :count #'1+ 0) …)`,
which would receive a state, not a context, and named an unbound symbol.

### P2-1: runners and conventions are implicit

`defapplication NAME` interns `RUN-NAME` in the caller's package without
exporting it; quitting is the convention of patching `:should-quit` to true,
documented only by example; the root viewport needs an explicit `:height`
to render when the cursor is on the last row (found while packaging the
minimal example). These are learnable but undocumented contracts.

### P2-2: docstrings

The public-docstring ratchet passes at 90.3% (1,662 of 1,840 bindings; 178
missing), concentrated in `elmtui.platform.backend.terminal`, the driver and
`cl-inputs`/`cl-events` protocol packages. The generated reference is fresh
and gated. Coverage is adequate for a 0.x library; the larger documentation
risk is P0-2: unbound exported names cannot be documented and still appear in
the reference as "no metadata".

## Documentation soundness

| Document | Status before this review | Action |
|---|---|---|
| README "Minimal application shape" | Runs; quits only on Ctrl-C; dead plist branch | Replaced by a tested Quickstart |
| README status/requirements | Stale (badge "pending", tag "will be cut", tmux tests "opt-in") | Rewritten |
| README Workbench command | `\\` continuations break copy-paste | Fixed |
| Website quickstart | "Your first TEA application" showed no code; stale release text | Added the Quickstart app; fixed text |
| Chapter 01 foundations | Application update shown with an update context and unbound `sapply` | Corrected (P1-3) |
| Chapter 03 tutorial | Pure functions and tests correct (6/6 pass); `run-pure-counter` fails (P0-1); "built-in" counter widget moved to `elmtui-example-widgets` in 0.3.0 | Known-issue note; corrected |
| Generated API reference | Fresh, gated | Unchanged |

The README Quickstart is now executed by `tests/e2e/readme-quickstart.py`
(release gate `readme_quickstart`): it extracts the code block from
`README.org`, runs it in tmux, presses `+ + + -`, checks the rendered count,
quits with `q`, and requires exit 0, identical stty and intact history.

## Recommendations

Non-breaking (0.3.x):

1. Fix or demote `deftea-app` (P0-1): make the driver keep a direct model
   for `deftea-app` specs (render from `view-fn`, skip component lookups on
   shutdown), and add a PTY test that runs one. Until then, mark it
   experimental in the support-levels table.
2. Re-point split identities (P0-2 pattern 2): have `elmtui.app.api` and
   `elmtui.state.api` import and re-export the working symbols instead of
   exporting their own. Their current symbols are unbound, so nothing can
   depend on them as functions.
3. Add `scripts/audit-api-bindings.lisp` to the release gate as a ratchet
   (fail when the phantom count rises).
4. Add a public key predicate, e.g. `elmtui.app:key-pressed-p
   (message &key char key modifiers)`, and a public logging switch, e.g.
   `elmtui.app:configure-logging (&key stream file level)` with a quiet
   default for terminal applications (P1-1, P1-2).
5. Document the update-function contract, the `:should-quit` convention,
   `RUN-NAME` and the root viewport `:height` rule in the `defapplication`
   docstring and chapter 01 (P1-3, P2-1).

Breaking (0.4.0):

6. Replace the root `elmtui` facade's `:reexport` with an explicit, curated
   export list of the Application-level API (or retire the root package),
   so `elmtui:` names are the framework's own symbols.
7. Remove the remaining never-implemented exports (`elmtui.state`,
   `elmtui.state.msg` predicates, `elmtui.view.core` helpers,
   `elmtui.pipeline` stage names, `elmtui.view.geo` shapes) or implement
   them with tests.

## Reproduction

```sh
clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
  --load scripts/audit-api-bindings.lisp
python3 tests/e2e/readme-quickstart.py
```
