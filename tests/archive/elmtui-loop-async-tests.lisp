;; ;;;===============================================================
;; ;;; File: tests/elmtui-loop-async-tests.lisp
;; ;;; FiveAM Unit Tests for Step 2: Event Loop & Async Interpreter

;; (defpackage :elmtui-loop-async-tests
;;   (:use :cl :fiveam
;;         :elmtui.core.loop
;;    :elmtui.core.async
;;         :elmtui.core.events ; For make-message, publish
;;    :elmtui.core.conditions)
;;   (:import-from :cleve-elm.api :event-type)
;;   (:import-from :cleve-elm.event :event)
;;   (:import-from :elmtui.core.async
;;    :await-cmd
;;                 :async-task-finished-p            :cmd-batch
;;                 :cancel-cmd
;;    :cmd-async :interpret-cmd)
;;   (:import-from :elmtui.core.loop :start-loop :stop-loop
;;    :event-loop-active-p
;;                 :subscribe :unsubscribe
;;                 :publish
;;                 ;; For testing async task cancellation
;;                 ))

;; (in-package :elmtui-loop-async-tests)

;; ;; (def-suite step2-loop-async)
;; ;; (in-suite step2-loop-async)

;; ;; ;;; 0. Helper to ensure loop is stopped and state is clean
;; ;; (defun ensure-loop-stopped ()
;; ;;   (when (elmtui.core.loop:elm-event-loop-active-p) ; Use the exported function
;; ;;     (elmtui.core.loop:elm-stop-loop))
;; ;;   ;; Clear elmtui.core.loop's own subscriber table
;; ;;   (setf elmtui.core.loop::*subscribers* (make-hash-table :test 'equal))
;; ;;   (setf elmtui.core.loop::*event-loop-instrumentation-hooks* nil)
;; ;;   ;; Assuming lifecycle-hooks are managed within elmtui.core.loop if specific to it
;; ;;   ;; If elmtui.core.loop::*lifecycle-hooks* is the correct variable:
;; ;;   (when (boundp 'elmtui.core.loop::*lifecycle-hooks*)
;; ;;     (setf elmtui.core.loop::*lifecycle-hooks* (make-hash-table :test 'equal))))

;; ;; (def-fixture ensure-stopped ()
;; ;;   (ensure-loop-stopped) ; Stop before test
;; ;;   (&body)
;; ;;   (ensure-loop-stopped)) ; Stop after test

;; ;; ;;; 1. Event loop subscriber management (add/remove)
;; ;; (defvar *loop-handler-called* nil)
;; ;; (defun loop-handler (event) (setf *loop-handler-called* (event-type event)))
;; ;; (test event-loop-subscriber-management
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (setf *loop-handler-called* nil)
;; ;;     (let ((token (subscribe :test-loop #'loop-handler)))
;; ;;       (publish (make-instance 'cleve-elm.event:event :event-type :test-loop))
;; ;;       (is (eq *loop-handler-called* :test-loop) "Handler should be called after subscribe and publish.")
;; ;;       (is (unsubscribe token) "Unsubscribe should return T for a valid token.")
;; ;;       (setf *loop-handler-called* nil)
;; ;;       (publish (make-instance 'cleve-elm.event:event :event-type :test-loop))
;; ;;       (is (null *loop-handler-called*) "Handler should not be called after unsubscribe."))))

;; ;; ;;; 1.5 Test unsubscribing with invalid token
;; ;; (test event-loop-unsubscribe-invalid
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (let ((invalid-token "invalid-token")
;; ;;           (malformed-token-no-type '(:handler #'loop-handler))
;; ;;           (malformed-token-no-handler '(:event-type :test)))
;; ;;       ;; Should not signal an error, just do nothing or return nil
;; ;;       (is (null (unsubscribe invalid-token)) "Unsubscribing with a string token should return NIL.")
;; ;;       (is (null (unsubscribe malformed-token-no-type)) "Unsubscribing with malformed token (no type) should return NIL.")
;; ;;       (is (null (unsubscribe malformed-token-no-handler)) "Unsubscribing with malformed token (no handler) should return NIL.")
;; ;;       (is (null (unsubscribe '(:event-type :non-existent :handler #'loop-handler))) "Unsubscribing a non-existent handler should return NIL."))))

;; ;; ;;; 2. Event loop graceful shutdown and restart
;; ;; (test event-loop-shutdown-restart
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (start-loop :fps 10)
;; ;;     (is (event-loop-active-p))
;; ;;     (stop-loop)
;; ;;     (is (not (event-loop-active-p)))
;; ;;     (start-loop :fps 10)
;; ;;     (is (event-loop-active-p))
;; ;;     (stop-loop)))

;; ;; ;;; 3. Async command execution and error handling
;; ;; (defvar *async-result* nil)
;; ;; (defun async-ok () 42)
;; ;; (defun async-fail () (error "Async error"))
;; ;; (test async-command-execution
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (let ((cmd (cmd-async #'async-ok)))
;; ;;       (interpret-cmd cmd)
;; ;;       (is (= (await-cmd cmd) 42)))
;; ;;     (let ((cmd (cmd-async #'async-fail)))
;; ;;       (is (signals elmtui.core.conditions:async-task-error
;; ;;             (progn (interpret-cmd cmd) (await-cmd cmd)))))))

;; ;; ;;; 4. Async command batching and cancellation
;; ;; (test async-batch-cancel
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (let ((cmd1 (cmd-async (lambda () (sleep 0.1) 1)))
;; ;;           (cmd2 (cmd-async (lambda () (sleep 0.1) 2))))
;; ;;       (let ((batch (cmd-batch cmd1 cmd2)))
;; ;;         (interpret-cmd batch)
;; ;;         (cancel-cmd batch)
;; ;;         ;; Cancellation might be asynchronous, give a moment
;; ;;         (sleep 0.05)
;; ;;         (is (every #'identity
;; ;;                    (mapcar #'async-task-finished-p (list (cadr cmd1) (cadr cmd2)))))))))

;; ;; ;;; 5. Instrumentation hooks and error isolation
;; ;; (defvar *instrumented-events* nil)
;; ;; (defun instrument-hook (event) (push (event-type event) *instrumented-events*))
;; ;; (test event-loop-instrumentation
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (setf *instrumented-events* nil)
;; ;;     (push #'instrument-hook elmtui.core.loop::*event-loop-instrumentation-hooks*)
;; ;;     (publish (make-instance 'cleve-elm.event:event :event-type :instr))
;; ;;     (is (member :instr *instrumented-events*))
;; ;;     (setf elmtui.core.loop::*event-loop-instrumentation-hooks* nil)))

;; ;; ;;; 6. Event loop error isolation (handler error does not stop loop)
;; ;; (defvar *isolation-called* nil)
;; ;; (defun isolation-handler (event)
;; ;;   (declare (ignore event))
;; ;;   (setf *isolation-called* t)
;; ;;   (error "Handler isolation test"))
;; ;; (test event-loop-error-isolation
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (setf *isolation-called* nil)
;; ;;     (let ((token (subscribe :isolate #'isolation-handler)))
;; ;;       (is (signals elmtui.core.conditions:subscriber-handler-error
;; ;;             (publish (make-instance 'cleve-elm.event:event :event-type :isolate))))
;; ;;       (is (not (null *isolation-called*)))
;; ;;       (is (unsubscribe token)))))

;; ;; ;;; 6.5 Subscriber Priorities
;; ;; (defvar *priority-call-order* nil)
;; ;; (defun prio-handler-1 (event) (declare (ignore event)) (push 1 *priority-call-order*))
;; ;; (defun prio-handler-2 (event) (declare (ignore event)) (push 2 *priority-call-order*))
;; ;; (defun prio-handler-3 (event) (declare (ignore event)) (push 3 *priority-call-order*))
;; ;; (test event-loop-subscriber-priority
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (setf *priority-call-order* nil)
;; ;;     ;; Subscribe in non-priority order
;; ;;     (let ((t2 (elmtui.core.loop::subscribe-with-priority :prio-test #'prio-handler-2 5))
;; ;;           (t1 (elmtui.core.loop::subscribe-with-priority :prio-test #'prio-handler-1 10)) ; Higher priority first
;; ;;           (t3 (elmtui.core.loop::subscribe-with-priority :prio-test #'prio-handler-3 1)))
;; ;;       (publish (make-instance 'cleve-elm.event:event :event-type :prio-test))
;; ;;       ;; Check they were called in priority order (should be 1,2,3)
;; ;;       (is (equal (reverse *priority-call-order*) '(1 2 3)))
;; ;;       (is (unsubscribe t1))
;; ;;       (is (unsubscribe t2))
;; ;;       (is (unsubscribe t3)))))


;; ;; ;;; 7. Advanced instrumentation hooks (timing/metrics/tracing) - API Check
;; ;; ;; TODO: Uncomment when advanced instrumentation hooks are implemented (Roadmap item 2, TODO)
;; ;; #|
;; ;; (test event-loop-instrumentation-hooks-api
;; ;; (with-fixture ensure-stopped ()
;; ;; (is (fboundp (find-symbol "ADD-INSTRUMENTATION-HOOK" "ELMTUI.CORE.LOOP")))
;; ;; (is (fboundp (find-symbol "REMOVE-INSTRUMENTATION-HOOK" "ELMTUI.CORE.LOOP")))))
;; ;; |#

;; ;; ;;; 8. Event loop pausing/resuming - API Check
;; ;; ;; TODO: Uncomment when event loop pausing/resuming is implemented (Roadmap item 2, TODO)
;; ;; #|
;; ;; (test event-loop-pausing-resuming-api
;; ;; (with-fixture ensure-stopped ()
;; ;; (is (fboundp (find-symbol "PAUSE-LOOP" "ELMTUI.CORE.LOOP")))
;; ;; (is (fboundp (find-symbol "RESUME-LOOP" "ELMTUI.CORE.LOOP")))))
;; ;; |#

;; ;; ;;; 9. Event queue inspection and replay - API Check
;; ;; ;; TODO: Uncomment when event queue inspection/replay is implemented (Roadmap item 2, TODO)
;; ;; #|
;; ;; (test event-queue-inspection-replay-api
;; ;; (with-fixture ensure-stopped ()
;; ;; (is (fboundp (find-symbol "INSPECT-EVENT-QUEUE" "ELMTUI.CORE.LOOP")))
;; ;; (is (fboundp (find-symbol "REPLAY-EVENT-QUEUE" "ELMTUI.CORE.LOOP")))))
;; ;; |#

;; ;; ;;; 10. Event deduplication and filtering - API Check
;; ;; ;; TODO: Uncomment when event deduplication/filtering is implemented (Roadmap item 1 & 2, TODOs)
;; ;; #|
;; ;; (test event-deduplication-filtering-api
;; ;; (with-fixture ensure-stopped ()
;; ;; (is (fboundp (find-symbol "SET-EVENT-DEDUPLICATION" "ELMTUI.CORE.LOOP")))
;; ;; (is (fboundp (find-symbol "SET-EVENT-FILTER" "ELMTUI.CORE.LOOP")))))
;; ;; |#

;; ;; ;;; 11. Event loop lifecycle hooks - API Check & Basic Call Test
;; ;; (defvar *lifecycle-hook-called* nil)
;; ;; (defun test-lifecycle-hook (hook-type &rest args)
;; ;;   (declare (ignore args))
;; ;;   (setf *lifecycle-hook-called* hook-type))

;; ;; (test event-loop-lifecycle-hooks
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (let ((add-hook-sym (find-symbol "ADD-LIFECYCLE-HOOK" "ELMTUI.CORE.LOOP"))
;; ;;           (remove-hook-sym (find-symbol "REMOVE-LIFECYCLE-HOOK" "ELMTUI.CORE.LOOP")))
;; ;;       (is (fboundp add-hook-sym))
;; ;;       (is (fboundp remove-hook-sym))
;; ;;       ;; Test basic hook call
;; ;;       (setf *lifecycle-hook-called* nil)
;; ;;       (when (and add-hook-sym (fboundp add-hook-sym))
;; ;;         (funcall add-hook-sym :before-dispatch #'test-lifecycle-hook))
;; ;;       (publish (make-instance 'cleve-elm.event:event :event-type :lifecycle-test))
;; ;;       ;; This check depends on the hook being successfully added and called
;; ;;       (if (and add-hook-sym (fboundp add-hook-sym))
;; ;;           (is (eq *lifecycle-hook-called* :before-dispatch))
;; ;;           (warn "ADD-LIFECYCLE-HOOK not found or not fboundp, cannot verify hook call."))
;; ;;       (when (and remove-hook-sym (fboundp remove-hook-sym))
;; ;;         (funcall remove-hook-sym :before-dispatch #'test-lifecycle-hook)))))

;; ;; ;;; 12. Async task cancellation API (single task)
;; ;; (test async-task-cancellation-api
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (is (fboundp 'elmtui.core.async:cancel-cmd)))
;; ;;   ;; Test cancelling already finished task
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (let ((cmd (cmd-async #'async-ok)))
;; ;;       (interpret-cmd cmd)
;; ;;       (await-cmd cmd) ; Ensure it's finished
;; ;;       (is (eq :cancelled (cancel-cmd cmd))))) ; Should likely return :cancelled or similar
;; ;;   ;; Test cancelling errored task
;; ;;   (with-fixture ensure-stopped ()
;; ;;     (let ((cmd (cmd-async #'async-fail)))
;; ;;       (signals elmtui.core.conditions:async-task-error (interpret-cmd cmd))
;; ;;       (is (eq :cancelled (cancel-cmd cmd))))))

;; ;; ;;; 13. Async task progress reporting - API Check
;; ;; ;; (test async-task-progress-reporting-api
;; ;; ;;   (with-fixture ensure-stopped ()
;; ;; ;;     (is (fboundp 'elmtui.core.async:cmd-progress))
;; ;; ;;     (is (fboundp 'elmtui.core.async:await-progress))))

;; ;; ;;; Run all tests
;; ;; ;;; #-asdf
;; ;; ;;; (run! 'step2-loop-async) ; Now handled by elmtui-all-tests:run-all-elmtui-tests
