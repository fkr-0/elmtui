# ElmTUI Lisp Workbench — architecture and implementation contract

Status: design baseline, 2026-10-09. Root: /home/user/code/lisp/elmtui.lisp.

## Goal

Terminal-native Common Lisp IDE: interactive editable REPL transcript, multiline Lisp editor, cursor-anchored completion popup **above cursor** (fall back below if insufficient room), delayed documentation for selected candidate (cancelable, nonblocking), optional multi-column live image inspector with packages, symbols, bounded value previews, loaded ASDF systems, conditions and object drilldown. Input and rendering must remain responsive during evaluation.

## Layout

```text
┌ Lisp Workbench ────────────────────── SBCL / CL-USER ─────────────┐
│ REPL transcript + editor                         │ Image         │
│ CL-USER> (defparameter *xs* '(1 2 3))            │ Packages      │
│ *XS*                                              │ Symbols/values│
│ CL-USER> (mapcar #'1+ *xs*)                       │ ASDF systems  │
│ (2 3 4)                                           │ Diagnostics   │
│                                                   │ Inspector     │
│ ┌ Above-cursor completion ─────────────────────┐  │               │
│ │ > REMOVE-IF-NOT   predicate sequence        │  │               │
│ │   REMOVE-IF                               │  │               │
│ │   REMOVE                                  │  │               │
│ ├ Selected-symbol docs (optional delayed) ────┤  │               │
│ │ Remove matching elements ...                 │  │               │
│ └ Cursor-attached, overlay not layout flow ────┘  │               │
├ Ctrl+Space Complete · Ctrl+Enter Eval · F2 Inspector · F3 Docs ───┤
└───────────────────────────────────────────────────────────────────┘
```

Wide (>=120 cols): ~68/32 REPL/inspector split, resizeable; 80–119: REPL first with inspector toggled; <80: single-pane stack. Completion remains an overlay anchored to actual screen-cell cursor coordinates on resize, and flips below when an above-popup would be clipped.

## Backend and ownership

ElmTUI owns editor, TEA event loop, overlays, terminal protocols, focus, layout, diff-rendering. Default runtime adapter is in-process Common Lisp introspection/evaluation; Slynk is optional for **remote SLY-protocol** image access, richer debugger/stack frame data, not LSP. Keep core elmtui.asd and main CLPM bundle independent of Slynk. A separately loadable elmtui-workbench.asd composes modules. Never add Slynk as a mandatory runtime dependency.

Workstreams (distinct new paths, do not modify core/release-owner files):
- W1 editor: src/workbench/editor*.lisp + tests/workbench/editor*; package :elmtui.workbench.editor
- W2 evaluation: src/workbench/eval*.lisp + tests/workbench/eval*; package :elmtui.workbench.eval
- W3 completion and docs: src/workbench/completion*.lisp, docs*.lisp + tests/workbench/completion*; package :elmtui.workbench.completion
- W4 inspector and optional Slynk: src/workbench/inspector*.lisp, slynk*.lisp + tests/workbench/inspector*; package :elmtui.workbench.inspector
- W5 app integration and PTY: src/workbench/app*.lisp, view*.lisp; elmtui-workbench.asd; examples/workbench*.lisp; tests/workbench/pty*; docs/workbench-user-guide.md; package :elmtui.workbench.app

Only integration lane touches its ASDF/launcher glue. Existing shared core files require separate coordination with ELMTUI-RELEASE-20261008. The workspace's max_active_workers=4 means lane W5 can queue until dependencies stabilize.

## Stable adapter contracts

Module owners publish final exported names before integration. Suggested interface:
- Editor: make-editor-state, editor-handle-key, editor-insert-text, editor-text, editor-balanced-p, editor-cursor-screen-position. Keep multiline editing, indentation, undo, history boundaries, Unicode scalar and display-cell positions.
- Evaluation: make-repl-session, request-evaluation(session source request-id), poll-evaluation, cancel-evaluation. Serialized per-session image worker; return tagged events :stdout, :stderr, :value, :condition, :aborted, :finished with request ID. Keep package/readtable and REPL history variables stable across requests; multiple values should appear distinctly. All TUI state mutations happen on UI update thread.
- Completion: complete-at(session source cursor generation) returns IDs, matching insertion span/text, symbol/package identity, annotations and ranking; documentation-for and signature-for for selected item. Work on incomplete code without evaluating it; reject stale generations; dwell is a timer message (default around 450ms), not a blocking sleep.
- Inspector: snapshot-image(session generation), inspect-object(session handle request-id). Bounded paginated package/symbol/ASDF/thread inventory, printable object previews, cyclic data protection and length/depth limits. Lexical locals shown **only** for an actual debugger frame; top-level REPL has global/special symbol bindings, not lexical scope.
- Application messages: :wb-key, :wb-resize, :wb-eval-result, :wb-completion-result, :wb-doc-dwell, :wb-inspector-result, :wb-focus. Async workers dispatch immutable messages, never paint terminal output themselves.

Keyboard: Ctrl+Space completion; Tab indent/accept; Up/Down select candidates or history; Enter submits complete expression and indents incomplete form (configurable); Shift+Enter newline; Ctrl+Enter submit; Ctrl+R history search; F2 inspector; F3 docs; F4 diagnostics; Escape closes overlays in reverse order; Ctrl+C cancellation; Ctrl+D exits when input empty. Resizing must retain focus/cursor. Mouse optional, keyboard mandatory.

Safety: User-chosen Lisp EVAL is **not sandboxed**. Completion/inspection must not call eval on highlighted or unfinished forms. Passive parsing binds *read-eval* NIL. Value print methods and documentation lookup may execute user code; cap previews and defer unsafe inspection. Remote image connection is explicit opt-in; local default requires no network listener. Capture stdout/errors without corrupting terminal.

## Mandatory acceptance and qualification

Real PTY launch via clpm bundle exec --with-client sbcl --; warning-clean startup. Multiline defun, repair/edit, Unicode, history, package persistence, multiple values and stream capture; completion above cursor; dwell doc appears and cancels on selection change; object/package/ASDF inspector updates; stale completion drops; error recovery; Ctrl+C/Ctrl+D; 80x24, 120x40, 160x50 resize and repeat start/exit with termios, cursor and alternate-screen restoration. Test simulated event state plus black-box PTY golden traces and nonblocking responsiveness. Independent review by another actor is mandatory. No push/publication.

Before .lisp edits read AGENTS.md/CLAUDE.md and sexp-manipulator skill; parse/transform/validate balanced forms and compile after each small increment. Preserve pre-existing dirty files and submodules; use guarded transactions, exclusive claims and typed workflow results. Normal SBCL invocation: clpm bundle exec --with-client sbcl -- <sbcl-options>.
