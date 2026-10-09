# Widget and layout inventory

ElmTUI's widget collection is **composable and growing**. This is a source-level inventory, not a certification that every widget behaves correctly in every terminal or that all APIs are stable.

## Application structure and layout

| Element | Role | Source |
|---|---|---|
| Root viewport | Full-screen and cursor-relative application anchoring | `src/ui/widgets/root-viewport.lisp` |
| Viewport | Bounded region and viewport operations | `src/ui/widgets/viewport.lisp` |
| Layout / grid container | Declarative geometry and layout composition | `src/ui/widgets/layout.lisp`, `grid-container.lisp` |
| Scroll panel | Scrollable clipped content | `src/ui/widgets/scroll-panel.lisp` |
| Scrollable container | Model-driven scrolling and associated view | `src/ui/widgets/scrollable-container.lisp` |

## Interactive components

| Widget | Role | Source |
|---|---|---|
| Button / enhanced button | Focusable activation and styled control patterns | `src/ui/widgets/button.lisp`, `button-enhanced.lisp` |
| Label / enhanced label | Content presentation | `src/ui/widgets/label.lisp`, `label-enhanced.lisp` |
| Text input | Stateful text editing and input | `src/ui/widgets/textinput.lisp` |
| List box | List navigation and selection with a model/update/view | `src/ui/widgets/listbox.lisp` |
| Modal dialog | Reusable modal-flow state machine and keyboard capture | `src/ui/widgets/modal-dialog.lisp` |
| Counter | Small reactive widget for learning | `src/ui/widgets/counter.lisp` |
| Key tester | Input protocol/keymap diagnosis | `src/ui/widgets/keytester.lisp` |

The component files live in the framework's `src/ui/widgets/` directory, and export contracts differ. For instance, a *model helper* is not interchangeable with a DSL *component*; check the public package exports. The root application includes declarative primitives such as text, containers and style properties that need not be one widget file each.

## Composition and state

A widget is part of the application's message flow rather than an independent terminal writer:

    message / key / resize
             ↓
       UPDATE(model)
             ↓
      new model + commands
             ↓
          VIEW(model)
             ↓
      DSL tree + geometry
             ↓
        frame differ
             ↓
         terminal

For larger work, prefer explicit state ownership and application-specific messages. The [patterns chapter](guide/widgets.md) explains component contracts; the [minimal tutorial](guide/tutorial.md) demonstrates state transitions.

## Before describing the library as extensive

For 0.1.0, we need an inventory of **shipped, exported, documented, independently tested** APIs with test fixtures for keyboard focus, narrow widths, Unicode display cells, scroll behavior, async effects, and terminal restoration. Current examples show the potential, but file count is not a stability claim.

See [example gallery](examples.md) and [Workbench](workbench.md) for full applications that exercise these primitives.
