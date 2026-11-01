;;; Contract: Workbench's nested style segments must survive the ElmTUI
;;; DSL -> layout -> renderer path, without an unsupported :white-space prop.
(require :asdf)
(asdf:load-system "elmtui-workbench")

;; This must be a native pane tree, rather than a prepainted character canvas.
(assert (fboundp 'elmtui.workbench.view::frame-view))

(let* ((text "abCDxyz")
       (spans (make-array 2 :initial-element nil))
       (rows (list text (format nil "unicode: ~C~C" #\界 (code-char #x301)))))
  (setf (aref spans 0) (list (list 2 4 '(:fg-color :red :bold t))))
  (setf (aref spans 1) (list (list 9 11 '(:fg-color :red :bold t))))
  (let* ((dsl (elmtui.workbench.view:frame-dsl rows 18 8 :style-map spans))
         (children (getf (cdr dsl) :children))
         (styled-row (first children))
         (unicode-row (second children))
         (fragments (getf (cdr styled-row) :children)))
    (assert (eq :container (first styled-row)))
    (assert (= 3 (length fragments)))
    (assert (eq :container (first unicode-row)))
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
      (let* ((wide (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer 1 9))
             (tail (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer 1 10))
             (style (elmtui.platform.backend.common.virtual-buffer:buffer-cell-style wide)))
        (assert (char= #\界 (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char wide)))
        (assert (char= #\Null (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char tail)))
        (assert (equal (elmtui.platform.backend.common.virtual-buffer:buffer-cell-grapheme wide)
                       (format nil "界~C" (code-char #x301))))
        (assert (elmtui.platform.backend.common.ansi-styling:terminal-style-bold style))
        (assert (eq :red (elmtui.platform.backend.common.ansi-styling:terminal-color-simple
                         (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color style)))))
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

(let ((rows (elmtui.workbench.view:frame-lines :width 80 :height 24
                                             :source "界a" :cursor 1)))
  ;; Cursor insertion must preserve the suffix, after a full two-cell glyph.
  (assert (some (lambda (row) (search " > 界|a" row)) rows)))
(let* ((accent (format nil "a~C" (code-char #x301)))
       (source (concatenate 'string accent "界x"))
       (rows (elmtui.workbench.view:frame-lines :width 80 :height 24
                                              :source source :cursor 3)))
  (assert (some (lambda (row) (search " > á界|x" row)) rows)))
(assert (string= " " (elmtui.view.layout.size-utils:terminal-string-slice "界a" 1 2)))
(assert (string= "a" (elmtui.view.layout.size-utils:terminal-string-slice "界a" 2 3)))
(assert (string= "界" (elmtui.view.layout.size-utils:terminal-string-slice "界a" 0 2)))
(assert (string= " " (elmtui.view.layout.size-utils:terminal-string-slice "界a" 0 1)))
(let* ((source (format nil "a~Cb" #\Tab))
       (before (elmtui.workbench.view:frame-lines :width 40 :height 12 :source source :cursor 0))
       (after (elmtui.workbench.view:frame-lines :width 40 :height 12 :source source :cursor 3)))
  (assert (some (lambda (row) (search " > |a       b" row)) before))
  (assert (some (lambda (row) (search " > a       b|" row)) after)))
(let* ((source (concatenate 'string (make-string 100 :initial-element #\x) "界a"))
       (rows (elmtui.workbench.view:frame-lines :width 24 :height 12
                                              :source source :cursor 101)))
  (assert (some (lambda (row) (search "界|" row)) rows)))
