(uiop:define-package :elmtui.tests.platform.rendering
  (:use :cl :fiveam :elmtui.platform.tree-renderer)
  (:import-from :elmtui.view.core #:make-ui-node)
  (:import-from #:elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.style-lib.api #:new #:style-set)
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

(def-suite rendering-suite :description "Tests for styling and rendering logic."
  )
(in-suite rendering-suite)

(test render-background-color
  (let* ((buffer (make-virtual-buffer 10 10))
         (style (new 'style-set :styles (list  :bg-color :red)))
         (node (make-styled-node
                :type :container
                :styles style
                :props (list :layout-rect
                             (make-rectangle
                              :pos (make-pos :x 0 :y 0)
                              :size (make-size :w 5 :h 5))))))
    (render-laid-out-tree-to-buffer (list node) :buffer buffer)
    (let* ((cell (buffer-cell-at buffer 0 0))
           (cell-style (buffer-cell-style cell)))
      (is (eq :red (terminal-color-simple (terminal-style-bg-color cell-style)))))))

(test render-text-with-style
  (let* ((buffer (make-virtual-buffer 10 10))
         (style (new 'style-set :styles (list  :color :blue :attributes '(:bold))))
         (node (make-styled-node
                :type :text
                :styles style
                :props (list :layout-rect (make-rectangle :pos (make-pos  :x 1 :y 1) :size (make-size  :w 5 :h 1))
                             :text "Hello"))))
    (render-laid-out-tree-to-buffer (list node) :buffer buffer)
    (let* ((cell (buffer-cell-at buffer 1 1))
           (cell-style (buffer-cell-style cell)))
      (is (char= #\H (buffer-cell-char cell)))
      (is (eq :blue (terminal-color-simple (terminal-style-fg-color cell-style))))
      (is (eq t (terminal-style-bold cell-style))))))

(test render-border-style

  ;; (render-laid-out-tree-to-buffer (list node) :buffer buf)
  ;; (is (= expected    (elmtui.dev:buffer->string buf)))))

  (let* ((buffer (make-virtual-buffer 10 10))
         (style (new 'style-set :styles (list  :border-style :solid :border-color :green)))
         (node (make-styled-node
                :type :container
                :styles style
                :props (list :layout-rect (make-rectangle :pos (make-pos  :x 1 :y 1) :size (make-size  :w 8 :h 8))))))
    (elmtui.dev::with-buffer-dump (buffer)
      (render-laid-out-tree-to-buffer (list node) :buffer buffer)
      (let* ((corner-cell (buffer-cell-at buffer 1 1))
             (corner-style (buffer-cell-style corner-cell)))
        (is (char= #\┌ (buffer-cell-char corner-cell)))
        (is (eq :green (terminal-color-simple (terminal-style-fg-color corner-style))))))))
;; (new 'style-set :styles (list :padding 1 :color :red))
;; (test render-inheritance-of-background
;;   (let* ((buffer (make-virtual-buffer 10 10))
;;          (parent-style ((new 'style-set :styles (list  :background-color :yellow))))
;;          (child-style ((new 'style-set :styles (list  :color :black))))
;;          (child-node (make-styled-node
;;                       :type :text
;;                       :styles child-style
;;                       :props (list :layout-rect (make-rectangle :pos (make-pos  :x 1 :y 1) :size (make-size  :w 5 :h 1))
;;                                    :text "Hi")))
;;          (parent-node (make-styled-node
;;                        :type :container
;;                        :styles parent-style
;;                        :children (list child-node)
;;                        :props (list :layout-rect (make-rectangle :pos (make-pos  :x 0 :y 0 :w 10 :h 10))))))
;;     (render-laid-out-tree-to-buffer (list parent-node) :buffer buffer)
;;     (let* ((cell (buffer-cell-at buffer 1 1))
;;            (cell-style (buffer-cell-style cell)))
;;       (is (char= #\H (buffer-cell-char cell)))
;;       (is (eq :black (terminal-color-simple (terminal-style-fg-color cell-style))))
;;       (is (eq :yellow (terminal-color-simple (terminal-style-bg-color cell-style)))))))
