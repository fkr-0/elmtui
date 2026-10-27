"""Link-retargeting guards for the curated documentation staging script."""
import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "prepare-site.py"
spec = importlib.util.spec_from_file_location("prepare_site", SCRIPT)
site = importlib.util.module_from_spec(spec)
spec.loader.exec_module(site)

ROOT = site.ROOT


class RetargetLinksTests(unittest.TestCase):
    def setUp(self):
        self.source = ROOT / "examples" / "README.md"
        self.target = ROOT / "website" / "guide" / "examples-catalog.md"
        self.staged = {
            (ROOT / "docs" / "workbench-user-guide.md").resolve():
                ROOT / "website" / "guide" / "workbench-user-guide.md",
            self.source.resolve(): self.target,
        }

    def retarget(self, text):
        return site.retarget_links(text, self.source, self.target, self.staged)

    def test_link_to_staged_page_becomes_sibling(self):
        self.assertEqual(
            self.retarget("[g](../docs/workbench-user-guide.md#top)"),
            "[g](workbench-user-guide.md#top)")

    def test_link_to_unstaged_repo_file_becomes_blob_url(self):
        self.assertEqual(
            self.retarget("[a](../docs/examples-capability-index.md)"),
            f"[a]({site.REPO_BLOB}docs/examples-capability-index.md)")

    def test_external_anchor_absolute_and_missing_links_are_untouched(self):
        for link in ("[x](https://example.org/a.md)", "[x](#section)",
                     "[x](/abs/path.md)", "[x](mailto:a@b.c)",
                     "[x](../docs/does-not-exist-anywhere.md)"):
            with self.subTest(link=link):
                self.assertEqual(self.retarget(link), link)

    def test_staged_pages_have_no_unresolvable_relative_markdown_links(self):
        for source_name, target_name in site.PAGES.items():
            source, target = ROOT / source_name, ROOT / target_name
            if not source.is_file():
                continue
            staged = {(ROOT / s).resolve(): ROOT / t for s, t in site.PAGES.items()}
            text = site.retarget_links(source.read_text(), source, target, staged)
            for match in site.LINK.finditer(text):
                path = match.group(2).partition("#")[0]
                if not path.endswith(".md") or ":" in path or path.startswith("/"):
                    continue
                with self.subTest(page=target_name, link=path):
                    candidate = (target.parent / path).resolve()
                    self.assertTrue(
                        candidate.is_file() or candidate in
                        {t.resolve() for t in staged.values()} or
                        (ROOT / "website" / path).exists(),
                        f"{target_name} links to unstaged {path}")


class StagedSiteIntegrationTests(unittest.TestCase):
    """Real staged document and image files, including a second identical run."""

    def test_copy_links_and_images_from_fixture_repository(self):
        import tempfile
        from unittest import mock

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def write(filename, text):
                path = root / filename
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
                return path

            write("examples/README.md",
                  "# Examples\n[Workbench](../docs/workbench-user-guide.md#keyboard)\n"
                  "![preview](../docs/assets/preview%20one.svg)\n"
                  "[Internal](../docs/private-notes.md)\n")
            write("docs/workbench-user-guide.md", "# Workbench\n## Keyboard\n")
            write("docs/private-notes.md", "# Source-only notes\n")
            write("docs/assets/preview one.svg", "<svg xmlns='http://www.w3.org/2000/svg'/>")
            write("docs/api/generated/api.md", "# API\n")
            pages = {
                "examples/README.md": "website/guide/examples-catalog.md",
                "docs/workbench-user-guide.md": "website/guide/workbench-user-guide.md",
            }
            with mock.patch.object(site, "ROOT", root), mock.patch.object(site, "PAGES", pages):
                self.assertEqual(site.main(), 0)
                catalog_path = root / "website/guide/examples-catalog.md"
                catalog = catalog_path.read_text(encoding="utf-8")
                self.assertIn("(workbench-user-guide.md#keyboard)", catalog)
                self.assertIn("(media/docs/assets/preview%20one.svg)", catalog)
                self.assertIn(site.REPO_BLOB + "docs/private-notes.md", catalog)
                self.assertEqual(
                    (root / "website/guide/media/docs/assets/preview one.svg").read_bytes(),
                    (root / "docs/assets/preview one.svg").read_bytes())
                self.assertTrue((root / "website/guide/workbench-user-guide.md").is_file())
                self.assertTrue((root / "website/guide/generated-api.md").is_file())
                self.assertEqual(site.main(), 0)
                self.assertEqual(catalog_path.read_text(encoding="utf-8"), catalog)

    def test_missing_links_are_not_masked(self):
        import tempfile
        from unittest import mock

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "examples/README.md"
            source.parent.mkdir()
            source.write_text("[missing](../docs/absent.md)", encoding="utf-8")
            target = root / "website/guide/examples-catalog.md"
            with mock.patch.object(site, "ROOT", root):
                result = site.retarget_links(source.read_text(), source, target, {})
            self.assertEqual(result, source.read_text())


    def test_missing_guide_fails_instead_of_staging_surrogate(self):
        import tempfile
        from unittest import mock

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "website").mkdir()
            (root / "website/workbench.md").write_text("# Surrogate, not guide\n")
            (root / "docs/api/generated").mkdir(parents=True)
            (root / "docs/api/generated/api.md").write_text("# API\n")
            with mock.patch.object(site, "ROOT", root), mock.patch.object(
                    site, "PAGES",
                    {"docs/workbench-user-guide.md":
                     "website/guide/workbench-user-guide.md"}):
                self.assertEqual(site.main(), 1)
                self.assertFalse((root / "website/guide/workbench-user-guide.md").exists())

class BuiltSiteIntegrationTests(unittest.TestCase):
    """Run with ELMTUI_SITE_BUILT=1 after a *fresh* mkdocs build --strict."""

    @unittest.skipUnless(__import__("os").environ.get("ELMTUI_SITE_BUILT") == "1",
                         "requires freshly built site; set ELMTUI_SITE_BUILT=1")
    def test_generated_html_local_hrefs_and_assets(self):
        from html.parser import HTMLParser
        from urllib.parse import unquote, urlsplit

        class Links(HTMLParser):
            def __init__(self):
                super().__init__()
                self.urls = []

            def handle_starttag(self, tag, attrs):
                attrs = dict(attrs)
                attribute = "href" if tag in ("a", "link") else "src"
                if tag in ("a", "link", "img", "script", "source") and attrs.get(attribute):
                    self.urls.append(attrs[attribute])

        output = ROOT / "dist/site"
        self.assertTrue((output / "index.html").is_file())
        pages = sorted(output.rglob("*.html"))
        self.assertTrue(any("examples-catalog" in str(p) for p in pages))
        verified = 0
        for page in pages:
            links = Links()
            links.feed(page.read_text(encoding="utf-8"))
            for raw in links.urls:
                url = urlsplit(raw)
                if url.scheme or url.netloc or not url.path:
                    continue
                ref = unquote(url.path)
                candidate = (output / ref.lstrip("/") if ref.startswith("/")
                             else page.parent / ref).resolve()
                try:
                    candidate.relative_to(output.resolve())
                except ValueError:
                    self.fail(f"{page} links outside site: {raw}")
                if candidate.is_dir():
                    candidate = candidate / "index.html"
                self.assertTrue(candidate.is_file(), f"{page}: {raw} -> {candidate}")
                verified += 1
        self.assertGreater(verified, 10)

if __name__ == "__main__":
    unittest.main()
