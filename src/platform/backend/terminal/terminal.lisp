;;;===============================================================
;;; File: src/platform/backend/terminal/terminal.lisp
;;; Standard Terminal Backend
;;;
;;; This backend interacts with a standard Unix-like terminal
;;; using raw mode for input and ANSI escape codes for output.
;;;===============================================================

(uiop:define-package :elmtui.backend.terminal
  (:use :cl :elmtui.platform.api :elmtui.backend.common.utils)
  (:import-from #:sb-posix
                #:tcgetattr #:tcsetattr #:termios #:termios-lflag #:termios-cc
                #:icanon #:echo #:vmin #:vtime #:tcsanow #:tcsaflush)
  (:import-from #:sb-unix
                #:unix-open #:unix-close #:unix-read #:unix-write #:o_rdwr)
  (:import-from #:sb-sys ; Removed #:io-stream-p
                #:fd-stream-fd #:make-fd-stream)
  (:import-from #:elmtui.core.input-events ; Event structs for intermediate parsing
                #:key-event-key #:key-event-char #:key-event-modifiers
                #:mouse-event-type #:mouse-event-button #:mouse-event-row #:mouse-event-col #:mouse-event-modifiers
                #:make-mouse-event     ; For creating mouse event objects
                #:make-key-event)      ; For creating key event objects
  ;; Note: Raw events are not mapped to messages, they are returned directly if parsing fails
  (:import-from #:elmtui.core.input-events #:make-raw-input-event)
  (:import-from #:elmtui.platform.api #:term-w #:term-h #:term-style #:term-stream)
  (:export #:terminal-instance
           #:initialize-backend ; Re-exporting for discoverability
           #:shutdown-backend
           #:backend-name
           #:backend-version))

(in-package :elmtui.backend.terminal)

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
  (lock (bt:make-recursive-lock "terminal-io-lock")))
(defmethod term-w((instance terminal-instance))
  "Return the width of the terminal instance."
  (terminal-instance-width instance))

(defmethod term-h((instance terminal-instance))
  "Return the height of the terminal instance."
  (terminal-instance-height instance))
(defmethod (setf term-h) ((instance terminal-instance) new-height)
  "Set the height of the terminal instance."
  (setf (terminal-instance-height instance) new-height))
(defmethod (setf term-w) ((instance terminal-instance) new-width)
  "Set the width of the terminal instance."
  (setf (terminal-instance-width instance) new-width))
"Return the current style of the terminal instance."
(defmethod term-style ((instance terminal-instance))
  (terminal-instance-current-style instance))
(defmethod term-stream ((instance terminal-instance))
  "Return the stream of the terminal instance."
  (terminal-instance-stream instance))

(defmacro with-terminal-lock ((instance) &body body)
  `(bt:with-recursive-lock-held ((terminal-instance-lock ,instance))
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

;;; ——— 1) enable-raw-mode: guard + VMIN/VTIME like the original spec ———
;; (defmethod enable-raw-mode ((fd integer))
;;   (let ((orig (sb-posix:tcgetattr fd)))
;;     (unless orig
;;       (error "sb-posix:tcgetattr failed on fd ~A" fd))
;;     (let ((new (copy-structure orig)))
;;       ;; disable canonical & echo
;;       (setf (sb-posix:termios-lflag new)
;;             (logand (sb-posix:termios-lflag new)
;;                     (lognot sb-posix:icanon)
;;                     (lognot sb-posix:echo)))
;;       ;; nonblocking read: VMIN=0, VTIME=1 (0.1s)
;;       (setf (aref (sb-posix:termios-cc new) sb-posix:vmin)  0
;;             (aref (sb-posix:termios-cc new) sb-posix:vtime) 1)
;;       (sb-posix:tcsetattr fd sb-posix:tcsanow new)
;;       orig)))
                                        ; return original

;;; ——— 2) initialize-backend: actually send escape sequences ———
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
              (terminal-instance-height instance) h))
      ;; now actually hide cursor & switch to alt buffer
      (send-sequence instance :cursor-hide)
      ;(send-sequence instance :alt-screen-buffer)
      (clear-screen instance)
      (flush-output instance)
      instance)))

;;;---------------------------------------------------------------
;;; Display & Screen Management
;;;---------------------------------------------------------------
(defun send-sequence (instance seq-id &rest args)
  (let ((seq-obj (get-sequence seq-id)))
    (when seq-obj
      (let ((rendered (apply #'render-seq seq-obj args)))
        (write-string rendered (terminal-instance-stream instance))))))

(defmethod get-screen-dimensions ((instance terminal-instance))
  (with-terminal-lock (instance)
    (send-sequence instance :cursor-save)
    (send-sequence instance :cursor-set-position 999 999) ; Move to an extreme corner
    (send-sequence instance :cursor-report)
    (finish-output (terminal-instance-stream instance))

    ;; Read response for cursor report: ESC [ <row> ; <col> R
    (let ((response-chars '()))
      (loop for i from 1 to 10 ; Limit read attempts
            for char = (read-char (terminal-instance-stream instance) nil nil)
            while char
            do (push char response-chars)
            when (char= char #\R) do (return)
              finally (warn "Timeout or incomplete cursor report response."))
      (send-sequence instance :cursor-restore)
      (finish-output (terminal-instance-stream instance))

      (let* ((str (coerce (nreverse response-chars) 'string))
             (parts (uiop:split-string (subseq str 2 (1- (length str))) :separator '(#\;))))
        (if (= (length parts) 2)
            (values (parse-integer (second parts)) (parse-integer (first parts))) ; typically col;row
            (values (terminal-instance-width instance) (terminal-instance-height instance))))))) ; fallback

(defmethod clear-screen ((instance terminal-instance))
  (with-terminal-lock (instance)
    (send-sequence instance :erase-screen)
    (send-sequence instance :cursor-set-position 0 0))
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
(defun apply-style-diff (instance new-style-plist)
  "Only emit the minimal SGR codes to transition from current to NEW-STYLE-PLIST."
  (let ((current (terminal-instance-current-style instance))
        (stream  (terminal-instance-stream instance))
        (changes '()))
    ;; figure out what changed
    (unless (equal (getf current :fg) (getf new-style-plist :fg))
      (push (list :fg-color (getf new-style-plist :fg)) changes))
    (unless (equal (getf current :bg) (getf new-style-plist :bg))
      (push (list :bg-color (getf new-style-plist :bg)) changes))
    (let ((cur-attrs (getf current :attrs))
          (new-attrs (getf new-style-plist :attrs)))
      (dolist (attr '(:bold :italic :underline :faint :blink :inverse :strike :invisible))
        (let ((had (member attr cur-attrs))
              (want (member attr new-attrs)))
          (unless (eq (not (null had)) (not (null want)))
            (push (list attr (not (null want))) changes)))))
    ;; emit in logical order
    (when changes
      (dolist (chg (nreverse changes))
        (case (first chg)
          (:fg-color
           (write-string
            (elmtui.backend.common.utils:ansi-fg-color-seq (second chg))
            stream))
          (:bg-color
           (write-string
            (elmtui.backend.common.utils:ansi-bg-color-seq (second chg))
            stream))
          (otherwise
           (write-string
            (elmtui.backend.common.utils:ansi-attr-seq (first chg) (second chg))
            stream))))
      (setf (terminal-instance-current-style instance) new-style-plist)
      (finish-output stream))))

(defmethod draw-text-at ((instance terminal-instance) row col text &key style)
  (with-terminal-lock (instance)
    (set-cursor-position instance row col)
    (when style (apply-style-diff instance style))
    (write-string text (terminal-instance-stream instance)))
  t)

(defmethod draw-char-at ((instance terminal-instance) row col char &key style)
  (with-terminal-lock (instance)
    (set-cursor-position instance row col)
    (when style (apply-style-diff instance style))
    (write-char char (terminal-instance-stream instance)))
  t)

;; Other drawing primitives (fill-rectangle, draw-box-outline, etc.) would also use send-sequence
;; and manage style application. For brevity, they are stubbed here.

(defmethod fill-rectangle ((instance terminal-instance) row col height width &key char style)
  (with-terminal-lock (instance)
    (when style (apply-style-diff instance style))
    (let ((fill-char (or char #\Space)))
      (loop repeat height
            for r from row
            do (set-cursor-position instance r col)
               (loop repeat width
                     do (write-char fill-char (terminal-instance-stream instance))))))
  t)

(defmethod draw-box-outline ((instance terminal-instance) row col height width &key style corners sides)
  (declare (ignore corners sides)) ; Basic implementation
  (with-terminal-lock (instance)
    (when style (apply-style-diff instance style))
    ;; Top line
    (set-cursor-position instance row col)
    (write-char #\+ (terminal-instance-stream instance))
    (loop repeat (- width 2) do (write-char #\- (terminal-instance-stream instance)))
    (write-char #\+ (terminal-instance-stream instance))
    ;; Sides
    (loop for r from (1+ row) below (+ row height -1)
          do (set-cursor-position instance r col)
             (write-char #\| (terminal-instance-stream instance))
             (set-cursor-position instance r (+ col width -1))
             (write-char #\| (terminal-instance-stream instance)))
    ;; Bottom line
    (set-cursor-position instance (+ row height -1) col)
    (write-char #\+ (terminal-instance-stream instance))
    (loop repeat (- width 2) do (write-char #\- (terminal-instance-stream instance)))
    (write-char #\+ (terminal-instance-stream instance)))
  t)


(defmethod set-cell-style ((instance terminal-instance) row col &key style)
  ;; This is tricky without knowing the char. Typically, you'd redraw the char with new style.
  ;; For a simple backend, we might just set current style and assume next draw uses it.
  (with-terminal-lock (instance)
    (set-cursor-position instance row col)
    (when style (apply-style-diff instance style)))
  t)

(defmethod clear-area ((instance terminal-instance) row col height width &key style)
  (with-terminal-lock (instance)
    (let ((effective-style (or style `(:fg ,(default-foreground-color instance) :bg ,(default-background-color instance) :attrs nil))))
      (apply-style-diff instance effective-style)
      (loop for r from row below (+ row height)
            do (set-cursor-position instance r col)
               (loop repeat width do (write-char #\Space (terminal-instance-stream instance))))))
  t)

;;;---------------------------------------------------------------
;;; Color and Style Management
;;;---------------------------------------------------------------
;; Helper to convert platform API color/style to SGR sequences
(defun elmtui.backend.common.utils:ansi-fg-color-seq (color-spec)
  (cond ((keywordp color-spec) (get-sequence (find-symbol (format nil "FG-~A" color-spec) :keyword)))
        ((and (listp color-spec) (eq (first color-spec) :rgb))
         (get-sequence :fg-color-24bit)) ; Args will be r g b
        ((and (listp color-spec) (eq (first color-spec) :xterm))
         (get-sequence :fg-color-256)) ; Arg will be color index
        (t (get-sequence :fg-default))))

(defun elmtui.backend.common.utils:ansi-bg-color-seq (color-spec)
  (cond ((keywordp color-spec) (get-sequence (find-symbol (format nil "BG-~A" color-spec) :keyword)))
        ((and (listp color-spec) (eq (first color-spec) :rgb))
         (get-sequence :bg-color-24bit))
        ((and (listp color-spec) (eq (first color-spec) :xterm))
         (get-sequence :bg-color-256))
        (t (get-sequence :bg-default))))

(defun elmtui.backend.common.utils:ansi-attr-seq (attr-keyword activep)
  (get-sequence (find-symbol (format nil "~A~A" attr-keyword (if activep "" "-OFF")) :keyword)))


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
         (final-button (cond ((eq type :scroll-up) 4)
                             ((eq type :scroll-down) 5)
                             ((= button 0) 1) ; Adjust button numbers
                             ((= button 1) 2)
                             ((= button 2) 3)
                             (t button)))) ; Keep others as is
    (make-mouse-event :type type
                      :button final-button
                      :row (1- row) ; Convert to 0-based
                      :col (1- col) ; Convert to 0-based
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
                                                       :row (mouse-event-row mouse-event)
                                                       :col (mouse-event-col mouse-event)
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
            ((= first-byte #o177) (make-key-event :key :backspace :modifiers nil :char nil)) ; DEL
            ((= first-byte #o10) (make-key-event :key :backspace :modifiers nil :char nil)) ; BS (Ctrl-H often maps here)
            ((= first-byte #o15) (make-key-event :key :enter :modifiers nil :char (code-char first-byte))) ; CR (Ctrl-M)
            ((= first-byte #o11) (make-key-event :key :tab :modifiers nil :char (code-char first-byte))) ; HT (Ctrl-I)

            ;; --- Other Ctrl Characters (C-@ to C-_) ---
            ((<= first-byte #o37)
             (let* ((base-char-code (+ first-byte 64))
                    (base-char (code-char base-char-code)))
               (make-key-event :key (intern (format nil "C-~A" base-char) :keyword)
                               :char (code-char first-byte) ; Keep original control char
                               :modifiers '(:control))))

            ;; --- Printable Characters ---
            (t (let ((char (code-char first-byte)))
                 (make-key-event :key (intern (string char) :keyword) ; Use char itself as key symbol
                                 :char char
                                 :modifiers nil))))
        (error (e)
          (warn "Error parsing input bytes ~A: ~A. Returning raw event." bytes-vector e)
          (make-raw-input-event :bytes (coerce raw '(vector (unsigned-byte 8))))))))) ; Fallback to raw event on error


(defmethod poll-input-event ((instance terminal-instance) &key timeout)
  (with-terminal-lock (instance)
    (let ((stream (terminal-instance-stream instance))
          (buffer (terminal-instance-input-buffer instance))
          (start-time (get-internal-real-time)))
      (setf (fill-pointer buffer) 0) ; Clear buffer

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
                     (sleep 0.01)))) ; Short sleep before trying again or if no timeout
            (t (vector-push-extend (char-code char) buffer))))

        ;; --- Attempt to Parse Collected Bytes ---
        (when (plusp (fill-pointer buffer))
          ;; If it looks like an escape sequence, try reading a bit more non-blockingly
          (when (= (aref buffer 0) #o33)
            (loop for i from 1 to 7 ; Read a few more chars non-blockingly
                  for next-char = (read-char-nonblock stream)
                  while next-char
                  do (vector-push-extend (char-code next-char) buffer)))
          ;; Now parse whatever we have collected
          (return (parse-input-bytes-to-message buffer))))))) ; Use new function


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
;;; ——— 4) shutdown-backend: restore screen, cursor & reset ———
;; (defmethod shutdown-backend ((instance terminal-instance))
;;   (with-terminal-lock (instance)
;;     ;; back to normal buffer, show cursor, reset all
;;     (send-sequence instance :normal-screen-buffer)
;;     (send-sequence instance :cursor-show)
;;     (send-sequence instance :reset)
;;     (flush-output instance)
;;     (disable-raw-mode (terminal-instance-fd instance)
;;                       (terminal-instance-original-termios instance))
;;     ;; close streams/fds
;;     (when (terminal-instance-stream instance)
;;       (close (terminal-instance-stream instance))
;;       (setf (terminal-instance-stream instance) nil))
;;     (when (>= (terminal-instance-fd instance) 0)
;;       (unix-close (terminal-instance-fd instance))
;;       (setf (terminal-instance-fd instance) -1)))
;;   t)
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
(defmethod shutdown-backend ((instance elmtui.backend.terminal:terminal-instance))
  (with-terminal-lock (instance)
    (send-sequence instance :normal-screen-buffer)
    (send-sequence instance :cursor-show)
    (send-sequence instance :reset)
    (flush-output instance)
    (disable-raw-mode (terminal-instance-fd instance)
                      (terminal-instance-original-termios instance))
    (when (terminal-instance-stream instance)
      (close (terminal-instance-stream instance))
      (setf (terminal-instance-stream instance) nil))
    (when (>= (terminal-instance-fd instance) 0)
      (unix-close (terminal-instance-fd instance))
      (setf (terminal-instance-fd instance) -1)))
  t)
