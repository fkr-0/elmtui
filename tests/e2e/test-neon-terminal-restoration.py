#!/usr/bin/env python3
"""Black-box regression: below-cursor Neon apps must never paint before reservation."""
import argparse
import importlib.util
from pathlib import Path
import re
import sys
import time
import tempfile
import types
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[2]
loader = importlib.util.spec_from_file_location('terminal_apps', ROOT / 'scripts/test-terminal-apps.py')
harness = importlib.util.module_from_spec(loader)
loader.loader.exec_module(harness)


class NeonRestoration(unittest.TestCase):
    def scenario(self, cursor_row, expected_scroll):
        prelude = "printf '\\033[2J'\n" + '\n'.join(
            "printf '\\033[%d;1HROW-%02d'" % (row, row) for row in range(1, 36)
        ) + "\nprintf '\\033[%d;9H'" % cursor_row
        app = harness.TerminalApp(
            'neon-tetris-restoration', '(elmtui.examples.neon-tetris:run-neon-tetris)',
            source='neon-tetris.lisp', use_launcher=False, prelude=prelude,
        )
        self.addCleanup(app.close)
        app.start()
        screen = app.expect('STACK LAB')
        rows = screen.splitlines()
        self.assertIn('TETRIS  /  STACK LAB', rows[11] if expected_scroll else rows[cursor_row],
                      'Tetris must be drawn immediately beneath its reserved origin')
        if expected_scroll:
            for i in range(11):
                self.assertTrue(rows[i].startswith('ROW-%02d' % (i + 25)),
                                'shell rows must survive reservation unmodified')
        app.key('q', 'q')
        end = time.monotonic() + 7
        while not (app.directory / 'exit-code').exists() and time.monotonic() < end:
            time.sleep(.06)
        self.assertTrue((app.directory / 'exit-code').exists(), 'Tetris must quit normally')
        self.assertEqual((app.directory / 'exit-code').read_text().strip(), '0')
        time.sleep(.15)
        restored = app.screen()
        self.assertNotIn('TETRIS', restored)
        self.assertNotIn('TELEMETRY', restored)
        self.assertNotIn('GHOST LANDING', restored)
        lines = restored.splitlines()
        if expected_scroll:
            # CSI T inserts blank rows; rows pushed beyond the top into
            # scrollback are not recoverable through reverse scrolling.
            for row in range(1 + expected_scroll, 35):
                self.assertEqual(lines[row - 1], 'ROW-%02d' % row,
                                 'shell rows that remain on screen must survive')
        else:
            for row in range(26, 36):
                self.assertEqual(lines[row - 1], 'ROW-%02d' % row,
                                 'rows outside the owned viewport must survive')
        self.assertIn('ELMTUI_E2E_SHELL_RESTORED', lines[cursor_row - 1])
        self.assertEqual((app.directory / 'before.stty').read_text(),
                         (app.directory / 'after.stty').read_text())
        raw = (app.directory / 'terminal.raw').read_bytes().split(b'\x1b[6n', 1)[-1]
        first_frame = raw.find(b'TETRIS')
        first_scroll = raw.find(b'\x1b[1S')
        steps_up = len(re.findall(rb'\x1b\[1S', raw))
        steps_down = len(re.findall(rb'\x1b\[1T', raw))
        self.assertEqual(steps_up, expected_scroll)
        self.assertEqual(steps_down, expected_scroll)
        if expected_scroll:
            self.assertTrue(0 <= first_scroll < first_frame,
                            'scroll reservation must complete before first Tetris paint')

    def test_bottom_cursor_reservation_and_restoration(self):
        self.scenario(35, 24)

    def test_top_cursor_does_not_duplicate_or_strand_frames(self):
        self.scenario(1, 0)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--timeout', type=float, default=12)
    p.add_argument('--output', type=Path)
    args = p.parse_args()
    args.terminal = 'tmux'
    args.output = (args.output or Path(tempfile.mkdtemp(prefix='neon-restoration-'))).resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    harness.OPTIONS = args
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(NeonRestoration))
    print('Artifacts:', args.output)
    sys.exit(0 if result.wasSuccessful() else 1)
