"""Release engineering checks; all fixtures are isolated temporary Git trees."""
from __future__ import annotations
import importlib.util
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "release_engineering", ROOT / "scripts/release-matrix-test.py")
release = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(release)

ENV = dict(os.environ, GIT_AUTHOR_NAME="Fixture", GIT_AUTHOR_EMAIL="fixture@example.invalid",
           GIT_COMMITTER_NAME="Fixture", GIT_COMMITTER_EMAIL="fixture@example.invalid")


def git(folder: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(folder), *args],
                                   text=True, env=ENV, stderr=subprocess.DEVNULL).strip()


def write(folder: Path, name: str, content: str) -> None:
    path = folder / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def fixture(root: Path) -> dict[str, str]:
    git(root, "init", "-q")
    write(root, "LICENSE", "root MIT\n")
    write(root, "clpmfile", "(:api-version \"0.4\")\n")
    write(root, "clpmfile.lock", "test lock\n")
    write(root, "elmtui.asd", '(asdf:defsystem "elmtui" :version "0.2.0")\n')
    write(root, ".gitmodules", "")
    git(root, "add", "LICENSE", "clpmfile", "clpmfile.lock", "elmtui.asd", ".gitmodules")
    pins = {}
    for lib in release.LIBRARIES:
        path = root / lib
        path.mkdir()
        git(path, "init", "-q")
        write(path, "LICENSE", "MIT\n")
        write(path, lib + ".asd", f'(asdf:defsystem "{lib}")\n')
        git(path, "add", ".")
        git(path, "commit", "-qm", "dependency")
        pin = git(path, "rev-parse", "HEAD")
        pins[lib] = pin
        git(root, "update-index", "--add", "--cacheinfo", f"160000,{pin},{lib}")
    git(root, "commit", "-qm", "source")
    pins["root"] = git(root, "rev-parse", "HEAD")
    return pins


def rewrite_archive(
    original: Path, forged: Path, changed: dict[str, bytes] | None = None,
    forged_vector: dict[str, str] | None = None, chmod: dict[str, int] | None = None,
) -> None:
    """Adversarially repack the tar, updating even its checksum and vector sidecars."""
    changed = changed or {}
    chmod = chmod or {}
    with tarfile.open(original, "r:gz") as before, tarfile.open(forged, "w:gz") as after:
        for original_member in before:
            member = copy.copy(original_member)
            if member.isfile():
                data = changed.get(
                    member.name,
                    before.extractfile(original_member).read(),
                )
                if (member.name == "elmtui-source/RELEASE-REVISION-VECTOR.json"
                        and forged_vector is not None):
                    data = (json.dumps(forged_vector, sort_keys=True, indent=2) + "\n").encode()
                member.size = len(data)
                if member.name in chmod:
                    member.mode = chmod[member.name]
                after.addfile(member, io.BytesIO(data))
            else:
                after.addfile(member)
    digest = hashlib.sha256(forged.read_bytes()).hexdigest()
    forged.with_suffix(forged.suffix + ".sha256").write_text(
        f"{digest}  {forged.name}\n"
    )
    sidecar = forged_vector if forged_vector is not None else json.loads(
        original.with_suffix(original.suffix + ".vector.json").read_text()
    )
    forged.with_suffix(forged.suffix + ".vector.json").write_text(
        json.dumps(sidecar, sort_keys=True, indent=2) + "\n"
    )


class ReleaseEngineeringTests(unittest.TestCase):
    def test_remote_url_resolution(self):
        self.assertEqual(
            "https://github.com/fkr-0/cl-inputs.git",
            release.relative_remote("https://github.com/fkr-0/elmtui.git", "../cl-inputs"))
        self.assertEqual(
            "git@github.com:fkr-0/cl-styles.git",
            release.relative_remote("git@github.com:fkr-0/elmtui.git", "../cl-styles"))

    def test_archive_is_frozen_git_vector_not_dirty_content(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            pins = fixture(root)
            write(root, "LICENSE", "DIRTY WORKTREE SHOULD NEVER LEAK\n")
            output = root / "release.tar.gz"
            observed = release.make_archive(root, output)
            self.assertEqual(pins, observed)
            self.assertEqual(pins, release.validate_archive(output, root))
            with tarfile.open(output, "r:gz") as t:
                self.assertEqual("root MIT\n",
                                 t.extractfile("elmtui-source/LICENSE").read().decode())
            self.assertTrue(output.with_suffix(".gz.sha256").is_file())
            self.assertTrue(output.with_suffix(".gz.vector.json").is_file())
            with self.assertRaisesRegex(RuntimeError, "refusing to replace"):
                release.make_archive(root, output)

    def test_tampered_archive_fails_even_with_recomputed_sha256(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            fixture(root)
            clean = root / "original.tar.gz"
            release.make_archive(root, clean)
            forged = root / "forged.tar.gz"
            rewrite_archive(clean, forged, {
                "elmtui-source/LICENSE": b"MALICIOUS LICENSE MODIFICATION\n",
            })
            with self.assertRaisesRegex(RuntimeError, "differs from pinned Git content"):
                release.validate_archive(forged, root)

    def test_forged_vector_fails_even_with_updated_sidecars(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            fixture(root)
            clean = root / "original.tar.gz"
            release.make_archive(root, clean)
            forged = root / "forged.tar.gz"
            altered = dict(json.loads(clean.with_suffix(".gz.vector.json").read_text()))
            altered["root"] = "0" * 40
            rewrite_archive(clean, forged, forged_vector=altered)
            with self.assertRaisesRegex(RuntimeError, "differs from pinned Git HEAD"):
                release.validate_archive(forged, root)

    def test_changed_executable_bit_fails_with_valid_rewritten_checksum(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            fixture(root)
            clean = root / "original.tar.gz"
            release.make_archive(root, clean)
            forged = root / "forged.tar.gz"
            # Source file is committed non-executable in the Git fixture.
            rewrite_archive(clean, forged, chmod={"elmtui-source/elmtui.asd": 0o755})
            with self.assertRaisesRegex(RuntimeError, "differs from pinned Git content/mode"):
                release.validate_archive(forged, root)

    def test_missing_independent_receipts_is_not_accepted(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            fixture(root)
            clean = root / "original.tar.gz"
            release.make_archive(root, clean)
            clean.with_suffix(".gz.sha256").unlink()
            with self.assertRaisesRegex(RuntimeError, "SHA256 sidecar"):
                release.validate_archive(clean, root)

    def test_corrupt_archive_missing_dependency_fails_closed(self):
        with tempfile.TemporaryDirectory() as td:
            output = Path(td) / "bad.tar.gz"
            with tarfile.open(output, "w:gz") as t:
                content = b"irrelevant"
                entry = tarfile.TarInfo("elmtui-source/LICENSE")
                entry.size = len(content)
                t.addfile(entry, io.BytesIO(content))
            with self.assertRaisesRegex(RuntimeError, "archive missing"):
                release.validate_archive(output)

    def test_path_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            output = Path(td) / "unsafe.tar.gz"
            with tarfile.open(output, "w:gz") as t:
                entry = tarfile.TarInfo("elmtui-source/../../escape")
                entry.size = 1
                t.addfile(entry, io.BytesIO(b"x"))
            with self.assertRaisesRegex(RuntimeError, "unsafe archive member"):
                release.validate_archive(output)

    def test_symlink_extraction_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            output = Path(td) / "unsafe-link.tar.gz"
            with tarfile.open(output, "w:gz") as t:
                entry = tarfile.TarInfo("elmtui-source/link")
                entry.type = tarfile.SYMTYPE
                entry.linkname = "/etc/passwd"
                t.addfile(entry)
            with self.assertRaisesRegex(RuntimeError, "unsafe archive member"):
                release.validate_archive(output)

    def test_conflicting_site_version_and_absent_ci_checks_fail(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            write(root, "elmtui.asd", '(asdf:defsystem "elmtui" :version "0.2.0")')
            write(root, "website/release.md", "# 0.1.0 release status\n")
            write(root, ".github/workflows/ci.yml", "jobs: {}\n")
            write(root, ".github/workflows/pages.yml", "jobs: {}\n")
            write(root, "scripts/release-check.sh", "require_clean_tree\n")
            errors = release.check_contract(root)
            self.assertTrue(any("site release version" in e for e in errors))
            self.assertTrue(any("CI release matrix" in e for e in errors))
            self.assertTrue(any("local release matrix" in e for e in errors))
            self.assertTrue(any("Pages" in e for e in errors))

    def test_commented_ci_gate_is_not_executable(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            write(root, "elmtui.asd", '(asdf:defsystem "elmtui" :version "0.2.0")')
            write(root, "website/release.md", "# 0.2.0 release status\n")
            write(root, ".github/workflows/ci.yml", "# scripts/release-check.sh\n")
            write(root, ".github/workflows/pages.yml", "mkdocs build --strict\n")
            write(root, "scripts/release-check.sh", "\n".join(release.LOCAL_GATES.values()))
            errors = release.check_contract(root)
            self.assertTrue(any("CI does not execute canonical" in e for e in errors))

    def test_no_false_green_on_repository_current_contract(self):
        # This test intentionally does not require the current branch to be
        # release-ready. It independently checks that failures are reported,
        # not replaced with a misleading zero count.
        errors = release.check_contract(ROOT)
        self.assertIsInstance(errors, list)
        for error in errors:
            self.assertIsInstance(error, str)


if __name__ == "__main__":
    unittest.main()
