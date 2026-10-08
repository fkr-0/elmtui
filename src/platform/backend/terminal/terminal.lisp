;;;===============================================================
;;; File: src/platform/backend/terminal/terminal.lisp
;;; Standard Terminal Backend
;;;
;;; This file contains the terminal instance management and core
;;; terminal operations. Added canvas integration for controlled positioning.
;;;===============================================================

(uiop:define-package :elmtui.platform.backend.terminal
  (:use :cl :elmtui.platform.api :log4cl)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:virtual-terminal-buffer #:make-virtual-buffer #:clear-buffer #:resize-buffer
    #:buffer-width #:buffer-height #:with-virtual-buffer-lock
    #:set-buffer-cell-at #:fill-buffer-region #:buffer-cell-at)
  ;; (:import-from :elmtui.platform.backend.terminal.diff-renderer ; For render-and-present
  ;;               #:compute-buffer-diff #:apply-terminal-diff)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from #:sb-unix
    #:sigwinch #:sigint) ; For signal handling
  (:import-from #:sb-sys
    #:enable-interrupt) ; For signal handling
  (:import-from #:cl-inputs.api
    #:make-ready-input-source #:with-input-source #:set-terminal-modes)
  (:import-from #:cl-inputs.loop
    #:next-token)
  (:import-from #:elmtui.platform.input
    #:cl-inputs-token->event)
  (:import-from #:cl-inputs.terminal.ansii
    #:get-sequence #:render-seq )
  (:import-from #:cl-inputs.device.api
    #:device-write-bytes #:device-output-stream #:device-input-stream)
  (:import-from #:cl-inputs.util
    #:string-to-utf-8-bytes)
  (:import-from #:elmtui.platform.api #:term-w #:term-h #:term-style #:term-stream)
  (:import-from :cl-styles.adapters
    #:normalize-tui-style-plist)
  (:import-from :elmtui.view.styled #:styled-ui-node #:styles)
  (:import-from :elmtui.view.geo #:x #:y #:w #:h #:rectangle-pos)
  (:import-from #:elmtui.platform.backend.common.ansi-styling
    #:make-terminal-style #:make-termcolor #:exec-sequence
    #:update-style! #:copy-term-style
    #:terminal-style-fg-color #:terminal-style-bg-color
    #:make-terminal-color
    #:terminal-style
    #:make-terminal-style
    #:terminal-style-bold #:terminal-style-italic
    #:terminal-style-underline #:terminal-style-inverse
    #:ansi-seqs #:stringify-sgr)
  (:import-from #:elmtui.platform.api
    #:clear-screen)

  (:import-from :elmtui.core.system-events #:make-terminalresized-systemevent
    #:make-cursorposition-systemevent)
  (:import-from :elmtui.core.errors
    #:backend-error #:signal-backend-operation-failed
    #:with-error-context #:error-with-context)

  ;; (:import-from #:elmtui.platform.canvas
  ;;               #:canvas
  ;;               #:make-terminal-canvas
  ;;               #:initialize-terminal-canvas
  ;;               #:get-canvas-viewport
  ;;               #:apply-canvas-to-buffer
  ;;               #:restore-terminal-state
  ;;               #:canvas-buffer)
                                        ; For render-and-present
  (:export #:terminal-instance
    #:initialize-backend
    #:shutdown-backend
    #:terminal-instance-stream
    #:terminal-instance-cl-device
    #:terminal-instance-width
    #:terminal-instance-height
    #:terminal-instance-cursor-visible-p
    #:terminal-instance-cursor-row
    #:terminal-instance-cursor-col
    #:terminal-instance-current-style
    #:terminal-instance-lock
    #:terminal-output-statistics
    #:reset-terminal-output-statistics
    #:terminal-output-stats-ops-processed
    #:terminal-output-stats-style-changes-applied
    #:terminal-output-stats-cursor-moves-applied
    #:terminal-output-stats-chars-written
    #:terminal-output-stats-forced-style-resets

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
    #:make-terminal-instance-for-device
    #:*terminal-debug-phase*
    #:*terminal-debug-frame-id*
    #:*terminal-debug-owned-region*
    ))

(in-package :elmtui.platform.backend.terminal)

(defvar *terminal-debug-phase* nil
  "Current rendering phase, bound dynamically during pipeline display.")
(defvar *terminal-debug-frame-id* nil
  "Current frame ID, bound dynamically during pipeline display.")
(defvar *terminal-debug-owned-region* nil
  "Current owned region, bound dynamically during pipeline display.")

(defparameter *log-terminal-clear-calls* nil
  "When true, log clear/erase calls with a backtrace for debugging.")

(defun %log-terminal-clear (label &optional details)
  (when *log-terminal-clear-calls*
    (let ((bt (with-output-to-string (s)
                (uiop:print-backtrace :stream s))))
      (log-info "TERMINAL ~A ~A~%~A" label details bt))))

(defstruct terminal-output-stats
  "Successful terminal output operations belonging to one presenter instance."
  (ops-processed 0 :type fixnum)
  (style-changes-applied 0 :type fixnum)
  (cursor-moves-applied 0 :type fixnum)
  (chars-written 0 :type fixnum)
  (forced-style-resets 0 :type fixnum))

(defstruct terminal-instance
  (stream nil :type (or null stream))
  (cl-device nil :type (or null t))
  (input-source nil :type (or null t))
  (width 80 :type integer)
  (height 24 :type integer)
  (cursor-start-col 24 :type integer)
  (cursor-start-row 24 :type integer)
  (cursor-visible-p t :type boolean)
  (cursor-row 0 :type integer)
  (cursor-col 0 :type integer)
  (current-style (make-terminal-style)
    :type (or null terminal-style))
  (lock (make-instance 'lockable) :type lockable)
  (front-buffer nil :type (or null virtual-terminal-buffer))
  (back-buffer nil :type (or null virtual-terminal-buffer))
  (publish-fn nil :type (or null function)) ; For signal handlers
  (scrolled-lines 0 :type integer)
  (output-stats (make-terminal-output-stats) :type terminal-output-stats))

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

(defun terminal-output-statistics (instance)
  "Return an independent snapshot of INSTANCE's successful output counters."
  (check-type instance terminal-instance)
  (with-terminal-lock (instance)
    (copy-terminal-output-stats (terminal-instance-output-stats instance))))

(defun reset-terminal-output-statistics (instance)
  "Reset only INSTANCE's output counters. Return an empty snapshot."
  (check-type instance terminal-instance)
  (with-terminal-lock (instance)
    (setf (terminal-instance-output-stats instance) (make-terminal-output-stats))
    (copy-terminal-output-stats (terminal-instance-output-stats instance))))

(defun %terminal-device (instance)
  "Return the cl-inputs device attached to INSTANCE, or NIL."
  (and instance (terminal-instance-cl-device instance)))

(defun %terminal-stream (instance)
  "Return the active output stream for INSTANCE, preferring the cl-inputs device stream."
  (or (and (terminal-instance-stream instance)
        (open-stream-p (terminal-instance-stream instance))
        (terminal-instance-stream instance))
    (let ((dev (%terminal-device instance)))
      (and dev (device-output-stream dev)))))

(defun %write-string-to-device (device string)
  "Write STRING to DEVICE using cl-inputs device-write-bytes."
  (when (and device string)
    (let ((bytes (string-to-utf-8-bytes string)))
      (device-write-bytes device bytes 0 (length bytes)))))

(defun %device-terminal-size (device)
  "Read Linux kernel geometry without consuming terminal input."
  #+linux
  (sb-alien:with-alien
      ((size (sb-alien:struct terminal-window-size
               (rows sb-alien:unsigned-short)
               (cols sb-alien:unsigned-short)
               (x sb-alien:unsigned-short)
               (y sb-alien:unsigned-short))))
    (when (zerop
           (sb-alien:alien-funcall
            (sb-alien:extern-alien
             "ioctl"
             (sb-alien:function sb-alien:int sb-alien:int
                                sb-alien:unsigned-long sb-alien:system-area-pointer))
            (cl-inputs.device.api:device-fd device)
            #x5413 ; Linux TIOCGWINSZ
            (sb-alien:alien-sap (sb-alien:addr size))))
      (return-from %device-terminal-size
        (values (sb-alien:slot size 'cols) (sb-alien:slot size 'rows)))))
  (cl-inputs.terminal.api:get-terminal-size device))

(defun %device-cursor-position (source)
  "Probe once through the input router before starting the input thread."
  (let* ((query (cl-inputs.loop:send-terminal-query source :cursor-position :timeout 0.5d0))
         (response (cl-inputs.loop:wait-terminal-response source query :timeout 0.5d0))
         (data (and response (cl-inputs.tokens:input-token-data response))))
    (values (and data (1- (getf data :row)))
            (and data (1- (getf data :column))))))

(defun make-terminal-instance-for-device (&key device publish-fn (initial-clear nil))
  "Construct a terminal-instance around a cl-inputs DEVICE."
  (declare (ignore initial-clear))
  (let ((stream (or (and device (device-output-stream device))
                  (error "cl-inputs device did not provide an output stream."))))
    (let ((instance (make-terminal-instance
                      :stream stream
                      :cl-device device
                      :input-source (and device (cl-inputs.api:make-ready-input-source :device device))
                      :publish-fn publish-fn)))
      (let* ((row 0)
             (col 0)
             (width 80)
             (height 24))
        ;; Cursor probes can time out on some pseudo terminals; keep sane defaults.
        (handler-case
            (multiple-value-bind (r c) (%device-cursor-position (terminal-instance-input-source instance))
              (when (and (numberp r) (>= r 0))
                (setf row r))
              (when (and (numberp c) (>= c 0))
                (setf col c)))
          (error (e)
            (log-warn "TERMINAL: Failed to read initial cursor position; using defaults: ~A" e)))
        ;; Dimension probes can also fail in non-interactive environments.
        (handler-case
            (multiple-value-bind (w h) (%device-terminal-size device)
              (when (and (numberp w) (> w 0))
                (setf width w))
              (when (and (numberp h) (> h 0))
                (setf height h)))
          (error (e)
            (log-warn "TERMINAL: Failed to read initial terminal size; using defaults: ~A" e)))
        (setf (terminal-instance-cursor-row instance) row
              (terminal-instance-cursor-start-row instance) row
              (terminal-instance-cursor-start-col instance) col
              (terminal-instance-cursor-col instance) col
              (terminal-instance-width instance) width
              (terminal-instance-height instance) height)
        (when publish-fn
          (funcall publish-fn (make-cursorposition-systemevent :col (1+ col) :row (1+ row)))
          (funcall publish-fn (make-terminalresized-systemevent :width width :height height)))
        (let ((front (make-virtual-buffer width height))
               (back (make-virtual-buffer width height)))
          (setf (terminal-instance-front-buffer instance) front
            (terminal-instance-back-buffer instance) back)))
      (setup-terminal-signal-handlers instance publish-fn)
      (when device (cl-inputs.terminal.api:hide-cursor device))
      ;; Only clear terminal if explicitly requested during init
      ;; This prevents clearing screen when initial-clear=nil is passed
      ;; Only clear terminal if explicitly requested during init
      ;; This prevents clearing screen when initial-clear=nil is passed
      ;; (setf elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t)
      (when device (cl-inputs.terminal.api:flush-output device))
      instance)))

;;;---------------------------------------------------------------
;;; Internal Terminal Reset Helper
;;;---------------------------------------------------------------
(defun %force-clear-terminal-and-reset-buffers
  (instance &key (row -1) (buffer t) (cursor (list 1 1)))
  "Internal helper: Forces a hard clear of the terminal screen and resets internal buffers."
  (check-type instance terminal-instance)
  (log:info "TERMINAL (internal): Forcing clear of terminal and resetting buffers.")
  (with-terminal-lock (instance)
    (when (= -1 row)
      (send-sequence instance :erase-in-display 2)) ;; Clear entire screen
    (send-sequence instance :cursor-set-position (car cursor)
      (cadr cursor)) ;; Move cursor to top-left
    (send-sequence instance :reset) ;; SGR 0 - Reset all styles
    (when buffer
      (let ((front-buffer (terminal-instance-front-buffer instance)))
        (when front-buffer
          (with-virtual-buffer-lock (front-buffer)
            (clear-buffer front-buffer :char #\Space))))
      (let ((back-buffer (terminal-instance-back-buffer instance)))
        (when back-buffer
          (with-virtual-buffer-lock (back-buffer)
            (clear-buffer back-buffer)))))

    (setf (terminal-instance-current-style instance) (make-terminal-style))
    (flush-output instance)
    (finish-output (terminal-instance-stream instance)))
  t)

;;;---------------------------------------------------------------
;;; Signal Handling Setup (SBCL/Unix specific)
;;;---------------------------------------------------------------
(defun setup-terminal-signal-handlers (instance publish-fn)
  (when publish-fn
    (let ((sigint-fired nil)
          (sigwinch-busy nil))
      ;; SIGWINCH - Terminal Resize (throttle reentry)
      (sb-sys:enable-interrupt sb-unix:sigwinch
        (lambda (signal code scp)
          (declare (ignore signal code scp))
          (unless sigwinch-busy
            (setf sigwinch-busy t)
            (multiple-value-bind (w h)
              (get-screen-dimensions instance) ; Use backend's method
              (log:info "TERMINAL: SIGWINCH detected. Publishing TerminalResized event W:~A H:~A" w h)
              (funcall publish-fn (make-terminalresized-systemevent :width w :height h)))
            (setf sigwinch-busy nil))))
      ;; SIGINT - Interrupt (Ctrl+C) (publish only once)
      (sb-sys:enable-interrupt sb-unix:sigint
        (lambda (signal code scp)
          (declare (ignore signal code scp))
          (when (not sigint-fired)
            (setf sigint-fired t)
            (log:info "TERMINAL: SIGINT detected. Publishing :app-quit-requested (latched)")
            (funcall publish-fn '(:app-quit-requested (:source :sigint))))))
      ;; SIGTERM - Termination signal (e.g. from kill or process manager)
      ;; Route through the same quit machinery so the app gets a clean shutdown.
      (sb-sys:enable-interrupt sb-unix:sigterm
        (lambda (signal code scp)
          (declare (ignore signal code scp))
          (log:info "TERMINAL: SIGTERM detected. Publishing :app-quit-requested")
          (funcall publish-fn '(:app-quit-requested (:source :sigterm))))))))

(defun teardown-terminal-signal-handlers ()
  (log:info "TERMINAL: Disabling signal handlers for terminal")
  ;; Disable SIGWINCH handler
  (sb-sys:enable-interrupt sb-unix:sigwinch :default)
  ;; After we latched SIGINT once we ignore further signals to avoid log spam during teardown
  (sb-sys:enable-interrupt sb-unix:sigint :ignore)
  ;; Restore default SIGTERM behaviour
  (sb-sys:enable-interrupt sb-unix:sigterm :default))


;;;---------------------------------------------------------------
;;; Backend Lifecycle
;;;---------------------------------------------------------------
(defmethod initialize-backend ((backend-type (eql :terminal))
                                &rest initargs &key &allow-other-keys)
  "Compatibility alias: :TERMINAL behaves the same as :TTY."
  (declare (ignore backend-type))
  (apply #'initialize-backend :tty initargs))

(defmethod initialize-backend ((backend-type (eql :tty))
                                &key publish-fn (tty-path "/dev/tty") (device nil) (initial-clear nil) &allow-other-keys)
  (handler-case
    (let ((dev (or device (cl-inputs.device.api:make-device :tty :path tty-path))))
      (log-info "TERMINAL: Initialized backend using cl-inputs device at ~A" tty-path)
      (make-terminal-instance-for-device :device dev :publish-fn publish-fn :initial-clear initial-clear))
    (error (e)
      (format t "TERMINAL: Initialization Error: ~A~%" e)
      (format t "~{~A~%~}" (uiop:print-backtrace))
      (signal-backend-operation-failed "terminal" "initialization" e))))

(defmethod shutdown-backend ((instance terminal-instance))
  (log-info "TERMINAL: Shutting down backend...")
  (handler-case
    (with-terminal-lock (instance)
      (teardown-terminal-signal-handlers)
      (send-sequence instance :cursor-show)
      (send-sequence instance :reset) ; SGR 0
      ;; Do not force-clear here; let root-viewport cleanup preserve surrounding content.
      ;; Restore normal screen buffer if alt screen was used
      ;; (send-sequence instance :normal-screen-buffer)
      ;; (write-output  (format nil "~c[?25h~c[0m~c[J~c[H"
      ;;                        #\Escape #\Escape #\Escape #\Escape)
      ;;                (term-stream instance)) ; Show cursor, reset, clear, home
      (flush-output instance)
      (log-info "TERMINAL> Resetting terminal")
      (flush-output instance)
      (let ((source (terminal-instance-input-source instance)))
        (when source
          (handler-case
              (cl-inputs.loop:close-input-source source)
            (error (condition)
              (log-warn "TERMINAL: input-source cleanup failed: ~A" condition)))
          (setf (terminal-instance-input-source instance) nil)))
      (let ((device (terminal-instance-cl-device instance)))
        (when device
          ;; cl-inputs close-input-source handles restoration; device kept for stream
          (handler-case
              (cl-inputs.device.api:close-device device)
            (error (condition)
              (log-warn "TERMINAL: device cleanup failed: ~A" condition)))
          (setf (terminal-instance-cl-device instance) nil)))
      (when (terminal-instance-stream instance)
        (handler-case
            (close (terminal-instance-stream instance))
          (error (condition)
            (log-warn "TERMINAL: stream cleanup failed: ~A" condition)))
        (setf (terminal-instance-stream instance) nil))
      (setf (terminal-instance-front-buffer instance) nil
        (terminal-instance-back-buffer instance) nil))
    (error (e)
      (log-info "TERMINAL: Shutdown Error: ~A" e)
      (log:error "TERMINAL: Error during primary shutdown: ~A" e)))


  (log-info "TERMINAL: Backend shutdown complete.")
  t)

(defmethod backend-name ((instance terminal-instance)) "Standard Terminal Backend")
(defmethod backend-version ((instance terminal-instance)) "0.2.0")

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
  t)

;;;---------------------------------------------------------------
;;; Rendering
;;;---------------------------------------------------------------


;;;---------------------------------------------------------------
;;; Display & Screen Management (existing methods)
;;;---------------------------------------------------------------
(defmethod send-sequence ((instance terminal-instance) seq-id &rest args)
  (let ((seq-obj (cl-inputs.terminal.ansii:get-sequence seq-id)))
    (when seq-obj
      (let ((rendered (apply #'cl-inputs.terminal.ansii:render-seq seq-obj args))
             (device (%terminal-device instance)))
        (cond
          (device (%write-string-to-device device rendered))
          (t
            (let ((stream (%terminal-stream instance)))
              (when stream
                (cl-inputs.util:write-output rendered stream)))))))))

(defmethod get-cursor-position ((instance terminal-instance))
  (let ((dev (%terminal-device instance)))
    (cond
      (dev
        (multiple-value-bind (row col) (cl-inputs.terminal.api:get-cursor-position dev)
          (when row (setf (terminal-instance-cursor-row instance) row))
          (when col (setf (terminal-instance-cursor-col instance) col))
          (values row col)))
      (t
        (values (terminal-instance-cursor-row instance)
          (terminal-instance-cursor-col instance))))))

(defmethod get-screen-dimensions ((instance terminal-instance))
  (let ((dev (%terminal-device instance)))
    (cond
      (dev
        (multiple-value-bind (w h) (cl-inputs.terminal.api:get-terminal-size dev)
          (when w (setf (terminal-instance-width instance) w))
          (when h (setf (terminal-instance-height instance) h))
          (values (or w (term-w instance)) (or h (term-h instance)))))
      (t
        (values (term-w instance) (term-h instance))))))

(defmethod device-input-source ((instance terminal-instance))
  "Get the input source from the terminal instance."
  (terminal-instance-input-source instance))

(defmethod elmtui.platform.api:backend-input-device ((instance terminal-instance))
  (terminal-instance-cl-device instance))

(defmethod elmtui.platform.api:backend-input-source ((instance terminal-instance))
  (terminal-instance-input-source instance))

(defmethod clear-screen ((instance terminal-instance) &optional rect)
  (%log-terminal-clear "clear-screen" rect)
  (log:debug "TERMINAL clear-screen: Clearing back-buffer.")
  (let ((dev (%terminal-device instance)))
    (when dev
      (if rect
        (cl-inputs.terminal.api:clear-area dev (y rect) (x rect) (h rect) (w rect))
        (cl-inputs.terminal.api:clear-screen dev))))
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (if rect
          (clear-area instance back-buffer (y rect) (x rect) (h rect) (w rect))
          (clear-buffer back-buffer)))))
  t)

(defmethod flush-output ((instance terminal-instance))
  (with-terminal-lock (instance)
    (let ((dev (%terminal-device instance)))
      (cond
        (dev (cl-inputs.terminal.api:flush-output dev))
        ((terminal-instance-stream instance)
          (finish-output (terminal-instance-stream instance))))))
  t)

(defmethod set-cursor-visibility ((instance terminal-instance) visible-p)
  (with-terminal-lock (instance)
    (setf (terminal-instance-cursor-visible-p instance) visible-p)
    (let ((dev (%terminal-device instance)))
      (cond
        (dev
          (if visible-p
            (cl-inputs.terminal.api:show-cursor dev)
            (cl-inputs.terminal.api:hide-cursor dev)))
        (t
          (if visible-p
            (send-sequence instance :cursor-show)
            (send-sequence instance :cursor-hide))))))
  t)

(defmethod set-cursor-position ((instance terminal-instance) row col)
  (with-terminal-lock (instance)
    (setf (terminal-instance-cursor-row instance) row)
    (setf (terminal-instance-cursor-col instance) col)
    (let ((dev (%terminal-device instance)))
      (if dev
        (cl-inputs.terminal.api:set-cursor-position dev row col)
        (send-sequence instance :cursor-set-position (1+ row) (1+ col)))))
  t)

;; (defmethod get-cursor-position ((instance terminal-instance))
;;   (values (terminal-instance-cursor-row instance) (terminal-instance-cursor-col instance)))

(defmethod hide-cursor ((instance terminal-instance)) (set-cursor-visibility instance nil))
(defmethod show-cursor ((instance terminal-instance)) (set-cursor-visibility instance t))

(defmethod scroll-down ((instance terminal-instance) &optional (lines 1))
  (with-terminal-lock (instance)
    (incf (terminal-instance-scrolled-lines instance) lines)
    (let ((dev (%terminal-device instance)))
      (if dev
        (cl-inputs.terminal.api:scroll-lines dev lines)
        (send-sequence instance :scroll-down lines)))))

(defmethod scroll-up ((instance terminal-instance) &optional (lines 1))
  (with-terminal-lock (instance)
    (decf (terminal-instance-scrolled-lines instance) lines)
    (let ((dev (%terminal-device instance)))
      (if dev
        (cl-inputs.terminal.api:scroll-lines dev (- lines))
        (send-sequence instance :scroll-up lines)))))

(defmethod elmtui.platform.api:scroll ((instance terminal-instance) n)
  "Scroll the terminal by N lines (positive=down, negative=up)."
  (elmtui.platform.api:scroll-lines instance n)
  t)

(defmethod elmtui.platform.api:scroll-lines ((instance terminal-instance) n)
  (cond
    ((> n 0) (scroll-down instance n))
    ((< n 0) (scroll-up instance (- n)))
    (t t)))

(defmethod elmtui.platform.api:clear-below-cursor ((instance terminal-instance))
  "Clear from cursor position to end of screen using ANSI escape sequence."
  (with-terminal-lock (instance)
    (let ((stream (term-stream instance)))
      ;; ANSI escape code: ESC[0J clears from cursor to end of screen
      (write-string (format nil "~C[0J" #\Escape) stream)
      (force-output stream))))

;;;---------------------------------------------------------------
;;; Drawing Primitives (draw to a specified target-buffer)
;;;---------------------------------------------------------------
(defmethod draw-text-at ((instance terminal-instance) target-buffer row col text &key style)
  (log:debug "BUFFER: draw-text-at on target-buffer - Row: ~A, Col: ~A, Text: \"~A\", Style: ~S" row col text style)
  (when target-buffer
    (with-virtual-buffer-lock (target-buffer)
      (let ((buffer-w (buffer-width target-buffer))
             (buffer-h (buffer-height target-buffer)))
        (loop for i from 0 below (length text)
          for char = (aref text i)
          for current-col = (+ col i)
          when (and (>= row 0) (< row buffer-h)
                 (>= current-col 0) (< current-col buffer-w))
          do (set-buffer-cell-at target-buffer row current-col char style)
          else do (log:warn "draw-text-at: Clipping char '~C' at (~A,~A) for target buffer" char row current-col) (loop-finish)))))
  t)

(defmethod draw-char-at ((instance terminal-instance) target-buffer row col char &key style)
  (log:debug "BUFFER: draw-char-at on target-buffer - Row: ~A, Col: ~A, Char: ~C, Style: ~S" row col char style)
  (when target-buffer
    (with-virtual-buffer-lock (target-buffer)
      (let ((buffer-w (buffer-width target-buffer))
             (buffer-h (buffer-height target-buffer)))
        (if (and (>= row 0) (< row buffer-h) (>= col 0) (< col buffer-w))
          (set-buffer-cell-at target-buffer row col char style)
          (log:warn "draw-char-at: Clipping char '~C' at (~A,~A) for target buffer" char row col)))))
  t)

(defmethod fill-rectangle ((instance terminal-instance) target-buffer row col height width &key char style)
  (log:debug "BUFFER: fill-rectangle on target-buffer - Row: ~A, Col: ~A, H: ~A, W: ~A, Char: ~C, Style: ~S" row col height width char style)
  (when target-buffer
    (with-virtual-buffer-lock (target-buffer)
      (fill-buffer-region target-buffer row col width height (or char #\Space) style)))
  t)

(defmethod draw-box-outline ((instance terminal-instance) target-buffer row col height width &key style corners sides)
  (declare (ignore corners sides)) ; Simple ASCII box for now
  (log:debug "BUFFER: draw-box-outline on target-buffer - Row: ~A, Col: ~A, H: ~A, W: ~A, Style: ~S" row col height width style)
  (when (and (> width 1) (> height 1))
    (when target-buffer
      (with-virtual-buffer-lock (target-buffer)
        (draw-char-at instance target-buffer row col #\+ :style style)
        (draw-char-at instance target-buffer row (+ col width -1) #\+ :style style)
        (draw-char-at instance target-buffer (+ row height -1) col #\+ :style style)
        (draw-char-at instance target-buffer (+ row height -1) (+ col width -1) #\+ :style style)
        (loop for c from (1+ col) below (+ col width -1)
          do (draw-char-at instance target-buffer row c #\- :style style)
          (draw-char-at instance target-buffer (+ row height -1) c #\- :style style))
        (loop for r from (1+ row) below (+ row height -1)
          do (draw-char-at instance target-buffer r col #\| :style style)
          (draw-char-at instance target-buffer r (+ col width -1) #\| :style style)))))
  t)

(defmethod draw-styled-box ((instance terminal-instance) target-buffer row col height width &key border-style border-color box-char-set style)
  (declare (ignore box-char-set))
  (log:debug "BUFFER: draw-styled-box on target-buffer - Pos: (~A,~A), Size: (~A,~A), Style: ~S, BorderStyle: ~S, BorderColor: ~S"
    row col height width style border-style border-color)
  (when (and (> width 1) (> height 1))
    (let* ((effective-style (if border-color (list :fg border-color) (getf style :attrs)))
            (chars (case border-style
                      (:single '(#\┌ #\┐ #\└ #\┘ #\─ #\│))
                     (:double '(#\╔ #\╗ #\╚ #\╝ #\═ #\║))
                     (otherwise '(#\+ #\+ #\+ #\+ #\- #\|))))
            (tl (first chars)) (tr (second chars)) (bl (third chars)) (br (fourth chars))
            (horiz (fifth chars)) (vert (sixth chars)))
      (when target-buffer
        (with-virtual-buffer-lock (target-buffer)
          (draw-char-at instance target-buffer row col tl :style effective-style)
          (draw-char-at instance target-buffer row (+ col width -1) tr :style effective-style)
          (draw-char-at instance target-buffer (+ row height -1) col bl :style effective-style)
          (draw-char-at instance target-buffer (+ row height -1) (+ col width -1) br :style effective-style)
          (loop for c from (1+ col) below (+ col width -1)
            do (draw-char-at instance target-buffer row c horiz :style effective-style)
            (draw-char-at instance target-buffer (+ row height -1) c horiz :style effective-style))
          (loop for r from (1+ row) below (+ row height -1)
            do (draw-char-at instance target-buffer r col vert :style effective-style)
            (draw-char-at instance target-buffer r (+ col width -1) vert :style effective-style))))))
  t)

(defmethod set-cell-style ((instance terminal-instance) target-buffer row col &key style)
  (log:debug "BUFFER: set-cell-style on target-buffer - Row: ~A, Col: ~A, Style: ~S" row col style)
  (when target-buffer
    (with-virtual-buffer-lock (target-buffer)
      (let ((buffer-w (buffer-width target-buffer)) (buffer-h (buffer-height target-buffer)))
        (if (and (>= row 0) (< row buffer-h) (>= col 0) (< col buffer-w))
          (let ((current-cell (buffer-cell-at target-buffer row col)))
            (set-buffer-cell-at target-buffer row col (elmtui.platform.backend.common.virtual-buffer::buffer-cell-char current-cell) style))
          (log:warn "set-cell-style: Clipping style at (~A,~A) for target buffer" row col)))))
  t)

(defmethod clear-area ((instance terminal-instance) target-buffer row col height width &key style)
  ;; Only update the virtual buffer. Terminal I/O is handled upstream (clear-screen calls
  ;; cl-inputs.terminal.api:clear-area before calling this) or by the diff renderer.
  ;; Previously this method also emitted ANSI escape sequences directly, causing double-writes
  ;; when called from clear-screen with a rect.
  (%log-terminal-clear "clear-area"
                       (list :row row :col col :height height :width width :style style))
  (log:debug "BUFFER: clear-area on target-buffer - Row: ~A, Col: ~A, H: ~A, W: ~A, Style: ~S" row col height width style)
  (when target-buffer
    (with-virtual-buffer-lock (target-buffer)
      (fill-buffer-region target-buffer row col width height #\Space style)))
  t)

;;;---------------------------------------------------------------
;;; Color and Style Management (existing methods)
;;;---------------------------------------------------------------
(defun style-to-terminal-style (style-plist)
  (log-debug "Converting style plist to terminal style: ~S" style-plist)
  (let ((normalized (when style-plist
                      (normalize-tui-style-plist style-plist))))
    (when normalized
    (let ((ts (make-terminal-style)))
      (let ((bg (getf normalized :bg-color)))
        (cond
          ((typep bg 'elmtui.platform.backend.common.ansi-styling:terminal-color)
            (setf (terminal-style-bg-color ts) bg))
          ((and (listp bg) (= (length bg) 3))
            (destructuring-bind (r g b) bg
              (setf (terminal-style-bg-color ts)
                (elmtui.platform.backend.common.ansi-styling:make-termcolor
                  :bg t :r r :g g :b b))))
          ((integerp bg)
            (setf (terminal-style-bg-color ts)
              (elmtui.platform.backend.common.ansi-styling:make-termcolor
                :bg t :color-256 bg)))
          ((keywordp bg)
            (setf (terminal-style-bg-color ts)
              (elmtui.platform.backend.common.ansi-styling:make-termcolor
                :bg t :simple bg)))
          (t
            ;; No background color specified; leave as default
            )))
      (let ((fg (getf normalized :fg-color)))
        (cond
          ((typep fg 'elmtui.platform.backend.common.ansi-styling:terminal-color)
            (setf (terminal-style-fg-color ts) fg))
          ((and (listp fg) (= (length fg) 3))
            (destructuring-bind (r g b) fg
              (setf (terminal-style-fg-color ts)
                (elmtui.platform.backend.common.ansi-styling:make-termcolor
                  :r r :g g :b b))))
          ((integerp fg)
            (setf (terminal-style-fg-color ts)
              (elmtui.platform.backend.common.ansi-styling:make-termcolor
                :color-256 fg)))
          ((keywordp fg)
            (setf (terminal-style-fg-color ts)
              (elmtui.platform.backend.common.ansi-styling:make-termcolor
                :simple fg)))
          (t
            ;; No foreground color specified; leave default
            )))
      (let ((attrs (getf normalized :attrs)))
        (when (member :bold attrs) (setf (terminal-style-bold ts) t))
        (when (member :italic attrs) (setf (terminal-style-italic ts) t))
        (when (member :underline attrs) (setf (terminal-style-underline ts) t))
        (when (member :inverse attrs) (setf (terminal-style-inverse ts) t)))
      (log:debug "APPLY-STYLE-DIFF CALLED. Current: ~A" ts)
      ts))))

(defun write-style-to-stream (stream style)
  "Write ANSI escape sequences for STYLE to STREAM. STYLE may be a style plist or a terminal-style instance."
  (when style
    (let ((ts (if (typep style 'elmtui.platform.backend.common.ansi-styling:terminal-style)
                style
                (style-to-terminal-style style))))
      (when ts
        (let ((seqs (elmtui.platform.backend.common.ansi-styling:ansi-seqs ts
                      :fg-color
                      :bg-color
                      :bold
                      :italic
                      :underline)))
          ;; Each seq is a full ESC[…m sequence; write directly
          (dolist (seq seqs)
            (write-output seq stream)))))))
(defmacro as-utf-8-bytes (char writer)
  "Given the character CHAR, call the WRITER for every byte in the
  UTF-8 encoded form of that character. WRITER may a function or a
  macro."
  (let ((char-code (gensym)))
    `(let ((,char-code (char-code ,char)))
       (declare (type fixnum ,char-code))
       (cond ((< ,char-code 128) (,writer ,char-code))
         ;; ((< ,char-code 2048)
         ;;  (,writer (logior #b11000000 (ldb (byte 5 6) ,char-code)))
         ;;  (,writer (logior #b10000000 (ldb (byte 6 0) ,char-code))))
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
  ;; (log:info "APPLY-STYLE-DIFF CALLED. Current: ~S, New: ~S" (term-style instance) new-style)
  (let* ((current-style (term-style instance))
          (stream (term-stream instance))
          ;; If new-style is already a terminal-style, use it directly
          (new-style-ts (cond
                          ((typep new-style 'elmtui.platform.backend.common.ansi-styling:terminal-style)
                            new-style)
                          (new-style (progn
                                       ;; (log:debug "APPLY-STYLE-DIFF: Converting plist to terminal-style: ~S" new-style)
                                       (style-to-terminal-style new-style)))
                          (t (make-terminal-style)))))
    (when (equal current-style new-style-ts)
      (return-from apply-style-diff t))
    ;; (log:debug "APPLY-STYLE-DIFF: Transitioning. Current: ~S, New: ~S" current-style new-style-ts)
    (let ((changes (update-style! current-style new-style-ts)))
      ;; Emit ANSI sequences only for changed attributes
      (dolist (change changes)
        (destructuring-bind (attr val) change
          (declare (ignore val)) ; We don't need the value, just the attribute
          (let ((seqs (elmtui.platform.backend.common.ansi-styling:ansi-seqs current-style attr)))
            (dolist (seq seqs)
              ;; (log:debug "APPLY-STYLE-DIFF: Writing ANSI sequence for ~S: ~S" attr seq)
              (exec-sequence (terminal-instance-lock instance)
                (terminal-instance-stream instance)
                seq)))))
      ;; current-style is mutated in-place by update-style!
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

(defmethod poll-input-event ((instance terminal-instance) &key timeout)
  (let ((source (terminal-instance-input-source instance)))
    (when source
      (let ((token (cl-inputs.loop:next-token source :timeout timeout)))
        (when token
          (cl-inputs-token->event token))))))


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
