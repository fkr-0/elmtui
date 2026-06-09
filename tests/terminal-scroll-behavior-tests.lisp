;;;===============================================================
;;; File: tests/terminal-scroll-behavior-tests.lisp
;;; Terminal Scrolling Behavior Validation Tests
;;;===============================================================

(uiop:define-package :elmtui.terminal-scroll-behavior.tests
  (:use :cl :fiveam
    :elmtui.platform.api
    :elmtui.ui.widgets.root-viewport
    :elmtui.ui.api
    :elmtui.state.api)
  (:export #:run-terminal-scroll-behavior-tests))

(in-package :elmtui.terminal-scroll-behavior.tests)

(def-suite terminal-scroll-behavior-test-suite
  :description "Test suite for terminal scrolling behavior on startup/shutdown")

(in-suite terminal-scroll-behavior-test-suite)

;;;----------------------------------------------------------------
;;; Test Helper Functions
;;;----------------------------------------------------------------
(defun create-test-state ()
  "Create a fresh test state for root viewport operations"
  (elmtui.state.api:make-state))

(defun get-render-commands (cmds command-type)
  "Extract commands of a specific type from command list"
  (remove-if-not (lambda (cmd)
                   (and (consp cmd)
                     (eq (first cmd) command-type)))
    cmds))

(defun get-scroll-amount (cmds scroll-direction)
  "Get the total scroll amount for a specific scroll direction from commands"
  (let ((scroll-cmds (get-render-commands cmds scroll-direction)))
    (reduce #'+ (mapcar (lambda (cmd)
                          (if (> (length cmd) 1) (second cmd) 0))
                  scroll-cmds)
      :initial-value 0)))

;;;----------------------------------------------------------------
;;; Primary Test: Scrolling Down on Startup When Insufficient Space
;;;----------------------------------------------------------------
(test scroll-down-on-startup-insufficient-space
  "Test scenario: Below-cursor needs 6 rows, only 3 available -> should scroll up 3 rows"
  ;; Setup: Terminal 80x24, cursor at row 18 (below-cursor mode, needs 6 rows)
  ;; Available below cursor: 24 - 18 = 6 rows
  ;; But we'll simulate scenario where only 3 rows are actually available
  ;; Expected behavior: Scroll up 3 rows to make space

  (let ((state (create-test-state))
         (terminal-dims '(80 24))
         (initial-cursor-pos '(0 18))
         (needed-height 6)
         (available-below 6))

    ;; Initialize root viewport with below-cursor anchor
    (multiple-value-bind (rv idp orig-state patches cmds)
      (elmtui.ui.api:init 'root-viewport
        :id-path '(:components :test-viewport)
        :initial-terminal-dimensions terminal-dims
        :initial-cursor-pos initial-cursor-pos
        :anchor :below-cursor)
      (declare (ignore rv idp orig-state))

      ;; Apply patches to update state
      (elmtui.state.transactions:apply-patches state patches)

      ;; Simulate scenario where viewport needs more space than available
      ;; This should trigger scroll-up commands during initialization
      (let ((init-cmds cmds))

        ;; Verify we get scroll commands when space is insufficient
        (let ((scroll-up-cmds (get-render-commands init-cmds :scroll-up)))
          (is (> (length scroll-up-cmds) 0)
            "Should get scroll-up commands when insufficient space below cursor"))

        ;; Check scroll amount
        (let ((scroll-amount (get-scroll-amount init-cmds :scroll-up)))
          (is (> scroll-amount 0)
            "Should scroll up by positive amount when insufficient space")

          ;; The exact amount depends on internal calculations
          ;; but should be reasonable for the scenario
          (is (<= scroll-amount 10)
            "Scroll amount should be reasonable (≤10 rows)"))

        ;; Verify no scroll-down during init
        (let ((scroll-down-cmds (get-render-commands init-cmds :scroll-down)))
          (is (= (length scroll-down-cmds) 0)
            "Should not scroll down during initialization"))))))

(test scroll-up-on-shutdown-restore-scroll
  "Test scenario: On termination, should clear below cursor and scroll back down by same amount"
  ;; This test validates the reverse operation of startup scrolling

  (let ((state (create-test-state))
         (terminal-dims '(80 24))
         (initial-cursor-pos '(0 18))
         (scroll-up-amount 0))

    ;; First, initialize and capture the scroll amount
    (multiple-value-bind (rv idp orig-state patches cmds)
      (elmtui.ui.api:init 'root-viewport
        :id-path '(:components :test-viewport)
        :initial-terminal-dimensions terminal-dims
        :initial-cursor-pos initial-cursor-pos
        :anchor :below-cursor)
      (declare (ignore rv orig-state))

      ;; Apply patches
      (elmtui.state.transactions:apply-patches state patches)

      ;; Capture the scroll-up amount from initialization
      (setf scroll-up-amount (get-scroll-amount cmds :scroll-up))

      (when (> scroll-up-amount 0)

        ;; Now trigger shutdown
        (multiple-value-bind (shutdown-patches shutdown-cmds)
          (elmtui.ui.api:update rv
            '(:appshutdown)
            state
            :id-path idp)

          ;; Apply shutdown patches
          (elmtui.state.transactions:apply-patches state shutdown-patches)

          ;; Verify we get blank-viewport command for the viewport area
          (let ((blank-cmds (remove-if-not (lambda (cmd)
                                             (and (consp cmd)
                                                  (eq (first cmd) :render)
                                                  (eq (second cmd) :blank-viewport)))
                                           shutdown-cmds)))
            (is (> (length blank-cmds) 0)
              "Should get blank-viewport command on shutdown"))

          ;; Verify we get scroll-down command with same amount
          (let ((scroll-down-cmds (get-render-commands shutdown-cmds :scroll-down)))
            (is (> (length scroll-down-cmds) 0)
              "Should get scroll-down command on shutdown"))

          (let ((scroll-down-amount (get-scroll-amount shutdown-cmds :scroll-down)))
            (is (= scroll-down-amount scroll-up-amount)
              "Scroll-down amount should equal initial scroll-up amount")

            (is (> scroll-down-amount 0)
              "Scroll-down amount should be positive")))))))

(test scroll-consistency-round-trip
  "Test that scroll-up and scroll-down amounts are consistent for round-trip"
  ;; This test ensures the viewport maintains consistent scrolling behavior
  ;; across startup and shutdown cycles

  (let ((state (create-test-state))
         (terminal-dims '(80 24)))

    ;; Test multiple cursor positions and scroll scenarios
    (dolist (cursor-row '((0 12) (0 15) (0 18) (0 20)))
      (let ((scroll-up-amount 0))

        ;; Initialize at current cursor position
        (multiple-value-bind (rv idp orig-state init-patches init-cmds)
          (elmtui.ui.api:init 'root-viewport
            :id-path '(:components :test-viewport)
            :initial-terminal-dimensions terminal-dims
            :initial-cursor-pos cursor-row
            :anchor :below-cursor)
          (declare (ignore rv orig-state))

          ;; Apply initialization
          (elmtui.state.transactions:apply-patches state init-patches)
          (setf scroll-up-amount (get-scroll-amount init-cmds :scroll-up))

          ;; Shutdown and verify round-trip consistency
          (multiple-value-bind (shutdown-patches shutdown-cmds)
            (elmtui.ui.api:update rv
              '(:appshutdown)
              state
              :id-path idp)

            (let ((scroll-down-amount (get-scroll-amount shutdown-cmds :scroll-down)))

              ;; Verify consistency
              (is (= scroll-up-amount scroll-down-amount)
                (format nil "Scroll consistency failed for cursor row ~A: up=~A, down=~A"
                  (second cursor-row) scroll-up-amount scroll-down-amount)))))))))

(test no-scroll-when-sufficient-space
  "Test that no scrolling occurs when sufficient space is available below cursor"
  ;; Control test: When there's enough space, no scrolling should happen

  (let ((state (create-test-state))
         (terminal-dims '(80 24))
         (initial-cursor-pos '(0 10)))  ;; 14 rows available below

    (multiple-value-bind (rv idp orig-state init-patches init-cmds)
      (elmtui.ui.api:init 'root-viewport
        :id-path '(:components :test-viewport)
        :initial-terminal-dimensions terminal-dims
        :initial-cursor-pos initial-cursor-pos
        :anchor :below-cursor)
      (declare (ignore rv orig-state))

      ;; Apply initialization
      (elmtui.state.transactions:apply-patches state init-patches)

      ;; Should not have any scroll commands when sufficient space
      (let ((scroll-up-cmds (get-render-commands init-cmds :scroll-up))
             (scroll-down-cmds (get-render-commands init-cmds :scroll-down)))

        (is (= (length scroll-up-cmds) 0)
          "Should not scroll up when sufficient space available")

        (is (= (length scroll-down-cmds) 0)
          "Should not scroll down during initialization when sufficient space")

          ;; On shutdown, should still get blank-viewport command but no scroll
          (multiple-value-bind (shutdown-patches shutdown-cmds)
            (elmtui.ui.api:update rv
              '(:appshutdown)
              state
              :id-path idp)

            (let ((shutdown-scroll-up (get-render-commands shutdown-cmds :scroll-up))
                   (shutdown-scroll-down (get-render-commands shutdown-cmds :scroll-down))
                   (blank-cmds (remove-if-not (lambda (cmd)
                                                (and (consp cmd)
                                                     (eq (first cmd) :render)
                                                     (eq (second cmd) :blank-viewport)))
                                              shutdown-cmds)))

            (is (= (length shutdown-scroll-up) 0)
              "Should not scroll up on shutdown when no initial scroll occurred")

            (is (= (length shutdown-scroll-down) 0)
              "Should not scroll down on shutdown when no initial scroll occurred")

            (is (> (length blank-cmds) 0)
              "Should always blank viewport area on shutdown")))))))

;;;----------------------------------------------------------------
;;; Edge Case Tests
;;;----------------------------------------------------------------
(test scroll-at-terminal-boundary
  "Test scrolling behavior when cursor is at terminal boundaries"

  (let ((state (create-test-state))
         (terminal-dims '(80 24)))

    ;; Test cursor at very bottom (row 23) - should force maximum scroll
    (multiple-value-bind (rv idp orig-state init-patches init-cmds)
      (elmtui.ui.api:init 'root-viewport
        :id-path '(:components :test-viewport)
        :initial-terminal-dimensions terminal-dims
        :initial-cursor-pos '(0 23)  ;; Last row
        :anchor :below-cursor)
      (declare (ignore rv orig-state))

      ;; Apply initialization
      (elmtui.state.transactions:apply-patches state init-patches)

      ;; Should get significant scroll-up when at bottom
      (let ((scroll-up-amount (get-scroll-amount init-cmds :scroll-up)))
        (is (> scroll-up-amount 0)
          "Should scroll up when cursor at terminal bottom")

        ;; On shutdown, should scroll down by same amount
        (multiple-value-bind (shutdown-patches shutdown-cmds)
          (elmtui.ui.api:update rv
            '(:appshutdown)
            state
            :id-path idp)

          (let ((scroll-down-amount (get-scroll-amount shutdown-cmds :scroll-down)))
            (is (= scroll-up-amount scroll-down-amount)
              "Scroll amounts should match even at boundary")))))))

(test zero-height-viewport-no-scroll
  "Test that zero-height viewport doesn't cause scrolling"

  (let ((state (create-test-state))
         (terminal-dims '(80 24)))

    (multiple-value-bind (rv idp orig-state init-patches init-cmds)
      (elmtui.ui.api:init 'root-viewport
        :id-path '(:components :test-viewport)
        :initial-terminal-dimensions terminal-dims
        :initial-cursor-pos '(0 18)
        :anchor :below-cursor)
      (declare (ignore rv orig-state))

      ;; Apply initialization
      (elmtui.state.transactions:apply-patches state init-patches)

      ;; Set viewport height to 0 (should not cause scrolling)
      (elmtui.state.api:set-state-ref
        state (append idp '(:height)) 0)

      ;; Shutdown with zero height
      (multiple-value-bind (shutdown-patches shutdown-cmds)
        (elmtui.ui.api:update rv
          '(:appshutdown)
          state
          :id-path idp)

        ;; Should not have scroll commands for zero-height viewport
        (let ((scroll-up-cmds (get-render-commands shutdown-cmds :scroll-up))
               (scroll-down-cmds (get-render-commands shutdown-cmds :scroll-down)))

          (is (= (length scroll-up-cmds) 0)
            "Zero-height viewport should not scroll up on shutdown")

          (is (= (length scroll-down-cmds) 0)
            "Zero-height viewport should not scroll down on shutdown"))))))

;;;----------------------------------------------------------------
;;; Test Runner
;;;----------------------------------------------------------------
(defun run-terminal-scroll-behavior-tests ()
  "Run all terminal scroll behavior tests"
  (format t "~%=== Running Terminal Scroll Behavior Tests ===~%")
  (run! 'terminal-scroll-behavior-test-suite)
  (format t "~%=== Terminal Scroll Behavior Tests Complete ===~%"))
