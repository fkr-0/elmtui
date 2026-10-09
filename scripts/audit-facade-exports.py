#!/usr/bin/env python3
"""Ratchet public symbol aliases across ElmTUI and its support libraries.

The TSV is a semver compatibility snapshot, not permission to remove aliases
or proof that the semantics of every exported binding have been reviewed.
"""
from __future__ import annotations

import argparse
import csv
import difflib
import io
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "docs/architecture/facade-reexports.tsv"
PREFIXES = ("ELMTUI", "CL-EVENTS", "CL-STATE", "CL-INPUTS", "CL-STYLES")
LEGACY = {("ELMTUI", "COMMON-LISP", "USE-VALUE"),
          ("ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER", "COMMON-LISP", "USE-VALUE")}
COLUMNS = ("exporter", "home", "symbol", "home_status", "identity", "review_status")
LISP = r"""
(require :asdf)
(asdf:load-system :elmtui)
(dolist (system '(:cl-events :cl-inputs :cl-state :cl-styles))
  (asdf:load-system system))
(defun framework-p (name)
  (some (lambda (prefix)
          (or (string= prefix name)
              (and (< (length prefix) (length name))
                   (string= prefix name :end2 (length prefix))
                   (char= (char name (length prefix)) #\.))))
        '("ELMTUI" "CL-EVENTS" "CL-STATE" "CL-INPUTS" "CL-STYLES")))
(let ((rows nil))
  (dolist (pkg (list-all-packages))
    (when (framework-p (package-name pkg))
      (do-external-symbols (sym pkg)
        (let ((home (symbol-package sym)))
          (when (and home (not (eq home pkg)))
            (multiple-value-bind (found status) (find-symbol (symbol-name sym) home)
              (push (format nil "~A~C~A~C~A~C~A~C~A"
                            (package-name pkg) #\Tab (package-name home) #\Tab
                            (symbol-name sym) #\Tab status #\Tab
                            (if (eq found sym) "identical" "mismatch")) rows)))))))
  (dolist (row (sort rows #'string<)) (write-line row)))
"""


def in_framework(name: str) -> bool:
    return any(name == prefix or name.startswith(prefix + ".") for prefix in PREFIXES)


def classify(exporter: str, home: str, name: str, origin: str) -> str:
    key = exporter, home, name
    if key in LEGACY and origin == "EXTERNAL":
        return "legacy-standard-restart"
    if not in_framework(home):
        raise ValueError(f"Unapproved foreign-origin export: {key}")
    if origin == "INTERNAL":
        return "private-origin-compat-review"
    if origin == "EXTERNAL":
        return "public-alias-retain"
    raise ValueError(f"Unexpected origin status: {key}, {origin}")


def snapshot() -> list[dict[str, str]]:
    with tempfile.NamedTemporaryFile(mode="w", suffix=".lisp", delete=False) as handle:
        handle.write(LISP)
        file = Path(handle.name)
    try:
        command = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
                   "--noinform", "--script", str(file)]
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        if run.returncode:
            raise RuntimeError(f"SBCL export inspection failed:\n{run.stderr}")
    finally:
        file.unlink(missing_ok=True)
    rows = []
    for line in run.stdout.splitlines():
        fields = line.split("\t")
        if len(fields) != 5:
            raise ValueError("Unexpected export inspection output: " + line)
        exporter, home, name, origin, identity = fields
        if identity != "identical":
            raise ValueError("Imported symbol identity changed: " + line)
        rows.append(dict(exporter=exporter, home=home, symbol=name,
                         home_status=origin, identity=identity,
                         review_status=classify(exporter, home, name, origin)))
    rows.sort(key=lambda row: (row["exporter"], row["home"], row["symbol"]))
    identities = {(r["exporter"], r["home"], r["symbol"]) for r in rows}
    if len(identities) != len(rows):
        raise ValueError("Duplicate export identities")
    return rows


def render(rows: list[dict[str, str]]) -> str:
    out = io.StringIO()
    writer = csv.DictWriter(out, COLUMNS, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return out.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh", action="store_true",
                        help="Rewrite baseline only after manual compatibility review")
    args = parser.parse_args()
    rows = snapshot()
    counts = {status: sum(row["review_status"] == status for row in rows)
              for status in sorted({row["review_status"] for row in rows})}
    print("FACADE-EXPORT-AUDIT", "aliases=" + str(len(rows)),
          *(f"{key}={value}" for key, value in counts.items()))
    actual = render(rows)
    if args.refresh:
        MANIFEST.write_text(actual)
        print("Refreshed", MANIFEST.relative_to(ROOT))
        return 0
    if not MANIFEST.is_file():
        print("Missing manifest. Review before using --refresh.", file=sys.stderr)
        return 1
    old = MANIFEST.read_text()
    if actual == old:
        print("PASS: exact aliases, origins, and symbol identities match manifest.")
        return 0
    delta = difflib.unified_diff(old.splitlines(), actual.splitlines(),
                                fromfile="committed", tofile="current", lineterm="")
    print("\n".join(list(delta)[:90]), file=sys.stderr)
    print("FAIL: export ABI drift; review before refreshing.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError) as exc:
        print("facade-export-audit:", exc, file=sys.stderr)
        sys.exit(1)
