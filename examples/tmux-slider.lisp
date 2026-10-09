(uiop:define-package :elmtui.examples.tmux-slider (:use :cl) (:import-from :elmtui.app #:defapplication) (:import-from :elmtui.core.event-types #:key-event #:key-event-key #:key-event-char) (:import-from :elmtui.state.api #:state-ref #:make-update-result) (:import-from :elmtui.platform.tmux #:tmux-available-p #:parse-ansi-string) (:export #:run-tmux-slider #:slider-view #:slider-update #:slider-subscriptions #:snapshot-from-styled-string #:slider-rows #:*slider-snapshot*))
(in-package :elmtui.examples.tmux-slider)
(defvar *slider-snapshot* nil)
(defvar *slider-initial-speed* 0.085)
(defvar *slider-max-frames* nil)
(defun %tmux-output (&rest args) (handler-case (uiop:run-program (cons "tmux" args) :output :string :ignore-error-status nil) (error () nil)))
(defun %pane-size () (let ((out (%tmux-output "display-message" "-p" "#{pane_width} #{pane_height}"))) (when out (let ((parts (remove "" (uiop:split-string (string-trim ' (#\Space #\Newline #\Tab) out) :separator ' (#\Space #\Tab)) :test #'string=))) (when (= (length parts) 2) (let ((width (ignore-errors (parse-integer (first parts)))) (height (ignore-errors (parse-integer (second parts))))) (when (and width height (> width 0) (> height 0)) (values width height))))))))
(defun snapshot-from-styled-string (content width height) "Pure input fixture parser. Each entry is a (glyph . SGR-style) cell. A newline advances exactly one row, even when the row exactly fills WIDTH." (check-type width (integer 1 *)) (check-type height (integer 1 *)) (let ((cells (make-array (list height width))) (row 0) (col 0)) (loop for y below height do (loop for x below width do (setf (aref cells y x) (cons #\Space nil)))) (dolist (run (parse-ansi-string (or content ""))) (loop for ch across (car run) do (cond ((char= ch #\Newline) (incf row) (setf col 0)) ((char= ch #\Return) nil) ((and (< row height) (< col width)) (setf (aref cells row col) (cons ch (copy-list (cdr run)))) (incf col)) ((< row height) (incf col))))) (list :width width :height height :cells cells)))
(defun %capture-styled-pane () (multiple-value-bind (width height) (%pane-size) (when (and width height) (let ((content (%tmux-output "capture-pane" "-p" "-e" "-S" "0"))) (when content (snapshot-from-styled-string content width height))))))
(defun %pressed (message &rest candidates) (let ((key (cond ((typep message 'key-event) (key-event-key message)) ((and (consp message) (member (first message) ' (:keyevent :key-event))) (getf (rest message) :key))))) (let ((char (cond ((typep message 'key-event) (key-event-char message)) ((and (consp message) (member (first message) ' (:keyevent :key-event))) (getf (rest message) :char))))) (or (member key candidates :test #'eql) (member char candidates :test #'eql)))))
(defun %patch (&rest pairs) (make-update-result :patches (loop for (key value) on pairs by #'cddr collect (list (list key) value))))
(defun slider-update (message state) (cond ((or (%pressed message :q #\q #\Q :escape :esc #\Escape) (and (consp message) (eq (first message) :app-quit-requested))) (%patch :should-quit t)) ((%pressed message :space #\Space #\p #\P) (%patch :running (not (state-ref state :running t)))) ((%pressed message :left :arrow-left) (%patch :dx -1)) ((%pressed message :right :arrow-right) (%patch :dx 1)) ((%pressed message :up :arrow-up #\+) (%patch :period (max 0.035 (- (state-ref state :period 0.085) 0.02)))) ((%pressed message :down :arrow-down #\-) (%patch :period (min 0.5 (+ (state-ref state :period 0.085) 0.02)))) ((or (eq message :tick) (and (consp message) (eq (first message) :tick))) (if (state-ref state :running t) (let* ((next (1+ (state-ref state :tick 0))) (limit (state-ref state :max-frames nil))) (%patch :tick next :should-quit (and limit (>= next limit)))) (make-update-result))) (t (make-update-result))))
(defun slider-subscriptions (state) "A paused slider has no timer and no periodic idle writes." (when (and (state-ref state :running t) (not (state-ref state :should-quit nil))) (list :timer (list :interval (state-ref state :period 0.085) :message ' (:tick)))))
(defun %cell-presentation (snapshot x y tick dx) (let* ((cell (aref (getf snapshot :cells) y x)) (style (cdr cell)) (width (getf snapshot :width)) (height (getf snapshot :height)) (hud (format nil " TMUX / CYAN SHIFT | FRAME ~4,'0D | ~A | SPACE PAUSE Q QUIT " tick (if (plusp dx) "EAST" "WEST"))) (index (mod (* (abs dx) tick) (+ width 8))) (left (if (minusp dx) (- width index) index)) (band (- x left)) (active (and (> y 0) (< y (1- height)) (<= 0 band) (< band 8))) (hud-p (and (zerop y) (< x (length hud)))) (fg (cond (hud-p ' (236 245 255)) (active ' (240 251 255)) (t (getf style :fg)))) (bg (cond (hud-p ' (38 35 94)) (active (cond ((or (= band 0) (= band 7)) ' (46 212 249)) ((evenp band) ' (55 46 132)) (t ' (32 102 153)))) (t (getf style :bg)))) (attrs (if (or active hud-p) ' (:bold) (getf style :attrs)))) (values (if hud-p (char hud x) (car cell)) fg bg attrs)))
(defun %line-children (snapshot y tick dx) (let* ((width (getf snapshot :width)) (output nil) (start 0) (previous nil) (chars (make-string width :initial-element #\Space))) (labels ((flush-run (end style) (when (> end start) (push (list :text :id (intern (format nil "SLIDER-~D-~D" y start) :keyword) :content (subseq chars start end) :style (list :width (- end start) :height 1 :fg-color (first style) :bg-color (second style) :bold (and (member :bold (third style)) t) :italic (and (member :italic (third style)) t) :underline (and (member :underline (third style)) t))) output)))) (loop for x below width do (multiple-value-bind (ch fg bg attrs) (%cell-presentation snapshot x y tick dx) (setf (aref chars x) ch) (let ((style (list fg bg attrs))) (unless (or (null previous) (equal previous style)) (flush-run x previous) (setf start x)) (setf previous style)))) (flush-run width previous)) (nreverse output)))
(defun slider-rows (snapshot tick dx) "Pure DSL frame: render untouched snapshot glyphs with a transient color band." (loop for y from 0 below (getf snapshot :height) collect (list :container :id (intern (format nil "SLIDER-ROW-~D" y) :keyword) :style (list :display :flex :flex-direction :row :height 1 :width (getf snapshot :width) :padding 0 :gap 0) :children (%line-children snapshot y tick dx))))
(defun slider-view (state) (let* ((snap (state-ref state :snapshot *slider-snapshot*)) (width (getf snap :width)) (height (getf snap :height))) (list :container :id :slider-frame :style (list :display :flex :flex-direction :column :width width :height height :padding 0 :gap 0) :children (slider-rows snap (state-ref state :tick 0) (state-ref state :dx 1)))))
(defun %initial-state () (list :snapshot *slider-snapshot* :tick 0 :dx 1 :running t :period *slider-initial-speed* :max-frames *slider-max-frames* :should-quit nil))
(defapplication tmux-slider-app :root-viewport-id :tmux-slider-root :root-component-dsl ' (:root-viewport :id :tmux-slider-root :anchor :top-left :width 100 :height 35 :overflow-policy :truncate :blank-on-exit nil :child-dsl-spec (:view nil)) :initial-state-fn #'%initial-state :update-fn #'slider-update :view-fn #'slider-view :subscriptions-fn slider-subscriptions)
(defun %slider-color-sgr (color background)
  "Encode parsed 8/256/true-color tmux styles without guessing color structs."
  (cond
    ((and (consp color) (eq (first color) :256)
          (integerp (second color)))
     (format nil "~C[~D;5;~Dm" #\Escape (if background 48 38)
             (second color)))
    ((and (consp color) (eq (first color) :rgb)
          (= (length color) 4)
          (every (lambda (part) (and (integerp part) (<= 0 part 255)))
                 (rest color)))
     (format nil "~C[~D;2;~D;~D;~Dm" #\Escape
             (if background 48 38) (second color) (third color) (fourth color)))
    ((keywordp color)
     (elmtui.platform.backend.common.ansi-styling::to-ansi-seq
      color :bg background))
    (t "")))
(defun %slider-restore-style (style)
  "Emit the recorded cell's foreground, background and attributes."
  (format t "~C[0m" #\Escape)
  (when style
    (let ((fg (getf style :fg))
          (bg (getf style :bg)))
      (when fg
        (write-string
         (%slider-color-sgr fg nil)))
      (when bg
        (write-string
         (%slider-color-sgr bg t)))
      (dolist (attr (getf style :attrs))
        (let ((code (case attr
                      (:bold 1) (:dim 2) (:italic 3)
                      (:underline 4) (:inverse 7) (otherwise nil))))
          (when code (format t "~C[~Dm" #\Escape code)))))))
(defun %slider-paint-cell (snapshot x y highlighted)
  "Change only SGR colors, always preserving the captured glyph."
  (let* ((cell (aref (getf snapshot :cells) y x))
         (glyph (car cell)))
    (format t "~C[~D;~DH" #\Escape (1+ y) (1+ x))
    (if highlighted
        (format t "~C[0;1;38;2;235;255;255;48;2;16;126;182m" #\Escape)
        (%slider-restore-style (cdr cell)))
    (write-char glyph)))
(defun %slider-band (snapshot offset highlighted)
  "Paint or restore a narrow column band without adding scrollback rows."
  (let ((width (getf snapshot :width))
        (height (getf snapshot :height)))
    (loop for y below height do
      (loop for x from (max 0 offset)
            below (min (1- width) (+ offset 8))
            do (%slider-paint-cell snapshot x y highlighted)))
    (format t "~C8" #\Escape)
    (finish-output)))
(defun %run-slider-overlay (snapshot speed frames)
  "Move a transient color band through the preserved tmux pane.
No alternate buffer, newline, scroll or clear is ever requested."
  (let* ((width (getf snapshot :width))
         (offset 0)
         (step 1)
         (count 0)
         (paused nil)
         (saved (sb-posix:tcgetattr 0))
         (working (sb-posix:tcgetattr 0)))
    (setf (sb-posix:termios-lflag working)
          (logand (sb-posix:termios-lflag working)
                  (lognot (logior sb-posix:icanon sb-posix:echo))))
    (format t "~C7" #\Escape)
    (finish-output)
    (unwind-protect
         (progn
           (sb-posix:tcsetattr 0 sb-posix:tcsanow working)
           (%slider-band snapshot offset t)
           (loop
             (sleep (if paused 0.04 speed))
             (let ((key (when (listen *standard-input*)
                          (read-char *standard-input* nil nil))))
               (when key
                 (case key
                   ((#\q #\Q #\Escape) (return))
                   ((#\Space #\p #\P) (setf paused (not paused)))
                   ((#\h #\H) (setf step -1))
                   ((#\l #\L) (setf step 1))
                   (otherwise nil))))
             (unless paused
               (%slider-band snapshot offset nil)
               (setf offset (mod (+ offset step width) width))
               (%slider-band snapshot offset t)
               (incf count)
               (when (and frames (>= count frames)) (return)))))
      (%slider-band snapshot offset nil)
      (sb-posix:tcsetattr 0 sb-posix:tcsanow saved)
      (format t "~C[0m~C8" #\Escape #\Escape)
      (finish-output))))
(defun run-tmux-slider (&key (backend-type :terminal) (speed 0.085) frames)
  "Animate a styled translucent band in place; restore exact pane content on exit."
  (unless (eq backend-type :terminal)
    (error "Tmux slider requires the terminal backend."))
  (unless (tmux-available-p)
    (format *error-output*
            "tmux-slider requires a live tmux pane; no terminal state was changed.~%")
    (return-from run-tmux-slider nil))
  (let ((snapshot (%capture-styled-pane)))
    (unless snapshot
      (format *error-output*
              "tmux-slider: styled pane capture failed; terminal left untouched.~%")
      (return-from run-tmux-slider nil))
    (%run-slider-overlay snapshot (max 0.035 (min 0.5 speed)) frames)))
