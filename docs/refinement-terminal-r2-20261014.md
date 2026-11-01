# Terminal R2: evidence and residual ledger (2026-10-14)

Canonical OCP task: ELMTUI-CLPM-07-TERMINAL-REFINE-20261014-R2
Packet: d304ad30-e992-45a8-b6e9-d20486ab82c9
Predecessor: ELMTUI-CLPM-07-QUALIFICATION-ENHANCE-20261014
Mutation transaction: 6c9999ca-4ae5-445c-b09a-de0ec3658433
Base revision: d29eace7bda867a353e4086551bc0031f4cfc986

## Reproduction and diagnosis

- Before correction: `python3 tests/e2e/test-bottom-row.py --output test-output/terminal-r2-repro`, exit 1, 0/2. Declared Wi-Fi root viewport is 13 rows in `examples/wifi-menu.lisp`; real 100x35 tmux PTY paints header at physical row 23, preserving ROW-14 through ROW-35. Trace emits CSI 13S, then CSI 13T during normal exit; termios and cursor restored. The test's hardcoded 20-row and single-step CSI assertions contradicted the application's declared geometry and ANSI's legal count-bearing scroll syntax.
- Before correction: `python3 tests/e2e/test-neon-terminal-restoration.py --output test-output/terminal-r2-neon`, exit 1, 1/2. Real trace CSI 24S and CSI 24T, while matcher only counted CSI 1S and CSI 1T. No source scroll implementation change was justified.
- Native screenshot cause: PATH resolves `import` to `/home/user/.local/bin/import`, a rofi shell script. Actual ImageMagick capture is `/usr/bin/import`. Native capture now selects system executable and fails closed without image capture/OCR prerequisites. Captured pixels/OCR subsequently show ROW-14..ROW-35 but not Wi-Fi title or guest, although PTY bytes contain both strings. This is an unresolved framebuffer/urxvt display defect.
- No reset or alternate-screen escape was introduced by these changes.

## Focused regression matrix

| Command | Exit | Cases | Evidence |
|---|---:|---|---|
| `python3 -m py_compile tests/e2e/test-bottom-row.py tests/e2e/test-neon-terminal-restoration.py tests/e2e/test-native-urxvt.py` | 0 | syntax | local cold Python compile |
| `python3 tests/e2e/test-bottom-row.py --output test-output/terminal-r2-fixed-bottom` | 0 | 2/2 pass | real private tmux, fake nmcli, screen/scroll/cursor/termios/scrollback |
| `python3 tests/e2e/test-neon-terminal-restoration.py --output test-output/terminal-r2-fixed-neon` | 0 | 2/2 pass | real private tmux bottom/top, CSI distances |
| `python3 scripts/test-terminal-apps.py --case wifi --output test-output/terminal-r2-wifi` | 0 | 4/4 pass | input, latency, fake nmcli, ordering |
| `python3 tests/e2e/test-native-urxvt.py --output test-output/terminal-r2-fixed-native` | 1 | 0/2 pass | PNGs created, OCR misses menu in framebuffer; screenshots not skipped |
| `python3 scripts/test-terminal-apps.py --case life --output test-output/terminal-r2-life` | 1 | 0/1 pass | actual ◉ PAUSED; harness expects Ⅱ PAUSED (not changed) |

## Executable residual gap ledger

1. **Native urxvt visible menu:** Diagnose PTY-to-X11 framebuffer position and capture ownership. Compare native cursor query, window geometry, OCR/PNG, physical row and pixels; require menu visible in screenshot and restored shell text. Keep native result FAIL until independently verified.
2. **Game of Life PTY expectation:** Determine whether current paused glyph `◉` is the intended UI contract, with source history and native view; change only if semantic evidence supports it. Preserve real pause/resume and shell restoration.
3. **Additional qualification:** tiny/large/tiny resize, slow double-Enter exactly one in-flight nmcli, exception unwind, bounded repeat shutdown, full 8397-check root suite and independent reviewer have not been completed by this packet. Do not report as pass.
4. **Review:** Separate authenticated reviewer must inspect exact source/test diff and rerun the native evidence. No author self-approval.

All other dirty work, root coverage/CI, macro/DSL, library paths and `docs/release-history-purge.md` deletion are preserved. No push, tag, release or history rewrite.
