(uiop:define-package
  :elmtui.ui.widgets.root-viewport
  (:use :cl #:log4cl
    :elmtui.ui.api
    :elmtui.ui.widgets.viewport)
  (:import-from :elmtui.utils :ensure-list :get-path :set-path)
  (:import-from :elmtui.update-dsl :with-cycle :msg> :state> :cstate> :cmd>)
  (:import-from :elmtui.tea-state :state-ref)
  (:import-from :elmtui.tea-state.msg
    #:msg-data #:msg-type)
  (:import-from :elmtui.app.api
    #:get-component-instance)
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
        (values safe-w (max 0 (- safe-h safe-r 1)) 0))
      (:above-cursor
        (values safe-w (max 0 safe-r) 0))

      ;; Full screen anchors - use entire terminal
      (otherwise
        (values safe-w safe-h 0)))))

(defun %overflow-effects (anchor height rows cursor-row overflow-policy issued)
  "Return NEW-HEIGHT, NEW-ISSUED and overflow render commands based on current
geometry.  NIL means the value should remain unchanged."
  (let ((new-height nil)
         (commands nil)
         (new-issued issued))
    (labels ((emit-scroll (dir amount)
               (when (> amount 0)
                 (ecase dir
                   (:down
                     (incf new-issued amount)
                     (push `(:render :scroll-down ,amount) commands))
                   (:up
                     (decf new-issued amount)
                     (push `(:render :scroll-up ,amount) commands)))))
              (truncate-height (limit)
                (setf new-height (max 1 limit))))
      (case anchor
        (:below-cursor
          (let* ((rows-remaining (max 0 (- rows (1+ cursor-row))))
                  (needed (max 0 (1- height)))
                  (excess (max 0 (- needed rows-remaining))))
            (when (> excess 0)
              (case overflow-policy
                (:scroll (emit-scroll :down excess))
                (:truncate (truncate-height (min height (1+ rows-remaining))))))))
        (:above-cursor
          (let* ((rows-available (max 0 cursor-row))
                  (excess (max 0 (- height rows-available))))
            (when (> excess 0)
              (case overflow-policy
                (:scroll (emit-scroll :up excess))
                (:truncate (truncate-height (min height rows-available))))))))
      (values new-height (if (/= new-issued issued) new-issued nil)
        (nreverse commands)))))

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
          (let* ((start-r (min (1+ cursor-r) (max 0 (- term-rows h))))
                  (start-c (%clamp cursor-c 0 (max 0 (- term-cols w)))))
            (set-top-left start-r start-c)
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
  "Return the live child component instance, or NIL when absent."
  (let* ((child-spec (get-path (append id-path '(:child)) state)))
    (when (and (consp child-spec) (keywordp (car child-spec)))
      (get-component-instance (append id-path (list (car child-spec))) state))))

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

(defmethod elmtui.ui.api:init ((component root-viewport)
                                &key id-path
                                initial-child-spec
                                dsl
                                anchor
                                overflow-policy
                                &allow-other-keys)
  ;; Accept DSL either as (:root-viewport ...props...) or a plain plist of props.
  (let* ((plist (if (and (consp dsl) (keywordp (first dsl)) (eq (first dsl) :root-viewport))
                  (rest dsl)
                  dsl))
          (style (getf plist :style))
          ;; Prefer explicit initargs, then top-level plist, then style.
          (anchor (normalize-anchor (or anchor
                                      (getf plist :anchor)
                                      (and style (getf style :anchor))
                                      :top-left)))
          (overflow-policy (or overflow-policy
                             (getf plist :overflow-policy)
                             (and style (getf style :overflow-policy))
                             :scroll)) ; :scroll | :truncate
          (oy 0) (ox 0) (ap (cons 0 0)) (growth :bottom-right))
    (values component
      (list
        (list (append id-path '(:type)) :root-viewport)
        (list (append id-path '(:state :offset-x)) ox)
        (list (append id-path '(:state :offset-y)) oy)
        ;; anchor meta
        (list (append id-path '(:state :anchor)) anchor)
        (list (append id-path '(:state :anchor-pos)) ap)         ; (row . col)
        (list (append id-path '(:state :anchor-growth)) growth)  ; anchor-growth-type
        ;; env info
        (list (append id-path '(:state :initial-cursor-pos)) nil) ; placeholder; set on first known
        ;; policies / book-keeping
        (list (append id-path '(:state :overflow-policy)) overflow-policy)
        (list (append id-path '(:state :issued-scroll-net)) 0)
        (list (append id-path '(:state :first-ready-done)) nil)
        ;; child / dsl
        (list (append id-path '(:state :child-dsl-spec)) initial-child-spec)
        (list (append id-path '(:state :dsl)) dsl))
      nil)))



;;; ---------------------------------------------------------------------------
;;; UPDATE
;;; ---------------------------------------------------------------------------

(defun %recompute-anchoring (st-path state &optional (log? t))
  "Recompute offsets, anchor-pos, growth given current state.
ST-PATH points at the :state subtree (i.e., ends with :state)."
  (let* ((anchor (get-path (append st-path '(:anchor)) state))
          (term-size (or (get-path (append st-path '(:terminal-size)) state) '(0 0)))
          (cursor-pos (or (get-path (append st-path '(:cursor-pos)) state) '(0 0)))
          (width  (or (get-path (append st-path '(:width)) state) 1))
          (height (or (get-path (append st-path '(:height)) state) 1)))
    ;; In :manual mode we do NOT recompute placement; we only clamp to bounds.
    (when (eq (normalize-anchor anchor) :manual)
      ;; Note: historical quirk — stored offsets may be labelled as
      ;; :offset-x (col) and :offset-y (row). Treat row from :offset-y and col from :offset-x.
      (let* ((ox (or (get-path (append st-path '(:offset-y)) state) 0))   ; column from :offset-y
              (oy (or (get-path (append st-path '(:offset-x)) state) 0))   ; row from :offset-x
              (cols (first term-size)) (rows (second term-size))
              ;; Clamp offsets to screen bounds: X against columns/width, Y against rows/height
              (new-ox (%clamp ox 0 (max 0 (- cols width))))
              (new-oy (%clamp oy 0 (max 0 (- rows height))))
              (ap (cons new-oy new-ox))
              (growth (or (get-path (append st-path '(:anchor-growth)) state) :bottom-right)))
        (when log?
          (log-debug "root-viewport: manual anchor → keep off(~a,~a) ap(~a.~a) grow=~a size(~a×~a)"
            new-oy new-ox (car ap) (cdr ap) growth width height))
        (return-from %recompute-anchoring (values new-oy new-ox ap growth (cons width height)))))
    (multiple-value-bind (oy ox ap growth eff)
      (compute-anchor-solution anchor width height
        (first term-size) (second term-size)
        (second cursor-pos) (first cursor-pos))
      (when log?
        (log-debug "root-viewport: recompute anchor → off(~a,~a) ap(~a.~a) grow=~a size(~a×~a)"
          oy ox (car ap) (cdr ap) growth (car eff) (cdr eff)))
      (values oy ox ap growth eff))))

(defun %apply-overflow-y (st-path state overflow-policy new-oy new-ox)
  "If current viewport height exceeds allowed space for above/below cursor, either
   scroll or truncate.

Returns (values PATCHES COMMANDS) where PATCHES is a list of (path value) pairs
for state updates, and COMMANDS is a list of render command plists."
  (declare (ignore new-oy new-ox))
  (let* ((anchor (normalize-anchor (get-path (append st-path '(:anchor)) state)))
          (term-size (or (get-path (append st-path '(:terminal-size)) state) '(0 0)))
          (cursor-pos (or (get-path (append st-path '(:cursor-pos)) state) '(0 0)))
          (height (or (get-path (append st-path '(:height)) state) 1))
          (issued (or (get-path (append st-path '(:issued-scroll-net)) state) 0))
          (rows (second term-size))
          (cursor-row (second cursor-pos)))
    (multiple-value-bind (new-height new-issued commands)
      (%overflow-effects anchor height rows cursor-row overflow-policy issued)
      (let ((patches nil))
        (when new-height
          (push (list (append st-path '(:height)) new-height) patches))
        (when new-issued
          (push (list (append st-path '(:issued-scroll-net)) new-issued) patches))
        (values (nreverse patches) commands)))))

(defmethod elmtui.ui.api:update ((component root-viewport) message state &key id-path)
  (log-info "root-viewport: update id-path=~a message=~a" id-path message)
  (let ((render-commands '()))
    (multiple-value-bind (new-state patches commands)
      (elmtui.update-dsl:with-cycle (ctx state :component-path id-path)
        (labels
          ((ensure-initial-cursor! (x y)
             "Record initial cursor position if not already set."
             (unless (cstate> :initial-cursor-pos)
               (setf (cstate> :initial-cursor-pos) (list x y))))
            (ready? ()
              "Check if both terminal size and cursor position are known."
              (or (and (cstate> :size-known) (cstate> :pos-known))
                (and (cstate> :terminal-size) (cstate> :cursor-pos))))
            (mark-first-ready! ()
              "Mark first ready and emit initial clear commands."
              (when (and (ready?) (not (cstate> :first-ready-done)))
                (setf (cstate> :first-ready-done) t)
                (case (normalize-anchor (cstate> :anchor))
                  (:below-cursor (push '(:render :clear-below-cursor) render-commands))
                  (:above-cursor (push '(:render :clear-above-cursor) render-commands)))))
            (sync-manual-offsets ()
              "Clamp manual anchor offsets to terminal bounds."
              (let* ((term-size (cstate> :terminal-size '(0 0)))
                      (width (cstate> :width 1))
                      (height (cstate> :height 1))
                      (ox (cstate> :offset-x 0))
                      (oy (cstate> :offset-y 0))
                      (cols (first term-size))
                      (rows (second term-size))
                      (new-ox (%clamp ox 0 (max 0 (- cols width))))
                      (new-oy (%clamp oy 0 (max 0 (- rows height)))))
                (when (or (/= new-ox ox) (/= new-oy oy))
                  (setf (cstate> :offset-x) new-ox)
                  (setf (cstate> :offset-y) new-oy))
                (setf (cstate> :anchor-pos) (cons new-oy new-ox))
                (unless (cstate> :anchor-growth)
                  (setf (cstate> :anchor-growth) :bottom-right))))
            (recompute-anchoring ()
              "Recompute anchor position based on current state."
              (let* ((anchor (normalize-anchor (cstate> :anchor)))
                      (term-size (cstate> :terminal-size '(0 0)))
                      (cursor-pos (cstate> :cursor-pos '(0 0)))
                      (width (cstate> :width 1))
                      (height (cstate> :height 1)))
                (multiple-value-bind (oy ox ap growth eff)
                  (compute-anchor-solution anchor width height
                    (first term-size) (second term-size)
                    (second cursor-pos) (first cursor-pos))
                  (declare (ignore eff))
                  (setf (cstate> :offset-x) ox)
                  (setf (cstate> :offset-y) oy)
                  (setf (cstate> :anchor-pos) ap)
                  (setf (cstate> :anchor-growth) growth))))
            (apply-overflow ()
              "Apply overflow effects based on current geometry."
              (let* ((anchor (normalize-anchor (cstate> :anchor)))
                      (term-size (cstate> :terminal-size '(0 0)))
                      (cursor-pos (cstate> :cursor-pos '(0 0)))
                      (height (cstate> :height 1))
                      (overflow-policy (cstate> :overflow-policy :scroll))
                      (issued (cstate> :issued-scroll-net 0))
                      (rows (second term-size))
                      (cursor-row (second cursor-pos)))
                (multiple-value-bind (new-height new-issued commands)
                  (%overflow-effects anchor height rows cursor-row overflow-policy issued)
                  (when new-height (setf (cstate> :height) new-height))
                  (when new-issued (setf (cstate> :issued-scroll-net) new-issued))
                  (when (and commands (listp commands) (not (null commands)))
                    (dolist (cmd commands)
                      (when cmd (push cmd render-commands)))))))
            (propagate-to-child ()
              "Propagate message to child component if exists."
              (let ((child (child-instance state id-path)))
                (when child
                  (let ((result (elmtui.ui.api:update child message state
                                  :id-path (append id-path (list (slot-value child 'id))))))
                    (let ((child-patches (elmtui.tea-state.api:ur-patches result))
                           (child-cmds (elmtui.tea-state.api:ur-commands result)))
                      (when child-patches
                        (dolist (patch child-patches)
                          (cmd> (lambda () `(:state-patch ,patch)))))
                      (when (and child-cmds (listp child-cmds))
                        (dolist (cmd child-cmds)
                          (when cmd (cmd> cmd))))))))
              
              (when (listp message)
                (case (msg-type message)
                  (:terminalresized
                    (let* ((cols (msg-data message :width))
                            (rows (msg-data message :height)))
                      (when (and cols rows (> cols 0) (> rows 0))
                        (setf (cstate> :terminal-size) (list cols rows))
                        (setf (cstate> :size-known) t)
                        ;; Compute viewport dimensions
                        (let* ((cursor-r (second (or (cstate> :cursor-pos) '(0 0))))
                                (initial-cursor-r (second (or (cstate> :initial-cursor-pos) '(0 0))))
                                (effective-r (or cursor-r initial-cursor-r 0)))
                          (multiple-value-bind (computed-w computed-h oy)
                            (compute-view-size (normalize-anchor (cstate> :anchor)) cols rows effective-r)
                            (declare (ignore oy))
                            ;; Always set so patches are recorded on resize; prefer existing values when present.
                            (let ((new-w (or (cstate> :width) computed-w))
                                   (new-h (or (cstate> :height) computed-h)))
                              (setf (cstate> :width) new-w)
                              (setf (cstate> :height) new-h)))))
                      (if (eq (normalize-anchor (cstate> :anchor)) :manual)
                        (sync-manual-offsets)
                        (progn
                          (recompute-anchoring)
                          (apply-overflow)))
                      (mark-first-ready!)))
                  (:cursorposition
                    (let ((c (msg-data message :col))
                           (r (msg-data message :row)))
                      (when (and c r (> c 0) (> r 0))
                        (setf (cstate> :cursor-pos) (list c r))
                        (setf (cstate> :pos-known) t)
                        (ensure-initial-cursor! c r)
                        ;; Update viewport dimensions
                        (let* ((term-size (cstate> :terminal-size '(0 0)))
                                (cols (first term-size))
                                (rows (second term-size)))
                          (when (and cols rows (> cols 0) (> rows 0))
                            (multiple-value-bind (computed-w computed-h oy)
                              (compute-view-size (normalize-anchor (cstate> :anchor)) cols rows r)
                              (declare (ignore oy))
                              (unless (cstate> :width) (setf (cstate> :width) computed-w))
                              (unless (cstate> :height) (setf (cstate> :height) computed-h)))))
                        (unless (eq (normalize-anchor (cstate> :anchor)) :manual)
                          (recompute-anchoring)
                          (apply-overflow))
                        (mark-first-ready!))))
                  (:anchor-move
                    (when (eq (normalize-anchor (cstate> :anchor)) :manual)
                      (let* ((dx (or (msg-data message :dx) 0))
                              (dy (or (msg-data message :dy) 0))
                              (term-size (cstate> :terminal-size '(0 0)))
                              (w (cstate> :width 1))
                              (h (cstate> :height 1))
                              (ox (cstate> :offset-x 0))
                              (oy (cstate> :offset-y 0))
                              (cols (first term-size))
                              (rows (second term-size))
                              (new-ox (%clamp (+ ox dx) 0 (max 0 (- cols w))))
                              (new-oy (%clamp (+ oy dy) 0 (max 0 (- rows h)))))
                        (setf (cstate> :offset-x) new-ox)
                        (setf (cstate> :offset-y) new-oy)
                        (setf (cstate> :anchor-pos) (cons new-oy new-ox))
                        (unless (cstate> :anchor-growth)
                          (setf (cstate> :anchor-growth) :bottom-right)))))
                  (:anchor-set-position
                    (when (eq (normalize-anchor (cstate> :anchor)) :manual)
                      (let* ((row (msg-data message :row))
                              (col (msg-data message :col))
                              (term-size (cstate> :terminal-size '(0 0)))
                              (w (cstate> :width 1))
                              (h (cstate> :height 1))
                              (cols (first term-size))
                              (rows (second term-size))
                              (new-oy (%clamp (or row 0) 0 (max 0 (- rows h))))
                              (new-ox (%clamp (or col 0) 0 (max 0 (- cols w)))))
                        (setf (cstate> :offset-x) new-ox)
                        (setf (cstate> :offset-y) new-oy)
                        (setf (cstate> :anchor-pos) (cons new-oy new-ox))
                        (unless (cstate> :anchor-growth)
                          (setf (cstate> :anchor-growth) :bottom-right)))))
                  (:terminal-scrolled
                    (let* ((dir (msg-data message :direction))
                            (n (or (msg-data message :amount) 0)))
                      (log-info "Root-viewport ~A received terminal-scrolled ~A ~A"
                        id-path dir n)
                      (when (and (member dir '(:up :down)) (> n 0))
                        (let ((issued (cstate> :issued-scroll-net 0)))
                          (setf (cstate> :issued-scroll-net)
                            (+ issued (if (eql dir :down) n (- n))))))))
                  (:appshutdown
                    (log-info "Root-viewport appshutdown: starting cleanup")
                    (let ((anc (normalize-anchor (cstate> :anchor))))
                      (log-info "Root-viewport appshutdown: anchor=~A" anc)
                      (case anc
                        (:below-cursor (push '(:render :clear-below-cursor) render-commands))
                        (:above-cursor (push '(:render :clear-above-cursor) render-commands))
                        (otherwise
                          (let ((ox (cstate> :offset-x 0))
                                 (oy (cstate> :offset-y 0)))
                            (push `(:render :set-cursor ,oy ,ox) render-commands)
                            (push '(:render :clear-below-cursor) render-commands))))
                      ;; Restore scroll position
                      (let ((issued (cstate> :issued-scroll-net 0)))
                        (log-info "Root-viewport shutdown: issued-scroll-net=~A" issued)
                        (when (/= issued 0)
                          (if (> issued 0)
                            (progn
                              (log-info "Root-viewport shutdown: emitting scroll-up ~A" issued)
                              (push `(:render :scroll-up ,issued) render-commands))
                            (progn
                              (log-info "Root-viewport shutdown: emitting scroll-down ~A" (- issued))
                              (push `(:render :scroll-down ,(- issued)) render-commands)))
                          (setf (cstate> :issued-scroll-net) 0)))))
                  (otherwise
                    (setf (cstate> :unrecognized-message) message))))))
          (propagate-to-child)))
      (let* ((command-payloads
               (remove nil
                 (mapcar (lambda (cmd)
                           (when (typep cmd 'elmtui.update-dsl.api:command)
                             (funcall (elmtui.update-dsl.api::command-thunk cmd))))
                   commands)))
              (all-commands (nconc (nreverse render-commands) command-payloads)))
        (elmtui.tea-state:make-update-result :patches patches :commands all-commands)))))
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
  (let* ((vp-state (get-path (append id-path '(:state)) state))
          (term-size (or (%state-value vp-state :terminal-size) '(0 0)))
          (cursor-pos (or (%state-value vp-state :cursor-pos) '(0 0)))
          (size-known (or (%state-value vp-state :size-known)
                        (and term-size (plusp (first term-size)) (plusp (second term-size)))))
          (pos-known (or (%state-value vp-state :pos-known)
                       (and cursor-pos (> (first cursor-pos) 0) (> (second cursor-pos) 0))))
          (effective-id (or (%state-value vp-state :id) (first (last id-path)))))
    (unless (and size-known pos-known)
      (log-debug "Root-viewport ~A waiting for size/cursor; returning NIL view." effective-id)
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
            (width (%state-value vp-state :width))
            (height (%state-value vp-state :height))
            (offset-x (%state-value vp-state :offset-x 0))
            (offset-y (%state-value vp-state :offset-y 0))
            (scroll-x (%state-value vp-state :scroll-x 0))
            (scroll-y (%state-value vp-state :scroll-y 0))
            (effective-id-viewport (intern (format nil "ROOT-VIEWPORT-~A" effective-id) :keyword)))
      (unless final-children
        (log-warn "Root-viewport ~A has no children." effective-id))
      `(:viewport :id ,effective-id-viewport
         :style (:width ,width :height ,height
                  :offset-x ,offset-x :offset-y ,offset-y
                  :scroll-x ,scroll-x :scroll-y ,scroll-y)
         :children ,final-children))))
