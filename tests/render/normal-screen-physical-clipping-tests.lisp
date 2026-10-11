;;; Regression: normal-screen terminal-cell clipping, run through CLPM.
(uiop:define-package :elmtui.tests.normal-screen-physical-clipping (:use :cl :fiveam))

(in-package :elmtui.tests.normal-screen-physical-clipping)

(def-suite normal-screen-physical-clipping-tests :in elmtui.tests:elmtui-test)
(in-suite normal-screen-physical-clipping-tests)

(defun check-glyph-clipping () "ASCII, CJK and combining characters are measured in physical cells." (let* ((op (list :type :write-chars :row 0 :start-col 4 :chars "A界B" :style :preserved-style)) (full (first (elmtui.platform.backend.terminal.diff-renderer::%clip-physical-diff-operations (list op) 7 3 0 0))) (short (first (elmtui.platform.backend.terminal.diff-renderer::%clip-physical-diff-operations (list op) 6 3 0 0)))) (is (string= (getf full :chars) "A界")) (is (string= (getf short :chars) "A")) (is (eq (getf full :style) :preserved-style))))

(defun check-coordinate-clipping () "Physical origin and row limits are enforced without terminal writes." (let ((clip #'elmtui.platform.backend.terminal.diff-renderer::%clip-physical-diff-operations)) (is (null (funcall clip (list (list :type :write-chars :row 4 :start-col 0 :chars "X")) 10 3 0 0))) (is (null (funcall clip (list (list :type :write-chars :row 1 :start-col 0 :chars "X")) 10 3 2 0))) (is (null (funcall clip (list (list :type :write-chars :row 0 :start-col 2 :chars "界")) 3 3 0 0)))))

(defun check-edge-graphemes () "Do not split double-width glyphs; preserve combining marks with their base." (let* ((clip #'elmtui.platform.backend.terminal.diff-renderer::%clip-physical-diff-operations) (left (first (funcall clip (list (list :type :write-chars :row 0 :start-col -1 :chars "A界B")) 3 2 0 0))) (combining (first (funcall clip (list (list :type :write-chars :row 0 :start-col 2 :chars "éZ")) 3 2 0 0)))) (is (= (getf left :start-col) 0)) (is (string= (getf left :chars) "界B")) (is (string= (getf combining :chars) "é"))))

(test physical-glyph-clip (check-glyph-clipping))
(test physical-origin-clip (check-coordinate-clipping))
(test physical-wide-and-combining-clip (check-edge-graphemes))

(test physical-zero-dimensions-produce-no-writes
  (let* ((clip #'elmtui.platform.backend.terminal.diff-renderer::%clip-physical-diff-operations)
         (writes (list (list :type :write-chars :row 0 :start-col 0 :chars "X"))))
    (is (null (funcall clip writes 0 4 0 0)))
    (is (null (funcall clip writes 10 0 0 0)))))

(test physical-cursor-width-uses-display-columns
  (let ((width #'elmtui.platform.backend.terminal.diff-renderer::%physical-run-columns))
    (is (= 4 (funcall width "A界B")))
    (is (= 1 (funcall width "é")))
    (is (= 0 (funcall width "")))))

(test clipped-wide-glyph-drops-its-combining-mark
  (let* ((op (list :type :write-chars :row 0 :start-col 0 :chars "A界́"))
         (result (first (elmtui.platform.backend.terminal.diff-renderer::%clip-physical-diff-operations (list op) 2 1 0 0))))
    (is (string= "A" (getf result :chars)))))
