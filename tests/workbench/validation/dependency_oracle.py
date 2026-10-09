"""Independent support-library test oracle for the Workbench release gate.

Do not count the ElmTUI root test suite, a module-load check or the PTY
fixture as evidence that the four independently packaged libraries work.
"""
from pathlib import Path
import re


DEPENDENCIES = ("cl-events", "cl-inputs", "cl-state", "cl-styles")


def qualify_dependency_result(run, log):
    """Fail closed if a child test suite was not actually exercised."""
    for name in DEPENDENCIES:
        if f"==> testing {name} independently" not in log:
            return False, f"missing independently launched {name} test suite"
    for idx, name in enumerate(DEPENDENCIES):
        start = log.index(f"==> testing {name} independently")
        end = (log.index(f"==> testing {DEPENDENCIES[idx + 1]} independently")
               if idx + 1 < len(DEPENDENCIES) else len(log))
        section = log[start:end]
        summaries = [int(n) for n in re.findall(r"Did\s+(\d+)\s+checks\.", section)]
        if not summaries or any(n < 1 for n in summaries):
            return False, f"{name} did not execute a nonempty test suite"
        failures = re.findall(r"Fail:\s*(\d+)", section)
        if len(failures) < len(summaries) or any(int(n) for n in failures):
            return False, f"{name} has failed or missing FiveAM suite verdicts"
    if "All reusable subsystem tests passed." not in log:
        return False, "subsystem runner did not reach its success marker"
    return run.get("exit_code") == 0, "four independent ASDF subsystem test suites"


def run_dependency_oracle(root: Path, out: Path, check):
    argv = ["bash", "scripts/test-subsystems.sh"]
    run = check("dependency_oracle", argv, out, timeout=180)
    stdout = (out / "dependency_oracle.stdout.log").read_text(errors="replace")
    ok, detail = qualify_dependency_result(run, stdout)
    return {
        **run,
        "result": "passed" if ok else "failed",
        "details": detail,
        "dependencies": list(DEPENDENCIES),
        "independent": True,
    }
