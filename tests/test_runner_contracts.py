#!/usr/bin/env python3
"""Static safety contracts for the non-interactive CLPM test runner.

These tests intentionally avoid loading the full Common Lisp system.  They guard the
entrypoint that every automated test command uses, so they must stay fast and safe
even when the Lisp suite is currently noisy or slow.
"""
from __future__ import annotations

from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "run-tests-clpm.lisp"


def _active_lisp_lines(path: Path) -> list[str]:
    """Return non-empty Lisp lines with full-line comments removed."""
    active: list[str] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        active.append(line)
    return active


def test_clpm_runner_converts_test_result_to_process_exit_status() -> None:
    lines = _active_lisp_lines(RUNNER)

    assert any("uiop:quit" in line for line in lines), (
        "run-tests-clpm.lisp must explicitly call uiop:quit so failed FiveAM "
        "runs cannot return process exit 0."
    )


def test_runner_does_not_reference_test_package_at_read_time() -> None:
    source = RUNNER.read_text(encoding="utf-8")
    forbidden = "elmtui.tests:run-all-elmtui-tests"
    assert forbidden not in source, (
        "run-tests-clpm.lisp must not use package-qualified test symbols at read time; "
        "ASDF loads the test package only after the file starts executing"
    )


def test_clpm_runner_removes_stdout_log_appenders_before_running_tests() -> None:
    lines = _active_lisp_lines(RUNNER)
    joined = "\n".join(lines)

    assert "log4cl:remove-all-appenders" in joined, (
        "run-tests-clpm.lisp must remove inherited log4cl appenders before tests "
        "so application INFO/WARN/ERROR output cannot leak into server stdout."
    )
    assert "log4cl:file-appender" in joined or "make-broadcast-stream" in joined, (
        "run-tests-clpm.lisp must replace stdout logging with a file/null sink "
        "before loading/running examples and runtime tests."
    )


def test_tmux_integration_tests_are_opt_in_by_default():
    path = ROOT / "tests" / "tmux-capture-integration-tests.lisp"
    text = path.read_text(encoding="utf-8")

    assert "ELMTUI_RUN_TMUX_INTEGRATION" in text, "missing explicit opt-in env var"
    assert "*run-tmux-integration-tests*" in text, "missing opt-in switch"
    assert "(not *run-tmux-integration-tests*)" in text, "skip macro must skip before probing live tmux"


def test_widgets_enhanced_asdf_definitions_match_file_stem() -> None:
    path = ROOT / "elmtui-widgets-enhanced.asd"
    source = path.read_text(encoding="utf-8")
    assert '"elmtui/widgets-enhanced"' not in source, (
        "elmtui-widgets-enhanced.asd must not define slash-named system "
        "elmtui/widgets-enhanced; ASDF warns because systems in this file "
        "must be elmtui-widgets-enhanced or elmtui-widgets-enhanced/*"
    )

def main() -> int:
    tests: list[Callable[[], None]] = [
        test_clpm_runner_converts_test_result_to_process_exit_status,
        test_runner_does_not_reference_test_package_at_read_time,
        test_clpm_runner_removes_stdout_log_appenders_before_running_tests,
        test_tmux_integration_tests_are_opt_in_by_default,
        test_widgets_enhanced_asdf_definitions_match_file_stem,
    ]
    failures = 0
    for test in tests:
        try:
            test()
        except AssertionError as exc:
            failures += 1
            print(f"FAIL {test.__name__}: {exc}")
        else:
            print(f"PASS {test.__name__}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

