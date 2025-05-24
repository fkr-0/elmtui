
(defmethod set-cursor-position ((term low-level-terminal) x y)
  "Set the cursor position."
  (exec-sequence term :cursor-set-position x y))

(defmethod hide-cursor ((term low-level-terminal))
  "Hide the cursor."
  (exec-sequence term :cursor-hide))

(defmethod show-cursor ((term low-level-terminal))
  "Show the cursor."
  (exec-sequence term :cursor-show))


(defmethod flush-out ((terminal low-level-terminal))
  "Flush the output"
  (force-output (fd terminal)))
(defmethod exec-sequence ((term low-level-terminal) (seq string) &rest args)
  "Print the escape sequence SEQ to the terminal TERM.
TERM is locked while the sequence is printed. The FD is receiving
the escape sequence as byte stream."
  (declare (ignore args))
  (with-lock (term)
    (loop for ch across seq
          do (write-byte (char-code ch) (fd term))))
  (finish-output (fd term)))
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

(defun sigint-handler (term)
  (lambda (sig code scp)
    (declare (ignore sig code scp))
    (format t "Caught SIGINT, exiting~%")
    (stop-term term)
    (sb-ext:exit)))



(defmethod stop-term ((term low-level-terminal))
  "Stop the terminal"
  (when (raw-mode term)
    (log:info "Stopping terminal")
    (handler-case
        (progn
          (disable-raw term)
          (dolist (hook (exit-hook term)) (funcall hook term))
          (when (open-stream-p (fd term))
            (close (fd term))))
      (error (c)
        (log:info "Error stopping terminal: ~a" c))))) ; Ignore any errors stopping

(defmethod timeout-term ((term low-level-terminal) timeout done-handler)
  "Set the terminal timeout"
  (let ((timeout (+ (get-universal-time) timeout)))
    (loop while (and (not (funcall done-handler))
                     (<= (get-universal-time) timeout))
          do (progn (sleep 1) (format t "."))))
  (stop-term term))

(defmethod exec-sequence ((term low-level-terminal) (seq string) &rest args)
  "Print the escape sequence SEQ to the terminal TERM.
TERM is locked while the sequence is printed. The FD is receiving
the escape sequence as byte stream."
  (declare (ignore args))
  (with-lock (term)
    (loop for ch across seq
          do (write-byte (char-code ch) (fd term))))
  (finish-output (fd term)))
(defmethod exec-sequence ((term low-level-terminal) (seq-id symbol) &rest args)
  "Execute the escape sequence SEQ on the terminal TERM.
TERM is locked while the sequence is executed. The FD is receiving
the escape sequence as byte stream."
  (let* ((seq (get-sequence seq-id))
         (rendered-seq (apply #'render-seq (append (list seq) args))))
    (unless seq
      ;; signal lowterm.errors::unknown-sequence-error with seq-id+string
      (let ((msg (format nil "Unknown sequence: ~A" seq-id)))
        (log-error msg)
        (signal 'ut.lowterm.errors:unknown-sequence-error :message msg)))
    (with-lock (term)
      (print-sequence term rendered-seq)
      (when (response-parser seq)
        (funcall (response-parser seq) (fd term))))))
(defmethod print-sequence ((term low-level-terminal) seq)
  "Print the sequence SEQ to the terminal TERM.

  This function is used to print the sequence to the terminal. It
  will be used to print the sequence to the terminal. The sequence
  will be rendered and then written to the terminal file.

Arguments:
  TERM: The terminal to print to.
  SEQ: The sequence to print.
  ARGS: The arguments to the sequence.
Raises:
  lowterm.errors::terminal-closed: If the terminal is closed."
  (with-lock (term)
    (loop for ch across seq
          do (write-byte (char-code ch) (fd term)))
    ;; catch
    ;; The value
    ;;   -1
    ;; is not of type
    ;;   (UNSIGNED-BYTE 62)
    ;; when binding SB-UNIX:FD
    (handler-case (finish-output (fd term))
      (type-error (e)
        (log-error "print-sequenceTYPEEERRRORR: ~A" e)
        (close (fd term))
        (setf (fd term) nil)
        (error 'ut.lowterm.errors:terminal-closed :terminal term))
      (sb-impl::file-error (e)
        (log-error "print-sequenceFILEEERRORR: ~A" e)
        (close (fd term))
        (setf (fd term) nil)
        (error 'ut.lowterm.errors:terminal-closed :terminal term))))
  ;; (finish-output (fd term))
  )
(defmethod exec-reset-sequence ((term low-level-terminal) seq-id)
  "Reset the escape sequence SEQ on the terminal TERM.
TERM is locked while the sequence is executed. The FD is receiving
the escape sequence as byte stream."
  (log-debug "exec-reset-sequence: ~A" seq-id)
  (let* ((seq (get-sequence seq-id))
         (reset-seq
           (when seq
             (reset-sequence seq))))
    (unless (and seq reset-seq)
      (error "Unknown sequence: ~A" seq))
    (print-sequence term reset-seq)))

(defun cancel-read ()
  "Cancels the current read operation."
  (sb-thread:release-foreground ;; (sb-thread:main-thread)
   )
  (sb-thread:interrupt-thread (sb-thread:main-thread)
                              'sb-thread:release-foreground)
  (bordeaux-threads:interrupt-thread (sb-thread:main-thread)
                                     (lambda ()
                                       (log-info
                                        "Start: Aborting read operation")
                                       (signal 'abort-read
                                               :message "Aborted read"))))

(defmethod read-input ((term low-level-terminal))
  "Read a character from the terminal. Returns the character or nil if the
read operation was aborted.
  Args:
    term: The terminal to read from.
  Returns:
    The character that was read or nil if the read operation was aborted."
  (handler-case
      (ensure-terminal-raw-mode (term)
                                (loop for char = (read-seq-from-fd term)
                                      do (log-debug "Read:" char)
                                         (emit term 'key-event :data char)))
    (abort-read (c)
      (progn
        (log-info "input-loop: quit")
        (emit term 'quit-event :data 'abort-read)
        (sb-thread:release-foreground)
        (format t "~a~&~%" c)
        ;; (stop-term term)
        (return-from read-input nil)))
    (error (e)
      (log-error "read-input: ~a" e)
      ;; (SB-THREAD:RELEASE-FOREGROUND SB-THREAD:*CURRENT-THREAD*)
      ;; (sb-thread:terminate-thread (sb-thread:current-thread) 1)
      (return-from read-input nil))))


(defun setup-resize (resize-fun)
  "Sets up a handler for SIGWINCH that calls RESIZE-FUN.
  Argument: RESIZE-FUN - the function to call when SIGWINCH is signaled.
  Returns: NIL.

  Examples:
    (setup-resize #'handle-resize)
     => NIL
    (setup-resize #'handle-resize)
     => NIL"
  (sb-sys:enable-interrupt sb-unix:sigwinch
                           (lambda (signal code scp)
                             (declare (ignore signal code scp))
                             (funcall resize-fun))))

(defun setup-interrupt (interrupt-fun)
  "Sets up a handler for SIGINT that calls INTERRUPT-FUN.
  Argument: INTERRUPT-FUN - the function to call when SIGINT is signaled.
  Returns: NIL.

  Examples:
    (setup-interrupt #'handle-interrupt)
     => NIL
    (setup-interrupt #'handle-interrupt)
     => NIL"
  (sb-sys:enable-interrupt sb-unix:sigint
                           (lambda (signal code scp)
                             (declare (ignore signal code scp))
                             (funcall interrupt-fun))))
(defmethod read-seq-from-fd ((term low-level-terminal))
  "Read input from the terminal file descriptor until an interaction is parsed."
  (with-slots (fd) term
    (let ((alt-pressed nil)
          (in-escape-sequence nil)) ;; Track if we're in the middle of an escape sequence
      ;; Reading from terminal in raw mode
      (loop
        (let ((byte (read-byte fd nil nil)))
          (log:info "Read byte: ~a" byte)
          (cond
            ;; Handle the Escape character initiating an escape sequence
            ((= (char-code #\Esc) byte)
             (if alt-pressed
                 (setf alt-pressed nil)
                 ;; Set state to be ready for an escape sequence
                 (progn (setf alt-pressed t)
                        (setf in-escape-sequence t))))

            ;; Handle '[' or other escape sequence characters
            ((and in-escape-sequence
                  (or (= (char-code #\[) byte) (= (char-code #\]) byte)))
             ;; Read escape sequence, likely for a special key
             (let ((esc-seq (read-escape-sequence-bytes fd)))
               ;; Reset escape state
               (setf in-escape-sequence nil)
               ;; Process escape sequence (e.g., arrow keys, Delete)
               (log:info "Escape sequence received: ~a" esc-seq)
               (return esc-seq)))

            ;; Handle regular tilde key
            ((and (= (char-code #\~) byte) (not in-escape-sequence))
             ;; If we are not in an escape sequence, treat '~' as a regular key
             (log:info "Regular tilde key pressed")
             (return (input-seq-from-input byte alt-pressed)))

            ;; Handle Backspace (usually sends ASCII 8 or 127)
            ((or (= 8 byte) (= 127 byte))
             (log:info "Backspace pressed")
             (return (input-seq-from-input byte alt-pressed)))

            ;; If we are in the middle of an escape sequence but receive an unexpected character
            ((and in-escape-sequence
                  (not (member byte (list (char-code #\[) (char-code #\])))))
             ;; Unexpected character, reset the escape sequence state
             (setf in-escape-sequence nil)
             (log:warn "Unexpected byte while reading escape sequence: ~a" byte))

            ;; Handle other normal characters
            (t
             ;; Reset in-escape-sequence if not in it
             (setf in-escape-sequence nil)
             (return (input-seq-from-input byte alt-pressed)))))))))
