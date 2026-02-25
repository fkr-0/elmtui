;;;===============================================================
;;; File: src/platform/tmux-capture.lisp
;;; Tmux screen capture helpers for buffer prefill
;;;===============================================================

(uiop:define-package :elmtui.platform.tmux
  (:use :cl)
  (:import-from :alexandria #:clamp)
  (:import-from :uiop
    #:run-program
    #:getenv)
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
  (:export
    #:tmux-available-p
    #:capture-pane-string
    #:capture-screen-string
    #:prefill-buffer-from-string
    #:prefill-backend-from-tmux
    #:make-buffer-from-tmux
    #:capture-lines
    #:split-by-ansi-sequences
    #:parse-ansi-sgr
    #:parse-ansi-string))

(in-package :elmtui.platform.tmux)

;;;----------------------------------------------------------------
;;; Environment helpers
;;;----------------------------------------------------------------
(defun %tmux-program ()
  "Locate the tmux binary if available using PATH search."
  (ignore-errors
    ;; Fallback: use 'command -v' to find tmux in PATH
    (let ((output (run-program '("command" "-v" "tmux")
                               :output :string
                               :error nil
                               :ignore-error-status t)))
      (when (and output (plusp (length output)))
        (string-trim '(#\Newline #\Return) output)))))

(defun tmux-available-p ()
  "Return true when tmux is available and current process is running inside tmux."
  (and (%tmux-program)
    (getenv "TMUX_PANE")))

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
  "Capture the current tmux pane (MODE :pane or :screen) and return it as a string."
  (case mode
    (:screen (%run-tmux "capture-pane" "-e" "-J" "-p"))
    (otherwise (%run-tmux "capture-pane" "-p"))))

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
Returns a list of alternating plain text and ANSI sequences."
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
          ;; Start of escape sequence
          ((and (not in-escape) (%esc-p char))
           ;; Flush current segment
           (let ((seg (get-output-stream-string current-segment)))
             (when (plusp (length seg))
               (push seg result)))
           ;; Start new segment for escape sequence
           (setf current-segment (make-string-output-stream))
           (write-char char current-segment)
           (setf in-escape t)
           (incf i))
          ;; Inside escape sequence - look for terminator
          (in-escape
           (write-char char current-segment)
           ;; Check for ANSI terminator (letter a-z or @)
           (when (alpha-char-p char)
             (let ((seg (get-output-stream-string current-segment)))
               (push seg result))
             (setf current-segment (make-string-output-stream))
             (setf in-escape nil))
           (incf i))
          ;; Regular character
          (t
           (write-char char current-segment)
           (incf i)))))
    (nreverse result)))

(defun %sgr-code->color (code kind)
  "Convert SGR color CODE to keyword.
KIND is :fg for foreground (30-37, 90-97) or :bg for background (40-47, 100-107)."
  (let ((base (ecase kind (:fg 30) (:bg 40))))
    (cond
      ;; High intensity colors (90-97, 100-107)
      ((and (>= code 90) (<= code 97))
       (let ((offset (- code (if (eq kind :fg) 90 100))))
         (ecase offset
           (0 :bright-black)
           (1 :bright-red)
           (2 :bright-green)
           (3 :bright-yellow)
           (4 :bright-blue)
           (5 :bright-magenta)
           (6 :bright-cyan)
           (7 :bright-white))))
      ;; Normal colors (30-37, 40-47)
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
    (7 :inverse)
    (22 :normal-intensity)
    (23 :not-italic)
    (24 :not-underline)
    (27 :not-inverse)
    (t nil)))

(defun parse-ansi-sgr (sequence)
  "Parse an ANSI SGR (Select Graphic Rendition) sequence into a style plist.
Returns NIL if the sequence is a reset, or a plist with :fg, :bg, :attrs keys.
SEQUENCE should be a string like \"\\e[31m\" or \"\\e[1;31;42m\"."
  (unless (and sequence (> (length sequence) 2))
    (return-from parse-ansi-sgr nil))
  ;; Verify it's an SGR sequence
  (unless (and (char= (aref sequence 0) #\Escape)
               (char= (aref sequence 1) #\[)
               (alpha-char-p (aref sequence (1- (length sequence)))))
    (return-from parse-ansi-sgr nil))
  ;; Extract the part between [ and final letter
  (let* ((end (1- (length sequence)))
         (params (subseq sequence 2 end)))
    (when (string= params "")
      (return-from parse-ansi-sgr nil))
    ;; Parse semicolon-separated codes
    (let* ((parts (loop for start = 0 then (1+ end)
                        while start
                        for end = (position #\; params :start start)
                        collect (subseq params start end)
                        unless end do (loop-finish)))
           (codes (mapcar #'parse-integer parts))
           (fg nil)
           (bg nil)
           (attrs '()))
      (dolist (code codes)
        (cond
          ;; Reset
          ((= code 0)
           (return-from parse-ansi-sgr nil))
          ;; Foreground colors
          ((or (and (>= code 30) (<= code 37))
               (and (>= code 90) (<= code 97)))
           (setf fg (%sgr-code->color code :fg)))
          ;; Background colors
          ((or (and (>= code 40) (<= code 47))
               (and (>= code 100) (<= code 107)))
           (setf bg (%sgr-code->color code :bg)))
          ;; Attributes
          (t
           (let ((attr (%sgr-code->attr code)))
             (when attr
               (push attr attrs))))))
      ;; Build result plist
      (let ((result '()))
        (when fg (setf (getf result :fg) fg))
        (when bg (setf (getf result :bg) bg))
        (when attrs (setf (getf result :attrs) (nreverse attrs)))
        (when (or fg bg attrs)
          result)))))

(defun parse-ansi-string (content)
  "Parse CONTENT into a list of (substring . style) pairs.
ANSI escape sequences are extracted and converted to style plists.
Returns list like ((\"text\" . NIL) (\"red\" . (:FG :RED)) ...)."
  (unless content
    (return-from parse-ansi-string '()))
  (let ((segments (split-by-ansi-sequences content))
        (result '())
        (current-style nil))
    (dolist (seg segments)
      (if (and (> (length seg) 0) (%esc-p (aref seg 0)))
          ;; This is an ANSI sequence - parse it
          (let ((parsed (parse-ansi-sgr seg)))
            (if (null parsed)
                ;; Reset sequence
                (setf current-style nil)
                ;; Update current style
                (setf current-style
                      (append parsed current-style))))
          ;; This is plain text
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
      (loop for row from 0 below height do
        (setf (aref result row)
          (if (< row (length vector-lines))
            (aref vector-lines row)
            "")))
      result)))

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
