"""Qualified docstrings for the 81 newly documented runtime and presentation exports.

These are live SBCL checks, not snapshots of textual comments. In particular
they protect the public API from regressions in docstring availability and
check documented return types and scroll/runtime ownership behavior.
"""
from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPORTED_SYMBOLS = """(ELMTUI.RUNTIME.CONTEXT:MAKE-RUNTIME-CONTEXT function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-ACTIVE-P function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-APP-SENDER function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-APP-SPEC function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-BACKEND function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-FOCUS-MANAGER function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-GENERATION function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-INPUT-CONTEXT function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-LAST-CONTEXT function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-MESSAGE-PROCESSOR function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-MODEL function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-PHASE function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-PREVIOUS-FRAME-BUFFER function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-ROOT-VIEWPORT-ID-PATH function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-SHUTDOWN-REQUESTED-P function)
(ELMTUI.RUNTIME.CONTEXT:RUNTIME-CONTEXT-SUBSCRIPTIONS function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:MSG-SCROLL-CONTAINER-KEY-PRESS variable)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:MSG-SCROLL-CONTAINER-SCROLL variable)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:MSG-SCROLL-CONTAINER-SET-SCROLL variable)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:MSG-SCROLL-CONTAINER-UPDATE-DIMENSIONS variable)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-CONTENT-HEIGHT function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-CONTENT-WIDTH function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-DISABLED function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-ID function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-ON-SCROLL function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-SCROLL-LEFT function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-SCROLL-TOP function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-SHOW-SCROLLBAR-X function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-SHOW-SCROLLBAR-Y function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-VIEWPORT-HEIGHT function)
(ELMTUI.UI.WIDGETS.SCROLLABLE-CONTAINER:SCROLLABLE-CONTAINER-MODEL-VIEWPORT-WIDTH function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL-CHAR function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL-STYLE function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CHAR function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-STYLE function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:INVALID-BUFFER-COORDINATES-ERROR-BUFFER function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:INVALID-BUFFER-COORDINATES-ERROR-COL function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:INVALID-BUFFER-COORDINATES-ERROR-ROW function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:MAKE-BUFFER-CELL function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:VIRTUAL-TERMINAL-BUFFER-CELLS function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:VIRTUAL-TERMINAL-BUFFER-HEIGHT function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:VIRTUAL-TERMINAL-BUFFER-LOCK function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:VIRTUAL-TERMINAL-BUFFER-WIDTH function)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-ERROR type)
(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:INVALID-BUFFER-COORDINATES-ERROR type)
(ELMTUI.VIEW.POSITION:COPY-ELEMENT-GRID-COORDINATES function)
(ELMTUI.VIEW.POSITION:COPY-ELEMENT-POSITION function)
(ELMTUI.VIEW.POSITION:ELEMENT-GRID-COORDINATES-COL function)
(ELMTUI.VIEW.POSITION:ELEMENT-GRID-COORDINATES-COL-SPAN function)
(ELMTUI.VIEW.POSITION:ELEMENT-GRID-COORDINATES-ROW function)
(ELMTUI.VIEW.POSITION:ELEMENT-GRID-COORDINATES-ROW-SPAN function)
(ELMTUI.VIEW.POSITION:ELEMENT-POSITION-HEIGHT function)
(ELMTUI.VIEW.POSITION:ELEMENT-POSITION-WIDTH function)
(ELMTUI.VIEW.POSITION:ELEMENT-POSITION-X function)
(ELMTUI.VIEW.POSITION:ELEMENT-POSITION-Y function)
(ELMTUI.VIEW.POSITION:MAKE-ELEMENT-GRID-COORDINATES function)
(ELMTUI.VIEW.POSITION:MAKE-ELEMENT-POSITION function)
(ELMTUI.VIEW.ELEMENT:EL/CHILDREN function)
(ELMTUI.VIEW.ELEMENT:EL/CONTENT function)
(ELMTUI.VIEW.ELEMENT:EL/DISPLAY function)
(ELMTUI.VIEW.ELEMENT:EL/ID function)
(ELMTUI.VIEW.ELEMENT:EL/LAYOUT-RECT function)
(ELMTUI.VIEW.ELEMENT:EL/PROPS function)
(ELMTUI.VIEW.ELEMENT:EL/SIZE function)
(ELMTUI.VIEW.ELEMENT:EL/STYLES function)
(ELMTUI.VIEW.ELEMENT:EL/STYLES-OF function)
(ELMTUI.VIEW.ELEMENT:EL/TYPE function)
(ELMTUI.VIEW.ELEMENT:ELEMENT-P function)
(ELMTUI.STATE.MODEL:FORM-STATE-SCHEMA variable)
(ELMTUI.STATE.MODEL:MAKE-STATE-PATCH function)
(ELMTUI.STATE.MODEL:MAKE-TRANSACTION function)
(ELMTUI.STATE.MODEL:STATE-PATCH-P function)
(ELMTUI.STATE.MODEL:TRANSACTION-DESCRIPTION function)
(ELMTUI.STATE.MODEL:TRANSACTION-ID function)
(ELMTUI.STATE.MODEL:TRANSACTION-P function)
(ELMTUI.STATE.MODEL:TRANSACTION-PATCHES function)
(ELMTUI.STATE.MODEL:TRANSACTION-POST-HOOKS function)
(ELMTUI.STATE.MODEL:TRANSACTION-PRE-HOOKS function)
(ELMTUI.STATE.MODEL:TRANSACTION-ROLLBACK function)
(ELMTUI.STATE.MODEL:TRANSACTION-STATUS function)
(ELMTUI.STATE.MODEL:TRANSACTION-TIMESTAMP function)"""


def sbcl(form: str) -> str:
    result = subprocess.run(
        [
            "clpm", "bundle", "exec", "--with-client", "sbcl", "--",
            "--noinform", "--non-interactive", "--eval", "(require :asdf)",
            "--eval", "(asdf:load-system :elmtui)", "--eval", form,
        ], cwd=ROOT, capture_output=True, text=True, timeout=60
    )
    if result.returncode:
        raise AssertionError(
            f"SBCL exited {result.returncode}\n"
            + (result.stderr + "\n" + result.stdout)[-6000:]
        )
    return result.stdout


class PublicRuntimeDocstrings(unittest.TestCase):
    def test_all_81_exports_have_substantive_live_docstrings(self):
        self.assertEqual(len(EXPORTED_SYMBOLS.splitlines()), 81)
        form = (
            "(progn (dolist (spec '(" + EXPORTED_SYMBOLS
            + ")) (destructuring-bind (sym kind) spec "
            + "(unless (and (eq :external (nth-value 1 (find-symbol "
            + "(symbol-name sym) (symbol-package sym)))) "
            + "(stringp (documentation sym kind)) "
            + "(>= (length (documentation sym kind)) 50)) "
            + "(error \"Missing documented export: ~S (~S)\" sym kind)))) "
            + '(format t "EIGHTY-ONE-API-DOCS-PASS~%"))'
        )
        self.assertIn("EIGHTY-ONE-API-DOCS-PASS", sbcl(form))

    def test_runtime_context_lifecycle_and_geometry(self):
        form = r'''(progn
           (let* ((ctx (elmtui.runtime.context:make-runtime-context))
                  (generation (elmtui.runtime.context:runtime-context-generation ctx))
                  (pos (elmtui.view.position:make-element-position
                        :x 4 :y 5 :width 7 :height 3))
                  (copied (elmtui.view.position:copy-element-position pos)))
             (assert (eq :booting (elmtui.runtime.context:runtime-context-phase ctx)))
             (assert (elmtui.runtime.context:runtime-context-valid-generation-p ctx generation))
             (assert (= 4 (elmtui.view.position:element-position-x copied)))
             (setf (elmtui.view.position:element-position-x copied) 12)
             (assert (= 4 (elmtui.view.position:element-position-x pos)))
             (elmtui.runtime.context:invalidate-runtime-context ctx)
             (assert (eq :stopped (elmtui.runtime.context:runtime-context-phase ctx)))
             (assert (not (elmtui.runtime.context:runtime-context-active-p ctx)))
             (assert (not (elmtui.runtime.context:runtime-context-valid-generation-p ctx generation))))
           (format t "RUNTIME-GEOMETRY-PASS~%"))'''
        self.assertIn("RUNTIME-GEOMETRY-PASS", sbcl(form))

    def test_scroll_offset_clamping_and_buffer_state(self):
        form = r'''(progn
           (multiple-value-bind (model command)
               (elmtui.ui.widgets.scrollable-container:init-scrollable-container
                 :list :viewport-width 10 :viewport-height 4
                 :content-width 30 :content-height 20)
             (assert (null command))
             (assert (= 30 (elmtui.ui.widgets.scrollable-container:scrollable-container-model-content-width model)))
             (assert (= 20 (elmtui.ui.widgets.scrollable-container:scrollable-container-model-content-height model)))
             (assert (= 0 (elmtui.ui.widgets.scrollable-container:scrollable-container-model-scroll-left model)))
             (setf (elmtui.ui.widgets.scrollable-container:scrollable-container-model-disabled model) t)
             (multiple-value-bind (updated commands)
                 (elmtui.ui.widgets.scrollable-container:update-scrollable-container
                   (list :scroll-container-set-scroll :x 100 :y 100) model)
               (assert (eq model updated))
               (assert (null commands))))
           (let* ((buf (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 4 3))
                  (cell (elmtui.platform.backend.common.virtual-buffer:make-buffer-cell :char #\A)))
             (assert (= 4 (elmtui.platform.backend.common.virtual-buffer:virtual-terminal-buffer-width buf)))
             (assert (= 3 (elmtui.platform.backend.common.virtual-buffer:virtual-terminal-buffer-height buf)))
             (assert (char= #\A (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell))))
           (format t "SCROLL-BUFFER-PASS~%"))'''
        self.assertIn("SCROLL-BUFFER-PASS", sbcl(form))


if __name__ == "__main__":
    unittest.main()
