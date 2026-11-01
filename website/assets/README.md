# Website media

All media here are recorded from real sessions of the maintained examples by
`scripts/record-demo-media.py` (Xvfb, urxvt, tmux and ffmpeg). Re-record all
of them, or a selection, with:

```sh
scripts/record-demo-media.py                 # everything into website/assets/
scripts/record-demo-media.py hero slider     # selected scenarios
```

| file | scenario | used on |
|---|---|---|
| `workbench-hero.webp` | `hero`: Workbench with completion popup and inspector | home, Workbench page |
| `terminal-slider.gif` | `slider`: tmux slider reversing, speeding up, pausing | home, examples |
| `workbench.gif` | `workbench`: evaluation, completion, package/symbol browsing | examples, GitHub release |
| `neon-tetris.gif` | `tetris`: a planned game clearing seven lines | examples, GitHub release |
| `tmux-glider.gif` | `glider`: Conway glider over live tmux pane text | examples, GitHub release |

`assets/preview.js` swaps the authored placeholder of each `data-preview`
stage for its media once the file loads, so a missing file never shows a
broken image. The recordings show only the repository's own git log and
example listing; do not commit terminal history, private paths, tokens,
machine names or customer data in media.
