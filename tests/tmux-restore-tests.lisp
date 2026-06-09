(uiop:define-package :elmtui.tests.tmux-restore
  (:use :cl :fiveam)
  (:import-from :elmtui.platform.tmux
                #:restore-to-tmux-capture
                #:save-tmux-capture
                #:has-saved-tmux-capture
                #:clear-saved-tmux-capture)
  (:import-from :elmtui.platform.backend.terminal
                #:terminal-instance
                #:terminal-instance-front-buffer)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:buffer-width
                #:buffer-height
                #:make-virtual-buffer
                #:buffer-cell-at
                #:buffer-cell-char
                #:buffer-cell-style
                #:set-buffer-cell-at
                #:virtual-terminal-buffer-p
                #:with-virtual-buffer-lock
                #:clear-buffer)
  (:export #:tmux-restore-tests))

(in-package :elmtui.tests.tmux-restore)

(def-suite tmux-restore-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for tmux capture+restore functionality")

(in-suite tmux-restore-tests)

(test save-tmux-capture-basic
  "Saving tmux capture stores buffer for later restore"
  (let* ((buffer (make-virtual-buffer 40 10))
         (buffer2 (make-virtual-buffer 40 10)))
    ;; Write some content to buffer
    (with-virtual-buffer-lock (buffer)
      (set-buffer-cell-at buffer 0 0 #\H nil)
      (set-buffer-cell-at buffer 0 1 #\e nil)
      (set-buffer-cell-at buffer 0 2 #\l nil)
      (set-buffer-cell-at buffer 0 3 #\l nil)
      (set-buffer-cell-at buffer 0 4 #\o nil))
    ;; Save the capture
    (save-tmux-capture buffer)
    ;; Verify it was saved
    (is (has-saved-tmux-capture))
    ;; Modify original buffer (simulating app running)
    (with-virtual-buffer-lock (buffer)
      (clear-buffer buffer)
      (set-buffer-cell-at buffer 0 0 #\X nil))
    ;; Restore from saved capture
    (restore-to-tmux-capture buffer)
    ;; Verify original content is back
    (let ((cell (buffer-cell-at buffer 0 0)))
      (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell) #\H)))
    (let ((cell (buffer-cell-at buffer 0 4)))
      (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell) #\o)))))

(test save-then-clear-saved
  "Clearing saved tmux capture removes the saved state"
  (let* ((buffer (make-virtual-buffer 40 10)))
    ;; Save a capture
    (save-tmux-capture buffer)
    (is (has-saved-tmux-capture))
    ;; Clear it
    (clear-saved-tmux-capture)
    (is (not (has-saved-tmux-capture)))
    ;; Restore should do nothing when no saved capture
    (restore-to-tmux-capture buffer)))

(test restore-to-empty-buffer
  "Restoring to an empty buffer is safe"
  (let* ((buffer (make-virtual-buffer 40 10))
         (empty-buffer (make-virtual-buffer 40 10)))
    ;; Save empty buffer
    (save-tmux-capture empty-buffer)
    ;; Create a buffer with content
    (with-virtual-buffer-lock (buffer)
      (set-buffer-cell-at buffer 0 0 #\X nil))
    ;; Restore (should clear since saved was empty)
    (restore-to-tmux-capture buffer)
    (let ((cell (buffer-cell-at buffer 0 0)))
      (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell) #\Space)))))

(test restore-multiple-saves
  "Multiple saves work correctly (last one wins)"
  (let* ((buffer1 (make-virtual-buffer 40 10))
         (buffer2 (make-virtual-buffer 40 10)))
    ;; Save first buffer with "A"
    (with-virtual-buffer-lock (buffer1)
      (set-buffer-cell-at buffer1 0 0 #\A nil))
    (save-tmux-capture buffer1)
    ;; Save second buffer with "B"
    (with-virtual-buffer-lock (buffer2)
      (set-buffer-cell-at buffer2 0 0 #\B nil))
    (save-tmux-capture buffer2)
    ;; Restore should get "B"
    (restore-to-tmux-capture buffer1)
    (let ((cell (buffer-cell-at buffer1 0 0)))
      (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell) #\B)))))
