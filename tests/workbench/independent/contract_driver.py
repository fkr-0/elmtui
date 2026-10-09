"""Execute black-box Common Lisp API assertions in an isolated CLPM/SBCL process.

No test imports or patches the implementation. Each invocation loads sources
directly and passes one Lisp expression as an argv item (never via a shell).
The currently active owner may still change an API; failures are reported
rather than silently treated as skips.
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
LISP_MODULES = {
    "editor": ROOT / "src/workbench/editor.lisp",
    "eval": ROOT / "src/workbench/eval.lisp",
    "completion": ROOT / "src/workbench/completion.lisp",
    "docs": ROOT / "src/workbench/docs.lisp",
    "inspector": ROOT / "src/workbench/inspector.lisp",
}
MARKER = "WB_INDEPENDENT_CONTRACT_PASS"


def required_tools() -> str | None:
    return next((tool for tool in ("clpm", "sbcl") if not shutil.which(tool)), None)


def run_lisp(names: tuple[str, ...], form: str, *, timeout: float = 16.0):
    """Return a completed subprocess; raises on missing source or timeout."""
    paths = [LISP_MODULES[name] for name in names]
    missing = [str(path.relative_to(ROOT)) for path in paths if not path.is_file()]
    if missing:
        raise FileNotFoundError(", ".join(missing))
    code = "(progn " + form + ' (format t "~&' + MARKER + '~%"))'
    args = [
        "clpm", "bundle", "exec", "--with-client", "sbcl", "--",
        "--noinform", "--non-interactive", "--no-sysinit", "--no-userinit",
        "--eval", "(require :asdf)",
    ]
    for path in paths:
        args.extend(["--load", str(path)])
    args.extend(["--eval", code])
    return subprocess.run(
        args, cwd=ROOT, capture_output=True, text=True, timeout=timeout,
        check=False,
    )
