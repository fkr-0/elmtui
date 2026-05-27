;;;===============================================================
;;; Tmux Idle/Screensaver Demo
;;;===============================================================

(uiop:define-package :elmtui.examples.tmux-idle
  (:use :cl :log4cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.core.event-types
                #:key-event)
  (:import-from :elmtui.state.api
                #:state-ref
                #:make-update-result)
  (:import-from :elmtui.platform.tmux
                #:tmux-available-p
                #:capture-lines
                #:make-buffer-from-tmux-styled)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:make-virtual-buffer
                #:copy-virtual-buffer
                #:buffer-width
                #:buffer-height
                #:buffer-char
                #:buffer-cell-at
                #:buffer-cell-char
                #:buffer-cell-style
                #:set-buffer-cell-at)
  (:export #:run-tmux-idle))

(in-package :elmtui.examples.tmux-idle)

(defparameter +idle-width+ 80)
(defparameter +idle-height+ 8)
(defparameter +mutate-glyphs+ (vector #\# #\@ #\% #\& #\* #\+ #\= #\~ #\? #\$))

(defun %safe-parse-int (s &optional (default 0))
  (handler-case
      (parse-integer s)
    (error () default)))

(defun %tmux-geometry ()
  "Return cursor/pane geometry as (values cursor-x cursor-y pane-width pane-height)."
  (let* ((out (ignore-errors
                (uiop:run-program
                 '("tmux" "display-message" "-p" "#{cursor_x} #{cursor_y} #{pane_width} #{pane_height}")
                 :output :string
                 :ignore-error-status t)))
         (parts (and out (uiop:split-string (string-trim '(#\Space #\Tab #\Newline) out)
                                            :separator '(#\Space #\Tab)))))
    (if (and parts (>= (length parts) 4))
        (values (%safe-parse-int (first parts) 0)
                (%safe-parse-int (second parts) 0)
                (%safe-parse-int (third parts) +idle-width+)
                (%safe-parse-int (fourth parts) +idle-height+))
        (values 0 0 +idle-width+ +idle-height+))))

(defun %char-at (line col)
  (if (and (stringp line) (>= col 0) (< col (length line)))
      (aref line col)
      #\Space))

(defun %buffer-from-lines (lines width height)
  "Create WIDTHxHEIGHT virtual buffer from string LINES."
  (let ((buffer (make-virtual-buffer width height)))
    (loop for y from 0 below height do
      (let ((line (if (< y (length lines)) (aref lines y) "")))
        (loop for x from 0 below width do
          (set-buffer-cell-at buffer y x (%char-at line x) nil))))
    buffer))

(defun %slice-buffer (source start-x start-y width height)
  "Copy a rectangular slice from SOURCE into a new WIDTHxHEIGHT buffer."
  (let* ((src-w (buffer-width source))
         (src-h (buffer-height source))
         (out (make-virtual-buffer width height)))
    (loop for y from 0 below height do
      (loop for x from 0 below width do
        (let ((src-x (+ start-x x))
              (src-y (+ start-y y)))
          (if (and (>= src-x 0) (< src-x src-w)
                   (>= src-y 0) (< src-y src-h))
              (let ((cell (buffer-cell-at source src-y src-x)))
                (set-buffer-cell-at out y x
                                    (buffer-cell-char cell)
                                    (buffer-cell-style cell)))
              (set-buffer-cell-at out y x #\Space nil)))))
    out))

(defun %collect-mutable-points (base-buffer)
  "Return vector of points where underlying cells are visible (non-space)."
  (let ((points '()))
    (loop for y from 0 below (buffer-height base-buffer) do
      (loop for x from 0 below (buffer-width base-buffer) do
        (let ((ch (buffer-char base-buffer y x)))
          (when (and (characterp ch)
                     (not (char= ch #\Space)))
            (push (list :x x :y y :char ch) points)))))
    (coerce (nreverse points) 'vector)))

(defun %slice-with-fallback-mutable-points (full-buffer preferred-x preferred-y width height)
  "Slice FULL-BUFFER at preferred coords and collect mutable points.
If preferred slice has no mutable points, fallback to top-left slice."
  (labels ((slice+points (x y)
             (let* ((buf (%slice-buffer full-buffer x y width height))
                    (pts (%collect-mutable-points buf)))
               (values buf pts))))
    (multiple-value-bind (base points) (slice+points preferred-x preferred-y)
      (if (plusp (length points))
          (values base points)
          (multiple-value-bind (fallback-base fallback-points) (slice+points 0 0)
            (if (plusp (length fallback-points))
                (values fallback-base fallback-points)
                (values base points)))))))

(defun %initial-idle-state ()
  (let ((tmux? (tmux-available-p)))
    (if tmux?
        (multiple-value-bind (cursor-x cursor-y pane-w pane-h) (%tmux-geometry)
          (let* ((view-x (max 0 (min cursor-x (max 0 (- pane-w +idle-width+)))))
                 (view-y (max 0 (min (1+ cursor-y) (max 0 (- pane-h +idle-height+)))))
                 (styled-full (or (make-buffer-from-tmux-styled pane-w pane-h :mode :pane)
                                  (%buffer-from-lines (capture-lines :mode :pane) pane-w pane-h)))
                 (base-buffer nil)
                 (points nil))
            (multiple-value-setq (base-buffer points)
              (%slice-with-fallback-mutable-points styled-full view-x view-y +idle-width+ +idle-height+))
            (list :tmux-enabled t
                  :ticks 0
                  :status-label "Press any key to exit"
                  :exiting nil
                  :should-quit nil
                  :base-buffer base-buffer
                  :mutable-points points
                  :current-mutations nil
                  :previous-mutations nil
                  :mutable-count (length points))))
        (list :tmux-enabled nil
              :ticks 0
              :status-label "Press any key to exit"
              :exiting nil
              :should-quit nil
              :base-buffer (make-virtual-buffer +idle-width+ +idle-height+)
              :mutable-points #()
              :current-mutations nil
              :previous-mutations nil
              :mutable-count 0))))

(defun %next-mutation-indices (points ticks)
  (let ((count (length points)))
    (if (<= count 0)
        nil
        (let* ((n (min 16 count))
               (seed (mod (* (max 1 ticks) 11) count))
               (out '()))
          (loop for i from 0 below n do
            (push (mod (+ seed (* i 17)) count) out))
          (nreverse out)))))

(defun %mutation-char (base-char ticks idx)
  (declare (ignore base-char))
  (let* ((glyph-count (length +mutate-glyphs+))
         (gidx (mod (+ ticks idx) glyph-count)))
    (aref +mutate-glyphs+ gidx)))

(defun %apply-active-mutations (frame-buffer points current ticks)
  "Mutate only the character field for active points, preserving cell styles."
  (let ((count (length points)))
    (dolist (idx current)
      (when (and (integerp idx) (>= idx 0) (< idx count))
        (let* ((pt (aref points idx))
               (x (getf pt :x))
               (y (getf pt :y))
               (base (getf pt :char #\Space)))
          (setf (buffer-char frame-buffer y x)
                (%mutation-char base ticks idx))))))
  frame-buffer)

(defun %buffer-row-string (buffer row)
  (let ((width (buffer-width buffer))
        (out (make-string (buffer-width buffer) :initial-element #\Space)))
    (loop for x from 0 below width do
      (setf (aref out x) (buffer-char buffer row x)))
    out))

(defun idle-update (message app-state)
  (cond
    ((or (typep message 'key-event)
         (and (listp message)
              (member (first message) '(:keyevent :key-event))))
     ;; Exit immediately so we avoid rendering an additional "Exiting..." frame.
     (make-update-result :patches '(((:should-quit) t))))
    ((and (listp message) (eq (first message) :app-quit-requested))
     (make-update-result :patches '(((:should-quit) t))))
    ((or (eq message :tick)
         (and (listp message) (eq (first message) :tick)))
     (let* ((ticks (1+ (state-ref app-state :ticks 0)))
            (points (state-ref app-state :mutable-points #()))
            (current (state-ref app-state :current-mutations nil))
            (exiting (state-ref app-state :exiting nil))
            (next (if exiting nil (%next-mutation-indices points ticks))))
       (if exiting
           (make-update-result
            :patches `(((:ticks) ,ticks)
                       ((:previous-mutations) ,current)
                       ((:current-mutations) nil)
                       ((:should-quit) t)))
           (make-update-result
            :patches `(((:ticks) ,ticks)
                       ((:previous-mutations) ,current)
                       ((:current-mutations) ,next))))))
    (t
     (make-update-result))))

(defun %overlay-children (state)
  (let* ((points (state-ref state :mutable-points #()))
         (ticks (state-ref state :ticks 0))
         (current (state-ref state :current-mutations nil))
         (status (state-ref state :status-label "Press any key to exit"))
         (base-buffer (state-ref state :base-buffer (make-virtual-buffer +idle-width+ +idle-height+)))
         (frame-buffer (copy-virtual-buffer base-buffer))
         (height (buffer-height frame-buffer))
         (width (buffer-width frame-buffer)))
    (%apply-active-mutations frame-buffer points current ticks)
    ;; Overlay status text on first row so keypress transition is visible.
    (when (> height 0)
      (loop for i from 0 below (min (length status) width) do
        (setf (buffer-char frame-buffer 0 i) (aref status i))))
    ;; Render one text node per row (much cheaper than per-cell nodes).
    (loop for y from 0 below height
          collect `(:text :content ,(%buffer-row-string frame-buffer y)))))

(defun idle-view (state)
  (let ((tmux? (state-ref state :tmux-enabled nil))
        (ticks (state-ref state :ticks 0))
        (mutable-count (state-ref state :mutable-count 0)))
    (if tmux?
        `(:container
          :id :tmux-idle-overlay
          :style (:display :flex :flex-direction :column :width ,+idle-width+ :height ,+idle-height+)
          :children ,(%overlay-children state))
        `(:container
          :id :tmux-idle-root
          :style (:display :flex :flex-direction :column :padding 1 :width ,+idle-width+ :height ,+idle-height+)
          :children
          ((:text :content "tmux-idle [NO-TMUX]")
           (:text :content "Press any key to exit")
           (:text :content ,(format nil "ticks: ~D" ticks))
           (:text :content ,(format nil "mutable chars: ~D" mutable-count)))))))

(defun idle-subscriptions (app-state)
  ;; Returning NIL lets the runtime reconcile and cancel the active timer on quit.
  (unless (state-ref app-state :should-quit nil)
    ;; Keep interval short so exit-after-label is responsive.
    '(:timer (:interval 0.4 :message (:tick)))))

(defapplication tmux-idle-app
  :root-viewport-id :tmux-idle-root
  :root-component-dsl '(:root-viewport
                        :id :tmux-idle-root
                        :anchor :below-cursor
                        :overflow-policy :truncate
                        :width 80
                        :height 8
                        :blank-on-exit nil)
  :initial-state-fn #'%initial-idle-state
  :update-fn #'idle-update
  :subscriptions-fn idle-subscriptions
  :view-fn #'idle-view)

(defun run-tmux-idle (&key (backend-type :terminal) (mode :pane))
  (log-info "tmux-idle: start backend=~S mode=~S" backend-type mode)
  (run-tmux-idle-app
   :platform backend-type
   :platform-options (list :prefill-from-tmux t
                           :tmux-prefill-mode mode)))
