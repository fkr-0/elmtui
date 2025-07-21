(uiop:define-package :elmtui.tests.tree-renderer-tests
  (:use :cl :fiveam :alexandria)
  (:import-from :elmtui.view.core #:ui-node-type #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.view.geo
                #:make-pos #:make-size
                #:make-rectangle #:rect-x #:rect-y #:rect-width #:rect-height)
  (:import-from :elmtui.view.styled #:make-styled-node #:styled-node-type #:styled-node-props #:styled-node-children #:styled-node-style-set #:style-value)
  (:import-from :elmtui.style-lib.api #:style-set) ; Keep style-set if tests inspect (styles node)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:clear-buffer
                #:make-virtual-buffer #:buffer-char #:buffer-style #:buffer-width #:buffer-height)
  (:import-from :elmtui.platform.backend.common.ansi-styling ; Correct source for these
                #:terminal-style-fg-color-val #:terminal-style-bg-color-val
                #:terminal-style-fg-color #:terminal-style-bg-color #:make-termcolor #:termcolor-simple)
  (:import-from :elmtui.platform.tree-renderer #:render-laid-out-tree-to-canvas #:get-border-characters))
(in-package :elmtui.tests.tree-renderer-tests)

(def-suite elmtui.tests.tree-renderer
  :description "Tests for the tree renderer using the new style system.")

(in-suite elmtui.tests.tree-renderer)

(defun setup-test-canvas (&optional (width 20) (height 10))
  (let ((buffer (make-virtual-buffer width height)))
    ;; Initialize buffer with spaces (make-virtual-buffer should do this by default)
    (clear-buffer buffer) ; Ensure the buffer is clean
    buffer))

(defun canvas-buffer (canvas)
  canvas)

(defun make-test-styled-node (type props children style-plist &optional (id "test-node"))
  (make-styled-node
   :type type
   ;; Pass the style-plist under the :style key within :props
   :props (list* :id id :style style-plist props)
   :children children))

(test basic-text-rendering
  (let* ((canvas (setup-test-canvas 10 5))
         (node (make-test-styled-node
                :text ; This should ideally be :drawable-content or a similar atomic type
                (list :text "Hello" :layout-rect (make-rectangle :pos (make-pos :x 1 :y 1 ) :size (make-size :w 5 :h 1)))
                nil
                (list :color :red))))
    (render-laid-out-tree-to-canvas node canvas)
    (let ((buffer (canvas-buffer canvas)))
      (is (char= (buffer-char buffer 1 1) #\H))
      (is (char= (buffer-char buffer 1 2) #\e))
      (is (char= (buffer-char buffer 1 3) #\l))
      (is (char= (buffer-char buffer 1 4) #\l))
      (is (char= (buffer-char buffer 1 5) #\o))
      (let ((style (buffer-style buffer 1 1)))
        (is-true style "Style object should not be NIL for basic text")
        (when style
          (is (eq :red (terminal-style-fg-color-val style)))))))) ; Changed to -val

(test background-color-rendering
  (let* ((canvas (setup-test-canvas 5 5))
         (node (make-test-styled-node
                :box ; Represents a generic block-level element for styling
                (list :layout-rect (make-rectangle :pos (make-pos :x 0 :y 0 ) :size (make-size :w 2 :h 2)))
                nil
                (list :background-color :blue))))
    (render-laid-out-tree-to-canvas node canvas)
    (let ((buffer (canvas-buffer canvas)))
      (loop for r from 0 to 1
            do (loop for c from 0 to 1
                     do
                        (is (char= (buffer-char buffer r c) #\Space)) ; Background sets char to space
                        (let ((style (buffer-style buffer r c)))
                          (is-true style (format nil "Style object at (~a,~a) should not be NIL" r c))
                          (when style
                            (is (eq :blue (terminal-style-bg-color-val style)))))))))) ; Changed to -val

(test simple-border-rendering
  (let* ((canvas (setup-test-canvas 5 5))
         (border-chars (get-border-characters :solid))
         (node (make-test-styled-node
                :box
                (list :layout-rect (make-rectangle :pos (make-pos :x 1 :y 1 ) :size (make-size :w 3 :h 3)))
                nil
                (list :border-style :solid :border-color  :green))))
    (render-laid-out-tree-to-canvas node canvas)
    (let ((buffer (canvas-buffer canvas)))
      ;; Corners
      (is (char= (buffer-char buffer 1 1) (getf border-chars :tl)))
      (is (char= (buffer-char buffer 1 3) (getf border-chars :tr)))
      (is (char= (buffer-char buffer 3 1) (getf border-chars :bl)))
      (is (char= (buffer-char buffer 3 3) (getf border-chars :br)))
      ;; Sides
      (is (char= (buffer-char buffer 1 2) (getf border-chars :h)))
      (is (char= (buffer-char buffer 3 2) (getf border-chars :h)))
      (is (char= (buffer-char buffer 2 1) (getf border-chars :v)))
      (is (char= (buffer-char buffer 2 3) (getf border-chars :v)))
      ;; Color
      (let ((style (buffer-style buffer 1 1)))
        (is-true style "Style object for border should not be NIL")
        (when style
          (is (eq :green (terminal-style-fg-color-val style)))))))) ; Changed to -val

(test ascii-border-rendering
  (let* ((canvas (setup-test-canvas 5 5))
         (border-chars (get-border-characters :ascii))
         (node (make-test-styled-node
                :box
                (list :layout-rect (make-rectangle :pos (make-pos :x 1 :y 1 ) :size (make-size :w 3 :h 3)))
                nil
                (list :border-style :ascii :border-color  :yellow))))
    (render-laid-out-tree-to-canvas node canvas)
    (let ((buffer (canvas-buffer canvas)))
      (is (char= (buffer-char buffer 1 1) (getf border-chars :tl))) 
      (is (char= (buffer-char buffer 1 2) (getf border-chars :h)))  
      (let ((style (buffer-style buffer 1 1)))
        (is-true style "Style object for ASCII border should not be NIL")
        (when style
          (is (eq :yellow (terminal-style-fg-color-val style)))))))) ; Changed to -val

(test text-wrapping-in-content-box
  (let* ((canvas (setup-test-canvas 10 5))
         (node (make-test-styled-node
                :drawable-content ; Use :drawable-content for text
                (list :text "abcdefghi"
                      :layout-rect (make-rectangle :pos (make-pos :x 1 :y 1 ) :size (make-size :w 7 :h 5))) ; border-box
                nil
                (list :border-style :solid :border-width 1 :padding 1 :color :black)))) ; Used :color
    (render-laid-out-tree-to-canvas node canvas)
    (let ((buffer (canvas-buffer canvas)))
      ;; Content box: x=1(node)+1(border)+1(pad)=3, y=1(node)+1(border)+1(pad)=3
      ;; width = 7 - 2(border) - 2(pad) = 3
      ;; height = 5 - 2(border) - 2(pad) = 1
      (is (char= (buffer-char buffer 3 3) #\a))
      (is (char= (buffer-char buffer 3 4) #\b))
      (is (char= (buffer-char buffer 3 5) #\c))
      (is (not (char= (buffer-char buffer 3 6) #\d))) 
      (is (not (char= (buffer-char buffer 4 3) #\d)))
      (let ((style (buffer-style buffer 3 3))) ; Check color of 'a'
        (is-true style "Style object for wrapped text should not be NIL")
        (when style
          (is (eq :black (terminal-style-fg-color-val style)))))))) ; Added check with -val

(test nested-nodes-background-clipping
  (let* ((canvas (setup-test-canvas 5 5))
         (parent-node (make-test-styled-node
                       :box
                       (list :layout-rect
                             (make-rectangle :pos (make-pos :x 0 :y 0 ) :size (make-size :w 5 :h 5)))
                       (list
                        (make-test-styled-node
                         :box
                         (list :layout-rect
                               (make-rectangle :pos (make-pos :x 1 :y 1 ) :size (make-size :w 3 :h 3)))
                         nil
                         (list :background-color  :red)
                         "child"))
                       (list :background-color  :blue) "parent")))
    (render-laid-out-tree-to-canvas parent-node canvas)
    (let ((buffer (canvas-buffer canvas)))
      (flet ((check-bg (r c expected-color)
               (let ((style (buffer-style buffer r c)))
                 (is-true style (format nil "Style object at (~a,~a) should not be NIL" r c))
                 (when style
                   (is (eq expected-color (terminal-style-bg-color-val style))))))) ; Changed to -val
        (check-bg 0 0 :blue)
        (check-bg 1 1 :red)
        (check-bg 2 2 :red)
        (check-bg 0 4 :blue)
        (check-bg 4 0 :blue)
        (check-bg 4 4 :blue)))))

(test border-over-parent-background
  (let* ((canvas (setup-test-canvas 5 5))
         (parent-node (make-test-styled-node
                       :box
                       (list :layout-rect (make-rectangle :pos (make-pos :x 0 :y 0 ) :size (make-size :w 5 :h 5)))
                       (list
                        (make-test-styled-node
                         :box
                         (list :layout-rect (make-rectangle :pos (make-pos :x 1 :y 1 ) :size (make-size :w 3 :h 3)))
                         nil
                         (list :border-style :solid :border-color  :green :background-color  :red)
                         "child"))
                       (list :background-color  :blue)
                       "parent")))
    (render-laid-out-tree-to-canvas parent-node canvas)
    (let ((buffer (canvas-buffer canvas)))
      (let ((cell-style (buffer-style buffer 1 1)))
        (is-true cell-style "Style object for border cell should not be NIL")
        (when cell-style
          (is (char= (buffer-char buffer 1 1) (getf (get-border-characters :solid) :tl)))
          (is (eq :green (terminal-style-fg-color-val cell-style))) ; Changed to -val
          (is (eq :blue (terminal-style-bg-color-val cell-style)))))))) ; Changed to -val

(test content-over-own-background
  (let* ((canvas (setup-test-canvas 5 5))
         (node (make-test-styled-node
                :drawable-content 
                (list :text "Hi" :layout-rect (make-rectangle :pos (make-pos :x 1 :y 1 ) :size (make-size :w 3 :h 1)))
                nil
                (list :color  :yellow :background-color  :magenta))))
    (render-laid-out-tree-to-canvas node canvas)
    (let ((buffer (canvas-buffer canvas)))
      (let ((cell-style-H (buffer-style buffer 1 1)))
        (is-true cell-style-H "Style for 'H' should not be NIL")
        (when cell-style-H
          (is (char= (buffer-char buffer 1 1) #\H))
          (is (eq :yellow (terminal-style-fg-color-val cell-style-H))) ; Changed to -val
          (is (eq :magenta (terminal-style-bg-color-val cell-style-H))))) ; Changed to -val
      (let ((cell-style-i (buffer-style buffer 1 2)))
        (is-true cell-style-i "Style for 'i' should not be NIL")
        (when cell-style-i
          (is (char= (buffer-char buffer 1 2) #\i))
          (is (eq :yellow (terminal-style-fg-color-val cell-style-i))) ; Changed to -val
          (is (eq :magenta (terminal-style-bg-color-val cell-style-i)))))))) ; Changed to -val

(test double-border-rendering
  (let* ((canvas (setup-test-canvas 5 5))
         (border-chars (get-border-characters :double))
         (node (make-test-styled-node
                :box
                (list :layout-rect (make-rectangle :pos (make-pos :x 1 :y 1 ) :size (make-size :w 3 :h 3)))
                nil
                (list :border-style :double :border-color  :cyan))))
    (render-laid-out-tree-to-canvas node canvas)
    (let ((buffer (canvas-buffer canvas)))
      (is (char= (buffer-char buffer 1 1) (getf border-chars :tl)) "Double border top-left")
      (is (char= (buffer-char buffer 1 3) (getf border-chars :tr)) "Double border top-right")
      (is (char= (buffer-char buffer 3 1) (getf border-chars :bl)) "Double border bottom-left")
      (is (char= (buffer-char buffer 3 3) (getf border-chars :br)) "Double border bottom-right")
      (is (char= (buffer-char buffer 1 2) (getf border-chars :h)) "Double border horizontal")
      (is (char= (buffer-char buffer 2 1) (getf border-chars :v)) "Double border vertical")
      (let ((style (buffer-style buffer 1 1)))
        (is-true style "Style for double border should not be NIL")
        (when style
          (is (eq :cyan (terminal-style-fg-color-val style)))))))) ; Changed to -val

(test no-border-rendering
  (let* ((canvas (setup-test-canvas 5 5))
         (node
           (make-test-styled-node
            :drawable-content
            (list :layout-rect
                  (make-rectangle :pos (make-pos :x 1 :y 1 )
                                  :size
                                  (make-size :w 3 :h 3))
                  :text "NB")
            nil
            ;; Using consistent style keys :color and :background-color
            (list :border-style :none :background-color :white :color :black))))
    (render-laid-out-tree-to-canvas node canvas)
    (let ((buffer (canvas-buffer canvas)))
      (is (char= (buffer-char buffer 1 1) #\N)) 
      (let ((style11 (buffer-style buffer 1 1)))
        (is-true style11 "Style at (1,1) should not be NIL")
        (when style11
          (is (eq :white (terminal-style-bg-color-val style11)))
          (is (eq :black (terminal-style-fg-color-val style11)))))

      (is (char= (buffer-char buffer 1 3) #\Space)) 
      (let ((style13 (buffer-style buffer 1 2)))
        (is (not (null style13)) "Style at (1,3) should not be NIL")
        (when style13
          (is (eq :white (terminal-style-bg-color-val style13))))))))
