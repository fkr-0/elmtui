;;; File: tests/condition-system-tests.lisp
;;; Behavioral tests for condition identity, restart scope, and debugger semantics.

(uiop:define-package :elmtui.tests.condition-system
  (:use :cl :fiveam)
  (:export #:condition-system-tests))

(in-package :elmtui.tests.condition-system)

(def-suite condition-system-tests
  :in elmtui.tests:elmtui-test
  :description "Common Lisp condition/restart/debugger semantics guaranteed by ElmTUI.")

(in-suite condition-system-tests)

(defun %make-state-error (&key (context '((:origin . :test)))
                               (message "state failed"))
  (make-condition 'elmtui.core.errors:state-error
                  :message message
                  :operation :update
                  :path '(:counter :value)
                  :state-type :plist
                  :context context
                  :suggestions '("inspect state")
                  :module :condition-test))

(defun %internal-restart-symbol (name package)
  (or (find-symbol name package)
      (error "Missing restart symbol ~A in package ~A" name package)))

(defun %find-internal-restart (name package &optional condition)
  (find-restart (%internal-restart-symbol name package) condition))

(defun %restart-names (&optional condition)
  (mapcar #'restart-name (compute-restarts condition)))

;;; ---------------------------------------------------------------------------
;;; Condition construction and diagnostic context
;;; ---------------------------------------------------------------------------

(test make-elmtui-error-preserves-structured-context-and-subtype-slots
  (let* ((context (list (cons :component-id :counter)))
         (condition
           (elmtui.core.errors:make-elmtui-error
            'elmtui.core.errors:state-error
            :message "invalid counter"
            :operation :write
            :path '(:counter :value)
            :state-type :plist
            :context context
            :suggestions '("retry" "inspect")
            :module :state-test)))
    (is (typep condition 'elmtui.core.errors:state-error))
    (is (eq context (elmtui.core.errors:elmtui-error-context condition)))
    (is (string= "invalid counter"
                 (elmtui.core.errors:elmtui-error-message condition)))
    (is (eq :write (elmtui.core.errors:state-error-operation condition)))
    (is (equal '(:counter :value)
               (elmtui.core.errors:state-error-path condition)))
    (is (eq :plist (elmtui.core.errors:state-error-type condition)))
    (is (equal '("retry" "inspect")
               (elmtui.core.errors:elmtui-error-suggestions condition)))))

(test with-error-context-preserves-exact-condition-identity-and-subtype-data
  (let* ((original
           (make-condition 'elmtui.core.errors:defcomponent-error
                           :message "bad component declaration"
                           :component-type :button
                           :component-id :save
                           :operation :expand
                           :macro-arg '(:width -1)
                           :validation-type :invalid-property
                           :context '((:phase . :macro))))
         (seen nil))
    (setf seen
          (handler-case
              (elmtui.core.errors:with-error-context
                  (:module :dsl :operation :validate :component-id :save)
                (error original))
            (elmtui.core.errors:defcomponent-error (condition)
              condition)))
    (is (eq original seen))
    (is (eq :invalid-property
            (elmtui.core.errors:defcomponent-error-validation-type original)))
    (is (equal '(:width -1)
               (elmtui.core.errors:defcomponent-error-arg original)))
    (is (eq :dsl (elmtui.core.errors:elmtui-error-module original)))
    (is (assoc :phase (elmtui.core.errors:elmtui-error-context original)))
    (is (assoc :operation (elmtui.core.errors:elmtui-error-context original)))
    (is (assoc :component-id (elmtui.core.errors:elmtui-error-context original)))))

(test with-error-context-evaluates-annotations-once
  (let ((evaluations 0)
        (condition (%make-state-error)))
    (handler-case
        (elmtui.core.errors:with-error-context
            (:context (progn (incf evaluations) :extra)
             :module (progn (incf evaluations) :module)
             :operation (progn (incf evaluations) :operation))
          (error condition))
      (elmtui.core.errors:state-error (_condition)
        (declare (ignore _condition))))
    (is (= 3 evaluations))))

(test nested-error-contexts-accumulate-on-one-condition
  (let ((condition (%make-state-error :context nil))
        (seen nil))
    (setf seen
          (handler-case
              (elmtui.core.errors:with-error-context (:module :outer :operation :outer-op)
                (elmtui.core.errors:with-error-context (:component-id :inner)
                  (error condition)))
            (elmtui.core.errors:state-error (signaled)
              signaled)))
    (is (eq condition seen))
    (let ((context (elmtui.core.errors:elmtui-error-context condition)))
      (is (assoc :component-id context))
      (is (assoc :operation context))
      (is (assoc :module context)))))

(test error-context-normalizes-atomic-existing-context
  (let ((condition (%make-state-error :context "legacy-context")))
    (handler-case
        (elmtui.core.errors:with-error-context (:operation :annotated)
          (error condition))
      (elmtui.core.errors:state-error (_condition)
        (declare (ignore _condition))))
    (is (equal "legacy-context"
               (cdr (assoc :context
                           (elmtui.core.errors:elmtui-error-context condition)))))
    (is (eq :annotated
            (cdr (assoc :operation
                        (elmtui.core.errors:elmtui-error-context condition)))))))

(test condition-report-and-print-object-keep-inspectable-diagnostics
  (let* ((condition (%make-state-error))
         (report (princ-to-string condition))
         (printed (with-output-to-string (stream)
                    (print-object condition stream))))
    (is (search "UPDATE" (string-upcase report)))
    (is (search "COUNTER" (string-upcase report)))
    (is (search "CONDITION-TEST" (string-upcase printed)))
    (is (search "COUNTER" (string-upcase printed)))))

;;; ---------------------------------------------------------------------------
;;; Condition family hierarchy
;;; ---------------------------------------------------------------------------

(test concrete-runtime-conditions-share-family-and-platform-stays-separate
  (dolist (type '(elmtui.core.conditions:message-validation-error
                  elmtui.core.conditions:command-execution-error
                  elmtui.core.conditions:event-loop-dispatch-error
                  elmtui.core.conditions:async-task-error
                  elmtui.core.conditions:state-update-error
                  elmtui.core.conditions:subscriber-handler-error
                  elmtui.core.conditions:render-error
                  elmtui.core.conditions:signal-subscriber-error))
    (is (subtypep type 'elmtui.core.errors:runtime-error)))
  (is (subtypep 'elmtui.core.errors:state-error 'elmtui.core.errors:runtime-error))
  (is (subtypep 'elmtui.core.errors:backend-error 'elmtui.core.errors:platform-error))
  (is (subtypep 'elmtui.core.errors:runtime-error 'elmtui.core.errors:elmtui-error))
  (is (subtypep 'elmtui.core.errors:platform-error 'elmtui.core.errors:elmtui-error))
  (is-false (subtypep 'elmtui.core.errors:platform-error 'elmtui.core.errors:runtime-error)))

;;; ---------------------------------------------------------------------------
;;; Generic WITH-RECOVERY contract
;;; ---------------------------------------------------------------------------

(test recovery-success-preserves-multiple-values
  (multiple-value-bind (a b c)
      (elmtui.core.conditions:with-recovery
          (elmtui.core.errors:state-error
           :on-error (lambda (_condition) (declare (ignore _condition)))
           :restarts '(:retry :use-value :abort))
        (values :a :b :c))
    (is (eq :a a))
    (is (eq :b b))
    (is (eq :c c))))

(test recovery-handler-sees-original-condition-with-selected-restarts-active
  (let* ((original (%make-state-error))
         (seen nil)
         (names nil)
         (result
           (handler-bind
               ((elmtui.core.errors:state-error
                  (lambda (condition)
                    (setf seen condition
                          names (%restart-names condition))
                    (is (find-restart 'use-value condition))
                    (is (find-restart 'abort condition))
                    (is (%find-internal-restart
                         "RETRY" :elmtui.core.conditions condition))
                    (is-false (%find-internal-restart
                               "SKIP" :elmtui.core.conditions condition))
                    (invoke-restart 'use-value :replacement))))
             (elmtui.core.conditions:with-recovery
                 (elmtui.core.errors:state-error
                  :on-error (lambda (_condition) (declare (ignore _condition)))
                  :restarts '(:retry :use-value :abort))
               (error original)))))
    (is (eq original seen))
    (is (member 'use-value names))
    (is (eq :replacement result))))

(test recovery-skip-and-ignore-task-return-nil
  (let ((skip-result
          (handler-bind
              ((elmtui.core.errors:state-error
                 (lambda (_condition)
                   (declare (ignore _condition))
                   (invoke-restart
                    (%find-internal-restart "SKIP" :elmtui.core.conditions)))))
            (elmtui.core.conditions:with-recovery
                (elmtui.core.errors:state-error
                 :on-error (lambda (_condition) (declare (ignore _condition)))
                 :restarts '(:skip))
              (error (%make-state-error)))))
        (ignore-result
          (handler-bind
              ((elmtui.core.errors:state-error
                 (lambda (_condition)
                   (declare (ignore _condition))
                   (invoke-restart
                    (%find-internal-restart "IGNORE-TASK" :elmtui.core.conditions)))))
            (elmtui.core.conditions:with-recovery
                (elmtui.core.errors:state-error
                 :on-error (lambda (_condition) (declare (ignore _condition)))
                 :restarts '(:ignore-task))
              (error (%make-state-error))))))
    (is-false skip-result)
    (is-false ignore-result)))

(test recovery-retry-reexecutes-the-protected-operation-exactly
  (let ((attempts 0)
        (handled 0))
    (let ((result
            (handler-bind
                ((elmtui.core.errors:state-error
                   (lambda (_condition)
                     (declare (ignore _condition))
                     (incf handled)
                     (invoke-restart
                      (%find-internal-restart "RETRY" :elmtui.core.conditions)))))
              (elmtui.core.conditions:with-recovery
                  (elmtui.core.errors:state-error
                   :on-error (lambda (_condition) (declare (ignore _condition)))
                   :restarts '(:retry))
                (incf attempts)
                (if (= attempts 1)
                    (error (%make-state-error))
                    :success)))))
      (is (eq :success result))
      (is (= 2 attempts))
      (is (= 1 handled)))))

(test recovery-abort-propagates-the-same-condition-object
  (let* ((original (%make-state-error))
         (restart-invoked-p nil)
         (escaped
           (handler-case
               (handler-bind
                   ((elmtui.core.errors:state-error
                      (lambda (condition)
                        ;; ABORT deliberately re-signals the original condition
                        ;; after unwinding the recovery frame. Invoke the local
                        ;; restart only for the first delivery; the second must
                        ;; continue outward to HANDLER-CASE.
                        (unless restart-invoked-p
                          (setf restart-invoked-p t)
                          (invoke-restart
                           (find 'abort
                                 (compute-restarts condition)
                                 :key #'restart-name))))))
                 (elmtui.core.conditions:with-recovery
                     (elmtui.core.errors:state-error
                      :on-error (lambda (_condition) (declare (ignore _condition)))
                      :restarts '(:abort))
                   (error original)))
             (elmtui.core.errors:state-error (condition)
               condition))))
    (is-true restart-invoked-p)
    (is (eq original escaped))))

(test recovery-does-not-intercept-unrelated-condition-types
  (let ((on-error-count 0))
    (signals simple-error
      (elmtui.core.conditions:with-recovery
          (elmtui.core.errors:state-error
           :on-error (lambda (_condition)
                       (declare (ignore _condition))
                       (incf on-error-count))
           :restarts '(:use-value))
        (error "unrelated")))
    (is (zerop on-error-count))))

(test recovery-rejects-unknown-restart-at-macroexpansion
  (signals error
    (macroexpand-1
     '(elmtui.core.conditions:with-recovery
          (elmtui.core.errors:state-error :restarts '(:not-a-restart))
        :body))))

(test recovery-handler-runs-before-stack-unwind
  (let ((cleanup-ran nil)
        (handler-saw-cleanup nil))
    (let ((result
            (handler-bind
                ((elmtui.core.errors:state-error
                   (lambda (_condition)
                     (declare (ignore _condition))
                     (setf handler-saw-cleanup cleanup-ran)
                     (invoke-restart 'use-value :recovered))))
              (elmtui.core.conditions:with-recovery
                  (elmtui.core.errors:state-error
                   :on-error (lambda (_condition) (declare (ignore _condition)))
                   :restarts '(:use-value))
                (unwind-protect
                     (error (%make-state-error))
                  (setf cleanup-ran t))))))
      (is (eq :recovered result))
      (is-false handler-saw-cleanup)
      (is-true cleanup-ran))))

;;; ---------------------------------------------------------------------------
;;; Message and render-specific restart suites
;;; ---------------------------------------------------------------------------

(test message-restarts-skip-replace-and-retry
  (let* ((skip
           (handler-bind
               ((elmtui.core.conditions:message-validation-error
                  (lambda (_condition)
                    (declare (ignore _condition))
                    (invoke-restart
                     (%find-internal-restart
                      "SKIP-MESSAGE" :elmtui.core.conditions)))))
             (elmtui.core.conditions:with-message-restarts (_condition)
               (error 'elmtui.core.conditions:message-validation-error
                      :message :bad :reason :invalid))))
         (replacement
           (handler-bind
               ((elmtui.core.conditions:message-validation-error
                  (lambda (_condition)
                    (declare (ignore _condition))
                    (invoke-restart
                     (%find-internal-restart
                      "REPLACE-MESSAGE" :elmtui.core.conditions)
                     '(:replacement)))))
             (elmtui.core.conditions:with-message-restarts (_condition)
               (error 'elmtui.core.conditions:message-validation-error
                      :message :bad :reason :invalid))))
         (attempts 0)
         (retried
           (handler-bind
               ((elmtui.core.conditions:message-validation-error
                  (lambda (_condition)
                    (declare (ignore _condition))
                    (invoke-restart
                     (%find-internal-restart "RETRY" :elmtui.core.conditions)))))
             (elmtui.core.conditions:with-message-restarts (_condition)
               (incf attempts)
               (if (= attempts 1)
                   (error 'elmtui.core.conditions:message-validation-error
                          :message :bad :reason :transient)
                   :message-ok)))))
    (is-false skip)
    (is (equal '(:replacement) replacement))
    (is (eq :message-ok retried))
    (is (= 2 attempts))))

(test render-restarts-skip-fallback-and-retry
  (let* ((skip
           (handler-bind
               ((elmtui.core.conditions:render-error
                  (lambda (_condition)
                    (declare (ignore _condition))
                    (invoke-restart
                     (%find-internal-restart "SKIP-FRAME" :elmtui.core.conditions)))))
             (elmtui.core.conditions:with-render-restarts (_condition)
               (error 'elmtui.core.conditions:render-error
                      :message :frame :reason :bad))))
         (fallback
           (handler-bind
               ((elmtui.core.conditions:render-error
                  (lambda (_condition)
                    (declare (ignore _condition))
                    (invoke-restart
                     (%find-internal-restart
                      "FALLBACK-VIEW" :elmtui.core.conditions)
                     '(:text :content "fallback")))))
             (elmtui.core.conditions:with-render-restarts (_condition)
               (error 'elmtui.core.conditions:render-error
                      :message :frame :reason :bad))))
         (attempts 0)
         (retried
           (handler-bind
               ((elmtui.core.conditions:render-error
                  (lambda (_condition)
                    (declare (ignore _condition))
                    (invoke-restart
                     (%find-internal-restart "RETRY" :elmtui.core.conditions)))))
             (elmtui.core.conditions:with-render-restarts (_condition)
               (incf attempts)
               (if (= attempts 1)
                   (error 'elmtui.core.conditions:render-error
                          :message :frame :reason :transient)
                   :render-ok)))))
    (is-false skip)
    (is (equal '(:text :content "fallback") fallback))
    (is (eq :render-ok retried))
    (is (= 2 attempts))))

;;; ---------------------------------------------------------------------------
;;; Async restart suite
;;; ---------------------------------------------------------------------------

(test async-restarts-expose-standard-and-specialized-recovery
  (let* ((original
           (make-condition 'elmtui.core.conditions:async-task-error
                           :task '(:lookup :id 7)
                           :reason (make-condition 'simple-error
                                                   :format-control "network")))
         (seen nil)
         (names nil)
         (result
           (handler-bind
               ((elmtui.core.conditions:async-task-error
                  (lambda (condition)
                    (setf seen condition
                          names (%restart-names condition))
                    (is (find-restart 'use-value condition))
                    (dolist (name '("IGNORE-TASK" "REPLACE-TASK" "PROVIDE-RESULT" "RETRY"))
                      (is (%find-internal-restart name :elmtui.core.async condition)))
                    (invoke-restart 'use-value :cached))))
             (elmtui.core.async:with-async-restarts (_condition)
               (error original)))))
    (is (eq original seen))
    (is (member 'use-value names))
    (is (eq :cached result))))

(test async-specialized-restarts-return-values
  (let ((ignored
          (handler-bind
              ((elmtui.core.conditions:async-task-error
                 (lambda (_condition)
                   (declare (ignore _condition))
                   (invoke-restart
                    (%find-internal-restart "IGNORE-TASK" :elmtui.core.async)))))
            (elmtui.core.async:with-async-restarts (_condition)
              (error 'elmtui.core.conditions:async-task-error
                     :task :task :reason :ignored))))
        (replacement
          (handler-bind
              ((elmtui.core.conditions:async-task-error
                 (lambda (_condition)
                   (declare (ignore _condition))
                   (invoke-restart
                    (%find-internal-restart "REPLACE-TASK" :elmtui.core.async)
                    :new-task))))
            (elmtui.core.async:with-async-restarts (_condition)
              (error 'elmtui.core.conditions:async-task-error
                     :task :task :reason :replace))))
        (provided
          (handler-bind
              ((elmtui.core.conditions:async-task-error
                 (lambda (_condition)
                   (declare (ignore _condition))
                   (invoke-restart
                    (%find-internal-restart "PROVIDE-RESULT" :elmtui.core.async)
                    :provided))))
            (elmtui.core.async:with-async-restarts (_condition)
              (error 'elmtui.core.conditions:async-task-error
                     :task :task :reason :provide)))))
    (is-false ignored)
    (is (eq :new-task replacement))
    (is (eq :provided provided))))

(test async-retry-reexecutes-operation-once-per-invocation
  (let ((attempts 0))
    (let ((result
            (handler-bind
                ((elmtui.core.conditions:async-task-error
                   (lambda (_condition)
                     (declare (ignore _condition))
                     (invoke-restart
                      (%find-internal-restart "RETRY" :elmtui.core.async)))))
              (elmtui.core.async:with-async-restarts (_condition)
                (incf attempts)
                (if (= attempts 1)
                    (error 'elmtui.core.conditions:async-task-error
                           :task :task :reason :transient)
                    :async-ok)))))
      (is (eq :async-ok result))
      (is (= 2 attempts)))))

;;; ---------------------------------------------------------------------------
;;; Debugger semantics: real INVOKE-DEBUGGER with a non-interactive hook
;;; ---------------------------------------------------------------------------

(test debugger-hook-sees-original-condition-and-active-restart
  "The debugger must inspect the same condition handlers saw while recovery remains live."
  (let* ((original (%make-state-error))
         (handler-seen nil)
         (debugger-seen nil)
         (debugger-restarts nil)
         (hook
           (lambda (condition previous-hook)
             (declare (ignore previous-hook))
             (setf debugger-seen condition
                   debugger-restarts (%restart-names condition))
             (invoke-restart (find-restart 'use-value condition)
                             :from-debugger)))
         (result
           (let ((*debugger-hook* hook)
                 #+sbcl (sb-ext:*invoke-debugger-hook* hook))
             (handler-bind
                 ((elmtui.core.errors:state-error
                    (lambda (condition)
                      (setf handler-seen condition)
                      (invoke-debugger condition))))
               (elmtui.core.conditions:with-recovery
                   (elmtui.core.errors:state-error
                    :on-error (lambda (_condition) (declare (ignore _condition)))
                    :restarts '(:use-value :abort))
                 (error original))))))
    (is (eq :from-debugger result))
    (is (eq original handler-seen))
    (is (eq original debugger-seen))
    (is (member 'use-value debugger-restarts))))

(test debugger-sees-enriched-context-before-unwind
  (let* ((original (%make-state-error :context nil))
         (debugger-context nil)
         (debugger-module nil)
         (hook
           (lambda (condition previous-hook)
             (declare (ignore previous-hook))
             (setf debugger-context
                   (copy-tree
                    (elmtui.core.errors:elmtui-error-context condition))
                   debugger-module
                   (elmtui.core.errors:elmtui-error-module condition))
             (invoke-restart (find-restart 'use-value condition)
                             :debugger-recovered)))
         (result
           (let ((*debugger-hook* hook)
                 #+sbcl (sb-ext:*invoke-debugger-hook* hook))
             (handler-bind
                 ((elmtui.core.errors:state-error
                    (lambda (condition)
                      (invoke-debugger condition))))
               (elmtui.core.conditions:with-recovery
                   (elmtui.core.errors:state-error
                    :on-error (lambda (_condition) (declare (ignore _condition)))
                    :restarts '(:use-value))
                 (elmtui.core.errors:with-error-context
                     (:module :renderer :operation :draw :component-id :counter)
                   (error original)))))))
    (is (eq :debugger-recovered result))
    (is (eq :renderer debugger-module))
    (is (eq :draw (cdr (assoc :operation debugger-context))))
    (is (eq :counter (cdr (assoc :component-id debugger-context))))))

(test restart-scope-disappears-after-recovery-frame-exits
  (let ((captured-restart nil))
    (let ((result
            (handler-bind
                ((elmtui.core.errors:state-error
                   (lambda (condition)
                     (setf captured-restart (find-restart 'use-value condition))
                     (invoke-restart captured-restart :done))))
              (elmtui.core.conditions:with-recovery
                  (elmtui.core.errors:state-error
                   :on-error (lambda (_condition) (declare (ignore _condition)))
                   :restarts '(:use-value))
                (error (%make-state-error))))))
      (is (eq :done result))
      (is-true captured-restart)
      (is-false (member captured-restart (compute-restarts) :test #'eq)))))

(test core-condition-errors-share-framework-root
  "Direct core.conditions failures remain concrete errors under the framework root."
  (let ((conditions
          (list
           (make-condition 'elmtui.core.conditions:message-validation-error
                           :message :message :reason :reason)
           (make-condition 'elmtui.core.conditions:command-execution-error
                           :cmd :command :reason :reason)
           (make-condition 'elmtui.core.conditions:event-loop-dispatch-error
                           :event :event :reason :reason)
           (make-condition 'elmtui.core.conditions:async-task-error
                           :task :task :reason :reason)
           (make-condition 'elmtui.core.conditions:state-update-error
                           :state :state :reason :reason)
           (make-condition 'elmtui.core.conditions:subscriber-handler-error
                           :event :event :handler :handler :reason :reason)
           (make-condition 'elmtui.core.conditions:render-error
                           :message :render :reason :reason)
           (make-condition 'elmtui.core.conditions:signal-subscriber-error
                           :signal :signal :reason :reason)
           (make-condition 'elmtui.core.conditions:message-serialization-error
                           :data :data :original-error :cause)
           (make-condition 'elmtui.core.conditions:message-deserialization-error
                           :serialized-data :data :original-error :cause)
           (make-condition 'elmtui.core.conditions:elmtui-validation-error
                           :message "invalid"))))
    (dolist (condition conditions)
      (is (typep condition 'error))
      (is (typep condition 'elmtui.core.errors:elmtui-error))
      (is (typep condition 'elmtui.core.errors:elmtui-condition)))))

(test migrated-condition-preserves-handler-identity-and-report
  "Concrete handlers and DEFINE-CONDITION reports survive hierarchy migration."
  (let* ((condition
           (make-condition 'elmtui.core.conditions:message-validation-error
                           :message :bad :reason :invalid))
         (concrete-seen
           (handler-case (error condition)
             (elmtui.core.conditions:message-validation-error (seen) seen)))
         (root-seen
           (handler-case (error condition)
             (elmtui.core.errors:elmtui-condition (seen) seen))))
    (is (eq condition concrete-seen))
    (is (eq condition root-seen))
    (let ((report (princ-to-string condition)))
      (is (search "Message validation failed" report))
      (is (search "INVALID" report)))))

(test prefixed-condition-readers-coexist-with-legacy-generics
  "New exported readers are unambiguous while legacy internal generics still work."
  (let* ((async (make-condition 'elmtui.core.conditions:async-task-error
                                :task :task-7 :reason :network))
         (render (make-condition 'elmtui.core.conditions:render-error
                                 :message :frame-9 :reason :bad-style))
         (serialized
           (make-condition 'elmtui.core.conditions:message-serialization-error
                           :data '(:payload 1) :original-error :codec))
         (validation
           (make-condition 'elmtui.core.conditions:elmtui-validation-error
                           :path '(:props :width) :value -1
                           :message "width must be positive"))
         (legacy-reason (find-symbol "REASON" :elmtui.core.conditions))
         (legacy-message (find-symbol "MESSAGE" :elmtui.core.conditions)))
    (is (eq :task-7 (elmtui.core.conditions:async-task-error-task async)))
    (is (eq :network (elmtui.core.conditions:async-task-error-reason async)))
    (is (eq :frame-9 (elmtui.core.conditions:render-error-message render)))
    (is (eq :bad-style (elmtui.core.conditions:render-error-reason render)))
    (is (equal '(:payload 1)
               (elmtui.core.conditions:message-serialization-error-data serialized)))
    (is (eq :codec
            (elmtui.core.conditions:message-serialization-error-underlying-condition
             serialized)))
    (is (string= "width must be positive"
                 (elmtui.core.conditions:validation-error-message validation)))
    (is (eq :network (funcall (symbol-function legacy-reason) async)))
    (is (eq :frame-9 (funcall (symbol-function legacy-message) render)))))

(test diagnostic-context-vocabulary-is-public-and-bounded
  "Framework diagnostic context uses one documented machine-readable vocabulary."
  (let ((expected
          '(:operation :component-id :component-path :state-path :backend
            :message :event :offending-value :expected-type :underlying-condition)))
    (is (equal expected elmtui.core.errors:+diagnostic-context-keys+))
    (dolist (key expected)
      (is (elmtui.core.errors:diagnostic-context-key-p key)))
    (is-false (elmtui.core.errors:diagnostic-context-key-p :ad-hoc))))

(test framework-severity-hierarchy-includes-non-errors
  "Informational conditions and warnings share the framework root without becoming errors."
  (let ((information (make-condition 'elmtui.core.errors:elmtui-information))
        (warning (make-condition 'elmtui.core.errors:elmtui-warning)))
    (is (typep information 'elmtui.core.errors:elmtui-condition))
    (is (typep warning 'elmtui.core.errors:elmtui-condition))
    (is (not (typep information 'error)))
    (is (not (typep information 'warning)))
    (is (typep warning 'warning))
    (is (not (typep warning 'error)))
    (is (eq information
            (handler-case (signal information)
              (elmtui.core.errors:elmtui-information (seen) seen))))
    (is (eq warning
            (handler-case (signal warning)
              (elmtui.core.errors:elmtui-warning (seen) seen))))))

(test signal-subscriber-report-reads-the-signal-slot
  "A report must display its signal value, not accidentally invoke CL:SIGNAL."
  (let* ((condition (make-condition 'elmtui.core.conditions:signal-subscriber-error
                                    :signal :widget-created :reason :handler-failed))
         (report (princ-to-string condition)))
    (is (eq :widget-created
            (elmtui.core.conditions:signal-subscriber-error-signal condition)))
    (is (search "WIDGET-CREATED" report))
    (is (search "HANDLER-FAILED" report))))

(test condition-packages-export-only-owned-prefixed-reader-api
  "Generic legacy readers are internal, and public core condition exports are owned."
  (dolist (name '("MESSAGE" "REASON" "STATE" "EVENT" "TASK" "HANDLER"
                  "CMD" "SIGNAL" "ORIGINAL-ERROR" "SUBSCRIBER-SIGNAL"))
    (multiple-value-bind (symbol status)
        (find-symbol name :elmtui.core.conditions)
      (declare (ignore symbol))
      (is (not (eq :external status)))))
  (dolist (package-name '(:elmtui.core.errors :elmtui.core.conditions))
    (let ((package (find-package package-name)))
      (do-external-symbols (symbol package)
        (is (eq package (symbol-package symbol))
            (format nil "~A must own its exported symbol ~A" package-name symbol))))))

(test no-implementation-private-framework-exports
  "All loaded ElmTUI and support-library APIs exclude SB-* implementation internals."
  (dolist (package (list-all-packages))
    (let ((name (package-name package)))
      (when (some (lambda (prefix)
                    (and (<= (length prefix) (length name))
                         (string= prefix name :end2 (length prefix))))
                  '("ELMTUI" "CL-EVENTS" "CL-STATE" "CL-INPUTS" "CL-STYLES"))
        (do-external-symbols (symbol package)
          (let ((home (symbol-package symbol)))
            (when home
              (is (not (and (<= 3 (length (package-name home)))
                            (string= "SB-" (package-name home) :end2 3)))
                  (format nil "~A exports implementation symbol ~A from ~A"
                          name symbol (package-name home))))))))))
