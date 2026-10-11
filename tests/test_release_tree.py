"""Release-tree and historical-path hygiene contracts.

Only checks tracked Git objects, never deletes user-local ignored files.
This suite intentionally does not build the project.
"""
from __future__ import annotations

from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "scripts/history-purge-paths.txt"


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True)


class ReleaseTreeTests(unittest.TestCase):
    def test_no_nonstandard_root_files_in_head(self) -> None:
        tracked = git("ls-tree", "-r", "--name-only", "HEAD").splitlines()
        root = [path for path in tracked if "/" not in path]
        expected = {
            ".gitignore", ".gitmodules", "CHANGELOG.md", "LICENSE",
            "README.org", "bridge.yml", "clpmfile", "clpmfile.lock",
            "mkdocs.yml",
            "cl-events", "cl-inputs", "cl-state", "cl-styles",
        }
        unexpected = sorted(
            path for path in root
            if path not in expected and not path.endswith(".asd")
        )
        self.assertEqual([], unexpected, f"nonstandard root files: {unexpected}")

    def test_history_does_not_contain_purged_paths(self) -> None:
        self.assertTrue(MANIFEST.is_file())
        forbidden = [
            path.strip() for path in MANIFEST.read_text().splitlines()
            if path.strip() and not path.startswith("#")
        ]
        history = set(git("log", "--all", "--name-only", "--format=").splitlines())
        violations = []
        for path in forbidden:
            if path.endswith("/"):
                violations.extend(p for p in history if p.startswith(path))
            elif path in history:
                violations.append(path)
        self.assertFalse(violations, f"purged paths remain in history: {sorted(set(violations))}")

    def test_notice_not_reintroduced_via_later_documentation(self) -> None:
        # The historical NOTICE.md was purged; no replacement NOTICE copy
        # belongs in the release lineage either.
        # No Git ref, including temporary internal review refs, may keep
        # the copied notice alive after a complete historical purge.
        self.assertNotIn("docs/licensing-history.md", set(
            git("log", "--all", "--name-only", "--format=").splitlines()
        ))
        self.assertFalse((ROOT / "docs/licensing-history.md").exists())

    def test_launchers_under_scripts_and_executable(self) -> None:
        for path in ("examples.sh", "run-glider.sh"):
            script = ROOT / "scripts" / path
            self.assertTrue(script.is_file(), str(script))
            self.assertTrue(script.stat().st_mode & 0o111, str(script))
        for path in ("coverage.lisp", "run-tests-clpm.lisp", "run-slynk.lisp"):
            self.assertTrue((ROOT / "scripts" / path).is_file())


if __name__ == "__main__":
    unittest.main()
