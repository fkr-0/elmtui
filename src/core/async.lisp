;;;===============================================================
;;; File: src/core/async.lisp
;;; Async Command Interpreter (using cl-events)
(uiop:define-package :elmtui.core.async
  (:use :cl)
  (:import-from :cl-events.async
   :async-task :new-task :async-exec :cancel
   :async-task-finished-p :async-task-result :async-task-status :promise-cancel
   :async-task-error :promise-cancelled-p
   :promise :make-promise :resolve-promise :reject-promise :await
   :schedule-after)
  (:import-from :elmtui.core.globals #:*app-sender*) ; Import *app-sender* from globals
                                        ;(:import-from :elmtui.state #:rollback-state) ; Import rollback-state from state module
                                        ; Import *app-sender* from globals
  (:export :cmd-async
   :with-async-restarts
           :spawn-worker
   :cmd-batch
           :interpret-cmd
   :*async-tasks*
           :*async-errors*
   :await-cmd
           :cancel-cmd))
                                        ; Removed export of *app-sender*
(in-package :elmtui.core.async)

;;;-----------------------------------------------------------------------------
;;; Globals & Conditions
;;;-----------------------------------------------------------------------------

(defvar *async-tasks* (make-hash-table :test 'equal) "Active async tasks.") ;; Still not used for cancellation
(defvar *async-errors* (make-hash-table :test 'equal) "Async task errors.")

(define-condition promise-cancelled-condition (elmtui.core.errors:elmtui-error)
  ((message :initarg :message :reader promise-cancelled-message))
  (:report (lambda (c s)
             (format s "~A" (promise-cancelled-message c)))))

;; Docs:
;; On the relation between a cmd and an async task:
;; A cmd is a command structure that can be interpreted by the app. It can be
;; an async task, a recurring task, a batch of commands, or a dispatch command.
;; The cmd is interpreted by the app, which resolves it into a sequence of
;; actions or an async task. The app can handle cmd types like :async, :recurring-task,
;; :batch, and :dispatch. Each cmd type has its own semantics and execution model.
;; -  :async :: cmd runs a function asynchronously, returning a promise
;;              that can be awaited.
;; - :recurring-task :: cmd runs periodically with a stop condition
;;                      and max iterations.
;; - :batch :: cmd executes a sequence of commands sequentially.
;; - :dispatch :: cmd dispatches to a specific handler or function, which results in a cmd
;;                that is interpreted by the app and executed immediately (synchronously).


;;;-----------------------------------------------------------------------------
;;; Command Construction
;;;-----------------------------------------------------------------------------

(defun cmd-async (function &key args on-complete on-error timeout cancellation-fn)
  "Construct an asynchronous ElmTUI command around FUNCTION.

Arguments:
  FUNCTION receives a progress callback followed by ARGS. ON-COMPLETE maps a
  successful result to an application message; ON-ERROR maps a failure to an
  application message. TIMEOUT schedules promise cancellation after the given
  seconds. CANCELLATION-FN is optional best-effort cancellation cleanup.

Returns:
  A command plist beginning with :ASYNC and containing the task, generated task
  id, promise, and completion/error callbacks. Execution does not begin until
  INTERPRET-CMD processes the command.

Mutation:
  Allocates task/promise objects. Once interpreted, the worker resolves/rejects
  the promise and sends progress/completion/error messages through *APP-SENDER*.
  A timeout may invoke CANCELLATION-FN and cancel the promise.

Conditions:
  Construction errors are exposed through ASYNC-TASK-ERROR recovery. Worker
  errors reject the promise, optionally emit ON-ERROR output, and remain
  available when the task is awaited. CANCELLATION-FN failures are currently
  deliberately suppressed during timeout cleanup.

Restarts:
  Construction is wrapped by WITH-RECOVERY with IGNORE-TASK and RETRY. Retrying
  construction may allocate a new task/promise pair.

Example:
  (cmd-async (lambda (progress value)
               (funcall progress '(:phase :working))
               (1+ value))
             :args '(41)
             :on-complete
             (lambda (result)
               `(:lookup-succeeded :result ,result)))"
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:async-task-error :restarts '(:ignore-task :retry))
    (let* ((task-id (gensym "TASK-"))
           (promise (make-promise))
           (progress-callback
             (lambda (progress-data)
               ;; Sends progress updates to the app
               (funcall *app-sender* `(:async-progress-update :task-id ,task-id :progress ,progress-data))))
           ;; Wrap the original function to inject the progress callback
           (wrapped-function
             (lambda ()
               (handler-case
                   (let ((result (apply function progress-callback args)))
                     ;; Check if the promise was cancelled during execution
                     (if (promise-cancelled-p promise)
                         (progn
                           (log:info "Task ~A was cancelled, not resolving promise" task-id)
                           ;; If on-error callback provided, call it with the cancelled condition
                           (when on-error
                             (let ((error-msg
                                     (make-condition
                                      'promise-cancelled-condition
                                      :message "Task cancelled")))
                               (funcall *app-sender* (funcall on-error error-msg)))))
                         (progn
                           ;; Task completed successfully
                           (resolve-promise promise result)
                           ;; If on-complete callback provided, call it with the result
                           (when on-complete
                             (funcall *app-sender* (funcall on-complete result)))))
                     result)
                 (error (e)
                   ;; Task failed with an error
                   (unless (promise-cancelled-p promise)
                     (reject-promise promise e)
                     ;; If on-error callback provided, call it with the error
                     (when on-error
                       (funcall *app-sender* (funcall on-error e))))
                   (error e)))))
           (task (new-task wrapped-function))) ; Create task with the wrapper

      (when timeout
        (schedule-after
         timeout
         (lambda ()
           (when cancellation-fn
             (handler-case
                 (funcall cancellation-fn)
               (error (condition)
                 (log4cl:log-warn "ASYNC: cancellation cleanup failed: ~A" condition))))
           (promise-cancel promise))))
      ;; Store task ID along with the task object in the command
      ;; The command structure is now (:async :task <task-obj> :id <task-id> :promise <promise>)
      (list :async :task task :id task-id :promise promise :on-complete on-complete :on-error on-error))))

(defun cmd-async-with-retry (function &key args on-complete on-error retry-attempts retry-delay timeout)
  "Construct a CMD that will run FUNCTION with ARGS asynchronously, retrying on failure.
   Parameters are the same as cmd-async with these additional options:
   - RETRY-ATTEMPTS: Number of retry attempts (default: 3)
   - RETRY-DELAY: Delay in seconds between retry attempts (default: 1.0)

   The function will retry automatically if it fails, up to RETRY-ATTEMPTS times
   with RETRY-DELAY seconds between attempts."
  (let ((attempts (or retry-attempts 3))
        (delay (or retry-delay 1.0)))

    (labels ((do-attempt (remaining-attempts)
               (if (<= remaining-attempts 0)
                   ;; No more attempts, create a regular cmd-async with the original callbacks
                   (cmd-async function
                              :args args
                              :on-complete on-complete
                              :on-error on-error
                              :timeout timeout)
                   ;; Custom callbacks that handle retry logic
                   (cmd-async function
                              :args args
                              :timeout timeout
                              :on-complete (lambda (result)
                                             (if on-complete
                                                 (funcall on-complete result)
                                                 `(:async-completed :task-id ,(gensym "RETRY-TASK-") :result ,result)))
                              :on-error (lambda (error)
                                          (log:info "Task failed, retrying (~A attempts left): ~A"
                                                    (1- remaining-attempts) error)
                                          ;; Schedule retry after delay
                                          (cmd-async (lambda (_)
                                                       (declare (ignore _))
                                                       (interpret-cmd (do-attempt (1- remaining-attempts))))
                                                     :args nil
                                                     :timeout delay)
                                          ;; Return an interim message about retry
                                          `(:async-retry :remaining ,(1- remaining-attempts) :error ,error))))))

      ;; Start the first attempt
      (do-attempt attempts))))



(defmacro with-async-restarts ((condition-var) &body forms)
  "Execute FORMS with async-task recovery restarts around the operation.

Arguments:
  CONDITION-VAR names an ELMTUI.CORE.CONDITIONS:ASYNC-TASK-ERROR while its
  handler is active. FORMS are the operation to execute.

Returns:
  The values of FORMS on success. IGNORE-TASK returns NIL, REPLACE-TASK returns
  the supplied replacement task, PROVIDE-RESULT returns the supplied result,
  and RETRY re-executes FORMS.

Mutation:
  The macro itself only logs signaled async-task conditions. FORMS controls
  application mutation. RETRY can repeat effects, so use it only around work
  whose retry semantics are safe, idempotent, or otherwise explicitly handled.

Conditions:
  ASYNC-TASK-ERROR is observed with HANDLER-BIND but is not reconstructed or
  re-signaled. If no handler/debugger invokes a restart, the original condition
  propagates normally with its identity and debugger context intact.

Restarts:
  IGNORE-TASK, REPLACE-TASK, PROVIDE-RESULT, the standard Common Lisp
  USE-VALUE, and RETRY are active while FORMS executes. USE-VALUE is the
  preferred programmatic value-substitution restart across package boundaries.

Example:
  (handler-bind
      ((elmtui.core.conditions:async-task-error
         (lambda (condition)
           (declare (ignore condition))
           (invoke-restart 'use-value :cached))))
    (with-async-restarts (_condition)
      (run-async-operation)))"
  (let ((attempt (gensym "ATTEMPT")))
    `(labels ((,attempt ()
                (restart-case
                    (handler-bind
                        ((elmtui.core.conditions:async-task-error
                           (lambda (,condition-var)
                             (elmtui.core.conditions:log-condition
                              ,condition-var))))
                      ,@forms)
                  (ignore-task ()
                    :report "Ignore/discard this async task."
                    nil)
                  (replace-task (new-task)
                    :report "Replace the async task interactively or programmatically."
                    new-task)
                  (provide-result (result)
                    :report "Provide a custom result for this task."
                    result)
                  (use-value (result)
                    :report "Supply a replacement result using the standard Common Lisp restart."
                    result)
                  (retry ()
                    :report "Retry the async task."
                    (,attempt)))))
       (,attempt))))

(defun cmd-recurring (interval-seconds function &key args on-message stop-condition max-iterations)
  "Create a recurring command that runs periodically.
   Parameters:
   - INTERVAL-SECONDS: Time in seconds between executions
   - FUNCTION: The function to execute repeatedly
   - ARGS: Arguments to pass to the function
   - ON-MESSAGE: Function to create messages from function results
   - STOP-CONDITION: Function that returns true when the recurring task should stop
   - MAX-ITERATIONS: Maximum number of iterations (-1 for unlimited)

   Returns a command structure for a recurring task that can be cancelled."
  (let* ((task-id (gensym "RECURRING-"))
         (iterations-left (or max-iterations -1)))

    (list :recurring-task
          :id task-id
          :interval interval-seconds
          :function function
          :args args
          :on-message on-message
          :stop-condition stop-condition
          :max-iterations iterations-left)))

(defun cancel-recurring-cmd (cmd)
  "Cancel a recurring command."
  (let ((cmd-type (car cmd)))
    (case cmd-type
      (:recurring-task
       (let ((task-id (getf (cdr cmd) :id)))
         (log:info "Cancelling recurring task ~A" task-id)
         (setf (getf (cdr cmd) :max-iterations) 0)
         t))
      (otherwise
       (log:warn "Cannot cancel non-recurring command: ~A" cmd-type)
       nil))))

;; Export new functions
(export '(cmd-async-with-retry cmd-recurring cancel-recurring-cmd) :elmtui.core.async)

;;;-----------------------------------------------------------------------------
;;; Command Execution
;;;-----------------------------------------------------------------------------

(defun interpret-cmd (cmd)
  "Interpret and execute one ElmTUI command.

Arguments:
  CMD begins with one of :ASYNC, :BATCH, :DISPATCH, or :RECURRING-TASK.
  *APP-SENDER* must name a callable application-message sink.

Returns:
  :ASYNC returns two values, its task and promise. :BATCH returns a list of
  recursively interpreted results. :DISPATCH sends its payload and returns NIL.
  :RECURRING-TASK starts its worker and returns its task id. Unknown command
  kinds return (:UNKNOWN KIND) after a warning.

Mutation:
  :ASYNC stores the task in *ASYNC-TASKS* and starts it. :DISPATCH sends a
  message. :RECURRING-TASK creates/stores a worker thread whose function may
  perform its documented effects and emit messages. The application model is
  changed only later through messages/update, not directly by this interpreter.

Conditions:
  Missing *APP-SENDER* is an error. Command execution failures are translated
  to ASYNC-TASK-ERROR with CMD in the task slot and the original condition in
  the reason slot.

Restarts:
  WITH-ASYNC-RESTARTS keeps the original ASYNC-TASK-ERROR inspectable while
  offering IGNORE-TASK, REPLACE-TASK, PROVIDE-RESULT, standard USE-VALUE, and
  RETRY. RETRY can repeat command side effects and is safe only when the command
  operation is idempotent or otherwise transactionally protected.

Example:
  (multiple-value-bind (task promise)
      (interpret-cmd
       (cmd-async (lambda (_progress) :ready)))
    (values task promise))"

  ;;Ensure we have a valid *app-sender* to send messages
  (unless *app-sender*
    (error "No *app-sender* defined. Ensure you have set it before interpreting commands."))
  ;; Use with-async-restarts for standard async error handling
  (with-async-restarts (c)
    (handler-case
        (let ((cmd-type (car cmd)))
          (case cmd-type
            (:async ;; Handle an async task command - executes a function asynchronously
             (let ((task (getf (cdr cmd) :task))
                   (task-id (getf (cdr cmd) :id))
                   (promise (getf (cdr cmd) :promise)))
               (unless task (error "Invalid :async command structure: ~S" cmd))
               (log:info "Executing async task ~A" task-id)
               (setf (gethash task-id *async-tasks*) task) ; Store task for potential cancellation
               (async-exec task) ; Execute the task (which includes the wrapper)
               (values task promise))) ; Return the task object and promise
            (:batch ;; Handle a batch of commands - each command is executed sequentially and can be of type :async or :dispatch
             (mapcar #'interpret-cmd (cadr cmd)))
            (:dispatch ; Handle potential :dispatch commands generated by widgets
                                        ; This is a no-op, as dispatch commands are not async tasks but rather immediate actions
                                        ; They are handled by the app-sender directly but we still need to return nil
             (funcall *app-sender* (cadr cmd)) ; Send the message payload
             nil) ; Dispatch commands don't return a task
            (:recurring-task
             (let ((task-id (getf (cdr cmd) :id))
                   (interval (getf (cdr cmd) :interval))
                   (function (getf (cdr cmd) :function))
                   (args (getf (cdr cmd) :args))
                   (on-message (getf (cdr cmd) :on-message))
                   (stop-condition (getf (cdr cmd) :stop-condition))
                   (max-iterations (getf (cdr cmd) :max-iterations)))

               ;; Create a thread that will periodically run the function
               (let ((thread
                       (bt:make-thread
                        (lambda ()
                          (let ((iterations 0))
                            (loop
                              ;; Check if we should stop
                              (when (and (not (minusp max-iterations))
                                         (>= iterations max-iterations))
                                (return))

                              ;; Check custom stop condition if provided
                              (when (and stop-condition (funcall stop-condition))
                                (return))

                              ;; Run the function
                              (handler-case
                                  (let ((result (apply function args)))
                                    ;; Send result as a message if on-message is provided
                                    (when on-message
                                      (let ((message (funcall on-message result)))
                                        (when message
                                          (funcall *app-sender* message)))))
                                (error (e)
                                  (log:error "Error in recurring task ~A: ~A" task-id e)))

                              ;; Increment iterations
                              (incf iterations)

                              ;; Sleep until next execution
                              (sleep interval))))
                        :name (format nil "Recurring-Task-~A" task-id))))

                 ;; Store the thread in the async tasks hash table
                 (setf (gethash task-id *async-tasks*) thread)

                 ;; Return the task ID
                 task-id)))
            (otherwise
             (log:warn "Unknown command type: ~A" cmd-type)
             (list :unknown cmd-type))))
      ;; Error handled by with-async-restarts, which signals async-task-error
      ;; No need for explicit signaling here unless we want to add more info
      (error (e)
        (error 'elmtui.core.conditions:async-task-error :task cmd :reason e)))))

(defun await-cmd (cmd)
  "Wait for CMD and return its completed result.

Arguments:
  CMD is an ElmTUI command structure. :ASYNC commands are awaited directly;
  :BATCH commands are awaited recursively; :DISPATCH returns NIL.

Returns:
  The async task result, a list of batch results, or NIL for non-awaitable
  command kinds.

Mutation:
  Waiting does not mutate application state, but the worker being awaited may
  already have performed its documented effects and promise transitions.

Conditions:
  Worker failures are translated to ASYNC-TASK-ERROR while preserving the
  original failure as the condition reason. Unknown command kinds are warned
  about and return NIL.

Restarts:
  WITH-ASYNC-RESTARTS establishes IGNORE-TASK, REPLACE-TASK, PROVIDE-RESULT,
  standard USE-VALUE, and RETRY while the await operation is active. RETRY may
  repeat an await and must not be confused with rerunning an arbitrary effect.

Example:
  (handler-bind
      ((elmtui.core.conditions:async-task-error
         (lambda (condition)
           (declare (ignore condition))
           (invoke-restart 'use-value :cached))))
    (await-cmd command))"
  (with-async-restarts (c)
    (let ((cmd-type (car cmd)))
      (case cmd-type
        (:async
         (let ((task (getf (cdr cmd) :task)))
           (unless task (error "Invalid :async command structure for await: ~S" cmd))
           (handler-case (await task)
             (error (e) (error 'elmtui.core.conditions:async-task-error :task cmd :reason e)))))
        (:batch (mapcar #'await-cmd (cadr cmd)))
        (:dispatch nil) ; Cannot await a dispatch command
        (otherwise (log:warn "Cannot await unknown command type: ~A" cmd-type) nil)))))

(defun cancel-cmd (cmd)
  "Cancel CMD according to its command kind.

Arguments:
  CMD is an ElmTUI command structure. For :ASYNC commands the associated task
  and promise are cancelled; batches are traversed recursively where supported.

Returns:
  The command-kind-specific cancellation result, conventionally true/NIL.

Mutation:
  Mutates task/promise lifecycle state and the async task registry as required
  by the command implementation. It does not directly mutate the application
  model.

Conditions:
  Cancellation failures are exposed as ASYNC-TASK-ERROR. Unknown/non-cancellable
  commands may warn and return NIL.

Restarts:
  The standard async recovery restarts are active while cancellation runs.
  Retrying cancellation is intended to be safe only for cancellation backends
  whose operation is idempotent.

Example:
  (cancel-cmd command)"
  (with-async-restarts (c)
    (let ((cmd-type (car cmd)))
      (case cmd-type
        (:async
         (let ((task (getf (cdr cmd) :task))
               (task-id (getf (cdr cmd) :id))
               (promise (getf (cdr cmd) :promise)))
           (unless task (error "Invalid :async command structure for cancel: ~S" cmd))
           (log:info "Cancelling async task ~A" task-id)
           ;; First cancel the promise if present
           (when promise
             (handler-case
                 (promise-cancel promise)
               (error (e)
                 (log:warn "Error cancelling promise for task ~A: ~A" task-id e))))
           ;; Then cancel the task itself
           (handler-case
               (progn
                 (cancel task)
                 (remhash task-id *async-tasks*)
                 t)
             (error (e)
               (error 'elmtui.core.conditions:async-task-error :task cmd :reason e)))))
        (:batch
         (mapcar #'cancel-cmd (cadr cmd)))
        (:dispatch
         nil) ; Cannot cancel a dispatch command
        (:recurring-task
         (let ((task-id (getf (cdr cmd) :id)))
           (log:info "Cancelling recurring task ~A" task-id)
           (let ((thread (gethash task-id *async-tasks*)))
             (when thread
               (handler-case
                   (progn
                     (when (bt:thread-alive-p thread)
                       (bt:destroy-thread thread))
                     (remhash task-id *async-tasks*)
                     t)
                 (error (e)
                   (log:warn "Error cancelling recurring task ~A: ~A" task-id e)
                   nil))))))
        (otherwise
         (log:warn "Cannot cancel unknown command type: ~A" cmd-type)
         nil)))))


(defun spawn-worker (task &key name )
  "Spawn a worker thread to execute TASK asynchronously."
  (with-async-restarts (c)
    (handler-case
        (let ((task-id (gensym (format nil "WORKER-~A" name)))
              (worker-task (new-task task)))
          ;; Store the worker task in the async tasks hash table
          (setf (gethash task-id *async-tasks*) worker-task)
          ;; Execute the worker task
          (async-exec worker-task)
          ;; Return the task ID
          task-id)
      ;; Handle errors with restarts
      (error (e) (error 'elmtui.core.conditions:async-task-error :task task :reason e)))))

(defun cmd-batch (commands)
  "Create a CMD that executes a batch of COMMANDS sequentially.
   Returns a list of results from each command in the batch."
  (with-async-restarts (c)
    (let ((results (mapcar #'interpret-cmd commands)))
      ;; Return the results of the batch execution
      results)))

(defun cmd-batch-await (commands)
  "Create a CMD that executes a batch of COMMANDS and waits for all to finish.
   Returns a list of results from each command in the batch."
  (with-async-restarts (c)
    (let ((results (mapcar #'await-cmd commands)))
      ;; Return the results of the batch execution
      results)))
;;; USAGE EXAMPLES:
;; (let ((cmd (cmd-async #'sleep 1)))
;;   (interpret-cmd cmd)
;;   (await-cmd cmd))

;;; CONTRACTS:
;; - All async commands are executed as cleve-elm.async tasks.
;; - Errors are handled with CL conditions and restarts.
;; - Supports batching and cancellation of commands.
