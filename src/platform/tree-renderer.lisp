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
   #:render-laid-out-tree-to-buffer
   #:style-property-capability
   #:style-property-capability-report))

(in-package :elmtui.platform.tree-renderer)

;; Terminal-tree capability contract. This intentionally lives with the
;; terminal painter, NOT in reusable cl-styles (which only validates syntax).
;; The four tiers describe the observable effect in this backend:
;; :rendered changes cells/paint order; :layout-only changes geometry;
;; :metadata-only is retained for higher-level widgets; :unimplemented has no
;; supported terminal effect. Qualified approximations are documented below.
(defparameter *style-property-capabilities*
  '((:rendered
     :display :visibility :overflow :white-space :color :background-color
     :attributes :bold :italic :underline :inverse :faint :blink :strike
     :invisible :border :border-width :border-top-width :border-right-width
     :border-bottom-width :border-left-width :border-style
     :border-top-style :border-right-style :border-bottom-style
     :border-left-style :border-color :border-top-color :border-right-color
     :border-bottom-color :border-left-color :z-index :opacity)
    (:layout-only
     :width :height :min-width :max-width :min-height :max-height
     :offset-x :offset-y :flex :flex-flow :flex-direction :flex-wrap
     :justify-content :align-items :align-self :align-content
     :gap :row-gap :column-gap :order :flex-grow :flex-shrink :flex-basis
     :grid-template-columns :grid-template-rows :grid-template-areas
     :grid-auto-flow :grid-auto-columns :grid-auto-rows :justify-items
     :padding :padding-top :padding-right :padding-bottom :padding-left
     :margin :margin-top :margin-right :margin-bottom :margin-left
     :aspect-ratio)
    (:metadata-only
     :scroll-x :scroll-y :font-family :font-size :font-weight :font-style
     :text-background-color)
    (:unimplemented :position :border-radius))
  "Exact ElmTUI terminal tree support classification of canonical cl-styles properties.")

(defun style-property-capability (property)
  "Return PROPERTY's ElmTUI terminal support tier, or NIL for unknown keys.
Also accepts registered cl-styles aliases. This is terminal-specific:
OPACITY is 0=hidden, 0<alpha<1=SGR faint, 1=opaque (no alpha blending);
Z-INDEX is stable sibling stacking, not full CSS stacking contexts."
  (let ((canonical (or (gethash property cl-styles.properties::*property-aliases*)
                       property)))
    (when (cl-styles.properties:property-definition canonical)
      (first (find-if (lambda (group) (member canonical (rest group)))
                      *style-property-capabilities*)))))

(defun style-property-capability-report ()
  "Return fresh (PROPERTY . TIER) pairs, including all registered properties."
  (sort (loop for property being the hash-keys
                of cl-styles.properties::*property-registry*
              collect (cons property (style-property-capability property)))
        #'string< :key (lambda (entry) (symbol-name (car entry)))))

(defun style-value (node key &optional default)
  (getf (element-style node) key default))

(defun get-border-characters (style)
  (case style
    (:solid   '(:h #\─ :v #\│ :tl #\┌ :tr #\┐ :bl #\└ :br #\┘))
    (:ascii   '(:h #\- :v #\| :tl #\+ :tr #\+ :bl #\+ :br #\+))
    (:double  '(:h #\═ :v #\║ :tl #\╔ :tr #\╗ :bl #\╚ :br #\╝))
    (:dashed  '(:h #\┄ :v #\┆ :tl #\┌ :tr #\┐ :bl #\└ :br #\┘))
    (:dotted  '(:h #\┈ :v #\┊ :tl #\┌ :tr #\┐ :bl #\└ :br #\┘))
    (t (get-border-characters :solid))))

(defvar *render-clip* nil
  "Absolute rectangle limiting renderer writes for the current node.
NIL preserves the historical buffer-only clipping behavior.")

(defun inside-buffer-p (buffer r c)
  (and (>= r 0) (< r (buffer-height buffer))
       (>= c 0) (< c (buffer-width buffer))
       (or (null *render-clip*)
           (and (>= r (y *render-clip*))
                (< r (+ (y *render-clip*) (h *render-clip*)))
                (>= c (x *render-clip*))
                (< c (+ (x *render-clip*) (w *render-clip*)))))))



(defun %content-geometry (node abs-x abs-y width height)
  "Return NODE's absolute content box as X, Y, WIDTH, HEIGHT values."
  (let* ((smap (elmtui.view.element:el/styles node))
         (btw (getf smap :border-top-width 0))
         (brw (getf smap :border-right-width 0))
         (bbw (getf smap :border-bottom-width 0))
         (blw (getf smap :border-left-width 0))
         (pad-t (getf smap :padding-top 0))
         (pad-r (getf smap :padding-right 0))
         (pad-b (getf smap :padding-bottom 0))
         (pad-l (getf smap :padding-left 0)))
    (values (+ abs-x blw pad-l)
            (+ abs-y btw pad-t)
            (max 0 (- width blw brw pad-l pad-r))
            (max 0 (- height btw bbw pad-t pad-b)))))

(defun %rectangle-intersection (a b)
  "Return the absolute intersection of rectangles A and B.
A NIL rectangle means no inherited clipping; disjoint rectangles produce a
zero-sized rectangle so an empty intersection is not confused with no clip."
  (cond
    ((null a) b)
    ((null b) a)
    (t
     (let* ((left (max (x a) (x b)))
            (top (max (y a) (y b)))
            (right (min (+ (x a) (w a)) (+ (x b) (w b))))
            (bottom (min (+ (y a) (h a)) (+ (y b) (h b)))))
       (elmtui.view.geo:make-rectangle
        :pos (elmtui.view.geo:make-pos :x left :y top)
        :size (elmtui.view.geo:make-size
               :w (max 0 (- right left))
               :h (max 0 (- bottom top))))))))

(defun %child-render-clip (node inherited-clip content-rect)
  "Return the clipping rectangle inherited by NODE's descendants.
The maintained terminal renderer keeps descendant overflow visible by default,
which preserves historical source behavior.  Setting :OVERFLOW to :HIDDEN clips
descendants to NODE's content rectangle.  Nested hidden-overflow ancestors
compose by rectangle intersection; other overflow values retain visible
behavior for compatibility."
  (if (eq (style-value node :overflow :visible) :hidden)
      (%rectangle-intersection inherited-clip content-rect)
      inherited-clip))

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

(defun %border-side-style (base-style declarations side)
  "Use an edge-specific color, then :BORDER-COLOR, then text foreground.
Preserve the original node background and terminal attributes."
  (let* ((key (ecase side
                (:top :border-top-color)
                (:right :border-right-color)
                (:bottom :border-bottom-color)
                (:left :border-left-color)))
         (color (or (getf declarations key)
                    (getf declarations :border-color)))
         (style (copy-term-style base-style)))
    (when color
      (setf (terminal-style-fg-color style)
            (elmtui.platform.backend.common.ansi-styling:fuzz-color color)))
    style))

(defun %border-edge-pattern (declarations side common-style)
  (getf declarations
        (ecase side
          (:top :border-top-style)
          (:right :border-right-style)
          (:bottom :border-bottom-style)
          (:left :border-left-style))
        common-style))

(defun draw-border (node buffer x y width height style)
  (let* ((smap (elmtui.view.element:el/styles node))
         (border-t (getf smap :border nil))
         (border-style-val
           (getf smap :border-style :solid)))
    (when (and border-t style
               (or (not (eq border-style-val :none))
                   (some (lambda (key)
                           (let ((value (getf smap key)))
                             (and value (not (eq value :none)))))
                         '(:border-top-style :border-right-style
                           :border-bottom-style :border-left-style))))
      (let* ((border-width (getf smap :border-width 1))
             (btw (getf smap :border-top-width border-width))
             (brw (getf smap :border-right-width border-width))
             (bbw (getf smap :border-bottom-width border-width))
             (blw (getf smap :border-left-width border-width))
             (top-style (%border-side-style style smap :top))
             (right-style (%border-side-style style smap :right))
             (bottom-style (%border-side-style style smap :bottom))
             (left-style (%border-side-style style smap :left))
             (top-pattern (%border-edge-pattern smap :top border-style-val))
             (right-pattern (%border-edge-pattern smap :right border-style-val))
             (bottom-pattern (%border-edge-pattern smap :bottom border-style-val))
             (left-pattern (%border-edge-pattern smap :left border-style-val))
             (top-p (and (> btw 0) (not (eq top-pattern :none))))
             (right-p (and (> brw 0) (not (eq right-pattern :none))))
             (bottom-p (and (> bbw 0) (not (eq bottom-pattern :none))))
             (left-p (and (> blw 0) (not (eq left-pattern :none))))
             (tc (get-border-characters top-pattern))
             (rc (get-border-characters right-pattern))
             (bc (get-border-characters bottom-pattern))
             (lc (get-border-characters left-pattern)))
        (flet ((corner (row col horizontal-p vertical-p horizontal vertical
                       horizontal-corner horizontal-style vertical-style)
                 (cond
                   ((and horizontal-p vertical-p)
                    (draw-border-char buffer row col horizontal-corner
                                      horizontal-style))
                   (horizontal-p
                    (draw-border-char buffer row col horizontal horizontal-style))
                   (vertical-p
                    (draw-border-char buffer row col vertical vertical-style)))))
          (when top-p
            (loop for c from (if left-p 1 0)
                  below (- width (if right-p 1 0))
                  do (draw-border-char buffer y (+ x c) (getf tc :h) top-style)))
          (when bottom-p
            (loop for c from (if left-p 1 0)
                  below (- width (if right-p 1 0))
                  do (draw-border-char buffer (+ y height -1) (+ x c)
                                       (getf bc :h) bottom-style)))
          (when left-p
            (loop for r from (if top-p 1 0)
                  below (- height (if bottom-p 1 0))
                  do (draw-border-char buffer (+ y r) x (getf lc :v) left-style)))
          (when right-p
            (loop for r from (if top-p 1 0)
                  below (- height (if bottom-p 1 0))
                  do (draw-border-char buffer (+ y r) (+ x width -1)
                                       (getf rc :v) right-style)))
          (corner y x top-p left-p (getf tc :h) (getf lc :v)
                  (getf tc :tl) top-style left-style)
          (corner y (+ x width -1) top-p right-p (getf tc :h) (getf rc :v)
                  (getf tc :tr) top-style right-style)
          (corner (+ y height -1) x bottom-p left-p
                  (getf bc :h) (getf lc :v) (getf bc :bl)
                  bottom-style left-style)
          (corner (+ y height -1) (+ x width -1) bottom-p right-p
                  (getf bc :h) (getf rc :v) (getf bc :br)
                  bottom-style right-style))))))

(defun %render-string-content (content buffer x y w h style white-space)
  "Paint Unicode clusters as intact glyphs; #\Null reserves wide-cell tails.
NFC normalizes composable accents; remaining multi-codepoint clusters live in
the lead buffer cell's GRAPHEME slot and are emitted together by the diff."
  (let ((text (sb-unicode:normalize-string content :nfc))
        (nowrap (eq white-space :nowrap))
        (col 0)
        (row 0))
    (labels ((paint-cell (ch rr cc &optional grapheme)
               (when (inside-buffer-p buffer rr cc)
                 (let* ((old (buffer-cell-style (buffer-cell-at buffer rr cc)))
                        (next (copy-term-style style)))
                   (unless (terminal-style-bg-color next)
                     (setf (terminal-style-bg-color next)
                           (and old (terminal-style-bg-color old))))
                   (set-buffer-cell-at buffer rr cc ch next
                                       :grapheme grapheme)))))
      (loop for (cluster . cluster-columns)
              in (elmtui.view.layout.size-utils:terminal-graphemes text)
            for ch = (char cluster 0)
            do
        (when (>= row h) (return))
        (when (and (char= ch #\Newline) (not nowrap))
          (setf col 0 row (1+ row)))
        (unless (char= ch #\Newline)
          (let ((columns (if (char= ch #\Tab)
                             (- 8 (mod col 8))
                             cluster-columns)))
            (when (> columns 0)
              (when (> (+ col columns) w)
                (if nowrap
                    (return)
                    (setf col 0 row (1+ row))))
              (when (>= row h) (return))
              (when (<= columns w)
                (if (char= ch #\Tab)
                    (dotimes (i columns)
                      (paint-cell #\Space (+ y row) (+ x col i)))
                    (when (and (inside-buffer-p buffer (+ y row) (+ x col))
                               (or (= columns 1)
                                   (inside-buffer-p buffer (+ y row)
                                                    (+ x col columns -1))))
                      (paint-cell ch (+ y row) (+ x col)
                                  (and (> (length cluster) 1) cluster))
                      (dotimes (i (1- columns))
                        (paint-cell #\Null (+ y row) (+ x col i 1)))))
                (incf col columns)
                (when (and (not nowrap) (>= col w))
                  (setf col 0 row (1+ row)))))))))))

(defun render-content (node buffer x y w h style)
  (when (and style (> w 0) (> h 0))
    (let* ((smap (elmtui.view.element:el/styles node))
           (white-space (getf smap :white-space :normal)))
      (case (element-type node)
        (:text
         (%render-string-content
          (text-content node) buffer x y w h style white-space))
        (:image
         (let* ((alt (getf (elmtui.view.element:el/props node) :alt ""))
                (fallback (if (and (stringp alt) (plusp (length alt)))
                              alt
                              "[image]")))
           (%render-string-content
            fallback buffer x y w h style white-space)))))))

(defvar *absolute-layout-rectangles-p* nil
  "Pipeline lists have absolute layout rects; direct legacy node tests use local rects.")

(defvar *render-effective-opacity* 1
  "Product of ancestor and node opacity for terminal approximation.
No alpha blending exists on a terminal: partial opacity maps to SGR faint.")

(defun %paint-order-children (node)
  "Stable sibling-only z-index ordering; equal indices keep source order.
All descendants retain their parent's clipping and stacking context."
  (stable-sort (copy-list (elmtui.view.element:el/children node))
               #'<
               :key (lambda (child)
                      (let ((z (getf (elmtui.view.element:el/styles child)
                                     :z-index 0)))
                        (if (realp z) z 0)))))

(defun render-node (node buffer parent-x parent-y &optional inherited-clip)
  "Paint nodes according to the active layout rectangle coordinate contract."
  (log-debug "Rendering node ~A of type ~A, typep ~A"
             node (type-of node) (typep node 'base-element))
  (if (listp node)
      (dolist (n node)
        (render-node n buffer parent-x parent-y inherited-clip))
      (if (typep node 'base-element)
          (let ((rect (elmtui.view.element:el/layout-rect node)))
            (log-debug "Rendering node ~A with canvas origin (~A, ~A) rect ~A"
                       node parent-x parent-y rect)
            (when rect
              (let* ((abs-x (+ parent-x (x rect)))
                     (abs-y (+ parent-y (y rect)))
                     (bw (w rect))
                     (bh (h rect)))
                (let ((*render-effective-opacity*
                        (* *render-effective-opacity*
                           (or (style-value node :opacity nil) 1))))
                  (when (and (plusp *render-effective-opacity*)
                             (visible-node-p node bw bh))
                  (multiple-value-bind (cx cy cw ch)
                      (%content-geometry node abs-x abs-y bw bh)
                    (let ((*render-clip* inherited-clip)
                          (ts (style-to-terminal-style
                               (elmtui.view.element:el/styles node))))
                      (when ts
                        (when (< *render-effective-opacity* 1)
                          (setf (terminal-style-faint ts) t))
                        (render-background buffer abs-x abs-y bw bh ts)
                        (draw-border node buffer abs-x abs-y bw bh ts)
                        (render-content node buffer cx cy cw ch ts)))
                    (let* ((content-rect
                             (elmtui.view.geo:make-rectangle
                              :pos (elmtui.view.geo:make-pos :x cx :y cy)
                              :size (elmtui.view.geo:make-size :w cw :h ch)))
                           (child-clip
                             (%child-render-clip node inherited-clip content-rect)))
                      (dolist (child (%paint-order-children node))
                        (render-node
                         child buffer
                         (if *absolute-layout-rectangles-p* parent-x abs-x)
                         (if *absolute-layout-rectangles-p* parent-y abs-y)
                         child-clip)))))))))
          (log-debug "Skipping non-element node ~A of type ~A"
                     node (type-of node)))))

(defun render-laid-out-tree-to-buffer
    (laid-out-tree &key buffer (origin-x 0) (origin-y 0) (clear-buffer-p t))
  (check-type buffer virtual-terminal-buffer)
  (let ((*absolute-layout-rectangles-p* (listp laid-out-tree)))
    (when clear-buffer-p
      (clear-buffer buffer))
    (render-node laid-out-tree buffer origin-x origin-y)
    buffer))
