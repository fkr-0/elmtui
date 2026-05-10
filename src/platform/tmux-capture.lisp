;;;===============================================================
;;; File: src/platform/tmux-capture.lisp
;;; Tmux screen capture helpers for buffer prefill
;;;===============================================================

(uiop:define-package :elmtui.platform.tmux
  (:use :cl)
  (:import-from :alexandria #:clamp)
  (:import-from :uiop
    #:run-program
    #:getenv
    #:find-program*)
  (:import-from :elmtui.platform.api
    #:term-w #:term-h)
  (:import-from :elmtui.platform.backend.terminal
    #:terminal-instance
    #:terminal-instance-front-buffer
    #:terminal-instance-back-buffer)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:virtual-terminal-buffer
    #:buffer-width
    #:buffer-height
    #:make-virtual-buffer
    #:copy-virtual-buffer
    #:set-buffer-cell-at
    #:clear-buffer
    #:with-virtual-buffer-lock)
  (:import-from :elmtui.platform.backend.common.ansi-styling
    #:style-to-terminal-style)
  (:export
    #:tmux-available-p
    #:capture-pane-string
    #:capture-screen-string
    #:prefill-buffer-from-string
    #:prefill-buffer-from-styled-content
    #:prefill-backend-from-tmux
    #:prefill-backend-from-tmux-styled
    #:make-buffer-from-tmux
    #:make-buffer-from-tmux-styled
    #:capture-lines
    #:split-by-ansi-sequences
    #:parse-ansi-sgr
    #:parse-ansi-string
    #:save-tmux-capture
    #:restore-to-tmux-capture
    #:has-saved-tmux-capture
    #:clear-saved-tmux-capture))

(in-package :elmtui.platform.tmux)

;;;----------------------------------------------------------------
;;; Environment helpers
;;;----------------------------------------------------------------
(defun %tmux-program ()
  "Locate the tmux binary if available using PATH search."
  (or (ignore-errors (find-program* "tmux"))
      (when (probe-file "/usr/bin/tmux") "/usr/bin/tmux")
      (when (probe-file "/bin/tmux") "/bin/tmux")
      (ignore-errors
        ;; Final fallback: try executing tmux directly from PATH.
        (run-program '("tmux" "-V")
                     :output :string
                     :error nil
                     :ignore-error-status t)
        "tmux")))

(defun tmux-available-p ()
  "Return true when tmux is available and current process is running inside tmux."
  (and (%tmux-program)
       (not (null (or (getenv "TMUX_PANE")
                      (getenv "TMUX"))))))

(defun %run-tmux (&rest args)
  "Execute tmux with ARGS and return its stdout as a string."
  (when (tmux-available-p)
    (handler-case
      (run-program (cons (%tmux-program) args)
        :output :string
        :input nil
        :error :output
        :ignore-error-status t)
      (error () nil))))

;;;----------------------------------------------------------------
;;; Capture utilities
;;;----------------------------------------------------------------

(defun %split-string-keep-empty (content separator)
  "Split CONTENT by SEPARATOR, preserving empty segments."
  (when content
    (let ((sep (if (consp separator) (first separator) separator))
           (result '())
           (start 0)
           (len (length content)))
      (loop for i from 0 below len do
        (when (char= (aref content i) sep)
          (push (subseq content start i) result)
          (setf start (1+ i))))
      (push (subseq content start len) result)
      (nreverse result))))

(defun capture-pane-string (&key (mode :pane))
  "Capture the current tmux pane (MODE :pane or :screen) and return it as a string.
The -e flag ensures escape sequences are included for style preservation."
  (case mode
    ;; Include tmux history (-S -) so we can prefill large terminal buffers
    ;; from the latest visible lines instead of leaving uncovered regions blank.
    (:screen (%run-tmux "capture-pane" "-e" "-J" "-p" "-S" "-"))
    (otherwise (%run-tmux "capture-pane" "-e" "-p" "-S" "-"))))

(defun capture-screen-string ()
  "Shortcut for capturing the entire tmux screen."
  (capture-pane-string :mode :screen))

(defun capture-lines (&key (mode :pane))
  "Capture tmux output and return a vector of lines."
  (let* ((content (capture-pane-string :mode mode))
         (lines (%split-string-keep-empty content '(#\Newline))))
    (if lines
        (coerce lines 'vector)
        #())))

;;;----------------------------------------------------------------
;;; ANSI Sequence Parsing
;;;----------------------------------------------------------------

(defun %esc-p (char)
  "Check if CHAR is the ESC character."
  (char= char #\Escape))

(defun split-by-ansi-sequences (content)
  "Split CONTENT into segments separated by ANSI escape sequences.
Returns a list of alternating plain text and ANSI sequences.
Consecutive plain text segments are merged together."
  (unless content
    (return-from split-by-ansi-sequences '()))
  (let ((result '())
        (current-segment (make-string-output-stream))
        (in-escape nil)
        (i 0)
        (len (length content)))
    (loop
      (when (>= i len)
        (let ((seg (get-output-stream-string current-segment)))
          (when (plusp (length seg))
            (push seg result)))
        (return))
      (let ((char (aref content i)))
        (cond
          ((and (not in-escape) (%esc-p char))
           (let ((seg (get-output-stream-string current-segment)))
             (when (plusp (length seg))
               (push seg result)))
           (setf current-segment (make-string-output-stream))
           (write-char char current-segment)
           (setf in-escape t)
           (incf i))
          (in-escape
           (write-char char current-segment)
           (when (alpha-char-p char)
             (let ((seg (get-output-stream-string current-segment)))
               (push seg result))
             (setf current-segment (make-string-output-stream))
             (setf in-escape nil))
           (incf i))
          (t
           (write-char char current-segment)
           (incf i)))))
    (let ((merged '())
          (current-plain ""))
      (dolist (seg (nreverse result))
        (if (and (> (length seg) 0) (%esc-p (aref seg 0)))
            (progn
              (when (plusp (length current-plain))
                (push current-plain merged))
              (setf current-plain "")
              (push seg merged))
            (setf current-plain (concatenate 'string current-plain seg))))
      (when (plusp (length current-plain))
        (push current-plain merged))
      (nreverse merged))))

(defun %sgr-code->color (code kind)
  "Convert SGR color CODE to keyword.
KIND is :fg for foreground (30-37, 90-97) or :bg for background (40-47, 100-107)."
  (let ((base (ecase kind (:fg 30) (:bg 40))))
    (cond
      ((and (eq kind :fg) (>= code 90) (<= code 97))
       (let ((offset (- code 90)))
         (ecase offset
           (0 :bright-black)
           (1 :bright-red)
           (2 :bright-green)
           (3 :bright-yellow)
           (4 :bright-blue)
           (5 :bright-magenta)
           (6 :bright-cyan)
           (7 :bright-white))))
      ((and (eq kind :bg) (>= code 100) (<= code 107))
       (let ((offset (- code 100)))
         (ecase offset
           (0 :bright-black)
           (1 :bright-red)
           (2 :bright-green)
           (3 :bright-yellow)
           (4 :bright-blue)
           (5 :bright-magenta)
           (6 :bright-cyan)
           (7 :bright-white))))
      ((and (>= code base) (<= code (+ base 7)))
       (let ((offset (- code base)))
         (ecase offset
           (0 :black)
           (1 :red)
           (2 :green)
           (3 :yellow)
           (4 :blue)
           (5 :magenta)
           (6 :cyan)
           (7 :white))))
      (t nil))))

(defun %sgr-code->attr (code)
  "Convert SGR attribute CODE to keyword."
  (case code
    (0 :reset)
    (1 :bold)
    (2 :dim)
    (3 :italic)
    (4 :underline)
    (5 :blink)
    (6 :blink-rapid)
    (7 :inverse)
    (8 :invisible)
    (9 :strike)
    (20 :fraktur-off)
    (21 :double-underline)
    (22 :normal-intensity)
    (23 :not-italic)
    (24 :not-underline)
    (25 :blink-off)
    (26 :proportional)
    (27 :not-inverse)
    (28 :not-hidden)
    (29 :not-strike)
    (53 :overline)
    (55 :not-overline)
    (t nil)))

(defun parse-ansi-sgr (sequence)
  "Parse an ANSI SGR (Select Graphic Rendition) sequence into a style plist.
Returns NIL if the sequence is a reset, or a plist with :fg, :bg, :attrs keys."
  (unless (and sequence (> (length sequence) 2))
    (return-from parse-ansi-sgr nil))
  (unless (and (char= (aref sequence 0) #\Escape)
               (char= (aref sequence 1) #\[)
               (alpha-char-p (aref sequence (1- (length sequence)))))
    (return-from parse-ansi-sgr nil))
  (let* ((end (1- (length sequence)))
         (params (subseq sequence 2 end)))
    (when (string= params "")
      (return-from parse-ansi-sgr nil))
    (let* ((parts (loop for start = 0 then (1+ end)
                        while start
                        for end = (position #\; params :start start)
                        collect (subseq params start end)
                        unless end do (loop-finish)))
           (codes (mapcar #'parse-integer parts))
           (fg nil)
           (bg nil)
           (attrs '()))
      (let ((i 0))
        (loop while (< i (length codes))
              do (let ((code (elt codes i)))
                   (cond
                     ((= code 0)
                      (return-from parse-ansi-sgr nil))
                     ((= code 38)
                      (if (< (+ i 1) (length codes))
                          (let ((mode (elt codes (+ i 1))))
                            (cond
                              ((and (= mode 5) (< (+ i 2) (length codes)))
                               (setf fg (list :256 (elt codes (+ i 2))))
                               (incf i 3))
                              ((and (= mode 2) (< (+ i 4) (length codes)))
                               (setf fg (list :rgb (elt codes (+ i 2))
                                              (elt codes (+ i 3))
                                              (elt codes (+ i 4))))
                               (incf i 5))
                              (t
                               (setf fg :default)
                               (incf i))))
                          (progn
                            (setf fg :default)
                            (incf i))))
                     ((= code 48)
                      (if (< (+ i 1) (length codes))
                          (let ((mode (elt codes (+ i 1))))
                            (cond
                              ((and (= mode 5) (< (+ i 2) (length codes)))
                               (setf bg (list :256 (elt codes (+ i 2))))
                               (incf i 3))
                              ((and (= mode 2) (< (+ i 4) (length codes)))
                               (setf bg (list :rgb (elt codes (+ i 2))
                                              (elt codes (+ i 3))
                                              (elt codes (+ i 4))))
                               (incf i 5))
                              (t
                               (setf bg :default)
                               (incf i))))
                          (progn
                            (setf bg :default)
                            (incf i))))
                     ((or (and (>= code 30) (<= code 37))
                          (and (>= code 90) (<= code 97)))
                      (setf fg (%sgr-code->color code :fg))
                      (incf i))
                     ((= code 39)
                      (setf fg :default)
                      (incf i))
                     ((or (and (>= code 40) (<= code 47))
                          (and (>= code 100) (<= code 107)))
                      (setf bg (%sgr-code->color code :bg))
                      (incf i))
                     ((= code 49)
                      (setf bg :default)
                      (incf i))
                     (t
                      (let ((attr (%sgr-code->attr code)))
                        (when attr
                          (push attr attrs)))
                      (incf i))))))
      (let ((result '()))
        (when fg (setf (getf result :fg) fg))
        (when bg (setf (getf result :bg) bg))
        (when attrs (setf (getf result :attrs) (nreverse attrs)))
        (when (or fg bg attrs)
          result)))))

(defun %style-attrs (style-plist)
  (copy-list (or (getf style-plist :attrs)
                 (getf style-plist :attributes)
                 '())))

(defun %remove-style-attrs (attrs removals)
  (loop for attr in attrs
        unless (member attr removals)
        collect attr))

(defun %normalize-style-plist (style-plist)
  (when style-plist
    (let ((result '())
          (fg (getf style-plist :fg :__missing__))
          (bg (getf style-plist :bg :__missing__))
          (attrs (%style-attrs style-plist)))
      (unless (eq fg :__missing__)
        (setf (getf result :fg) fg))
      (unless (eq bg :__missing__)
        (setf (getf result :bg) bg))
      (when attrs
        (setf (getf result :attrs) attrs))
      result)))

(defun %merge-ansi-style (current-style parsed-style)
  "Merge PARSED-STYLE into CURRENT-STYLE while respecting ANSI reset/off semantics."
  (let* ((result (or (%normalize-style-plist current-style) '()))
         (parsed-fg (getf parsed-style :fg :__missing__))
         (parsed-bg (getf parsed-style :bg :__missing__))
         (attrs (%style-attrs parsed-style)))
    (unless (eq parsed-fg :__missing__)
      (if (eq parsed-fg :default)
          (remf result :fg)
          (setf (getf result :fg) parsed-fg)))
    (unless (eq parsed-bg :__missing__)
      (if (eq parsed-bg :default)
          (remf result :bg)
          (setf (getf result :bg) parsed-bg)))
    (when attrs
      (let ((current-attrs (%style-attrs result)))
        (dolist (attr attrs)
          (case attr
            (:bold (pushnew :bold current-attrs))
            ((:dim :faint) (pushnew :dim current-attrs))
            (:italic (pushnew :italic current-attrs))
            ((:underline :double-underline) (pushnew :underline current-attrs))
            ((:blink :blink-rapid) (pushnew :blink current-attrs))
            (:inverse (pushnew :inverse current-attrs))
            (:invisible (pushnew :invisible current-attrs))
            (:strike (pushnew :strike current-attrs))
            (:overline (pushnew :overline current-attrs))
            (:normal-intensity
             (setf current-attrs (%remove-style-attrs current-attrs '(:bold :dim))))
            ((:not-italic :fraktur-off)
             (setf current-attrs (%remove-style-attrs current-attrs '(:italic))))
            (:not-underline
             (setf current-attrs (%remove-style-attrs current-attrs '(:underline))))
            (:blink-off
             (setf current-attrs (%remove-style-attrs current-attrs '(:blink))))
            (:not-inverse
             (setf current-attrs (%remove-style-attrs current-attrs '(:inverse))))
            (:not-hidden
             (setf current-attrs (%remove-style-attrs current-attrs '(:invisible))))
            (:not-strike
             (setf current-attrs (%remove-style-attrs current-attrs '(:strike))))
            (:not-overline
             (setf current-attrs (%remove-style-attrs current-attrs '(:overline))))
            (otherwise nil)))
        (if current-attrs
            (setf (getf result :attrs) (nreverse current-attrs))
            (remf result :attrs))))
    (and result result)))

(defun parse-ansi-string (content)
  "Parse CONTENT into a list of (substring . style) pairs.
ANSI escape sequences are extracted and converted to style plists."
  (unless content
    (return-from parse-ansi-string '()))
  (let ((segments (split-by-ansi-sequences content))
        (result '())
        (current-style nil))
    (dolist (seg segments)
      (if (and (> (length seg) 0) (%esc-p (aref seg 0)))
          (let ((parsed (parse-ansi-sgr seg)))
            (if (null parsed)
                (setf current-style nil)
                (setf current-style (%merge-ansi-style current-style parsed))))
          (when (plusp (length seg))
            (push (cons seg current-style) result))))
    (nreverse result)))

;;;----------------------------------------------------------------
;;; Buffer population
;;;----------------------------------------------------------------

(defun %normalize-lines (content width height)
  "Return a vector of lines sized for WIDTH/HEIGHT given CONTENT string."
  (declare (ignore width))
  (let* ((raw-lines (%split-string-keep-empty content '(#\Newline)))
         (vector-lines (or (and raw-lines (coerce raw-lines 'vector))
                           (make-array 0 :element-type 'string))))
    (let ((result (make-array height :element-type 'string :initial-element "")))
      (let ((start (max 0 (- (length vector-lines) height))))
        (loop for row from 0 below height do
          (setf (aref result row)
                (if (< (+ start row) (length vector-lines))
                    (aref vector-lines (+ start row))
                    "")))
        result))))

(defun prefill-buffer-from-string (buffer content &key (width (buffer-width buffer)) (height (buffer-height buffer)))
  "Fill BUFFER (virtual-terminal-buffer) with CONTENT text."
  (when (and buffer content)
    (let ((lines (%normalize-lines content width height)))
      (with-virtual-buffer-lock (buffer)
        (clear-buffer buffer)
        (loop for row from 0 below height do
          (let* ((line (aref lines row))
                 (line-length (length line)))
            (loop for col from 0 below width do
              (let ((ch (if (< col line-length)
                            (aref line col)
                            #\Space)))
                (set-buffer-cell-at buffer row col ch nil))))))
      buffer)))

(defun make-buffer-from-tmux (width height &key (mode :pane))
  "Create a virtual buffer populated from tmux output."
  (when (tmux-available-p)
    (let ((content (capture-pane-string :mode mode)))
      (when content
        (let ((buffer (make-virtual-buffer width height)))
          (prefill-buffer-from-string buffer content :width width :height height))))))

(defun %maybe-copy-buffer (buffer)
  (when (typep buffer 'virtual-terminal-buffer)
    (copy-virtual-buffer buffer)))

(defun prefill-backend-from-tmux (backend &key (mode :pane))
  "Prefill terminal backend buffers from current tmux capture.
Returns a virtual buffer copy that can be used as the driver's previous frame."
  (when (and (tmux-available-p)
             (typep backend 'terminal-instance))
    (let* ((width (term-w backend))
           (height (term-h backend))
           (content (capture-pane-string :mode mode)))
      (when (and content width height)
        (let ((front (terminal-instance-front-buffer backend))
              (back (terminal-instance-back-buffer backend)))
          (when front
            (prefill-buffer-from-string front content :width width :height height))
          (when back
            (prefill-buffer-from-string back content :width width :height height))
          (let ((snapshot (make-virtual-buffer width height)))
            (prefill-buffer-from-string snapshot content :width width :height height)
            snapshot))))))

;;;----------------------------------------------------------------
;;; Styled Buffer Operations
;;;----------------------------------------------------------------

(defun prefill-buffer-from-styled-content (buffer runs width height)
  "Fill BUFFER (virtual-terminal-buffer) with styled RUNS from parse-ansi-string.
RUNS is a list of (substring . style) pairs where style is a plist or NIL.
WIDTH and HEIGHT specify the buffer dimensions for wrapping."
  (when (and buffer runs)
    (with-virtual-buffer-lock (buffer)
      (clear-buffer buffer)
      (let ((row 0)
            (col 0))
        (dolist (run runs)
          (let* ((text (car run))
                 (style-plist (cdr run))
                 (style (when style-plist
                          (style-to-terminal-style style-plist)))
                 (text-len (length text)))
            (loop for i from 0 below text-len
                  while (< row height)
                  do (let ((char (aref text i)))
                       (cond
                         ((char= char #\Newline)
                          (setf col 0)
                          (incf row))
                         ((char= char #\Return)
                          nil)
                         ((< col width)
                          (set-buffer-cell-at buffer row col char style)
                          (incf col)
                          (when (>= col width)
                            (setf col 0)
                            (incf row))))))))))
    buffer))

(defun make-buffer-from-tmux-styled (width height &key (mode :pane))
  "Create a virtual buffer populated from tmux output with ANSI styles parsed.
Returns NIL if tmux is not available, or the populated buffer otherwise."
  (when (tmux-available-p)
    (let ((content (capture-pane-string :mode mode)))
      (when content
        (let* ((runs (parse-ansi-string content))
               (buffer (make-virtual-buffer width height)))
          (prefill-buffer-from-styled-content buffer runs width height)
          buffer)))))

(defun prefill-backend-from-tmux-styled (backend &key (mode :pane))
  "Prefill terminal backend buffers from current tmux capture with ANSI style parsing.
Returns a virtual buffer snapshot that can be used as the driver's previous frame."
  (when (and (tmux-available-p)
             (typep backend 'terminal-instance))
    (let* ((width (term-w backend))
           (height (term-h backend))
           (content (capture-pane-string :mode mode)))
      (when (and content width height)
        (let* ((runs (parse-ansi-string content))
               (front (terminal-instance-front-buffer backend))
               (back (terminal-instance-back-buffer backend)))
          (when front
            (prefill-buffer-from-styled-content front runs width height))
          (when back
            (prefill-buffer-from-styled-content back runs width height))
          (let ((snapshot (make-virtual-buffer width height)))
            (prefill-buffer-from-styled-content snapshot runs width height)
            snapshot))))))

;;;----------------------------------------------------------------
;;; Capture+Restore Functionality
;;;----------------------------------------------------------------

(defparameter *saved-tmux-capture* nil
  "Stores the initial tmux-captured buffer for restoration on exit.")

(defun has-saved-tmux-capture ()
  "Check if there is a saved tmux capture available for restoration."
  (not (null *saved-tmux-capture*)))

(defun save-tmux-capture (buffer)
  "Save a copy of BUFFER for later restoration."
  (when (typep buffer 'virtual-terminal-buffer)
    (setf *saved-tmux-capture* (copy-virtual-buffer buffer))))

(defun clear-saved-tmux-capture ()
  "Clear the saved tmux capture."
  (setf *saved-tmux-capture* nil))

(defun restore-to-tmux-capture (buffer)
  "Restore BUFFER to the saved tmux capture state."
  (when (and *saved-tmux-capture*
             (typep buffer 'virtual-terminal-buffer))
    (with-virtual-buffer-lock (buffer)
      (let ((saved *saved-tmux-capture*)
            (width (buffer-width buffer))
            (height (buffer-height buffer)))
        (loop for row from 0 below height
              do (loop for col from 0 below width
                       do (let ((cell (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at saved row col)))
                            (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at
                             buffer row col
                             (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell)
                             (elmtui.platform.backend.common.virtual-buffer:buffer-cell-style cell))))))))
  buffer)
