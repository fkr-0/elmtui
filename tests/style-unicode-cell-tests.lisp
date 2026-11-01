;;; Display-cell agreement among intrinsic layout, virtual buffer and diff.
(uiop:define-package :elmtui.tests.style-unicode-cells
  (:use :cl :fiveam))
(in-package :elmtui.tests.style-unicode-cells)
(def-suite unicode-cell-contract-suite :in elmtui.tests:elmtui-test
  :description "Wide glyphs and NFC text occupy measured terminal cells")
(in-suite unicode-cell-contract-suite)

(test layout-controls-remain-separate-from-graphemes
  (is (= 9 (elmtui.view.layout.size-utils:terminal-string-width (format nil "a~Cb" #\Tab))))
  (is (= 3 (elmtui.view.layout.size-utils:terminal-string-width (format nil "ab~%xyz"))))
  (is (string= "       b" (elmtui.view.layout.size-utils:terminal-string-slice
                           (format nil "a~Cb" #\Tab) 1 9)))
  (is (string= "ab" (elmtui.view.layout.size-utils:terminal-string-slice
                     (format nil "ab~%xyz") 0))))

(defun %buffer-glyph (buffer x &optional (y 0))
  (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char
   (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer y x)))

(defun %paint-standalone-text (content width height &key (white-space :nowrap))
  (let* ((node (make-instance 'elmtui.view.base-elements:text-element
                              :content content
                              :style (list :white-space white-space
                                           :fg-color :green)))
         (buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer
                  width height)))
    (setf (elmtui.view.element:el/layout-rect node)
          (elmtui.view.geo:make-rectangle
           :pos (elmtui.view.geo:make-pos :x 0 :y 0)
           :size (elmtui.view.geo:make-size :w width :h height)))
    (elmtui.platform.tree-renderer:render-laid-out-tree-to-buffer
     node :buffer buffer)
    buffer))

(test intrinsic-width-matches-the-terminal-painter-and-physical-clipper
  (dolist (fixture (list (list #\A 1)
                         (list (code-char #x754c) 2)
                         (list (code-char #x1f642) 2)
                         (list (code-char #x0301) 0)))
    (destructuring-bind (glyph cells) fixture
      (is (= cells
             (elmtui.view.layout.size-utils:terminal-glyph-width glyph)))
      (is (= cells
             (elmtui.platform.backend.terminal.diff-renderer::%physical-glyph-columns
              glyph)))))
  (let* ((text (format nil "~CA" (code-char #x754c)))
         (node (make-instance 'elmtui.view.base-elements:text-element
                              :content text)))
    (is (= 3 (elmtui.view.layout.size-utils:terminal-string-width text)))
    (multiple-value-bind (minw maxw minh maxh)
        (elmtui.view.layout.size-utils:measure-node-intrinsic-size node 80 24)
      (declare (ignore maxw minh maxh))
      (is (= 3 minw)))))

(test wide-glyph-occupies-two-cells-with-continuation-sentinel
  (let* ((cjk (code-char #x754c))
         (buffer (%paint-standalone-text (format nil "~CA" cjk) 3 1))
         (operations (elmtui.render.diff:compute-buffer-diff
                      nil buffer :initial-frame-p t)))
    (is (char= cjk (%buffer-glyph buffer 0)))
    (is (char= #\Null (%buffer-glyph buffer 1)))
    (is (char= #\A (%buffer-glyph buffer 2)))
    (is (equal (list (string cjk) "A")
               (mapcar (lambda (op) (getf op :chars)) operations)))
    (is (equal '(0 2)
               (mapcar (lambda (op) (getf op :start-col)) operations)))
    (is (null (elmtui.render.diff:compute-buffer-diff
               buffer buffer :initial-frame-p nil)))))

(test wide-glyph-never-partially-paints-a-clipped-last-column
  (let* ((cjk (code-char #x754c))
         (buffer (%paint-standalone-text (format nil "A~C" cjk) 2 1)))
    (is (char= #\A (%buffer-glyph buffer 0)))
    (is (char= #\Space (%buffer-glyph buffer 1))))
  (let* ((cjk (code-char #x754c))
         (buffer (%paint-standalone-text (format nil "A~C" cjk) 2 2
                                         :white-space :normal)))
    (is (char= #\A (%buffer-glyph buffer 0)))
    (is (char= cjk (%buffer-glyph buffer 0 1)))
    (is (char= #\Null (%buffer-glyph buffer 1 1)))))

(test canonically-composable-accent-occupies-one-cell
  (let* ((input (concatenate 'string "e" (string (code-char #x0301))))
         (buffer (%paint-standalone-text (concatenate 'string input "X") 2 1)))
    (is (= 1 (elmtui.view.layout.size-utils:terminal-string-width input)))
    (is (char= (code-char #xe9) (%buffer-glyph buffer 0)))
    (is (char= #\X (%buffer-glyph buffer 1)))))

(test uncomposable-combining-sequence-is-preserved-across-render-and-diff
  (let* ((text (concatenate 'string "q" (string (code-char #x0301)) "X"))
         (buffer (%paint-standalone-text text 2 1))
         (cell (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at
                buffer 0 0))
         (ops (elmtui.render.diff:compute-buffer-diff nil buffer)))
    (is (= 2 (elmtui.view.layout.size-utils:terminal-string-width text)))
    (is (equal (subseq text 0 2)
               (elmtui.platform.backend.common.virtual-buffer:buffer-cell-grapheme
                cell)))
    (is (string= text (apply #'concatenate 'string
                             (mapcar (lambda (op) (getf op :chars)) ops))))
    (is (equal '(0) (mapcar (lambda (op) (getf op :start-col)) ops)))))

(test emoji-zwj-and-flag-clusters-are-atomic-two-cell-glyphs
  (let* ((woman (code-char #x1f469))
         (laptop (code-char #x1f4bb))
         (zwj (code-char #x200d))
         (flag-a (code-char #x1f1e9))
         (flag-b (code-char #x1f1ea))
         (emoji (format nil "~C~C~C" woman zwj laptop))
         (flag (format nil "~C~C" flag-a flag-b))
         (content (concatenate 'string emoji flag "X"))
         (buffer (%paint-standalone-text content 5 1))
         (ops (elmtui.render.diff:compute-buffer-diff nil buffer)))
    (is (= 5 (elmtui.view.layout.size-utils:terminal-string-width content)))
    (is (string= emoji
                 (elmtui.platform.backend.common.virtual-buffer:buffer-cell-grapheme
                  (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at
                   buffer 0 0))))
    (is (char= #\Null (%buffer-glyph buffer 1)))
    (is (char= flag-a (%buffer-glyph buffer 2)))
    (is (char= #\Null (%buffer-glyph buffer 3)))
    (is (char= #\X (%buffer-glyph buffer 4)))
    (is (string= content
                 (apply #'concatenate 'string
                        (mapcar (lambda (op) (getf op :chars)) ops))))
    (is (equal '(0 2 4)
               (mapcar (lambda (op) (getf op :start-col)) ops)))))

(test grapheme-copy-compare-and-diff-preserve-noncomposed-marks
  (let* ((a (concatenate 'string "q" (string (code-char #x0301))))
         (b (concatenate 'string "q" (string (code-char #x0302))))
         (original (%paint-standalone-text a 1 1))
         (copy (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer
                original))
         (changed (%paint-standalone-text b 1 1)))
    (is (null (elmtui.render.diff:compute-buffer-diff original copy)))
    (is (equal a
               (elmtui.platform.backend.common.virtual-buffer:buffer-cell-grapheme
                (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at
                 copy 0 0))))
    (let ((diff (elmtui.render.diff:compute-buffer-diff copy changed)))
      (is (= 1 (length diff)))
      (is (string= b (getf (first diff) :chars))))))

(test physical-clipping-never-splits-a-wide-grapheme-cluster
  (let* ((emoji (format nil "~C~C~C" (code-char #x1f469)
                        (code-char #x200d) (code-char #x1f4bb)))
         (op (list :type :write-chars :row 0 :start-col 0
                   :chars (concatenate 'string "A" emoji "B")
                   :style nil))
         (clip #'elmtui.platform.backend.terminal.diff-renderer::%clip-physical-diff-operations))
    (let ((result (funcall clip (list op) 2 1 0 0)))
      (is (= 1 (length result)))
      (is (string= "A" (getf (first result) :chars))))
    (let ((result (funcall clip (list op) 3 1 0 0)))
      (is (= 1 (length result)))
      (is (string= (concatenate 'string "A" emoji)
                   (getf (first result) :chars))))))

(test emoji-variation-selector-and-skin-tone-have-two-cell-width
  (let* ((heart (format nil "~C~C" (code-char #x2764)
                        (code-char #xfe0f)))
         (thumbs (format nil "~C~C" (code-char #x1f44d)
                         (code-char #x1f3fd)))
         (input (concatenate 'string heart thumbs))
         (buffer (%paint-standalone-text input 4 1)))
    (is (= 4 (elmtui.view.layout.size-utils:terminal-string-width input)))
    (is (char= #\Null (%buffer-glyph buffer 1)))
    (is (char= #\Null (%buffer-glyph buffer 3)))
    (is (string= heart
                 (elmtui.platform.backend.common.virtual-buffer:buffer-cell-grapheme
                  (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at
                   buffer 0 0))))))

(test grapheme-preserved-through-buffer-blit-and-resize
  (let* ((cluster (format nil "q~C" (code-char #x0301)))
         (source (%paint-standalone-text cluster 1 1))
         (target (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer
                  1 1)))
    (elmtui.platform.backend.common.virtual-buffer:copy-buffer-contents
     source target)
    (let ((cell (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at
                 target 0 0)))
      (is (equal cluster
                 (elmtui.platform.backend.common.virtual-buffer:buffer-cell-grapheme
                  cell))))
    (let* ((resized
             (elmtui.platform.backend.common.virtual-buffer:resize-buffer
              target 2 1))
           (cell (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at
                  resized 0 0)))
      (is (equal cluster
                 (elmtui.platform.backend.common.virtual-buffer:buffer-cell-grapheme
                  cell))))))
