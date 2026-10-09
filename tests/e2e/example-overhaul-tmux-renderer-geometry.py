#!/usr/bin/env python3
"""Verify global layout coordinates vs legacy local layouts independently."""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPR = r'''(let* ((snap (elmtui.examples.tmux-slider:snapshot-from-styled-string
                       (format nil "FIRST~%SECOND~%THIRD") 20 4))
                    (state (list :snapshot snap :tick 3 :dx 1))
                    (backend (elmtui.platform.backend.terminal::make-terminal-instance
                              :stream *standard-output* :width 20 :height 4))
                    (rect (elmtui.view.geo:make-rectangle
                           :pos (elmtui.view.geo:make-pos :x 0 :y 0)
                           :size (elmtui.view.geo:make-size :w 20 :h 4)))
                    (ctx (elmtui.contracts:make-app-context
                          :state state :view-fn
                          (function elmtui.examples.tmux-slider:slider-view)
                          :backend backend :viewport-rect rect)))
               (elmtui.pipeline:render-pipeline-0-to-5 ctx)
               (let ((buf (elmtui.contracts:ctx-back-buffer ctx)))
                 (loop for y below 4 do
                   (format t "BUFFER-ROW-~D:~A~%" y
                     (coerce
                        (loop for x below 20 collect
                          (elmtui.platform.backend.common.virtual-buffer:buffer-char
                           buf y x)) 'string)))))'''

class GlobalRectangles(unittest.TestCase):
    def test_real_pipeline_does_not_double_parent_offsets(self):
        result = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive",
             "--eval", "(require :asdf)",
             "--eval", '(asdf:load-system "elmtui")',
             "--load", "examples/tmux-slider.lisp", "--eval", EXPR],
            cwd=ROOT, capture_output=True, text=True, timeout=45)
        self.assertEqual(result.returncode, 0, result.stderr[-1800:])
        lines = [line for line in result.stdout.splitlines()
                 if line.startswith("BUFFER-ROW-")]
        self.assertEqual(len(lines), 4)
        self.assertIn("SECOND", lines[1])
        self.assertIn("THIRD", lines[2])
        self.assertNotIn("SECOND", lines[2])
        self.assertNotIn("THIRD", lines[3])

if __name__ == "__main__":
    unittest.main(verbosity=2)
