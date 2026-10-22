#!/usr/bin/env python3
"""Keep the examples capability atlas exhaustive and all local links resolvable.

Run:
    python3 -m unittest tests/test_examples_capability_index.py
"""

from collections import Counter
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / "docs/examples-capability-index.md"
SOURCE_DIR = ROOT / "examples"
GUIDE = SOURCE_DIR / "README.md"


class ExamplesCapabilityIndexTest(unittest.TestCase):
    def test_each_top_level_lisp_source_has_one_catalog_row(self):
        content = ATLAS.read_text(encoding="utf-8")
        # Tour links intentionally repeat six highlighted examples. Only
        # the five numbered tables constitute the one-to-one inventory.
        tables = content.split("## 1. Language of ElmTUI:", 1)[1].split(
            "## Qualification map:", 1
        )[0]
        sources = {path.name for path in SOURCE_DIR.glob("*.lisp")}
        references = re.findall(
            r"^\|\s*\[[^\]]+\]\(\.\./examples/([^)]+\.lisp)\)\s*\|",
            tables,
            re.MULTILINE,
        )
        counts = Counter(references)
        self.assertEqual(set(counts), sources,
                         f"Unindexed: {sorted(sources - set(counts))}\n"
                         f"Unexpected: {sorted(set(counts) - sources)}")
        self.assertEqual(
            {name: count for name, count in counts.items() if count != 1}, {},
            "Every example source must have exactly one distinct catalog row",
        )

    def test_local_atlas_links_exist(self):
        content = ATLAS.read_text(encoding="utf-8")
        for target in re.findall(r"\]\(([^)#]+)(?:#[^)]+)?\)", content):
            if "://" in target or target.startswith("#"):
                continue
            with self.subTest(target=target):
                self.assertTrue((ATLAS.parent / target).exists(),
                                f"Broken local index link: {target}")

    def test_examples_guide_links_capability_atlas(self):
        self.assertIn("../docs/examples-capability-index.md",
                      GUIDE.read_text(encoding="utf-8"))

    def test_support_and_optional_classification_matches_asdf(self):
        asd = (ROOT / "elmtui-examples.asd").read_text(encoding="utf-8")
        base = set(re.findall(r'\(:file\s+"([^"]+)"\)', asd))
        sources = {source.stem for source in SOURCE_DIR.glob("*.lisp")}
        self.assertTrue(base <= sources)
        self.assertEqual(
            sources - base,
            {"async-weather", "fzy-picker", "tmux-glider",
             "tmux-slider", "workbench"},
            "Update the atlas classification when the ASDF graph changes",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
