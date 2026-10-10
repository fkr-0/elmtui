#!/usr/bin/env python3
"""Neon Life/Glider end-to-end: animated frames, pause, stepping and TTY cleanup."""
from __future__ import annotations

import re
import sys
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/workbench/independent"))
from pty_driver import PrivateTmuxPTY

@unittest.skipUnless(PrivateTmuxPTY.available(), "private tmux and stty not installed")
class NeonLifeGliderPTY(unittest.TestCase):
    def check_application(self, name, title, token):
        with PrivateTmuxPTY(["./examples.sh", "run", name],
                            cols=100, rows=35, timeout=14) as terminal:
            terminal.wait_for(title, timeout=15)
            initial = terminal.capture()
            self.assertLessEqual(max(map(len, initial.splitlines())), 100)
            pattern = re.compile(r"\b" + token + r"\s+(\d+)")
            initial_match = pattern.search(initial)
            self.assertIsNotNone(initial_match, initial[-2500:])
            first = int(initial_match.group(1))
            time.sleep(.75)
            later = terminal.capture()
            later_match = pattern.search(later)
            self.assertIsNotNone(later_match, later[-2500:])
            second = int(later_match.group(1))
            self.assertGreater(second, first, "timer subscription never advanced")
            terminal.send_text(" ")
            terminal.wait_for("PAUSED", timeout=5)
            time.sleep(.18)
            paused = terminal.capture()
            time.sleep(.45)
            idle = terminal.capture()
            self.assertEqual(paused, idle, "screen changed while paused")
            before_step = int(pattern.search(idle).group(1))
            terminal.send_text("n")
            stepped = terminal.wait_for(
                lambda s: bool(pattern.search(s)) and
                int(pattern.search(s).group(1)) == before_step + 1,
                timeout=5)
            self.assertIn("PAUSED", stepped)
            terminal.send_text("r")
            terminal.wait_for(
                lambda s: bool(pattern.search(s)) and
                int(pattern.search(s).group(1)) < before_step + 1,
                timeout=5)
            terminal.send_text("q")
            code, termios_restored = terminal.wait_for_exit(timeout=8)
            self.assertEqual(code, 0)
            self.assertTrue(termios_restored, "terminal mode not restored")

    def test_game_of_life(self):
        self.check_application("neon-life", "NEON BIOSPHERE", "GEN")

    def test_glider_animation(self):
        self.check_application("neon-glider", "NEON FLIGHT CONTROL", "TICK")

    def check_original(self, name, title, token):
        with PrivateTmuxPTY(["./examples.sh", "run", name],
                            cols=100, rows=35, timeout=14) as terminal:
            terminal.wait_for(title, timeout=15)
            expression = re.compile(r"\b" + token + r"\s*(\d+)")
            first_screen = terminal.capture()
            first = expression.search(first_screen)
            self.assertIsNotNone(first, first_screen[-1800:])
            time.sleep(.75)
            second_screen = terminal.capture()
            second = expression.search(second_screen)
            self.assertIsNotNone(second, second_screen[-1800:])
            self.assertGreater(int(second.group(1)), int(first.group(1)))
            terminal.send_text("q")
            code, restored = terminal.wait_for_exit(timeout=8)
            self.assertEqual(code, 0)
            self.assertTrue(restored)

    def test_original_game_of_life_launcher(self):
        self.check_original("game-of-life", "LIFE / NEON GRID", "GEN")

    def test_original_life_80x24_pause_step_and_resize(self):
        with PrivateTmuxPTY(["./examples.sh", "run", "game-of-life"],
                            cols=80, rows=24, timeout=14) as terminal:
            terminal.wait_for("LIFE / NEON GRID", timeout=15)
            initial = terminal.capture()
            self.assertIn("┌", initial)
            self.assertIn("40 × 20 MATRIX", initial)
            self.assertNotIn("╭", initial)
            self.assertEqual(len(initial.splitlines()), 24)
            self.assertLessEqual(max(map(len, initial.splitlines())), 80)
            terminal.send_text("p")
            terminal.wait_for("PAUSED", timeout=4)
            time.sleep(.2)
            frozen = terminal.capture()
            time.sleep(.4)
            self.assertEqual(frozen, terminal.capture(),
                             "paused original Life still repaints")
            matcher = re.compile(r"GEN\s*(\d+)")
            generation = matcher.search(frozen)
            self.assertIsNotNone(generation)
            expected = int(generation.group(1)) + 1
            terminal.send_text("n")
            stepped = terminal.wait_for(
                lambda text: (bool(matcher.search(text))
                              and int(matcher.search(text).group(1)) == expected),
                timeout=4)
            self.assertIn("PAUSED", stepped)
            terminal.resize(120, 40)
            self.assertEqual(terminal.geometry(), (120, 40))
            after = terminal.capture()
            self.assertIn("LIFE / NEON GRID", after)
            self.assertLessEqual(max(map(len, after.splitlines())), 120)
            terminal.send_text("q")
            code, restored = terminal.wait_for_exit(timeout=8)
            self.assertEqual(code, 0)
            self.assertTrue(restored)


    def test_original_glider_real_launcher(self):
        self.check_original("glider-real", "NEON FLIGHT CONTROL", "TICK")

if __name__ == "__main__":
    unittest.main()
