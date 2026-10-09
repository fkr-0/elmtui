#!/usr/bin/env python3
"""Pure styled tmux snapshot and deterministic ElmTUI frame contracts.

The assertions exercise real Lisp functions without a terminal or tmux server.
"""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]

LISP = r'''
(let* ((source (format nil "~C[31;44mABC~C[0m~%DEF~%GHI~%JKL" #\Escape #\Escape))
       (snapshot (elmtui.examples.tmux-slider:snapshot-from-styled-string source 10 4))
       (cells (getf snapshot :cells)))
  (assert (char= (car (aref cells 0 0)) #\A))
  (assert (eq (getf (cdr (aref cells 0 0)) :fg) :red))
  (assert (eq (getf (cdr (aref cells 0 0)) :bg) :blue))
  (assert (char= (car (aref cells 1 0)) #\D))
  (assert (null (cdr (aref cells 1 0))))
  (assert (char= (car (aref cells 3 0)) #\J))
  (multiple-value-bind (glyph fg bg attrs)
      (elmtui.examples.tmux-slider::%cell-presentation snapshot 0 1 0 1)
    (assert (char= glyph #\D))
    (assert (equal bg '(46 212 249)))
    (assert (member :bold attrs))
    (assert (equal fg '(240 251 255))))
  (assert (null (cdr (aref cells 1 0))))
  (assert (null (elmtui.examples.tmux-slider:slider-subscriptions
                 '(:running nil :should-quit nil :period 0.085))))
  (assert (null (elmtui.examples.tmux-slider:slider-subscriptions
                 '(:running t :should-quit t :period 0.085))))
  (assert (consp (elmtui.examples.tmux-slider:slider-subscriptions
                   '(:running t :should-quit nil :period 0.085))))
  (format t "PURE-STYLED-SLIDER-PASS~%"))
'''


class PureSlider(unittest.TestCase):
    def test_styled_cell_and_immutable_highlight(self):
        proc = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive",
             "--eval", '(asdf:load-system "elmtui")',
             "--load", "examples/tmux-slider.lisp",
             "--eval", LISP],
            cwd=ROOT, text=True, capture_output=True, timeout=30)
        self.assertEqual(proc.returncode, 0, proc.stderr[-4500:])
        self.assertIn("PURE-STYLED-SLIDER-PASS", proc.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
