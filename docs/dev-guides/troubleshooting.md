# Troubleshooting

## Setup issues

### System not found

ASDF reports `:elmtui` or a `cl-*` system as missing.

- Clone with `--recurse-submodules` (or run `git submodule update --init
  --recursive`).
- Run `clpm bundle install` from the repository root.
- Run commands through `clpm bundle exec` so the CLPM context is active.

### Dependency not found

A CLPM-managed library is missing.

- Re-run `clpm bundle install`.
- Check that `clpmfile.lock` is present and not gitignored.
- If you added a new dependency, update `clpmfile` and regenerate the
  lock.

## Runtime issues

### Terminal output is garbled

- Check `$TERM` (`xterm-256color` or similar).
- Ensure UTF-8 locale (`$LANG`, `$LC_ALL`).
- Try a different terminal emulator. ElmTUI is tested primarily on
  `xterm`, `gnome-terminal`, `alacritty`, `kitty`, and tmux.
- Simplify the UI tree to isolate the problem.
- Enable framework logging: pass `:log-file "debug.log"` to the
  generated runner.

### Application freezes

- Check for infinite loops in update or view logic.
- Use the Lisp debugger to inspect the backtrace.
- Enable `log4cl` tracing to follow event/message flow.
- Check for deadlocks if using threads.

### Layout or sizing is wrong

- Verify flex/grid style properties.
- Simplify the component tree to isolate the issue.
- Check terminal dimensions (`tput cols`, `tput lines`).
- Use `elmtui-dev` diagnostics if loaded (`asdf:load-system
  "elmtui-dev"`).

### Key presses not handled

- Confirm which component has focus.
- Check keymap definitions — use
  `elmtui.keymaps:list-active-keybindings` to inspect.
- Verify the update function handles the expected message shapes.
- Enable event logging to trace the input pipeline.

## Performance issues

- Use SBCL profiling (`sb-profile`) to identify bottlenecks.
- Check whether view functions perform expensive computation on every
  render.
- Consider memoization for stable view subtrees.
- The `elmtui-dev` system provides optional microbenchmarks; see the
  [developer tools guide](../developer-tools.md).

## Common conditions

| Condition | Meaning |
|---|---|
| `invalid-dsl-form` | The DSL tree contains an improper, circular, or over-deep form. |
| `state-mutation-forbidden` | A `:strict-elm` frozen snapshot was mutated through a supported API. |
| `component-error` | A component signalled during init, update, or view. |

Use `handler-bind` to inspect structured conditions and their restarts
before they unwind. See the
[foundations chapter](../longform/01-foundations-and-elm-architecture.md)
for the condition/restart architecture.

## Reporting issues

1. Create a minimal reproducible example.
2. Gather: ElmTUI version, SBCL version, OS, terminal, backtrace.
3. Report at [github.com/fkr-0/elmtui/issues](https://github.com/fkr-0/elmtui/issues).
