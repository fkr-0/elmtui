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
RUNNER = ROOT / "scripts/run-tests-clpm.lisp"


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
        "scripts/run-tests-clpm.lisp must explicitly call uiop:quit so failed FiveAM "
        "runs cannot return process exit 0."
    )


def test_runner_does_not_reference_test_package_at_read_time() -> None:
    source = RUNNER.read_text(encoding="utf-8")
    forbidden = "elmtui.tests:run-all-elmtui-tests"
    assert forbidden not in source, (
        "scripts/run-tests-clpm.lisp must not use package-qualified test symbols at read time; "
        "ASDF loads the test package only after the file starts executing"
    )


def test_clpm_runner_removes_stdout_log_appenders_before_running_tests() -> None:
    lines = _active_lisp_lines(RUNNER)
    joined = "\n".join(lines)

    assert "log4cl:remove-all-appenders" in joined, (
        "scripts/run-tests-clpm.lisp must remove inherited log4cl appenders before tests "
        "so application INFO/WARN/ERROR output cannot leak into server stdout."
    )
    assert "log4cl:file-appender" in joined or "make-broadcast-stream" in joined, (
        "scripts/run-tests-clpm.lisp must replace stdout logging with a file/null sink "
        "before loading/running examples and runtime tests."
    )


def test_tmux_integration_tests_are_opt_in_by_default():
    path = ROOT / "tests" / "tmux-capture-integration-tests.lisp"
    text = path.read_text(encoding="utf-8")

    assert "ELMTUI_RUN_TMUX_INTEGRATION" in text, "missing explicit opt-in env var"
    assert "*run-tmux-integration-tests*" in text, "missing opt-in switch"
    assert "(not *run-tmux-integration-tests*)" in text, "skip macro must skip before probing live tmux"


def test_terminal_app_uses_a_short_private_tmux_socket_path() -> None:
    import importlib.util
    import os
    import tempfile
    from types import SimpleNamespace

    script = ROOT / "scripts" / "test-terminal-apps.py"
    spec = importlib.util.spec_from_file_location("elmtui_terminal_e2e", script)
    assert spec is not None and spec.loader is not None
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)

    with tempfile.TemporaryDirectory(prefix="elmtui-e2e-contract-") as temp_dir:
        long_output_path = Path(temp_dir) / ("artifacts-" + "x" * 80)
        runner.OPTIONS = SimpleNamespace(output=long_output_path, terminal="tmux")
        app = runner.TerminalApp("long-path", "(quote t)")
        assert len(os.fsencode(app.socket)) < 104, (
            "The private tmux socket must stay below the Unix-domain socket "
            "path limit even when artifact paths are long."
        )
        assert Path(app.socket).parent == Path(tempfile.gettempdir())


def test_widgets_enhanced_asdf_definitions_match_file_stem() -> None:
    path = ROOT / "elmtui-widgets-enhanced.asd"
    source = path.read_text(encoding="utf-8")
    assert '"elmtui/widgets-enhanced"' not in source, (
        "elmtui-widgets-enhanced.asd must not define slash-named system "
        "elmtui/widgets-enhanced; ASDF warns because systems in this file "
        "must be elmtui-widgets-enhanced or elmtui-widgets-enhanced/*"
    )


def test_focus_keymaps_contract_is_not_skipped_or_example_bound() -> None:
    path = ROOT / "tests" / "focus-keymaps-example-tests.lisp"
    source = path.read_text(encoding="utf-8")
    active_lines = _active_lisp_lines(path)
    active = "\n".join(active_lines).lower()

    assert "(skip" not in active, (
        "focus/keymaps example behavior must run in the default suite; "
        "replace the examples-bound skip with a minimal core fixture."
    )
    assert "elmtui-examples" not in source.lower(), (
        "focus/keymaps behavior must not depend on compiling the full examples ASDF system."
    )


def test_focus_keymaps_fixture_suppresses_fixture_stdout() -> None:
    path = ROOT / "tests" / "focus-keymaps-example-tests.lisp"
    source = path.read_text(encoding="utf-8")

    assert "*standard-output*" in source and "make-broadcast-stream" in source, (
        "focus/keymaps fixture calls focus-simple app-update, which may FORMAT to "
        "standard output; the test must bind *standard-output* to a null sink so "
        "default CLPM output stays machine-readable."
    )


def test_viewport_enhanced_imports_apply_state_patches() -> None:
    path = ROOT / "src" / "ui" / "widgets" / "viewport-enhanced.lisp"
    source = path.read_text(encoding="utf-8")

    assert "#:apply-state-patches" in source, (
        "viewport-enhanced.lisp calls apply-state-patches and must import it "
        "from elmtui.state.model to avoid undefined-function compiler warnings."
    )


def test_contracts_tests_muffle_intentional_non_typed_message_warnings() -> None:
    path = ROOT / "tests" / "contracts-tests.lisp"
    source = path.read_text(encoding="utf-8")

    assert "with-muffled-non-typed-message-warnings" in source and "muffle-warning" in source, (
        "contracts-tests intentionally exercise legacy non-typed hybrid messages; "
        "those expected warnings must be locally muffled so default test stderr "
        "remains useful for unexpected warnings."
    )


def test_warning_clean_script_exists_and_fails_on_unexpected_warnings() -> None:
    path = ROOT / "scripts" / "run-tests-warning-clean.sh"
    assert path.exists(), "missing warning-clean gate script"
    source = path.read_text(encoding="utf-8")

    assert "scripts/run-tests-clpm.lisp" in source, (
        "warning-clean gate must wrap the declared CLPM test runner, not a parallel command."
    )
    assert "STYLE-WARNING" in source and "caught WARNING" in source, (
        "warning-clean gate must fail on compiler/runtime warning markers."
    )
    assert "grep" in source and "exit 1" in source, (
        "warning-clean gate must return non-zero when unexpected warning markers are present."
    )


def test_noninteractive_command_matrix_is_documented() -> None:
    path = ROOT / "docs" / "dev-guides" / "noninteractive-verification.md"
    assert path.exists(), "missing non-interactive verification command matrix"
    source = path.read_text(encoding="utf-8")

    required = [
        "scripts/run-tests-warning-clean.sh",
        "clpm bundle exec --with-client sbcl -- --noinform --load scripts/run-tests-clpm.lisp",
        "ELMTUI_RUN_TMUX_INTEGRATION=1",
        "ELMTUI_REQUIRE_TMUX=1",
        "tests/faketerm-tests.lisp",
        "faketerm-run-to-quiescence",
        "test-output/",
        "log4cl",
    ]
    missing = [item for item in required if item not in source]
    assert not missing, f"non-interactive verification docs missing: {missing}"


def test_bridge_manifest_exposes_warning_clean_command() -> None:
    path = ROOT / "bridge.yml"
    source = path.read_text(encoding="utf-8")

    assert "warning-clean:" in source, "bridge.yml must expose warning-clean as a named command"
    assert "scripts/run-tests-warning-clean.sh" in source, (
        "bridge warning-clean command must invoke the same executable warning-clean gate "
        "documented for non-interactive review."
    )


def test_enhanced_widget_observers_do_not_write_to_stdout() -> None:
    for rel in [
        "src/ui/widgets/button-enhanced.lisp",
        "src/ui/widgets/label-enhanced.lisp",
    ]:
        source = (ROOT / rel).read_text(encoding="utf-8")
        observer_pos = source.find(":observers")
        assert observer_pos >= 0, f"{rel} must declare observers explicitly"
        observer_block = source[observer_pos: source.find(":documentation", observer_pos)]
        assert "format t" not in observer_block.lower(), (
            f"{rel} observers run during ordinary state updates and must not "
            "write diagnostics to standard output."
        )


def test_enhanced_widget_describe_helpers_are_silent_by_default() -> None:
    for rel in [
        "src/ui/widgets/button-enhanced.lisp",
        "src/ui/widgets/label-enhanced.lisp",
        "src/ui/widgets/viewport-enhanced.lisp",
    ]:
        source = (ROOT / rel).read_text(encoding="utf-8").lower()
        assert "defun describe-" in source, f"{rel} must expose a describe helper"
        assert "with-output-to-string" in source, (
            f"{rel} describe helper should build a string first instead of "
            "forcing diagnostics to *standard-output*."
        )
        describe_pos = source.find("defun describe-")
        next_defun = source.find("(defun ", describe_pos + 1)
        describe_block = source[describe_pos: next_defun if next_defun >= 0 else len(source)]
        assert "format t" not in describe_block, (
            f"{rel} describe helper must be silent by default; accept an optional "
            "stream or return the description string instead."
        )


def test_contract_diagnostic_helpers_are_silent_by_default() -> None:
    source = (ROOT / "src" / "contracts.lisp").read_text(encoding="utf-8").lower()

    for name in ["trace-contracts", "suggest-message-schema"]:
        marker = f"(defun {name}"
        start = source.find(marker)
        assert start >= 0, f"missing {name}"
        next_defun = source.find("(defun ", start + 1)
        block = source[start: next_defun if next_defun >= 0 else len(source)]
        assert "format t" not in block, (
            f"{name} is a diagnostic helper and must not force writes to "
            "standard output in non-interactive runs."
        )
        assert "with-output-to-string" in block, (
            f"{name} should build and return diagnostic text for explicit callers."
        )


def test_run_app_platform_does_not_silently_accept_unknown_keywords() -> None:
    source = (ROOT / "src" / "platform" / "driver.lisp").read_text(encoding="utf-8")
    start = source.index("(defun run-app-platform")
    end = source.index('  "Main entry point', start)
    signature = source[start:end].lower()

    assert "platform-options" in signature
    assert "&allow-other-keys" not in signature, (
        "run-app-platform must reject unrecognized direct keyword arguments; "
        "supported platform options belong in the validated :platform-options plist."
    )


def main() -> int:
    tests: list[Callable[[], None]] = [
        test_clpm_runner_converts_test_result_to_process_exit_status,
        test_runner_does_not_reference_test_package_at_read_time,
        test_clpm_runner_removes_stdout_log_appenders_before_running_tests,
        test_tmux_integration_tests_are_opt_in_by_default,
        test_terminal_app_uses_a_short_private_tmux_socket_path,
        test_widgets_enhanced_asdf_definitions_match_file_stem,
        test_focus_keymaps_contract_is_not_skipped_or_example_bound,
        test_focus_keymaps_fixture_suppresses_fixture_stdout,
        test_viewport_enhanced_imports_apply_state_patches,
        test_contracts_tests_muffle_intentional_non_typed_message_warnings,
        test_warning_clean_script_exists_and_fails_on_unexpected_warnings,
        test_noninteractive_command_matrix_is_documented,
        test_bridge_manifest_exposes_warning_clean_command,
        test_enhanced_widget_observers_do_not_write_to_stdout,
        test_enhanced_widget_describe_helpers_are_silent_by_default,
        test_contract_diagnostic_helpers_are_silent_by_default,
        test_run_app_platform_does_not_silently_accept_unknown_keywords,
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
