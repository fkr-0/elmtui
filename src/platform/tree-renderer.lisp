(uiop:define-package :elmtui.platform.tree-renderer
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.view.base-elements
                #:base-element #:element-children #:element-style #:element-layout
                #:element-type #:text-content #:element-id)
  (:import-from :elmtui.view.geo #:rectangle #:pos #:size #:x #:y #:w #:h)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer #:set-buffer-cell-at #:buffer-cell-at
                #:buffer-cell-style #:buffer-width #:buffer-height #:clear-buffer)
  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:copy-term-style #:make-terminal-style #:copy-terminal-style
                #:terminal-style-fg-color #:terminal-style-bg-color #:terminal-style-bold
                #:terminal-style-italic #:terminal-style-underline #:terminal-style-inverse
                #:terminal-style-faint #:terminal-style-blink #:terminal-style-strike
                #:terminal-style-invisible #:style-to-terminal-style)
  (:export
   #:render-laid-out-tree-to-buffer))

(in-package :elmtui.platform.tree-renderer)

(defun style-value (node key &optional default)
  (getf (element-style node) key default))

(defun get-border-characters (style)
  (case style
    (:solid   '(:h #\─ :v #\│ :tl #\┌ :tr #\┐ :bl #\└ :br #\┘))
    (:ascii   '(:h #\- :v #\| :tl #\+ :tr #\+ :bl #\+ :br #\+))
    (:double  '(:h #\═ :v #\║ :tl #\╔ :tr #\╗ :bl #\╚ :br #\╝))
    (t (get-border-characters :solid))))

(defun inside-buffer-p (buffer r c)
  (and (>= r 0) (< r (buffer-height buffer))
       (>= c 0) (< c (buffer-width  buffer))))

(defun fill-rect (buffer x y w h char style)
  (loop for row below h
        do (loop for col below w
                 do (let ((rr (+ y row))
                          (cc (+ x col)))
                      (when (inside-buffer-p buffer rr cc)
                        (set-buffer-cell-at buffer rr cc char style))))))

(defun draw-border-char (buffer r c ch base-style)
  (when (inside-buffer-p buffer r c)
    (let* ((existing-style (buffer-cell-style (buffer-cell-at buffer r c)))
           (style (copy-term-style (or existing-style base-style))))
      (setf (terminal-style-fg-color style) (terminal-style-fg-color base-style))
      (set-buffer-cell-at buffer r c ch style))))

(defun visible-node-p (node width height)
  (let* ((style (element-style node))
         (vis (getf style :visibility :visible))
         (disp (getf style :display :block)))
    (and (> width 0) (> height 0)
         (not (eq vis :hidden))
         (not (eq disp :none)))))

(defun render-background (buffer x y w h style)
  (when (and style (terminal-style-bg-color style))
    (fill-rect buffer x y w h #\Space style)))

(defun draw-border (node buffer x y width height style)
  (let* ((smap (elmtui.view.element:el/styles node))
         (border-t (getf smap :border nil))
         (border-style-val
           (getf smap :border-style :solid)))
    (when (and border-t (not (eq border-style-val :none)) style)
      (let* ((border-width (if (eq border-style-val :none) 0 (getf smap :border-width 1)))
             (btw (getf smap :border-top-width border-width))
             (brw (getf smap :border-right-width border-width))
             (bbw (getf smap :border-bottom-width border-width))
             (blw (getf smap :border-left-width border-width))
             (border-style (style-to-terminal-style
                            (elmtui.view.element:el/styles node))))
        (destructuring-bind (&key h v tl tr bl br) (get-border-characters border-style-val)
          (when (> btw 0) (loop for c from (if (> blw 0) 1 0)
                                  below (- width (if (> brw 0) 1 0))
                                do (draw-border-char
                                    buffer y (+ x c) h border-style)))
          (when (> bbw 0) (loop for c from (if (> blw 0) 1 0)
                                  below (- width (if (> brw 0) 1 0))
                                do (draw-border-char
                                    buffer (+ y height -1) (+ x c) h border-style)))
          (when (> blw 0) (loop for r from (if (> btw 0) 1 0)
                                  below (- height (if (> bbw 0) 1 0))
                                do (draw-border-char
                                    buffer (+ y r) x v border-style)))
          (when (> brw 0) (loop for r from (if (> btw 0) 1 0)
                                  below (- height (if (> bbw 0) 1 0))
                                do (draw-border-char
                                    buffer (+ y r) (+ x width -1) v border-style)))
          (when (and (> btw 0) (> blw 0))
            (draw-border-char buffer y x tl border-style))
          (when (and (> btw 0) (> brw 0))
            (draw-border-char buffer y (+ x width -1) tr border-style))
          (when (and (> bbw 0) (> blw 0))
            (draw-border-char buffer (+ y height -1) x bl border-style))
          (when (and (> bbw 0) (> brw 0))
            (draw-border-char
             buffer (+ y height -1) (+ x width -1) br border-style)))))))

(defun render-content (node buffer x y w h style)
  (when (and style (> w 0) (> h 0))
    (case (element-type node)
      (:text
       (let* ((smap (elmtui.view.element:el/styles node))
              (white-space (getf smap :white-space :normal)))
         (cond
           ;; Truncate: draw a single line clipped to width
           ((eq white-space :nowrap)
            (loop for i from 0 below (min (length (text-content node)) w)
                  for ch = (aref (text-content node) i)
                  do (let ((rr y) (cc (+ x i)))
                       (when (inside-buffer-p buffer rr cc)
                         (let* ((existing-style (buffer-cell-style (buffer-cell-at buffer rr cc)))
                                (new-style (copy-term-style style)))
                           (unless (terminal-style-bg-color new-style)
                             (setf (terminal-style-bg-color new-style)
                                   (when existing-style (terminal-style-bg-color existing-style))))
                           (set-buffer-cell-at buffer rr cc ch new-style))))))
           ;; Wrap by width into multiple rows up to h rows
           (t
            (loop with cur-x = 0 and cur-y = 0
                  for ch across (text-content node)
                  do (when (>= cur-y h) (return))
                     (let ((rr (+ y cur-y)) (cc (+ x cur-x)))
                       (when (inside-buffer-p buffer rr cc)
                         (let* ((existing-style (buffer-cell-style (buffer-cell-at buffer rr cc)))
                                (new-style (copy-term-style style)))
                           (unless (terminal-style-bg-color new-style)
                             (setf (terminal-style-bg-color new-style)
                                   (when existing-style (terminal-style-bg-color existing-style))))
                           (set-buffer-cell-at buffer rr cc ch new-style))))
                     (incf cur-x)
                     (when (>= cur-x w)
                       (setq cur-x 0)
                       (incf cur-y))))))))))

(defun render-node (node buffer parent-x parent-y)
  (log-debug "Rendering node ~A of type ~A, typep ~A"
            node
            (type-of node)
            (typep node 'base-element))
  (if (listp node)
      (dolist (n node)
        (render-node n buffer parent-x parent-y))
      (if (typep node 'base-element)
          (let ((rect (elmtui.view.element:el/layout-rect node)))
            (log-debug "Rendering node ~A at parent pos (~A, ~A) with rect ~A"
                      node parent-x parent-y rect)
            (when rect
              (let* ((abs-x (+ parent-x (x rect)))
                     (abs-y (+ parent-y (y rect)))
                    (bw (w rect))
                    (bh (h rect)))
                (when (visible-node-p node bw bh)
                  (let ((ts (style-to-terminal-style (elmtui.view.element:el/styles node))))
                    (when ts
                      (render-background buffer abs-x abs-y bw bh ts)
                      (draw-border node buffer abs-x abs-y bw bh ts)
                      (let* ((smap (elmtui.view.element:el/styles node))
                             (btw (getf smap :border-top-width 0)) (brw (getf smap :border-right-width 0))
                             (bbw (getf smap :border-bottom-width 0)) (blw (getf smap :border-left-width 0))
                             (pad-t (getf smap :padding-top 0)) (pad-r (getf smap :padding-right 0))
                             (pad-b (getf smap :padding-bottom 0)) (pad-l (getf smap :padding-left 0))
                             (cx (+ abs-x blw pad-l)) (cy (+ abs-y btw pad-t))
                             (cw (max 0 (- bw blw brw pad-l pad-r)))
                             (ch (max 0 (- bh btw bbw pad-t pad-b))))
                        (render-content node buffer cx cy cw ch ts))))
                  (dolist (child (elmtui.view.element:el/children node))
                    (render-node child buffer abs-x abs-y))))))
          (log-debug "Skipping non-element node ~A of type ~A" node (type-of node)))))

(defun render-laid-out-tree-to-buffer (laid-out-tree &key buffer (origin-x 0) (origin-y 0) (clear-buffer-p t))
  (check-type buffer virtual-terminal-buffer)
  (when clear-buffer-p
    (clear-buffer buffer))
  (render-node laid-out-tree buffer origin-x origin-y)
  buffer)
