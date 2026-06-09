(uiop:define-package :elmtui.tests.tmux-integration
  (:use :cl :fiveam)
  (:import-from :elmtui.platform.tmux
    #:tmux-available-p
    #:capture-pane-string
    #:capture-screen-string
    #:split-by-ansi-sequences
    #:parse-ansi-sgr
    #:parse-ansi-string
    #:save-tmux-capture
    #:restore-to-tmux-capture
    #:clear-saved-tmux-capture
    #:make-buffer-from-tmux-styled
    #:prefill-buffer-from-styled-content)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:buffer-width
    #:buffer-height
    #:buffer-cell-at
    #:set-buffer-cell-at
    #:virtual-terminal-buffer-p)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:make-virtual-buffer)
  (:export #:tmux-integration-tests))

(in-package :elmtui.tests.tmux-integration)

(def-suite tmux-integration-tests
  :in elmtui.tests:elmtui-test
  :description "Integration tests for tmux screen capture (require tmux)")

(in-suite tmux-integration-tests)

;;;----------------------------------------------------------------
;;; Helper: Skip tests if tmux not available
;;;----------------------------------------------------------------

(defun %truthy-env-p (name)
  (member (string-downcase (or (uiop:getenv name) ""))
          '("1" "true" "yes")
          :test #'string=))

(defparameter *require-tmux-integration-tests*
  (%truthy-env-p "ELMTUI_REQUIRE_TMUX")
  "When true, tmux integration tests fail (instead of skip) if tmux is unavailable.")

(defparameter *run-tmux-integration-tests*
  (or (%truthy-env-p "ELMTUI_RUN_TMUX_INTEGRATION")
      *require-tmux-integration-tests*)
  "When true, tests may probe and capture the live tmux pane.")

(defmacro skip-unless-tmux (&body body)
  "Run BODY only when live tmux integration is explicitly enabled and tmux exists."
  `(cond
     ((not *run-tmux-integration-tests*)
      (skip "live tmux integration requires ELMTUI_RUN_TMUX_INTEGRATION=1"))
     ((tmux-available-p)
      (progn ,@body))
     (*require-tmux-integration-tests*
      (fail "tmux unavailable but ELMTUI_REQUIRE_TMUX requires live tmux integration"))
     (t
      (skip "tmux not available in this environment"))))

;;;----------------------------------------------------------------
;;; Environment Detection Tests
;;;----------------------------------------------------------------

(test tmux-available-detection
  "tmux-available-p returns boolean indicating tmux availability when live tmux integration is enabled"
  (skip-unless-tmux
    (let ((result (tmux-available-p)))
      (is (or (eq result t) (eq result nil))))))

;;;----------------------------------------------------------------
;;; Capture Function Tests
;;;----------------------------------------------------------------

(test capture-pane-string-basic
  "capture-pane-string returns a string when tmux is available"
  (skip-unless-tmux
    (let ((result (capture-pane-string)))
      (is (stringp result))
      (format t "  Captured ~A characters~%" (length result))
      (is (plusp (length result))))))

(test capture-pane-string-contains-ansi
  "Captured content may contain ANSI escape sequences"
  (skip-unless-tmux
    (let ((result (capture-pane-string)))
      ;; Just check we got something - actual ANSI content depends on terminal state
      (is (stringp result))
      (format t "  Sample content (first 50 chars): ~A~%"
        (subseq result 0 (min 50 (length result)))))))

;;;----------------------------------------------------------------
;;; ANSI Parsing Tests
;;;----------------------------------------------------------------

(test split-by-ansi-sequences-simple
  "Splitting text with ANSI sequences works correctly"
  (let* ((input (concatenate 'string "Hello" (format nil "~C[31m" #\Escape) "World" (format nil "~C[0m" #\Escape) "!"))
          (result (split-by-ansi-sequences input)))
    (is (= (length result) 5))
    (is (string= (first result) "Hello"))
    (is (string= (second result) (format nil "~C[31m" #\Escape)))
    (is (string= (third result) "World"))
    (is (string= (fourth result) (format nil "~C[0m" #\Escape)))
    (is (string= (fifth result) "!"))))

(test split-by-ansi-empty
  "Empty string returns empty list"
  (let ((result (split-by-ansi-sequences "")))
    (is (null result))))

(test split-by-ansi-no-ansi
  "Plain text without ANSI returns single segment"
  (let ((result (split-by-ansi-sequences "Just plain text")))
    (is (= (length result) 1))
    (is (string= (first result) "Just plain text"))))

(test parse-ansi-sgr-red-fg
  "Parsing SGR for red foreground"
  (let ((result (parse-ansi-sgr (format nil "~C[31m" #\Escape))))
    (is (not (null result)))
    (is (eq (getf result :fg) :red))))

(test parse-ansi-sgr-bold
  "Parsing SGR for bold attribute"
  (let ((result (parse-ansi-sgr (format nil "~C[1m" #\Escape))))
    (is (not (null result)))
    (is (member :bold (getf result :attrs)))))

(test parse-ansi-sgr-complex
  "Parsing complex SGR with multiple attributes"
  (let ((result (parse-ansi-sgr (format nil "~C[1;31;42m" #\Escape))))
    (is (not (null result)))
    (is (eq (getf result :fg) :red))
    (is (eq (getf result :bg) :green))
    (is (member :bold (getf result :attrs)))))

(test parse-ansi-sgr-reset
  "Parsing SGR reset returns NIL"
  (let ((result (parse-ansi-sgr (format nil "~C[0m" #\Escape))))
    (is (null result))))

(test parse-ansi-string-full
  "Parsing full string with multiple styles"
  (let* ((text "Hello ")
          (esc1 (format nil "~C[31m" #\Escape))
          (text2 "World")
          (esc2 (format nil "~C[0m" #\Escape))
          (text3 "!")
          (input (concatenate 'string text esc1 text2 esc2 text3))
          (result (parse-ansi-string input)))
    (is (= (length result) 3))
    (is (string= (caar result) text))
    (is (null (cdar result)))
    (is (string= (caadr result) text2))
    (is (eq (getf (cdadr result) :fg) :red))
    (is (string= (caaddr result) text3))
    (is (null (cdaddr result)))))

;;;----------------------------------------------------------------
;;; Buffer Prefill Tests (styled)
;;;----------------------------------------------------------------

(test prefill-buffer-from-styled-basic
  "Prefilling buffer with styled content"
  (let* ((buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 20 2))
          (runs '(("Hello " . nil)
                   ("World" . (:fg :red))
                   ("!" . nil))))
    (prefill-buffer-from-styled-content buffer runs 20 2)
    (is (virtual-terminal-buffer-p buffer))
    (is (= (buffer-width buffer) 20))
    (is (= (buffer-height buffer) 2))
    ;; Check some cells
    (let ((cell (buffer-cell-at buffer 0 0)))
      (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell) #\H)))
    ;; Check red color at position 6 (W)
    (let ((cell (buffer-cell-at buffer 0 6)))
      (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell) #\W))
      (is (not (null (elmtui.platform.backend.common.virtual-buffer:buffer-cell-style cell)))))))

(test prefill-buffer-from-styled-wrap
  "Styled content wraps correctly to next line"
  (let* ((buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 10 2))
          (runs '(("1234567890" . nil)    ; exactly 10 chars
                   ("abcdefghij" . (:fg :red))))) ; should wrap to next line
    (prefill-buffer-from-styled-content buffer runs 10 2)
    ;; First row should be "1234567890"
    (let ((cell (buffer-cell-at buffer 0 9)))
      (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell) #\0)))
    ;; Second row should start with "a"
    (let ((cell (buffer-cell-at buffer 1 0)))
      (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell) #\a)))))

(test prefill-buffer-from-styled-empty
  "Empty runs list does nothing"
  (let* ((buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 10 1))
          (runs '()))
    (prefill-buffer-from-styled-content buffer runs 10 1)
    (is (virtual-terminal-buffer-p buffer))))

;;;----------------------------------------------------------------
;;; Full Integration Test (requires tmux)
;;;----------------------------------------------------------------

(test make-buffer-from-tmux-styled-basic
  "Create styled buffer from actual tmux capture"
  (skip-unless-tmux
    (let ((buffer (make-buffer-from-tmux-styled 40 10)))
      (is (not (null buffer)))
      (when buffer
        (is (virtual-terminal-buffer-p buffer))
        (is (= (buffer-width buffer) 40))
        (is (= (buffer-height buffer) 10))
        (format t "  Created buffer from tmux: ~Ax~A~%"
          (buffer-width buffer) (buffer-height buffer))))))

(test end-to-end-capture-and-parse
  "Full end-to-end test: capture tmux, parse ANSI, create buffer"
  (skip-unless-tmux
    ;; Step 1: Capture from tmux
    (let* ((content (capture-pane-string))
            ;; Step 2: Parse into styled runs
            (runs (parse-ansi-string content))
            ;; Step 3: Create buffer
            (buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 40 10)))
      (is (stringp content))
      (is (listp runs))
      (is (virtual-terminal-buffer-p buffer))
      ;; Step 4: Fill buffer
      (prefill-buffer-from-styled-content buffer runs 40 10)
      (format t "  End-to-end test passed: ~A runs, ~Ax~A buffer~%"
        (length runs) (buffer-width buffer) (buffer-height buffer)))))

(test end-to-end-capture-parse-save-restore-visible
  "Integration smoke: capture visible pane, parse, save snapshot, then restore into another buffer"
  (skip-unless-tmux
    (let* ((width 40)
           (height 10)
           (content (capture-pane-string :mode :pane))
           (runs (parse-ansi-string content))
           (snapshot (make-virtual-buffer width height))
           (target (make-virtual-buffer width height)))
      (unwind-protect
           (progn
             (is (stringp content))
             (is (listp runs))
             (prefill-buffer-from-styled-content snapshot runs width height)
             (save-tmux-capture snapshot)
             ;; Dirty target so restore has to replace real content.
             (set-buffer-cell-at target 0 0 #\X nil)
             (restore-to-tmux-capture target)
             (let* ((snap-cell (buffer-cell-at snapshot 0 0))
                    (restored-cell (buffer-cell-at target 0 0)))
               (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char restored-cell)
                          (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char snap-cell)))
               ;; terminal-style is a struct; compare structurally, not by identity.
               (is (equalp (elmtui.platform.backend.common.virtual-buffer:buffer-cell-style restored-cell)
                           (elmtui.platform.backend.common.virtual-buffer:buffer-cell-style snap-cell)))))
        (clear-saved-tmux-capture)))))
