;;; Executable capability matrix: not only accepted style declarations, but
;;; the actual styled cells written by the terminal rendering pipeline.
(uiop:define-package :elmtui.tests.style-render-capabilities
  (:use :cl :fiveam)
  (:import-from :elmtui.view.base-elements
                #:container-element #:text-element)
  (:import-from :elmtui.view.geo
                #:make-rectangle #:make-pos #:make-size)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:make-virtual-buffer #:buffer-cell-at
                #:buffer-cell-char #:buffer-cell-style)
  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:terminal-color-simple #:terminal-style-fg-color
                #:terminal-style-bg-color #:terminal-style-bold
                #:terminal-style-underline #:terminal-style-inverse
                #:terminal-style-faint #:terminal-style-strike)
  (:import-from :elmtui.platform.tree-renderer
                #:render-laid-out-tree-to-buffer))
(in-package :elmtui.tests.style-render-capabilities)

(def-suite style-render-capabilities-suite :in elmtui.tests:elmtui-test
  :description "Style declarations must cause exact terminal buffer effects")
(in-suite style-render-capabilities-suite)

(defun %rect (x y width height)
  (make-rectangle :pos (make-pos :x x :y y)
                  :size (make-size :w width :h height)))

(defun %cell (buffer row col)
  (buffer-cell-at buffer row col))

(defun %fg (buffer row col)
  (terminal-style-fg-color (buffer-cell-style (%cell buffer row col))))

(defun %bg (buffer row col)
  (let ((style (buffer-cell-style (%cell buffer row col))))
    (and style (terminal-style-bg-color style))))

(defun %color-rgb (color)
  (list (elmtui.platform.backend.common.ansi-styling::terminal-color-red color)
        (elmtui.platform.backend.common.ansi-styling::terminal-color-green color)
        (elmtui.platform.backend.common.ansi-styling::terminal-color-blue color)))

(defun %paint-box (style &key (width 7) (height 5))
  (let ((buffer (make-virtual-buffer (+ width 3) (+ height 3)))
        (node (make-instance 'container-element :style style)))
    (setf (elmtui.view.element:el/layout-rect node)
          (%rect 1 1 width height))
    (render-laid-out-tree-to-buffer node :buffer buffer)
    buffer))

(test border-color-is-the-border-foreground-not-the-text-foreground
  "A registered :border-color must affect the rendered glyphs."
  (let* ((buffer (%paint-box
                  '(:border t :border-width 1 :border-style :solid
                    :fg-color :white :bg-color :black
                    :border-color :red :bold t)))
         (corner (%cell buffer 1 1))
         (style (buffer-cell-style corner)))
    (is (char= #\┌ (buffer-cell-char corner)))
    (is (eq :red (terminal-color-simple (%fg buffer 1 1))))
    (is (eq :red (terminal-color-simple (%fg buffer 1 4))))
    (is (eq :red (terminal-color-simple (%fg buffer 3 1))))
    (is (eq :black (terminal-color-simple
                    (terminal-style-bg-color style))))
    (is (terminal-style-bold style))
    (is (eq :black (terminal-color-simple (%bg buffer 3 4))))))

(test border-side-colors-honor-specific-over-global-and-accept-rgb
  "Top/right/bottom/left colors override the shared border color."
  (let ((buffer (%paint-box
                 '(:border t :border-style :double
                   :border-color :white :fg-color :black
                   :border-top-color :red
                   :border-right-color (:rgb 11 22 33)
                   :border-bottom-color (:hsl 120 100 50)
                   :border-left-color :yellow))))
    (is (char= #\═ (buffer-cell-char (%cell buffer 1 4))))
    (is (char= #\║ (buffer-cell-char (%cell buffer 3 7))))
    (is (eq :red (terminal-color-simple (%fg buffer 1 4))))
    (is (equal '(11 22 33) (%color-rgb (%fg buffer 3 7))))
    (is (equal '(0 255 0) (%color-rgb (%fg buffer 5 4))))
    (is (eq :yellow (terminal-color-simple (%fg buffer 3 1))))
    (is (eq :red (terminal-color-simple (%fg buffer 1 1))))
    (is (equal '(0 255 0) (%color-rgb (%fg buffer 5 1))))
    (is (eq :white (terminal-color-simple
                    (%fg (%paint-box '(:border t :border-color :white))
                         1 1))))))

(test advertised-border-style-variants-produce-distinct-glyphs
  "Solid, dashed, dotted, ASCII and double are not silent aliases."
  (dolist (fixture '((:solid #\─ #\│ #\┌)
                     (:dashed #\┄ #\┆ #\┌)
                     (:dotted #\┈ #\┊ #\┌)
                     (:ascii #\- #\| #\+)
                     (:double #\═ #\║ #\╔)))
    (destructuring-bind (style h v corner) fixture
      (let ((buffer (%paint-box (list :border t :border-style style
                                      :border-color :cyan))))
        (is (char= h (buffer-cell-char (%cell buffer 1 4))))
        (is (char= v (buffer-cell-char (%cell buffer 3 1))))
        (is (char= corner (buffer-cell-char (%cell buffer 1 1))))
        (is (eq :cyan (terminal-color-simple (%fg buffer 1 4)))))))
  (let ((buffer (%paint-box
                 '(:border t :border-style :none :bg-color :green))))
    (is (char= #\Space (buffer-cell-char (%cell buffer 1 1))))
    (is (eq :green (terminal-color-simple (%bg buffer 1 1))))))

(test independently-configured-border-side-styles
  "Every side-specific style affects the actual glyph; NONE suppresses its edge."
  (let ((buffer (%paint-box
                 '(:border t :border-style :solid :border-color :white
                   :border-top-style :dashed :border-top-color :red
                   :border-right-style :dotted :border-right-color :green
                   :border-bottom-style :double :border-bottom-color :blue
                   :border-left-style :none))))
    (is (char= #\┄ (buffer-cell-char (%cell buffer 1 4))))
    (is (char= #\┊ (buffer-cell-char (%cell buffer 3 7))))
    (is (char= #\═ (buffer-cell-char (%cell buffer 5 4))))
    (is (char= #\Space (buffer-cell-char (%cell buffer 3 1))))
    (is (char= #\┄ (buffer-cell-char (%cell buffer 1 1))))
    (is (char= #\═ (buffer-cell-char (%cell buffer 5 1))))
    (is (eq :red (terminal-color-simple (%fg buffer 1 1))))
    (is (eq :green (terminal-color-simple (%fg buffer 3 7))))
    (is (eq :blue (terminal-color-simple (%fg buffer 5 1))))))

(test side-border-absent-edges-do-not-leave-phantom-corners
  (let ((buffer (%paint-box
                 '(:border t :border-style :solid :border-color :magenta
                   :border-top-style :none :border-bottom-style :none
                   :border-right-style :none :border-left-style :dotted))))
    (is (char= #\┊ (buffer-cell-char (%cell buffer 1 1))))
    (is (char= #\┊ (buffer-cell-char (%cell buffer 3 1))))
    (is (char= #\┊ (buffer-cell-char (%cell buffer 5 1))))
    (is (char= #\Space (buffer-cell-char (%cell buffer 1 4))))
    (is (char= #\Space (buffer-cell-char (%cell buffer 1 7))))
    (is (char= #\Space (buffer-cell-char (%cell buffer 5 7))))))

(test side-border-style-can-override-a-globally-disabled-border
  (let ((buffer (%paint-box
                 '(:border t :border-style :none
                   :border-top-style :dashed :border-color :cyan))))
    (is (char= #\┄ (buffer-cell-char (%cell buffer 1 4))))
    (is (char= #\Space (buffer-cell-char (%cell buffer 3 1))))
    (is (char= #\Space (buffer-cell-char (%cell buffer 5 4))))
    (is (eq :cyan (terminal-color-simple (%fg buffer 1 4))))))

(test opacity-zero-skips-subtree-and-intermediate-opacity-uses-faint
  "A TUI has no alpha channel: 0 hides, 0<value<1 produces inherited SGR faint."
  (let* ((buffer (make-virtual-buffer 6 2))
         (hidden (make-instance 'text-element :content "HIDE"
                                :style '(:opacity 0 :fg-color :red)))
         (dimmed (make-instance 'container-element
                                :style '(:opacity 0.5)
                                :children (list
                                           (make-instance 'text-element
                                             :content "OK"
                                             :style '(:fg-color :green))))))
    (setf (elmtui.view.element:el/layout-rect hidden) (%rect 0 0 4 1)
          (elmtui.view.element:el/layout-rect dimmed) (%rect 0 1 4 1)
          (elmtui.view.element:el/layout-rect
           (first (elmtui.view.element:el/children dimmed))) (%rect 0 1 2 1))
    (render-laid-out-tree-to-buffer (list hidden dimmed) :buffer buffer)
    (is (char= #\Space (buffer-cell-char (%cell buffer 0 0))))
    (is (char= #\O (buffer-cell-char (%cell buffer 1 0))))
    (is (elmtui.platform.backend.common.ansi-styling:terminal-style-faint
         (buffer-cell-style (%cell buffer 1 0))))))

(test sibling-z-index-is-sorted-but-equal-values-are-stable
  (let* ((buffer (make-virtual-buffer 2 1))
         (low (make-instance 'text-element :content "L"
                             :style '(:z-index -2)))
         (high (make-instance 'text-element :content "H"
                              :style '(:z-index 5)))
         (same (make-instance 'text-element :content "S"
                              :style '(:z-index 5)))
         (parent (make-instance 'container-element
                                :children (list high low same))))
    (dolist (node (list parent high low same))
      (setf (elmtui.view.element:el/layout-rect node) (%rect 0 0 1 1)))
    (render-laid-out-tree-to-buffer parent :buffer buffer)
    (is (char= #\S (buffer-cell-char (%cell buffer 0 0))))
    (setf (elmtui.view.element:el/children parent) (list same low high))
    (render-laid-out-tree-to-buffer parent :buffer buffer)
    (is (char= #\H (buffer-cell-char (%cell buffer 0 0))))))

(test text-sgr-flags-and-hsl-color-survive-the-renderer
  (let ((buffer (make-virtual-buffer 7 2))
        (node (make-instance
               'text-element :content "TEXT"
               :style '(:fg-color (:hsl 240 100 50) :bg-color "#102030"
                        :attributes (:bold :underline :inverse :faint :strike)))))
    (setf (elmtui.view.element:el/layout-rect node)
          (%rect 1 0 4 1))
    (render-laid-out-tree-to-buffer node :buffer buffer)
    (let ((style (buffer-cell-style (%cell buffer 0 1))))
      (is (char= #\T (buffer-cell-char (%cell buffer 0 1))))
      (is (equal '(0 0 255) (%color-rgb (terminal-style-fg-color style))))
      (is (equal '(16 32 48) (%color-rgb (terminal-style-bg-color style))))
      (is (terminal-style-bold style))
      (is (terminal-style-underline style))
      (is (terminal-style-inverse style))
      (is (terminal-style-faint style))
      (is (terminal-style-strike style)))))

(test border-color-does-not-leak-into-child-foreground
  "Separate text foreground remains unchanged after painting a colored border."
  (let* ((buffer (make-virtual-buffer 9 5))
         (child (make-instance 'text-element
                               :content "OK" :style '(:fg-color :white)))
         (parent (make-instance 'container-element
                                :children (list child)
                                :style '(:border t :border-color :magenta
                                         :bg-color :black :fg-color :cyan))))
    (setf (elmtui.view.element:el/layout-rect parent) (%rect 1 0 7 4)
          (elmtui.view.element:el/layout-rect child) (%rect 1 1 2 1))
    (render-laid-out-tree-to-buffer parent :buffer buffer)
    (is (eq :magenta (terminal-color-simple (%fg buffer 0 1))))
    (is (char= #\O (buffer-cell-char (%cell buffer 1 2))))
    (is (eq :white (terminal-color-simple (%fg buffer 1 2))))
    (is (eq :black (terminal-color-simple (%bg buffer 1 2))))))

(test painted-border-color-survives-diff-and-idle-does-no-ops
  "The real diff backend emits border style changes, never writes on idle."
  (let* ((before (make-virtual-buffer 10 8))
         (after (%paint-box '(:border t :border-color :red
                              :bg-color :black :border-style :dashed)))
         (operations (elmtui.render.diff:compute-buffer-diff
                      before after :initial-frame-p nil))
         (red-run (find-if
                   (lambda (op)
                     (let* ((style (getf op :style))
                            (color (and style (terminal-style-fg-color style))))
                       (and (eq (getf op :type) :write-chars)
                            color
                            (eq :red (terminal-color-simple color)))))
                   operations)))
    (is (not (null red-run)))
    (when red-run
      (is (search (string #\┄) (getf red-run :chars))))
    (is (null (elmtui.render.diff:compute-buffer-diff
               after after :initial-frame-p nil)))))

(test visibility-none-and-overflow-hidden-actually-clip-cells
  (dolist (style '((:display :none :bg-color :red)
                   (:visibility :hidden :bg-color :red)))
    (let ((buffer (%paint-box style)))
      (is (char= #\Space (buffer-cell-char (%cell buffer 1 1))))
      (is (null (%bg buffer 1 1)))))
  (let ((buffer (make-virtual-buffer 8 2))
        (child (make-instance 'text-element
                              :content "WXYZ" :style '(:fg-color :cyan))))
    (let ((parent (make-instance 'container-element
                                 :children (list child)
                                 :style '(:overflow :hidden :padding-left 1
                                          :padding-right 1))))
      (setf (elmtui.view.element:el/layout-rect parent) (%rect 1 0 4 1)
            (elmtui.view.element:el/layout-rect child) (%rect 0 0 4 1))
      (render-laid-out-tree-to-buffer parent :buffer buffer)
      (is (char= #\X (buffer-cell-char (%cell buffer 0 2))))
      (is (char= #\Y (buffer-cell-char (%cell buffer 0 3))))
      (is (char= #\Space (buffer-cell-char (%cell buffer 0 4)))))))

(test later-sibling-must-not-leave-a-half-wide-grapheme
  "Painting onto the trailing cell of a wide sibling invalidates its lead."
  (let* ((buffer (make-virtual-buffer 4 1))
         (wide (make-instance 'text-element :content "界"
                              :style '(:fg-color :cyan)))
         (overlap (make-instance 'text-element :content "X"
                                 :style '(:fg-color :yellow))))
    (setf (elmtui.view.element:el/layout-rect wide) (%rect 0 0 2 1)
          (elmtui.view.element:el/layout-rect overlap) (%rect 1 0 1 1))
    (render-laid-out-tree-to-buffer (list wide overlap) :buffer buffer)
    (is (char= #\Space (buffer-cell-char (%cell buffer 0 0))))
    (is (char= #\X (buffer-cell-char (%cell buffer 0 1))))
    (is (eq :yellow (terminal-color-simple (%fg buffer 0 1))))
    (let ((runs (elmtui.render.diff:compute-buffer-diff
                 nil buffer :initial-frame-p t)))
      (is (notany (lambda (op) (search "界" (getf op :chars))) runs))
      (is (some (lambda (op) (search "X" (getf op :chars))) runs)))))

(test later-sibling-overwriting-wide-lead-clears-continuation
  "Overwriting the lead cell does not strand a non-printing continuation."
  (let* ((buffer (make-virtual-buffer 4 1))
         (wide (make-instance 'text-element :content "界"
                              :style '(:fg-color :cyan)))
         (overlap (make-instance 'text-element :content "X"
                                 :style '(:fg-color :yellow))))
    (setf (elmtui.view.element:el/layout-rect wide) (%rect 0 0 2 1)
          (elmtui.view.element:el/layout-rect overlap) (%rect 0 0 1 1))
    (render-laid-out-tree-to-buffer (list wide overlap) :buffer buffer)
    (is (char= #\X (buffer-cell-char (%cell buffer 0 0))))
    (is (char= #\Space (buffer-cell-char (%cell buffer 0 1))))
    (is (not (null
              (elmtui.render.diff:compute-buffer-diff
               nil buffer :initial-frame-p t))))))

(test incremental-overlay-and-border-cannot-fragment-wide-cell
  "Retained frames and border overlays obey the same two-cell ownership rule."
  (let* ((buffer (make-virtual-buffer 4 2))
         (wide (make-instance 'text-element :content "界"
                              :style '(:fg-color :blue)))
         (text (make-instance 'text-element :content "Z"
                              :style '(:fg-color :green)))
         (border (make-instance 'container-element
                                :style '(:border t :border-style :ascii
                                         :border-color :red))))
    (setf (elmtui.view.element:el/layout-rect wide) (%rect 0 0 2 1)
          (elmtui.view.element:el/layout-rect text) (%rect 1 0 1 1)
          (elmtui.view.element:el/layout-rect border) (%rect 1 0 2 2))
    (render-laid-out-tree-to-buffer wide :buffer buffer)
    (render-laid-out-tree-to-buffer text :buffer buffer :clear-buffer-p nil)
    (is (char= #\Space (buffer-cell-char (%cell buffer 0 0))))
    (is (char= #\Z (buffer-cell-char (%cell buffer 0 1))))
    (render-laid-out-tree-to-buffer wide :buffer buffer :clear-buffer-p nil)
    (render-laid-out-tree-to-buffer border :buffer buffer :clear-buffer-p nil)
    (is (char= #\Space (buffer-cell-char (%cell buffer 0 0))))
    (is (char= #\+ (buffer-cell-char (%cell buffer 0 1))))))

(test overlapping-wide-siblings-erase-the-previous-full-footprint
  "Painting a new wide glyph over the tail of an earlier wide glyph is atomic."
  (let* ((buffer (make-virtual-buffer 4 1))
         (left (make-instance 'text-element :content "界"
                              :style '(:fg-color :red)))
         (right (make-instance 'text-element :content "語"
                               :style '(:fg-color :blue))))
    (setf (elmtui.view.element:el/layout-rect left) (%rect 0 0 2 1)
          (elmtui.view.element:el/layout-rect right) (%rect 1 0 2 1))
    (render-laid-out-tree-to-buffer (list left right) :buffer buffer)
    (is (char= #\Space (buffer-cell-char (%cell buffer 0 0))))
    (is (char= #\語 (buffer-cell-char (%cell buffer 0 1))))
    (is (char= #\Null (buffer-cell-char (%cell buffer 0 2))))
    (is (eq :blue (terminal-color-simple (%fg buffer 0 1))))
    (let* ((ops (elmtui.render.diff:compute-buffer-diff
                 nil buffer :initial-frame-p t))
           (chars (apply #'concatenate 'string
                         (mapcar (lambda (op) (getf op :chars)) ops))))
      (is (search "語" chars))
      (is (not (search "界" chars))))))

(test glyph-partly-outside-parent-clip-is-not-invalidated
  "A clipped child cannot erase the outside half of an existing wide glyph."
  (let* ((buffer (make-virtual-buffer 4 1))
         (wide (make-instance 'text-element :content "界"
                              :style '(:fg-color :cyan)))
         (child (make-instance 'text-element :content "X"
                               :style '(:fg-color :yellow)))
         (parent (make-instance 'container-element
                                :style '(:overflow :hidden :padding-left 1)
                                :children (list child))))
    (setf (elmtui.view.element:el/layout-rect wide) (%rect 0 0 2 1)
          (elmtui.view.element:el/layout-rect parent) (%rect 0 0 2 1)
          (elmtui.view.element:el/layout-rect child) (%rect 1 0 1 1))
    (render-laid-out-tree-to-buffer wide :buffer buffer)
    (render-laid-out-tree-to-buffer parent :buffer buffer
                                    :clear-buffer-p nil)
    (is (char= #\界 (buffer-cell-char (%cell buffer 0 0))))
    (is (char= #\Null (buffer-cell-char (%cell buffer 0 1))))))

(test emoji-presentation-selector-is-invalidated-as-one-wide-glyph
  "An emoji cluster whose first codepoint is narrow owns two physical cells."
  (let* ((buffer (make-virtual-buffer 4 1))
         (emoji (format nil "~C~C" (code-char #x2764) (code-char #xfe0f)))
         (heart (make-instance 'text-element :content emoji
                               :style '(:fg-color :magenta)))
         (text (make-instance 'text-element :content "X"
                              :style '(:fg-color :green))))
    (setf (elmtui.view.element:el/layout-rect heart) (%rect 0 0 2 1)
          (elmtui.view.element:el/layout-rect text) (%rect 1 0 1 1))
    (render-laid-out-tree-to-buffer (list heart text) :buffer buffer)
    (is (char= #\Space (buffer-cell-char (%cell buffer 0 0))))
    (is (char= #\X (buffer-cell-char (%cell buffer 0 1))))
    (is (notany
         (lambda (op) (search emoji (getf op :chars)))
         (elmtui.render.diff:compute-buffer-diff
          nil buffer :initial-frame-p t)))))
