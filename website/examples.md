# Example gallery

Runnable example applications make the ElmTUI concepts concrete. Begin with the simple, then move to editor, games and diagnostics.

| Example | Role | Command |
|---|---|---|
| Minimal application | TEA update/view contract | `./examples.sh run minimal-app` |
| Mini text editor | Editable buffer and asynchronous saving | `./examples.sh run mini-text-editor` |
| Neon Pong | Input, animation and telemetry | `./examples.sh run neon-pong` |
| Neon Tetris | Game loop and dynamic layout | `./examples.sh run neon-tetris` |
| Neon Nano | Styled text editor with save flow | `./examples.sh run neon-nano` |
| Neon Less | Read-only file viewer | `./examples.sh run neon-less` |
| Key tester | Terminal key decoder instrumentation | `./examples.sh run key-tester` |
| Wi-Fi menu | Asynchronous external-tool integration | `./examples.sh run wifi-menu` |
| Workbench | Interactive REPL, completion, inspector | See [Workbench](workbench.md) |

The [maintained examples catalog](guide/examples-catalog.md) records keybindings, configuration variables and known limitations. Live interactive PTY behavior remains part of the release gate; an example being present is not proof of passing tests.

## Planned animated demonstration

<div class="media-stage motion-stage" role="img" aria-label="Animated terminal slider interaction" data-preview="../assets/terminal-slider.gif">
  <div class="motion-placeholder"><span class="motion-bars">▁ ▃ ▅ ▇ ▅ ▃ ▁</span><br>TERMINAL SLIDER / ANIMATION PREVIEW<br><small>website/assets/terminal-slider.gif</small></div>
  <span class="preview-caption">Demonstration GIF pending</span>
</div>

## Example authoring standard

Every public example should have a short summary, a reproducible launch command, terminal size requirements, keybinding summary, external dependencies, cleanup behavior, and at least one automated smoke test.
