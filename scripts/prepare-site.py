#!/usr/bin/env python3
"""Stage a curated public documentation tree without copying internal release notes."""
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
PAGES = {
    "docs/longform/01-foundations-and-elm-architecture.md": "website/guide/foundations.md",
    "docs/longform/02-core-principles-widgets-and-patterns.md": "website/guide/widgets.md",
    "docs/longform/03-hands-on-counter-and-async.md": "website/guide/tutorial.md",
    "docs/workbench-user-guide.md": "website/guide/workbench-user-guide.md",
    "examples/README.md": "website/guide/examples-catalog.md",
}


def main() -> int:
    for source_name, target_name in PAGES.items():
        source, target = ROOT / source_name, ROOT / target_name
        if not source.is_file():
            if source_name == "docs/workbench-user-guide.md":
                # W5's technical guide is tracked by a separate active owner;
                # keep fresh clones buildable until that guide is committed.
                source = ROOT / "website/workbench.md"
                print("NOTE: staging Workbench landing page until guide is tracked")
            else:
                print(f"ERROR: missing source {source_name}", file=sys.stderr)
                return 1
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        print(f"Staged {source_name}")
    generated = ROOT / "docs/api/generated/api.md"
    if generated.is_file():
        shutil.copyfile(generated, ROOT / "website/guide/generated-api.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
