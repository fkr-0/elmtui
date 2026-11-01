"""Negative-path qualification for primary SB-COVER accounting."""
import importlib.util
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "coverage-gate.py"
spec = importlib.util.spec_from_file_location("coverage_gate", SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class CoverageGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "src").mkdir()
        (self.root / "src" / "a.lisp").write_text("(+ 1 2)")
        (self.root / "src" / "b.lisp").write_text("(+ 3 4)")
        self.inventory = self.root / "inventory"
        self.inventory.write_text("src/a.lisp\nsrc/b.lisp\n")
        self.report = self.root / "report.html"
        self.render()

    def render(self, first=(1, 2), second=(0, 8)):
        def row(name, counts):
            return (f"<tr><td><a href='{name}.html'>{name}.lisp</a></td>"
                    f"<td>{counts[0]}</td><td>{counts[1]}</td><td>0%</td>"
                    "<td>0</td><td>0</td><td>-</td></tr>")
        self.report.write_text(
            f"<table><tr><td colspan='7'>{self.root / 'src'}/</td></tr>"
            + row("a", first) + row("b", second) + "</table>")

    def check(self, minimum=0):
        return gate.check(self.report, self.inventory, self.root, minimum, None)

    def test_failed_gate_invalidates_previous_summary(self):
        output = self.root / 'output'
        gate.check(self.report, self.inventory, self.root, 0, output)
        self.assertTrue((output / 'coverage-summary.json').exists())
        with self.assertRaisesRegex(ValueError, 'ratchet regression'):
            gate.check(self.report, self.inventory, self.root, 90, output)
        self.assertFalse((output / 'coverage-summary.json').exists())

    def test_nan_minimum_fails(self):
        with self.assertRaisesRegex(ValueError, 'finite'):
            self.check(minimum=float('nan'))

    def test_json_provenance_includes_zero_covered_file(self):
        import json
        out = self.root / 'output'
        gate.check(self.report, self.inventory, self.root, 0, out)
        info = json.loads((out / 'coverage-summary.json').read_text())
        self.assertEqual(info['covered_expressions'], 1)
        self.assertEqual(info['total_expressions'], 10)
        self.assertIn('src/b.lisp', info['source_sha256'])
        self.assertIn('10.00%', (out / 'coverage-badge.svg').read_text())

    def test_zero_covered_source_still_in_denominator(self):
        self.check(minimum=10)  # 1 / 10, not mean(50%, excluded 0%)
        with self.assertRaisesRegex(ValueError, "ratchet regression"):
            self.check(minimum=11)

    def test_missing_source_fails_closed(self):
        self.report.write_text(self.report.read_text().replace(
            "<tr><td><a href='b.html'>b.lisp</a></td><td>0</td><td>8</td><td>0%</td><td>0</td><td>0</td><td>-</td></tr>", ""))
        with self.assertRaisesRegex(ValueError, "absent"):
            self.check()

    def test_malformed_counts_fails(self):
        self.render(first=("broken", 2))
        with self.assertRaisesRegex(ValueError, "Malformed"):
            self.check()

    def test_zero_total_fails(self):
        self.render(second=(0, 0))
        with self.assertRaisesRegex(ValueError, "denominator"):
            self.check()

    def test_covered_greater_than_total_fails(self):
        self.render(first=(3, 2))
        with self.assertRaisesRegex(ValueError, "denominator"):
            self.check()

    def test_reviewed_inventory_mismatch_fails(self):
        baseline = self.root / 'baseline'
        baseline.write_text('src/a.lisp\n')
        with self.assertRaisesRegex(ValueError, 'inventory drift'):
            gate.check(self.report, self.inventory, self.root, 0, None, baseline=baseline)

    def test_missing_reviewed_baseline_fails(self):
        with self.assertRaisesRegex(ValueError, 'Missing reviewed'):
            gate.check(self.report, self.inventory, self.root, 0, None, baseline=self.root / 'missing')

    def test_denominator_drift_fails(self):
        with self.assertRaisesRegex(ValueError, "denominator drift"):
            gate.check(self.report, self.inventory, self.root, 0, None, 11)

    def test_missing_report_fails(self):
        self.report.unlink()
        with self.assertRaisesRegex(ValueError, "Missing"):
            self.check()

    def test_missing_inventory_fails(self):
        self.inventory.unlink()
        with self.assertRaisesRegex(ValueError, "Missing"):
            self.check()

    def test_duplicate_inventory_fails(self):
        self.inventory.write_text("src/a.lisp\nsrc/a.lisp\n")
        with self.assertRaisesRegex(ValueError, "duplicate"):
            self.check()

    def test_unexpected_escape_fails(self):
        self.inventory.write_text("../outside.lisp\n")
        with self.assertRaisesRegex(ValueError, "Invalid inventory"):
            self.check()


if __name__ == "__main__":
    unittest.main()
