"""Headless CI must run the real urxvt gate with a private Xvfb display."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
URXVT_GATE = re.compile(
    r'(?m)^run_gate[ \t]+terminal_urxvt[ \t]+xvfb-run[ \t]+-a[ \t]+'
    r'python3[ \t]+scripts/test-terminal-apps\.py[ \t]+--terminal[ \t]+urxvt(?:[ \t]|$)'
)


class ReleaseCiXvfbTests(unittest.TestCase):
    def test_headless_urxvt_gate_uses_independent_x_display(self):
        script = (ROOT / "scripts/release-check.sh").read_text()
        self.assertIn("run_gate xvfb_ci_contract", script)
        self.assertIsNotNone(
            URXVT_GATE.search(script),
            "urxvt suite must be run inside xvfb-run -a in headless CI",
        )
        self.assertEqual(
            len(re.findall(r'(?m)^run_gate[ \t]+terminal_urxvt(?:[ \t]|$)', script)),
            1, "one mandatory terminal_urxvt gate",
        )
        # Negative mutation tests the guard rather than trusting a comment.
        self.assertIsNone(URXVT_GATE.search(script.replace("xvfb-run -a ", "")))

    def test_ci_installs_display_prerequisites(self):
        ci = (ROOT / ".github/workflows/ci.yml").read_text()
        for package in ("xvfb", "rxvt-unicode", "xdotool", "tmux"):
            self.assertIn(package, ci, f"CI lacks display dependency: {package}")
        self.assertIn("run: scripts/release-check.sh", ci)


if __name__ == "__main__":
    unittest.main()
