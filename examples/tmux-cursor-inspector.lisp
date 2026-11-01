;;; Physical, reversible tmux cell inspector. Never uses the alternate screen.
(eval-when (:compile-toplevel :load-toplevel :execute)
  ;; *LOAD-TRUENAME* can name a test runner or an ASDF FASL cache file.
  ;; Locate the maintained sources through ASDF instead of that caller context.
  (unless (find-package :elmtui-examples.cursor-inspector)
    (load (asdf:system-relative-pathname :elmtui-examples
                                         "examples/cursor-inspector.lisp")))
  (unless (find-package :elmtui.examples.tmux-slider)
    (load (asdf:system-relative-pathname :elmtui-examples
                                         "examples/tmux-slider.lisp"))))

(uiop:define-package :elmtui.examples.tmux-cursor-inspector
  (:use :cl)
  (:import-from :elmtui.platform.tmux
                #:tmux-available-p #:parse-ansi-string)
  (:export #:run-tmux-cursor-inspector #:snapshot-from-styled-string
           #:inspected-cell #:overlay-cells))
(in-package :elmtui.examples.tmux-cursor-inspector)

(defun %width (char)
  ;; Keep selection and snapshot coordinates in terminal cells, not codepoints.
  (elmtui-examples.cursor-inspector::%codepoint-width char))

(defun snapshot-from-styled-string (input width height)
  "Decode a styled tmux pane into terminal cells. A wide glyph owns its lead
and continuation cells; combining marks belong to their preceding base."
  (check-type width (integer 1 *))
  (check-type height (integer 1 *))
  (let ((cells (make-array (list height width)))
        (x 0) (y 0))
    (dotimes (row height)
      (dotimes (col width)
        (setf (aref cells row col)
              (list :glyph " " :width 1 :style nil :lead col))))
    (dolist (run (parse-ansi-string (or input "")))
      (loop for char across (car run)
            for cw = (%width char)
            do (cond
                 ((char= char #\Newline)
                  (incf y) (setf x 0))
                 ((char= char #\Return) nil)
                 ((and (zerop cw) (not (char= char #\Null)))
                  (when (and (< y height) (> x 0) (<= x width))
                    (let* ((previous (aref cells y (1- x)))
                           (lead (getf previous :lead))
                           (base (aref cells y lead)))
                      (setf (getf base :glyph)
                            (concatenate 'string (getf base :glyph)
                                         (string char))))))
                 (t
                  (when (and (< y height) (<= 0 x)
                             (<= (+ x cw) width))
                    (setf (aref cells y x)
                          (list :glyph (string char) :width cw
                                :style (copy-list (cdr run)) :lead x))
                    (loop for continuation from (1+ x)
                          below (+ x cw)
                          do (setf (aref cells y continuation)
                                   (list :glyph "" :width 0
                                         :style (copy-list (cdr run))
                                         :lead x))))
                  (incf x cw)))))
    (list :width width :height height :cells cells)))

(defun %capture-snapshot ()
  (multiple-value-bind (width height)
      (elmtui.examples.tmux-slider::%pane-size)
    (when (and width height (>= width 8) (>= height 6))
      (let ((raw (elmtui.examples.tmux-slider::%tmux-output
                  "capture-pane" "-e" "-p" "-S" "0")))
        (when raw (snapshot-from-styled-string raw width height))))))

(defun inspected-cell (snapshot x y)
  "Return the owning cell, start column and width at physical (X,Y)."
  (let* ((width (getf snapshot :width))
         (height (getf snapshot :height))
         (col (max 0 (min x (- width 2))))
         (row (max 0 (min y (1- height))))
         (cells (getf snapshot :cells))
         (lead (getf (aref cells row col) :lead))
         (cell (aref cells row lead)))
    (values cell lead (getf cell :width))))

(defun %pane-cursor ()
  (let ((reply (elmtui.examples.tmux-slider::%tmux-output
                "display-message" "-p" "#{cursor_x} #{cursor_y}")))
    (when reply
      (let ((parts (remove "" (uiop:split-string
                                (string-trim '(#\Space #\Newline) reply)
                                :separator '(#\Space))
                           :test #'string=)))
        (when (= (length parts) 2)
          (values (ignore-errors (parse-integer (first parts)))
                  (ignore-errors (parse-integer (second parts)))))))))

(defun %color (style)
  "The same SGR restoration encoder used by the proven tmux slider."
  (elmtui.examples.tmux-slider::%slider-restore-style style)
  ;; The slider supports the common attributes; preserve these additional
  ;; parsed SGR flags when restoring a physical underlay cell.
  (dolist (attribute (getf style :attrs))
    (let ((code (case attribute
                  (:blink 5)
                  (:strike 9)
                  (otherwise nil))))
      (when code (format t "~C[~Dm" #\Escape code)))))

(defun %move (x y)
  (format t "~C[~D;~DH" #\Escape (1+ y) (1+ x)))

(defun %original-row (snapshot y)
  "Repaint one touched row with the captured glyphs and exact SGR metadata.
Never write the final column, which could cause a terminal autowrap/scroll."
  (let ((cells (getf snapshot :cells))
        (limit (1- (getf snapshot :width)))
        (x 0))
    (loop while (< x limit)
          for cell = (aref cells y x)
          for cw = (getf cell :width)
          do (if (or (zerop cw) (> (+ x cw) limit))
                 (incf x)
                 (progn
                   (%move x y)
                   (%color (getf cell :style))
                   (write-string (getf cell :glyph))
                   (incf x cw))))))

(defun %tooltip-lines (snapshot x y cell)
  (let* ((glyph (getf cell :glyph))
         (style (getf cell :style))
         (char (if (plusp (length glyph)) (char glyph 0) #\Space))
         (name (format nil "CELL (~D,~D)  ~S  U+~4,'0X  width ~D"
                       x y glyph (char-code char) (getf cell :width)))
         (details (format nil "FG ~S  BG ~S  ATTR ~S"
                          (getf style :fg) (getf style :bg)
                          (getf style :attrs)))
         (available (min 70 (- (getf snapshot :width) 3)))
         (inside (max 4 (- available 4))))
    (flet ((line (label)
             ;; Pad by terminal cells, not codepoints: the selected glyph may
             ;; itself be CJK or contain a combining mark.
             (let* ((short (elmtui-examples.cursor-inspector::%slice-columns
                            label 0 inside))
                    (padding (make-string (max 0 (- inside
                                         (elmtui-examples.cursor-inspector::%display-width
                                          short)))
                                          :initial-element #\Space)))
               (format nil "│ ~A~A │" short padding))))
      (list (concatenate 'string "┌" (make-string (+ inside 2) :initial-element #\─) "┐")
            (line name)
            (line details)
            (concatenate 'string "└" (make-string (+ inside 2) :initial-element #\─) "┘")))))

(defun overlay-cells (snapshot x y)
  "Pure description of the cursor-box and B1 tooltip. Never alters SNAPSHOT.
Each entry is (X Y STRING SGR-STYLE); all writes stay before the right edge."
  (multiple-value-bind (cell lead cw) (inspected-cell snapshot x y)
    (let* ((width (getf snapshot :width))
           (height (getf snapshot :height))
           (result nil)
           (focus '(:fg (:rgb 10 12 20) :bg (:rgb 97 255 211)
                    :attrs (:bold)))
           (border '(:fg (:rgb 97 255 211) :attrs (:bold)))
           (tooltip-style '(:fg (:rgb 255 218 132) :attrs (:bold)))
           (space-right (- width (+ lead cw)))
           (box-p (and (> lead 0) (>= space-right 2)
                       (> y 0) (< y (1- height))))
           (tooltip (%tooltip-lines snapshot lead y cell))
           (tw (length (first tooltip)))
           (tx (if (<= (+ lead cw 3 tw) (1- width))
                   (+ lead cw 3)
                   (if (>= (- lead tw 3) 0) (- lead tw 3) 0)))
           (ty (if (<= (+ y 3 (length tooltip)) height)
                   (+ y 3)
                   (max 0 (- y 1 (length tooltip))))))
      (labels ((add (px py glyph style)
                 (when (and (<= 0 px)
                            (<= (+ px
                                   (elmtui-examples.cursor-inspector::%display-width
                                    glyph))
                                (1- width))
                            (<= 0 py) (< py height))
                   (push (list px py glyph style) result))))
        (when box-p
          (add (1- lead) (1- y) "┌" border)
          (add (+ lead cw) (1- y) "┐" border)
          (add (1- lead) y "│" border)
          (add (+ lead cw) y "│" border)
          (add (1- lead) (1+ y) "└" border)
          (add (+ lead cw) (1+ y) "┘" border)
          (dotimes (i cw)
            (add (+ lead i) (1- y) "─" border)
            (add (+ lead i) (1+ y) "─" border)))
        ;; Preserve the source glyph itself; background highlight marks the
        ;; actual selected terminal cell, including two-column wide glyphs.
        (add lead y (getf cell :glyph) focus)
        (loop for line in tooltip for row from ty
              do (loop with col = tx
                       for ch across line
                       for cw = (%width ch)
                       do (if (zerop cw)
                              (when (and result (= (second (first result)) row))
                                (setf (third (first result))
                                      (concatenate 'string
                                                   (third (first result))
                                                   (string ch))))
                              (progn
                                (add col row (string ch) tooltip-style)
                                (incf col cw)))))
      (nreverse result)))))

(defun %paint-frame (snapshot old-overlay new-overlay)
  "Restore just the union of formerly and newly touched rows, then draw.
No newline, screen clearing, history changes, or idle writes."
  (let ((rows (remove-duplicates
               (append (mapcar #'second old-overlay)
                       (mapcar #'second new-overlay)))))
    (dolist (y (sort rows #'<))
      (%original-row snapshot y))
    (dolist (entry new-overlay)
      (destructuring-bind (x y glyph style) entry
        (%move x y) (%color style) (write-string glyph)))
    (format t "~C[0m~C8" #\Escape #\Escape)
    (finish-output)))

(defun %next-key ()
  "Read raw keys without polling; gather a CSI cursor sequence if present."
  (flet ((pending ()
           ;; READ-CHAR may have already buffered the rest of a tmux key
           ;; sequence. A raw fd-only readiness test misses those bytes.
           (or (listen *standard-input*)
               (sb-sys:wait-until-fd-usable 0 :input 0.09))))
    (let ((char (read-char *standard-input* nil nil)))
    (cond
      ((null char) :quit)
      ((char= char #\Escape)
       (if (pending)
           (let ((prefix (read-char *standard-input* nil nil)))
             (if (and prefix (find prefix "[O"))
                 (if (pending)
                     (case (read-char *standard-input* nil nil)
                       (#\A :up) (#\B :down) (#\C :right) (#\D :left)
                       (otherwise :ignore))
                     :ignore)
                 :quit))
           :quit))
      (t (case char
           ((#\q #\Q) :quit)
           ((#\h #\H) :left)
           ((#\j #\J) :down)
           ((#\k #\K) :up)
           ((#\l #\L) :right)
           (otherwise :ignore)))))))

(defun %next-position (snapshot x y direction)
  (let* ((width (getf snapshot :width))
         (height (getf snapshot :height)))
    (multiple-value-bind (cell lead cw) (inspected-cell snapshot x y)
      (declare (ignore cell))
      (case direction
        (:left (setf x (max 0 (1- lead))))
        (:right (setf x (min (- width 2) (+ lead cw))))
        (:up (setf y (max 0 (1- y))))
        (:down (setf y (min (1- height) (1+ y)))))
      (multiple-value-bind (new-cell start) (inspected-cell snapshot x y)
        (declare (ignore new-cell))
        (values start y)))))

(defun %run-overlay (snapshot)
  (let* ((saved (sb-posix:tcgetattr 0))
         (raw (sb-posix:tcgetattr 0))
         (overlay nil)
         (x 0) (y 0))
    (multiple-value-bind (cx cy) (%pane-cursor)
      (setf x (or cx 0) y (or cy 0)))
    (multiple-value-bind (cell lead) (inspected-cell snapshot x y)
      (declare (ignore cell))
      (setf x lead y (max 0 (min y (1- (getf snapshot :height))))))
    (setf (sb-posix:termios-lflag raw)
          (logand (sb-posix:termios-lflag raw)
                  (lognot (logior sb-posix:icanon sb-posix:echo))))
    (format t "~C7" #\Escape)
    (finish-output)
    (unwind-protect
         (progn
           (sb-posix:tcsetattr 0 sb-posix:tcsanow raw)
           (setf overlay (overlay-cells snapshot x y))
           (%paint-frame snapshot nil overlay)
           (loop for action = (%next-key)
                 do (when (eq action :quit) (return))
                    (unless (eq action :ignore)
                      (multiple-value-bind (nx ny)
                          (%next-position snapshot x y action)
                        (unless (and (= nx x) (= ny y))
                          (let ((next (overlay-cells snapshot nx ny)))
                            (%paint-frame snapshot overlay next)
                            (setf overlay next x nx y ny)))))))
      (unwind-protect
           (%paint-frame snapshot overlay nil)
        (sb-posix:tcsetattr 0 sb-posix:tcsanow saved)
        (format t "~C[0m~C8" #\Escape #\Escape)
        (finish-output)))))

(defun run-tmux-cursor-inspector (&key (backend-type :terminal))
  "Highlight a real tmux pane cell and show its data in a movable tooltip.
Restores every affected cell and termios on exit; no alternate screen."
  (unless (eq backend-type :terminal)
    (error "tmux-cursor-inspector requires the real terminal backend"))
  (unless (tmux-available-p)
    (format *error-output*
            "tmux-cursor-inspector requires a live tmux pane; untouched.~%")
    (return-from run-tmux-cursor-inspector nil))
  (let ((snapshot (%capture-snapshot)))
    (unless snapshot
      (format *error-output*
              "tmux-cursor-inspector could not capture pane; untouched.~%")
      (return-from run-tmux-cursor-inspector nil))
    (%run-overlay snapshot)))
