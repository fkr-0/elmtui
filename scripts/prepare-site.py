#!/usr/bin/env python3
"""Stage a curated public documentation tree without copying internal release notes."""
import os
from pathlib import Path
import re
import shutil
import sys
from urllib.parse import quote, unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
REPO_BLOB = "https://github.com/fkr-0/elmtui/blob/main/"
LINK = re.compile(r"(\]\()([^)\s]+)(\))")
IMAGE_SUFFIXES = {".avif", ".gif", ".ico", ".jpeg", ".jpg", ".png", ".svg", ".webp"}
PAGES = {
    "docs/longform/01-foundations-and-elm-architecture.md": "website/guide/foundations.md",
    "docs/longform/02-core-principles-widgets-and-patterns.md": "website/guide/widgets.md",
    "docs/longform/03-hands-on-counter-and-async.md": "website/guide/tutorial.md",
    "docs/workbench-user-guide.md": "website/guide/workbench-user-guide.md",
    "examples/README.md": "website/guide/examples-catalog.md",
}


def retarget_links(text: str, source: Path, target: Path, staged: dict) -> str:
    """Resolve links when documentation pages are copied into the site tree.

    Staged pages link to staged counterparts. Nonstaged repository documents
    are linked to GitHub; local image assets are copied to the published site,
    not linked to GitHub's HTML blob viewer. Missing references are left intact
    so strict MkDocs validation can detect them.
    """
    def rewrite(match):
        head, link, tail = match.groups()
        url = urlsplit(link)
        if not url.path or url.scheme or url.netloc or url.path.startswith("/"):
            return match.group(0)
        resolved = (source.parent / unquote(url.path)).resolve()
        if resolved in staged:
            relative = os.path.relpath(staged[resolved], target.parent)
        elif resolved.is_file():
            try:
                repository_path = resolved.relative_to(ROOT.resolve())
            except ValueError:
                return match.group(0)
            if resolved.suffix.lower() in IMAGE_SUFFIXES:
                asset = ROOT / "website/guide/media" / repository_path
                asset.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(resolved, asset)
                relative = os.path.relpath(asset, target.parent)
            else:
                relative = REPO_BLOB + quote(repository_path.as_posix(), safe="/")
        else:
            return match.group(0)
        if not relative.startswith(("https://", "http://")):
            relative = quote(relative.replace(os.sep, "/"), safe="/%")
        suffix = ("?" + url.query if url.query else "") + (
            "#" + url.fragment if url.fragment else "")
        return f"{head}{relative}{suffix}{tail}"

    return LINK.sub(rewrite, text)


def main() -> int:
    staged = {(ROOT / src).resolve(): ROOT / dst for src, dst in PAGES.items()}
    for source_name, target_name in PAGES.items():
        source, target = ROOT / source_name, ROOT / target_name
        if not source.is_file():
            print(f"ERROR: missing source {source_name}", file=sys.stderr)
            return 1
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(retarget_links(source.read_text(), source, target, staged))
        print(f"Staged {source_name}")
    generated = ROOT / "docs/api/generated/api.md"
    if not generated.is_file():
        print("ERROR: checked-in API reference is missing; run scripts/build-api-docs.sh",
              file=sys.stderr)
        return 1
    shutil.copyfile(generated, ROOT / "website/guide/generated-api.md")
    print("Staged docs/api/generated/api.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
