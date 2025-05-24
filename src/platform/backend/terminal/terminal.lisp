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
                #:set-buffer-cell-at #:fill-buffer-region #:buffer-cell-at) ; Added for drawing
  (:import-from :log4cl #:log-debug)
  (:import-from #:sb-posix
                #:tcgetattr #:tcsetattr #:termios #:termios-lflag #:termios-cc
                #:icanon #:echo #:vmin #:vtime #:tcsanow #:tcsaflush)
  (:import-from #:sb-unix
                #:unix-open #:unix-close #:unix-read #:unix-write #:o_rdwr)
  (:import-from #:sb-sys ; Removed #:io-stream-p
                #:fd-stream-fd #:make-fd-stream)
  (:import-from #:elmtui.core.event-types ; Event structs for intermediate parsing
                #:key-event-key #:key-event-char #:key-event-modifiers
                #:mouse-event-x #:mouse-event-y
                #:mouse-event-type #:mouse-event-button #:mouse-event-modifiers
                #:make-mouse-event     ; For creating mouse event objects
                #:make-raw-input-event
                #:make-key-event)      ; For creating key event objects
  ;; Note: Raw events are not mapped to messages, they are returned directly if parsing fails
  (:import-from #:elmtui.platform.api #:term-w #:term-h #:term-style #:term-stream)
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
                #:restore-terminal-state)
  (:export #:terminal-instance
           #:initialize-backend ; Re-exporting for discoverability
           #:shutdown-backend
           #:get-screen-dimensions
           #:send-sequence
           #:clear-screen
           #:backend-name
           #:backend-version
           #:resize-terminal-buffers ; Exporting the new resize function
           #:force-clear-terminal-and-reset-buffers
           #:terminal-instance-front-buffer
           #:terminal-instance-back-buffer
           #:with-terminal-lock
           ;; Export the new style utility functions
           #:write-style-to-stream
           #:write-style-reset-to-stream
           #:style-to-terminal-style
           ;; Export canvas-related functions
           #:terminal-instance-canvas
           #:make-terminal-canvas
           #:initialize-terminal-canvas
           #:get-canvas-viewport
           #:apply-canvas-to-buffer
           #:restore-terminal-state))

(in-package :elmtui.platform.backend.terminal)

;; Add canvas to the terminal instance structure
(defstruct terminal-instance
  (fd -1 :type integer)
  (stream nil :type (or null stream))
  (original-termios nil :type (or null termios))

  (current-termios nil :type (or null termios))
  (width 80 :type integer)
  (height 24 :type integer)
  (cursor-visible-p t :type boolean)
  (cursor-row 0 :type integer)
  (cursor-col 0 :type integer)
  (current-style '(:fg :white :bg :black :attrs nil)) ; Store current style as a plist
  (input-buffer (make-array 0 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0))
  (lock (make-instance 'lockable) :type lockable)
  (front-buffer nil :type (or null virtual-terminal-buffer))
  (back-buffer nil :type (or null virtual-terminal-buffer))
  (canvas nil :type (or null canvas)))

(defmethod term-w((instance terminal-instance))
  "Return the width of the terminal instance."
  (terminal-instance-width instance))

(defmethod term-h((instance terminal-instance))
  "Return the height of the terminal instance."
  (terminal-instance-height instance))
(defmethod (setf term-h) (new-height (instance terminal-instance))
  "Set the height of the terminal instance."
  (setf (terminal-instance-height instance) new-height))
(defmethod (setf term-w) (new-width (instance terminal-instance))
  "Set the width of the terminal instance."
  (setf (terminal-instance-width instance) new-width))
"Return the current style of the terminal instance."
(defmethod term-style ((instance terminal-instance))
  (terminal-instance-current-style instance))
(defmethod (setf term-style) (new-style (instance terminal-instance))
  "Set the current style of the terminal instance."
  (setf (terminal-instance-current-style instance) new-style))
(defmethod term-stream ((instance terminal-instance))
  "Return the stream of the terminal instance."
  (terminal-instance-stream instance))

(defmacro with-terminal-lock ((instance) &body body)
  `(bt:with-recursive-lock-held ((lock-of (terminal-instance-lock ,instance)))
     ,@body))

;;;---------------------------------------------------------------
;;; Terminal Raw Mode Control
;;;---------------------------------------------------------------
(defun disable-raw-mode (fd original-termios)
  (when original-termios
    (tcsetattr fd tcsaflush original-termios)))

;;;---------------------------------------------------------------
;;; Backend Lifecycle
;;;---------------------------------------------------------------

(defmethod initialize-backend ((backend-type (eql :terminal)) &key (tty-path "/dev/tty") &allow-other-keys)
  (let ((fd (sb-unix:unix-open tty-path sb-posix:o-rdwr 0)))
    (unless (and fd (>= fd 0))
      (error "Could not open terminal TTY: ~A" tty-path))
    (let* ((orig-termios  (enable-raw-mode fd))
           (stream        (sb-sys:make-fd-stream fd :input t :output t :element-type 'character :buffering :none))
           (curr-termios  (sb-posix:tcgetattr fd))

           (instance      (make-terminal-instance
                           :fd             fd
                           :stream         stream
                           :original-termios orig-termios
                           :current-termios curr-termios)))
      ;; store dimensions
      (multiple-value-bind (w h) (get-screen-dimensions instance)
        (setf (terminal-instance-width  instance) w
              (terminal-instance-height instance) h)
        ;; Initialize front and back buffers
        (let ((front (make-virtual-buffer w h))
              (back (make-virtual-buffer w h)))
          (clear-buffer front)
          (clear-buffer back)
          (setf (terminal-instance-front-buffer instance) front
                (terminal-instance-back-buffer instance) back)))
      ;; now actually hide cursor & switch to alt buffer
      (send-sequence instance :cursor-hide)
                                        ;(send-sequence instance :alt-screen-buffer)
      (clear-screen instance) ; This will eventually draw to back-buffer
      (flush-output instance)
      instance)))

(defmethod shutdown-backend ((instance elmtui.platform.backend.terminal:terminal-instance))
  (restore-terminal-state instance)
  (with-terminal-lock (instance)
    ;; (send-sequence instance :normal-screen-buffer)
    (log-info "Instance - Termios: ~A% FD: ~A%" (terminal-instance-original-termios instance)(terminal-instance-fd instance))
    (log-info "Cursor Position: ~A ~A" (terminal-instance-cursor-row instance) (terminal-instance-cursor-col instance))
    (send-sequence instance :cursor-show)
    (log-info "Cursor, show ran.")
    (send-sequence instance :reset)
    (log-info "Reset sequence sent.")
    (flush-output instance)
    (log-info "Flushed output.")
    (disable-raw-mode (terminal-instance-fd instance)
                      (terminal-instance-original-termios instance))
    (log-info "Raw mode disabled.")
    (when (terminal-instance-stream instance)
      (log-info "Closing terminal stream.")
      (close (terminal-instance-stream instance))
      (setf (terminal-instance-stream instance) nil))
    (when (>= (terminal-instance-fd instance) 0)
      (log-info "Closing terminal file descriptor.")
      (unix-close (terminal-instance-fd instance))
      (setf (terminal-instance-fd instance) -1))
    ;; Clear buffer references
    (setf (terminal-instance-front-buffer instance) nil
          (terminal-instance-back-buffer instance) nil))
  (log-info "Terminal instance ~A cleaned up." instance)
  t)

;;;---------------------------------------------------------------
;;; Resize Handling
;;;---------------------------------------------------------------
(defun resize-terminal-buffers (instance new-width new-height)
  "Resizes the front and back buffers of the terminal instance.
This should be called when the physical terminal size changes."
  (check-type instance terminal-instance)
  (check-type new-width (integer 0 *))
  (check-type new-height (integer 0 *))
  (log:info "Resizing terminal buffers for instance to ~Ax~A" new-width new-height)
  ;; Update internal dimension tracking
  (setf (terminal-instance-width instance) new-width
        (terminal-instance-height instance) new-height)

  ;; Resize front buffer
  (when (terminal-instance-front-buffer instance)
    (setf (terminal-instance-front-buffer instance)
          (resize-buffer (terminal-instance-front-buffer instance) new-width new-height)))
  ;; Resize back buffer
  (when (terminal-instance-back-buffer instance)
    (setf (terminal-instance-back-buffer instance)
          (resize-buffer (terminal-instance-back-buffer instance) new-width new-height)))
  ;; Note: The driver will need to trigger a full redraw after this.
  t)

;;;---------------------------------------------------------------
;;; Display & Screen Management
;;;---------------------------------------------------------------
(defun send-sequence (instance seq-id &rest args)
  (let ((seq-obj (get-sequence seq-id)))
    (when seq-obj
      (let ((rendered (apply #'render-seq seq-obj args)))
        (write-string rendered (terminal-instance-stream instance))))))

(defmethod get-screen-dimensions ((instance terminal-instance))
  ;; Only hold the lock while sending sequences, not while blocking on input.
  (with-terminal-lock (instance)
    (send-sequence instance :cursor-save)
    (send-sequence instance :cursor-set-position 999 999) ; Move to an extreme corner
    (send-sequence instance :cursor-report)
    (finish-output (terminal-instance-stream instance)))
  ;; Read response for cursor report: ESC [ <row> ; <col> R
  (let ((response-chars '()))
    (loop for i from 1 to 10 ; Limit read attempts
          for char = (read-char (terminal-instance-stream instance) nil nil)
          while char
          do (push char response-chars)
          when (char= char #\R) do (return)
            finally (warn "Timeout or incomplete cursor report response."))
    (with-terminal-lock (instance)
      (send-sequence instance :cursor-restore)
      (finish-output (terminal-instance-stream instance)))
    (let* ((str (coerce (nreverse response-chars) 'string))
           (parts (uiop:split-string (subseq str 2 (1- (length str))) :separator '(#\;))))
      (if (= (length parts) 2)
          (values (parse-integer (second parts)) (parse-integer (first parts))) ; typically col;row
          (values (terminal-instance-width instance) (terminal-instance-height instance)))))) ; fallback

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
    (send-sequence instance :cursor-set-position (1+ row) (1+ col))) ; Terminals are 1-indexed
  t)

(defmethod get-cursor-position ((instance terminal-instance))
  (values (terminal-instance-cursor-row instance) (terminal-instance-cursor-col instance)))

(defmethod hide-cursor ((instance terminal-instance))
  (set-cursor-visibility instance nil))

(defmethod show-cursor ((instance terminal-instance))
  (set-cursor-visibility instance t))

;;;---------------------------------------------------------------
;;; Drawing Primitives
;;;---------------------------------------------------------------
;;; ——— 3) apply-style-diff: write the raw ANSI bytes from ansi-*-seq ———
;; (defun apply-style-diff (instance new-style-plist)
;;   "Only emit the minimal SGR codes to transition from current to NEW-STYLE-PLIST."
;;   (log:debug "APPLY-STYLE-DIFF: Current style: ~S, New style: ~S"
;;              (terminal-instance-current-style instance) new-style-plist)
;;   (let ((current (terminal-instance-current-style instance))
;;         (stream  (terminal-instance-stream instance))
;;         (changes '())
;;         (generated-sequences '())) ; To log generated sequences
;;     ;; figure out what changed
;;     (unless (equal (getf current :fg) (getf new-style-plist :fg))
;;       (push (list :fg-color (getf new-style-plist :fg)) changes))
;;     (unless (equal (getf current :bg) (getf new-style-plist :bg))
;;       (push (list :bg-color (getf new-style-plist :bg)) changes))
;;     (let ((cur-attrs (getf current :attrs))
;;           (new-attrs (getf new-style-plist :attrs)))
;;       (dolist (attr '(:bold :italic :underline :faint :blink :inverse :strike :invisible))
;;         (let ((had (member attr cur-attrs))
;;               (want (member attr new-attrs)))
;;           (unless (eq (not (null had)) (not (null want)))
;;             (push (list attr (not (null want))) changes)))))
;;     ;; emit in logical order
;;     (when changes
;;       (log:debug "APPLY-STYLE-DIFF: Detected changes: ~S" changes)
;;       (dolist (chg (nreverse changes))
;;         (let ((seq-val nil)
;;               (spec-val (second chg))
;;               (op-type (first chg)))
;;           (case op-type
;;             (:fg-color
;;              (setf seq-val (elmtui.backend.common.utils:ansi-fg-color-seq spec-val)))
;;             (:bg-color
;;              (setf seq-val (elmtui.backend.common.utils:ansi-bg-color-seq spec-val)))
;;             (otherwise ; Attributes
;;              (setf seq-val (elmtui.backend.common.utils:ansi-attr-seq op-type spec-val))))

;;           (log:debug "APPLY-STYLE-DIFF: Change op: ~S, Spec-val: ~S, Generated ANSI seq: ~S"
;;                      op-type spec-val seq-val)
;;           (if (stringp seq-val)
;;               (progn


;;                 (write-string seq-val stream)
;;                 (push (list op-type spec-val seq-val) generated-sequences))
;;               (when seq-val ; If non-nil but not a string, it's an error from previous log
;;                 (log:error "APPLY-STYLE-DIFF: Received non-string sequence for ~S (~S): ~S (type ~A). Not writing."
;;                            op-type spec-val seq-val (type-of seq-val))
;;                 (push (list op-type spec-val :ERROR-NON-STRING) generated-sequences))))))
;;     (log:debug "APPLY-STYLE-DIFF: Attempted to write ANSI sequences: ~S" (nreverse generated-sequences))
;;     (setf (terminal-instance-current-style instance) new-style-plist)))
;; finish-output stream))) ; finish-output removed, will be handled by apply-terminal-diff
;; (defun apply-style-diff (instance new-style-plist)
;;   "Applies style changes to the terminal. If NEW-STYLE-PLIST is NIL and current style is
;; not NIL, sends SGR 0 for a full reset. Otherwise, sends minimal SGR codes to transition
;; from current to NEW-STYLE-PLIST."
;;   (log:info "APPLY-STYLE-DIFF CALLED. Instance Current Style: ~S, Requested New Style: ~S" (terminal-instance-current-style instance)
;;             new-style-plist)
;;   (let ((current (terminal-instance-current-style instance))
;;         (stream (terminal-instance-stream instance)))

;;     (when (equal current new-style-plist) ; If styles are already identical, do nothing
;;       (log:debug "APPLY-STYLE-DIFF: Styles already identical (Current: ~S, New: ~S). No action." current new-style-plist)
;;       (return-from apply-style-diff))

;;     (log:debug "APPLY-STYLE-DIFF: Transitioning. Current style: ~S, New style: ~S" current new-style-plist)

;;     (if (and (null new-style-plist) current) ; Transitioning to full default (NIL) from a non-default state
;;         (let ((reset-seq-str (elmtui.backend.common.utils:render-seq (elmtui.backend.common.utils:get-sequence :reset))))
;;           (log:debug "APPLY-STYLE-DIFF: Full reset to default. Current: ~S, New: NIL. Sending SGR 0 (~S)."
;;                      current reset-seq-str)
;;           (write-string reset-seq-str stream)
;;           (setf (terminal-instance-current-style instance) nil)) ; Update instance state to NIL (full default)
;;         (progn ; Incremental update or setting a specific new non-NIL style
;;           (let ((changes '())
;;                 (generated-sequences '()))
;;             ;; Calculate minimal changes needed
;;             (unless (equal (getf current :fg) (getf new-style-plist :fg))
;;               (push (list :fg-color (getf new-style-plist :fg)) changes))
;;             (unless (equal (getf current :bg) (getf new-style-plist :bg))
;;               (push (list :bg-color (getf new-style-plist :bg)) changes))
;;             (let ((cur-attrs (getf current :attrs))
;;                   (new-attrs (getf new-style-plist :attrs)))
;;               (dolist (attr '(:bold :italic :underline :faint :blink :inverse :strike :invisible))
;;                 (let ((had (member attr cur-attrs))
;;                       (want (member attr new-attrs)))
;;                   (unless (eq (not (null had)) (not (null want)))
;;                     (push (list attr (not (null want))) changes)))))

;;             (if changes
;;                 (progn
;;                   (log:debug "APPLY-STYLE-DIFF: Incremental update. Current: ~S, New: ~S. Changes: ~S"
;;                              current new-style-plist changes)
;;                   (dolist (chg (nreverse changes))
;;                     (let ((seq-val nil)
;;                           (op-type (first chg))
;;                           (spec-val (second chg)))
;;                       (case op-type
;;                         (:fg-color (setf seq-val (elmtui.backend.common.utils:ansi-fg-color-seq spec-val)))
;;                         (:bg-color (setf seq-val (elmtui.backend.common.utils:ansi-bg-color-seq spec-val)))
;;                         (otherwise  (setf seq-val (elmtui.backend.common.utils:ansi-attr-seq op-type spec-val)))) ; spec-val is T/NIL for attrs

;;                       (log:debug "APPLY-STYLE-DIFF: Change op: ~S, Spec-val: ~S, Generated ANSI seq: ~S" op-type spec-val seq-val)

;;                       (if (stringp seq-val)
;;                           (progn
;;                             (write-string seq-val stream)
;;                             (push (list op-type spec-val seq-val) generated-sequences))
;;                           (when seq-val ; Log error if seq-val is non-nil but not a string
;;                             (log:error "APPLY-STYLE-DIFF: Received non-string sequence for ~S (~S): ~S (type ~A). Not writing."
;;                                        op-type spec-val seq-val (type-of seq-val))
;;                             (push (list op-type spec-val :ERROR-NON-STRING) generated-sequences))))))
;;                 (log:debug "APPLY-STYLE-DIFF: Incremental update wrote ANSI sequences: ~S" (nreverse generated-sequences)))
;;             (log:debug "APPLY-STYLE-DIFF: No effective incremental changes needed for non-NIL new-style ~S from ~S"
;;                        new-style-plist current))
;;           (setf (terminal-instance-current-style instance) new-style-plist)))))
                                        ; Update instance state
;; finish-output is handled by the caller (apply-terminal-diff)

(defun style-to-terminal-style (style-plist)
  "Convert a style plist to a terminal-style object for ANSI sequence generation."
  (when style-plist
    (let ((ts (make-terminal-style)))
      ;; Handle background color
      (let ((bg (getf style-plist :bg)))
        (when bg
          (if (and bg (listp bg)) ; RGB color format
              (setf (terminal-style-bg-color ts)
                    (elmtui.backend.common.ansi-styling:make-termcolor
                     :bg t
                     :r (first bg)
                     :g (second bg)
                     :b (third bg)))
              (if (and bg (numberp bg))
                  (setf (terminal-style-bg-color ts)
                        (elmtui.backend.common.ansi-styling:make-termcolor
                         :bg t
                         :color-256 bg))
                  (setf (terminal-style-bg-color ts)
                        (elmtui.backend.common.ansi-styling:make-termcolor
                         :bg t
                         :simple bg))))))
      
      ;; Handle foreground color
      (let ((fg (getf style-plist :fg)))
        (when fg
          (if (and fg (listp fg)) ; RGB color format
              (setf (terminal-style-fg-color ts)
                    (elmtui.backend.common.ansi-styling:make-termcolor
                     :r (first fg)
                     :g (second fg)
                     :b (third fg)))
              (if (and fg (numberp fg))
                  (setf (terminal-style-fg-color ts)
                        (elmtui.backend.common.ansi-styling:make-termcolor
                         :color-256 fg))
                  (setf (terminal-style-fg-color ts)
                        (elmtui.backend.common.ansi-styling:make-termcolor
                         :simple fg))))))

      ;; Handle text attributes
      (let ((attrs (getf style-plist :attrs)))
        (when (and attrs (member :bold attrs))
          (setf (terminal-style-bold ts) t))
        (when (member :italic attrs)
          (setf (terminal-style-italic ts) t))
        (when (member :underline attrs)
          (setf (terminal-style-underline ts) t))
        (when (member :inverse attrs)
          (setf (terminal-style-inverse ts) t)))
      ts)))

(defun write-style-to-stream (stream style)
  "Write the ANSI escape sequences for the given style to the stream.
   Uses the ansi-styling framework for consistent ANSI sequence generation."
  (when style
    (let ((ts (style-to-terminal-style style)))
      (when ts
        ;; Generate ANSI sequences for all relevant attributes
        (let ((seqs (elmtui.backend.common.ansi-styling:ansi-seqs
                     ts :fg-color :bg-color :bold :italic :underline)))
          ;; Write each sequence to the stream
          (dolist (seq seqs)
            (write-string (concatenate 'string (string (code-char 27)) seq) stream)))))))

;; (with-open-stream (stream (make-string-output-stream))
;;   (write-style-to-stream stream (list :bold t)))
;; (style-to-terminal-style (list :bold ))
;; (ansi-seqs (list :bold t))
(defun write-style-reset-to-stream (stream)
  "Write a style reset ANSI sequence to the stream."
  (write-string (concatenate 'string (string (code-char 27)) "[0m") stream))

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
                else do (log:warn "draw-text-at: Clipping character '~C' at (~A, ~A) outside buffer bounds (~Ax~A)"
                                  char row current-col buffer-w buffer-h)
                        (loop-finish)))))) ; Stop if text goes out of bounds
  t)

(defmethod draw-char-at ((instance terminal-instance) row col char &key style)
  (log:debug "BUFFER: draw-char-at - Row: ~A, Col: ~A, Char: ~C, Style: ~S" row col char style)
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (let ((buffer-w (buffer-width back-buffer))
              (buffer-h (buffer-height back-buffer)))
          (if (and (>= row 0) (< row buffer-h)
                   (>= col 0) (< col buffer-w))
              (set-buffer-cell-at back-buffer row col char style)
              (log:warn "draw-char-at: Clipping character '~C' at (~A, ~A) outside buffer bounds (~Ax~A)"
                        char row col buffer-w buffer-h))))))
  t)

(defmethod fill-rectangle ((instance terminal-instance) row col height width &key char style)
  (log:debug "BUFFER: fill-rectangle - Row: ~A, Col: ~A, H: ~A, W: ~A, Char: ~C, Style: ~S"
             row col height width char style)
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (fill-buffer-region back-buffer row col width height (or char #\Space) style))))
  t)

(defmethod draw-box-outline ((instance terminal-instance) row col height width &key style corners sides)
  (declare (ignore corners sides)) ; Simple ASCII box for now
  (log:debug "BUFFER: draw-box-outline - Row: ~A, Col: ~A, H: ~A, W: ~A, Style: ~S"
             row col height width style)
  (when (and (> width 1) (> height 1))
    (let ((back-buffer (terminal-instance-back-buffer instance)))
      (when back-buffer
        (with-virtual-buffer-lock (back-buffer)
          ;; Corners
          (draw-char-at instance row col #\+ :style style)
          (draw-char-at instance row (+ col width -1) #\+ :style style)
          (draw-char-at instance (+ row height -1) col #\+ :style style)
          (draw-char-at instance (+ row height -1) (+ col width -1) #\+ :style style)
          ;; Horizontal lines
          (loop for c from (1+ col) below (+ col width -1)
                do (draw-char-at instance row c #\- :style style)
                   (draw-char-at instance (+ row height -1) c #\- :style style))
          ;; Vertical lines
          (loop for r from (1+ row) below (+ row height -1)
                do (draw-char-at instance r col #\| :style style)
                   (draw-char-at instance r (+ col width -1) #\| :style style))))))
  t)

(defmethod set-cell-style ((instance terminal-instance) row col &key style)
  (log:debug "BUFFER: set-cell-style - Row: ~A, Col: ~A, Style: ~S" row col style)
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (let ((buffer-w (buffer-width back-buffer))
              (buffer-h (buffer-height back-buffer)))
          (if (and (>= row 0) (< row buffer-h)
                   (>= col 0) (< col buffer-w))
              (let ((current-cell (buffer-cell-at back-buffer row col)))
                (set-buffer-cell-at back-buffer row col (elmtui.platform.backend.common.virtual-buffer::buffer-cell-char current-cell) style))
              (log:warn "set-cell-style: Clipping style at (~A, ~A) outside buffer bounds (~Ax~A)"
                        row col buffer-w buffer-h))))))
  t)

(defmethod clear-area ((instance terminal-instance) row col height width &key style)
  (log:debug "BUFFER: clear-area - Row: ~A, Col: ~A, H: ~A, W: ~A, Style: ~S"
             row col height width style)
  (let ((back-buffer (terminal-instance-back-buffer instance)))
    (when back-buffer
      (with-virtual-buffer-lock (back-buffer)
        (fill-buffer-region back-buffer row col width height #\Space style))))
  t)

(defmethod draw-styled-box ((instance terminal-instance) row col height width &key border-style border-color box-char-set style)
  (declare (ignore box-char-set)) ; Not using custom char sets for now
  (log:debug "BUFFER: draw-styled-box - Pos: (~A,~A), Size: (~A,~A), Style: ~S, BorderStyle: ~S, BorderColor: ~S"
             row col height width style border-style border-color)
  (when (and (> width 1) (> height 1))
    (let* ((effective-style (if border-color
                                (list :fg border-color) ; Prioritize explicit border-color
                                (getf style :attrs))) ; Fallback to general style for attributes if any
           (chars (case border-style
                    (:single '(#\┌ #\┐ #\└ #\┘ #\─ #\│))
                    (:double '(#\╔ #\╗ #\╚ #\╝ #\═ #\║))
                    (otherwise '(#\+ #\+ #\+ #\+ #\- #\|)))) ; Default to simple ASCII
           (tl (first chars)) (tr (second chars))
           (bl (third chars)) (br (fourth chars))
           (horiz (fifth chars)) (vert (sixth chars))
           (back-buffer (terminal-instance-back-buffer instance)))

      (when back-buffer
        (with-virtual-buffer-lock (back-buffer)
          ;; Draw corners
          (draw-char-at instance row col tl :style effective-style)
          (draw-char-at instance row (+ col width -1) tr :style effective-style)
          (draw-char-at instance (+ row height -1) col bl :style effective-style)
          (draw-char-at instance (+ row height -1) (+ col width -1) br :style effective-style)

          ;; Draw horizontal lines
          (loop for c from (1+ col) below (+ col width -1)
                do (draw-char-at instance row c horiz :style effective-style)
                   (draw-char-at instance (+ row height -1) c horiz :style effective-style))

          ;; Draw vertical lines
          (loop for r from (1+ row) below (+ row height -1)
                do (draw-char-at instance r col vert :style effective-style)
                   (draw-char-at instance r (+ col width -1) vert :style effective-style))))))
  t)

;;; ---------------------------------------------------------------
;;; Color and Style Management
;;;---------------------------------------------------------------
;; Helper functions elmtui.backend.common.utils:ansi-fg-color-seq,
;; elmtui.backend.common.utils:ansi-bg-color-seq, and
;; elmtui.backend.common.utils:ansi-attr-seq are defined in and
;; used from the elmtui.backend.common.utils package.
;; The local definitions that were here were incorrect and have been removed.

(defmethod make-color ((instance terminal-instance) r-or-name &optional g b)
  (if g
      (list :rgb r-or-name g b)
      r-or-name))

(defmethod make-style ((instance terminal-instance) &key foreground-color background-color attributes)
  (list :fg (or foreground-color (default-foreground-color instance))
        :bg (or background-color (default-background-color instance))
        :attrs (copy-list attributes)))

(defmethod apply-style ((instance terminal-instance) style-plist)
  (with-terminal-lock (instance)
    (apply-style-diff instance style-plist))
  t)

(defmethod default-foreground-color ((instance terminal-instance)) :white)
(defmethod default-background-color ((instance terminal-instance)) :black)

(defmethod supports-truecolor-p ((instance terminal-instance))
  ;; This could be queried from terminfo or env vars like COLORTERM=truecolor
  t)

(defmethod max-colors ((instance terminal-instance))
  (if (supports-truecolor-p instance) (expt 2 24) 256))

;;;---------------------------------------------------------------
;;; Input Handling
;;;---------------------------------------------------------------
(defun read-char-nonblock (stream)
  (read-char-no-hang stream nil nil))

(defun parse-sgr-mouse-event (params raw-bytes final-char-code) ; Added final-char-code
  "Parses SGR mouse event parameters (e.g., from ESC [ < Cb ; Cx ; Cy ; M/m)."
  (let* ((button-code (first params))
         (col (second params))
         (row (third params))
         ;; (press-release-char (fourth params)) ; This was incorrect for SGR
         (button (logand button-code 3)) ; Low 2 bits often indicate button (0=1, 1=2, 2=3)
         (modifiers (let ((mod-code (ash button-code -2))) ; Higher bits for modifiers
                      (append (when (logbitp 0 mod-code) '(:shift))
                              (when (logbitp 1 mod-code) '(:alt)) ; Meta/Alt often same
                              (when (logbitp 2 mod-code) '(:control)))))
         (type (cond
                 ((= 35 (logand button-code 35)) :mouse-move) ; Motion often has bit 5 set
                 ((= final-char-code (char-code #\M)) :mouse-down) ; 'M'
                 ((= final-char-code (char-code #\m)) :mouse-up)   ; 'm'
                 ((>= button-code 64) ; Scroll events often start at 64
                  (if (= (logand button-code 1) 0) :scroll-up :scroll-down))
                 (t :unknown-mouse)))
         (final-button (cond ((eq type :scroll-up) :scroll-up)
                             ((eq type :scroll-down) :scroll-down)
                             ((= button 0) :left) ; Adjust button numbers
                             ((= button 1) :middle)
                             ((= button 2) :right)
                             ((= button 3) :dunno)))) ; Keep others as is
    (make-mouse-event :type type
                      :button final-button
                      :y (1- row) ; Convert to 0-based
                      :x (1- col) ; Convert to 0-based
                      :modifiers modifiers
                      :raw raw-bytes)))

(defun parse-input-bytes-to-message (bytes-vector)
  "Parses a vector of bytes into a standardized elmtui AppMsg."
  (when (zerop (length bytes-vector))
    (return-from parse-input-bytes-to-message nil))

  (let ((first-byte (aref bytes-vector 0))
        (raw (copy-seq bytes-vector))) ; Keep original bytes
    (block parser
      (handler-case
          (cond
            ;; --- ESC Sequences ---
            ((= first-byte #o33) ; ESC
             (if (> (length bytes-vector) 1)
                 (let ((introducer-char-code (aref bytes-vector 1)))
                   (cond
                     ;; CSI Introducer (ESC [)
                     ((= introducer-char-code #o133) ; '['
                      (if (> (length bytes-vector) 2)
                          (let ((csi-content-list (coerce (subseq bytes-vector 2) 'list))) ; Use list for collect-csi-params
                            (multiple-value-bind (params intermediates final-byte-code)
                                (collect-csi-params csi-content-list)
                              ;; (declare (ignore intermediates)) ; Removed ignore, as intermediates is used below
                              (cond
                                ;; SGR Mouse Event (ESC [ < Cb ; Cx ; Cy M/m)
                                ((and (member #\< intermediates) ; Check for SGR mouse intermediate '<'
                                      (or (= final-byte-code (char-code #\M))
                                          (= final-byte-code (char-code #\m))))
                                 (let ((mouse-event (parse-sgr-mouse-event params raw final-byte-code)))
                                   (return-from parser
                                     (make-mouse-event :type (mouse-event-type mouse-event)
                                                       :button (mouse-event-button mouse-event)
                                                       :y (mouse-event-y mouse-event)
                                                       :x (mouse-event-x mouse-event)
                                                       :modifiers (mouse-event-modifiers mouse-event)))))

                                ;; Other CSI sequences (likely keys)
                                (t (multiple-value-bind (key-symbol remaining)
                                       (read-escape-bytes (make-string-input-stream (map 'string #'code-char csi-content-list)) :CSI)
                                     (declare (ignore remaining))
                                     (if key-symbol
                                         (make-key-event :key key-symbol :modifiers '(:alt) :char nil) ; Assume Alt for now
                                         (make-raw-input-event :bytes raw))))))) ; Return raw if unknown CSI
                          (make-key-event :key :escape :modifiers nil :char nil))) ; Just ESC [

                     ;; SS3 Introducer (ESC O) - Often for F-keys, arrows
                     ((= introducer-char-code #o117) ; 'O'
                      (if (> (length bytes-vector) 2)
                          (multiple-value-bind (key-symbol remaining)
                              (read-escape-bytes (make-string-input-stream (map 'string #'code-char (subseq bytes-vector 2))) :SS3)
                            (declare (ignore remaining))
                            (if key-symbol
                                (make-key-event :key key-symbol :modifiers '(:alt) :char nil) ; Assume Alt
                                (make-raw-input-event :bytes raw)))
                          (make-key-event :key :escape :modifiers nil :char nil))) ; Just ESC O

                     ;; Alt + Character (ESC followed by a non-introducer)
                     (t (let ((char (code-char introducer-char-code)))
                          (make-key-event :key (intern (string-upcase (string char)) :keyword)
                                          :char char
                                          :modifiers '(:alt))))))
                 ;; Just ESC key
                 (make-key-event :key :escape :modifiers nil :char nil)))

            ;; --- Basic Control Characters ---
            ((= first-byte #o177)
             (make-key-event :key :backspace :modifiers nil :char nil)) ; DEL
            ((= first-byte #o10) (make-key-event :key :backspace
                                                 :code #o10
                                                 :type :key-down
                                                 :char (code-char first-byte)
                                                 :modifiers nil)) ; BS (Ctrl-H often maps here)
            ((= first-byte #o15) (make-key-event :key :enter
                                                 :code #o15
                                                 :type :key-down
                                                 :modifiers nil
                                                 :char (code-char first-byte))) ; CR (Ctrl-M)
            ((= first-byte #o11) (make-key-event :key :tab
                                                 :code #o11
                                                 :type :key-down
                                                 :modifiers nil
                                                 :char (code-char first-byte))) ; HT (Ctrl-I)

            ;; --- Other Ctrl Characters (C-@ to C-_) ---
            ((<= first-byte #o37)
             (let* ((base-char-code (+ first-byte 64))
                    (base-char (code-char base-char-code)))
               (make-key-event :key (intern (format nil "C-~A" base-char) :keyword)
                               :code first-byte ; Keep original control char
                               :char base-char
                               :type :key-down
                               :modifiers '(:control))))

            ;; --- Printable Characters ---
            (t (let ((char (code-char first-byte)))
                 (make-key-event :key (intern (string char) :keyword) ; Use char itself as key symbol
                                 :code first-byte
                                 :type :key-down
                                 :modifiers nil))))
        (error (e)
          (warn "Error parsing input bytes ~A: ~A. Returning raw event." bytes-vector e)
          (make-raw-input-event :bytes (coerce raw '(vector (unsigned-byte 8))))))))) ; Fallback to raw event on error

(defmethod poll-input-event ((instance terminal-instance) &key timeout)
  (let ((stream (terminal-instance-stream instance))
        (buffer (terminal-instance-input-buffer instance))
        (start-time (get-internal-real-time)))
    (with-terminal-lock (instance)
      (setf (fill-pointer buffer) 0)) ; Only lock for buffer reset

    (loop
      (let ((char (if (zerop (fill-pointer buffer)) ; Only block/timeout on first char
                      (if timeout
                          (read-char stream nil :eof (if (= timeout 0) :nonblock-peek)) ; Complex logic for timeout
                          (read-char stream nil :eof))
                      (read-char-nonblock stream))))
        (cond
          ((eq char :eof) (return nil)) ; EOF
          ((eq char :nonblock-peek) (return nil)) ; Non-blocking and nothing available
          ((null char) ; No char available (non-blocking or timed out after first char)
           (if (plusp (fill-pointer buffer))
               (return (parse-input-bytes-to-message buffer)) ; Use new function
               (if (and timeout (> timeout 0)
                        (> (/ (- (get-internal-real-time) start-time)
                              internal-time-units-per-second)
                           timeout))
                   (return nil) ; Actual timeout expired
                   ;; (sleep 0.01)
                   ))) ; Short sleep before trying again or if no timeout
          (t (with-terminal-lock (instance)
               (vector-push-extend (char-code char) buffer)))))

      ;; --- Attempt to Parse Collected Bytes ---
      (when (plusp (fill-pointer buffer))
        ;; If it looks like an escape sequence, try reading a bit more non-blockingly
        (when (= (aref buffer 0) #o33)
          (loop for i from 1 to 7 ; Read a few more chars non-blockingly
                for next-char = (read-char-nonblock stream)
                while next-char
                do (with-terminal-lock (instance)
                     (vector-push-extend (char-code next-char) buffer))))
        ;; Now parse whatever we have collected
        (return (parse-input-bytes-to-message buffer))))))

(defmethod peek-input-event ((instance terminal-instance))
  ;; Peeking is hard with raw terminal reads and escape sequences.
  ;; A simple approach might involve a small internal buffer, but
  ;; for now, this is not robustly implemented.
  (warn "peek-input-event is not reliably implemented for terminal backend.")
  nil)

(defmethod enable-mouse-support ((instance terminal-instance) &key motion-events-p)
  (with-terminal-lock (instance)
    (if motion-events-p
        (send-sequence instance :enable-mouse-any-event)
        (send-sequence instance :enable-mouse-btn-event))
    (send-sequence instance :enable-mouse-sgr-ext-mode) ; For better coordinate reporting
    (finish-output (terminal-instance-stream instance)))
  t)

(defmethod disable-mouse-support ((instance terminal-instance))
  (with-terminal-lock (instance)
    (send-sequence instance :disable-mouse-any-event)
    (send-sequence instance :disable-mouse-sgr-ext-mode)
    (finish-output (terminal-instance-stream instance)))
  t)

;; (defmethod set-input-mode ((instance terminal-instance) mode)
;;   (declare (ignore mode))
;; Raw mode is handled by initialize/shutdown. Other modes (cbreak, cooked)
;; are not explicitly managed here beyond that.
(defmethod enable-raw-mode ((fd integer))
  (let ((orig (the sb-posix:termios (sb-posix:tcgetattr fd))))

    ;; now safe to treat ORIG as a termios structure
    (let ((new (the sb-posix:termios (sb-int:sys-copy-struct orig))))
      ;; disable canonical & echo
      (setf (sb-posix:termios-lflag new)
            (logand (sb-posix:termios-lflag new)
                    (lognot sb-posix:icanon)
                    (lognot sb-posix:echo)))
      ;; nonblocking reads: VMIN=0, VTIME=1
      (setf (aref (sb-posix:termios-cc new) sb-posix:vmin)  0
            (aref (sb-posix:termios-cc new) sb-posix:vtime) 1)
      (sb-posix:tcsetattr fd sb-posix:tcsaflush new)
      orig)))
(defun force-clear-terminal-and-reset-buffers
    (instance)
  "Forces a hard clear of the terminal screen and resets internal buffers.
This is a recovery mechanism to ensure the next render cycle performs a full redraw."
  (check-type instance terminal-instance)
  (log:info "TERMINAL: Forcing clear of terminal and resetting buffers.")
  (with-terminal-lock (instance)
    ;; 1. Send direct terminal clear sequences
    (send-sequence instance :erase-in-display 2) ; CSI 2 J (Erase entire screen)
    (send-sequence instance :cursor-set-position 1 1) ; CSI H (Cursor to home)
    (send-sequence instance :reset) ; SGR 0 - Reset all graphic renditions to default
    ;; 2. Clear front-buffer with a distinct 'invalid' marker
    ;; This ensures compute-buffer-diff will see it as entirely different from the newly rendered back-buffer.
    (let ((front-buffer (terminal-instance-front-buffer instance)))
      (when front-buffer
        (with-virtual-buffer-lock (front-buffer)
          (clear-buffer front-buffer :default-char #\Nul :default-style nil)))) ; Use NUL char as a clear marker

    ;; 3. Clear back-buffer to a standard clean state (spaces, default style)
    (let ((back-buffer (terminal-instance-back-buffer instance)))
      (when back-buffer
        (with-virtual-buffer-lock (back-buffer)
          (clear-buffer back-buffer)))) ; Uses default char/style from clear-buffer

    ;; 4. Reset terminal's logical current style
    (setf (terminal-instance-current-style instance) '(:fg :white :bg :black :attrs nil)) ; Reset to a known default

    ;; 5. Ensure all commands are sent to the terminal
    (finish-output (terminal-instance-stream instance)))
  t)
(defun apply-style-diff (terminal-instance new-style)
  "Applies style difference between terminal's current style and new-style.
   Uses the ansi-styling system for consistent ANSI sequence generation."
  (log:info "APPLY-STYLE-DIFF CALLED. Instance Current Style: ~S, Requested New Style: ~S"
            (term-style terminal-instance) new-style)

  (let ((current-style (term-style terminal-instance))
        (stream (terminal-instance-stream terminal-instance)))

    ;; If styles are identical, do nothing
    (when (equal current-style new-style)
      (log:debug "APPLY-STYLE-DIFF: No change needed, styles identical")
      (return-from apply-style-diff t))
    
    (log:debug "APPLY-STYLE-DIFF: Transitioning. Current style: ~S, New style: ~S"
               current-style new-style)

    ;; Handle style reset (when new-style is NIL)
    ;; (if (null new-style)
    ;;     (progn
    ;;       (log:debug "APPLY-STYLE-DIFF: Full reset to default. Current: ~S, New: NIL"
    ;;                  current-style)
    ;;       ;; Use our direct reset function
    ;;       (write-style-reset-to-stream stream)
    ;;       (setf (term-style terminal-instance) nil))

    ;; Handle applying a new style
    (log-info "APPLY-STYLE-DIFF: Applying new style: ~S" new-style)
    (let* ((new-style-ts (if new-style (style-to-terminal-style new-style)
                             (make-terminal-style)))
           (styles-to-upgrade
             (update-style! current-style new-style-ts)))
      (setf current-style (copy-term-style current-style))
      (dolist (s (ansi-seqs styles-to-upgrade))
        (log:debug "APPLY-STYLE-DIFF: Writing ANSI sequence: ~S" s)
        (exec-sequence
         (terminal-instance-lock terminal-instance)
         (terminal-instance-fd terminal-instance) s))
      ;; Reset first if needed
      ;; (when current-style
      ;;   (write-style-reset-to-stream stream))
      ;;
      ;; Use our ansi-styling integration to apply the new style
      ;; (write-style-to-stream stream new-style)

      ;; Update the terminal's current style
      (setf (term-style terminal-instance) current-style))

    ;; Ensure changes are visible
    (finish-output stream)
    t))

;; (defun apply-canvas-to-buffer
;;     (canvas buffer)
;;   "Applies the canvas to the buffer, ensuring the buffer is updated with the canvas content."
;;   (declare (ignore canvas))
;;   (let ((back-buffer (terminal-instance-back-buffer buffer)))
;;     (when back-buffer
;;       (with-virtual-buffer-lock (back-buffer)
;;         (let ((buffer-w (buffer-width back-buffer))
;;               (buffer-h (buffer-height back-buffer)))
;;           (loop for row from 0 below buffer-h
;;                 do (loop for col from 0 below buffer-w
;;                          do (set-buffer-cell-at back-buffer row col #\Space nil)))))) ; Clear the buffer
;;         ))
