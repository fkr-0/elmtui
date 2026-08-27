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

(test descendant-overflow-visible-by-default
  "Descendants retain historical visible overflow when :overflow is absent."
  (let* ((buffer (make-virtual-buffer 6 2))
         (child (make-instance 'text-element
                               :content "XYZ"
                               :style '(:fg-color :white)))
         (parent (make-instance 'container-element :children (list child))))
    (setf (elmtui.view.element:el/layout-rect parent)
          (make-rectangle :pos (make-pos :x 0 :y 0)
                          :size (make-size :w 3 :h 1)))
    (setf (elmtui.view.element:el/layout-rect child)
          (make-rectangle :pos (make-pos :x 2 :y 0)
                          :size (make-size :w 3 :h 1)))
    (render-laid-out-tree-to-buffer parent :buffer buffer)
    (is (char= #\X (buffer-cell-char (buffer-cell-at buffer 0 2))))
    (is (char= #\Y (buffer-cell-char (buffer-cell-at buffer 0 3))))
    (is (char= #\Z (buffer-cell-char (buffer-cell-at buffer 0 4))))))

(test hidden-overflow-clips-descendants-to-parent-content
  "Parent content clipping composes with each child's own content bounds."
  (let* ((buffer (make-virtual-buffer 5 2))
         (child (make-instance 'text-element
                               :content "ABC"
                               :style '(:fg-color :white)))
         (parent (make-instance 'container-element
                                :style '(:overflow :hidden
                                         :padding-left 1
                                         :padding-right 1)
                                :children (list child))))
    (setf (elmtui.view.element:el/layout-rect parent)
          (make-rectangle :pos (make-pos :x 0 :y 0)
                          :size (make-size :w 4 :h 1)))
    (setf (elmtui.view.element:el/layout-rect child)
          (make-rectangle :pos (make-pos :x 0 :y 0)
                          :size (make-size :w 2 :h 1)))
    (render-laid-out-tree-to-buffer parent :buffer buffer)
    (is (char= #\Space (buffer-cell-char (buffer-cell-at buffer 0 0))))
    (is (char= #\B (buffer-cell-char (buffer-cell-at buffer 0 1))))
    (is (char= #\Space (buffer-cell-char (buffer-cell-at buffer 0 2))))))

(test nested-hidden-overflow-intersects-ancestor-clips
  "Nested hidden-overflow ancestors intersect their absolute content clips."
  (let* ((buffer (make-virtual-buffer 7 2))
         (grandchild (make-instance 'text-element
                                    :content "WXYZ"
                                    :style '(:fg-color :white)))
         (child (make-instance 'container-element
                               :style '(:overflow :hidden)
                               :children (list grandchild)))
         (parent (make-instance 'container-element
                                :style '(:overflow :hidden)
                                :children (list child))))
    (setf (elmtui.view.element:el/layout-rect parent)
          (make-rectangle :pos (make-pos :x 0 :y 0)
                          :size (make-size :w 4 :h 1)))
    (setf (elmtui.view.element:el/layout-rect child)
          (make-rectangle :pos (make-pos :x 2 :y 0)
                          :size (make-size :w 4 :h 1)))
    (setf (elmtui.view.element:el/layout-rect grandchild)
          (make-rectangle :pos (make-pos :x 0 :y 0)
                          :size (make-size :w 4 :h 1)))
    (render-laid-out-tree-to-buffer parent :buffer buffer)
    (is (char= #\W (buffer-cell-char (buffer-cell-at buffer 0 2))))
    (is (char= #\X (buffer-cell-char (buffer-cell-at buffer 0 3))))
    (is (char= #\Space (buffer-cell-char (buffer-cell-at buffer 0 4))))
    (is (char= #\Space (buffer-cell-char (buffer-cell-at buffer 0 5))))))

(test overlapping-siblings-use-source-order-not-z-index
  "Later lowered siblings paint over earlier siblings; :z-index is not interpreted."
  (let* ((buffer (make-virtual-buffer 3 1))
         (first (make-instance 'text-element
                               :content "A"
                               :style '(:fg-color :red :z-index 100)))
         (second (make-instance 'text-element
                                :content "B"
                                :style '(:fg-color :blue :z-index -100)))
         (parent (make-instance 'container-element
                                :children (list first second))))
    (setf (elmtui.view.element:el/layout-rect parent)
          (make-rectangle :pos (make-pos :x 0 :y 0)
                          :size (make-size :w 3 :h 1)))
    (setf (elmtui.view.element:el/layout-rect first)
          (make-rectangle :pos (make-pos :x 1 :y 0)
                          :size (make-size :w 1 :h 1)))
    (setf (elmtui.view.element:el/layout-rect second)
          (make-rectangle :pos (make-pos :x 1 :y 0)
                          :size (make-size :w 1 :h 1)))
    (render-laid-out-tree-to-buffer parent :buffer buffer)
    (let* ((cell (buffer-cell-at buffer 0 1))
           (style (buffer-cell-style cell)))
      (is (char= #\B (buffer-cell-char cell)))
      (is (eq :blue (terminal-color-simple (terminal-style-fg-color style)))))))

(test image-element-renders-alt-text-on-terminal
  "Terminal image elements render ALT text instead of silently disappearing."
  (let* ((buffer (make-virtual-buffer 5 1))
         (node (elmtui.view.base-elements:dsl->objects
                '(:image :src "asset.png" :alt "ALT"
                         :style (:fg-color :cyan)))))
    (setf (elmtui.view.element:el/layout-rect node)
          (make-rectangle :pos (make-pos :x 1 :y 0)
                          :size (make-size :w 3 :h 1)))
    (render-laid-out-tree-to-buffer node :buffer buffer)
    (is (char= #\A (buffer-cell-char (buffer-cell-at buffer 0 1))))
    (is (char= #\L (buffer-cell-char (buffer-cell-at buffer 0 2))))
    (is (char= #\T (buffer-cell-char (buffer-cell-at buffer 0 3))))))

(test image-element-with-empty-alt-renders-visible-placeholder
  "An image without ALT text still has a visible terminal fallback."
  (let* ((buffer (make-virtual-buffer 9 1))
         (node (elmtui.view.base-elements:dsl->objects
                '(:image :src "asset.png" :alt ""
                         :style (:fg-color :yellow)))))
    (setf (elmtui.view.element:el/layout-rect node)
          (make-rectangle :pos (make-pos :x 1 :y 0)
                          :size (make-size :w 7 :h 1)))
    (render-laid-out-tree-to-buffer node :buffer buffer)
    (is (string= "[image]"
                 (coerce
                  (loop for col from 1 below 8
                        collect (buffer-cell-char (buffer-cell-at buffer 0 col)))
                  'string)))))
