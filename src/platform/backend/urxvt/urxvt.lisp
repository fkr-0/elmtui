;;;===============================================================
;;; File: src/platform/backend/urxvt/urxvt.lisp
;;; URxvt Terminal Backend
;;;
;;; This backend manages a URxvt terminal instance, spawning it
;;; as a child process and communicating via a pseudo-terminal (pty).
;;;===============================================================

(uiop:define-package :elmtui.backend.urxvt
  (:use :cl :elmtui.platform.api :elmtui.backend.common.utils)
  (:import-from #:elmtui.platform.backend.terminal ; For reusing raw mode, etc.
                #:enable-raw-mode #:disable-raw-mode #:send-sequence #:apply-style-diff
                #:read-char-nonblock) ; Removed parse-input-bytes import
  (:import-from #:sb-posix
                #:tcgetattr #:tcsetattr #:termios #:termios-lflag #:termios-cc
                #:icanon #:echo #:vmin #:vtime #:tcsanow #:tcsaflush
                #:fcntl #:f-setfd) ; Removed o_nonblock and f_getfd, will use sb-posix::
  (:import-from #:sb-unix
                #:unix-open #:unix-close #:unix-read #:unix-write #:o_rdwr #:o_noctty)
  (:import-from #:sb-ext #:run-program  #:process-pid #:process-pty #:process-kill)
  (:import-from #:sb-sys #:make-fd-stream #:fd-stream-fd)
  (:import-from #:elmtui.core.event-types ; Event structs for intermediate parsing
                #:key-event-key #:key-event-char #:key-event-modifiers
                #:mouse-event-type #:mouse-event-button #:mouse-event-y #:mouse-event-x #:mouse-event-modifiers
                #:make-mouse-event     ; For creating mouse event objects
                #:make-key-event)      ; For creating key event objects
  ;; Note: Raw events are not mapped to messages, they are returned directly if parsing fails
  (:import-from #:elmtui.core.event-types #:make-raw-input-event)
  (:shadowing-import-from #:elmtui.backend.common.utils #:render-seq) ; Ensure we use our common one
  (:export #:urxvt-instance
           #:initialize-backend
           #:shutdown-backend
           #:backend-name
           #:backend-version))

(in-package :elmtui.backend.urxvt)

;;;---------------------------------------------------------------
;;; PTY Management Utilities (adapted from lowterm/urxvt.lisp)
;;;---------------------------------------------------------------
(sb-alien:define-alien-routine "ptsname" sb-alien:c-string (fd sb-alien:int))
(sb-alien:define-alien-routine "grantpt" sb-alien:int (fd sb-alien:int))
(sb-alien:define-alien-routine "unlockpt" sb-alien:int (fd sb-alien:int))

(defun find-pty ()
  "Attempts to open a new pseudo-terminal master and returns (VALUES MASTER-FD SLAVE-FD SLAVE-NAME)."
  (let ((master-fd (unix-open "/dev/ptmx" (logior o_rdwr o_noctty) 0)))
    (when (and master-fd (>= master-fd 0))
      (when (zerop (grantpt master-fd))
        (when (zerop (unlockpt master-fd))
          (let* ((slave-name (ptsname master-fd))
                 (slave-fd (unix-open slave-name (logior o_rdwr o_noctty) 0)))
            (if (and slave-fd (>= slave-fd 0))
                (return-from find-pty (values master-fd slave-fd slave-name))
                (progn (unix-close master-fd)
                       (error "Could not open PTY slave: ~A" slave-name))))))
      (when (and master-fd (>= master-fd 0)) (unix-close master-fd))
      (error "Could not grantpt/unlockpt on PTY master.")))
  (error "Could not open /dev/ptmx."))

(defstruct urxvt-instance
  (master-fd -1 :type integer)
  (slave-fd -1 :type integer)
  (pty-name nil :type (or null string))
  (u-process nil :type (or null t))
  (stream nil :type (or null stream))
  (original-termios nil :type (or null termios))
  (width 80 :type integer)
  (height 24 :type integer)
  (cursor-visible-p t :type boolean)
  (cursor-row 0 :type integer)
  (cursor-col 0 :type integer)
  (current-style '(:fg :white :bg :black :attrs nil))
  (input-buffer (make-array 0 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0))
  (lock (bt:make-recursive-lock "urxvt-io-lock")))

(defmacro with-urxvt-lock ((instance) &body body)
  `(bt:with-recursive-lock-held ((urxvt-instance-lock ,instance))
     ,@body))

;;;---------------------------------------------------------------
;;; Backend Lifecycle
;;;---------------------------------------------------------------
(defmethod initialize-backend ((backend-type (eql :urxvt))
                               &key (urxvt-program "/usr/bin/urxvt")
                                 (urxvt-args '("-name" "elmtui-urxvt" "-fn" "xft:monospace:size=12"))
                               &allow-other-keys)
  (multiple-value-bind (master-fd slave-fd pty-name) (find-pty)
    (handler-case
        (let* ((process (run-program urxvt-program
                                     (append urxvt-args (list "-pty-fd" (format nil "~A" slave-fd)))
                                     :search t :wait nil :input nil :output nil :error :output
                                     ;; :preserve-fds (list slave-fd) ; SBCL specific, might not be needed if urxvt handles -pty-fd correctly
                                     ))
               (stream (make-fd-stream master-fd :input t :output t :element-type 'character :buffering :none))
               (original-termios (enable-raw-mode master-fd)) ; Set raw mode on our end of PTY
               (instance (make-urxvt-instance :master-fd master-fd
                                              :slave-fd slave-fd ; Keep for potential cleanup
                                              :pty-name pty-name
                                              :u-process process
                                              :stream stream
                                              :original-termios original-termios)))
          ;; Set non-blocking on master PTY for reads
          (fcntl master-fd sb-posix::f-setfd (fcntl master-fd sb-posix::f-getfd 0)) ; Clear O_NONBLOCK if set by run-program
          (fcntl master-fd sb-posix::f-setfd (logior
                                              (fcntl master-fd sb-posix::f-getfd 0)
                                              sb-posix::o-nonblock))
          (sleep 0.5) ; Give URxvt a moment to start up

          (multiple-value-bind (w h) (get-screen-dimensions instance)
            (setf (urxvt-instance-width instance) w
                  (urxvt-instance-height instance) h))
          (elmtui.backend.common.utils:render-seq (get-sequence :cursor-hide))
          (elmtui.backend.common.utils:render-seq (get-sequence :alt-screen-buffer))
          (clear-screen instance)
          (flush-output instance)
          instance)
      (error (c)
        (when (and master-fd (>= master-fd 0)) (unix-close master-fd))
        (when (and slave-fd (>= slave-fd 0)) (unix-close slave-fd))
        (error "Failed to initialize URxvt backend: ~A" c)))))

(defmethod shutdown-backend ((instance urxvt-instance))
  (with-urxvt-lock (instance)
    (handler-case
        (progn
          (when (urxvt-instance-stream instance)
            (elmtui.backend.common.utils:render-seq (get-sequence :normal-screen-buffer))
            (elmtui.backend.common.utils:render-seq (get-sequence :cursor-show))
            (elmtui.backend.common.utils:render-seq (get-sequence :reset))
            (finish-output (urxvt-instance-stream instance)))

          (when (and (urxvt-instance-master-fd instance) (>= (urxvt-instance-master-fd instance) 0))
            (disable-raw-mode (urxvt-instance-master-fd instance) (urxvt-instance-original-termios instance)))

          (when (urxvt-instance-stream instance)
            (close (urxvt-instance-stream instance))
            (setf (urxvt-instance-stream instance) nil))

          (when (and (urxvt-instance-master-fd instance) (>= (urxvt-instance-master-fd instance) 0))
            (unix-close (urxvt-instance-master-fd instance))
            (setf (urxvt-instance-master-fd instance) -1))

          (when (and (urxvt-instance-slave-fd instance) (>= (urxvt-instance-slave-fd instance) 0))
            ;; Slave FD is typically managed by the PTY system and URxvt,
            ;; closing master should be enough. Explicit close might error if URxvt already closed it.
            ;; (unix-close (urxvt-instance-slave-fd instance))
            (setf (urxvt-instance-slave-fd instance) -1))

          (when (urxvt-instance-u-process instance)
            (ignore-errors (process-kill (urxvt-instance-u-process instance) 15)) ; SIGTERM
            (sleep 0.1)
            (ignore-errors (process-kill (urxvt-instance-u-process instance) 9))  ; SIGKILL
            (setf (urxvt-instance-u-process instance) nil)))
      (error (c)
        (warn "Error during URxvt backend shutdown: ~A" c))))
  t)

(defmethod backend-name ((instance urxvt-instance)) "URxvtTerminal")
(defmethod backend-version ((instance urxvt-instance)) "0.1.0")

;;;---------------------------------------------------------------
;;; Display & Screen Management (largely delegates to terminal-like behavior)
;;;---------------------------------------------------------------
(defmethod get-screen-dimensions ((instance urxvt-instance))
  (with-urxvt-lock (instance)
    (send-sequence instance :cursor-save)
    (send-sequence instance :cursor-set-position 999 999)
    (send-sequence instance :cursor-report)
    (finish-output (urxvt-instance-stream instance))
    (sleep 0.1) ; Give time for response

    (let ((response-chars '()))
      (loop for i from 1 to 20 ; Increased limit for PTY latency
            for char = (read-char-nonblock (urxvt-instance-stream instance))
            while char
            do (push char response-chars)
            when (char= char #\R) do (return)
              finally (warn "Timeout or incomplete cursor report for URxvt."))
      (send-sequence instance :cursor-restore)
      (finish-output (urxvt-instance-stream instance))

      (let* ((str (coerce (nreverse response-chars) 'string)))
        (if (and (> (length str) 2) (char= (char str 0) #\Esc) (char= (char str 1) #\[))
            (let ((parts (uiop:split-string (subseq str 2 (1- (length str))) :separator '(#\;))))
              (if (= (length parts) 2)
                  (values (parse-integer (second parts)) (parse-integer (first parts)))
                  (values (urxvt-instance-width instance) (urxvt-instance-height instance))))
            (values (urxvt-instance-width instance) (urxvt-instance-height instance)))))))

(defmethod clear-screen ((instance urxvt-instance))
  (with-urxvt-lock (instance)
    (send-sequence instance :erase-screen)
    (send-sequence instance :cursor-set-position 0 0))
  t)

(defmethod flush-output ((instance urxvt-instance))
  (with-urxvt-lock (instance) (finish-output (urxvt-instance-stream instance))) t)

(defmethod set-cursor-visibility ((instance urxvt-instance) visible-p)
  (with-urxvt-lock (instance)
    (setf (urxvt-instance-cursor-visible-p instance) visible-p)
    (if visible-p (send-sequence instance :cursor-show) (send-sequence instance :cursor-hide)))
  t)

(defmethod set-cursor-position ((instance urxvt-instance) row col)
  (with-urxvt-lock (instance)
    (setf (urxvt-instance-cursor-row instance) row)
    (setf (urxvt-instance-cursor-col instance) col)
    (send-sequence instance :cursor-set-position (1+ row) (1+ col)))
  t)

(defmethod get-cursor-position ((instance urxvt-instance))
  (values (urxvt-instance-cursor-row instance) (urxvt-instance-cursor-col instance)))

(defmethod hide-cursor ((instance urxvt-instance)) (set-cursor-visibility instance nil))
(defmethod show-cursor ((instance urxvt-instance)) (set-cursor-visibility instance t))

;;;---------------------------------------------------------------
;;; Drawing Primitives (delegates to terminal-like behavior)
;;;---------------------------------------------------------------
(defmethod draw-text-at ((instance urxvt-instance) target-buffer  row col text &key style)
  (with-urxvt-lock (instance)
    (set-cursor-position instance row col)
    (when style (apply-style-diff instance style))
    (write-string text (urxvt-instance-stream instance)))
  t)

(defmethod draw-char-at ((instance urxvt-instance) target-buffer row col char &key style)
  (with-urxvt-lock (instance)
    (set-cursor-position instance row col)
    (when style (apply-style-diff instance style))
    (write-char char (urxvt-instance-stream instance)))
  t)

(defmethod fill-rectangle ((instance urxvt-instance) target-buffer row col height width &key char style)
  (with-urxvt-lock (instance)
    (when style (apply-style-diff instance style))
    (let ((fill-char (or char #\Space)))
      (loop repeat height for r from row do
        (set-cursor-position instance r col)
        (loop repeat width do (write-char fill-char (urxvt-instance-stream instance))))))
  t)

(defmethod draw-box-outline ((instance urxvt-instance) target-buffer row col height width &key style corners sides)
  (declare (ignore corners sides)) ; Basic implementation
  (with-urxvt-lock (instance)
    (when style (apply-style-diff instance style))
    (set-cursor-position instance row col) (write-char #\+ (urxvt-instance-stream instance))
    (loop repeat (- width 2) do (write-char #\- (urxvt-instance-stream instance))) (write-char #\+ (urxvt-instance-stream instance))
    (loop for r from (1+ row) below (+ row height -1) do
      (set-cursor-position instance r col) (write-char #\| (urxvt-instance-stream instance))
      (set-cursor-position instance r (+ col width -1)) (write-char #\| (urxvt-instance-stream instance)))
    (set-cursor-position instance (+ row height -1) col) (write-char #\+ (urxvt-instance-stream instance))
    (loop repeat (- width 2) do (write-char #\- (urxvt-instance-stream instance))) (write-char #\+ (urxvt-instance-stream instance)))
  t)

(defmethod set-cell-style ((instance urxvt-instance)  target-buffer row col &key style)
  (with-urxvt-lock (instance)
    (set-cursor-position instance row col)
    (when style (apply-style-diff instance style)))
  t)

(defmethod clear-area ((instance urxvt-instance) target-buffer row col height width &key style)
  (with-urxvt-lock (instance)
    (let ((effective-style (or style `(:fg ,(default-foreground-color instance) :bg ,(default-background-color instance) :attrs nil))))
      (apply-style-diff instance effective-style)
      (loop for r from row below (+ row height) do
        (set-cursor-position instance r col)
        (loop repeat width do (write-char #\Space (urxvt-instance-stream instance))))))
  t)

;;;---------------------------------------------------------------
;;; Color and Style Management (delegates)
;;;---------------------------------------------------------------
(defmethod make-color ((instance urxvt-instance) r-or-name &optional g b)
  (if g (list :rgb r-or-name g b) r-or-name))

(defmethod make-style ((instance urxvt-instance) &key foreground-color background-color attributes)
  (list :fg (or foreground-color (default-foreground-color instance))
        :bg (or background-color (default-background-color instance))
        :attrs (copy-list attributes)))

(defmethod apply-style ((instance urxvt-instance) style-plist)
  (with-urxvt-lock (instance) (apply-style-diff instance style-plist)) t)

(defmethod default-foreground-color ((instance urxvt-instance)) :white)
(defmethod default-background-color ((instance urxvt-instance)) :black)
(defmethod supports-truecolor-p ((instance urxvt-instance)) t)
(defmethod max-colors ((instance urxvt-instance)) (expt 2 24))

;;;---------------------------------------------------------------
;;; Input Handling (delegates to terminal-like behavior)
;;;---------------------------------------------------------------

;;;---------------------------------------------------------------
;;; Input Handling (SGR mouse + robust CSI parsing)
;;;---------------------------------------------------------------

(defun parse-sgr-mouse-event (params raw-bytes final-char-code)
  "Parses SGR mouse event parameters (ESC [ < Cb ; Cx ; Cy M/m)."
  (let* ((button-code     (first  params))
         (col             (second params))
         (row             (third  params))
         (button          (logand button-code 3))
         (mod-code        (ash button-code -2))
         (modifiers       (append (when (logbitp 0 mod-code) '(:shift))
                                  (when (logbitp 1 mod-code) '(:alt))
                                  (when (logbitp 2 mod-code) '(:control)))) ; End of modifiers value
         (type            (cond
                            ((logbitp 5 button-code)                     :mouse-move)  ; bit 5 = motion
                            ((= final-char-code (char-code #\M))         :mouse-down)
                            ((= final-char-code (char-code #\m))         :mouse-up)
                            ((>= button-code 64)                         ; scroll events
                             (if (evenp (logand button-code 1)) :scroll-up :scroll-down))
                            (t                                            :unknown-mouse)))
         (final-button    (case type
                            (:scroll-up   :scroll-up)
                            (:scroll-down :scroll-down)
                            (otherwise    (if (= (1+ button) 1)
                                              :left :dunno-2)))))                 ; shift 0→1,1→2,2→3
    (make-mouse-event
     :type      type
     :button    final-button
     :y       (1- row)    ; to 0-based
     :x       (1- col)
     :modifiers modifiers
     :raw       raw-bytes)))

(defun parse-input-bytes-to-message (bytes-vector)
  "Parses BYTES-VECTOR into an ElmtUI AppMsg; handles ESC/[ CSI, SS3, control, and printable."
  (when (zerop (length bytes-vector))
    (return-from parse-input-bytes-to-message nil))
  (let ((first-byte (aref bytes-vector 0))
        (raw        (copy-seq bytes-vector)))
    (handler-case
        (cond
          ;; ESC sequences
          ((= first-byte (char-code #\e)) ; Use char-code
           (if (> (length bytes-vector) 1)
               (let ((intro (aref bytes-vector 1))) ; intro is a byte (char-code)
                 (cond
                   ((= intro (char-code #\[)) ;; CSI
                    (multiple-value-bind (params intermediates final-byte)
                        (collect-csi-params (coerce (subseq bytes-vector 2) 'list))
                      (if (and (member #\< intermediates)
                               (member final-byte (list (char-code #\M) (char-code #\m))))
                          ;; SGR mouse
                          (let ((me (parse-sgr-mouse-event params raw final-byte)))
                            (make-mouse-event
                             :type      (mouse-event-type me)
                             :button    (mouse-event-button me)
                             :y       (mouse-event-y me)
                             :x       (mouse-event-x me)
                             :modifiers (mouse-event-modifiers me)))
                          ;; fallback to key CSI
                          (multiple-value-bind (keysym _)
                              (read-escape-bytes (make-string-input-stream (coerce params 'string)) :CSI)
                            (declare (ignore _)) ; Ignore unused variable
                            (if keysym
                                (make-key-event :key keysym :modifiers '(:alt) :char nil)
                                (make-raw-input-event :bytes raw))))))

                   ((= intro (char-code #\O)) ;; SS3
                    (multiple-value-bind (keysym _)
                        (read-escape-bytes (make-string-input-stream (coerce (subseq bytes-vector 2) 'string)) :SS3)
                      (declare (ignore _)) ; Ignore unused variable
                      (if keysym
                          (make-key-event :key keysym :modifiers '(:alt) :char nil)
                          (make-raw-input-event :bytes raw))))

                   (t ;; Alt + char (intro is the char-code of the char after ESC)
                    (let ((c (code-char intro)))
                      (make-key-event
                       :key       (intern (string-upcase (string c)) :keyword)
                       :char      c
                       :modifiers '(:alt))))))
               ;; lone ESC
               (make-key-event :key :escape :modifiers nil :char nil)))

          ;; Simple controls
          ((= first-byte 177) (make-key-event :key :backspace :modifiers nil :char nil)) ; Assuming 177 is decimal DEL/Rubout
          ((= first-byte (char-code #\Newline)) (make-key-event :key :enter :modifiers nil :char #\Newline))
          ((<= first-byte (char-code #\_)) ; Use char-code
           (let* ((base (+ first-byte 64)) ; first-byte is already a char-code here
                  (char (code-char base)))
             (make-key-event
              :key       (intern (format nil "C-~A" char) :keyword)
              :char      (code-char first-byte)
              :modifiers '(:control))))
          ;; Printable
          (t
           (let ((c (code-char first-byte)))
             (make-key-event :key (intern (string c) :keyword)
                             :char c
                             :modifiers nil))))
      (error (e)
        (warn "Parsing error ~A; returning raw" e)
        (make-raw-input-event :bytes raw)))))

;; Reusing the parsing logic structure from terminal.lisp

;; (defun parse-sgr-mouse-event (params raw-bytes final-char-code) ; Added final-char-code
;;   "Parses SGR mouse event parameters (e.g., from ESC [ < Cb ; Cx ; Cy ; M/m)."
;;   (let* ((button-code (first params))
;;          (col (second params))
;;          (row (third params))
;;          ;; (press-release-char (fourth params)) ; This was incorrect for SGR
;;          (button (logand button-code 3)) ; Low 2 bits often indicate button (0=1, 1=2, 2=3)
;;          (modifiers (let ((mod-code (ash button-code -2))) ; Higher bits for modifiers
;;                       (append (when (logbitp 0 mod-code) '(:shift))
;;                               (when (logbitp 1 mod-code) '(:alt)) ; Meta/Alt often same
;;                               (when (logbitp 2 mod-code) '(:control)))))
;;          (type (cond
;;                  ((= 35 (logand button-code 35)) :mouse-move) ; Motion often has bit 5 set
;;                  ((= final-char-code (char-code #\M)) :mouse-down) ; 'M'
;;                  ((= final-char-code (char-code #\m)) :mouse-up)   ; 'm'
;;                  ((>= button-code 64) ; Scroll events often start at 64
;;                   (if (= (logand button-code 1) 0) :scroll-up :scroll-down))
;;                  (t :unknown-mouse)))
;;          (final-button (cond ((= type :scroll-up) 4)
;;                              ((= type :scroll-down) 5)
;;                              ((= button 0) 1) ; Adjust button numbers
;;                              ((= button 1) 2)
;;                              ((= button 2) 3)
;;                              (t button)))) ; Keep others as is
;;     (make-mouse-event :type type
;;                       :button final-button
;;                       :row (1- row) ; Convert to 0-based
;;                       :col (1- col) ; Convert to 0-based
;;                       :modifiers modifiers
;;                       :raw raw-bytes)))

;; (defun parse-input-bytes-to-message (bytes-vector)
;;   "Parses a vector of bytes into a standardized elmtui AppMsg."
;;   (when (zerop (length bytes-vector))
;;     (return-from parse-input-bytes-to-message nil))

;;   (let ((first-byte (aref bytes-vector 0))
;;         (raw (copy-seq bytes-vector))) ; Keep original bytes
;;     (block parser
;;       (handler-case
;;           (cond
;;             ;; --- ESC Sequences ---
;;             ((= first-byte #o33) ; ESC
;;              (if (> (length bytes-vector) 1)
;;                  (let ((introducer-char-code (aref bytes-vector 1)))
;;                    (cond
;;                      ;; CSI Introducer (ESC [)
;;                      ((= introducer-char-code #o133) ; '['
;;                       (if (> (length bytes-vector) 2)
;;                           (let ((csi-content-list (coerce (subseq bytes-vector 2) 'list)))
;;                             (multiple-value-bind (params intermediates final-byte-code)
;;                                 (collect-csi-params csi-content-list)
;;                               (declare (ignore intermediates))
;;                               (cond
;;                                 ;; SGR Mouse Event (ESC [ < Cb ; Cx ; Cy M/m)
;;                                 ((and (member #\< intermediates) ; Check for SGR mouse intermediate '<'
;;                                       (or (= final-byte-code (char-code #\M))
;;                                           (= final-byte-code (char-code #\m))))
;;                                  (let ((mouse-event (parse-sgr-mouse-event params raw final-byte-code)))
;;                                    (return-from parser
;;                                      (make-mouse-event-app-msg :type (mouse-event-type mouse-event)
;;                                                                :button (mouse-event-button mouse-event)
;;                                                                :row (mouse-event-row mouse-event)
;;                                                                :col (mouse-event-col mouse-event)
;;                                                                :modifiers (mouse-event-modifiers mouse-event)))))

;;                                 ;; Other CSI sequences (likely keys)
;;                                 (t (multiple-value-bind (key-symbol remaining)
;;                                        (read-escape-bytes (make-string-input-stream (coerce csi-content-list 'string)) :CSI)
;;                                      (declare (ignore remaining))
;;                                      (if key-symbol
;;                                          (make-key-event-app-msg :key key-symbol :modifiers '(:alt) :char nil) ; Assume Alt for now
;;                                          (make-raw-input-event :bytes raw))))))) ; Return raw if unknown CSI
;;                           (make-key-event-app-msg :key :escape :modifiers nil :char nil))) ; Just ESC [

;;                      ;; SS3 Introducer (ESC O) - Often for F-keys, arrows
;;                      ((= introducer-char-code #o117) ; 'O'
;;                       (if (> (length bytes-vector) 2)
;;                           (multiple-value-bind (key-symbol remaining)
;;                               (read-escape-bytes (make-string-input-stream (coerce (subseq bytes-vector 2) 'string)) :SS3)
;;                             (declare (ignore remaining))
;;                             (if key-symbol
;;                                 (make-key-event-app-msg :key key-symbol :modifiers '(:alt) :char nil) ; Assume Alt
;;                                 (make-raw-input-event :bytes raw)))
;;                           (make-key-event-app-msg :key :escape :modifiers nil :char nil))) ; Just ESC O

;;                      ;; Alt + Character (ESC followed by a non-introducer)
;;                      (t (let ((char (code-char introducer-char-code)))
;;                           (make-key-event-app-msg :key (intern (string-upcase (string char)) :keyword)
;;                                                   :char char
;;                                                   :modifiers '(:alt))))))
;;                  ;; Just ESC key
;;                  (make-key-event-app-msg :key :escape :modifiers nil :char nil)))

;;             ;; --- Basic Control Characters ---
;;             ((= first-byte #o177) (make-key-event-app-msg :key :backspace :modifiers nil :char nil)) ; DEL
;;             ((= first-byte #o10) (make-key-event-app-msg :key :backspace :modifiers nil :char nil)) ; BS (Ctrl-H often maps here)
;;             ((= first-byte #o15) (make-key-event-app-msg :key :enter :modifiers nil :char (code-char first-byte))) ; CR (Ctrl-M)
;;             ((= first-byte #o11) (make-key-event-app-msg :key :tab :modifiers nil :char (code-char first-byte))) ; HT (Ctrl-I)

;;             ;; --- Other Ctrl Characters (C-@ to C-_) ---
;;             ((<= first-byte #o37)
;;              (let* ((base-char-code (+ first-byte 64))
;;                     (base-char (code-char base-char-code)))
;;                (make-key-event-app-msg :key (intern (format nil "C-~A" base-char) :keyword)
;;                                        :char (code-char first-byte) ; Keep original control char
;;                                        :modifiers '(:control))))

;;             ;; --- Printable Characters ---
;;             (t (let ((char (code-char first-byte)))
;;                  (make-key-event-app-msg :key (intern (string char) :keyword) ; Use char itself as key symbol
;;                                          :char char
;;                                          :modifiers nil))))
;;         (error (e)
;;           (warn "Error parsing input bytes ~A: ~A. Returning raw event." bytes-vector e)
;;           (make-raw-input-event :bytes raw)))))) ; Fallback to raw event on error

(defmethod poll-input-event ((instance urxvt-instance) &key timeout)
  (with-urxvt-lock (instance)
    (let ((stream (urxvt-instance-stream instance))
          (buffer (urxvt-instance-input-buffer instance))
          (start-time (get-internal-real-time)))
      (setf (fill-pointer buffer) 0)
      (loop
        (let ((char (if (zerop (fill-pointer buffer))
                        (if timeout (read-char stream nil :eof (if (= timeout 0) :nonblock-peek)) (read-char stream nil :eof))
                        (read-char-nonblock stream))))
          (cond ((eq char :eof) (return nil))
                ((eq char :nonblock-peek) (return nil))
                ((null char)
                 (if (plusp (fill-pointer buffer)) (return (parse-input-bytes-to-message buffer)) ; Use new function
                     (if (and timeout (> timeout 0) (> (/ (- (get-internal-real-time) start-time) internal-time-units-per-second) timeout))
                         (return nil)
                         (sleep 0.005)))) ; Shorter sleep for PTY
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

(defmethod peek-input-event ((instance urxvt-instance))
  (warn "peek-input-event is not reliably implemented for urxvt backend.") nil)

(defmethod enable-mouse-support ((instance urxvt-instance) &key motion-events-p)
  (with-urxvt-lock (instance)
    (if motion-events-p (send-sequence instance :enable-mouse-any-event) (send-sequence instance :enable-mouse-btn-event))
    (send-sequence instance :enable-mouse-sgr-ext-mode)
    (finish-output (urxvt-instance-stream instance)))
  t)

(defmethod disable-mouse-support ((instance urxvt-instance))
  (with-urxvt-lock (instance)
    (send-sequence instance :disable-mouse-any-event)
    (send-sequence instance :disable-mouse-sgr-ext-mode)
    (finish-output (urxvt-instance-stream instance)))
  t)

(defmethod set-input-mode ((instance urxvt-instance) mode) (declare (ignore mode)) t)

;;;---------------------------------------------------------------
;;; Capability Querying (delegates)
;;;---------------------------------------------------------------
(defmethod query-feature ((instance urxvt-instance) feature-keyword)
  (case feature-keyword
    (:unicode t) (:truecolor t) (:mouse t) (otherwise nil)))
(defmethod supports-unicode-p ((instance urxvt-instance)) (query-feature instance :unicode))
(defmethod supports-mouse-p ((instance urxvt-instance)) (query-feature instance :mouse))

;;;---------------------------------------------------------------
;;; Raw Access (Escape Hatch)
;;;---------------------------------------------------------------
(defmethod get-native-handle ((instance urxvt-instance)) (urxvt-instance-master-fd instance))
