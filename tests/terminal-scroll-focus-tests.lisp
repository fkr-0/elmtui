;;;===============================================================
;;; File: tests/terminal-scroll-focus-tests.lisp
;;; Focused Terminal Scrolling Test - Your Specific Scenario
;;;===============================================================

(uiop:define-package :elmtui.terminal-scroll-focus.tests
  (:use :cl :fiveam 
        :elmtui.platform.api
        :elmtui.ui.widgets.root-viewport
        :elmtui.ui.api
        :elmtui.state.api)
  (:export #:run-terminal-scroll-focus-tests))

(in-package :elmtui.terminal-scroll-focus.tests)

(def-suite terminal-scroll-focus-test-suite
  :description "Focused test for terminal scrolling behavior")

(in-suite terminal-scroll-focus-test-suite)

;; Test for your specific scenario:
;; - Below-cursor anchor needs 6 rows
;; - Only 3 rows available 
;; - Should scroll up 3 rows on startup
;; - On termination: clear below cursor and scroll down 3 rows back
(test specific-scroll-scenario-below-cursor
  "Test YOUR scenario: below-cursor, 6 rows needed, 3 available -> scroll up 3, reverse on shutdown"
  
  (let ((state (elmtui.state.api:make-state)))
    
    ;; Step 1: Initialize root viewport at row 18, below-cursor anchor
    ;; Available below cursor: 24 - 18 = 6 rows
    ;; We'll manually force a scenario where viewport needs 6 rows but only 3 available
    (multiple-value-bind (rv idpath init-patch init-cmds)
        (elmtui.ui.api:init 'root-viewport 
                              :id-path '(:components :scroll-test)
                              :initial-terminal-dimensions '(80 24)
                              :initial-cursor-pos '(0 18)
                              :anchor :below-cursor)
      
      (declare (ignore rv idpath))
      
      ;; Apply initialization patches
      (elmtui.state.transactions:apply-patches state init-patch)
      
      ;; Step 2: Force scenario where viewport needs 6 rows but only 3 available
      ;; This simulates your specific case
      (elmtui.state.api:set-state-ref 
          state '(:components :scroll-test :height) 6)  ;; Need 6 rows
      (elmtui.state.api:set-state-ref 
          state '(:components :scroll-test :terminal-rows-below-cursor) 3)  ;; But only 3 available
      
      ;; Trigger update to handle space constraints
      (multiple-value-bind (update-patch update-cmds)
          (elmtui.ui.api:update rv
                                        '(:terminalresized :width 80 :height 24)
                                        state
                                        :id-path '(:components :scroll-test))
        
        (elmtui.state.transactions:apply-patches state update-patch)
        
        ;; Step 3: Verify scroll-up command was generated
        (let ((scroll-up-cmds (remove-if-not (lambda (cmd) 
                                           (and (consp cmd) (eq (first cmd) :scroll-up)))
                                         update-cmds)))
          
          (is (> (length scroll-up-cmds) 0)
              "Should generate scroll-up commands when insufficient space below cursor")
          
          (when scroll-up-cmds
            (let ((scroll-amount (second (first scroll-up-cmds))))
              (is (> scroll-amount 0)
                  "Scroll-up amount should be positive")
              
              (is (= scroll-amount 3)
                  "Should scroll up exactly 3 rows (6 needed - 3 available)"))))
        
        ;; Step 4: Test shutdown behavior
        (multiple-value-bind (shutdown-patch shutdown-cmds)
            (elmtui.ui.api:update rv
                                      '(:appshutdown)
                                      state
                                      :id-path '(:components :scroll-test))
          
          (elmtui.state.transactions:apply-patches state shutdown-patch)
          
          ;; Step 5: Verify blank-viewport command for the viewport area
          (let ((blank-cmds (remove-if-not (lambda (cmd)
                                             (and (consp cmd)
                                                  (eq (first cmd) :render)
                                                  (eq (second cmd) :blank-viewport)))
                                           shutdown-cmds)))
            (is (> (length blank-cmds) 0)
                "Should generate blank-viewport command on shutdown"))
          
          ;; Step 6: Verify scroll-down command to reverse the scroll
          (let ((scroll-down-cmds (remove-if-not (lambda (cmd) 
                                              (and (consp cmd) (eq (first cmd) :scroll-down)))
                                            shutdown-cmds)))
            
            (is (> (length scroll-down-cmds) 0)
                "Should generate scroll-down command on shutdown to reverse initial scroll")
            
            (when scroll-down-cmds
              (let ((scroll-down-amount (second (first scroll-down-cmds))))
                (is (> scroll-down-amount 0)
                    "Scroll-down amount should be positive")
                
                (is (= scroll-down-amount 3)
                    "Should scroll down exactly 3 rows to reverse initial scroll-up"))))))))))

;; Test the round-trip consistency
(test scroll-round-trip-consistency
  "Test that scroll-up and scroll-down amounts are perfectly consistent"
  
  (let ((state (elmtui.state.api:make-state)))
    
    ;; Initialize at different cursor positions and test consistency
    (dolist (cursor-row '((0 15) (0 18) (0 20)))
      
      (multiple-value-bind (rv idpath init-patch init-cmds)
          (elmtui.ui.api:init 'root-viewport 
                                :id-path '(:components :scroll-test)
                                :initial-terminal-dimensions '(80 24)
                                :initial-cursor-pos cursor-row
                                :anchor :below-cursor)
        
        (declare (ignore rv idpath))
        
        ;; Apply initialization
        (elmtui.state.transactions:apply-patches state init-patch)
        
        ;; Force constrained scenario
          (elmtui.state.api:set-state-ref 
            state '(:components :scroll-test :height) 8)  ;; Need 8 rows
          (elmtui.state.api:set-state-ref 
            state '(:components :scroll-test :terminal-rows-below-cursor) 4)  ;; But only 4 available
        
        ;; Trigger update
        (multiple-value-bind (update-patch update-cmds)
            (elmtui.ui.api:update rv
                                          '(:terminalresized :width 80 :height 24)
                                          state
                                          :id-path '(:components :scroll-test))
          
          (elmtui.state.transactions:apply-patches state update-patch)
          
          ;; Get scroll-up amount
          (let ((scroll-up-cmds (remove-if-not (lambda (cmd) 
                                             (and (consp cmd) (eq (first cmd) :scroll-up))
                                           update-cmds)))
            
            (when scroll-up-cmds
              (let ((scroll-up-amount (second (first scroll-up-cmds))))
                
                ;; Shutdown
                (multiple-value-bind (shutdown-patch shutdown-cmds)
                    (elmtui.ui.api:update rv
                                              '(:appshutdown)
                                              state
                                              :id-path '(:components :scroll-test))
                  
                  (elmtui.state.transactions:apply-patches state shutdown-patch)
                  
                  ;; Verify round-trip consistency
                  (let ((scroll-down-cmds (remove-if-not (lambda (cmd) 
                                                        (and (consp cmd) (eq (first cmd) :scroll-down))
                                                      shutdown-cmds)))
                    
                    (when scroll-down-cmds
                      (let ((scroll-down-amount (second (first scroll-down-cmds))))
                        (is (= scroll-up-amount scroll-down-amount)
                            (format nil "Scroll round-trip failed for cursor row ~A: up=~A, down=~A"
                                    (second cursor-row) scroll-up-amount scroll-down-amount))))))))))))))

(defun run-terminal-scroll-focus-tests ()
  "Run focused terminal scroll tests for YOUR specific scenario"
  (format t "~%=== Running Focused Terminal Scroll Tests ===~%")
  (format t "Testing: Below-cursor, 6 rows needed, 3 available -> scroll up 3, reverse on shutdown~%")
  (run! 'terminal-scroll-focus-test-suite)
  (format t "~%=== Focused Terminal Scroll Tests Complete ===~%"))
