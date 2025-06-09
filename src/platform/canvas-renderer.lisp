(uiop:define-package :elmtui.platform.canvas-renderer
  (:use :cl :log4cl)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:set-buffer-cell-at #:buffer-width #:buffer-height)
  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:make-terminal-style #:make-termcolor)
  (:export #:draw-text-on-canvas
           #:draw-rectangle-on-canvas
           #:draw-border-on-canvas
           #:render-ui-tree-to-buffer))
(in-package :elmtui.platform.canvas-renderer)

(defun color->termcolor (col &optional (bg nil))
  "Convert a color spec (keyword, RGB list, or 256-int) into a terminal-color."  ; helper
  (cond
    ((and (listp col) (= (length col) 3)
          (every #'integerp col))
     (destructuring-bind (r g b) col
       (make-termcolor :r r :g g :b b :bg bg)))
    ((integerp col)
     (make-termcolor :color-256 col :bg bg))
    ((keywordp col)
     (make-termcolor :simple col :bg bg))
    (t
     (make-termcolor))))

(defun draw-text-on-canvas (canvas text x y fg-color bg-color &key bold underline inverse)
  "Draw each character of TEXT onto CANVAS at position (X, Y) with terminal-style struct."
  (let* ((max-w (buffer-width canvas))
         (max-h (buffer-height canvas))
         (style (make-terminal-style
                 :fg-color (color->termcolor fg-color)
                 :bg-color (color->termcolor bg-color t)
                 :bold bold
                 :underline underline
                 :inverse inverse))
         (len (length text)))
    (loop for i from 0 below len
          for ch = (char text i)
          for col = (+ x i)
          do (when (and (>= y 0) (< y max-h)
                        (>= col 0) (< col max-w))
               (set-buffer-cell-at canvas y col ch style)))))

(defun draw-rectangle-on-canvas (canvas x y width height color)
  "Fill a WIDTH x HEIGHT rectangle on CANVAS at (X, Y) with background COLOR using terminal-style."
  (let* ((max-w (buffer-width canvas))
         (max-h (buffer-height canvas))
         (style (make-terminal-style
                 :bg-color (color->termcolor color t))))
    (loop for row from y below (+ y height) do
      (when (and (>= row 0) (< row max-h))
        (loop for col from x below (+ x width) do
          (when (and (>= col 0) (< col max-w))
            ;; Use full block to ensure background color is visible
            (set-buffer-cell-at canvas row col #\  ; #\█
                                style)))))))
(defun rect-x (rect)
  "Get the x-coordinate of the rectangle."
  (elmtui.view.geo:x rect))
(defun rect-y (rect)
  "Get the y-coordinate of the rectangle."
  (elmtui.view.geo:y rect))

(defun draw-border-on-canvas (canvas x y width height color style thickness)
  "Draw a solid border of STYLE and THICKNESS around the WIDTH x HEIGHT rectangle at (X, Y) on CANVAS using terminal-style."
  (declare (ignorable style)) ; only solid implemented
  (let* ((max-w (buffer-width canvas))
         (max-h (buffer-height canvas))
         (fg-style (make-terminal-style
                    :fg-color (make-termcolor :simple color))))
    (loop for layer from 0 below thickness do
      (let ((top (+ y layer))
            (bottom (- (+ y height -1) layer))
            (left (+ x layer))
            (right (- (+ x width -1) layer)))
        ;; horizontal lines
        (loop for col from left to right do
          (when (and (>= top 0) (< top max-h)
                     (>= col 0) (< col max-w))
            (set-buffer-cell-at canvas top col #\- fg-style))
          (when (and (>= bottom 0) (< bottom max-h)
                     (>= col 0) (< col max-w))
            (set-buffer-cell-at canvas bottom col #\- fg-style)))
        ;; vertical lines
        (loop for row from top to bottom do
          (when (and (>= row 0) (< row max-h)
                     (>= left 0) (< left max-w))
            (set-buffer-cell-at canvas row left #\| fg-style))
          (when (and (>= row 0) (< row max-h)
                     (>= right 0) (< right max-w))
            (set-buffer-cell-at canvas row right #\| fg-style)))
        ;; corners
        (dolist (pt (list (cons left top)
                          (cons right top)
                          (cons left bottom)
                          (cons right bottom)))
          (let ((row (cdr pt)) (col (car pt)))
            (when (and (>= row 0) (< row max-h)
                       (>= col 0) (< col max-w))
              (set-buffer-cell-at canvas row col #\+ fg-style))))))))

(defun render-ui-tree-to-buffer (ui-node target-buffer)
  "Renders a UI-NODE tree to the TARGET-BUFFER (e.g., a canvas).
This function will be responsible for translating the styled and laid-out UI tree
into drawing operations on the target buffer."
  (when ui-node
    (let* ((layout-box (getf (elmtui.view.core:ui-node-props ui-node) :layout-rect)))
      (when layout-box
        ;; Phase 1: Box Model Elements (Backgrounds & Borders)
        ;; Render Background
        (let ((bg-color (style-value ui-node :background-color)))
          (when bg-color
            (draw-rectangle-on-canvas target-buffer
                                      (elmtui.view.geo:x layout-box)
                                      (elmtui.view.geo:y layout-box)
                                      (elmtui.view.geo:w layout-box)
                                      (elmtui.view.geo:h layout-box)
                                      bg-color)))

        ;; Render Borders (simplified: assumes solid border if color is present)
        ;; TODO: Handle different border styles and individual border sides
        (let* ((border-color (style-value ui-node :border-color))
               (border-style (style-value ui-node :border-style :none))
               (border-width (style-value ui-node :border-width 1)))
          (when (and border-color (not (eq border-style :none)))
            (draw-border-on-canvas target-buffer
                                   (elmtui.view.geo:x layout-box)
                                   (elmtui.view.geo:y layout-box)
                                   (elmtui.view.geo:w layout-box)
                                   (elmtui.view.geo:h layout-box)
                                   border-color
                                   border-style
                                   border-width)))

        ;; Phase 1: Text Elements
        (let ((content (getf (elmtui.view.core:ui-node-props ui-node) :content)))
          (when (stringp content)
            (let* ((fg-color (or (style-value ui-node :color) :black))
                   (text-bg (or (style-value ui-node :text-background-color)
                                (style-value ui-node :background-color :white)))
                   (bold (style-value ui-node :bold nil))
                   (underline (style-value ui-node :underline nil))
                   (inverse (style-value ui-node :inverse nil)))
              ;; draw-text-on-canvas now can inspect style flags in its implementation
              (draw-text-on-canvas target-buffer
                                   content
                                   (elmtui.view.geo:x layout-box)
                                   (elmtui.view.geo:y layout-box)
                                   fg-color
                                   text-bg
                                   :bold bold
                                   :underline underline
                                   :inverse inverse)))))) ; Fallback for text BG

    ;; Recursively render children
    ;; Phase 2: Z-index ordering of children
    (let ((children (sort (copy-list (elmtui.view.core:ui-node-children ui-node)) #'<
                          :key (lambda (c) (or (style-value c :z-index 0) 0)))) )
      (dolist (child children)
        (render-ui-tree-to-buffer child target-buffer)))
    nil ;;; Return nil to indicate successful rendering without errors)
    ))
