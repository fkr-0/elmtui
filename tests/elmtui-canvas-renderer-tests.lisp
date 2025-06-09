(uiop:define-package :elmtui.tests.canvas-render
  (:use :cl :fiveam :alexandria)
  (:import-from :elmtui.view.geo
                #:rectangle
                #:make-rectangle
                #:pos
                #:make-pos
                #:size
                #:make-size
                #:w
                #:h
                #:x
                #:y)
  (:import-from :elmtui.platform.canvas
                #:canvas
                #:make-canvas
                #:canvas-buffer
                #:canvas-backend
                #:canvas-position-strategy
                #:canvas-anchor-point
                #:canvas-content-rectangle
                #:initialize-canvas
                #:update-canvas-size
                #:apply-canvas-to-buffer
                #:prepare-canvas-for-rendering
                #:finalize-canvas-after-rendering
                #:restore-terminal-state)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer
                #:make-virtual-buffer
                #:with-virtual-buffer-lock
                #:buffer-cell-at
                #:buffer-cell-char
                #:buffer-cell-style
                #:set-buffer-cell-at
                #:buffer-width
                #:buffer-height))
(in-package :elmtui.tests.canvas-render)

(def-suite elmtui-canvas-renderer-tests
  :description "Tests for the canvas rendering system."
  ;; :in elmtui-tests ; This was commented out, ensure your test runner picks it up or uncomment if needed.
  )

(in-suite elmtui-canvas-renderer-tests)

;; Import renderer functions for direct testing
(:import-from :elmtui.platform.canvas-renderer
              #:draw-text-on-canvas
              #:draw-rectangle-on-canvas
              #:draw-border-on-canvas)

(test render-text-element
  (let* ((text-node (elmtui.view.core:make-ui-node
                     :content "Hello"
                     :style (elmtui.style.core:parse-styles '(:color :red :text-background-color :blue)) ; Using text-background-color
                     :layout-box (elmtui.view.geo:make-rectangle :x 10 :y 5 :width 5 :height 1)))
         (mock-canvas (gensym "mock-canvas-")))
    (let ((output (with-output-to-string (*standard-output*)
                    (elmtui.platform.canvas-renderer:render-ui-tree-to-buffer text-node mock-canvas))))
      (is (str:containsp "Drawing text 'Hello' at (10, 5) FG: :RED BG: :BLUE" output))
      (is (null (elmtui.platform.canvas-renderer:render-ui-tree-to-buffer nil mock-canvas))))))

(test render-box-model-element
  (let* ((box-node (elmtui.view.core:make-ui-node
                    :style (elmtui.style.core:parse-styles '(:background-color :green
                                                              :border-color :black
                                                              :border-style :solid
                                                              :border-width 2))
                    :layout-box (elmtui.view.geo:make-rectangle :x 1 :y 2 :width 10 :height 5)))
         (mock-canvas (gensym "mock-canvas-")))
    (let ((output (with-output-to-string (*standard-output*)
                    (elmtui.platform.canvas-renderer:render-ui-tree-to-buffer box-node mock-canvas))))
      (is (str:containsp "Drawing rectangle at (1, 2) size (10, 5) Color: :GREEN" output))
      (is (str:containsp "Drawing border at (1, 2) size (10, 5) Color: :BLACK Style: :SOLID Thickness: 2" output)))))

(test render-box-with-text-inside
  (let* ((parent-node (elmtui.view.core:make-ui-node
                       :style (elmtui.style.core:parse-styles '(:background-color :yellow :border-color :magenta))
                       :layout-box (elmtui.view.geo:make-rectangle :x 0 :y 0 :width 20 :height 3)))
         (text-child (elmtui.view.core:make-ui-node
                      :content "Child Text"
                      :style (elmtui.style.core:parse-styles '(:color :blue)) ; Text BG will fallback to parent's BG
                      :layout-box (elmtui.view.geo:make-rectangle :x 1 :y 1 :width 18 :height 1)))
         (mock-canvas (gensym "mock-canvas-")))
    (push text-child (elmtui.view.core:ui-node-children parent-node))
    (let ((output (with-output-to-string (*standard-output*)
                    (elmtui.platform.canvas-renderer:render-ui-tree-to-buffer parent-node mock-canvas))))
      (is (str:containsp "Drawing rectangle at (0, 0) size (20, 3) Color: :YELLOW" output))
      (is (str:containsp "Drawing border at (0, 0) size (20, 3) Color: :MAGENTA Style: :SOLID Thickness: 1" output)) ; Default thickness
      (is (str:containsp "Drawing text 'Child Text' at (1, 1) FG: :BLUE BG: :YELLOW" output)))))

(test draw-text-on-canvas-direct
  (let* ((buf (make-virtual-buffer 10 2)))
    (draw-text-on-canvas buf "AB" 2 1 :green :black)
    ;; Verify characters and style at positions
    (let ((cellA (buffer-cell-at buf 1 2))
          (cellB (buffer-cell-at buf 1 3)))
      (is (char= (buffer-cell-char cellA) #\A))
      (is (char= (buffer-cell-char cellB) #\B))
      (is (typep (buffer-cell-style cellA) 'elmtui.platform.backend.common.ansi-styling:terminal-style))
      (is (typep (buffer-cell-style cellB) 'elmtui.platform.backend.common.ansi-styling:terminal-style))
      (is (equal (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color (buffer-cell-style cellA))
                 (elmtui.platform.backend.common.ansi-styling:make-termcolor :simple :green)))
      (is (equal (elmtui.platform.backend.common.ansi-styling:terminal-style-bg-color (buffer-cell-style cellA))
                 (elmtui.platform.backend.common.ansi-styling:make-termcolor :simple :black)))))

(test draw-rectangle-on-canvas-direct
  (let* ((buf (make-virtual-buffer 5 5)))
    (draw-rectangle-on-canvas buf 1 1 3 2 :blue)
    ;; Cells in rectangle should be spaces with bg-color :blue
    (loop for row from 1 below 3 do
          (loop for col from 1 below 4 do
            (let ((cell (buffer-cell-at buf row col)))
              (is (char= (buffer-cell-char cell) #\Space))
              (is (typep (buffer-cell-style cell) 'elmtui.platform.backend.common.ansi-styling:terminal-style))
              (is (equal (elmtui.platform.backend.common.ansi-styling:terminal-style-bg-color (buffer-cell-style cell))
                         (elmtui.platform.backend.common.ansi-styling:make-termcolor :simple :blue)))))))

(test draw-border-on-canvas-direct
  (let* ((buf (make-virtual-buffer 6 4)))
    (draw-border-on-canvas buf 1 1 4 3 :red :solid 1)
    ;; Check top border
    (loop for col from 1 below 5 do
      (let ((cell (buffer-cell-at buf 1 col)))
        (is (char= (buffer-cell-char cell) #\-))
        (is (typep (buffer-cell-style cell) 'elmtui.platform.backend.common.ansi-styling:terminal-style))
        (is (equal (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color (buffer-cell-style cell))
                   (elmtui.platform.backend.common.ansi-styling:make-termcolor :simple :red)))))
    ;; Check bottom border
    (loop for col from 1 below 5 do
      (let ((cell (buffer-cell-at buf 3 col)))
        (is (char= (buffer-cell-char cell) #\-))
        (is (typep (buffer-cell-style cell) 'elmtui.platform.backend.common.ansi-styling:terminal-style))
        (is (equal (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color (buffer-cell-style cell))
                   (elmtui.platform.backend.common.ansi-styling:make-termcolor :simple :red)))))
    ;; Check left border
    (loop for row from 1 below 4 do
      (let ((cell (buffer-cell-at buf row 1)))
        (is (char= (buffer-cell-char cell) #\|))
        (is (typep (buffer-cell-style cell) 'elmtui.platform.backend.common.ansi-styling:terminal-style))
        (is (equal (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color (buffer-cell-style cell))
                   (elmtui.platform.backend.common.ansi-styling:make-termcolor :simple :red)))))
    ;; Check corner
    (let ((cell (buffer-cell-at buf 1 1)))
      (is (char= (buffer-cell-char cell) #\+))
      (is (typep (buffer-cell-style cell) 'elmtui.platform.backend.common.ansi-styling:terminal-style))
      (is (equal (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color (buffer-cell-style cell))
                 (elmtui.platform.backend.common.ansi-styling:make-termcolor :simple :red))))))
