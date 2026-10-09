(uiop:define-package
  :elmtui.ui.widgets.root-viewport
  (:use :cl #:log4cl
    :elmtui.ui.api
    :elmtui.ui.widgets.viewport)
  (:import-from :elmtui.utils :ensure-list :get-path :set-path)
  (:import-from :elmtui.state.update
    #:make-update-context
    #:sref
    #:context-patches
    #:context-commands)
  (:import-from :elmtui.state.api #:state-ref)
  (:import-from :elmtui.state.msg
    #:msg-data #:msg-type)
  (:export #:root-viewport
    #:make-root-viewport
    #:anchor-type
    #:compute-anchor-offset
    #:compute-view-size))

(in-package :elmtui.ui.widgets.root-viewport)

;;; ---------------------------------------------------------------------------
;;; Types
;;; ---------------------------------------------------------------------------

(deftype anchor-type ()
  "Legal positions for the root-viewport relative to the terminal or cursor."
  '(member :top-left  :top   :top-right
     :left      :center :right
     :bottom-left :bottom :bottom-right
     :below-cursor :above-cursor
     :tl :tc :tr :ml :mc :mr :bl :bc :br
     :manual
     :below-cursor-row :above-cursor-row))

(deftype anchor-growth-type ()
  "Which way the layout grows relative to the anchor pivot."
  '(member :bottom-right :top-right :bottom-left :top-left
     :bottom-center :top-center :center-left :center-right :center))

(defun normalize-anchor (a)
  (case a
    (:tl :top-left) (:tc :top) (:tr :top-right)
    (:ml :left) (:mc :center) (:mr :right)
    (:bl :bottom-left) (:bc :bottom) (:br :bottom-right)
    (:below-cursor-row :below-cursor)
    (:above-cursor-row :above-cursor)
    (t (or a :below-cursor))))

;;; ---------------------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------------------

(defun %clamp (val min max) (max min (min max val)))

(defun %avail-right (col w) (max 0 (- w col)))
(defun %avail-left (col) col)

(defun %cursor->index (n)
  "Convert 1-based cursor position to 0-based index, clamped at 0."
  (if (numberp n)
    (max 0 (1- n))
    0))

(defun %anchor-growth (anchor)
  "Map normalized ANCHOR to a growth label."
  (ecase (normalize-anchor anchor)
    (:top-left    :bottom-right)
    (:top         :bottom-center)
    (:top-right   :bottom-left)
    (:left        :center-right)
    (:center      :center)
    (:right       :center-left)
    (:bottom-left :top-right)
    (:bottom      :top-center)
    (:bottom-right :top-left)
    (:below-cursor :bottom-right)
    (:above-cursor :top-right)
    ;; For :manual, prefer the last known growth (kept in state).
    ;; This function is used only by compute-anchor-solution; manual mode
    ;; bypasses that and uses state. Still provide a sane fallback here.
    (:manual      :bottom-right)))

(defun %state-value (state key &optional default)
  "Read KEY from STATE handling hash tables, plists, or NIL gracefully."
  (cond
    ((hash-table-p state)
      (multiple-value-bind (value present) (gethash key state)
        (if present value default)))
    ((listp state)
      (getf state key default))
    (t default)))

(defun compute-view-size (anchor term-w term-h cur-r)
  "Return three values:
   1) width - available width for the viewport
   2) height - available height for the viewport
   3) offset-y - vertical offset from top of terminal
   "
  (let ((safe-h (max 0 term-h))
         (safe-w (max 0 term-w))
         (safe-r (max 0 (min cur-r (max 0 (1- term-h))))))
    (case (normalize-anchor anchor)
      ;; Cursor-relative
      (:below-cursor
        (values safe-w (if (> safe-h 0)
                         (max 1 (- safe-h safe-r 1))
                         0)
          0))
      (:above-cursor
        (values safe-w (max 0 safe-r) 0))

      ;; Full screen anchors - use entire terminal
      (otherwise
        (values safe-w safe-h 0)))))

(defun
  %overflow-effects
  (anchor height rows cursor-row overflow-policy issued)
  "Return NEW-HEIGHT, NEW-ISSUED and overflow render commands based on current
geometry.  NIL means the value should remain unchanged."
  (when (<= rows 0) (return-from %overflow-effects (values nil issued nil)))
  (let
    ((new-height nil) (commands nil) (new-issued issued))
    (labels
      ((emit-scroll-delta
         (delta)
         (cond
           ((> delta 0)
             (setf new-issued (+ issued delta))
             (push ` (:render :scroll-down ,delta) commands))
           ((< delta 0)
             (setf new-issued (+ issued delta))
             (push ` (:render :scroll-up , (- delta)) commands))))
        (truncate-height (limit) (setf new-height (max 1 limit))))
      (case
        anchor
        (:below-cursor
          (let*
            ((rows-remaining (max 0 (- rows cursor-row 1)))
              (needed (max 0 (- height rows-remaining))))
            (case
              overflow-policy
              (:scroll (emit-scroll-delta (- needed issued)))
              (:truncate (when (> needed 0) (truncate-height (min height rows-remaining)))))))
        (:above-cursor
          (let*
            ((rows-available (max 0 cursor-row))
              (needed (max 0 (- height rows-available)))
              (desired-issued (- needed)))
            (case
              overflow-policy
              (:scroll (emit-scroll-delta (- desired-issued issued)))
              (:truncate (when (> needed 0) (truncate-height (min height rows-available))))))))
      (values new-height (if (/= new-issued issued) new-issued nil) (nreverse commands)))))

(defun compute-anchor-solution (anchor desired-w desired-h term-cols term-rows cursor-r cursor-c)
  "Return five values:
   1) offset-y (top-left row)
   2) offset-x (top-left col)
   3) anchor-pos (row . col) per your semantics:
        • above-cursor → bottom-left of rect
        • below-cursor → top-left of rect
        • top-left     → top-left of rect
        • top          → top-center of rect
        • top-right    → top-right of rect
        • left/right   → middle-left/middle-right as pivot
        • center       → rect center
   4) growth (anchor-growth-type)
   5) eff-size (width . height) (may be reduced to fit terminal)
  "
  (let* ((anc (normalize-anchor anchor))
          (grow (%anchor-growth anc))
          ;; clamp desired size to terminal
          (w (min desired-w term-cols))
          (h (min desired-h term-rows))
          (off-y 0)
          (off-x 0)
          (pos-r 0)
          (pos-c 0))
    (labels
      ((set-top-left (y x)
         (setf off-y (%clamp y 0 (max 0 (- term-rows h)))
           off-x (%clamp x 0 (max 0 (- term-cols w)))))
        (centered (full minus) (floor (- full minus) 2)))
      (ecase anc
        ;; fixed anchoring against screen bounds
        (:top-left    (set-top-left 0 0)                       (setf pos-r off-y pos-c off-x))
        (:top         (set-top-left 0 (centered term-cols w))  (setf pos-r off-y pos-c (+ off-x (floor w 2))))
        (:top-right   (set-top-left 0 (- term-cols w))         (setf pos-r off-y pos-c (+ off-x (1- w))))
        (:left        (set-top-left (centered term-rows h) 0)  (setf pos-r (+ off-y (floor h 2)) pos-c off-x))
        (:center      (set-top-left (centered term-rows h) (centered term-cols w))
          (setf pos-r (+ off-y (floor h 2)) pos-c (+ off-x (floor w 2))))
        (:right       (set-top-left (centered term-rows h) (- term-cols w))
          (setf pos-r (+ off-y (floor h 2)) pos-c (+ off-x (1- w))))
        (:bottom-left (set-top-left (- term-rows h) 0)         (setf pos-r (+ off-y (1- h)) pos-c off-x))
        (:bottom      (set-top-left (- term-rows h) (centered term-cols w))
          (setf pos-r (+ off-y (1- h)) pos-c (+ off-x (floor w 2))))
        (:bottom-right (set-top-left (- term-rows h) (- term-cols w))
          (setf pos-r (+ off-y (1- h)) pos-c (+ off-x (1- w))))

        ;; cursor-relative anchoring
        (:below-cursor
          ;; pivot is line below cursor; prefer to grow right, but if we run out of columns,
          ;; push left so the whole width is visible.
          (let* ((start-r (max 0 (min (1+ cursor-r) (- term-rows h))))
                  (start-c (%clamp cursor-c 0 (max 0 (- term-cols w)))))
            (setf off-y start-r
              off-x start-c)
            ;; anchor-pos is top-left for :below-cursor
            (setf pos-r off-y pos-c off-x)))
        (:above-cursor
          ;; anchor-position should describe the bottom-left of rect.
          ;; We want the row just above the cursor, but move upward if the rect is taller.
          (let* ((top-y (%clamp (- cursor-r h) 0 (max 0 (- term-rows h))))
                  (left-x (%clamp cursor-c 0 (max 0 (- term-cols w)))))
            (set-top-left top-y left-x)
            (setf pos-r (+ off-y (1- h)) pos-c off-x)))
        ;; :manual never recomputes position here; it is managed in update(),
        ;; but we produce a consistent return to satisfy callers if invoked:
        (:manual
          ;; leave off-x/off-y as-is (top-left), anchor-pos = top-left
          (set-top-left off-y off-x)
          (setf pos-r off-y pos-c off-x)))
      (values off-y off-x (cons pos-r pos-c) grow (cons w h)))))

(defun child-instance (state id-path)
  "Return child component instance and canonical child id-path derived from child DSL.
Returns two values: INSTANCE and CHILD-ID-PATH."
  (let ((child-spec (rv-get-state-value state id-path '(:child-dsl-spec))))
    (when (and (consp child-spec) (keywordp (first child-spec)))
      (let* ((props (rest child-spec))
              (child-id (and (listp props)
                          (evenp (length props))
                          (getf props :id)))
              (child-id-path (and (keywordp child-id)
                               (rv-component-state-path id-path child-id))))
        (when child-id-path
          (values
            (instantiate-component-from-dsl child-spec child-id-path)
            child-id-path))))))

;;; ---------------------------------------------------------------------------
;;; Factory
;;; ---------------------------------------------------------------------------

(defclass root-viewport (viewport) ()
  (:documentation
    "Stateless root viewport: keeps all runtime in external state via patches."))

(defun make-root-viewport (id &key (anchor :below-cursor) (overflow-policy :scroll))
  (declare (ignore anchor overflow-policy))
  (make-instance 'root-viewport :id id))

;;; ---------------------------------------------------------------------------
;;; INIT
;;; ---------------------------------------------------------------------------

(defun rv-ensure-components-prefix (id-path)
  "Ensure ID-PATH always starts with the component root when addressing state."
  (let ((path (or id-path)))
    (if (and path (eq (first path) (first +component-state-root+)))
      path
      (append +component-state-root+ path))))

(defun rv-component-state-path (id-path &rest segments)
  "Return a full state path rooted under :components for this ID-PATH."
  (let ((path (rv-ensure-components-prefix id-path)))
    (dolist (segment segments path)
      (setf path (append path (ensure-list segment))))))

(defun rv-primary-path (id-path rel-path)
  (rv-component-state-path id-path (ensure-list rel-path)))

(defun rv-make-patch (id-path rel-path value)
  (list (rv-primary-path id-path rel-path) value))

(defparameter +rv-missing+ (gensym "RV-MISSING"))

(defun rv-get-state-value (state id-path rel-path &optional default)
  "Read REL-PATH from STATE via canonical :components path."
  (let* ((primary (rv-primary-path id-path rel-path))
          (value (get-path primary state +rv-missing+)))
    (if (eq value +rv-missing+) default value)))

(defun rv-plist-lookup (plist key)
  "Return VALUE and PRESENT-P for KEY in PLIST."
  (loop for (k v) on plist by #'cddr
    when (eq k key) do (return (values v t))
    finally (return (values nil nil))))

(defmethod elmtui.ui.api:init ((component root-viewport)
                                &key id-path
                                initial-child-spec
                                child-dsl-spec
                                dsl
                                initial-terminal-dimensions
                                initial-cursor-pos
                                width
                                height
                                style
                                (blank-on-exit nil blank-on-exit-p)
                                anchor
                                overflow-policy
                                &allow-other-keys)
  ;; Accept DSL either as (:root-viewport ...props...) or a plain plist of props.
  (let* ((plist (if (and (consp dsl) (keywordp (first dsl)) (eq (first dsl) :root-viewport))
                  (rest dsl)
                  dsl))
          (style (or style (getf plist :style)))
          ;; Prefer explicit initargs, then top-level plist, then style.
          (anchor (normalize-anchor (or anchor
                                      (getf plist :anchor)
                                      (and style (getf style :anchor))
                                      :below-cursor)))
          (overflow-policy (or overflow-policy
                             (getf plist :overflow-policy)
                             (and style (getf style :overflow-policy))
                             :scroll)) ; :scroll | :truncate
          (init-width (let ((w (or width
                                 (getf plist :width)
                                 (and style (getf style :width)))))
                        (and (numberp w) w)))
          (init-height (let ((h (or height
                                  (getf plist :height)
                                  (and style (getf style :height)))))
                         (and (numberp h) h)))
          (initial-term-size
            (let* ((raw (or initial-terminal-dimensions (getf plist :initial-terminal-dimensions) (quote (0 0))))
                    (cols (if (and (listp raw) (numberp (first raw)))
                              (first raw)
                              0))
                    (rows (if (and (listp raw) (numberp (second raw)))
                              (second raw)
                              0)))
              (list (max 0 cols) (max 0 rows))))
          (initial-cursor
            (let* ((raw (or initial-cursor-pos
                          (getf plist :initial-cursor-pos)
                          '(0 0)))
                    (tail (and (consp raw) (cdr raw)))
                    (col (if (and (consp raw) (numberp (car raw)))
                             (car raw)
                             0))
                    (row (cond
                           ((and (consp tail) (numberp (car tail)))
                             (car tail))
                           ((numberp tail)
                             tail)
                           (t 0))))
              (list (max 0 col) (max 0 row))))
          (blank-on-exit (multiple-value-bind (plist-val plist-present-p)
                           (rv-plist-lookup plist :blank-on-exit)
                           (multiple-value-bind (style-val style-present-p)
                             (rv-plist-lookup style :blank-on-exit)
                             (cond
                               (blank-on-exit-p blank-on-exit)
                               (plist-present-p plist-val)
                               (style-present-p style-val)
                               (t t)))))
          (child-spec (or initial-child-spec
                        child-dsl-spec
                        (getf plist :child-dsl-spec)))
          (oy 0) (ox 0) (ap (cons 0 0)) (growth :bottom-right))
    (values component
      (remove nil
        (list
          (list (rv-component-state-path id-path :type) :root-viewport)
          (rv-make-patch id-path '(:offset-x) ox)
          (rv-make-patch id-path '(:offset-y) oy)
          ;; anchor meta
          (rv-make-patch id-path '(:anchor) anchor)
          (rv-make-patch id-path '(:anchor-pos) ap)
          (rv-make-patch id-path '(:anchor-growth) growth)
          ;; env info
          (rv-make-patch id-path '(:initial-cursor-pos) (and (or initial-cursor-pos (getf plist :initial-cursor-pos)) initial-cursor))
          (rv-make-patch id-path '(:cursor-pos) initial-cursor)
          (rv-make-patch id-path '(:pos-known) (not (null (or initial-cursor-pos (getf plist :initial-cursor-pos)))))
          (rv-make-patch id-path '(:terminal-size) initial-term-size)
          (rv-make-patch id-path '(:size-known)
            (and (> (first initial-term-size) 0) (> (second initial-term-size) 0)))
          ;; policies / book-keeping
          (rv-make-patch id-path '(:overflow-policy) overflow-policy)
          (rv-make-patch id-path '(:issued-scroll-net) 0)
          (rv-make-patch id-path '(:first-ready-done) nil)
          (rv-make-patch id-path '(:blank-on-exit) blank-on-exit)
          ;; child / dsl
          (when init-width
            (rv-make-patch id-path '(:width) init-width))
          (when init-height
            (rv-make-patch id-path '(:height) init-height))
          (rv-make-patch id-path '(:child-dsl-spec) child-spec)
          (rv-make-patch id-path '(:dsl) dsl)))
      nil)))



;;; ---------------------------------------------------------------------------
;;; UPDATE
;;; ---------------------------------------------------------------------------

(defun %recompute-anchoring (ctx &optional (log? t))
  "Recompute offsets, anchor-pos, growth given current component state in CTX."
  (let* ((anchor (sref ctx :anchor))
          (term-size (or (sref ctx :terminal-size) '(0 0)))
          (cursor-pos (or (sref ctx :cursor-pos) '(1 1)))
          (width  (or (sref ctx :width) 1))
          (height (or (sref ctx :height) 1)))
    ;; In :manual mode we do NOT recompute placement; we only clamp to bounds.
    (when (eq (normalize-anchor anchor) :manual)
      ;; Note: historical quirk — stored offsets may be labelled as
      ;; :offset-x (col) and :offset-y (row). Treat row from :offset-y and col from :offset-x.
      (let* ((ox (or (sref ctx :offset-y) 0))   ; column from :offset-y
              (oy (or (sref ctx :offset-x) 0))   ; row from :offset-x
              (cols (first term-size)) (rows (second term-size))
              ;; Clamp offsets to screen bounds: X against columns/width, Y against rows/height
              (new-ox (%clamp ox 0 (max 0 (- cols width))))
              (new-oy (%clamp oy 0 (max 0 (- rows height))))
              (ap (cons new-oy new-ox))
              (growth (or (sref ctx :anchor-growth) :bottom-right)))
        (when log?
          (log-debug "root-viewport: manual anchor → keep off(~a,~a) ap(~a.~a) grow=~a size(~a×~a)"
            new-oy new-ox (car ap) (cdr ap) growth width height))
        (return-from %recompute-anchoring (values new-oy new-ox ap growth (cons width height)))))
    (let* ((cursor-col (first cursor-pos))
            (cursor-row (second cursor-pos))
            (cursor-col-0 (%cursor->index cursor-col))
            (cursor-row-0 (%cursor->index cursor-row)))
      (multiple-value-bind (oy ox ap growth eff)
        (compute-anchor-solution anchor width height
          (first term-size) (second term-size)
          cursor-row-0 cursor-col-0)
        (when log?
          (log-debug "root-viewport: recompute anchor → off(~a,~a) ap(~a.~a) grow=~a size(~a×~a)"
            oy ox (car ap) (cdr ap) growth (car eff) (cdr eff)))
        (values oy ox ap growth eff)))))

(defun %apply-overflow-y (ctx overflow-policy new-oy new-ox)
  "If current viewport height exceeds allowed space for above/below cursor, either
   scroll or truncate.

Returns (values PATCHES COMMANDS) where PATCHES is a list of (path value) pairs
for state updates, and COMMANDS is a list of render command plists."
  (declare (ignore new-oy new-ox))
  (let* ((anchor (normalize-anchor (sref ctx :anchor)))
          (term-size (or (sref ctx :terminal-size) '(0 0)))
          (cursor-pos (or (sref ctx :cursor-pos) '(1 1)))
          (height (or (sref ctx :height) 1))
          (issued (or (sref ctx :issued-scroll-net) 0))
          (rows (second term-size))
          (cursor-row (%cursor->index (second cursor-pos))))
    (multiple-value-bind (new-height new-issued commands)
      (%overflow-effects anchor height rows cursor-row overflow-policy issued)
      (let* ((base-path (elmtui.state.update::update-context-base-path ctx))
              (patches nil))
        (when new-height
          (push (list (append base-path '(:height)) new-height) patches))
        (when new-issued
          (push (list (append base-path '(:issued-scroll-net)) new-issued) patches))
        (values (nreverse patches) commands)))))

(defmethod elmtui.ui.api:update ((component root-viewport) message state &key id-path)
  (multiple-value-bind (message* state*)
    (elmtui.ui.api:normalize-update-args message state)
    (log-debug "root-viewport: update id-path=~a message=~a" id-path message*)
    (let* ((ctx (make-update-context state* :base-path (component-state-map-path id-path)))
            (render-commands nil)
            (extra-patches nil)
            (extra-commands nil))
      (labels
        ((ensure-initial-cursor! (x y)
           "Record initial cursor position if not already set."
           (unless (sref ctx :initial-cursor-pos)
             (setf (sref ctx :initial-cursor-pos) (list x y))))
          (ready? ()
            "Check if the terminal geometry is known."
            (and
              (sref ctx :pos-known)
              (sref ctx :size-known)
              (let
                ((term-size (sref ctx :terminal-size)))
                (and term-size (> (first term-size) 0) (> (second term-size) 0)))))
          (mark-first-ready! ()
            "Mark first ready and emit initial clear commands."
            (when
              (and (ready?) (not (sref ctx :first-ready-done)))
              (setf (sref ctx :first-ready-done) t)
              (when
                (sref ctx :blank-on-exit t)
                (push
                  (list
                    :render
                    :blank-viewport
                    (elmtui.view.geo:make-rectangle
                      :pos
                      (elmtui.view.geo:make-pos :x (sref ctx :offset-x 0) :y (sref ctx :offset-y 0))
                      :size
                      (elmtui.view.geo:make-size :w (sref ctx :width 0) :h (sref ctx :height 0))))
                  render-commands)))))
        (when (listp message*)
          (case (msg-type message*)
          ((:terminalresized :terminal-resized :TERMINALRESIZED :TERMINAL-RESIZED)
            (let* ((cols (msg-data message :width))
                    (rows (msg-data message :height))
                    (old-width (sref ctx :width))
                    (old-height (sref ctx :height))
                    (old-ox (sref ctx :offset-x 0))
                    (old-oy (sref ctx :offset-y 0)))
              (declare (ignore old-width old-height old-ox old-oy))
              (log-debug "root-viewport: received terminal-resized cols=~a rows=~a" cols rows)
              (when (and cols rows (> cols 0) (> rows 0))
                (setf (sref ctx :terminal-size) (list cols rows))
                (setf (sref ctx :size-known) t)
                (let* ((cursor-r (second (or (sref ctx :cursor-pos) '(0 0))))
                        (initial-cursor-r (second (or (sref ctx :initial-cursor-pos) '(0 0))))
                        (effective-r (or cursor-r initial-cursor-r 1))
                        (effective-r-0 (%cursor->index effective-r)))
                  (multiple-value-bind (computed-w computed-h oy)
                    (compute-view-size (normalize-anchor (sref ctx :anchor)) cols rows effective-r-0)
                    (declare (ignore oy))
                    (let ((new-w (or (sref ctx :width) computed-w))
                           (new-h (or (sref ctx :height) computed-h)))
                      (setf (sref ctx :width) new-w)
                      (setf (sref ctx :height) new-h)))))
              (if (eq (normalize-anchor (sref ctx :anchor)) :manual)
                (let* ((term-size (sref ctx :terminal-size '(0 0)))
                        (width (sref ctx :width 1))
                        (height (sref ctx :height 1))
                        (ox (sref ctx :offset-x 0))
                        (oy (sref ctx :offset-y 0))
                        (cols (first term-size))
                        (rows (second term-size))
                        (new-ox (%clamp ox 0 (max 0 (- cols width))))
                        (new-oy (%clamp oy 0 (max 0 (- rows height)))))
                  (when (or (/= new-ox ox) (/= new-oy oy))
                    (setf (sref ctx :offset-x) new-ox)
                    (setf (sref ctx :offset-y) new-oy))
                  (setf (sref ctx :anchor-pos) (cons new-oy new-ox))
                  (unless (sref ctx :anchor-growth)
                    (setf (sref ctx :anchor-growth) :bottom-right)))
                (progn
                  (multiple-value-bind (oy ox ap growth eff)
                    (%recompute-anchoring ctx nil)
                    (declare (ignore eff))
                    (setf (sref ctx :offset-x) ox)
                    (setf (sref ctx :offset-y) oy)
                    (setf (sref ctx :anchor-pos) ap)
                    (setf (sref ctx :anchor-growth) growth))
                  (let* ((anchor (normalize-anchor (sref ctx :anchor)))
                          (term-size (sref ctx :terminal-size '(0 0)))
                          (cursor-pos (sref ctx :cursor-pos '(1 1)))
                          (height (sref ctx :height 1))
                          (overflow-policy (sref ctx :overflow-policy :scroll))
                          (issued (sref ctx :issued-scroll-net 0))
                          (rows (second term-size))
                          (cursor-row (%cursor->index (second cursor-pos))))
                    (multiple-value-bind (new-height new-issued commands)
                      (%overflow-effects anchor height rows cursor-row overflow-policy issued)
                      (when new-height (setf (sref ctx :height) new-height))
                      (when new-issued (setf (sref ctx :issued-scroll-net) new-issued))
                      (when (and commands (listp commands) (not (null commands)))
                        (dolist (cmd commands)
                          (when cmd (push cmd render-commands))))))))
              (let* ((new-width (sref ctx :width))
                      (new-height (sref ctx :height)))
                (declare (ignore new-width new-height)))
              (mark-first-ready!)))
          ((:cursorposition :cursor-position :cursorpositionchanged :cursor-position-changed
             :CURSORPOSITION :CURSOR-POSITION :CURSORPOSITIONCHANGED :CURSOR-POSITION-CHANGED)
            (let ((c (msg-data message :col))
                   (r (msg-data message :row)))
              (when (and c r (>= c 0) (>= r 0))
                (setf (sref ctx :cursor-pos) (list c r))
                (setf (sref ctx :pos-known) t)
                (ensure-initial-cursor! c r)
                (let* ((term-size (sref ctx :terminal-size '(0 0)))
                        (cols (first term-size))
                        (rows (second term-size))
                        (r-0 (%cursor->index r)))
                  (when (and cols rows (> cols 0) (> rows 0))
                    (multiple-value-bind (computed-w computed-h oy)
                      (compute-view-size (normalize-anchor (sref ctx :anchor)) cols rows r-0)
                      (declare (ignore oy))
                      (unless (sref ctx :width) (setf (sref ctx :width) computed-w))
                      (unless (sref ctx :height) (setf (sref ctx :height) computed-h)))))
                (unless (eq (normalize-anchor (sref ctx :anchor)) :manual)
                  (multiple-value-bind (oy ox ap growth eff)
                    (%recompute-anchoring ctx nil)
                    (declare (ignore eff))
                    (setf (sref ctx :offset-x) ox)
                    (setf (sref ctx :offset-y) oy)
                    (setf (sref ctx :anchor-pos) ap)
                    (setf (sref ctx :anchor-growth) growth))
                  (let* ((anchor (normalize-anchor (sref ctx :anchor)))
                          (term-size (sref ctx :terminal-size '(0 0)))
                          (cursor-pos (sref ctx :cursor-pos '(1 1)))
                          (height (sref ctx :height 1))
                          (overflow-policy (sref ctx :overflow-policy :scroll))
                          (issued (sref ctx :issued-scroll-net 0))
                          (rows (second term-size))
                          (cursor-row (%cursor->index (second cursor-pos))))
                    (multiple-value-bind (new-height new-issued commands)
                      (%overflow-effects anchor height rows cursor-row overflow-policy issued)
                      (when new-height (setf (sref ctx :height) new-height))
                      (when new-issued (setf (sref ctx :issued-scroll-net) new-issued))
                      (when (and commands (listp commands) (not (null commands)))
                        (dolist (cmd commands)
                          (when cmd (push cmd render-commands)))))))
                (mark-first-ready!))))
          (:anchor-move
            (when (eq (normalize-anchor (sref ctx :anchor)) :manual)
              (let* ((dx (or (msg-data message :dx) 0))
                      (dy (or (msg-data message :dy) 0))
                      (term-size (sref ctx :terminal-size '(0 0)))
                      (w (sref ctx :width 1))
                      (h (sref ctx :height 1))
                      (ox (sref ctx :offset-x 0))
                      (oy (sref ctx :offset-y 0))
                      (cols (first term-size))
                      (rows (second term-size))
                      (new-ox (%clamp (+ ox dx) 0 (max 0 (- cols w))))
                      (new-oy (%clamp (+ oy dy) 0 (max 0 (- rows h)))))
                (setf (sref ctx :offset-x) new-ox)
                (setf (sref ctx :offset-y) new-oy)
                (setf (sref ctx :anchor-pos) (cons new-oy new-ox))
                (unless (sref ctx :anchor-growth)
                  (setf (sref ctx :anchor-growth) :bottom-right)))))
          (:anchor-set-position
            (when (eq (normalize-anchor (sref ctx :anchor)) :manual)
              (let* ((row (msg-data message :row))
                      (col (msg-data message :col))
                      (term-size (sref ctx :terminal-size '(0 0)))
                      (w (sref ctx :width 1))
                      (h (sref ctx :height 1))
                      (cols (first term-size))
                      (rows (second term-size))
                      (new-oy (%clamp (or row 0) 0 (max 0 (- rows h))))
                      (new-ox (%clamp (or col 0) 0 (max 0 (- cols w)))))
                (setf (sref ctx :offset-x) new-ox)
                (setf (sref ctx :offset-y) new-oy)
                (setf (sref ctx :anchor-pos) (cons new-oy new-ox))
                (unless (sref ctx :anchor-growth)
                  (setf (sref ctx :anchor-growth) :bottom-right)))))
          (:terminal-scrolled
            (let* ((dir (msg-data message :direction))
                    (n (or (msg-data message :amount) 0)))
              (log-info "Root-viewport ~A received terminal-scrolled ~A ~A"
                id-path dir n)
              (when (and (member dir '(:up :down)) (> n 0))
                (let ((issued (sref ctx :issued-scroll-net 0)))
                  (setf (sref ctx :issued-scroll-net)
                    (+ issued (if (eql dir :down) n (- n))))))))
          (:appshutdown
            (log-info "Root-viewport appshutdown: starting cleanup")
            (let ((anc (normalize-anchor (sref ctx :anchor))))
              (log-info "Root-viewport appshutdown: anchor=~A" anc)
              (let* ((ox (sref ctx :offset-x 0))
                      (oy (sref ctx :offset-y 0))
                      (w (max 0 (or (sref ctx :width) 0)))
                      (h (max 0 (or (sref ctx :height) 0)))
                      (rect (elmtui.view.geo:make-rectangle
                              :pos (elmtui.view.geo:make-pos :x ox :y oy)
                              :size (elmtui.view.geo:make-size :w w :h h))))
                (when (and (> w 0) (> h 0) (sref ctx :blank-on-exit t))
                  (push `(:render :blank-viewport ,rect) render-commands)))
              (let ((issued (sref ctx :issued-scroll-net 0)))
                (log-info "Root-viewport shutdown: issued-scroll-net=~A" issued)
                (when (/= issued 0)
                  (if (> issued 0)
                    (progn
                      (log-info "Root-viewport shutdown: emitting scroll-up ~A" issued)
                      (push `(:render :scroll-up ,issued) render-commands))
                    (progn
                      (log-info "Root-viewport shutdown: emitting scroll-down ~A" (- issued))
                      (push `(:render :scroll-down ,(- issued)) render-commands)))
                  (setf (sref ctx :issued-scroll-net) 0)))
              (let* ((initial-pos (sref ctx :initial-cursor-pos))
                      (col (first initial-pos))
                      (row (second initial-pos)))
                (when (and (numberp row) (numberp col))
                  (push `(:render :set-cursor ,row ,col) render-commands)))))
          (otherwise
            (setf (sref ctx :unrecognized-message) message*))))
      (multiple-value-bind (child child-id-path)
        (child-instance state* id-path)
        (when child
          (let* ((result (elmtui.ui.api:update child message* state*
                           :id-path child-id-path))
                  (child-patches (elmtui.state.api:ur-patches result))
                  (child-cmds (elmtui.state.api:ur-commands result)))
            (when child-patches
              (setf extra-patches (nconc extra-patches child-patches)))
            (when (and child-cmds (listp child-cmds))
              (setf extra-commands (nconc extra-commands child-cmds)))))))
      (let* ((ctx-patches (context-patches ctx))
              (ctx-commands (context-commands ctx))
              (all-commands (nconc (nreverse render-commands) ctx-commands extra-commands)))
        (elmtui.state.api:make-update-result
          :patches (append ctx-patches extra-patches)
          :commands all-commands)))))
;; (defmethod elmtui.ui.api:update ((component root-viewport) message state &key id-path)
;;   (log-info "root-viewport: update id-path=~a message=~a"
;;     id-path message)

;;   (multiple-value-bind (_new-state patches commands)
;;     (elmtui.update-dsl:with-cycle (ctx state :component-path id-path)
;;       (flet ((patch (subkey value) `(,(append id-path subkey) ,value)))
;;         (let* ((st-path (append id-path '(:state)))
;;                 (anchor   (cstate> :anchor))
;;                 (overflow-policy (cstate> :overflow-policy :scroll))
;;                 ;; (pos-known (cstate> :cursor-pos))
;;                 ;; (size-known  (cstate> :terminal-size))
;;                 (issued-scroll-net (cstate> :issued-scroll-net 0))
;;                 (own-patches nil)
;;                 (commands nil))

;;           (labels
;;             (;; (ready? () (and size-known pos-known))
;;               (ensure-initial-cursor! (x y)
;;                 (unless (cstate> :initial-cursor-pos)
;;                   (setf (cstate> :initial-cursor-pos) (list x y)))))
;;             ;; (setf (cstate> :sef) :bc)
;;                                         ;(let ((cp (cstate> :cursor-pos)))
;;             ;; (push (patch '(:state :initial-cursor-pos) cp) own-patches)
;;             (when (listp message)
;;               (or (case (msg-type message)
;;                     ;; --- terminal resized ------------------------------------------------
;;                     (:terminalresized
;;                       (let* ((cols (msg-data message :width))
;;                               (rows (msg-data message :height)))
;;                         (when (and cols rows (> cols 0) (> rows 0))
;;                           (setf (cstate> :terminal-size) (list cols rows))
;;                           (if (eq (normalize-anchor anchor) :manual)
;;                             ;; Manual: do not recompute; only clamp current offsets to fit.
;;                             (let* ((width  (cstate> :width 1))
;;                                     (height (cstate> :height 1))
;;                                     (ox (cstate> :offset-x 0))
;;                                     (oy (cstate> :offset-y 0))
;;                                     (cx (%clamp ox 0 (max 0 (- rows height))))
;;                                     (cy (%clamp oy 0 (max 0 (- cols width)))))
;;                               (when (or (/= cx ox) (/= cy oy))
;;                                 (push (patch '(:state :offset-x) cx) own-patches)
;;                                 (push (patch '(:state :offset-y) cy) own-patches))
;;                               ;; anchor-pos in manual = top-left
;;                               (push (patch '(:state :anchor-pos) (cons cx cy)) own-patches)
;;                               ;; keep existing :anchor-growth or set default if missing
;;                               (setf (cstate>   :size-known) t)
;;                               (unless (cstate> :anchor-growth)

;;                                 (push (patch '(:state :anchor-growth) :bottom-right) own-patches)))
;;                             ;; Non-manual: full recompute + overflow

;;                             (multiple-value-bind (oy ox ap growth eff) (%recompute-anchoring st-path state)
;;                               (declare (ignore eff))
;;                               (push (patch '(:state :offset-x) ox) own-patches)
;;                               (push (patch '(:state :offset-y) oy) own-patches)
;;                               (push (patch '(:state :anchor-pos) ap) own-patches)
;;                               (push (patch '(:state :anchor-growth) growth) own-patches)
;;                               (multiple-value-bind (ov-patches ov-cmds)
;;                                 (%apply-overflow-y st-path state overflow-policy oy ox)
;;                                 (setf own-patches (nconc own-patches ov-patches))
;;                                 (setf commands (nconc commands ov-cmds)))))
;;                           (case (normalize-anchor anchor)
;;                             (:below-cursor (push '(:render :clear-below-cursor) commands))
;;                             (:above-cursor (push '(:render :clear-above-cursor) commands)))
;;                           )))

;;                     ;; --- cursor moved ----------------------------------------------------
;;                     (:cursorposition
;;                       (let ((c (msg-data message :col))
;;                              (r (msg-data message :row)))
;;                         (when (and c r (> c 0) (> r 0))
;;                           (setf (cstate> :cursor-pos) (list c r))
;;                           (ensure-initial-cursor! c r)
;;                           (if (eq (normalize-anchor anchor) :manual)
;;                             ;; manual: ignore cursor for placement
;;                             (progn)
;;                             (multiple-value-bind (oy ox ap growth eff) (%recompute-anchoring st-path state)
;;                               (declare (ignore eff))
;;                               (push (patch '(:state :offset-x) ox) own-patches)
;;                               (push (patch '(:state :offset-y) oy) own-patches)
;;                               (push (patch '(:state :anchor-pos) ap) own-patches)
;;                               (push (patch '(:state :anchor-growth) growth) own-patches)
;;                               (multiple-value-bind (ov-patches ov-cmds)
;;                                 (%apply-overflow-y st-path state overflow-policy oy ox)
;;                                 (setf own-patches (nconc own-patches ov-patches))
;;                                 (setf commands (nconc commands ov-cmds)))))
;;                           ;; (when (and size-known (not (cstate> :first-ready-done)) state)))
;;                           ;; (push (patch '(:state :first-ready-done) t) own-patches)
;;                           ;; (case (normalize-anchor anchor)
;;                           ;;   (:below-cursor (push '(:render :clear-below-cursor) commands))
;;                           ;;   (:above-cursor (push '(:render :clear-above-cursor) commands))
;;                           ;;   (otherwise nil))
;;                           )))
;;                     ;; --- manual anchoring controls -------------------------------------
;;                     (:anchor-move
;;                       ;; Move manual anchor by dx (cols) / dy (rows)
;;                       (when (eq (normalize-anchor anchor) :manual)
;;                         (let* ((dx (or (msg-data message :dx) 0))
;;                                 (dy (or (msg-data message :dy) 0))
;;                                 (cols (first (cstate> :terminal-size '(0 0))))
;;                                 (rows (second (cstate> :terminal-size '(0 0))))
;;                                 (w (cstate> :width 1))
;;                                 (h (cstate> :height 1))
;;                                 (ox (cstate> :offset-x 0))
;;                                 (oy (cstate> :offset-y 0))
;;                                 (new-ox (%clamp (+ ox dx) 0 (max 0 (- cols w))))
;;                                 (new-oy (%clamp (+ oy dy) 0 (max 0 (- rows h)))))
;;                           (push (patch '(:state :offset-x) new-ox) own-patches)
;;                           (push (patch '(:state :offset-y) new-oy) own-patches)
;;                           ;; anchor-pos (manual) = top-left
;;                           (push (patch '(:state :anchor-pos) (cons new-oy new-ox)) own-patches)
;;                           ;; keep or seed growth
;;                           (unless (cstate> :anchor-growth)
;;                             (push (patch '(:state :anchor-growth) :bottom-right) own-patches)))))
;;                     (:anchor-set-position
;;                       ;; Set manual anchor absolute top-left (row/col)
;;                       (when (eq (normalize-anchor anchor) :manual)
;;                         (let* ((row (msg-data message :row))
;;                                 (col (msg-data message :col))
;;                                 (cols (first (cstate> :terminal-size '(0 0))))
;;                                 (rows (second (cstate> :terminal-size '(0 0))))
;;                                 (w (cstate> :width 1))
;;                                 (h (cstate> :height 1))
;;                                 (new-oy (%clamp (or row 0) 0 (max 0 (- rows h))))
;;                                 (new-ox (%clamp (or col 0) 0 (max 0 (- cols w)))))
;;                           (push (patch '(:state :offset-x) new-ox) own-patches)
;;                           (push (patch '(:state :offset-y) new-oy) own-patches)
;;                           (push (patch '(:state :anchor-pos) (cons new-oy new-ox)) own-patches)
;;                           (unless (cstate> :anchor-growth)
;;                             (push (patch '(:state :anchor-growth) :bottom-right) own-patches)))))

;;                     ;; --- renderer announced it scrolled (optional integration) ----------
;;                     (:terminal-scrolled
;;                       ;; Expected msg-data: (:direction :up|:down :amount <n>)
;;                       (let* ((dir (msg-data message :direction))
;;                               (n   (or (msg-data message :amount) 0)))
;;                         (log-info "Root-viewport ~A received terminal-scrolled ~A ~A"
;;                           id-path dir n)
;;                         (when (and (member dir '(:up :down)) (> n 0))
;;                           (incf issued-scroll-net (if (eql dir :down) n (- n)))
;;                           (push (patch '(:state :issued-scroll-net) issued-scroll-net) own-patches))))

;;                     ;; --- app shutdown: restore net scroll -------------------------------
;;                     (:appshutdown
;;                       ;; Clear the viewport content before restoring scroll
;;                       (let ((anc (normalize-anchor anchor)))
;;                         (case anc
;;                           (:below-cursor (push '(:render :clear-below-cursor) commands))
;;                           (:above-cursor (push '(:render :clear-above-cursor) commands))
;;                           (otherwise 
;;                             ;; For other anchors, clear the viewport area
;;                             (let ((ox (cstate> :offset-x 0))
;;                                    (oy (cstate> :offset-y 0))
;;                                    (w (cstate> :width 1))
;;                                    (h (cstate> :height 1)))
;;                               (declare (ignore w h))
;;                               ;; Clear by setting cursor to viewport top-left and clearing down
;;                               (push `(:render :set-cursor ,oy ,ox) commands)
;;                               (push '(:render :clear-below-cursor) commands)))))
;;                       ;; Restore scroll position
;;                       (when (/= issued-scroll-net 0)
;;                         (if (> issued-scroll-net 0)
;;                           (push `(:render :scroll-up ,issued-scroll-net) commands)
;;                           (push `(:render :scroll-down ,(- issued-scroll-net)) commands))
;;                         (setf issued-scroll-net 0)
;;                         (push (patch '(:state :issued-scroll-net) 0) own-patches))))

;;                 ;; --- arrow key panning (independent of anchor) ----------------------

;;                 ;; ((or :key-right :key-left :key-up :key-down)
;;                 ;;  (let* ((term-size (cstate> :terminal-size '(0 0)))
;;                 ;;         (width     (cstate> :width 1))
;;                 ;;         (height    (cstate> :height 1))
;;                 ;;         (ox        (cstate> :offset-x 0))
;;                 ;;         (oy        (cstate> :offset-y 0))
;;                 ;;         (cols (first term-size)) (rows (second term-size)))
;;                 ;;    (case (msg-type message)
;;                 ;;      (:key-right (incf oy))
;;                 ;;      (:key-left  (decf oy))
;;                 ;;      (:key-up    (decf ox))
;;                 ;;      (:key-down  (incf ox)))
;;                 ;;    (setf ox (%clamp ox 0 (max 0 (- rows height)))
;;                 ;;          oy (%clamp oy 0 (max 0 (- cols width))))
;;                 ;;    (push (patch '(:state :offset-x) ox) own-patches)
;;                 ;;    (push (patch '(:state :offset-y) oy) own-patches)))                     )

;;                 ;; Unrecognized → stash raw for debugging
;;                 (push (patch '(:state :unrecognized-message) message) own-patches))

;;               ;; propagate downstream
;;               (multiple-value-bind (child-patches child-cmds)
;;                 (let ((child (child-instance state id-path)))
;;                   (when child
;;                     (elmtui.ui.api:update child message state
;;                       :id-path
;;                       (append id-path (list (slot-value child 'id))))))
;;                 (log-info "root-viewport ~A child ~A produced ~A patches and ~A commands."
;;                   id-path (child-instance state id-path) child-patches (length child-cmds))
;;                 (let ((cp (and (listp child-patches) child-patches))
;;                        (cc (and (listp child-cmds) child-cmds)))
;;                   (values (nconc own-patches cp)
;;                     (nconc commands cc)))))))))
;;     (declare (ignore _new-state))
;;     (log-info "root-viewport ~A produced ~A patches and ~A commands."
;;       ;; (state-ref (get-path (append id-path '(:state)) state) :id (first (last id-path)))
;;       id-path
;;       patches (length commands))
;;     (values patches commands)))

;;; ---------------------------------------------------------------------------
;;; VIEW
;;; ---------------------------------------------------------------------------
(defmethod elmtui.ui.api:view ((component root-viewport) state
                                &key id-path children &allow-other-keys)
  (declare (type list id-path) (type t state))
  (let* ((vp-state-raw (rv-get-state-value state id-path nil))
          (vp-state (multiple-value-bind (inner present-p)
                      (typecase vp-state-raw
                        (hash-table (gethash :state vp-state-raw))
                        (list (rv-plist-lookup vp-state-raw :state))
                        (t (values nil nil)))
                      (if present-p inner vp-state-raw)))
          (term-size-raw (or (%state-value vp-state :terminal-size) '(0 0)))
          (term-size (if (and (listp term-size-raw)
                           (numberp (first term-size-raw))
                           (numberp (second term-size-raw)))
                       term-size-raw
                       '(0 0)))
          (size-known (or (%state-value vp-state :size-known)
                        (and (> (first term-size) 1) (> (second term-size) 1))))
          (term-cols (max 0 (or (first term-size) 0)))
          (term-rows (max 0 (or (second term-size) 0)))
          ;; Geometry is sufficient to render; cursor position only refines anchoring.
          ;; :first-ready-done marks initial cleanup commands, not view readiness.
          (ready? (and size-known (> term-cols 0) (> term-rows 0)))
          (effective-id (or (%state-value vp-state :id) (first (last id-path))))
          (effective-id-viewport (let* ((name (string-upcase (string effective-id)))
                                         (pref "ROOT-VIEWPORT-"))
                                   (if (uiop:string-prefix-p pref name)
                                     effective-id
                                     (intern (concatenate 'string pref name) :keyword)))))
    (when (not ready?)
      (log-debug "root-viewport:view id=~a waiting for terminal dimensions (size-known=~a term-size=~a)"
        effective-id size-known term-size)
      (return-from elmtui.ui.api:view nil))
    (let* ((children-from-args children)
            (child-from-state (%state-value vp-state :child-dsl-spec))
            (final-children (or children-from-args
                              (cond
                                ((null child-from-state) nil)
                                ((and (listp child-from-state)
                                   (keywordp (first child-from-state)))
                                  (list child-from-state))
                                (t (list child-from-state)))))
            (width (or (%state-value vp-state :width)
                     term-cols
                     1))
            (height (or (%state-value vp-state :height)
                      term-rows
                      1))
            (offset-x (%state-value vp-state :offset-x 0))
            (offset-y (%state-value vp-state :offset-y 0))
            (scroll-x (%state-value vp-state :scroll-x 0))
            (scroll-y (%state-value vp-state :scroll-y 0)))
      (unless final-children
        (log-debug "Root-viewport ~A has no children." effective-id))
      `(:container :id ,effective-id-viewport
         :style (:width ,width :height ,height
                  :offset-x ,offset-x :offset-y ,offset-y
                  :scroll-x ,scroll-x :scroll-y ,scroll-y)
         :children ,final-children))))
