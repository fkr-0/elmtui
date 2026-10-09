#!/usr/bin/env python3
"""Evidence-first W6 qualification: actual app oracles, no fixture substitution.

Represent all 30 matrix cases and run only implemented real oracles.
Unimplemented cases remain NOT RUN; passing a fixture never implies app success.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

from live_cases import run_case_oracles

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
MATRIX = ROOT / "tests/workbench/qualification-matrix.json"
TASK = "ELMTUI-WB-06-VALIDATION-20261009"


def check(name, argv, out, timeout=180, env=None):
    started = time.monotonic()
    timed_out = False
    try:
        p = subprocess.run(argv, cwd=ROOT, text=True, capture_output=True,
                           timeout=timeout, check=False, env=env)
        rc, stdout, stderr = p.returncode, p.stdout, p.stderr
    except (subprocess.TimeoutExpired, OSError) as error:
        rc, stdout, stderr = None, "", str(error)
        timed_out = isinstance(error, subprocess.TimeoutExpired)
    stdout_path, stderr_path = out / (name + ".stdout.log"), out / (name + ".stderr.log")
    stdout_path.write_text(stdout, encoding="utf-8")
    stderr_path.write_text(stderr, encoding="utf-8")
    warnings = [line[:500] for line in (stdout + "\n" + stderr).splitlines()
                if re.search(r"(?i)\b(?:warning|error)\s*:", line)]
    return {"command": argv, "exit_code": rc, "result": "passed" if rc == 0 else "failed",
            "timed_out": timed_out, "elapsed_seconds": round(time.monotonic() - started, 3),
            "warnings": warnings[:60], "warning_count": len(warnings),
            "stdout": str(stdout_path.relative_to(ROOT)),
            "stderr": str(stderr_path.relative_to(ROOT))}


def launcher_status():
    asd = ROOT / "elmtui-workbench.asd"
    launchers = sorted((ROOT / "examples").glob("workbench*.lisp"))
    missing = ([] if asd.is_file() else ["elmtui-workbench.asd"])
    if not launchers:
        missing.append("examples/workbench*.lisp")
    return {"present": not missing, "missing": missing,
            "sources": [str(p.relative_to(ROOT)) for p in launchers]}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output", type=Path, help="Path below tests/workbench/validation")
    ap.add_argument("--no-compile", action="store_true")
    args = ap.parse_args()
    out = (args.output or HERE / "artifacts" / ("run-" + uuid.uuid4().hex[:10])).resolve()
    if not out.is_relative_to(HERE):
        ap.error("output must remain under tests/workbench/validation/")
    out.mkdir(parents=True, exist_ok=True)
    raw = MATRIX.read_bytes()
    matrix = json.loads(raw)
    cases = matrix["cases"]
    ids = [case["id"] for case in cases]
    if len(ids) != 30 or len(set(ids)) != 30:
        ap.error("refuse incomplete or duplicate 30-case matrix")
    started = time.monotonic()
    checks = {}
    checks["catalog"] = check("catalog", [
        sys.executable, "-m", "unittest", "discover", "-s", "tests/workbench",
        "-p", "test_qualification_matrix.py", "-v"], out)
    checks["pty_fixture"] = check("pty_fixture", [
        sys.executable, "-m", "unittest", "discover", "-s",
        "tests/workbench/validation", "-p", "test_fixture.py", "-v"], out,
        env=dict(os.environ, ELMTUI_WB_QA_ARTIFACT_DIR=str(out / "fixture-traces")))
    if args.no_compile or not shutil.which("clpm"):
        checks["clpm_baseline"] = {"result": "skipped", "exit_code": None,
            "command": None, "warning_count": 0, "warnings": [], "elapsed_seconds": 0,
            "reason": "explicit --no-compile or clpm unavailable"}
    else:
        checks["clpm_baseline"] = check("clpm_baseline", [
            "clpm", "bundle", "exec", "--with-client", "sbcl", "--",
            "--noinform", "--non-interactive", "--eval", "(require :asdf)",
            "--eval", '(asdf:load-system "elmtui")'], out)
    launcher = launcher_status()
    dependency = ("W5 launcher absent: " + ", ".join(launcher["missing"])
                  if not launcher["present"] else
                  "No independently executable oracle implemented for this matrix case")
    observed = run_case_oracles(cases, ROOT, out, check) if launcher["present"] else {}
    rows = []
    for case in cases:
        receipt = observed.get(case["id"], {"status": "not-run", "reason": dependency,
                                            "command": None, "exit_code": None,
                                            "elapsed_seconds": 0, "warnings": [], "evidence": None})
        rows.append({"id": case["id"], "lane": case["lane"], "kind": case["kind"],
                     "required": case["required"], "oracle": case["oracle"], **receipt})
    counts = {status: sum(row["status"] == status for row in rows)
              for status in ("passed", "failed", "not-run")}
    report = {
        "schema": "elmtui.workbench.qa-evidence/v1", "task": TASK,
        "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "matrix_sha256": hashlib.sha256(raw).hexdigest(),
        "head": subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                               capture_output=True, text=True).stdout.strip(),
        "launcher": launcher,
        "qualification": {"total": 30, "passed": counts["passed"],
                          "failed": counts["failed"], "not_run": counts["not-run"],
            "note": "Only case-specific executed oracles qualify; fixture/catalog/baseline never do"},
        "checks": checks, "cases": rows,
        "elapsed_seconds": round(time.monotonic() - started, 3),
        "review": {"required": True, "independent_verdict": "pending"}}
    (out / "result.json").write_text(json.dumps(report, indent=2) + "\n",
                                     encoding="utf-8")
    for name, item in checks.items():
        print(name, item["result"], "exit=", item.get("exit_code"),
              "warnings=", item.get("warning_count", 0),
              "seconds=", item.get("elapsed_seconds"))
    print("APPLICATION_CASES: PASS=%d FAIL=%d NOT_RUN=%d" %
          (counts["passed"], counts["failed"], counts["not-run"]))
    if counts["not-run"]:
        print("UNQUALIFIED:", ", ".join(row["id"] for row in rows if row["status"] == "not-run"))
    print("DEPENDENCY:", dependency)
    print("EVIDENCE:", out / "result.json")
    if counts["failed"] or any(r["result"] == "failed" for r in checks.values()):
        return 1
    return 2 if counts["not-run"] else 0


if __name__ == "__main__":
    sys.exit(main())
