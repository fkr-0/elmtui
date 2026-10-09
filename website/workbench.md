# ElmTUI Workbench

<div class="eyebrow">THE FLAGSHIP EXPERIENCE · NATIVE COMMON LISP REPL</div>

The Workbench is an ElmTUI application for editing and evaluating Common Lisp in the terminal. It is both a useful developer tool and a deliberately demanding demonstration of the framework's state management, layout, command handling, terminal input and incremental presentation.

<div class="media-stage hero-shot" role="img" aria-label="ElmTUI Workbench showing Lisp REPL and image inspector" data-preview="../assets/workbench-hero.webp">
  <div class="window-top">LISP WORKBENCH · SCREENSHOT</div>
  <div class="shot-placeholder"><div class="mock-main">CL-USER&gt; (mapcar #'1+ '(1 2 3))<br><span class="mock-result">(2 3 4)</span><br><br>CL-USER&gt; (describe 'defun)</div><div class="mock-side">Packages<br>Symbols<br>ASDF systems<br>Diagnostics</div></div>
  <span class="preview-caption">Pending screenshot: website/assets/workbench-hero.webp</span>
</div>

## Design

The interactive Workbench joins:

- **Editable multiline REPL** with form-aware input and a transcript.
- **Symbol completion** with a cursor-anchored selection menu and delayed documentation.
- **Package and image inspector** for loaded packages, exported symbols, globals and ASDF systems.
- **Diagnostics** and tagged evaluation results, with a worker keeping the interface responsive during evaluation.
- **Terminal lifecycle** management, including alternate-screen cleanup on exit.

The evaluation backend is an in-process, trusted Lisp image. It is **not a sandbox**. Slynk is an optional integration adapter, not a mandatory dependency, and a remote listener is not started by default.

## Run it

```sh
git submodule update --init --recursive
clpm bundle install
clpm bundle exec --with-client sbcl -- \
  --noinform --non-interactive \
  --load examples/workbench.lisp
```

Expected controls in the current implementation:

| Key | Action |
|---|---|
| Enter | Evaluate a balanced form or continue editing an incomplete form |
| Ctrl+Space | Request completion (terminal protocol permitting) |
| Tab / Up / Down | Accept or navigate completion |
| F2 | Focus image inspector |
| F3 | Toggle documentation |
| F4 | Diagnostics |
| Ctrl+C | Request cooperative cancellation |
| Ctrl+D | Exit on empty editor |

!!! warning "Release qualification"
    Targeted Workbench PTY smoke tests have passed during ongoing development, after earlier startup and terminal-restoration failures were diagnosed. The Workbench is **included as a release target**, but the final pinned release build still requires independent startup, evaluation, completion, resize, idle-output and terminal-restoration qualification. See [release status](release.md).

## What it demonstrates

This application exercises the ElmTUI model/update/view architecture for more than a one-screen demo: keyboard focus, asynchronous evaluation messages, completion generation IDs, timed documentation, image inspection and multi-column layouts.

Read the [detailed Workbench guide](guide/workbench-user-guide.md) and [architecture foundations](guide/foundations.md). For a simpler introduction, start with the [counter tutorial](guide/tutorial.md).
