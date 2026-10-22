;;; Contract: Workbench's nested style segments must survive the ElmTUI
;;; DSL -> layout -> renderer path, without an unsupported :white-space prop.
(require :asdf)
(asdf:load-system "elmtui-workbench")

(let* ((text "abCDxyz")
       (spans (make-array 2 :initial-element nil))
       (rows (list text (format nil "unicode: ~C~C" #\界 (code-char #x301)))))
  (setf (aref spans 0) (list (list 2 4 '(:fg-color :red :bold t))))
  (let* ((dsl (elmtui.workbench.view:frame-dsl rows 18 8 :style-map spans))
         (children (getf (cdr dsl) :children))
         (styled-row (first children))
         (unicode-row (second children))
         (fragments (getf (cdr styled-row) :children)))
    (assert (eq :container (first styled-row)))
    (assert (= 3 (length fragments)))
    (assert (eq :text (first unicode-row)))
    (assert (string= text (apply #'concatenate 'string
                                (mapcar (lambda (fragment)
                                          (getf (cdr fragment) :content))
                                        fragments))))
    (assert (eq :red (getf (getf (cdr (second fragments)) :style)
                           :fg-color)))
    (assert (not (search ":WHITE-SPACE" (write-to-string dsl))))
    (let* ((root (elmtui.view.base-elements:dsl->objects dsl))
           (vp (elmtui.view.geo:make-rectangle
                :pos (elmtui.view.geo:make-pos :x 0 :y 0)
                :size (elmtui.view.geo:make-size :w 18 :h 8)))
           (laid (elmtui.view.tree-transforms:process-tree
                  root
                  :ctx (elmtui.contracts:make-app-context
                        :viewport-rect vp)
                  :root-rect vp))
           (buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer
                    18 8)))
      (elmtui.platform.tree-renderer:render-laid-out-tree-to-buffer
       (list laid) :buffer buffer)
      (let ((rendered
              (coerce
               (loop for col below (length text) collect
                 (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char
                  (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at
                   buffer 0 col)))
               'string))
            (style
              (elmtui.platform.backend.common.virtual-buffer:buffer-cell-style
               (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at
                buffer 0 2))))
        (assert (string= text rendered))
        (assert (eq :red
                    (elmtui.platform.backend.common.ansi-styling:terminal-color-simple
                     (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color
                      style))))
        (assert (elmtui.platform.backend.common.ansi-styling:terminal-style-bold
                 style)))))
  (format t "REPL-NATIVE-LAYOUT-PASS~%"))
