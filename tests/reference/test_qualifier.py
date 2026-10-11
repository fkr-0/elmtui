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
        with tempfile.TemporaryDirectory(dir=ROOT) as root:
            md = Path(root) / "api.md"
            out = Path(root) / "api.html"
            md.write_text(markdown)
            out.write_text(html)
            live = MODULE.Entry("ELMTUI.APP:DEFAPPLICATION", "macro", True)
            with patch.object(MODULE, "live_entries", return_value=[live]):
                with self.assertRaisesRegex(AssertionError, "stale or incorrectly qualified"):
                    MODULE.qualify(markdown=md, html=out, strict_coverage=False)

    def test_stale_landing_page_coverage_rejected(self):
        markdown, html = fake_reference()
        with tempfile.TemporaryDirectory(dir=ROOT) as root:
            root_path = Path(root)
            (root_path / "website").mkdir()
            (root_path / "website" / "reference.md").write_text(
                "**Current audited coverage: 0/1 (0.0%).**\n"
                "1 public bindings lack documentation.\n"
            )
            md = root_path / "api.md"
            out = root_path / "api.html"
            md.write_text(markdown)
            out.write_text(html)
            live = MODULE.Entry("ELMTUI.APP:DEFAPPLICATION", "macro", True)
            with patch.object(MODULE, "ROOT", root_path), \
                    patch.object(MODULE, "live_entries", return_value=[live]):
                with self.assertRaisesRegex(AssertionError, "landing page coverage"):
                    MODULE.qualify(markdown=md, html=out, strict_coverage=False)

    def test_wrapped_landing_page_coverage_is_accepted(self):
        markdown, html = fake_reference()
        with tempfile.TemporaryDirectory(dir=ROOT) as root:
            root_path = Path(root)
            (root_path / "website").mkdir()
            (root_path / "website" / "reference.md").write_text(
                "**Current audited coverage: 1/1 (100.0%).**\n"
                "0 public bindings\nlack documentation.\n"
            )
            md = root_path / "api.md"
            out = root_path / "api.html"
            md.write_text(markdown)
            out.write_text(html)
            live = MODULE.Entry("ELMTUI.APP:DEFAPPLICATION", "macro", True)
            with patch.object(MODULE, "ROOT", root_path), \
                    patch.object(MODULE, "live_entries", return_value=[live]):
                MODULE.qualify(markdown=md, html=out, strict_coverage=False)

    def test_unsafe_unclosed_fence_rejected(self):
        markdown, _ = fake_reference()
        markdown = markdown[:-3]
        with self.assertRaisesRegex(AssertionError, "Unclosed documentation fence"):
            MODULE.markdown_entries(markdown)


    def test_documented_entry_rejects_html_doc_drift(self):
        markdown, html = fake_reference(doc="Expected behavior")
        html = html.replace("<pre>Expected behavior</pre>", "<pre>Different behavior</pre>")
        with tempfile.TemporaryDirectory() as root:
            md, page = Path(root) / "api.md", Path(root) / "api.html"
            md.write_text(markdown)
            page.write_text(html)
            live = MODULE.Entry("ELMTUI.APP:DEFAPPLICATION", "macro", True)
            with patch.object(MODULE, "live_entries", return_value=[live]):
                with self.assertRaisesRegex(AssertionError, "documentation mismatch"):
                    MODULE.qualify(markdown=md, html=page, strict_coverage=False)

    def test_missing_entry_rejects_fake_html_documentation(self):
        markdown, html = fake_reference(doc="Forms")
        markdown = markdown.replace(
            "**Coverage:** 1 of 1 bindings documented; 0 have no metadata",
            "**Coverage:** 0 of 1 bindings documented; 1 have no metadata",
)
        markdown = markdown.replace(
            chr(96) * 3 + "text\nForms\n" + chr(96) * 3,
            "_No documentation metadata._",
        )
        with tempfile.TemporaryDirectory() as root:
            md, page = Path(root) / "api.md", Path(root) / "api.html"
            md.write_text(markdown)
            page.write_text(html)
            live = MODULE.Entry("ELMTUI.APP:DEFAPPLICATION", "macro", False)
            with patch.object(MODULE, "live_entries", return_value=[live]):
                with self.assertRaisesRegex(AssertionError, "missing-documentation marker"):
                    MODULE.qualify(markdown=md, html=page, strict_coverage=False)

    def test_documentation_html_escape_roundtrips(self):
        markdown, html = fake_reference(doc="Literal <em>tag</em> & escaped")
        html = html.replace(
            "<pre>Literal <em>tag</em> & escaped</pre>",
            "<pre>Literal &lt;em&gt;tag&lt;/em&gt; &amp; escaped</pre>",
        )
        with tempfile.TemporaryDirectory() as root:
            md, page = Path(root) / "api.md", Path(root) / "api.html"
            md.write_text(markdown)
            page.write_text(html)
            live = MODULE.Entry("ELMTUI.APP:DEFAPPLICATION", "macro", True)
            with patch.object(MODULE, "live_entries", return_value=[live]):
                MODULE.qualify(markdown=md, html=page, strict_coverage=False)

    def test_strict_coverage_rejects_missing_metadata(self):
        markdown, html = fake_reference(doc="Forms")
        markdown = markdown.replace(
            "**Coverage:** 1 of 1 bindings documented; 0 have no metadata",
            "**Coverage:** 0 of 1 bindings documented; 1 have no metadata",
        ).replace(
            chr(96) * 3 + "text\nForms\n" + chr(96) * 3,
            "_No documentation metadata._",
        )
        html = html.replace("<pre>Forms</pre>", "<pre>No documentation metadata.</pre>")
        with tempfile.TemporaryDirectory() as root:
            md, page = Path(root) / "api.md", Path(root) / "api.html"
            md.write_text(markdown)
            page.write_text(html)
            live = MODULE.Entry("ELMTUI.APP:DEFAPPLICATION", "macro", False)
            with patch.object(MODULE, "live_entries", return_value=[live]):
                MODULE.qualify(markdown=md, html=page, strict_coverage=False)
                with self.assertRaisesRegex(AssertionError, "REFERENCE-DOCSTRING-DEBT"):
                    MODULE.qualify(markdown=md, html=page, strict_coverage=True)

if __name__ == "__main__":
    unittest.main()
