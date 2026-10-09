;;;===============================================================
;;; File: tests/viewport-scroll-integration-tests.lisp
;;; Integration Tests for Viewport Scrolling and Cleanup
;;;
;;; Tests the complete flow from driver to platform backend,
;;; verifying correct command ordering and execution.
;;;===============================================================

(uiop:define-package :elmtui.tests.viewport-scroll-integration
  (:use :cl :fiveam)
  (:import-from #:log4cl #:log-info)
  (:import-from :elmtui.backend.faketerm
    #:faketerm-instance
    #:faketerm-instance-stream
    #:faketerm-instance-filepath)
  (:import-from :elmtui.state
    #:state-ref
    #:make-application-state)
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

(test alternate-screen-preflight-refuses-without-touching-backend
  "Normal-buffer mode is mandatory: reject alternate-screen before initialization."
  (let ((sentinel (gensym "BACKEND")))
    (let ((elmtui.platform.driver::*backend* sentinel))
      (signals error
        (elmtui.platform.driver:run-app-platform
         '(:name :reject-alternate) :backend-type :terminal
         :platform-options '(:use-alternate-screen t)))
      (is (eq sentinel elmtui.platform.driver::*backend*)))))

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
  (let ((commands nil))
    (when (and (stringp log-content) (> (length log-content) 0))
      (with-input-from-string (stream log-content)
        (loop for raw-line = (read-line stream nil nil)
          while raw-line do
          (let ((line (typecase raw-line
                        (string raw-line)
                        (t (string raw-line)))))
            (when (and (> (length line) 0)
                    (char= (char line 0) #\;))
              (let ((trimmed (string-trim '(#\Space #\Tab) (subseq line 1))))
                (when (> (length trimmed) 0)
                  (push trimmed commands))))))))
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
                (commands (parse-command-sequence log))
                (scroll-commands (find-command-pattern commands "SCROLL")))
          (is (not (null scroll-commands)) "Log should contain SCROLL command")
          (is (>= (length scroll-commands) 2)
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
  (let* ((state (make-application-state))
          (rv (make-root-viewport :test-rv :anchor :below-cursor))
          (id-path '(:components :test-rv)))

    ;; Initialize root viewport
    (multiple-value-bind (comp patches cmds)
      (init rv :id-path id-path
        :initial-terminal-dimensions '(80 24)
        :initial-cursor-pos '(0 12)
        :anchor :below-cursor)
      (declare (ignore comp cmds))
      ;; Apply patches to state
      (elmtui.state:apply-patches state patches))
    ;; Provide known viewport size for cleanup
    (elmtui.state:apply-patches state
      (list
        (list (append id-path '(:width)) 10)
        (list (append id-path '(:height)) 3)))

    ;; Set issued-scroll-net to simulate scrolling happened
    (elmtui.state:apply-patches state
      (list (list (append id-path '(:issued-scroll-net)) 5)))

    ;; Send shutdown message
    (let* ((result (update rv '(:appshutdown) state :id-path id-path))
            (commands (elmtui.state.api:ur-commands result)))
      ;; Verify commands
      (is (find-if (lambda (cmd)
                     (and (consp cmd)
                       (eq (first cmd) :render)
                       (eq (second cmd) :blank-viewport)))
            commands)
        "Should have blank-viewport command for viewport area")

      (is (find-if (lambda (cmd)
                     (and (consp cmd)
                       (eq (first cmd) :render)
                       (eq (second cmd) :scroll-up)
                       (= (third cmd) 5)))
            commands)
        "Should have scroll-up 5 command to restore scroll"))))

;;;---------------------------------------------------------------
;;; Test: Below-cursor inline startup behavior
;;;---------------------------------------------------------------

(test below-cursor-inline-startup-scroll-no-clear
  "Verify inline below-cursor anchoring scrolls for overflow without clearing at startup."
  (let* ((state (make-application-state))
          (rv (make-root-viewport :test-inline :anchor :below-cursor))
          (id-path '(:components :test-inline))
          (dsl '(:root-viewport :id :test-inline :anchor :below-cursor
                  :width 10 :height 4 :child-dsl-spec (:view nil))))
    (multiple-value-bind (comp patches cmds)
      (init rv :id-path id-path :dsl dsl :anchor :below-cursor)
      (declare (ignore comp cmds))
      (elmtui.state:apply-patches state patches))
    (let* ((res1 (update rv '(:terminalresized :width 10 :height 4) state :id-path id-path))
            (cmds1 (elmtui.state.api:ur-commands res1)))
      (elmtui.state:apply-patches state (elmtui.state.api:ur-patches res1))
      (let* ((res2 (update rv '(:cursorposition :col 1 :row 2) state :id-path id-path))
              (cmds2 (elmtui.state.api:ur-commands res2))
              (all-commands (append cmds1 cmds2)))
        (elmtui.state:apply-patches state (elmtui.state.api:ur-patches res2))
        (is (null (find-if (lambda (cmd)
                             (and (consp cmd)
                                  (eq (first cmd) :render)
                                  (eq (second cmd) :clear)))
                  all-commands))
          "Startup should not clear for inline anchoring")
        (is (null (find-if (lambda (cmd)
                             (and (consp cmd)
                               (eq (first cmd) :render)
                               (eq (second cmd) :clear-below-cursor)))
                    all-commands))
          "Startup should not clear below cursor for inline anchoring")
        (is (find-if (lambda (cmd)
                       (and (consp cmd)
                         (eq (first cmd) :render)
                         (eq (second cmd) :scroll-down)
                         (= (third cmd) 1)))
              all-commands)
          "Should scroll down by 1 when viewport exceeds remaining rows")))))

;;;---------------------------------------------------------------
;;; Test: Below-cursor inline shutdown cleanup
;;;---------------------------------------------------------------

(test below-cursor-inline-shutdown-clears-rect-and-restores-scroll
  "Verify inline below-cursor shutdown blanks only the viewport area and restores scroll."
  (let* ((state (make-application-state))
          (rv (make-root-viewport :test-inline-cleanup :anchor :below-cursor))
          (id-path '(:components :test-inline-cleanup))
          (dsl '(:root-viewport :id :test-inline-cleanup :anchor :below-cursor
                  :width 10 :height 4 :child-dsl-spec (:view nil))))
    (multiple-value-bind (comp patches cmds)
      (init rv :id-path id-path :dsl dsl :anchor :below-cursor)
      (declare (ignore comp cmds))
      (elmtui.state:apply-patches state patches))
    (let* ((res1 (update rv '(:terminalresized :width 10 :height 4) state :id-path id-path)))
      (elmtui.state:apply-patches state (elmtui.state.api:ur-patches res1)))
    (let* ((res2 (update rv '(:cursorposition :col 1 :row 2) state :id-path id-path)))
      (elmtui.state:apply-patches state (elmtui.state.api:ur-patches res2)))
    (let* ((res3 (update rv '(:appshutdown) state :id-path id-path))
            (cmds3 (elmtui.state.api:ur-commands res3)))
      (is (find-if (lambda (cmd)
                     (and (consp cmd)
                       (eq (first cmd) :render)
                       (eq (second cmd) :blank-viewport)))
            cmds3)
        "Shutdown should blank the viewport rectangle")
      (is (null (find-if (lambda (cmd)
                           (and (consp cmd)
                             (eq (first cmd) :render)
                             (eq (second cmd) :clear-below-cursor)))
                  cmds3))
        "Shutdown should not clear below cursor for inline anchoring")
      (is (find-if (lambda (cmd)
                     (and (consp cmd)
                       (eq (first cmd) :render)
                       (eq (second cmd) :scroll-up)
                       (= (third cmd) 2)))
            cmds3)
        "Shutdown should restore scroll by 2"))))

;;;---------------------------------------------------------------
;;; Test: Below-cursor inline lifecycle with faketerm
;;;---------------------------------------------------------------

(test below-cursor-inline-faketerm-lifecycle
  "Verify inline below-cursor flow emits blank-viewport and scroll commands on faketerm."
  (let* ((filepath "/tmp/test-inline-faketerm.log")
          (backend (make-test-backend filepath))
          (state (make-application-state))
          (rv (make-root-viewport :test-inline-ft :anchor :below-cursor))
          (id-path '(:components :test-inline-ft))
          (dsl '(:root-viewport :id :test-inline-ft :anchor :below-cursor
                  :width 10 :height 4 :child-dsl-spec (:view nil))))
    (unwind-protect
      (progn
        (multiple-value-bind (comp patches cmds)
          (init rv :id-path id-path :dsl dsl :anchor :below-cursor)
          (declare (ignore comp cmds))
          (elmtui.state:apply-patches state patches))
        (let ((res1 (update rv '(:terminalresized :width 10 :height 4) state :id-path id-path)))
          (elmtui.state:apply-patches state (elmtui.state.api:ur-patches res1))
          (dolist (cmd (elmtui.state.api:ur-commands res1))
            (execute-render-command cmd backend)))
        (let ((res2 (update rv '(:cursorposition :col 1 :row 2) state :id-path id-path)))
          (elmtui.state:apply-patches state (elmtui.state.api:ur-patches res2))
          (dolist (cmd (elmtui.state.api:ur-commands res2))
            (execute-render-command cmd backend)))
        (let ((res3 (update rv '(:appshutdown) state :id-path id-path)))
          (dolist (cmd (elmtui.state.api:ur-commands res3))
            (execute-render-command cmd backend)))
        (shutdown-backend backend)
        (let* ((log (read-log-file filepath))
                (commands (parse-command-sequence log)))
          (is (find-command-pattern commands "BLANK_VIEWPORT")
            "Should blank viewport area in faketerm log")
          (is (find-command-pattern commands "SCROLL_DOWN")
            "Should scroll down to make space for inline viewport")
          (is (find-command-pattern commands "SCROLL_UP")
            "Should scroll up on shutdown to restore scroll")
          (is (null (find-command-pattern commands "CLEAR_BELOW_CURSOR"))
            "Should not clear below cursor in inline mode")))
      (ignore-errors (delete-file filepath)))))

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

;; (defun test-init-app-update (message app-state)
;;   (declare (ignore message app-state))
;;   (elmtui.ui.api:make-update-result))

;; (defun test-init-app-subscriptions (model)
;;   (declare (ignore model))
;;   nil)
;; (defun test-init-app-view (model)
;;   (log-info "Rendering test-init-app with model: ~A" model))

;; (elmtui.app:defapplication test-init-app
;;   :initial-state-plist `(:counter 0
;;                           :text "hello")
;;   :root-component-dsl '(;; :root-viewport :id :main-column passes
;;                          :root-viewport :id :main-column ;; fails
;;                          :initial-terminal-dimensions (1 1)
;;                          :initial-cursor-pos (1 1)
;;                          :children
;;                          ((:test-component :id :comp1 :initial-state "comp1 state")
;;                            (:test-parent-component :id :parent1 :child-initial-state "child state")))
;;   :view-fn test-init-app-view
;;   :update-fn test-init-app-update
;;   :root-viewport-id :rv
;;   :subscriptions-fn test-init-app-subscriptions)
;; (let* ((state (elmtui.state:make-application-state))
;;         (rv (make-root-viewport :test-rv2 :anchor :below-cursor))
;;         (id-path '(:components :test-rv2)))
;;   (multiple-value-bind (comp patches cmds)
;;     (init rv :id-path id-path
;;       :initial-terminal-dimensions '(80 24)
;;       :initial-cursor-pos '(0 18)
;;       :anchor :below-cursor)
;;     ;; (cl-state.patch:apply-patches state patches)
;;     (elmtui.state:apply-patches state patches)
;;     (list comp state patches cmds))
;;   (multiple-value-bind (patches3 cmds3)
;;     (update rv '(:terminal-scrolled :direction :up :amount 3) state :id-path id-path)
;;     (declare (ignore cmds3))
;;     (elmtui.state:apply-patches state patches3))
;;   (state-ref state (append id-path '(:issued-scroll-net))))

(defun get-prop (state compid prop)
  (state-ref state (list :components compid prop)))
(test scroll-net-tracking
  "Only ordered acknowledgments consume pending effects and record displacement."
  (let* ((state (elmtui.state:make-application-state))
          (rv (make-root-viewport :test-rv2 :anchor :below-cursor))
          (id-path '(:components :test-rv2)))

    ;; Initialize
    (multiple-value-bind (comp patches cmds)
      (init rv :id-path id-path
        :initial-terminal-dimensions '(80 24)
        :initial-cursor-pos '(0 18)
        :anchor :below-cursor)
      (declare (ignore comp cmds))
      (elmtui.state:apply-patches state patches))

    ;; These are pre-issued scrolls awaiting ordered terminal notifications.
    (setf (state-ref state (append id-path '(:issued-scroll-net))) 4
          (state-ref state (append id-path '(:pending-scroll-ops))) '(3 2 -1))
    ;; Simulate scroll completions
    (let ((result1 (update rv '(:terminal-scrolled :direction :down :amount 3) state :id-path id-path)))
      (elmtui.state:apply-patches state (elmtui.state.api:ur-patches result1)))

    (let ((result2 (update rv '(:terminal-scrolled :direction :down :amount 2) state :id-path id-path)))
      (elmtui.state:apply-patches state (elmtui.state.api:ur-patches result2)))

    (let ((result3 (update rv '(:terminal-scrolled :direction :up :amount 1) state :id-path id-path)))
      (elmtui.state:apply-patches state (elmtui.state.api:ur-patches result3)))

    ;; Requested scrolls are consumed, while committed displacement survives.
    (is (= 0 (state-ref state (append id-path '(:issued-scroll-net)))))
    (is (null (state-ref state (append id-path '(:pending-scroll-ops)))))
    (is (= 4 (state-ref state (append id-path '(:scrolled-net)))))
    (is (equal '(0 14) (state-ref state (append id-path '(:cursor-pos)))))
    (let ((result (update rv '(:terminal-scrolled :direction :down :amount 4)
                          state :id-path id-path)))
      (elmtui.state:apply-patches state (elmtui.state.api:ur-patches result)))
    (is (= 4 (state-ref state (append id-path '(:scrolled-net))))
        "An unsolicited duplicate acknowledgment must not mutate scroll state")))

(test nested-viewport-scroll-is-local
  "An inner viewport moves its content without issuing terminal scroll effects."
  (let* ((state (make-application-state))
         (vp (elmtui.ui.widgets.viewport:make-viewport :id :inner))
         (id-path '(:components :inner)))
    (multiple-value-bind (component patches commands)
        (init vp :id-path id-path :initial-width 20 :initial-height 150)
      (declare (ignore component commands))
      (elmtui.state:apply-patches state patches))
    (let* ((result (update vp '(:scroll-by :dx 0 :dy 5) state :id-path id-path))
           (commands (elmtui.state.api:ur-commands result)))
      (elmtui.state:apply-patches state (elmtui.state.api:ur-patches result))
      (is (null (remove-if-not
                 (lambda (cmd)
                   (and (consp cmd) (eq (first cmd) :render)
                        (member (second cmd) '(:scroll-up :scroll-down :scroll))))
                 commands)))
      (is (= 5 (state-ref state (append id-path '(:scroll-y))))))))

(test driver-scroll-effect-produces-ordered-notification
  "The real effect executor reports the direction and magnitude it executed."
  (let* ((filepath "/tmp/test-scroll-ack.log")
         (backend (make-test-backend filepath))
         (messages nil))
    (unwind-protect
        (progn
          (is (elmtui.platform.driver::%execute-render-command-and-notify
               '(:render :scroll-down 3) backend
               (lambda (msg) (push msg messages))))
          (is (equal '(:terminal-scrolled :direction :down :amount 3)
                     (first messages)))
          (is (elmtui.platform.driver::%execute-render-command-and-notify
               '(:render :scroll-up 2) backend
               (lambda (msg) (push msg messages))))
          (is (equal '(:terminal-scrolled :direction :up :amount 2)
                     (first messages))))
      (shutdown-backend backend)
      (ignore-errors (delete-file filepath)))))


;; (let* ((state (elmtui.state:make-application-state))
;;         (rv (make-root-viewport :test-rv2 :anchor :below-cursor))
;;         (id-path '(:components :test-rv2)))

;;   ;; Initialize
;;   (multiple-value-bind (comp patches cmds)
;;     (init rv :id-path id-path
;;       :initial-terminal-dimensions '(80 24)
;;       :initial-cursor-pos '(0 18)
;;       :anchor :below-cursor)
;;     (elmtui.state:apply-patches state patches))

;;   ;; Simulate scroll events
;;   (multiple-value-bind (patches1 cmds1)
;;     (update rv '(:terminal-scrolled :direction :down :amount 3) state :id-path id-path)
;;     (declare (ignore cmds1))
;;     (elmtui.state:apply-patches state patches1))

;;   (multiple-value-bind (patches2 cmds2)
;;     (update rv '(:terminal-scrolled :direction :down :amount 2) state :id-path id-path)
;;     (declare (ignore cmds2))
;;     (elmtui.state:apply-patches state patches2))

;;   (multiple-value-bind (patches3 cmds3)
;;     (update rv '(:terminal-scrolled :direction :up :amount 1) state :id-path id-path)
;;     (declare (ignore cmds3))
;;     (elmtui.state:apply-patches state patches3))

;;   ;; Check accumulated scroll
;;   (let ((net-scroll
;;           (state-ref state (list :components :test-rv2 :issued-scroll-net))))
;;      (format nil "Net scroll got ~A should be 3 + 2 - 1 = 4"
;;                            net-scroll)))
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
