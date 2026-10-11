# Terminal application end-to-end tests

These tests run actual example applications in fresh CLPM/SBCL processes through
private tmux PTYs. Wi-Fi scenarios invoke the public `./examples.sh run wifi-menu`
launcher. Their temporary `nmcli` executable returns deterministic networks and
records connection requests, so the tests never change the host's Wi-Fi state.
Secure network fixtures exercise Up/Down selection, password masking, typing,
Backspace, and abort. Every interactive transition must complete within one
second; per-action timings are saved in `frames.json`. Repeated startup scenarios
check for mixed frames while initial scans and terminal events arrive together.

Run the Wi-Fi lifecycle scenarios:

```sh
python scripts/test-terminal-apps.py --case wifi
python tests/e2e/test-bottom-row.py
python scripts/test-startup-output.py
python cl-inputs/tests/tty-termios-regression.py
```

To send real X11 key events through urxvt, use a private Xvfb display:

```sh
python scripts/test-terminal-apps.py --terminal urxvt --case wifi
python tests/e2e/test-bottom-row.py --terminal urxvt
```

For independent native terminal proof without tmux emulation:

```sh
python tests/e2e/test-native-urxvt.py
```

This runner launches urxvt directly on another private Xvfb display. `script`
relays and records the application's PTY bytes; urxvt itself interprets terminal
commands and answers cursor-position queries. The tests query the real terminal
after shutdown and check row 35, column 9, exact termios restoration, twenty
individual scroll steps each way, and bounded Escape/Enter shutdown. When
ImageMagick `import` and Tesseract are installed, they also capture and read the
native window before and after shutdown to verify visible menu removal and
preserved surrounding rows. Screenshots, OCR text, actual cursor replies, and
shutdown timings are retained alongside the transcript. The `--terminal urxvt`
adapter above instead uses urxvt to display a private tmux session; these are
separate qualification paths.

The urxvt mode always starts its own Xvfb display, including when the calling
shell already has `DISPLAY` set. Each case owns a separate tmux socket and closes
only its own server and emulator. It requires `tmux`, `clpm`, and `sbcl`; urxvt
mode additionally requires `urxvt`, `xdotool`, and `xvfb-run`. A Docker daemon is
not required.

The bottom-row suite fills the terminal with numbered rows and starts the menu
at row 35, column 9. It checks reservation of 20 rows, readable menu placement,
preservation of surrounding content and scrollback, Escape/Enter shutdown,
reversal of the reservation, exact cursor restoration, termios restoration,
bounded shutdown latency, and absence of whole-terminal reset sequences.

Each run saves `result.json` under a unique `test-output` directory. Per-case
artifacts include `terminal.raw`, `stderr.txt`, `frames.json`, `last-screen.txt`,
the launcher script, exit status, and before/after terminal settings. Use
`--output PATH` to select an artifact directory and `--timeout SECONDS` to bound
waits. The main suite also supports `--case SUBSTRING`.

The broader application suite is deliberately retained as a diagnostic gate:

```sh
python scripts/test-terminal-apps.py
```

It includes minimal input, focus navigation, counter updates, scrolling, and
Game of Life. Earlier runs exposed startup component lookup, quit handling,
blank scrolling, and key-message handling failures in these examples. A passing
Wi-Fi subset does not qualify those other applications. Check the full suite's
current `result.json` before claiming the project is ready for release.

The fake network fixture verifies application behavior and command arguments.
It does not qualify NetworkManager, a real wireless adapter, or connection
success against an actual access point.

## Extended maintained-example lifecycle suite

Run the focused private-tmux PTY coverage for the maintained examples that are
not covered by the broader suite:

```sh
python3 tests/e2e/extended-examples-pty.py -v
```

The suite checks finder filtering, selector filtering, glider animation,
cursor-inspector startup, inline Pong, root-viewport navigation and both dirty
editor quit paths. It requires Python 3, `tmux`, `clpm`, and SBCL. Each case
starts a private tmux server and fresh Lisp process; it does not use the
caller's tmux session or make live network requests. Transcript bytes, screen
frames, stderr, exit status, and before/after terminal settings are retained in
per-case directories under
`/tmp/elmtui-extended-evidence-20261009`.

The opt-in live tmux integration gate is separate:

```sh
ELMTUI_RUN_TMUX_INTEGRATION=1 scripts/release-check.sh
```
