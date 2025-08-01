;;;===============================================================
;;; File: src/platform/tree-renderer.lisp
;;; Renders a laid-out UI tree to a canvas's virtual buffer.
;;;===============================================================
(uiop:define-package :elmtui.platform.tree-renderer
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.contracts #:define-stage)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-p #:ui-node-type #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.view.api #:ui-node-p #:styled-ui-node)
  (:import-from :elmtui.view.geo #:rectangle #:pos #:size #:x #:y #:w #:h)
  (:import-from :elmtui.view.styled #:styled-ui-node #:style-value #:styled-ui-node-style-map)
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
                #:copy-term-style
                #:make-terminal-style
                #:copy-terminal-style
                #:make-termcolor
                #:terminal-style-bg-color
                #:termcolor-bg
                #:fuzz-color ; Utility to convert colors to termcolor
                #:terminal-style ; Struct name, for type checks if needed
                #:terminal-color ; Struct name for type checks
                #:terminal-style-fg-color #:terminal-style-bg-color #:terminal-style-bold
                #:terminal-style-italic #:terminal-style-underline #:terminal-style-inverse
                #:terminal-style-faint #:terminal-style-blink #:terminal-style-strike #:terminal-style-invisible
                #:style-to-terminal-style) ; Utility if still relevant, or re-implement conversion
  (:export
   #:convert-abstract-style-to-terminal-style
   #:render-laid-out-tree-to-buffer))

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
                  (format t "TREE-RENDERER: Unknown border style '~A', defaulting to :solid." style))
                (list :h #\─ :v #\│ :tl #\┌ :tr #\┐ :bl #\└ :br #\┘)))))
;; (defun color-or-nil (raw &optional (bgp nil))
;;   "Like FUZZ-COLOR but returns NIL instead of signalling."
;;   (when raw
;;     (handler-case (fuzz-color raw bgp)
;;       (error () nil))))

(defun convert-abstract-style-to-terminal-style (node)
  "Extracts relevant style properties from a styled-ui-node and translates
   them into a concrete terminal-style struct.
   Always returns a terminal-style object, even if empty."
  (let ((result
          (handler-case
              (progn
                (format t "TREE-RENDERER: convert-abstract-style-to-terminal-style ENTRY - node=~S~%" node)
                (if (typep node 'styled-ui-node)
                    (let* ((node-id (getf (ui-node-props node) :id "N/A"))
                           (style-map (styled-ui-node-style-map node)))

                      (format t "TREE-RENDERER: Node ID: ~S - style-map=~S~%" node-id style-map)

                      (if (null style-map)
                          (progn
                            (format t "TREE-RENDERER: Node ID: ~S - No style-map found. Using empty terminal-style.~%" node-id)
                            (make-terminal-style))
                          (let* ((raw-fg-val (or (getf style-map :fg nil)
                                                 (getf style-map :fg-color nil)
                                                 (getf style-map :color nil)
                                                 (getf style-map :foreground-color nil)))
                                 (raw-bg-val (or (getf style-map :bg nil)
                                                 (getf style-map :bg-color nil)
                                                 (getf style-map :background-color nil)))
                                 (attrs-val (getf style-map :attributes nil)) ; e.g., '(:bold :underline)
                                 (ts (make-terminal-style))) ; Always create a terminal-style instance

                            (format t "TREE-RENDERER: Style extraction - fg=~S bg=~S attrs=~S~%" raw-fg-val raw-bg-val attrs-val)

                            (when raw-fg-val
                              (handler-case
                                  ;; (setf (terminal-style-fg-color ts) (fuzz-color raw-fg-val nil))
                                        ; Pass nil for bg flag
                                  (let ((c (color-or-nil raw-fg-val)))
                                    (when c (setf (terminal-style-fg-color ts) c)))

                                (error (e) (format t "TREE-RENDERER: Error setting fg-color: ~A~%" e))))

                            (when raw-bg-val
                              (handler-case
                                  (setf (terminal-style-bg-color ts) (fuzz-color raw-bg-val t)) ; Pass t for bg flag
                                (error (e) (format t "TREE-RENDERER: Error setting bg-color: ~A~%" e))))

                            (when attrs-val
                              (handler-case
                                  (progn
                                    (when (member :bold attrs-val) (setf (terminal-style-bold ts) t))
                                    (when (member :italic attrs-val) (setf (terminal-style-italic ts) t))
                                    (when (member :underline attrs-val) (setf (terminal-style-underline ts) t))
                                    (when (member :inverse attrs-val) (setf (terminal-style-inverse ts) t))
                                    (when (member :faint attrs-val) (setf (terminal-style-faint ts) t))
                                    (when (member :blink attrs-val) (setf (terminal-style-blink ts) t))
                                    (when (member :strike attrs-val) (setf (terminal-style-strike ts) t))
                                    (when (member :invisible attrs-val) (setf (terminal-style-invisible ts) t)))
                                (error (e) (format t "TREE-RENDERER: Error setting attributes: ~A~%" e))))

                            (format t "TREE-RENDERER: Terminal style created successfully: ~S~%" ts)
                            ts))) ; Return the terminal-style struct
                    ;; If not a styled-ui-node, return empty terminal-style
                    (progn
                      (format t "TREE-RENDERER: Node is not styled-ui-node, returning empty terminal-style~%")
                      (make-terminal-style))))
            (error (e)
              (format t "TREE-RENDERER: CRITICAL ERROR in convert-abstract-style-to-terminal-style: ~A~%" e)
              (format t "TREE-RENDERER: Returning emergency empty terminal-style~%")
              (make-terminal-style)))))
    ;; Extra safety check: ensure we never return NIL
    (or result ;; (progn
        ;;   (format t "TREE-RENDERER: EMERGENCY FALLBACK - result was NIL, creating new terminal-style~%")
        ;;   (make-terminal-style))
        )))

;; (defun %render-node (node canvas-buffer parent-abs-x parent-abs-y)
;;   "Recursively renders a single laid-out UI node and its children to the canvas-buffer.
;;    NODE: The ui-node to render.
;;    CANVAS-BUFFER: The virtual-terminal-buffer of the canvas.
;;    PARENT-ABS-X, PARENT-ABS-Y: Absolute coordinates of the parent, for relative positioning."
;;   ;; (format t "DEBUG: %render-node ENTRY - node=~S~%" node)
;;   ;; (format t "DEBUG: Node type check - node exists: ~S, is styled-ui-node: ~S~%"
;;   ;;         (not (null node))
;;   ;;         (when node (typep node 'styled-ui-node)))
;;   (when (and node (typep node 'styled-ui-node))
;;     ;; (format t "DEBUG: Type check PASSED - proceeding with render~%")
;;     (let ((layout-rect (getf (ui-node-props node) :layout-rect)))
;;       ;; (format t "DEBUG: Layout rect = ~S~%" layout-rect)
;;       ;; (format t "DEBUG: Layout rect type check = ~S~%" (typep layout-rect 'rectangle))

;;       (unless (and layout-rect (typep layout-rect 'rectangle))
;;         (format t "DEBUG: SKIPPING node - layout-rect invalid~%")
;;         (return-from %render-node))

;;       ;; Calculate absolute position and size of the current node's border-box
;;       (let* ((abs-x (+ parent-abs-x (x layout-rect)))
;;              (abs-y (+ parent-abs-y (y layout-rect)))
;;              (border-box-w (w layout-rect))
;;              (border-box-h (h layout-rect))
;;              (terminal-style (convert-abstract-style-to-terminal-style node))
;;              (buffer-w (buffer-width canvas-buffer))
;;              (buffer-h (buffer-height canvas-buffer)))

;;         ;; (format t "DEBUG: Terminal style created: ~S~%" terminal-style)
;;         ;; (when terminal-style
;;         ;;   (format t "DEBUG: Terminal style bg-color: ~S~%" (terminal-style-bg-color terminal-style)))

;;         ;; Only proceed if node is visible and has dimensions
;;         ;; (format t "DEBUG: Visibility check - border-box-w=~A border-box-h=~A visibility=~S display=~S~%"
;;         ;;         border-box-w border-box-h
;;         ;;         (getf (styled-ui-node-style-map node) :visibility :visible)
;;         ;;         (getf (styled-ui-node-style-map node) :display :block))
;;         (when (and (> border-box-w 0) (> border-box-h 0)
;;                    (not (eq (getf (styled-ui-node-style-map node) :visibility :visible) :hidden))
;;                    (not (eq (getf (styled-ui-node-style-map node) :display :block) :none)))
;;           ;; (format t "DEBUG: Visibility check PASSED - proceeding to background fill~%")

;;           ;; 1. First render Background (fills the border-box)
;;           ;; (format t "DEBUG: Early background fill check - terminal-style=~S bg-color=~S~%"
;;           ;;         (not (null terminal-style))
;;           ;;         (when terminal-style (terminal-style-bg-color terminal-style)))
;;           (when (and terminal-style (terminal-style-bg-color terminal-style))
;;             ;; (format t "DEBUG: Early background fill - EXECUTING! Filling border-box ~Ax~A~%"
;;             ;;         border-box-w border-box-h)
;;             (loop for r from 0 below border-box-h
;;                   do (loop for c from 0 below border-box-w
;;                            do (let ((target-r (+ abs-y r))
;;                                     (target-c (+ abs-x c)))
;;                                 (when (and (>= target-r 0) (< target-r buffer-h)
;;                                            (>= target-c 0) (< target-c buffer-w))
;;                                   ;; Use the full style for the background fill
;;                                   (set-buffer-cell-at canvas-buffer target-r target-c #\Space terminal-style)
;;                                   ;; DEBUG: Check cell immediately after fill
;;                                   (when (and (= target-r 0) (= target-c 0))
;;                                     (let ((cell (buffer-cell-at canvas-buffer target-r target-c)))
;;                                       (format t "DEBUG: Cell (0,0) IMMEDIATELY after background fill: ~S~%" cell)
;;                                       (format t "DEBUG: Cell bg-color IMMEDIATELY after fill: ~S~%"
;;                                               (when cell (terminal-style-bg-color (buffer-cell-style cell)))))))))))

;;           ;; Calculate effective border widths and padding
;;           (let* ((style-map (styled-ui-node-style-map node))
;;                  (border-style-val (getf style-map :border-style :none))
;;                  (effective-btw (if (eq border-style-val :none) 0 (getf style-map :border-top-width 1)))
;;                  (effective-brw (if (eq border-style-val :none) 0 (getf style-map :border-right-width 1)))
;;                  (effective-bbw (if (eq border-style-val :none) 0 (getf style-map :border-bottom-width 1)))
;;                  (effective-blw (if (eq border-style-val :none) 0 (getf style-map :border-left-width 1)))
;;                  ;; (a (format t "DEBUG: Border values - border-style-val=~S effective-btw=~S effective-blw=~S~%"
;;                  ;;           border-style-val effective-btw effective-blw))
;;                  ;; (b (format t "DEBUG: Border condition check - terminal-style=~S (not (eq border-style-val :none))=~S~%"
;;                  ;;            (not (null terminal-style)) (not (eq border-style-val :none))))
;;                  (padding-top (getf style-map :padding-top 0))
;;                  (padding-right (getf style-map :padding-right 0))
;;                  (padding-bottom (getf style-map :padding-bottom 0))
;;                  (padding-left (getf style-map :padding-left 0)))

;;             ;; 2. Render Borders
;;             (when (and terminal-style (not (eq border-style-val :none)))
;;               ;; (format t "DEBUG: Border rendering - CONDITION PASSED! border-style=~S~%" border-style-val)
;;               (let* ((border-chars (get-border-characters border-style-val))
;;                      (char-h (getf border-chars :h #\?))
;;                      (char-v (getf border-chars :v #\?))
;;                      (char-tl (getf border-chars :tl #\?))
;;                      (char-tr (getf border-chars :tr #\?))
;;                      (char-bl (getf border-chars :bl #\?))
;;                      (char-br (getf border-chars :br #\?))
;;                      (border-fg-color-obj
;;                        (color-or-nil (or (getf style-map :border-color)
;;                                          (terminal-style-fg-color terminal-style))))

;;                      ;; (border-color-val (getf style-map :border-color nil))
;;                      ;; (border-fg-color-obj (fuzz-color (or border-color-val (terminal-style-fg-color terminal-style))))
;;                      )

;;                 ;; (format t "DEBUG: Border chars: tl=~S border-color-val=~S border-fg-color-obj=~S~%"
;;                 ;;         char-tl border-color-val border-fg-color-obj)
;;                 (when border-fg-color-obj ; Only draw if border has a color
;;                   (format t "DEBUG: Border color check PASSED! Drawing borders...~%")
;;                   (flet ((draw-border-char (r c char)
;;                            (when (and (>= r 0) (< r buffer-h) (>= c 0) (< c buffer-w))
;;                              (let* ((existing-style (buffer-cell-style (buffer-cell-at canvas-buffer r c)))
;;                                     (border-style (if existing-style
;;                                                       (copy-term-style existing-style)
;;                                                       (copy-term-style terminal-style))))
;;                                (setf (terminal-style-fg-color border-style) border-fg-color-obj)
;;                                (set-buffer-cell-at canvas-buffer r c char border-style)))))

;;                     ;; Draw horizontal borders
;;                     (when (> effective-btw 0)
;;                       (loop for c-idx from (if (> effective-blw 0) 1 0) below (- border-box-w (if (> effective-brw 0) 1 0))
;;                             do (draw-border-char abs-y (+ abs-x c-idx) char-h)))
;;                     (when (> effective-bbw 0)
;;                       (loop for c-idx from (if (> effective-blw 0) 1 0) below (- border-box-w (if (> effective-brw 0) 1 0))
;;                             do (draw-border-char (+ abs-y border-box-h -1) (+ abs-x c-idx) char-h)))

;;                     ;; Draw vertical borders
;;                     (when (> effective-blw 0)
;;                       (loop for r-idx from (if (> effective-btw 0) 1 0) below (- border-box-h (if (> effective-bbw 0) 1 0))
;;                             do (draw-border-char (+ abs-y r-idx) abs-x char-v)))
;;                     (when (> effective-brw 0)
;;                       (loop for r-idx from (if (> effective-btw 0) 1 0) below (- border-box-h (if (> effective-bbw 0) 1 0))
;;                             do (draw-border-char (+ abs-y r-idx) (+ abs-x border-box-w -1) char-v)))

;;                     ;; Draw Corners
;;                     (when (and (> effective-btw 0) (> effective-blw 0)) (draw-border-char abs-y abs-x char-tl))
;;                     (when (and (> effective-btw 0) (> effective-brw 0)) (draw-border-char abs-y (+ abs-x border-box-w -1) char-tr))
;;                     (when (and (> effective-bbw 0) (> effective-blw 0)) (draw-border-char (+ abs-y border-box-h -1) abs-x char-bl))
;;                     (when (and (> effective-bbw 0) (> effective-brw 0)) (draw-border-char (+ abs-y border-box-h -1) (+ abs-x border-box-w -1) char-br))))))

;;             ;; Calculate Content Box dimensions
;;             (let* ((content-abs-x (+ abs-x effective-blw padding-left))
;;                    (content-abs-y (+ abs-y effective-btw padding-top))
;;                    (content-w (max 0 (- border-box-w effective-blw effective-brw padding-left padding-right)))
;;                    (content-h (max 0 (- border-box-h effective-btw effective-bbw padding-top padding-bottom))))

;;               ;; (format t "TREE-RENDERER: Node ID ~S - BorderBox: (~A,~A W:~A H:~A), ContentBox: (~A,~A W:~A H:~A)"
;;               ;;         (getf (ui-node-props node) :id "N/A")
;;               ;;         abs-x abs-y border-box-w border-box-h
;;               ;;         content-abs-x content-abs-y content-w content-h)

;;               ;; 2.5. Fill background area with background color
;;               ;; (format t "TREE-RENDERER: Background fill condition check - terminal-style=~S bg-color=~S content-w=~A content-h=~A"
;;               ;;         (not (null terminal-style))
;;               ;;         (when terminal-style (not (null (terminal-style-bg-color terminal-style))))
;;               ;;         content-w content-h)
;;               ;; (format t "TREE-RENDERER: Terminal style object: ~S" terminal-style)
;;               ;; (when terminal-style
;;               ;;   (format t "TREE-RENDERER: Terminal style bg-color: ~S" (terminal-style-bg-color terminal-style)))
;;               ;; DISABLED: Prevent second background fill from overwriting the first one
;;               (when  (and terminal-style (terminal-style-bg-color terminal-style) (> content-w 0) (> content-h 0))
;;                 ;; (format t "TREE-RENDERER: Background fill - CONDITION PASSED, filling area")
;;                 ;; (format t "TREE-RENDERER: Background fill area: from (~A,~A) to (~A,~A)"
;;                 ;;         content-abs-x content-abs-y
;;                 ;;         (+ content-abs-x content-w -1) (+ content-abs-y content-h -1))
;;                 (loop for r from content-abs-y below (+ content-abs-y content-h)
;;                       do (loop for c from content-abs-x below (+ content-abs-x content-w)
;;                                when (and (>= r 0) (< r buffer-h) (>= c 0) (< c buffer-w))
;;                                  do (let ((bg-style (copy-term-style terminal-style)))
;;                                       (format t "TREE-RENDERER: Filling cell (~A,~A) with bg-color=~S"
;;                                               r c (terminal-style-bg-color bg-style))
;;                                       ;; Clear foreground for background-only cells
;;                                       (setf (terminal-style-fg-color bg-style) nil)
;;                                       (set-buffer-cell-at canvas-buffer r c #\Space bg-style)))))

;;               ;; 3. Render Content (e.g., text) within the content-box
;;               (when (and terminal-style (> content-w 0) (> content-h 0))
;;                 (case (ui-node-type node)
;;                   ((:text :drawable-content)
;;                    (let ((text (getf (ui-node-props node) :text "")))
;;                      (loop with current-x = 0
;;                            with current-y = 0
;;                            for char across text
;;                            do
;;                               (when (>= current-y content-h) (return))
;;                               (let ((target-r (+ content-abs-y current-y))
;;                                     (target-c (+ content-abs-x current-x)))
;;                                 (when (and (>= target-r 0) (< target-r buffer-h)
;;                                            (>= target-c 0) (< target-c buffer-w))
;;                                   (let* ((existing-style (buffer-cell-style (buffer-cell-at canvas-buffer target-r target-c)))
;;                                          (text-style (copy-term-style terminal-style)))
;;                                     ;; Inherit background if text style doesn't have one
;;                                     (unless (terminal-style-bg-color text-style)
;;                                       (setf (terminal-style-bg-color text-style)
;;                                             (when existing-style (terminal-style-bg-color existing-style))))
;;                                     (set-buffer-cell-at canvas-buffer target-r target-c char text-style))))
;;                               (incf current-x)
;;                               (when (>= current-x content-w) ; Wrap line
;;                                 (setf current-x 0)
;;                                 (incf current-y)))))))
;;               ;; Add other node types here as needed
;;               )))

;;         ;; DEBUG: Check cell at end of render
;;         ;; (let ((final-cell (buffer-cell-at canvas-buffer 0 0)))
;;         ;;   (format t "DEBUG: Cell (0,0) at END of render: ~S~%" final-cell)
;;         ;;   (format t "DEBUG: Cell bg-color at END of render: ~S~%"
;;         ;;           (when final-cell (terminal-style-bg-color (buffer-cell-style final-cell)))))

;;         ;; Recursively render children
;;         (dolist (child (ui-node-children node))
;;           (%render-node child canvas-buffer abs-x abs-y))))))
;;;; -----------------------------------------------------------------------
;;;;  tree-renderer/helpers.lisp
;;;; -----------------------------------------------------------------------

(in-package :elmtui.platform.tree-renderer)
(use-package :log4cl)            ; shorthand  (log:debug …)


;;; ─────────────────────────────────────────────────────────────────────────
;;;  Tiny utilities
;;; ─────────────────────────────────────────────────────────────────────────

(defun color-or-nil (raw &optional (bgp nil))
  "Safe wrapper around FUZZ-COLOR.
   Returns NIL instead of signalling when RAW cannot be coerced."
  (when raw
    (handler-case (fuzz-color raw bgp)
      (error () nil))))

(defun %abs-rect (parent-x parent-y rect)
  "Translate RECT (a GEO:RECTANGLE) by PARENT-X/Y.
   Returns five values: abs-x abs-y width height rect-ok-p."
  (if (and rect (typep rect 'rectangle))
      (values (+ parent-x (x rect))
              (+ parent-y (y rect))
              (w rect)
              (h rect)
              t)
      (values 0 0 0 0 nil)))

(defun %inside-buffer-p (buffer r c)
  (and (>= r 0) (< r (buffer-height buffer))
       (>= c 0) (< c (buffer-width  buffer))))

(defun %fill-rect (buffer x y w h char style)
  (loop for row below h
        do (loop for col below w
                 do (let ((rr (+ y row))
                          (cc (+ x col)))
                      (when (%inside-buffer-p buffer rr cc)
                        (set-buffer-cell-at buffer rr cc char style))))))


;;; ─────────────────────────────────────────────────────────────────────────
;;;  High-level predicates
;;; ─────────────────────────────────────────────────────────────────────────

(defun %visible-node-p (node width height)
  (let* ((style (styled-ui-node-style-map node))
         (vis   (getf style :visibility :visible))
         (disp  (getf style :display    :block)))
    (and (> width 0) (> height 0)
         (not (eq vis  :hidden))
         (not (eq disp :none)))))


;;; ─────────────────────────────────────────────────────────────────────────
;;;  Rendering helpers
;;; ─────────────────────────────────────────────────────────────────────────

(defun %render-background (buffer x y w h style)
  "Fill border-box with background colour, if any."
  (when (terminal-style-bg-color style)
    (log-debug "BG fill ~Ax~A at (~A,~A)" w h x y)
    (%fill-rect buffer x y w h #\Space style)))

(defun %draw-border-char (buffer r c ch base-style fg)
  (when (%inside-buffer-p buffer r c)
    (let* ((existing-style (buffer-cell-style (buffer-cell-at buffer r c)))
           (style          (copy-term-style (or existing-style base-style))))
      (setf (terminal-style-fg-color style) fg)
      (set-buffer-cell-at buffer r c ch style))))


(defun %draw-border (node buffer x y width height style)
  (let* ((smap             (styled-ui-node-style-map node))
         (border-style-val (getf smap :border-style :none)))
    (when (and (not (eq border-style-val :none)) ; nothing to draw
               style)
      ;; border widths (default 1 when style present)
      (flet ((bw (side) (if (eq border-style-val :none) 0
                            (getf smap side 1))))
        (let* ((btw (bw :border-top-width))
               (brw (bw :border-right-width))
               (bbw (bw :border-bottom-width))
               (blw (bw :border-left-width))
               (fg  (color-or-nil (or (getf smap :border-color)
                                      (terminal-style-fg-color style)))))
          (when fg
            (log-debug "Drawing border id=~A style=~A fg=~A"
                       (getf (ui-node-props node) :id) border-style-val fg)
            (destructuring-bind (&key h v tl tr bl br)
                (get-border-characters border-style-val)
              ;; horizontal
              (when (> btw 0)
                (loop for c from (if (> blw 0) 1 0)
                        below (- width (if (> brw 0) 1 0))
                      do (%draw-border-char buffer y       (+ x c) h style fg)))
              (when (> bbw 0)
                (loop for c from (if (> blw 0) 1 0)
                        below (- width (if (> brw 0) 1 0))
                      do (%draw-border-char buffer (+ y height -1) (+ x c) h style fg)))
              ;; vertical
              (when (> blw 0)
                (loop for r from (if (> btw 0) 1 0)
                        below (- height (if (> bbw 0) 1 0))
                      do (%draw-border-char buffer (+ y r) x               v style fg)))
              (when (> brw 0)
                (loop for r from (if (> btw 0) 1 0)
                        below (- height (if (> bbw 0) 1 0))
                      do (%draw-border-char buffer (+ y r) (+ x width -1)      v style fg)))
              ;; corners
              (when (and (> btw 0) (> blw 0)) (%draw-border-char buffer y             x               tl style fg))
              (when (and (> btw 0) (> brw 0)) (%draw-border-char buffer y             (+ x width -1)      tr style fg))
              (when (and (> bbw 0) (> blw 0)) (%draw-border-char buffer (+ y height -1) x               bl style fg))
              (when (and (> bbw 0) (> brw 0)) (%draw-border-char buffer (+ y height -1) (+ x width -1) br style fg)))))))))

(defun %render-content (node buffer x y w h style)
  (when (and style (> w 0) (> h 0))
    (case (ui-node-type node)
      ((:text :drawable-content)
       ;; simple left-to-right, top-to-bottom text renderer
       (loop with cur-x = 0
             with cur-y = 0
             for ch across (getf (ui-node-props node) :text "")
             do (when (>= cur-y h) (return))
                (let ((rr (+ y cur-y))
                      (cc (+ x cur-x)))
                  (when (%inside-buffer-p buffer rr cc)
                    (let* ((existing (buffer-cell-style (buffer-cell-at buffer rr cc)))
                           (ts (copy-term-style style)))
                      (unless (terminal-style-bg-color ts)
                        (setf (terminal-style-bg-color ts)
                              (when existing (terminal-style-bg-color existing))))
                      (set-buffer-cell-at buffer rr cc ch ts))))
                (incf cur-x)
                (when (>= cur-x w)
                  (setq cur-x 0)
                  (incf cur-y))))
      (t
       ;; extend with more node-types when ready
       nil))))


;;; ─────────────────────────────────────────────────────────────────────────
;;;  Public entry
;;; ─────────────────────────────────────────────────────────────────────────

(defun %render-node (node buffer parent-x parent-y)
  "Pure TEA-style renderer: consumes a laid-out STYLED-UI-NODE,
   mutates BUFFER, recurses on children, returns NIL."
  (when (typep node 'styled-ui-node)
    (multiple-value-bind (abs-x abs-y bw bh okp)
        (%abs-rect parent-x parent-y (getf (ui-node-props node) :layout-rect))
      (when (and okp
                 (%visible-node-p node bw bh))
        (let ((ts (convert-abstract-style-to-terminal-style node)))
          ;; pass 1 – background
          (%render-background buffer abs-x abs-y bw bh ts)
          ;; pass 2 – border
          (%draw-border       node buffer abs-x abs-y bw bh ts)
          ;; content box calculation
          (let* ((smap     (styled-ui-node-style-map node))
                 (btw      (getf smap :border-top-width    0))
                 (brw      (getf smap :border-right-width  0))
                 (bbw      (getf smap :border-bottom-width 0))
                 (blw      (getf smap :border-left-width   0))
                 (pad-t    (getf smap :padding-top    0))
                 (pad-r    (getf smap :padding-right 0))
                 (pad-b    (getf smap :padding-bottom 0))
                 (pad-l    (getf smap :padding-left  0))
                 (cx (+ abs-x blw pad-l))
                 (cy (+ abs-y btw pad-t))
                 (cw (max 0 (- bw blw brw pad-l pad-r)))
                 (ch (max 0 (- bh btw bbw pad-t pad-b))))
            ;; pass 3 – content
            (%render-content node buffer cx cy cw ch ts)))
        ;; recurse
        (dolist (child (ui-node-children node))
          (%render-node child buffer abs-x abs-y))))))

(define-stage render-laid-out-tree-to-buffer
    ((or null (cons styled-ui-node null)) ; Input: list with 0 or 1 laid-out styled-ui-node
     virtual-terminal-buffer)             ; Output: the buffer that was rendered to
    (laid-out-tree &key buffer)
  "Renders the laid-out UI tree to the virtual buffer (Stage 5)."
  (check-type buffer virtual-terminal-buffer)
  ;; (format t "TREE-RENDERER: Starting render to buffer.")
  ;; (format t "TREE-RENDERER DEBUG: laid-out-tree = ~A" laid-out-tree)
  ;; (format t "TREE-RENDERER DEBUG: first node = ~A" (first laid-out-tree))
  (clear-buffer buffer) ; Prepare canvas by clearing or resetting to default
  (%render-node (first laid-out-tree) buffer 0 0)
  (log-info "TREE-RENDERER: Finished render to buffer.")
  buffer)

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
;;                   (format t "TREE-RENDERER: Unknown border style '~A', defaulting to :solid." style))
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
