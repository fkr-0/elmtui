(uiop:define-package
    :elmtui.ui.widgets.root-viewport
  (:use :cl #:log4cl
        :elmtui.ui.api
   :elmtui.ui.widgets.viewport)
  (:import-from :elmtui.utils :ensure-list :get-path :set-path)
  (:import-from :elmtui.update-dsl :with-cycle :cmd> :state> :cstate>)
  (:import-from :elmtui.tea-state :state-ref)
  (:import-from :elmtui.tea-state.msg
                #:msg-data #:msg-type)
  (:import-from :elmtui.app.api
                #:get-component-instance)
  (:export #:root-viewport
           #:make-root-viewport
           #:anchor-type))

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
    (t a)))

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
                                 dsl)
  ;; Accept DSL either as (:root-viewport ...props...) or a plain plist of props.
  (let* ((plist (if (and (consp dsl) (keywordp (first dsl)) (eq (first dsl) :root-viewport))
                    (rest dsl)
                    dsl))
         (style (getf plist :style))
         ;; Prefer top-level :anchor/:overflow-policy when present; else fall back to :style's.
         (anchor (normalize-anchor (or (getf plist :anchor)
                                       (and style (getf style :anchor))
                                       :top-left)))
         (overflow-policy (or (getf plist :overflow-policy)
                              (and style (getf style :overflow-policy))
                              :scroll)) ; :scroll | :truncate
         ;; (term-cols (or (first initial-terminal-dimensions) 0))
         ;; (term-rows (or (second initial-terminal-dimensions) 0))
         ;; (cursor-c  (or (first initial-cursor-pos) 0))
         ;; (cursor-r  (or (second initial-cursor-pos) 0))
         ;; default dims until we know both
         ;; (desired-w nil)
         ;; (desired-h nil)
         (oy 0) (ox 0) (ap (cons 0 0)) (growth :bottom-right) ;; (eff (cons desired-w desired-h))
         )
    ;; (when (and size-known pos-known)
    ;;   (multiple-value-setq (oy ox ap growth eff)
    ;;     (compute-anchor-solution anchor desired-w desired-h
    ;;                              term-cols term-rows
    ;;                              cursor-r cursor-c)))
    (values component
            (list
             (list (append id-path '(:type)) :root-viewport)
             ;; geometry
             ;; (list (append id-path '(:state :width))  (car eff))
             ;; (list (append id-path '(:state :height)) (cdr eff))
             (list (append id-path '(:state :offset-x)) ox)
             (list (append id-path '(:state :offset-y)) oy)
             ;; anchor meta
             (list (append id-path '(:state :anchor)) anchor)
             (list (append id-path '(:state :anchor-pos)) ap)         ; (row . col)
             (list (append id-path '(:state :anchor-growth)) growth)  ; anchor-growth-type
             ;; env info
             (list (append id-path '(:state :initial-cursor-pos)) nil) ; placeholder; set on first known
             ;; (list (append id-path '(:state :size-known))  size-known)
             ;; (list (append id-path '(:state :pos-known))   pos-known)
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
   scroll or truncate. Returns two values: patches, commands."
  (declare (ignore new-oy new-ox))
  (let* ((anchor (normalize-anchor (get-path (append st-path '(:anchor)) state)))
         (term-size (or (get-path (append st-path '(:terminal-size)) state) '(0 0)))
         (cursor-pos (or (get-path (append st-path '(:cursor-pos)) state) '(0 0)))
         (height (or (get-path (append st-path '(:height)) state) 1))
         (issued (or (get-path (append st-path '(:issued-scroll-net)) state) 0))
         ;; (cols (first term-size))
         (rows (second term-size))
         ;; (c (first cursor-pos))
         (r (second cursor-pos))
         (patches nil) (commands nil))
    (labels ((emit-scroll (dir n)
               (when (> n 0)
                 (ecase dir
                   (:down (push `(:render :scroll-down ,n) commands)
                    (setf issued (+ issued n)))
                   (:up   (push `(:render :scroll-up ,n)   commands)
                    (setf issued (- issued n))))
                 (push (list (append st-path '(:issued-scroll-net)) issued) patches)))
             (truncate-height (new-h)
               ;; (declare (ignore cols c))
               (when (/= (max 1 new-h) height)
                 (push (list (append st-path '(:height)) (max 1 new-h)) patches))))
      ;; (declare (ignore cols c))
      (case anchor
        (:below-cursor
         ;; rows strictly below cursor (after the cursor line)
         (let* ((rows-remaining (max 0 (- rows (1+ r))))
                (needed (max 0 (- height 1)))
                (excess (max 0 (- needed rows-remaining))))
           (log-info "root-viewport: below-cursor rows-remaining=~a needed=~a excess=~a"
                     rows-remaining needed excess)
           (when (> excess 0)
             (case overflow-policy
               (:scroll   (emit-scroll :down excess))
               (:truncate (truncate-height (min height (1+ rows-remaining))))))))
        (:above-cursor
         (let* ((rows-available (max 0 r))
                (excess (max 0 (- height rows-available))))
           (log-info "root-viewport: above-cursor rows-available=~a needed=~a excess=~a"
                     rows-available height excess)
           (when (> excess 0)
             (case overflow-policy
               (:scroll   (emit-scroll :up excess))
               (:truncate (truncate-height (min height rows-available)))))))
        (otherwise
         ;; screen-anchored: no vertical overflow handling here
         t))
      (values patches commands))))


(defmethod elmtui.ui.api:update ((component root-viewport) message state &key id-path)
  (log-info "root-viewport: update id-path=~a message=~a"
            id-path message)

  (multiple-value-bind (_new-state patches commands)
      (elmtui.update-dsl:with-cycle (ctx state :component-path id-path)
        (flet ((patch (subkey value) `(,(append id-path subkey) ,value)))
          (let* ((st-path (append id-path '(:state)))
                 (anchor   (cstate> :anchor))
                 (overflow-policy (cstate> :overflow-policy :scroll))
                 ;; (pos-known (cstate> :cursor-pos))
                 ;; (size-known  (cstate> :terminal-size))
                 (issued-scroll-net (cstate> :issued-scroll-net 0))
                 (own-patches nil)
                 (commands nil))

            (labels
                (;; (ready? () (and size-known pos-known))
                 (ensure-initial-cursor! (x y)
                   (unless (cstate> :initial-cursor-pos)
                     (setf (cstate> :initial-cursor-pos) (list x y)))))
              ;; (setf (cstate> :sef) :bc)
                                        ;(let ((cp (cstate> :cursor-pos)))
              ;; (push (patch '(:state :initial-cursor-pos) cp) own-patches)
              (when (listp message)
                (or (case (msg-type message)
                      ;; --- terminal resized ------------------------------------------------
                      (:terminalresized
                       (let* ((cols (msg-data message :width))
                              (rows (msg-data message :height)))
                         (when (and cols rows (> cols 0) (> rows 0))
                           (setf (cstate> :terminal-size) (list cols rows))
                           (if (eq (normalize-anchor anchor) :manual)
                               ;; Manual: do not recompute; only clamp current offsets to fit.
                               (let* ((width  (cstate> :width 1))
                                      (height (cstate> :height 1))
                                      (ox (cstate> :offset-x 0))
                                      (oy (cstate> :offset-y 0))
                                      (cx (%clamp ox 0 (max 0 (- rows height))))
                                      (cy (%clamp oy 0 (max 0 (- cols width)))))
                                 (when (or (/= cx ox) (/= cy oy))
                                   (push (patch '(:state :offset-x) cx) own-patches)
                                   (push (patch '(:state :offset-y) cy) own-patches))
                                 ;; anchor-pos in manual = top-left
                                 (push (patch '(:state :anchor-pos) (cons cx cy)) own-patches)
                                 ;; keep existing :anchor-growth or set default if missing
                                 (setf (cstate>   :size-known) t)
                                 (unless (cstate> :anchor-growth)

                                   (push (patch '(:state :anchor-growth) :bottom-right) own-patches)))
                               ;; Non-manual: full recompute + overflow

                               (multiple-value-bind (oy ox ap growth eff) (%recompute-anchoring st-path state)
                                 (declare (ignore eff))
                                 (push (patch '(:state :offset-x) ox) own-patches)
                                 (push (patch '(:state :offset-y) oy) own-patches)
                                 (push (patch '(:state :anchor-pos) ap) own-patches)
                                 (push (patch '(:state :anchor-growth) growth) own-patches)
                                 (multiple-value-bind (ov-patches ov-cmds)
                                     (%apply-overflow-y st-path state overflow-policy oy ox)
                                   (setf own-patches (nconc own-patches ov-patches))
                                   (setf commands (nconc commands ov-cmds)))))
                           (case (normalize-anchor anchor)
                             (:below-cursor (push '(:render :clear-below-cursor) commands))
                             (:above-cursor (push '(:render :clear-above-cursor) commands)))
                           )))

                      ;; --- cursor moved ----------------------------------------------------
                      (:cursorposition
                       (let ((c (msg-data message :col))
                             (r (msg-data message :row)))
                         (when (and c r (> c 0) (> r 0))
                           (setf (cstate> :cursor-pos) (list c r))
                           (ensure-initial-cursor! c r)
                           (if (eq (normalize-anchor anchor) :manual)
                               ;; manual: ignore cursor for placement
                               (progn)
                               (multiple-value-bind (oy ox ap growth eff) (%recompute-anchoring st-path state)
                                 (declare (ignore eff))
                                 (push (patch '(:state :offset-x) ox) own-patches)
                                 (push (patch '(:state :offset-y) oy) own-patches)
                                 (push (patch '(:state :anchor-pos) ap) own-patches)
                                 (push (patch '(:state :anchor-growth) growth) own-patches)
                                 (multiple-value-bind (ov-patches ov-cmds)
                                     (%apply-overflow-y st-path state overflow-policy oy ox)
                                   (setf own-patches (nconc own-patches ov-patches))
                                   (setf commands (nconc commands ov-cmds)))))
                           ;; (when (and size-known (not (cstate> :first-ready-done)) state)))
                           ;; (push (patch '(:state :first-ready-done) t) own-patches)
                           ;; (case (normalize-anchor anchor)
                           ;;   (:below-cursor (push '(:render :clear-below-cursor) commands))
                           ;;   (:above-cursor (push '(:render :clear-above-cursor) commands))
                           ;;   (otherwise nil))
                           )))
                      ;; --- manual anchoring controls -------------------------------------
                      (:anchor-move
                       ;; Move manual anchor by dx (cols) / dy (rows)
                       (when (eq (normalize-anchor anchor) :manual)
                         (let* ((dx (or (msg-data message :dx) 0))
                                (dy (or (msg-data message :dy) 0))
                                (cols (first (cstate> :terminal-size '(0 0))))
                                (rows (second (cstate> :terminal-size '(0 0))))
                                (w (cstate> :width 1))
                                (h (cstate> :height 1))
                                (ox (cstate> :offset-x 0))
                                (oy (cstate> :offset-y 0))
                                (new-ox (%clamp (+ ox dx) 0 (max 0 (- cols w))))
                                (new-oy (%clamp (+ oy dy) 0 (max 0 (- rows h)))))
                           (push (patch '(:state :offset-x) new-ox) own-patches)
                           (push (patch '(:state :offset-y) new-oy) own-patches)
                           ;; anchor-pos (manual) = top-left
                           (push (patch '(:state :anchor-pos) (cons new-oy new-ox)) own-patches)
                           ;; keep or seed growth
                           (unless (cstate> :anchor-growth)
                             (push (patch '(:state :anchor-growth) :bottom-right) own-patches)))))
                      (:anchor-set-position
                       ;; Set manual anchor absolute top-left (row/col)
                       (when (eq (normalize-anchor anchor) :manual)
                         (let* ((row (msg-data message :row))
                                (col (msg-data message :col))
                                (cols (first (cstate> :terminal-size '(0 0))))
                                (rows (second (cstate> :terminal-size '(0 0))))
                                (w (cstate> :width 1))
                                (h (cstate> :height 1))
                                (new-oy (%clamp (or row 0) 0 (max 0 (- rows h))))
                                (new-ox (%clamp (or col 0) 0 (max 0 (- cols w)))))
                           (push (patch '(:state :offset-x) new-ox) own-patches)
                           (push (patch '(:state :offset-y) new-oy) own-patches)
                           (push (patch '(:state :anchor-pos) (cons new-oy new-ox)) own-patches)
                           (unless (cstate> :anchor-growth)
                             (push (patch '(:state :anchor-growth) :bottom-right) own-patches)))))

                      ;; --- renderer announced it scrolled (optional integration) ----------
                      (:terminal-scrolled
                       ;; Expected msg-data: (:direction :up|:down :amount <n>)
                       (let ((dir (msg-data message :direction))
                             (n   (or (msg-data message :amount) 0)))
                         (when (and (member dir '(:up :down)) (> n 0))
                           (incf issued-scroll-net (if (eql dir :down) n (- n)))
                           (push (patch '(:state :issued-scroll-net) issued-scroll-net) own-patches))))

                      ;; --- app shutdown: restore net scroll -------------------------------
                      (:appshutdown
                       (when (/= issued-scroll-net 0)
                         (if (> issued-scroll-net 0)
                             (push `(:render :scroll-up ,issued-scroll-net) commands)
                             (push `(:render :scroll-down ,(- issued-scroll-net)) commands))
                         (setf issued-scroll-net 0)
                         (push (patch '(:state :issued-scroll-net) 0) own-patches))))

                    ;; --- arrow key panning (independent of anchor) ----------------------

                    ;; ((or :key-right :key-left :key-up :key-down)
                    ;;  (let* ((term-size (cstate> :terminal-size '(0 0)))
                    ;;         (width     (cstate> :width 1))
                    ;;         (height    (cstate> :height 1))
                    ;;         (ox        (cstate> :offset-x 0))
                    ;;         (oy        (cstate> :offset-y 0))
                    ;;         (cols (first term-size)) (rows (second term-size)))
                    ;;    (case (msg-type message)
                    ;;      (:key-right (incf oy))
                    ;;      (:key-left  (decf oy))
                    ;;      (:key-up    (decf ox))
                    ;;      (:key-down  (incf ox)))
                    ;;    (setf ox (%clamp ox 0 (max 0 (- rows height)))
                    ;;          oy (%clamp oy 0 (max 0 (- cols width))))
                    ;;    (push (patch '(:state :offset-x) ox) own-patches)
                    ;;    (push (patch '(:state :offset-y) oy) own-patches)))                     )

                    ;; Unrecognized → stash raw for debugging
                    (push (patch '(:state :unrecognized-message) message) own-patches))

                ;; propagate downstream
                (multiple-value-bind (child-patches child-cmds)
                    (let ((child (child-instance state id-path)))
                      (when child
                        (elmtui.ui.api:update child message state
                                              :id-path
                                              (append id-path (list (slot-value child 'id))))))
                  (log-info "root-viewport ~A child ~A produced ~A patches and ~A commands."
                            id-path (child-instance state id-path) child-patches (length child-cmds))
                  (let ((cp (and (listp child-patches) child-patches))
                        (cc (and (listp child-cmds) child-cmds)))
                    (values (nconc own-patches cp)
                            (nconc commands cc)))))))))
    (declare (ignore _new-state))
    (log-info "root-viewport ~A produced ~A patches and ~A commands."
              ;; (state-ref (get-path (append id-path '(:state)) state) :id (first (last id-path)))
              id-path
              patches (length commands))
    (values patches commands)))

;;; ---------------------------------------------------------------------------
;;; VIEW
;;; ---------------------------------------------------------------------------
(defmethod elmtui.ui.api:view ((component root-viewport) state
                               &key id-path children &allow-other-keys)
  (declare (type list id-path) (type t state))
  (log-info "ROOT-VIEWPORT VIEW> id path ~A state ~A" id-path (elmtui.tea-state.api::pprinc-application-state state))
  (let ((asdf nil))
    (elmtui.update-dsl:with-cycle (ctx state :component-path id-path)
      (log-info "id path ~A state ~A" id-path (elmtui.tea-state.api::pprinc-application-state state))
      (let* ((vp-state (get-path (append id-path '(:state)) state))
             (effective-id (state-ref vp-state :id (first (last id-path))))
             (term-size (cstate> :terminal-size))
             (cursor-pos  (cstate> :cursor-pos)))
        ;; 1) Defer view until both are known
        ;; (setf (cstate> :halulu) :abc)
        (unless (and term-size cursor-pos)
          (log-debug "Root-viewport ~A waiting for size/cursor; returning NIL view." effective-id)
          (return-from elmtui.ui.api:view nil))

        ;; 2) Build viewport DSL with computed offsets & size (available space)
        (let* ((children-from-args children)
               (child-from-state (state-ref vp-state :child-dsl-spec))
               (final-children (or children-from-args
                                   (when child-from-state (list child-from-state))))
               (_ (log-info "Children ~A" final-children))
               (width (state-ref vp-state :width))
               (height (state-ref vp-state :height))
               (offset-x (state-ref vp-state :offset-x 0))
               (offset-y (state-ref vp-state :offset-y 0))
               (scroll-x (state-ref vp-state :scroll-x 0))
               (scroll-y (state-ref vp-state :scroll-y 0))
               (effective-id-viewport (intern (format nil "ROOT-VIEWPORT-~A" effective-id) :keyword)))

          (unless final-children
            (log-warn "Root-viewport ~A has no children." effective-id))

          (setf asdf `(:viewport :id ,effective-id-viewport
                                 :style (:width ,width :height ,height
                                         :offset-x ,offset-x :offset-y ,offset-y
                                         :scroll-x ,scroll-x :scroll-y ,scroll-y)
                                 :children ,final-children)))))
    asdf))
