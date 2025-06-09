;;;===============================================================
;;; File: src/platform/tree-renderer.lisp
;;; Renders a laid-out UI tree to a canvas's virtual buffer.
;;;===============================================================
(uiop:define-package :elmtui.platform.tree-renderer
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-p #:ui-node-type #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.view.geo #:rectangle #:pos #:size #:x #:y #:w #:h)
  (:import-from :elmtui.platform.backend.common.ansi-styling #:terminal-color)
  (:import-from :elmtui.view.styled #:styled-ui-node #:style-value)
  (:import-from :elmtui.style-lib.api #:styles #:style-set)


  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:buffer-style
                #:virtual-terminal-buffer ; Structure name (though usually manipulated via canvas)
                #:set-buffer-cell-at
                #:buffer-cell-at ; Added for reading existing cell style
                #:buffer-cell-style ; Added for reading existing cell style
                #:buffer-width
                #:buffer-height
                #:clear-buffer ; To prepare canvas before rendering
                #:default-buffer-cell) ; For clearing/filling

  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:make-terminal-style
                #:copy-terminal-style
                #:terminal-color
                #:make-termcolor
                #:terminal-style-bg-color
                #:terminal-color-bg
                #:fuzz-color ; Utility to convert colors to termcolor
                #:terminal-style ; Struct name, for type checks if needed
                #:terminal-color ; Struct name for type checks
                #:terminal-style-fg-color #:terminal-style-bg-color #:terminal-style-bold
                #:terminal-style-italic #:terminal-style-underline #:terminal-style-inverse
                #:terminal-style-faint #:terminal-style-blink #:terminal-style-strike #:terminal-style-invisible
                #:style-to-terminal-style) ; Utility if still relevant, or re-implement conversion
  (:export #:render-laid-out-tree-to-canvas))

(in-package :elmtui.platform.tree-renderer)
;;;===============================================================
;;; File: src/platform/tree-renderer.lisp
;;; Renders a laid-out UI tree to a canvas's virtual buffer.
;;;===============================================================
(uiop:define-package :elmtui.platform.tree-renderer
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-p #:ui-node-type #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.view.geo #:rectangle #:pos #:size #:x #:y #:w #:h)
  (:import-from :elmtui.view.styled #:styled-ui-node #:style-value)
  (:import-from :elmtui.style-lib.api #:styles #:style-set)


  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer ; Structure name (though usually manipulated via canvas)
                #:set-buffer-cell-at
                #:buffer-cell-at ; Added for reading existing cell style
                #:buffer-cell-style ; Added for reading existing cell style
                #:buffer-width
                #:buffer-height
                #:clear-buffer ; To prepare canvas before rendering
                #:default-buffer-cell) ; For clearing/filling

  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:make-terminal-style
                #:copy-terminal-style
                #:make-termcolor
                #:terminal-style-bg-color
                #:terminal-color-bg
                #:fuzz-color ; Utility to convert colors to termcolor
                #:terminal-style ; Struct name, for type checks if needed
                #:termcolor ; Struct name for type checks
                #:terminal-style-fg-color #:terminal-style-bg-color #:terminal-style-bold
                #:terminal-style-italic #:terminal-style-underline #:terminal-style-inverse
                #:terminal-style-faint #:terminal-style-blink #:terminal-style-strike #:terminal-style-invisible
                #:style-to-terminal-style) ; Utility if still relevant, or re-implement conversion
  (:export #:render-laid-out-tree-to-canvas))

(in-package :elmtui.platform.tree-renderer)

(defun get-border-characters (style)
  "Returns a plist of characters for the given border style.
   Supported styles: :solid, :ascii. Defaults to :solid characters if style is unknown or :none."
  (case style
    (:solid   (list :h #\─ :v #\│ :tl #\┌ :tr #\┐ :bl #\└ :br #\┘))
    (:ascii   (list :h #\- :v #\| :tl #\+ :tr #\+ :bl #\+ :br #\+))
    (:double (list :h #\═ :v #\║ :tl #\╔ :tr #\╗ :bl #\╚ :br #\╝))
    (t        (progn
                (unless (or (null style) (eq style :none) (eq style :solid)) ; don't warn for common/default cases
                  (log-warn "TREE-RENDERER: Unknown border style '~A', defaulting to :solid." style))
                (list :h #\─ :v #\│ :tl #\┌ :tr #\┐ :bl #\└ :br #\┘)))))

(defun convert-abstract-style-to-terminal-style (node)
  "Extracts relevant style properties from a styled-ui-node and translates
   them into a concrete terminal-style struct.
   Returns NIL if node is not styled or has no relevant styles."
  (when (typep node 'styled-ui-node)
    (let* ((node-id (getf (ui-node-props node) :id "N/A"))
           (style-set-obj (styles node))) ; Use the imported 'styles'
      (unless (typep style-set-obj 'style-set) ; Use imported 'style-set'
        (log-warn "TREE-RENDERER: Node ID: ~S - (styles node) did not return a style-set. Type: ~A. Using no styles."
                  node-id (type-of style-set-obj))
        (return-from convert-abstract-style-to-terminal-style nil))

      (let* ((raw-fg-val (or (style-value node :fg nil)
                             (style-value node :fg-color nil)
                             (style-value node :color nil)
                             (style-value node :foreground-color nil)))
             (raw-bg-val (or (style-value node :bg nil)
                             (style-value node :bg-color nil)
                             ;; (style-value node :color nil) ; :color should not be a fallback for background
                             (style-value node :background-color nil)))
             (attrs-val (style-value node :attributes nil)) ; e.g., '(:bold :underline)
             (ts (make-terminal-style))) ; Always create a terminal-style instance

        (when raw-fg-val
          (setf (terminal-style-fg-color ts) (fuzz-color raw-fg-val nil))) ; Pass nil for bg flag

        (when raw-bg-val
          (setf (terminal-style-bg-color ts) (fuzz-color raw-bg-val t))) ; Pass t for bg flag

        (when attrs-val
          (when (member :bold attrs-val) (setf (terminal-style-bold ts) t))
          (when (member :italic attrs-val) (setf (terminal-style-italic ts) t))
          (when (member :underline attrs-val) (setf (terminal-style-underline ts) t))
          (when (member :inverse attrs-val) (setf (terminal-style-inverse ts) t))
          (when (member :faint attrs-val) (setf (terminal-style-faint ts) t))
          (when (member :blink attrs-val) (setf (terminal-style-blink ts) t))
          (when (member :strike attrs-val) (setf (terminal-style-strike ts) t))
          (when (member :invisible attrs-val) (setf (terminal-style-invisible ts) t)))
        ts)))) ; Return the terminal-style struct

(defun %render-node (node canvas-buffer parent-abs-x parent-abs-y)
  "Recursively renders a single laid-out UI node and its children to the canvas-buffer.
   NODE: The ui-node to render.
   CANVAS-BUFFER: The virtual-terminal-buffer of the canvas.
   PARENT-ABS-X, PARENT-ABS-Y: Absolute coordinates of the parent, for relative positioning."
  (when (and node (typep node 'ui-node))
    (let ((layout-rect (getf (ui-node-props node) :layout-rect)))
      (log-debug "TREE-RENDERER: render-node - Type: ~S, ID: ~S, LayoutRect: ~S"
                 (ui-node-type node) (getf (ui-node-props node) :id "N/A") layout-rect)

      (unless (and layout-rect (typep layout-rect 'rectangle))
        (log-warn "TREE-RENDERER: Skipping node ID ~S, Type ~S due to missing or invalid layout-rect."
                  (getf (ui-node-props node) :id "N/A") (ui-node-type node))
        (return-from %render-node))

      ;; Calculate absolute position and size of the current node's border-box
      (let* ((abs-x (+ parent-abs-x (x layout-rect)))
             (abs-y (+ parent-abs-y (y layout-rect)))
             (border-box-w (w layout-rect))
             (border-box-h (h layout-rect))
             (terminal-style (convert-abstract-style-to-terminal-style node))
             (buffer-w (buffer-width canvas-buffer))
             (buffer-h (buffer-height canvas-buffer)))

        ;; Only proceed if node is visible and has dimensions
        (when (and (> border-box-w 0) (> border-box-h 0)
                   (not (eq (style-value node :visibility :visible) :hidden))
                   (not (eq (style-value node :display :block) :none)))

          ;; 1. First render Background (fills the border-box)
          (let ((bg-color-obj (when terminal-style (terminal-style-bg-color terminal-style))))
            (when bg-color-obj

              (loop for r from 0 below border-box-h
                    do (loop for c from 0 below border-box-w
                             do (let ((target-r (+ abs-y r))
                                      (target-c (+ abs-x c)))
                                  (when (and (>= target-r 0) (< target-r buffer-h)
                                             (>= target-c 0) (< target-c buffer-w))
                                    (let* ((cell-style (make-terminal-style :bg-color bg-color-obj)))
                                      (set-buffer-cell-at canvas-buffer target-r target-c #\Space cell-style))))))))

          ;; Calculate effective border widths and padding
          (let* ((border-style-val (style-value node :border-style :none))
                 (effective-btw (if (eq border-style-val :none) 0 (style-value node :border-top-width 1)))
                 (effective-brw (if (eq border-style-val :none) 0 (style-value node :border-right-width 1)))
                 (effective-bbw (if (eq border-style-val :none) 0 (style-value node :border-bottom-width 1)))
                 (effective-blw (if (eq border-style-val :none) 0 (style-value node :border-left-width 1)))
                 (padding-top (style-value node :padding-top 0))
                 (padding-right (style-value node :padding-right 0))
                 (padding-bottom (style-value node :padding-bottom 0))
                 (padding-left (style-value node :padding-left 0)))

            ;; 2. Render Borders
            (when (and terminal-style (not (eq border-style-val :none)))
              (let* ((border-chars (get-border-characters border-style-val))
                     (char-h (getf border-chars :h #\?))
                     (char-v (getf border-chars :v #\?))
                     (char-tl (getf border-chars :tl #\?))
                     (char-tr (getf border-chars :tr #\?))
                     (char-bl (getf border-chars :bl #\?))
                     (char-br (getf border-chars :br #\?))
                     (border-color-val (style-value node :border-color nil))
                     (border-fg-color-obj
                       (let ((resolved-color-src (or border-color-val (terminal-style-fg-color terminal-style))))
                         (cond ((listp resolved-color-src)
                                (make-termcolor :r (first resolved-color-src)
                                                :g (second resolved-color-src)
                                                :b (third resolved-color-src)))
                               ((integerp resolved-color-src)
                                (make-termcolor :color-256 resolved-color-src))
                               ((keywordp resolved-color-src)
                                (make-termcolor :simple resolved-color-src))
                               ((typep resolved-color-src 'elmtui.platform.backend.common.ansi-styling:terminal-color) resolved-color-src)
                               (t nil)))))

                (when border-fg-color-obj ; Only draw if border has a color
                  (flet ((draw-border-char (r c char)
                           (when (and (>= r 0) (< r buffer-h) (>= c 0) (< c buffer-w))
                             (let* ((cell-style
                                      (elmtui.platform.backend.common.virtual-buffer:buffer-style canvas-buffer r c))
                                    (existing-bg (when cell-style (terminal-style-bg-color cell-style)))
                                    (border-style (make-terminal-style
                                                   :fg-color border-fg-color-obj
                                                   :bg-color existing-bg)))
                               (set-buffer-cell-at canvas-buffer r c char border-style)))))

                    ;; Draw horizontal borders
                    ;; (when (> effective-btw 0)
                    (when (> effective-btw 0)
                      (loop for c-idx
                              from
                              (if (> effective-blw 0) 1 0)
                              below (- border-box-w (if (> effective-brw 0) 0 0))
                                        ; Removed the subtraction of 1 if the right border exists
                            do (draw-border-char abs-y (+ abs-x c-idx) char-h)))

                    ;; (loop for c-idx from (if (> effective-blw 0) 1 0) below (- border-box-w (if (> effective-brw 0) 1 0))
                    ;;       do (draw-border-char abs-y (+ abs-x c-idx) char-h)))
                    (when (> effective-bbw 0)
                      (loop for c-idx from (if (> effective-blw 0) 1 0) below (- border-box-w (if (> effective-brw 0) 1 0))
                            do (draw-border-char (+ abs-y border-box-h -1) (+ abs-x c-idx) char-h)))

                    ;; Draw vertical borders
                    (when (> effective-blw 0)
                      (loop for r-idx from (if (> effective-btw 0) 1 0) below (- border-box-h (if (> effective-bbw 0) 1 0))
                            do (draw-border-char (+ abs-y r-idx) abs-x char-v)))
                    (when (> effective-brw 0)
                      (loop for r-idx from (if (> effective-btw 0) 1 0) below (- border-box-h (if (> effective-bbw 0) 1 0))
                            do (draw-border-char (+ abs-y r-idx) (+ abs-x border-box-w -1) char-v)))

                    ;; Draw Corners
                    (cond ((and (> effective-btw 0) (> effective-blw 0))
                           (draw-border-char abs-y abs-x char-tl))
                          ((> effective-btw 0)
                           (draw-border-char abs-y abs-x char-h))
                          ((> effective-blw 0)
                           (draw-border-char abs-y abs-x char-v)))

                    (cond ((and (> effective-btw 0) (> effective-brw 0))
                           (draw-border-char abs-y (+ abs-x border-box-w -1) char-tr))
                          ((> effective-btw 0)
                           (draw-border-char abs-y (+ abs-x border-box-w -1) char-h))
                          ((> effective-brw 0)
                           (draw-border-char abs-y (+ abs-x border-box-w -1) char-v)))

                    (cond ((and (> effective-bbw 0) (> effective-blw 0))
                           (draw-border-char (+ abs-y border-box-h -1) abs-x char-bl))
                          ((> effective-bbw 0)
                           (draw-border-char (+ abs-y border-box-h -1) abs-x char-h))
                          ((> effective-blw 0)
                           (draw-border-char (+ abs-y border-box-h -1) abs-x char-v)))

                    (cond ((and (> effective-bbw 0) (> effective-brw 0))
                           (draw-border-char (+ abs-y border-box-h -1) (+ abs-x border-box-w -1) char-br))
                          ((> effective-bbw 0)
                           (draw-border-char (+ abs-y border-box-h -1) (+ abs-x border-box-w -1) char-h))
                          ((> effective-brw 0)
                           (draw-border-char (+ abs-y border-box-h -1) (+ abs-x border-box-w -1) char-v)))))))

            ;; Calculate Content Box dimensions
            (let* ((content-abs-x (+ abs-x effective-blw padding-left))
                   (content-abs-y (+ abs-y effective-btw padding-top))
                   (content-w (max 0 (- border-box-w effective-blw effective-brw padding-left padding-right)))
                   (content-h (max 0 (- border-box-h effective-btw effective-bbw padding-top padding-bottom))))

              (log-debug "TREE-RENDERER: Node ID ~S - BorderBox: (~A,~A W:~A H:~A), ContentBox: (~A,~A W:~A H:~A)"
                         (getf (ui-node-props node) :id "N/A")
                         abs-x abs-y border-box-w border-box-h
                         content-abs-x content-abs-y content-w content-h)

              ;; 3. Render Content (e.g., text) within the content-box
              (when (and terminal-style (> content-w 0) (> content-h 0))
                (case (ui-node-type node)
                  ((:text :drawable-content)
                   (let ((text (getf (ui-node-props node) :text "")))
                     (loop with current-x = 0 with current-y = 0
                           for char-index from 0 below
                                                 (length text)
                           for char = (aref text char-index)
                           do (progn (when
                                         (>= current-x content-w)
                                       (setf current-x 0)
                                       (incf current-y))
                                     (when (>= current-y content-h) (return))
                                     (let ((target-r (+ content-abs-y current-y))
                                           (target-c (+ content-abs-x current-x)))
                                       (when (and (>= target-r 0)
                                                  (< target-r buffer-h)
                                                  (>= target-c 0)
                                                  (< target-c buffer-w))
                                         (let* ((cell-style (elmtui.platform.backend.common.virtual-buffer:buffer-style canvas-buffer target-r target-c))
                                                (existing-bg (when cell-style (terminal-style-bg-color cell-style)))
                                                (fg-color (terminal-style-fg-color terminal-style))
                                                (text-style (make-terminal-style
                                                             :fg-color fg-color
                                                             :bg-color (or (terminal-style-bg-color terminal-style) existing-bg)
                                                             :bold (when terminal-style (terminal-style-bold terminal-style))
                                                             :italic (when terminal-style (terminal-style-italic terminal-style))
                                                             :underline (when terminal-style (terminal-style-underline terminal-style))
                                                             :inverse (when terminal-style (terminal-style-inverse terminal-style))
                                                             :faint (when terminal-style (terminal-style-faint terminal-style))
                                                             :blink (when terminal-style (terminal-style-blink terminal-style))
                                                             :strike (when terminal-style (terminal-style-strike terminal-style))
                                                             :invisible (when terminal-style (terminal-style-invisible terminal-style)))))
                                           (set-buffer-cell-at canvas-buffer target-r target-c char text-style))))
                                     (incf current-x)
                                     (when (>= current-x content-w) ; Wrap line
                                       (setf current-x 0)
                                       (incf current-y))))

                     ;; (incf current-x)))

                     ;; (loop with current-x = 0
                     ;;       with current-y = 0
                     ;;       for char-index from 0 below (length text)
                     ;;       for char = (aref text char-index)
                     ;;       do
                     ;;          (when (>= current-y content-h) (return)) ; Stop if content height is exceeded
                     ;;          (let ((target-r (+ content-abs-y current-y))
                     ;;                (target-c (+ content-abs-x current-x)))
                     ;;            (when (and (>= target-r 0) (< target-r buffer-h)
                     ;;                       (>= target-c 0) (< target-c buffer-w))
                     ;;              (let* ((cell-style (elmtui.platform.backend.common.virtual-buffer:buffer-style canvas-buffer target-r target-c))
                     ;;                     (existing-bg (when cell-style (terminal-style-bg-color cell-style)))
                     ;;                     (fg-color (terminal-style-fg-color terminal-style))
                     ;;                     (text-style (make-terminal-style
                     ;;                                  :fg-color fg-color
                     ;;                                  :bg-color (or (terminal-style-bg-color terminal-style) existing-bg)
                     ;;                                  :bold (when terminal-style (terminal-style-bold terminal-style))
                     ;;                                  :italic (when terminal-style (terminal-style-italic terminal-style))
                     ;;                                  :underline (when terminal-style (terminal-style-underline terminal-style))
                     ;;                                  :inverse (when terminal-style (terminal-style-inverse terminal-style))
                     ;;                                  :faint (when terminal-style (terminal-style-faint terminal-style))
                     ;;                                  :blink (when terminal-style (terminal-style-blink terminal-style))
                     ;;                                  :strike (when terminal-style (terminal-style-strike terminal-style))
                     ;;                                  :invisible (when terminal-style (terminal-style-invisible terminal-style)))))
                     ;;                (set-buffer-cell-at canvas-buffer target-r target-c char text-style))))
                     ;;          (incf current-x)
                     ;;          (when (>= current-x content-w) ; Wrap line
                     ;;            (setf current-x 0)
                     ;;            (incf current-y)))
                     )))
                ;; Add other node types here as needed
                ))))

        ;; Recursively render children
        (dolist (child (ui-node-children node))
          (%render-node child canvas-buffer abs-x abs-y))))))

(defun render-laid-out-tree-to-canvas (laid-out-tree buffer)
  "Renders the laid-out UI tree to the canvas's virtual buffer."
  (log-info "TREE-RENDERER: Starting render to canvas.")
  (clear-buffer buffer) ; Prepare canvas by clearing or resetting to default
  (%render-node laid-out-tree buffer 0 0)
  (log-info "TREE-RENDERER: Finished render to canvas."))
                                        ; Return the canvas, now with the rendered tree in its buffer

;; Ensure all functions are properly closed and the file ends correctly.

;; (defun get-border-characters (style)
;;   "Returns a plist of characters for the given border style.
;;    Supported styles: :solid, :ascii. Defaults to :solid characters if style is unknown or :none."
;;   (case style
;;     (:solid   (list :h #\─ :v #\│ :tl #\┌ :tr #\┐ :bl #\└ :br #\┘))
;;     (:ascii   (list :h #\- :v #\| :tl #\+ :tr #\+ :bl #\+ :br #\+))
;;     (:double (list :h #\═ :v #\║ :tl #\╔ :tr #\╗ :bl #\╚ :br #\╝))
;;     (t        (progn
;;                 (unless (or (null style) (eq style :none) (eq style :solid)) ; don't warn for common/default cases
;;                   (log-warn "TREE-RENDERER: Unknown border style '~A', defaulting to :solid." style))
;;                 (list :h #\─ :v #\│ :tl #\┌ :tr #\┐ :bl #\└ :br #\┘)))))

;; (defun convert-abstract-style-to-terminal-style (node)
;;   "Extracts relevant style properties from a styled-ui-node and translates
;;    them into a concrete terminal-style struct.
;;    Returns NIL if node is not styled or has no relevant styles."
;;   (when (typep node 'ui-node)
;;     ;; Extract style from node props if stored there (for tests) or use styled-ui-node API
;;     (let* ((props (ui-node-props node))
;;            (style-plist (getf props :style nil))
;;            (ts (make-terminal-style)))

;;       ;; If there's a style plist in props, use it directly
;;       (when style-plist
;;         ;; Extract foreground color
;;         (let ((fg-val (fuzz-color (or (getf style-plist :fg nil)
;;                                       (getf style-plist :fg-color nil)
;;                                       (getf style-plist :color nil)
;;                                       (getf style-plist :foreground-color nil)))))
;;           (when fg-val
;;             (setf (terminal-style-fg-color ts)  fg-val )))

;;         ;; Extract background color
;;         (let ((bg-val (fuzz-color (or (getf style-plist :bg nil)
;;                                       (getf style-plist :bg-color nil)
;;                                       (getf style-plist :background-color nil)) t)))
;;           (when bg-val
;;             (setf (terminal-style-bg-color ts)  bg-val )))

;;         ;; Extract attributes
;;         (let ((attrs-val (getf style-plist :attrs nil)))
;;           (when attrs-val
;;             (when (member :bold attrs-val) (setf (terminal-style-bold ts) t))
;;             (when (member :italic attrs-val) (setf (terminal-style-italic ts) t))
;;             (when (member :underline attrs-val) (setf (terminal-style-underline ts) t))
;;             (when (member :inverse attrs-val) (setf (terminal-style-inverse ts) t))
;;             (when (member :faint attrs-val) (setf (terminal-style-faint ts) t))
;;             (when (member :blink attrs-val) (setf (terminal-style-blink ts) t))
;;             (when (member :strike attrs-val) (setf (terminal-style-strike ts) t))
;;             (when (member :invisible attrs-val) (setf (terminal-style-invisible ts) t))))

;;         ;; Also handle direct style properties
;;         (when (getf style-plist :bold) (setf (terminal-style-bold ts) t))
;;         (when (getf style-plist :italic) (setf (terminal-style-italic ts) t))
;;         (when (getf style-plist :underline) (setf (terminal-style-underline ts) t))
;;         (when (getf style-plist :inverse) (setf (terminal-style-inverse ts) t))

;;         ts)

;;       ;; If it's a styled-ui-node, use its API (fallback for normal operation)
;;       (when (and (typep node 'styled-ui-node) (null style-plist))
;;         (let* ((style-set-obj (styles node))
;;                (raw-fg-val (fuzz-color (or (style-value node :fg nil)
;;                                            (style-value node :fg-color nil)
;;                                            (style-value node :color nil)
;;                                            (style-value node :foreground-color nil)
;;                                            (elmtui.style-lib.style-set:style-of style-set-obj :fg-color))
;;                                        nil))
;;                (raw-bg-val (fuzz-color
;;                             (or (style-value node :bg nil)
;;                                 (style-value node :bg-color nil)
;;                                 (style-value node :background-color nil)
;;                                 (elmtui.style-lib.style-set:style-of style-set-obj :bg-color))
;;                             t))
;;                (attrs-val (style-value node :attributes nil)))

;;           (when raw-fg-val
;;             (setf (terminal-style-fg-color ts) raw-fg-val))

;;           (when raw-bg-val
;;             (setf (terminal-style-bg-color ts) raw-bg-val ))

;;           (when attrs-val
;;             (when (member :bold attrs-val) (setf (terminal-style-bold ts) t))
;;             (when (member :italic attrs-val) (setf (terminal-style-italic ts) t))
;;             (when (member :underline attrs-val) (setf (terminal-style-underline ts) t))
;;             (when (member :inverse attrs-val) (setf (terminal-style-inverse ts) t))
;;             (when (member :faint attrs-val) (setf (terminal-style-faint ts) t))
;;             (when (member :blink attrs-val) (setf (terminal-style-blink ts) t))
;;             (when (member :strike attrs-val) (setf (terminal-style-strike ts) t))
;;             (when (member :invisible attrs-val) (setf (terminal-style-invisible ts) t)))
;;           ts))
;;       ts)))
