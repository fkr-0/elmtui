;;;===============================================================
;;; File: src/platform/tmux-capture.lisp
;;; Tmux screen capture helpers for buffer prefill
;;;===============================================================

(uiop:define-package :elmtui.platform.tmux
  (:use :cl)
  (:import-from :alexandria #:clamp)
  (:import-from :uiop
    #:find-program*
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
    (or (find-program* "tmux")
        ;; Fallback: try using 'command -v' or 'which'
        (let ((output (run-program '("command" "-v" "tmux")
                                   :output :string
                                   :error nil
                                   :ignore-error-status t)))
          (when (and output (plusp (length output)))
            (string-trim '(#\Newline #\Return) output))))))

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
