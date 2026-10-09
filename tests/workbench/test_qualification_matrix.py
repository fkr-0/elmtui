#!/usr/bin/env python3
"""Validate the workbench qualification case catalog, not the application.

Run: python3 -m unittest discover -s tests/workbench -p 'test_qualification_matrix.py'
The individual cases remain NOT RUN until explicit, evidence-backed execution.
"""
import json
import re
import unittest
from collections import Counter
from pathlib import Path

MATRIX = Path(__file__).with_name("qualification-matrix.json")
VALID_KINDS = {"unit", "pty", "static"}
VALID_LANES = {"editor", "eval", "completion", "inspector", "integration"}
REQUIRED_PTY = {
    "completion-above-cursor",
    "completion-doc-dwell",
    "integration-termios",
    "integration-80x24",
    "integration-120x40",
    "integration-160x50",
    "integration-resize",
    "eval-infinite-loop",
    "inspector-refresh",
}
REQUIRED_SIZES = {(80, 24), (120, 40), (160, 50)}


class QualificationMatrixContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads(MATRIX.read_text(encoding="utf-8"))
        cls.cases = cls.catalog["cases"]

    def test_schema_and_expected_terminal_sizes(self):
        self.assertEqual(
            self.catalog["schema"], "elmtui.workbench.qualification-matrix/v1"
        )
        self.assertEqual(
            {(item["cols"], item["rows"]) for item in self.catalog["terminalSizes"]},
            REQUIRED_SIZES,
        )
        self.assertEqual(set(self.catalog["lanes"]), VALID_LANES)
        self.assertEqual(set(self.catalog["kinds"]), VALID_KINDS)

    def test_cases_unique_nontrivial_and_pending(self):
        identifiers = [case["id"] for case in self.cases]
        self.assertGreaterEqual(len(identifiers), 25)
        self.assertEqual(len(identifiers), len(set(identifiers)))
        for case in self.cases:
            with self.subTest(case=case["id"]):
                self.assertRegex(case["id"], r"^[a-z][a-z0-9-]+$")
                self.assertIn(case["lane"], VALID_LANES)
                self.assertIn(case["kind"], VALID_KINDS)
                self.assertTrue(case["required"])
                self.assertGreaterEqual(len(case["scenario"]), 30)
                self.assertGreaterEqual(len(case["oracle"]), 15)
                self.assertEqual(case["status"], "not-run")

    def test_lane_coverage(self):
        counts = Counter(case["lane"] for case in self.cases)
        for lane in VALID_LANES:
            with self.subTest(lane=lane):
                self.assertGreaterEqual(counts[lane], 4)

    def test_black_box_and_safety_gates_present(self):
        by_id = {case["id"]: case for case in self.cases}
        self.assertTrue(REQUIRED_PTY.issubset(by_id))
        for name in REQUIRED_PTY:
            self.assertEqual(by_id[name]["kind"], "pty")
        for name in (
            "integration-reader-security",
            "integration-remote-opt-in",
            "inspector-cycles",
            "eval-cancel-race",
            "completion-stale-generation",
        ):
            self.assertIn(name, by_id)


if __name__ == "__main__":
    unittest.main()
