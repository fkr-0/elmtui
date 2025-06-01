;;;===============================================================
;;; File: src/platform/backend/terminal/terminal.lisp
;;; Standard Terminal Backend
;;;
;;; This file contains the terminal instance management and core
;;; terminal operations. Added canvas integration for controlled positioning.
;;;===============================================================

(uiop:define-package :elmtui.platform.backend.terminal
  (:use :cl :elmtui.platform.api :elmtui.backend.common.utils :log4cl)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer #:make-virtual-buffer #:clear-buffer #:resize-buffer
                #:buffer-width #:buffer-height #:with-virtual-buffer-lock
                #:set-buffer-cell-at #:fill-buffer-region #:buffer-cell-at)
  ;; (:import-from :elmtui.platform.backend.terminal.diff-renderer ; For render-and-present
  ;;               #:compute-buffer-diff #:apply-terminal-diff)
  ;; (:import-from :elmtui.platform.output ; For render-frame
  ;;               #:render-frame)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from #:sb-posix #:o-rdwr
                #:tcgetattr #:tcsetattr #:termios #:termios-lflag #:termios-cc
                #:icanon #:echo #:vmin #:vtime #:tcsanow #:tcsaflush)
  (:import-from #:sb-unix
                #:unix-open #:unix-close #:unix-read #:unix-write
                #:sigwinch #:sigint) ; For signal handling
  (:import-from #:sb-sys
                #:fd-stream-fd #:make-fd-stream #:enable-interrupt) ; For signal handling
  (:import-from #:elmtui.core.event-types
                #:key-event-key #:key-event-char #:key-event-modifiers
                #:mouse-event-x #:mouse-event-y
                #:mouse-event-type #:mouse-event-button #:mouse-event-modifiers
                #:make-mouse-event
                #:make-raw-input-event
                #:make-key-event)
  (:import-from #:elmtui.platform.api #:term-w #:term-h #:term-style #:term-stream)
  (:import-from :elmtui.view.styled #:styled-ui-node #:styles)
  (:import-from :elmtui.view.core #:ui-node-props #:ui-node-type #:ui-node-children)
  (:import-from :elmtui.view.geo #:x #:y #:w #:h #:rectangle-pos)
  (:import-from :elmtui.style-lib.api #:style-set) ; Added for typep check
  (:import-from :elmtui.style-lib.style-set #:styles-list) ; Added for conversion
  (:import-from #:elmtui.backend.common.ansi-styling
                #:make-terminal-style #:make-termcolor #:exec-sequence
                #:update-style! #:copy-term-style
                #:terminal-style-fg-color #:terminal-style-bg-color
                #:terminal-style-bold #:terminal-style-italic
                #:terminal-style-underline #:terminal-style-inverse
                #:ansi-seqs #:stringify-sgr)
  (:import-from #:elmtui.backend.common.utils
                #:get-sequence #:render-seq
                #:ansi-fg-color-seq #:ansi-bg-color-seq
                #:ansi-attr-seq)
  (:import-from #:elmtui.platform.canvas
                #:canvas
                #:make-terminal-canvas
                #:initialize-terminal-canvas
                #:get-canvas-viewport
                #:apply-canvas-to-buffer
                #:restore-terminal-state
                #:canvas-buffer) ; For render-and-present
  (:export #:terminal-instance
           #:initialize-backend
           #:shutdown-backend
           #:render-ui-tree-to-buffer
           #:write-output
           #:get-screen-dimensions
           #:send-sequence
           #:clear-screen
           #:backend-name
           #:backend-version
           ;; #:resize-terminal-buffers ; No longer primary interface, use handle-backend-resize
           ;; #:force-clear-terminal-and-reset-buffers ; Internalized
           #:terminal-instance-front-buffer
           #:terminal-instance-back-buffer
           #:with-terminal-lock
           #:write-style-to-stream
           #:write-style-reset-to-stream
           #:style-to-terminal-style
           #:terminal-instance-canvas
           #:make-terminal-canvas
           #:initialize-terminal-canvas
           #:get-canvas-viewport
           ;; #:apply-canvas-to-buffer ; Used internally by render-and-present
           #:restore-terminal-state
           ;; New generic method implementations are implicitly exported by their generic definitions
           ))

(in-package :elmtui.platform.backend.terminal)

(defstruct terminal-instance
  (fd -1 )
  (stream nil :type (or null stream))
  (original-termios nil :type (or null termios))
  (current-termios nil :type (or null termios))
  (width 80 :type integer)
  (height 24 :type integer)
  (cursor-visible-p t :type boolean)
  (cursor-row 0 :type integer)
  (cursor-col 0 :type integer)
  (current-style '(:fg :white :bg :black :attrs nil))
  (input-buffer (make-array 0 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0))
  (lock (make-instance 'lockable) :type lockable)
  (front-buffer nil :type (or null virtual-terminal-buffer))
  (back-buffer nil :type (or null virtual-terminal-buffer))
  (canvas nil :type (or null canvas))
  (publish-fn nil :type (or null function))) ; For signal handlers

(defmethod term-w ((instance terminal-instance)) (terminal-instance-width instance))
(defmethod term-h ((instance terminal-instance)) (terminal-instance-height instance))
(defmethod (setf term-w) (new-width (instance terminal-instance)) (setf (terminal-instance-width instance) new-width))
(defmethod (setf term-h) (new-height (instance terminal-instance)) (setf (terminal-instance-height instance) new-height))
(defmethod term-style ((instance terminal-instance)) (terminal-instance-current-style instance))
(defmethod (setf term-style) (new-style (instance terminal-instance)) (setf (terminal-instance-current-style instance) new-style))
(defmethod term-stream ((instance terminal-instance)) (terminal-instance-stream instance))

(defmacro with-terminal-lock ((instance) &body body)
  `(bt:with-recursive-lock-held ((lock-of (terminal-instance-lock ,instance)))
     ,@body))

;;;---------------------------------------------------------------
;;; Internal Terminal Reset Helper
;;;---------------------------------------------------------------
(defun %force-clear-terminal-and-reset-buffers (instance)
  "Internal helper: Forces a hard clear of the terminal screen and resets internal buffers."
  (check-type instance terminal-instance)
  (log:info "TERMINAL (internal): Forcing clear of terminal and resetting buffers.")
  (with-terminal-lock (instance)
    (send-sequence instance :erase-in-display 2)
    (send-sequence instance :cursor-set-position 1 1)
    (send-sequence instance :reset)
    (let ((front-buffer (terminal-instance-front-buffer instance)))
      (when front-buffer
        (with-virtual-buffer-lock (front-buffer)
          (clear-buffer front-buffer :default-char #\Nul :default-style nil))))
    (let ((back-buffer (terminal-instance-back-buffer instance)))
      (when back-buffer
        (with-virtual-buffer-lock (back-buffer)
          (clear-buffer back-buffer))))
    (setf (terminal-instance-current-style instance) '(:fg :white :bg :black :attrs nil))
    (finish-output (terminal-instance-stream instance)))
  t)

;;;---------------------------------------------------------------
;;; Signal Handling Setup (SBCL/Unix specific)
;;;---------------------------------------------------------------
(defun setup-terminal-signal-handlers (instance publish-fn)
  (when publish-fn
    ;; SIGWINCH - Terminal Resize
    (sb-sys:enable-interrupt sb-unix:sigwinch
                             (lambda (signal code scp)
                               (declare (ignore signal code scp))
                               (multiple-value-bind (w h)
                                   (get-screen-dimensions instance) ; Use backend's method
                                 (log:info "TERMINAL: SIGWINCH detected. Publishing :backend-resize-request W:~A H:~A" w h)
                                 (funcall publish-fn (list :backend-resize-request :width w :height h)))))
    ;; SIGINT - Interrupt (Ctrl+C)
    (sb-sys:enable-interrupt sb-unix:sigint
                             (lambda (signal code scp)
                               (declare (ignore signal code scp))
                               (log:info "TERMINAL: SIGINT detected. Publishing :app-quit-requested")
                               (funcall publish-fn '(:app-quit-requested (:source :sigint)))))))

;;;---------------------------------------------------------------
;;; Terminal Raw Mode Control
;;;---------------------------------------------------------------
(defun disable-raw-mode (fd original-termios)
  (when original-termios
    (handler-case (tcsetattr fd tcsaflush original-termios)
      (error (e) (log:warn "TERMINAL: Failed to disable raw mode: ~A" e)))))

(defmethod enable-raw-mode ((fd integer))
  (let ((orig (the sb-posix:termios (sb-posix:tcgetattr fd))))
    (let ((new (the sb-posix:termios (sb-int:sys-copy-struct orig))))
      (setf (sb-posix:termios-lflag new)
            (logand (sb-posix:termios-lflag new)
                    (lognot sb-posix:icanon)
                    (lognot sb-posix:echo)))
      (setf (aref (sb-posix:termios-cc new) sb-posix:vmin)  0
            (aref (sb-posix:termios-cc new) sb-posix:vtime) 1)
      (sb-posix:tcsetattr fd sb-posix:tcsaflush new)
      orig)))

;;;---------------------------------------------------------------
;;; Backend Lifecycle
;;;---------------------------------------------------------------
(defmethod initialize-backend ((backend-type (eql :terminal)) &key publish-fn (tty-path "/dev/tty") &allow-other-keys)
  (let ((fd (sb-unix:unix-open tty-path sb-posix:o-rdwr 0)))
    ;; (unless (and fd (>= fd 0))
    ;;   (error "Could not open terminal TTY: ~A" tty-path))
    (let* ((orig-termios  (enable-raw-mode fd))
           (stream        (open "/dev/tty"
                                :direction :io
                                :if-exists :append
                                :if-does-not-exist :create
                                :element-type '(unsigned-byte 8)))
           (curr-termios  (sb-posix:tcgetattr fd))
           (instance      (make-terminal-instance
                           :fd fd :stream stream
                           :original-termios orig-termios
                           :current-termios curr-termios
                           :publish-fn publish-fn)))
      (log-info "TERMINAL: Initialized backend instance with fd ~A, stream ~S" fd stream)
      (multiple-value-bind (w h) (get-screen-dimensions instance)
        (setf (terminal-instance-width instance) w
              (terminal-instance-height instance) h)
        (let ((front (make-virtual-buffer w h))
              (back (make-virtual-buffer w h)))
          (setf (terminal-instance-front-buffer instance) front
                (terminal-instance-back-buffer instance) back)))

      (setup-terminal-signal-handlers instance publish-fn)
      (send-sequence instance :cursor-hide)
      (%force-clear-terminal-and-reset-buffers instance) ; Initial clear and buffer reset
      (flush-output instance)
      instance)))

(defmethod shutdown-backend ((instance terminal-instance))
  (log-info "TERMINAL: Shutting down backend...")
  (handler-case
      (with-terminal-lock (instance)
        (send-sequence instance :cursor-show)
        (send-sequence instance :reset) ; SGR 0
        ;; Restore normal screen buffer if alt screen was used
        ;; (send-sequence instance :normal-screen-buffer)
        (write-output  (format nil "~c[?25h~c[0m~c[J~c[H" #\Escape #\Escape #\Escape #\Escape) (term-stream instance)) ; Show cursor, reset, clear, home
        (flush-output instance)
        (disable-raw-mode (terminal-instance-fd instance)
                          (terminal-instance-original-termios instance))
        (when (terminal-instance-stream instance)
          (close (terminal-instance-stream instance))
          (setf (terminal-instance-stream instance) nil))
        (when (>= (terminal-instance-fd instance) 0)
          (unix-close (terminal-instance-fd instance))
          (setf (terminal-instance-fd instance) -1))
        (setf (terminal-instance-front-buffer instance) nil
              (terminal-instance-back-buffer instance) nil))
    (error (e) (log:error "TERMINAL: Error during primary shutdown: ~A" e)))

  (handler-case (sb-ext:run-program "/bin/stty" '("sane") :search t :input nil :output nil :error :output)
    (error (e) (log:error "TERMINAL: stty sane failed: ~A" e)))
  (log-info "TERMINAL: Backend shutdown complete.")
  t)

(defmethod backend-name ((instance terminal-instance)) "Standard Terminal Backend")
(defmethod backend-version ((instance terminal-instance)) "0.1.0")

;;;---------------------------------------------------------------
;;; Resize Handling
;;;---------------------------------------------------------------
(defun resize-terminal-buffers (instance new-width new-height)
  "Internal: Resizes the front and back buffers of the terminal instance."
  (check-type instance terminal-instance)
  (check-type new-width (integer 0 *))
  (check-type new-height (integer 0 *))
  (log:info "TERMINAL: Resizing internal buffers to ~Ax~A" new-width new-height)
  (setf (terminal-instance-width instance) new-width
        (terminal-instance-height instance) new-height)
  (when (terminal-instance-front-buffer instance)
    (setf (terminal-instance-front-buffer instance)
          (resize-buffer (terminal-instance-front-buffer instance) new-width new-height)))
  (when (terminal-instance-back-buffer instance)
    (setf (terminal-instance-back-buffer instance)
          (resize-buffer (terminal-instance-back-buffer instance) new-width new-height)))
  t)

(defmethod handle-backend-resize ((instance terminal-instance) width height)
  (log:info "TERMINAL: Handling backend resize to ~Ax~A" width height)
  (resize-terminal-buffers instance width height)
  (%force-clear-terminal-and-reset-buffers instance)
  t)

;;;---------------------------------------------------------------
;;; Rendering
;;;---------------------------------------------------------------


;;;---------------------------------------------------------------
;;; Display & Screen Management (existing methods)
;;;---------------------------------------------------------------
(defmethod send-sequence ((instance terminal-instance) seq-id &rest args)
  (let ((seq-obj (get-sequence seq-id)))
    (when seq-obj
      (let ((rendered (apply #'render-seq seq-obj args)))
        (write-output rendered (terminal-instance-stream instance))))))

(defmethod get-screen-dimensions ((instance terminal-instance))
  (let ((response-str nil)
        (default-w (term-w instance))
        (default-h (term-h instance)))
    (with-terminal-lock (instance)
      (send-sequence instance :cursor-save)
      (send-sequence instance :cursor-set-position 999 999) ; Standard way to request dimensions
      (send-sequence instance :cursor-report)
      (finish-output (terminal-instance-stream instance))

      (let ((response-chars '())
            (stream (terminal-instance-stream instance))
            (deadline (+ (get-internal-real-time) (* 0.5 internal-time-units-per-second)))) ; 0.5s total timeout
        (loop
          (when (> (get-internal-real-time) deadline)
            (log:warn "Timeout waiting for cursor report. Read so far: ~S" (coerce (nreverse (copy-list response-chars)) 'string))
            (return)) ; Exit loop, response-str will be nil or partial

          (let ((char (read-byte stream nil :eof)))
            (cond
              ((eq char :eof)
               (log:warn "EOF encountered while reading cursor report. Read so far: ~S" (coerce (nreverse (copy-list response-chars)) 'string))
               (return)) ; Exit loop
              ;; ((null char) ; No character available right now
              ;;  (sleep 0.01))
                                        ; Wait a bit (10ms) and retry
              (t ; Character read
               (push char response-chars)
               (when (= char (char-code #\R))
                 (setq response-str (coerce (mapcar #'code-char (nreverse response-chars)) 'string))
                 (log:debug "Cursor report full response read: ~S" response-str)
                 (return)))))))) ; Exit loop, proceed to parse

    ;; Always restore cursor, regardless of whether we got a response
    (with-terminal-lock (instance)
      (send-sequence instance :cursor-restore)
      (finish-output (terminal-instance-stream instance)))

    (when response-str
      (handler-case
          (let* ((esc-pos (position #\Esc response-str))
                 (bracket-pos (position #\[ response-str :start (if esc-pos (1+ esc-pos) 0)))
                 (r-pos (position #\R response-str :from-end t)))
            (if (and esc-pos bracket-pos r-pos (< bracket-pos r-pos) (> r-pos (1+ bracket-pos))) ; Ensure content between [ and R
                (let* ((content (subseq response-str (1+ bracket-pos) r-pos))
                       (parts (uiop:split-string content :separator '(#\;))))
                  (if (and (= (length parts) 2)
                           (every #'digit-char-p (first parts))
                           (plusp (length (first parts))) ; Ensure not empty string
                           (every #'digit-char-p (second parts))
                           (plusp (length (second parts)))) ; Ensure not empty string
                      (let ((parsed-h (parse-integer (first parts)))
                            (parsed-w (parse-integer (second parts))))
                        (log:info "Parsed dimensions: W=~A, H=~A from ~S" parsed-w parsed-h response-str)
                        (return-from get-screen-dimensions (values parsed-w parsed-h)))
                      (log:warn "Could not parse dimensions from report parts: ~S (original: ~S)" parts response-str)))
                (log:warn "Malformed cursor report: ~S. ESC:~S, [:~S, R:~S" response-str esc-pos bracket-pos r-pos)))
        (error (e)
          (log:error "Error parsing cursor report string ~S: ~A" response-str e))))

    ;; Fallback if parsing failed or no response
    (log:warn "Failed to get screen dimensions from terminal, using defaults: W=~A, H=~A" default-w default-h)
    (values default-w default-h))) ; Exit loop, proceed to parse

(defmethod clear-screen ((instance terminal-instance))
  (log:debug "TERMINAL clear-screen: Clearing back-buffer.")
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (clear-buffer back-buffer))))
  t)

(defmethod flush-output ((instance terminal-instance))
  (with-terminal-lock (instance)
    (finish-output (terminal-instance-stream instance)))
  t)

(defmethod set-cursor-visibility ((instance terminal-instance) visible-p)
  (with-terminal-lock (instance)
    (setf (terminal-instance-cursor-visible-p instance) visible-p)
    (if visible-p
        (send-sequence instance :cursor-show)
        (send-sequence instance :cursor-hide)))
  t)

(defmethod set-cursor-position ((instance terminal-instance) row col)
  (with-terminal-lock (instance)
    (setf (terminal-instance-cursor-row instance) row)
    (setf (terminal-instance-cursor-col instance) col)
    (send-sequence instance :cursor-set-position (1+ row) (1+ col)))
  t)

(defmethod get-cursor-position ((instance terminal-instance))
  (values (terminal-instance-cursor-row instance) (terminal-instance-cursor-col instance)))

(defmethod hide-cursor ((instance terminal-instance)) (set-cursor-visibility instance nil))
(defmethod show-cursor ((instance terminal-instance)) (set-cursor-visibility instance t))

;;;---------------------------------------------------------------
;;; Drawing Primitives (draw to back-buffer)
;;;---------------------------------------------------------------
(defmethod draw-text-at ((instance terminal-instance) row col text &key style)
  (log:debug "BUFFER: draw-text-at - Row: ~A, Col: ~A, Text: \"~A\", Style: ~S" row col text style)
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (let ((buffer-w (buffer-width back-buffer))
              (buffer-h (buffer-height back-buffer)))
          (loop for i from 0 below (length text)
                for char = (aref text i)
                for current-col = (+ col i)
                when (and (>= row 0) (< row buffer-h)
                          (>= current-col 0) (< current-col buffer-w))
                  do (set-buffer-cell-at back-buffer row current-col char style)
                else do (log:warn "draw-text-at: Clipping char '~C' at (~A,~A)" char row current-col) (loop-finish))))))
  t)

(defmethod draw-char-at ((instance terminal-instance) row col char &key style)
  (log:debug "BUFFER: draw-char-at - Row: ~A, Col: ~A, Char: ~C, Style: ~S" row col char style)
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (let ((buffer-w (buffer-width back-buffer))
              (buffer-h (buffer-height back-buffer)))
          (if (and (>= row 0) (< row buffer-h) (>= col 0) (< col buffer-w))
              (set-buffer-cell-at back-buffer row col char style)
              (log:warn "draw-char-at: Clipping char '~C' at (~A,~A)" char row col))))))
  t)

(defmethod fill-rectangle ((instance terminal-instance) row col height width &key char style)
  (log:debug "BUFFER: fill-rectangle - Row: ~A, Col: ~A, H: ~A, W: ~A, Char: ~C, Style: ~S" row col height width char style)
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (fill-buffer-region back-buffer row col width height (or char #\Space) style))))
  t)

(defmethod draw-box-outline ((instance terminal-instance) row col height width &key style corners sides)
  (declare (ignore corners sides)) ; Simple ASCII box for now
  (log:debug "BUFFER: draw-box-outline - Row: ~A, Col: ~A, H: ~A, W: ~A, Style: ~S" row col height width style)
  (when (and (> width 1) (> height 1))
    (let ((back-buffer (terminal-instance-back-buffer instance)))
      (when back-buffer
        (with-virtual-buffer-lock (back-buffer)
          (draw-char-at instance row col #\+ :style style)
          (draw-char-at instance row (+ col width -1) #\+ :style style)
          (draw-char-at instance (+ row height -1) col #\+ :style style)
          (draw-char-at instance (+ row height -1) (+ col width -1) #\+ :style style)
          (loop for c from (1+ col) below (+ col width -1)
                do (draw-char-at instance row c #\- :style style)
                   (draw-char-at instance (+ row height -1) c #\- :style style))
          (loop for r from (1+ row) below (+ row height -1)
                do (draw-char-at instance r col #\| :style style)
                   (draw-char-at instance r (+ col width -1) #\| :style style))))))
  t)

(defmethod draw-styled-box ((instance terminal-instance) row col height width &key border-style border-color box-char-set style)
  (declare (ignore box-char-set))
  (log:debug "BUFFER: draw-styled-box - Pos: (~A,~A), Size: (~A,~A), Style: ~S, BorderStyle: ~S, BorderColor: ~S"
             row col height width style border-style border-color)
  (when (and (> width 1) (> height 1))
    (let* ((effective-style (if border-color (list :fg border-color) (getf style :attrs)))
           (chars (case border-style
                    (:single '(#\┌ #\┐ #\└ #\┘ #\─ #\│))
                    (:double '(#\╔ #\╗ #\╚ #\╝ #\═ #\║))
                    (otherwise '(#\+ #\+ #\+ #\+ #\- #\|))))
           (tl (first chars)) (tr (second chars)) (bl (third chars)) (br (fourth chars))
           (horiz (fifth chars)) (vert (sixth chars))
           (back-buffer (terminal-instance-back-buffer instance)))
      (when back-buffer
        (with-virtual-buffer-lock (back-buffer)
          (draw-char-at instance row col tl :style effective-style)
          (draw-char-at instance row (+ col width -1) tr :style effective-style)
          (draw-char-at instance (+ row height -1) col bl :style effective-style)
          (draw-char-at instance (+ row height -1) (+ col width -1) br :style effective-style)
          (loop for c from (1+ col) below (+ col width -1)
                do (draw-char-at instance row c horiz :style effective-style)
                   (draw-char-at instance (+ row height -1) c horiz :style effective-style))
          (loop for r from (1+ row) below (+ row height -1)
                do (draw-char-at instance r col vert :style effective-style)
                   (draw-char-at instance r (+ col width -1) vert :style effective-style))))))
  t)

(defmethod set-cell-style ((instance terminal-instance) row col &key style)
  (log:debug "BUFFER: set-cell-style - Row: ~A, Col: ~A, Style: ~S" row col style)
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (let ((buffer-w (buffer-width back-buffer)) (buffer-h (buffer-height back-buffer)))
          (if (and (>= row 0) (< row buffer-h) (>= col 0) (< col buffer-w))
              (let ((current-cell (buffer-cell-at back-buffer row col)))
                (set-buffer-cell-at back-buffer row col (elmtui.platform.backend.common.virtual-buffer::buffer-cell-char current-cell) style))
              (log:warn "set-cell-style: Clipping style at (~A,~A)" row col))))))
  t)

(defmethod clear-area ((instance terminal-instance) row col height width &key style)
  (log:debug "BUFFER: clear-area - Row: ~A, Col: ~A, H: ~A, W: ~A, Style: ~S" row col height width style)
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (fill-buffer-region back-buffer row col width height #\Space style))))
  t)

;;;---------------------------------------------------------------
;;; Color and Style Management (existing methods)
;;;---------------------------------------------------------------
(defun style-to-terminal-style (style-plist)
  (when style-plist
    (let ((ts (make-terminal-style)))
      (let ((bg (getf style-plist :bg)))
        (when bg (if (listp bg) (setf (terminal-style-bg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :bg t :r (first bg) :g (second bg) :b (third bg)))
                     (if (numberp bg) (setf (terminal-style-bg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :bg t :color-256 bg))
                         (setf (terminal-style-bg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :bg t :simple bg))))))
      (let ((fg (getf style-plist :fg)))
        (when fg (if (listp fg) (setf (terminal-style-fg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :r (first fg) :g (second fg) :b (third fg)))
                     (if (numberp fg) (setf (terminal-style-fg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :color-256 fg))
                         (setf (terminal-style-fg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :simple fg))))))
      (let ((attrs (getf style-plist :attrs)))
        (when (member :bold attrs) (setf (terminal-style-bold ts) t))
        (when (member :italic attrs) (setf (terminal-style-italic ts) t))
        (when (member :underline attrs) (setf (terminal-style-underline ts) t))
        (when (member :inverse attrs) (setf (terminal-style-inverse ts) t)))
      ts)))

(defun write-style-to-stream (stream style)
  (when style
    (let ((ts (style-to-terminal-style style)))
      (when ts
        (let ((seqs (elmtui.backend.common.ansi-styling:ansi-seqs ts :fg-color :bg-color :bold :italic :underline)))
          (dolist (seq seqs) (write-output (concatenate 'string (string #\Esc) seq) stream)))))))
(defmacro as-utf-8-bytes (char writer)
  "Given the character CHAR, call the WRITER for every byte in the
  UTF-8 encoded form of that character. WRITER may a function or a
  macro."
  (let ((char-code (gensym)))
    `(let ((,char-code (char-code ,char)))
       (declare (type fixnum ,char-code))
       (cond ((< ,char-code 128) (,writer ,char-code))
             ((< ,char-code 2048)
              (,writer (logior #b11000000 (ldb (byte 5 6) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 0) ,char-code))))
             ((< ,char-code 65536)
              (,writer (logior #b11100000 (ldb (byte 4 12) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 6) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 0) ,char-code))))
             (t
              (,writer (logior #b11110000 (ldb (byte 3 18) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 12) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 6) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 0) ,char-code))))))))

(defun write-output (output stream )
  "Write output to the terminal
This method should be implemented by subclasses of low-level-terminal."
  ;; (declare (ignore style))
  ;; ;; (with-lock (term)
  ;; (exec-sequence term :cursor-set-position y x)
  (dotimes (i (length output))
    (as-utf-8-bytes (char output i) (lambda (x) (write-byte x stream)))))

(defun write-style-reset-to-stream (stream)
  (write-output (concatenate 'string (string #\Esc) "[0m") stream))

(defmethod apply-style-diff ((instance terminal-instance) new-style)
  (log:info "APPLY-STYLE-DIFF CALLED. Current: ~S, New: ~S" (term-style instance) new-style)
  (let ((current-style (term-style instance)) (stream (term-stream instance)))
    (when (equal current-style new-style) (return-from apply-style-diff t))
    (log:debug "APPLY-STYLE-DIFF: Transitioning. Current: ~S, New: ~S" current-style new-style)
    (let* ((new-style-ts (if new-style (style-to-terminal-style new-style) (make-terminal-style)))
           (styles-to-upgrade (update-style! current-style new-style-ts)))
      (setf current-style (copy-term-style current-style)) ; This was problematic, should be (term-style instance)
      (dolist (s (ansi-seqs styles-to-upgrade))
        (log:debug "APPLY-STYLE-DIFF: Writing ANSI sequence: ~S" s)
        (exec-sequence (terminal-instance-lock instance) (terminal-instance-fd instance) s))
      (setf (term-style instance) current-style)) ; Update instance's current style
    (finish-output stream) t))

(defmethod make-color ((instance terminal-instance) r-or-name &optional g b)
  (if g (list :rgb r-or-name g b) r-or-name))

(defmethod make-style ((instance terminal-instance) &key foreground-color background-color attributes)
  (list :fg (or foreground-color (default-foreground-color instance))
        :bg (or background-color (default-background-color instance))
        :attrs (copy-list attributes)))

(defmethod apply-style ((instance terminal-instance) style-plist)
  (with-terminal-lock (instance)
    (apply-style-diff instance style-plist)) ; apply-style-diff is the one that writes to stream
  t)

(defmethod default-foreground-color ((instance terminal-instance)) :white)
(defmethod default-background-color ((instance terminal-instance)) :black)
(defmethod supports-truecolor-p ((instance terminal-instance)) t)
(defmethod max-colors ((instance terminal-instance)) (expt 2 24))

;;;---------------------------------------------------------------
;;; Input Handling (existing methods)
;;;---------------------------------------------------------------
(defun read-char-nonblock (stream) (read-byte stream nil nil))


(defun parse-sgr-mouse-event (params raw-bytes final-char-code)
  (let* ((button-code (first params)) (col (second params)) (row (third params))
         (button (logand button-code 3))
         (modifiers (let ((mod-code (ash button-code -2)))
                      (append (when (logbitp 0 mod-code) '(:shift))
                              (when (logbitp 1 mod-code) '(:alt))
                              (when (logbitp 2 mod-code) '(:control)))))
         (type (cond ((= 35 (logand button-code 35)) :mouse-move)
                     ((= final-char-code (char-code #\M)) :mouse-down)
                     ((= final-char-code (char-code #\m)) :mouse-up)
                     ((>= button-code 64) (if (= (logand button-code 1) 0) :scroll-up :scroll-down))
                     (t :unknown-mouse)))
         (final-button (cond ((eq type :scroll-up) :scroll-up) ((eq type :scroll-down) :scroll-down)
                             ((= button 0) :left) ((= button 1) :middle) ((= button 2) :right)
                             ((= button 3) :dunno))))
    (make-mouse-event :type type :button final-button :y (1- row) :x (1- col) :modifiers modifiers :raw raw-bytes)))

(defun parse-input-bytes-to-message (bytes-vector)
  (when (zerop (length bytes-vector)) (return-from parse-input-bytes-to-message nil))
  (let ((first-byte (aref bytes-vector 0)) (raw (copy-seq bytes-vector)))
    (block parser
      (handler-case
          (cond
            ((= first-byte #o33) ; ESC
             (if (> (length bytes-vector) 1)
                 (let ((introducer-char-code (aref bytes-vector 1)))
                   (cond
                     ((= introducer-char-code #o133) ; '[' CSI
                      (if (> (length bytes-vector) 2)
                          (let ((csi-content-list (coerce (subseq bytes-vector 2) 'list)))
                            (when (and (> (length csi-content-list) 0) (= (car (last csi-content-list)) 82)) ; 'R'
                              (log:debug "Ignoring cursor position response: ~S" bytes-vector) (return-from parser nil))
                            (multiple-value-bind (params intermediates final-byte-code) (collect-csi-params csi-content-list)
                              (cond
                                ((and (member #\< intermediates) (or (= final-byte-code (char-code #\M)) (= final-byte-code (char-code #\m))))
                                 (parse-sgr-mouse-event params raw final-byte-code))
                                (t (multiple-value-bind (key-sym rem) (read-escape-bytes (make-string-input-stream (map 'string #'code-char csi-content-list)) :CSI)
                                     (declare (ignore rem))
                                     (if key-sym (make-key-event :key key-sym :modifiers '(:alt) :char nil) (make-raw-input-event :bytes raw)))))))
                          (make-key-event :key :escape :modifiers nil :char nil))) ; Just ESC [
                     ((= introducer-char-code #o117) ; 'O' SS3
                      (if (> (length bytes-vector) 2)
                          (multiple-value-bind (key-sym rem) (read-escape-bytes (make-string-input-stream (map 'string #'code-char (subseq bytes-vector 2))) :SS3)
                            (declare (ignore rem))
                            (if key-sym (make-key-event :key key-sym :modifiers '(:alt) :char nil) (make-raw-input-event :bytes raw)))
                          (make-key-event :key :escape :modifiers nil :char nil))) ; Just ESC O
                     (t (let ((char (code-char introducer-char-code))) (make-key-event :key (intern (string-upcase (string char)) :keyword) :char char :modifiers '(:alt))))))
                 (make-key-event :key :escape :modifiers nil :char nil)))
            ((= first-byte #o177) (make-key-event :key :backspace :modifiers nil :char nil)) ; DEL
            ((= first-byte #o10) (make-key-event :key :backspace :code #o10 :type :key-down :char (code-char first-byte) :modifiers nil)) ; BS
            ((= first-byte #o15) (make-key-event :key :enter :code #o15 :type :key-down :modifiers nil :char (code-char first-byte))) ; CR
            ((= first-byte #o11) (make-key-event :key :tab :code #o11 :type :key-down :modifiers nil :char (code-char first-byte))) ; HT
            ((<= first-byte #o37) (let* ((base-char-code (+ first-byte 64)) (base-char (code-char base-char-code)))
                                    (make-key-event :key (intern (format nil "C-~A" base-char) :keyword) :code first-byte :char base-char :type :key-down :modifiers '(:control))))
            (t (let ((char (code-char first-byte))) (make-key-event :key (intern (string char) :keyword) :code first-byte :type :key-down :modifiers nil))))
        (error (e) (warn "Error parsing input bytes ~A: ~A." bytes-vector e) (make-raw-input-event :bytes raw))))))

(defmethod poll-input-event ((instance terminal-instance) &key timeout)
  ;; timeout: nil (block), 0 (non-block), >0 (timeout in seconds)
  (let ((stream (terminal-instance-stream instance))
        (buffer (terminal-instance-input-buffer instance)))
    ;; (deadline (if (and timeout (> timeout 0)) ; Commented out as it's unused
    ;;               (+ (get-internal-real-time) (* timeout internal-time-units-per-second))
    ;;               nil)))
    (with-terminal-lock (instance) (setf (fill-pointer buffer) 0))

    ;; 1. Read the first character
    (let ((first-char
            (cond
              ((null timeout) ; Block indefinitely
               (read-byte stream nil :eof))
              ((= timeout 0) ; Non-blocking
               (read-byte stream nil :eof))
              (t ; Timed read - relies on VTIME set by enable-raw-mode
               ;; read-char will wait up to VTIME (0.1s)
               ;; We also have an overall 'deadline' for the whole poll-input-event
               (read-byte stream nil :eof)))))

      (cond
        ((or (eq first-char :eof) (null first-char)) ; EOF or no char (for non-blocking/timed)
         (return-from poll-input-event nil))
        (t
         (with-terminal-lock (instance) (vector-push-extend   first-char buffer)))))

    ;; 2. If the first char was ESC, try to read the rest of the sequence non-blockingly
    (when (and (> (length buffer) 0) (= (aref buffer 0) #o33)) ; ESC
      ;; (format t "TERMINAL: ESC sequence detected, reading further characters non-blocking.")
      (loop with escape-deadline = (+ (get-internal-real-time) (* 0.05 internal-time-units-per-second)) ; Short (50ms) deadline for escape sequence
            for i from 1 to 7 ; Max typical escape sequence length
            do
               (when (> (get-internal-real-time) escape-deadline) (loop-finish))
               (let ((next-char (read-byte stream nil :eof)))
                 (if next-char
                     (with-terminal-lock (instance) (vector-push-extend  next-char buffer))
                     nil
                     ;; (loop-finish)
                     )))) ; No more chars for ESC sequence

    ;; 3. Parse whatever is in the buffer
    (if (plusp (fill-pointer buffer))
        (parse-input-bytes-to-message buffer)
        nil))) ; Should not happen if first-char was read

;; (defmethod poll-input-event ((instance terminal-instance) &key timeout)
;;   (let ((stream (terminal-instance-stream instance)) (buffer (terminal-instance-input-buffer instance)) (start-time (get-internal-real-time)))
;;     (with-terminal-lock (instance) (setf (fill-pointer buffer) 0))
;;     (loop
;;       (let ((char (if (zerop (fill-pointer buffer))
;;                       (if timeout (read-char stream nil :eof (if (= timeout 0) :nonblock-peek)) (read-char stream nil :eof))
;;                       (read-char-nonblock stream))))
;;         (cond
;;           ((eq char :eof) (return nil))
;;           ((eq char :nonblock-peek) (return nil))
;;           ((null char) (if (plusp (fill-pointer buffer)) (return (parse-input-bytes-to-message buffer))
;;                            (if (and timeout (> timeout 0) (> (/ (- (get-internal-real-time) start-time) internal-time-units-per-second) timeout))
;;                                (return nil))))
;;           (t (with-terminal-lock (instance) (vector-push-extend (char-code char) buffer))))
;;         (when (plusp (fill-pointer buffer))
;;           (when (= (aref buffer 0) #o33)
;;             (loop for i from 1 to 7 for next-char = (read-char-nonblock stream) while next-char
;;                   do (with-terminal-lock (instance) (vector-push-extend (char-code next-char) buffer))))
;;           (return (parse-input-bytes-to-message buffer)))))))

(defmethod peek-input-event ((instance terminal-instance))
  (warn "peek-input-event not reliably implemented for terminal backend.") nil)

(defmethod enable-mouse-support ((instance terminal-instance) &key motion-events-p)
  (with-terminal-lock (instance)
    (if motion-events-p (send-sequence instance :enable-mouse-any-event) (send-sequence instance :enable-mouse-btn-event))
    (send-sequence instance :enable-mouse-sgr-ext-mode)
    (finish-output (terminal-instance-stream instance))) t)

(defmethod disable-mouse-support ((instance terminal-instance))
  (with-terminal-lock (instance)
    (send-sequence instance :disable-mouse-any-event)
    (send-sequence instance :disable-mouse-sgr-ext-mode)
    (finish-output (terminal-instance-stream instance))) t)

(defmethod set-input-mode ((instance terminal-instance) mode)
  (declare (ignore mode)) ; Raw mode is handled by initialize/shutdown.
  t)

;; Forward declaration
(declaim (ftype (function (terminal-instance t) t) render-ui-tree-to-buffer))

;; Helper function to render the UI tree to the back-buffer
;; This function will recursively traverse the tree and draw nodes.
(defun render-ui-tree-to-buffer (backend ui-node)
  (when ui-node
    (let* ((props (elmtui.view.core:ui-node-props ui-node))
           (node-type (elmtui.view.core:ui-node-type ui-node))
           (node-id (getf props :id))
           (layout-rect (getf props :layout-rect))
           ;; Get the raw style object, which might be a style-set
           (style-object (if (typep ui-node 'elmtui.view.styled:styled-ui-node)
                             (elmtui.view.styled:styles ui-node)
                             nil))
           ;; Convert to plist if it's a style-set, otherwise use as is (expecting nil or already a plist)
           (node-computed-styles (cond
                                   ((null style-object) nil)
                                   ((typep style-object 'style-set) ; style-set type imported
                                    (styles-list style-object))     ; styles-list function imported
                                   ((listp style-object) style-object) ; Already a plist (defensive)
                                   (t
                                    (log:warn "render-ui-tree-to-buffer: Unexpected style object type ~A for node type ~A, ID: ~A"
                                              (type-of style-object) node-type node-id)
                                    nil))))

      (log:debug "OUTPUT: render-node - Type: ~S, ID: ~S, LayoutRect: ~S, StyleObject: ~S, ComputedStylesPlist: ~S"
                 node-type node-id layout-rect style-object node-computed-styles)

      (when layout-rect
        (let ((rect-x (elmtui.view.geo:x layout-rect))
              (rect-y (elmtui.view.geo:y layout-rect))
              (rect-w (elmtui.view.geo:w layout-rect))
              (rect-h (elmtui.view.geo:h layout-rect)))

          ;; Proceed only if width and height are positive
          (when (and rect-w rect-h (> rect-w 0) (> rect-h 0))
            (let* ((bg-color (getf node-computed-styles :background-color)) ; Key from stylesheet
                   (fg-color (getf node-computed-styles :color))          ; Standard key for text color
                   ;; Construct the style plist for buffer cell (expects :bg, :fg, :attrs)
                   (cell-style-plist ()))
              (when bg-color (setf cell-style-plist (list* :bg bg-color cell-style-plist)))
              (when fg-color (setf cell-style-plist (list* :fg fg-color cell-style-plist)))
              ;; TODO: Add other attributes if necessary, e.g. :bold, :italic from node-computed-styles
              ;; (let ((attrs ()))
              ;;   (when (getf node-computed-styles :font-weight-bold) (push :bold attrs)) ; Example
              ;;   (when attrs (setf cell-style-plist (list* :attrs attrs cell-style-plist))))

              (log:debug "RENDER-UI-TREE: Node ~S (~S), Rect (~A,~A ~Ax~A), using cell-style ~S"
                         node-id node-type rect-x rect-y rect-w rect-h cell-style-plist)

              (cond
                ((or (eq node-type :container) (eq node-type :div)) ; For rainbow stripes and other general containers
                 (fill-rectangle backend rect-y rect-x rect-h rect-w
                                 :char #\Space ; Default char for background
                                 :style cell-style-plist))
                ;; Add handling for :text-node or other specific types if needed
                ;; ((eq node-type :text-node)
                ;;  (let ((text-content (getf props :text "")))
                ;;    (draw-text-at backend rect-y rect-x text-content :style cell-style-plist)))
                (t
                 ;; Default behavior for other node types: if it has a background, fill it.
                 (when bg-color
                   (fill-rectangle backend rect-y rect-x rect-h rect-w
                                   :char #\Space
                                   :style cell-style-plist))))))))

      ;; Recursively render children
      (dolist (child (elmtui.view.core:ui-node-children ui-node))
        (render-ui-tree-to-buffer backend child)))))
