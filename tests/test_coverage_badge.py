"""Test that the gate builds a machine-derived badge only on success."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "coverage-gate.py"
spec = importlib.util.spec_from_file_location("coverage_badge_gate", SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class BadgeTests(unittest.TestCase):
    def test_success_and_failure_are_consistent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "src").mkdir()
            (root / "src" / "one.lisp").write_text("(print :ok)\n")
            inventory = root / "sources.txt"
            inventory.write_text("src/one.lisp\n")
            report = root / "report.html"
            report.write_text(f"<table><tr><td colspan='7'>{root / 'src'}/</td></tr>"
                "<tr><td><a href='one.html'>one.lisp</a></td><td>1</td><td>2</td>"
                "<td>50%</td><td>0</td><td>0</td><td>-</td></tr></table>")
            out = root / "out"
            gate.check(report, inventory, root, 46.0, out, baseline=inventory)
            provenance = json.loads((out / "coverage-summary.json").read_text())
            self.assertEqual((provenance["covered_expressions"], provenance["total_expressions"]), (1, 2))
            self.assertIn("50.00%", (out / "coverage-badge.svg").read_text())
            endpoint = json.loads((out / "endpoint.json").read_text())
            self.assertEqual(endpoint["schemaVersion"], 1)
            self.assertEqual(endpoint["message"], "50.00%")
            with self.assertRaisesRegex(ValueError, "ratchet"):
                gate.check(report, inventory, root, 51.0, out, baseline=inventory)
            self.assertFalse((out / "coverage-badge.svg").exists())
            self.assertFalse((out / "endpoint.json").exists(),
                             "a failed gate must not leave a publishable badge endpoint")
            self.assertFalse((out / "coverage-summary.json").exists())


if __name__ == "__main__":
    unittest.main()
