---
# AI Metadata Tags
ai_keywords: [Rainbow Example, defapplication, run-application, stylesheet, flexbox, Elmtui Example, colored stripes]
ai_contexts: [usage, example, implementation]
ai_relations: ["../modules/app/overview.md", "../modules/app/implementation.md", "../modules/view/overview.md"]
---

# Rainbow Example Application

<!-- AI-IMPORTANCE:level=high -->

## Overview

The Rainbow Example demonstrates how to build a simple Elmtui application using `defapplication`, custom stylesheets, and the view DSL. It displays colored vertical stripes using flexbox layout and quits on any key press.

## Key Features

- Uses `defapplication` for idiomatic app definition.
- Demonstrates stylesheet and class usage for color and layout.
- Shows how to wire up `init`, `update`, and `view` functions.
- Illustrates the use of the root viewport and flexbox container.

## How to Run

1. Ensure the project is loaded and compiled.
2. In your Lisp REPL or via the dev setup script, run:

```lisp
(elmtui.dev-setup:run-example-app
  'elmtui.examples.rainbow-app:run-rainbow-example-app
  :package-name :elmtui.examples.rainbow-app)
```

Or, if using a script:

```lisp
(load "run_clpm.lisp")
```
and follow the prompts to select the Rainbow example.

## Implementation Highlights

- **Stylesheet:** Defines a set of color classes for each stripe using `defrule` and `defstylesheet`.
- **View:** Uses a flexbox-style container to lay out colored stripes horizontally.
- **Update:** Any key event or `:app-quit-requested` message sets `:should-quit` to `t`, causing the app to exit.
- **App Definition:** Uses `defapplication` to tie together state, update, view, and subscriptions.

## Source Location

- [`examples/rainbow-app.lisp`](../examples/rainbow-app.lisp)

## Related Documentation

- [App Module Overview](../modules/app/overview.md)
- [App Module Implementation](../modules/app/implementation.md)
- [View Module Overview](../modules/view/overview.md)