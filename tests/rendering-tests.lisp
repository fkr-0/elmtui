(uiop:define-package :elmtui.tests.platform.rendering
  (:use :cl :fiveam :elmtui.platform.tree-renderer)
  (:import-from :elmtui.view.base-elements
                #:container-element #:text-element
                #:element-layout)
  (:import-from :elmtui.view.geo #:make-rectangle #:make-pos #:make-size)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:make-virtual-buffer
                #:buffer-cell-at
                #:buffer-cell-style
                #:buffer-cell-char)
  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:terminal-style-fg-color
                #:terminal-style-bg-color
                #:terminal-style-bold
                #:terminal-color-simple))

(in-package :elmtui.tests.platform.rendering)

(def-suite rendering-suite :description "Tests for styling and rendering logic.")
(in-suite rendering-suite)

(test render-background-color
  (let* ((buffer (make-virtual-buffer 10 10))
         (node (make-instance 'container-element
                              :style '(:bg-color :red))))
    (setf (elmtui.view.element:el/layout-rect node)
          (make-rectangle :pos (make-pos :x 0 :y 0)
                          :size (make-size :w 5 :h 5)))
    (render-laid-out-tree-to-buffer node :buffer buffer)
    (let* ((cell (buffer-cell-at buffer 0 0))
           (cell-style (buffer-cell-style cell)))
      (is (eq :red (terminal-color-simple (terminal-style-bg-color cell-style)))))))

(test render-text-with-style
  (let* ((buffer (make-virtual-buffer 10 10))
         (node (make-instance 'text-element
                              :content "Hello"
                              :style '(:fg-color :blue :attributes (:bold)))))
    (setf (elmtui.view.element:el/layout-rect node)
          (make-rectangle :pos (make-pos :x 1 :y 1)
                          :size (make-size :w 5 :h 1)))
    (render-laid-out-tree-to-buffer node :buffer buffer)
    (let* ((cell (buffer-cell-at buffer 1 1))
           (cell-style (buffer-cell-style cell)))
      (is (char= #\H (buffer-cell-char cell)))
      (is (eq :blue (terminal-color-simple (terminal-style-fg-color cell-style))))
      (is (eq t (terminal-style-bold cell-style))))))

(test render-border-style
  (let* ((buffer (make-virtual-buffer 10 10))
         (node (make-instance 'container-element
                              :style '(:border-style :solid :border t :fg-color :green))))
    (setf (elmtui.view.element:el/layout-rect node)
          (make-rectangle :pos (make-pos :x 1 :y 1)
                          :size (make-size :w 8 :h 8)))
    (render-laid-out-tree-to-buffer node :buffer buffer)
    (let* ((corner-cell (buffer-cell-at buffer 1 1))
           (corner-style (buffer-cell-style corner-cell)))
      (is (char= #\┌ (buffer-cell-char corner-cell)))
      (is (eq :green (terminal-color-simple (terminal-style-fg-color corner-style)))))))
