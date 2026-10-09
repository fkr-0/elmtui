"""Self-tests for the generated API reference verifier."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "elmtui_ref_qualifier", ROOT / "scripts/qualify-api-reference.py")
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def fake_reference(name="ELMTUI.APP:DEFAPPLICATION", doc="Forms"):
    markdown = (
        "# ElmTUI API Reference\n\n"
        "**Coverage:** 1 of 1 bindings documented; 0 have no metadata\n\n"
        f"## {name}\n\nKinds: macro\n\n"
        + chr(96) * 3 + f"text\n{doc}\n" + chr(96) * 3 + "\n"
    )
    html = (
        "<html><body><section>"
        f"<h2>{name}</h2><p>Kinds: macro</p><pre>{doc}</pre>"
        "</section></body></html>"
    )
    return markdown, html


class QualifierRegression(unittest.TestCase):
    def test_markdown_fence_protects_fake_headings(self):
        markdown, _ = fake_reference(doc="This describes a macro.\n## INVENTED:EXPORT")
        actual, text = MODULE.markdown_entries(markdown)
        self.assertEqual(len(actual), 1)
        self.assertEqual(actual[0].qualified, "ELMTUI.APP:DEFAPPLICATION")
        self.assertIn("## INVENTED:EXPORT", text[0])

    def test_duplicate_heading_rejected(self):
        markdown, _ = fake_reference()
        duplicate = "## ELMTUI.APP:DEFAPPLICATION\n\nKinds: macro\n\n_No documentation metadata._\n"
        with self.assertRaisesRegex(AssertionError, "Duplicate API headings"):
            MODULE.markdown_entries(markdown + duplicate)

    def test_unknown_export_cannot_pass_full_comparison(self):
        markdown, html = fake_reference(name="ELMTUI.APP:IMAGINARY")
        with tempfile.TemporaryDirectory() as root:
            md = Path(root) / "api.md"
            out = Path(root) / "api.html"
            md.write_text(markdown)
            out.write_text(html)
            live = MODULE.Entry("ELMTUI.APP:DEFAPPLICATION", "macro", True)
            with patch.object(MODULE, "live_entries", return_value=[live]):
                with self.assertRaisesRegex(AssertionError, "stale or incorrectly qualified"):
                    MODULE.qualify(markdown=md, html=out, strict_coverage=False)

    def test_unsafe_unclosed_fence_rejected(self):
        markdown, _ = fake_reference()
        markdown = markdown[:-3]
        with self.assertRaisesRegex(AssertionError, "Unclosed documentation fence"):
            MODULE.markdown_entries(markdown)


if __name__ == "__main__":
    unittest.main()
