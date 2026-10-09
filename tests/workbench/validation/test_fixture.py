"""Only driver/fixture tests; never mark W1-W5 application cases PASS."""
import tempfile
import os
from contextlib import contextmanager
from pathlib import Path
import sys
import unittest

from pty import PrivatePTY

HERE = Path(__file__).resolve().parent


@contextmanager
def evidence_root(case_name):
    configured = os.environ.get("ELMTUI_WB_QA_ARTIFACT_DIR")
    if configured:
        root = Path(configured) / case_name
        root.mkdir(parents=True, exist_ok=True)
        yield root
    else:
        with tempfile.TemporaryDirectory(prefix="wb-qa-fixture-") as temporary:
            yield Path(temporary)


@unittest.skipUnless(PrivatePTY.available(), "private tmux/stty not installed")
class RealTerminalFixtureTests(unittest.TestCase):
    def open_fixture(self, root, cols, rows):
        return PrivatePTY([sys.executable, "-u", str(HERE / "terminal_fixture.py")],
                          Path(root) / ("%dx%d" % (cols, rows)), cols, rows)

    def test_fixture_input_resize_and_restoration(self):
        with evidence_root("input-resize-restoration") as td:
            with self.open_fixture(td, 80, 24) as tty:
                tty.expect("WB_QA_FIXTURE_READY")
                tty.text("z")
                tty.expect("FIXTURE_KEY:7A")
                for dims in ((120, 40), (160, 50), (80, 24)):
                    tty.resize(*dims)
                tty.text("q")
                done = tty.finish(key=None)
                self.assertEqual(done["exit_code"], 0)
                self.assertTrue(done["termios_restored"])
                self.assertTrue(done["cursor_visible"])
                self.assertTrue(done["shell_sentinel"])
                raw = tty.artifact_dir / "terminal.raw"
                self.assertTrue(raw.exists() and raw.stat().st_size > 0)

    def test_fixture_idle_has_zero_terminal_writes(self):
        with evidence_root("idle-zero-writes") as td:
            with self.open_fixture(td, 120, 40) as tty:
                tty.expect("WB_QA_FIXTURE_READY")
                # A successful fixture test is *not* an application idle proof.
                self.assertEqual(tty.idle_bytes(0.35), 0)
                tty.text("q")
                self.assertEqual(tty.finish(key=None)["exit_code"], 0)


if __name__ == "__main__":
    unittest.main()
