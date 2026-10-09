"""Real W6 workbench case oracles. Missing oracles remain NOT RUN.

All :pty cases launch the genuine examples/workbench.lisp CLPM process.
Only named, executable independent tests can qualify unit cases.
"""
import os
from pathlib import Path
import re
import sys
import time

from pty import PrivatePTY

CMD = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
       "--noinform", "--non-interactive", "--load", "examples/workbench.lisp"]

# Deliberately narrow mapping: never infer a result from a whole-suite green.
UNIT = {
    "editor-multiline-defun": ["test_unit_invariants.IndependentModuleContracts.test_editor_multiline_submits_only_when_complete"],
    "editor-unicode-display": ["test_unit_invariants.IndependentModuleContracts.test_editor_unicode_wide_and_combining_screen_cells"],
    "editor-undo-history": ["test_unit_invariants.IndependentModuleContracts.test_editor_history_restores_draft_and_undo_redo"],
    "eval-persistent-image": ["test_unit_invariants.IndependentModuleContracts.test_eval_persistence_multiple_values_and_no_terminal_print"],
    "eval-package-context": ["test_evaluator_review_regressions.EvaluatorSequentialReaderContracts.test_same_submission_in_package_affects_subsequent_read"],
    "eval-multiple-values": ["test_unit_invariants.IndependentModuleContracts.test_eval_persistence_multiple_values_and_no_terminal_print"],
    "completion-incomplete": ["test_unit_invariants.IndependentModuleContracts.test_completion_does_not_read_eval_or_offer_comment_candidates"],
    "completion-stale-generation": ["test_unit_invariants.IndependentModuleContracts.test_completion_dwell_requires_same_candidate_and_generation"],
    "inspector-cycles": ["test_unit_invariants.IndependentModuleContracts.test_inspector_handles_cycles_and_missing_handles"],
    "integration-reader-security": [
        "test_unit_invariants.IndependentModuleContracts.test_editor_passive_reader_rejects_read_eval",
        "test_unit_invariants.IndependentModuleContracts.test_completion_does_not_read_eval_or_offer_comment_candidates"],
}
# Each entry is a real named FiveAM test, not a parent-suite success proxy.
FIVEAM = {
    "eval-streams": ("eval", ["captured-stdout-stderr"]),
    "eval-cancel-race": ("eval", ["cooperative-cancellation",
                                 "cancelled-queued-reader-never-runs"]),
    "completion-rotation": ("completion", ["exact-prefix-ranks-first"]),
    "inspector-packages": ("inspector", ["lazy-refresh-and-pagination", "asdf-inventory"]),
    "inspector-values": ("inspector", ["unbound-symbols-are-not-lexical",
                                      "variable-watches-are-live-and-mark-changes"]),
}
MODULES = {
    "eval": ["src/workbench/eval.lisp", "tests/workbench/eval-tests.lisp"],
    "completion": ["src/workbench/completion.lisp", "src/workbench/docs.lisp",
                   "tests/workbench/completion-tests.lisp"],
    "inspector": ["src/workbench/inspector.lisp", "src/workbench/slynk-adapter.lisp",
                  "tests/workbench/inspector-tests.lisp"],
}


def fiveam_case(case_id, root, out, check):
    module, names = FIVEAM[case_id]
    cmd = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
           "--noinform", "--non-interactive", "--eval", "(require :asdf)",
           "--eval", "(asdf:load-system :fiveam)"]
    for name in MODULES[module]:
        cmd.extend(["--load", name])
    package = "elmtui.workbench.%s.tests" % module
    for name in names:
        cmd.extend(["--eval", "(fiveam:run! (quote %s::%s))" % (package, name)])
    run = check("case-" + case_id, cmd, out, timeout=90)
    log = (out / ("case-" + case_id + ".stdout.log")).read_text(errors="replace")
    ok = (run["exit_code"] == 0 and log.count("Fail: 0") == len(names)
          and log.count("Skip: 0") == len(names)
          and log.count("Pass:") == len(names))
    return result("passed" if ok else "failed",
                  "Exact standalone FiveAM tests (not a substitute for live PTY)",
                  evidence={"stdout": run["stdout"], "stderr": run["stderr"]},
                  command=cmd, exit_code=run["exit_code"],
                  elapsed=run["elapsed_seconds"], warnings=run["warnings"])


SIZES = {
    "integration-80x24": "80x24",
    "integration-120x40": "120x40",
    "integration-160x50": "160x50",
}


def result(status, reason, evidence=None, command=None, exit_code=None, elapsed=0, warnings=None):
    return {"status": status, "reason": reason, "evidence": evidence,
            "command": command, "exit_code": exit_code,
            "elapsed_seconds": round(elapsed, 3), "warnings": warnings or []}


def unit_test(case_id, root, out, check):
    env = dict(os.environ)
    src = str(root / "tests/workbench/independent")
    env["PYTHONPATH"] = src + os.pathsep + env.get("PYTHONPATH", "")
    argv = [sys.executable, "-m", "unittest", "-v", *UNIT[case_id]]
    run = check("case-" + case_id, argv, out, timeout=90, env=env)
    ok = run["exit_code"] == 0 and "skipped" not in (
        (out / ("case-" + case_id + ".stderr.log")).read_text(errors="replace"))
    return result("passed" if ok else "failed", "Direct independent CLPM/SBCL API test; never a PTY pass",
                  evidence={"stdout": run["stdout"], "stderr": run["stderr"]},
                  command=argv, exit_code=run["exit_code"],
                  elapsed=run["elapsed_seconds"], warnings=run["warnings"])


def static_test(case_id, root, out, check):
    if case_id == "integration-warning-clean":
        argv = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
                "--noinform", "--non-interactive", "--eval", '(require :asdf)',
                "--eval", '(asdf:compile-system "elmtui-workbench" :force t)']
        run = check("case-" + case_id, argv, out, timeout=120)
        inherited = [line for line in run["warnings"] if "LOG4CL-IMPL" in line]
        workbench_warnings = [line for line in run["warnings"] if line not in inherited]
        ok = run["exit_code"] == 0 and not workbench_warnings
        return result("passed" if ok else "failed",
                      "Forced optional ASDF compile; inherited LOG4CL redefinition warnings=%d, owned-module warnings=%d" %
                      (len(inherited), len(workbench_warnings)),
                      evidence={"stdout":run["stdout"],"stderr":run["stderr"]},
                      command=argv, exit_code=run["exit_code"], elapsed=run["elapsed_seconds"],
                      warnings=run["warnings"])
    if case_id in ("integration-remote-opt-in", "inspector-slynk-optional"):
        argv = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
                "--noinform", "--non-interactive", "--eval", '(require :asdf)',
                "--eval", '(asdf:load-system "elmtui-workbench")',
                "--eval", '(let* ((components (asdf:system-depends-on (asdf:find-system "elmtui-workbench"))) (cap (elmtui.workbench.slynk:slynk-capability-report))) (unless (and (not (member "slynk" components :test (function string-equal))) (eq :disabled (getf cap :transport)) (eq :not-implemented (getf cap :remote-inspection))) (error "Slynk local opt-in contract violated")) (format t "LOCAL_SLYNK_DISABLED_OK~%"))']
        run = check("case-" + case_id, argv, out, timeout=70)
        text = (out / ("case-" + case_id + ".stdout.log")).read_text(errors="replace")
        ok = run["exit_code"] == 0 and "LOCAL_SLYNK_DISABLED_OK" in text
        return result("passed" if ok else "failed",
                      "Local-system load and optional transport capability only; not socket-level probing",
                      evidence={"stdout":run["stdout"],"stderr":run["stderr"]},
                      command=argv, exit_code=run["exit_code"], elapsed=run["elapsed_seconds"],
                      warnings=run["warnings"])


def quoted_reader_case(root, out, check):
    source = r'''(flet ((verify (source expected)
                         (let ((actual (not (null (elmtui.workbench.editor:editor-balanced-p
                                                  (elmtui.workbench.editor:make-editor-state :text source))))))
                           (unless (eq actual expected)
                             (error "Reader balance mismatch for ~S expected ~S got ~S"
                                    source expected actual)))))
                  (verify "(list (quote (x y)))" t)
                  (verify "(list #| outer #| nested |# comment |# 42)" t)
                  (verify (format nil "(list ~S 42)" "(") t)
                  (verify "(list #| unterminated" nil)
                  (verify (format nil "(list ~S" "(") nil)
                  (verify "#.(error \"passive reader evaluated source\")" nil)
                  (format t "WB_READER_LEXICAL_OK~%"))'''
    argv = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
            "--noinform", "--non-interactive", "--load", "src/workbench/editor.lisp",
            "--eval", source]
    run = check("case-editor-quoted-brackets", argv, out, timeout=60)
    text = (out / "case-editor-quoted-brackets.stdout.log").read_text(errors="replace")
    ok = run["exit_code"] == 0 and "WB_READER_LEXICAL_OK" in text
    return result("passed" if ok else "failed",
                  "Independent passive Common Lisp bracket/string/comment/read-eval edge assertions",
                  evidence={"stdout": run["stdout"], "stderr":run["stderr"]},
                  command=argv, exit_code=run["exit_code"],
                  elapsed=run["elapsed_seconds"], warnings=run["warnings"])


def pty_check(case_id, root, out):
    if not PrivatePTY.available():
        return result("not-run", "tmux/stty unavailable; no terminal fallback")
    base = out / ("live-" + case_id)
    start = time.monotonic()
    try:
        size = (120, 40) if case_id in ("completion-above-cursor", "completion-doc-dwell", "inspector-refresh") else (80, 24)
        with PrivatePTY(CMD, base, cols=size[0], rows=size[1], cwd=root, timeout=16) as app:
            frame, _ = app.wait(lambda screen, state: "Ready" in screen and "Transcript" in screen and "> |" in screen,
                                "ready-editor", timeout=16)
            if case_id == "integration-no-spinner":
                delta = app.idle_bytes(duration=0.65)
                if delta != 0:
                    raise AssertionError("unchanged UI emitted %d terminal bytes during idle" % delta)
                detail = "actual workbench terminal delta=0 over 0.65s"
            elif case_id == "completion-above-cursor":
                app.text("(mapc")
                app.key("C-Space")
                view, _ = app.wait(lambda screen, _: "COMPLETION" in screen and "MAPCAR" in screen,
                                   "completion-overlay", timeout=8)
                lines = view.splitlines()
                menu = next((i for i, s in enumerate(lines) if "COMPLETION" in s), -1)
                editor = next((i for i, s in enumerate(lines) if "> (mapc" in s), -1)
                if menu < 0 or editor < 0 or menu >= editor:
                    raise AssertionError("popup not above editor; menu row=%d editor row=%d" % (menu, editor))
                detail = "actual tmux cells: popup row %d above editor row %d" % (menu, editor)
                app.key("Escape")
                for _ in range(5):
                    app.key("BSpace")
            elif case_id == "integration-resize":
                app.text("ZZZ")
                app.wait(lambda screen, _: "ZZZ" in screen, "unsent-draft", timeout=6)
                for cols, rows in ((160, 50), (120, 40), (80, 24)):
                    frame, geo = app.resize(cols, rows)
                    if geo["cols"] != cols or geo["rows"] != rows or "ZZZ" not in frame:
                        raise AssertionError("resizing lost unsent edit at %sx%s" % (cols, rows))
                detail = "unsent draft persisted 80x24 -> 160x50 -> 120x40 -> 80x24"
                for _ in range(3):
                    app.key("BSpace")
            elif case_id == "editor-paste-controls":
                paste = "(list 1)\n(+ 2 3)"
                # Literal bracketed paste transport through the real tmux pane.
                app.text("\x1b[200~" + paste + "\x1b[201~")
                view, _ = app.wait(lambda screen, _: "list 1" in screen and "+ 2 3" in screen,
                                   "paste-buffer", timeout=6)
                if "Transcript (0)" not in view or "Evaluating..." in view:
                    raise AssertionError("multiline paste triggered unexpected evaluation")
                detail = "bracketed multiline paste preserved as editor-only input"
                for _ in range(len(paste) + 1):
                    app.key("BSpace")
            elif case_id == "eval-infinite-loop":
                app.text("(sleep 2)")
                app.key("Enter")
                app.wait(lambda screen, _: "Evaluating..." in screen, "slow-eval", timeout=5)
                app.key("C-c")
                app.wait(lambda screen, _: "Cancellation requested" in screen,
                         "responsive-cancel", timeout=0.9)
                app.text("Z")
                app.wait(lambda screen, _: "> Z" in screen, "editable-during-eval", timeout=0.9)
                app.key("BSpace")
                detail = "2s bounded evaluation remained keyboard-responsive with visible Ctrl+C request (cooperative)"
            elif case_id == "completion-doc-dwell":
                app.text("(mapc")
                app.key("C-Space")
                view, _ = app.wait(lambda screen, _: "COMPLETION" in screen,
                                   "completion-before-dwell", timeout=8)
                if "DOC:" in view:
                    raise AssertionError("documentation painted before first observable completion frame")
                doc, _ = app.wait(lambda screen, _: "DOC:" in screen,
                                  "delayed-selected-documentation", timeout=2)
                app.key("Down")
                changed, _ = app.wait(lambda screen, _: "COMPLETION" in screen and "DOC:" not in screen,
                                      "stale-documentation-cancelled", timeout=0.8)
                detail = "timed docs appeared after selection, cancelled immediately on Down"
                app.key("Escape")
                for _ in range(5):
                    app.key("BSpace")
            elif case_id == "inspector-refresh":
                app.text("(defparameter *wb-qa-live-value* 1)")
                app.key("Enter")
                app.wait(lambda screen, _: "*WB-QA-LIVE-VALUE*" in screen and
                         "Evaluation" in screen, "defined-global", timeout=6)
                app.key("F2")
                app.key("Tab")  # Packages -> Symbols
                app.key("/")
                app.text("WB-QA-LIVE-VALUE")
                app.key("Enter")
                app.wait(lambda screen, _: "WB-QA-LIVE-VALUE" in screen and "IMAGE / SYMBOLS" in screen,
                         "filtered-symbol", timeout=5)
                app.key("w")
                app.key("Tab")  # Symbols -> Watches
                app.wait(lambda screen, _: "IMAGE / WATCHES" in screen and
                         any("WB-QA-LIVE-VALUE" in line and "1" in line
                             for line in screen.splitlines()), "watch-initial", timeout=5)
                app.key("F2")
                app.text("(setf *wb-qa-live-value* 2)")
                app.key("Enter")
                app.wait(lambda screen, _: "IMAGE / WATCHES" in screen and
                         any("WB-QA-LIVE-VALUE" in line and "2" in line
                             for line in screen.splitlines()), "watch-after-eval", timeout=6)
                detail = "watched variable refreshed from 1 to 2 without losing editor focus"
            elif case_id == "integration-termios":
                detail = "private PTY exact stty -g and cursor restoration"
            else:
                return result("not-run", "no matching application oracle")
            finish = app.finish(key="C-d", timeout=10)
            if not (finish["exit_code"] == 0 and finish["termios_restored"] and
                    finish["cursor_visible"] and finish["shell_sentinel"]):
                raise AssertionError("shutdown/termios/cursor contract failed: %r" % finish)
        return result("passed", detail, evidence=str((base / "timeline.json").relative_to(root)),
                      command=CMD, exit_code=0, elapsed=time.monotonic()-start)
    except Exception as exc:
        return result("failed", "%s: %s" % (type(exc).__name__, exc),
                      evidence=str((base / "timeline.json").relative_to(root)) if
                      (base / "timeline.json").exists() else None,
                      command=CMD, exit_code=1, elapsed=time.monotonic()-start)


def run_case_oracles(cases, root, out, check):
    """Return an ID -> execution receipt dict, not blanket suite-level success."""
    receipts = {}
    if not (root / "elmtui-workbench.asd").is_file() or not (
        root / "examples/workbench.lisp").is_file():
        return receipts

    # Genuine W5 PTY smoke exposes separate assertion results per geometry.
    argv = [sys.executable, "tests/workbench/pty-workbench.py", "--traces",
            str(out / "w5-smoke-traces")]
    smoke = check("application-smoke", argv, out, timeout=100)
    text = (out / "application-smoke.stdout.log").read_text(errors="replace")
    for case_id, size in SIZES.items():
        ok = re.search(r"^PASS " + re.escape(size) + r"\b", text, re.M)
        receipts[case_id] = result("passed" if ok else "failed",
                                  "Real CLPM app PTY startup/edit/eval/completion/exit at " + size,
                                  evidence={"stdout":smoke["stdout"],"stderr":smoke["stderr"],
                                            "trace":str((out / "w5-smoke-traces" / (size+".trace")).relative_to(root))},
                                  command=argv, exit_code=0 if ok else smoke["exit_code"],
                                  elapsed=smoke["elapsed_seconds"],warnings=smoke["warnings"])

    receipts["editor-quoted-brackets"] = quoted_reader_case(root, out, check)
    for case_id in UNIT:
        receipts[case_id] = unit_test(case_id, root, out, check)
    for case_id in FIVEAM:
        receipts[case_id] = fiveam_case(case_id, root, out, check)
    for case_id in ("integration-warning-clean", "integration-remote-opt-in",
                    "inspector-slynk-optional"):
        receipts[case_id] = static_test(case_id, root, out, check)
    for case_id in ("integration-no-spinner", "completion-above-cursor",
                    "integration-resize", "integration-termios",
                    "editor-paste-controls", "eval-infinite-loop",
                    "completion-doc-dwell", "inspector-refresh"):
        receipts[case_id] = pty_check(case_id, root, out)
    return receipts
