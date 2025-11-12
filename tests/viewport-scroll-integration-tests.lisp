;;;===============================================================
;;; File: tests/viewport-scroll-integration-tests.lisp
;;; Integration Tests for Viewport Scrolling and Cleanup
;;;
;;; Tests the complete flow from driver to platform backend,
;;; verifying correct command ordering and execution.
;;;===============================================================

(uiop:define-package :elmtui.tests.viewport-scroll-integration
  (:use :cl :fiveam)
  (:import-from :elmtui.backend.faketerm
                #:faketerm-instance
                #:faketerm-instance-stream
                #:faketerm-instance-filepath)
  (:import-from :elmtui.platform.api
                #:initialize-backend
                #:shutdown-backend
                #:scroll
                #:clear-below-cursor
                #:set-cursor-position)
  (:import-from :elmtui.ui.widgets.root-viewport
                #:make-root-viewport
                #:root-viewport)
  (:import-from :elmtui.ui.api
                #:init #:update #:view)
  (:import-from :elmtui.platform.driver
                #:execute-render-command)
  (:export #:run-viewport-scroll-integration-tests))

(in-package :elmtui.tests.viewport-scroll-integration)

(def-suite viewport-scroll-integration
  :description "Integration tests for viewport scrolling with faketerm backend")

(in-suite viewport-scroll-integration)

;;;---------------------------------------------------------------
;;; Test Helpers
;;;---------------------------------------------------------------

(defun make-test-backend (&optional (filepath "/tmp/elmtui-scroll-test.log"))
  "Create a faketerm backend for testing."
  (initialize-backend :faketerm :filepath filepath :width 80 :height 24))

(defun read-log-file (filepath)
  "Read the contents of a log file and return as string."
  (with-open-file (stream filepath :direction :input :if-does-not-exist nil)
    (when stream
      (let ((contents (make-string (file-length stream))))
        (read-sequence contents stream)
        contents))))

(defun parse-command-sequence (log-content)
  "Extract command sequence from log content."
  (let ((lines (uiop:split-string log-content :separator '(#\Newline)))
        (commands nil))
    (dolist (line lines)
      (when (and (> (length line) 0) (char= (char line 0) #\;))
        (push (string-trim " " (subseq line 1)) commands)))
    (nreverse commands)))

(defun find-command-pattern (commands pattern)
  "Find commands matching a pattern (substring match)."
  (remove-if-not (lambda (cmd) (search pattern cmd)) commands))

(defun command-order-correct-p (commands pattern-sequence)
  "Verify commands appear in the specified order (not necessarily consecutive)."
  (let ((remaining-commands commands))
    (loop for pattern in pattern-sequence
          for found-index = (position-if 
                             (lambda (cmd) (search pattern cmd)) 
                             remaining-commands)
          always (when found-index
                   (setf remaining-commands (subseq remaining-commands (1+ found-index)))
                   t))))

;;;---------------------------------------------------------------
;;; Test: Basic Scroll Commands
;;;---------------------------------------------------------------

(test scroll-commands-are-logged
  "Verify scroll commands are properly logged in faketerm."
  (let* ((filepath "/tmp/test-scroll-basic.log")
         (backend (make-test-backend filepath)))
    (unwind-protect
        (progn
          ;; Execute scroll commands
          (scroll backend 5)  ; scroll down
          (scroll backend -3) ; scroll up
          (shutdown-backend backend)
          
          ;; Read and verify log
          (let* ((log (read-log-file filepath))
                 (commands (parse-command-sequence log)))
            (is (find "SCROLL" (format nil "~{~A~^~%~}" commands) :test #'search)
                "Log should contain SCROLL command")
            (is (>= (length (find-command-pattern commands "SCROLL")) 2)
                "Should have at least 2 scroll commands")))
      (ignore-errors (delete-file filepath)))))

;;;---------------------------------------------------------------
;;; Test: Clear Below Cursor
;;;---------------------------------------------------------------

(test clear-below-cursor-command
  "Verify clear-below-cursor is properly executed."
  (let* ((filepath "/tmp/test-clear-below.log")
         (backend (make-test-backend filepath)))
    (unwind-protect
        (progn
          (set-cursor-position backend 10 0)
          (clear-below-cursor backend)
          (shutdown-backend backend)
          
          (let* ((log (read-log-file filepath))
                 (commands (parse-command-sequence log)))
            (is (find-command-pattern commands "CLEAR_BELOW_CURSOR")
                "Log should contain CLEAR_BELOW_CURSOR command")
            (is (command-order-correct-p commands 
                                        '("SET_CURSOR_POSITION" "CLEAR_BELOW_CURSOR"))
                "Cursor positioning should precede clear")))
      (ignore-errors (delete-file filepath)))))

;;;---------------------------------------------------------------
;;; Test: Complete Lifecycle Flow
;;;---------------------------------------------------------------

(test viewport-lifecycle-command-sequence
  "Test complete flow: init -> render -> scroll -> cleanup."
  (let* ((filepath "/tmp/test-viewport-lifecycle.log")
         (backend (make-test-backend filepath)))
    (unwind-protect
        (progn
          ;; Simulate viewport lifecycle
          ;; 1. Initialize
          (set-cursor-position backend 12 0)
          
          ;; 2. Clear initial area
          (clear-below-cursor backend)
          
          ;; 3. Render (simulated)
          (set-cursor-position backend 13 5)
          
          ;; 4. Need more space, scroll
          (scroll backend 3)
          
          ;; 5. Render more content
          (set-cursor-position backend 16 5)
          
          ;; 6. Shutdown - clear and restore
          (clear-below-cursor backend)
          (scroll backend -3)
          
          (shutdown-backend backend)
          
          ;; Verify command sequence
          (let* ((log (read-log-file filepath))
                 (commands (parse-command-sequence log)))
            (is (command-order-correct-p commands
                                        '("SET_CURSOR_POSITION"
                                          "CLEAR_BELOW_CURSOR"
                                          "SET_CURSOR_POSITION"
                                          "SCROLL"
                                          "SET_CURSOR_POSITION"
                                          "CLEAR_BELOW_CURSOR"
                                          "SCROLL"))
                "Commands should follow lifecycle pattern")))
      (ignore-errors (delete-file filepath)))))

;;;---------------------------------------------------------------
;;; Test: Root Viewport Integration
;;;---------------------------------------------------------------

(test root-viewport-generates-correct-commands
  "Test root-viewport generates proper command sequence on shutdown."
  (let* ((state (make-hash-table :test 'equal))
         (rv (make-root-viewport :test-rv :anchor :below-cursor))
         (id-path '(:components :test-rv)))
    
    ;; Initialize root viewport
    (multiple-value-bind (comp patches cmds)
        (init rv :id-path id-path
                 :initial-terminal-dimensions '(80 24)
                 :initial-cursor-pos '(0 12)
                 :anchor :below-cursor)
      (declare (ignore comp))
      
      ;; Apply patches to state
      (dolist (patch patches)
        (setf (gethash (first patch) state) (second patch))))
    
    ;; Set issued-scroll-net to simulate scrolling happened
    (setf (gethash (append id-path '(:state :issued-scroll-net)) state) 5)
    
    ;; Send shutdown message
    (multiple-value-bind (patches commands)
        (update rv '(:appshutdown) state :id-path id-path)
      (declare (ignore patches))
      
      ;; Verify commands
      (is (find-if (lambda (cmd) 
                     (and (consp cmd)
                          (eq (first cmd) :render)
                          (eq (second cmd) :clear-below-cursor)))
                   commands)
          "Should have clear-below-cursor command")
      
      (is (find-if (lambda (cmd)
                     (and (consp cmd)
                          (eq (first cmd) :render)
                          (eq (second cmd) :scroll-up)
                          (= (third cmd) 5)))
                   commands)
          "Should have scroll-up 5 command to restore scroll"))))

;;;---------------------------------------------------------------
;;; Test: Command Ordering in Driver
;;;---------------------------------------------------------------

(test driver-executes-commands-in-order
  "Verify driver's execute-render-command handles all command types."
  (let* ((filepath "/tmp/test-driver-commands.log")
         (backend (make-test-backend filepath)))
    (unwind-protect
        (progn
          ;; Execute various render commands through driver
          (execute-render-command '(:render :scroll-down 3) backend)
          (execute-render-command '(:render :clear-below-cursor) backend)
          (execute-render-command '(:render :scroll-up 2) backend)
          (execute-render-command '(:render :set-cursor 5 10) backend)
          
          (shutdown-backend backend)
          
          (let* ((log (read-log-file filepath))
                 (commands (parse-command-sequence log)))
            (is (>= (length (find-command-pattern commands "SCROLL")) 2)
                "Should have scroll commands")
            (is (find-command-pattern commands "CLEAR_BELOW_CURSOR")
                "Should have clear command")
            (is (find-command-pattern commands "SET_CURSOR_POSITION")
                "Should have cursor positioning")))
      (ignore-errors (delete-file filepath)))))

;;;---------------------------------------------------------------
;;; Test: Scroll Tracking Accuracy
;;;---------------------------------------------------------------

(test scroll-net-tracking
  "Verify scroll tracking accumulates correctly."
  (let* ((state (make-hash-table :test 'equal))
         (rv (make-root-viewport :test-rv2 :anchor :below-cursor))
         (id-path '(:components :test-rv2)))
    
    ;; Initialize
    (multiple-value-bind (comp patches cmds)
        (init rv :id-path id-path
                 :initial-terminal-dimensions '(80 24)
                 :initial-cursor-pos '(0 18)
                 :anchor :below-cursor)
      (declare (ignore comp cmds))
      (dolist (patch patches)
        (setf (gethash (first patch) state) (second patch))))
    
    ;; Simulate scroll events
    (multiple-value-bind (patches1 cmds1)
        (update rv '(:terminal-scrolled :direction :down :amount 3) state :id-path id-path)
      (declare (ignore cmds1))
      (dolist (patch patches1)
        (setf (gethash (first patch) state) (second patch))))
    
    (multiple-value-bind (patches2 cmds2)
        (update rv '(:terminal-scrolled :direction :down :amount 2) state :id-path id-path)
      (declare (ignore cmds2))
      (dolist (patch patches2)
        (setf (gethash (first patch) state) (second patch))))
    
    (multiple-value-bind (patches3 cmds3)
        (update rv '(:terminal-scrolled :direction :up :amount 1) state :id-path id-path)
      (declare (ignore cmds3))
      (dolist (patch patches3)
        (setf (gethash (first patch) state) (second patch))))
    
    ;; Check accumulated scroll
    (let ((net-scroll (gethash (append id-path '(:state :issued-scroll-net)) state)))
      (is (= net-scroll 4) "Net scroll should be 3 + 2 - 1 = 4"))))

;;;---------------------------------------------------------------
;;; Test: Multiple Clear Operations
;;;---------------------------------------------------------------

(test multiple-clear-operations
  "Test handling of multiple clear operations in sequence."
  (let* ((filepath "/tmp/test-multiple-clear.log")
         (backend (make-test-backend filepath)))
    (unwind-protect
        (progn
          (set-cursor-position backend 5 0)
          (clear-below-cursor backend)
          (set-cursor-position backend 10 0)
          (clear-below-cursor backend)
          (set-cursor-position backend 15 0)
          (clear-below-cursor backend)
          
          (shutdown-backend backend)
          
          (let* ((log (read-log-file filepath))
                 (commands (parse-command-sequence log)))
            (is (>= (length (find-command-pattern commands "CLEAR_BELOW_CURSOR")) 3)
                "Should have 3 clear operations")
            (is (>= (length (find-command-pattern commands "SET_CURSOR_POSITION")) 3)
                "Should have 3 cursor positions")))
      (ignore-errors (delete-file filepath)))))

;;;---------------------------------------------------------------
;;; Run All Tests
;;;---------------------------------------------------------------

(defun run-viewport-scroll-integration-tests ()
  "Run all viewport scroll integration tests."
  (run! 'viewport-scroll-integration))
