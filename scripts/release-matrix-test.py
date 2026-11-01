#!/usr/bin/env python3
"""Release engineering: immutable source archive, cold install, exact remote pins.

Never creates commits/tags, touches remotes, or uses uncommitted dependency
content. A successful local tar build is not proof that its SHAs are public.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from urllib.parse import urlsplit, urlunsplit

LIBRARIES = ("cl-events", "cl-inputs", "cl-state", "cl-styles")
CI_GATES = {
    "compilation": "asdf:compile-system",
    "warning-clean": "run-tests-warning-clean.sh",
    "ASDF acceptance": "test_asdf_acceptance.py",
    "coverage": "run-coverage-warning-clean.sh",
    "Workbench": "tests/workbench/independent",
    "Workbench PTY": "tests/workbench/pty-workbench.py",
    "Neon": "elmtui-neon-tests",
    "Neon PTY": "test-neon-terminal-restoration.py",
    "packager PTY": "release-gate-packager-pty.py",
    "terminal sweep": "test-terminal-apps.py",
    "archive": "release-matrix-test.py archive",
    "cold install": "release-matrix-test.py cold",
    "public pins": "release-matrix-test.py pins",
}
LOCAL_GATES = {
    "clean tree": "require_clean_tree",
    "Workbench PTY": "pty-workbench.py",
    "Neon PTY": "test-neon-terminal-restoration.py",
    "terminal sweep": "test-terminal-apps.py",
    "coverage": "run-coverage-warning-clean.sh",
    "archive": "release-matrix-test.py archive",
    "cold install": "release-matrix-test.py cold",
    "public pins": "release-matrix-test.py pins",
    "strict docs": "mkdocs build --strict",
    "normal-screen B2/resize contracts": "example-overhaul-tmux-review-contracts.py",
    "normal-screen hover regressions": "tmux-hover-defect-regressions.py",
    "normal-screen resize history": "tmux-normal-compositor-resize.py",
    "example shutdown sweep": "all-examples-shutdown-restoration.py",
    "packager tool executable": "packager-executable.py",
    "README quickstart": "readme-quickstart.py",
    "deftea-app runtime": "deftea-app-pty.py",
    "API binding ratchet": "audit-api-bindings.lisp",
}
def cmd(*args: str, cwd: Path | None = None, env=None, timeout=180) -> str:
    result = subprocess.run(args, cwd=cwd, env=env, check=True,
                            text=True, capture_output=True, timeout=timeout)
    return result.stdout.strip()

def git(root: Path, *args: str) -> str:
    return cmd("git", "-C", str(root), *args)

def vector(root: Path) -> dict[str, str]:
    result = {"root": git(root, "rev-parse", "HEAD")}
    for name in LIBRARIES:
        if git(root, "ls-tree", "HEAD", name).split()[0] != "160000":
            raise RuntimeError(f"not a gitlink: {name}")
        result[name] = git(root, "rev-parse", f"HEAD:{name}")
    return result

def unpack_git_archive(root: Path, ref: str, destination: Path) -> None:
    proc = subprocess.run(["git", "-C", str(root), "archive", "--format=tar", ref],
                          check=True, capture_output=True, timeout=120)
    destination.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=__import__("io").BytesIO(proc.stdout), mode="r:") as archive:
        archive.extractall(destination, filter="data")

def _committed_file_manifest(root: Path, pins: dict[str, str]) -> dict[str, tuple[str, int]]:
    """Independently read every expected file from pinned Git objects.

    An embedded revision-vector JSON or a checksum shipped next to a tarball is
    not an independent integrity oracle: an attacker can rewrite both.
    """
    expected: dict[str, tuple[str, int]] = {}
    for repo, prefix in (("root", ""), *((lib, lib + "/") for lib in LIBRARIES)):
        source = root if repo == "root" else root / repo
        data = subprocess.run(
            ["git", "-C", str(source), "archive", "--format=tar", pins[repo]],
            check=True, capture_output=True, timeout=120,
        ).stdout
        with tarfile.open(fileobj=__import__("io").BytesIO(data), mode="r:") as obj:
            for member in obj:
                if not member.isfile():
                    # Git tracks no empty folders. The gitlink itself is a
                    # directory placeholder and the actual dependency source
                    # is checked independently below.
                    continue
                relative = prefix + member.name
                if relative == "RELEASE-REVISION-VECTOR.json":
                    raise RuntimeError("tracked source conflicts with revision vector")
                stream = obj.extractfile(member)
                if stream is None or relative in expected:
                    raise RuntimeError(f"invalid pinned Git source member: {relative}")
                expected[relative] = (
                    hashlib.sha256(stream.read()).hexdigest(), member.mode & 0o111
                )
    return expected


def validate_archive(archive: Path, source_root: Path | None = None) -> dict[str, str]:
    """Verify tar safety, checksum, sidecars and ALL files against pinned Git.

    The local checked-out superproject's HEAD/gitlink object IDs are the
    independent trust anchor. This is a reproducible local provenance check,
    not a signature or proof of public remote reachability.
    """
    root = source_root or Path(__file__).resolve().parents[1]
    actual_files: dict[str, tuple[str, int]] = {}
    actual_dirs: set[str] = set()
    names: set[str] = set()
    with tarfile.open(archive, "r:gz") as obj:
        for member in obj:
            p = PurePosixPath(member.name)
            parts = member.name.rstrip("/").split("/")
            if (p.is_absolute() or ".." in p.parts or "." in parts or
                    "" in parts or not p.parts or p.parts[0] != "elmtui-source" or
                    member.name.rstrip("/") != str(p) or
                    not (member.isfile() or member.isdir())):
                raise RuntimeError(f"unsafe archive member: {member.name}")
            if str(p) in names:
                raise RuntimeError(f"duplicate archive member: {member.name}")
            names.add(str(p))
            if member.isdir():
                actual_dirs.add(str(p))
            else:
                stream = obj.extractfile(member)
                if stream is None:
                    raise RuntimeError(f"unreadable archive member: {member.name}")
                actual_files[str(p)] = (
                    hashlib.sha256(stream.read()).hexdigest(), member.mode & 0o111
                )
        for name in ("LICENSE", "clpmfile", "clpmfile.lock", "elmtui.asd",
                     "RELEASE-REVISION-VECTOR.json"):
            if f"elmtui-source/{name}" not in actual_files:
                raise RuntimeError(f"archive missing root file: {name}")
        for lib in LIBRARIES:
            for filename in (f"{lib}.asd", "LICENSE"):
                if f"elmtui-source/{lib}/{filename}" not in actual_files:
                    raise RuntimeError(f"archive missing dependency: {lib}/{filename}")
        member = obj.extractfile("elmtui-source/RELEASE-REVISION-VECTOR.json")
        if member is None:
            raise RuntimeError("missing vector")
        pins = json.loads(member.read())
    if set(pins) != {"root", *LIBRARIES} or any(
        not isinstance(v, str) or not re.fullmatch(r"[0-9a-f]{40}", v)
        for v in pins.values()
    ):
        raise RuntimeError("invalid revision vector")

    trusted = vector(root)
    if pins != trusted:
        raise RuntimeError("embedded archive revision vector differs from pinned Git HEAD")
    vector_sidecar = archive.with_suffix(archive.suffix + ".vector.json")
    if not vector_sidecar.is_file() or json.loads(vector_sidecar.read_text()) != trusted:
        raise RuntimeError("missing or mismatched independent revision-vector sidecar")
    digest_sidecar = archive.with_suffix(archive.suffix + ".sha256")
    expected_digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if (not digest_sidecar.is_file() or
            digest_sidecar.read_text() != f"{expected_digest}  {archive.name}\n"):
        raise RuntimeError("missing or mismatched source archive SHA256 sidecar")

    expected = _committed_file_manifest(root, trusted)
    vector_path = "elmtui-source/RELEASE-REVISION-VECTOR.json"
    actual_files.pop(vector_path)
    actual = {name.removeprefix("elmtui-source/"): value
              for name, value in actual_files.items()}
    missing = expected.keys() - actual.keys()
    extra = actual.keys() - expected.keys()
    if missing or extra:
        raise RuntimeError(
            f"archive pinned Git file inventory mismatch: "
            f"missing={sorted(missing)[:10]} extra={sorted(extra)[:10]}")
    for name in expected:
        if expected[name] != actual[name]:
            raise RuntimeError(f"archive file differs from pinned Git content/mode: {name}")
    required_dirs = {"elmtui-source"}
    for file in (*actual_files, vector_path):
        parts = PurePosixPath(file).parts[:-1]
        for index in range(1, len(parts) + 1):
            required_dirs.add("/".join(parts[:index]))
    if actual_dirs != required_dirs:
        raise RuntimeError("archive directory inventory differs from pinned Git sources")
    return trusted

def make_archive(root: Path, output: Path) -> dict[str, str]:
    if output.exists():
        raise RuntimeError(f"refusing to replace existing archive: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    pins = vector(root)
    with tempfile.TemporaryDirectory(prefix="elmtui-archive-") as work:
        source = Path(work) / "elmtui-source"
        unpack_git_archive(root, pins["root"], source)
        for lib in LIBRARIES:
            # Fetch nothing: this demands exact locally available commit objects.
            git(root / lib, "cat-file", "-e", pins[lib] + "^{commit}")
            unpack_git_archive(root / lib, pins[lib], source / lib)
        (source / "RELEASE-REVISION-VECTOR.json").write_text(
            json.dumps(pins, sort_keys=True, indent=2) + "\n")
        with tarfile.open(output, "x:gz") as obj:
            obj.add(source, arcname="elmtui-source", recursive=True)
    sha = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(output.suffix + ".sha256").write_text(f"{sha}  {output.name}\n")
    output.with_suffix(output.suffix + ".vector.json").write_text(
        json.dumps(pins, sort_keys=True, indent=2) + "\n")
    check = validate_archive(output, root)
    if check != pins:
        raise RuntimeError("archive revision vector mismatch")
    print(json.dumps({"archive": str(output), "sha256": sha, "vector": pins}, sort_keys=True))
    return pins

def cold_install(archive: Path) -> None:
    pins = validate_archive(archive)
    with tempfile.TemporaryDirectory(prefix="elmtui-fresh-install-") as work:
        workdir = Path(work)
        with tarfile.open(archive, "r:gz") as obj:
            obj.extractall(workdir, filter="data")
        root = workdir / "elmtui-source"
        home = workdir / "home"
        home.mkdir()
        (home / ".sbclrc").write_text(
            "(require :asdf)\n"
            "(dolist (p '(:sb-c :sb-pcl :sb-int :sb-kernel))\n"
            "  (let ((pkg (find-package p)))\n"
            "    (when pkg (sb-ext:unlock-package pkg))))\n"
        )
        env = os.environ.copy()
        env.update(HOME=str(home), CLPM_HOME=str(workdir / "clpm-home"),
                   XDG_CONFIG_HOME=str(workdir / "config"),
                   XDG_DATA_HOME=str(workdir / "data"),
                   XDG_CACHE_HOME=str(workdir / "cache"))
        # CLPM uses XDG_DATA_HOME for package sources. Clear all XDG homes
        # explicitly: CLPM_HOME alone does NOT isolate its global cache.
        # Download failures in this clean environment are hard failures.
        for command in (
            ["clpm", "bundle", "install"],
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive", "--eval", "(require :asdf)",
             "--eval", '(asdf:load-system "elmtui")',
             "--eval", '(format t "COLD_ARCHIVE_LOAD_OK~%")'],
        ):
            subprocess.run(command, cwd=root, env=env, check=True, timeout=600)
        print(json.dumps({"cold_install": "passed", "vector": pins}, sort_keys=True))

def relative_remote(root_url: str, url: str) -> str:
    if not url.startswith("../"):
        return url
    if "://" in root_url:
        parts = urlsplit(root_url)
        path = posixpath.normpath(posixpath.join(parts.path, url))
        return urlunsplit(parts._replace(path=path + ("" if url.endswith(".git") else ".git")))
    if ":" in root_url:
        host, path = root_url.split(":", 1)
        return host + ":" + posixpath.normpath(posixpath.join(path, url)) + (
            "" if url.endswith(".git") else ".git")
    raise RuntimeError("cannot resolve relative Git remote")

def probe_pins(root: Path, output: Path) -> bool:
    output.parent.mkdir(parents=True, exist_ok=True)
    pins = vector(root)
    root_url = git(root, "remote", "get-url", "origin")
    records = []
    for lib in (*LIBRARIES, "root"):
        relative = git(root, "config", "-f", ".gitmodules", "--get",
                       f"submodule.{lib}.url") if lib != "root" else root_url
        url = relative_remote(root_url, relative)
        with tempfile.TemporaryDirectory(prefix="elmtui-pin-probe-") as work:
            cmd("git", "init", "-q", "--bare", work)
            result = subprocess.run(
                ["git", "-C", work, "-c", "protocol.version=2",
                 "fetch", "-q", "--no-tags", url, pins[lib]],
                capture_output=True, text=True, timeout=60)
            reachable = result.returncode == 0
            if reachable:
                reachable = subprocess.run(["git", "-C", work, "cat-file", "-e",
                                            pins[lib] + "^{commit}"],
                                           capture_output=True).returncode == 0
        records.append(dict(name=lib, sha=pins[lib], remote=url,
                            status="reachable" if reachable else "unresolved"))
    output.write_text(json.dumps(records, indent=2) + "\n")
    for record in records:
        print(f"{record['name']} {record['sha']} {record['status']} {record['remote']}")
    print(f"PIN_RECEIPT={output}")
    return all(item["status"] == "reachable" for item in records)

def check_contract(root: Path) -> list[str]:
    errors = []
    asd = (root / "elmtui.asd").read_text()
    webpage = (root / "website/release.md").read_text()
    versions = set(re.findall(r':version\s+"(\d+\.\d+\.\d+)"', asd))
    if len(versions) != 1:
        errors.append("root ASDF version ambiguous or missing")
    else:
        version = next(iter(versions))
        # Compare advertised title, not historical discussions of other versions.
        match = re.search(r"^#\s+(\d+\.\d+\.\d+)\s+release", webpage, flags=re.M)
        if not match or match.group(1) != version:
            errors.append(f"site release version conflicts with root {version}")
    ci = (root / ".github/workflows/ci.yml").read_text()
    local = (root / "scripts/release-check.sh").read_text()
    # Reject a comment or a mention in documentation: CI must execute the
    # exact local gate (or remain blocked pending alignment).
    ci_calls_gate = bool(re.search(
        r"(?m)^[ \t]*(?:-\s*)?(?:run:[ \t]*)?(?:bash[ \t]+)?(?:\./)?scripts/release-check\.sh(?:[ \t]|$)",
        ci,
    ))
    if not ci_calls_gate:
        errors.append("CI does not execute canonical scripts/release-check.sh")
        for name, token in CI_GATES.items():
            if token not in ci:
                errors.append(f"CI release matrix missing {name}: {token}")
    for name, token in LOCAL_GATES.items():
        if token not in local:
            errors.append(f"local release matrix missing {name}: {token}")
    if "mkdocs build --strict" not in (root / ".github/workflows/pages.yml").read_text():
        errors.append("Pages lacks strict MkDocs build")
    return errors

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("archive", "verify-archive", "cold", "pins", "contract"))
    parser.add_argument("artifact", nargs="?", type=Path)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        if args.operation == "contract":
            errors = check_contract(args.root)
            for error in errors:
                print("RELEASE_BLOCKED: " + error, file=sys.stderr)
            print(f"RELEASE_CONTRACT_FAILURES={len(errors)}")
            return 1 if errors else 0
        if args.artifact is None or not args.artifact.is_absolute():
            raise RuntimeError("archive/receipt path must be absolute")
        if args.operation == "archive":
            make_archive(args.root, args.artifact)
        elif args.operation == "verify-archive":
            print(json.dumps(validate_archive(args.artifact), sort_keys=True))
        elif args.operation == "cold":
            cold_install(args.artifact)
        elif args.operation == "pins":
            return 0 if probe_pins(args.root, args.artifact) else 1
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError,
            subprocess.TimeoutExpired, tarfile.TarError) as exc:
        print("RELEASE_BLOCKED: " + str(exc), file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
