;;;===============================================================
;;; File: src/core/async.lisp
;;; Async Command Interpreter (using clevelib)
(uiop:define-package :elmtui.core.async
  (:use :cl)
  (:import-from :cleve-elm.async
   :async-task :new-task :async-exec :cancel-async-task
   :async-task-finished-p :async-task-result :async-task-status :promise-cancel
   :async-task-error :promise-cancelled-p :promise-cancelled-condition
                :promise :resolve-promise :reject-promise :await)
  (:import-from :elmtui.core.globals #:*app-sender*) ; Import *app-sender* from globals
  (:import-from :elmtui.state #:rollback-state) ; Import rollback-state from state module
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

;; *app-sender* is now defined and imported from elmtui.core.events

(defvar *async-tasks* (make-hash-table :test 'equal) "Active async tasks.") ;; Still not used for cancellation
(defvar *async-errors* (make-hash-table :test 'equal) "Async task errors.")

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
  "Construct a CMD that will run FUNCTION with ARGS asynchronously.
   Parameters:
   - FUNCTION: The function to execute asynchronously
   - ARGS: Arguments to pass to the function
   - ON-COMPLETE: Optional function to call when task completes successfully
   - ON-ERROR: Optional function to call when task fails
   - TIMEOUT: Optional timeout in seconds after which the task is cancelled
   - CANCELLATION-FN: Optional function to call when the task is cancelled

   The function should accept a progress-callback as its first argument,
   followed by the specified ARGS.
   The progress-callback can be called with arbitrary data to report progress."
  (elmtui.core.conditions:with-recovery (elmtui.core.conditions:async-task-error :restarts '(:ignore-task :retry))
    (let* ((task-id (gensym "TASK-"))
           (promise (make-instance 'cleve-elm.async:promise
                                   :timeout timeout
                                   :cancellation-fn cancellation-fn))
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
                   (unless (cleve-elm.async:promise-cancelled-p promise)
                     (reject-promise promise e)
                     ;; If on-error callback provided, call it with the error
                     (when on-error
                       (funcall *app-sender* (funcall on-error e))))
                   (error e)))))
           (task (new-task wrapped-function))) ; Create task with the wrapper

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
(defmacro with-async-restarts ((condition-var) &body forms) ; Renamed body to forms
  "Handle async task failures with DRY restarts: ignore, rollback, replace, provide result."
  `(block with-async-restarts
     (handler-bind
         ((elmtui.core.conditions:async-task-error
            (lambda (,condition-var)
              (elmtui.core.conditions:log-condition ,condition-var)
              (restart-case
                  (signal ,condition-var)
                (ignore-task ()
                  :report "Ignore/discard this async task."
                  (return-from with-async-restarts nil))
                (rollback-state ()
                  :report "Rollback state to previous checkpoint."
                  ;; Call the imported rollback-state function
                  (rollback-state)
                  (return-from with-async-restarts nil))
                (replace-task (new-task)
                  :report "Replace the async task interactively or programmatically."
                  ;; Return the new task value, don't funcall body
                  (return-from with-async-restarts new-task))
                (provide-result (result)
                  :report "Provide a custom result for this task."
                  (return-from with-async-restarts result))
                (retry ()
                  :report "Retry the async task."
                  (return-from with-async-restarts (progn ,@forms))))))) ; Use forms
       ,@forms)))
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
  "Execute CMD: spawn async-task(s) or sequence. Handles errors with restarts and async-task-error."
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
             nil)))
      ;; Error handled by with-async-restarts, which signals async-task-error
      ;; No need for explicit signaling here unless we want to add more info
      (error (e)
        (error 'elmtui.core.conditions:async-task-error :task cmd :reason e)))))

(defun await-cmd (cmd)
  "Wait for CMD (async-task) to finish and return result. Handles async-task-error."
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
  "Cancel CMD (async-task). Handles async-task-error."
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
                 (cancel-async-task task)
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
      results))
  (error 'elmtui.core.conditions:async-task-error :task commands :reason "Batch execution failed"))

(defun cmd-batch-await (commands)
  "Create a CMD that executes a batch of COMMANDS and waits for all to finish.
   Returns a list of results from each command in the batch."
  (with-async-restarts (c)
    (let ((results (mapcar #'await-cmd commands)))
      ;; Return the results of the batch execution
      results))
  (error 'elmtui.core.conditions:async-task-error :task commands :reason "Batch await failed"))
;;; USAGE EXAMPLES:
;; (let ((cmd (cmd-async #'sleep 1)))
;;   (interpret-cmd cmd)
;;   (await-cmd cmd))

;;; CONTRACTS:
;; - All async commands are executed as cleve-elm.async tasks.
;; - Errors are handled with CL conditions and restarts.
;; - Supports batching and cancellation of commands.
