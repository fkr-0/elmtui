;;;===============================================================
;;; File: tests/elmtui-loop-async-tests.lisp
;;; FiveAM Unit Tests for Step 2: Event Loop & Async Interpreter

(defpackage :elmtui-loop-async-tests
  (:use :cl :fiveam
        :elmtui.core.loop
        :elmtui.core.async
        :elmtui.core.conditions))

(in-package :elmtui-loop-async-tests)

(def-suite step2-loop-async)
(in-suite step2-loop-async)

;;; 1. Event loop subscriber management (add/remove)
(defvar *loop-handler-called* nil)
(defun loop-handler (event) (setf *loop-handler-called* (event-type event)))
(test event-loop-subscriber-management
  (setf *loop-handler-called* nil)
  (let ((token (subscribe :test-loop #'loop-handler)))
    (publish (make-instance 'clevelib.event:event :event-type :test-loop))
    (is (eq *loop-handler-called* :test-loop))
    (unsubscribe token)
    (setf *loop-handler-called* nil)
    (publish (make-instance 'clevelib.event:event :event-type :test-loop))
    (is (null *loop-handler-called*))))

;;; 2. Event loop graceful shutdown and restart
(test event-loop-shutdown-restart
  (start-loop :fps 10)
  (is (event-loop-active-p))
  (stop-loop)
  (is (not (event-loop-active-p)))
  (start-loop :fps 10)
  (is (event-loop-active-p))
  (stop-loop))

;;; 3. Async command execution and error handling
(defvar *async-result* nil)
(defun async-ok () 42)
(defun async-fail () (error "Async error"))
(test async-command-execution
  (let ((cmd (cmd-async #'async-ok)))
    (interpret-cmd cmd)
    (is (= (await-cmd cmd) 42)))
  (let ((cmd (cmd-async #'async-fail)))
    (is (signals elmtui.core.conditions:async-task-error
                 (progn (interpret-cmd cmd) (await-cmd cmd))))))

;;; 4. Async command batching and cancellation
(test async-batch-cancel
  (let ((cmd1 (cmd-async (lambda () (sleep 0.1) 1)))
        (cmd2 (cmd-async (lambda () (sleep 0.1) 2))))
    (let ((batch (cmd-batch cmd1 cmd2)))
      (interpret-cmd batch)
      (cancel-cmd batch)
      (is (every #'identity
                 (mapcar #'async-task-finished-p (list (cadr cmd1) (cadr cmd2))))))))

;;; 5. Instrumentation hooks and error isolation
(defvar *instrumented-events* nil)
(defun instrument-hook (event) (push (event-type event) *instrumented-events*))
(test event-loop-instrumentation
  (setf *instrumented-events* nil)
  (push #'instrument-hook elmtui.core.loop::*event-loop-instrumentation-hooks*)
  (publish (make-instance 'clevelib.event:event :event-type :instr))
  (is (member :instr *instrumented-events*))
  (setf elmtui.core.loop::*event-loop-instrumentation-hooks* nil))

;;; 6. Event loop error isolation (handler error does not stop loop)
(defvar *isolation-called* nil)
(defun isolation-handler (event)
  (setf *isolation-called* t)
  (error "Handler isolation test"))
(test event-loop-error-isolation
  (setf *isolation-called* nil)
  (let ((token (subscribe :isolate #'isolation-handler)))
    (is (signals elmtui.core.conditions:subscriber-handler-error
                 (publish (make-instance 'clevelib.event:event :event-type :isolate))))
    (is *isolation-called*)
    (unsubscribe token)))

;;; 7. Advanced instrumentation hooks (timing/metrics/tracing)
(test event-loop-instrumentation-hooks-api
  (is (fboundp 'elmtui.core.loop:add-instrumentation-hook))
  (is (fboundp 'elmtui.core.loop:remove-instrumentation-hook)))

;;; 8. Event loop pausing/resuming
(test event-loop-pausing-resuming-api
  (is (fboundp 'elmtui.core.loop:pause-loop))
  (is (fboundp 'elmtui.core.loop:resume-loop)))

;;; 9. Event queue inspection and replay
(test event-queue-inspection-replay-api
  (is (fboundp 'elmtui.core.loop:inspect-event-queue))
  (is (fboundp 'elmtui.core.loop:replay-event-queue)))

;;; 10. Event deduplication and filtering
(test event-deduplication-filtering-api
  (is (fboundp 'elmtui.core.loop:set-event-deduplication))
  (is (fboundp 'elmtui.core.loop:set-event-filter)))

;;; 11. Event loop lifecycle hooks
(test event-loop-lifecycle-hooks-api
  (is (fboundp 'elmtui.core.loop:add-lifecycle-hook))
  (is (fboundp 'elmtui.core.loop:remove-lifecycle-hook)))

;;; 12. Async task cancellation API (single task)
(test async-task-cancellation-api
  (is (fboundp 'elmtui.core.async:cancel-cmd)))

;;; 13. Async task progress reporting
(test async-task-progress-reporting-api
  (is (fboundp 'elmtui.core.async:cmd-progress))
  (is (fboundp 'elmtui.core.async:await-progress)))

;;; Run all tests
#-asdf
(run! 'step2-loop-async)
