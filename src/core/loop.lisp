;;;===============================================================
;;; File: src/core/loop.lisp
;;; Event Loop & Dispatcher (Channel-Based System)
;;;===============================================================

(uiop:define-package :elmtui.core.loop
  (:use :cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-warn #:log-info)
  (:import-from :elmtui.core.globals
                #:*event-loop* #:*app-state* #:*app-message-processor* #:*app-sender*)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:key-event-code #:key-event-modifiers)
  (:import-from :elmtui.state.msg #:make-keyevent-appmsg)
  (:import-from :bordeaux-threads
                #:make-thread #:thread-alive-p #:join-thread #:destroy-thread)
  (:import-from :cl-events.channel
                #:make-channel #:chan-close #:-> #:<- #:no-wait #:channel-length)
  (:import-from :elmtui.core.event-channels
                #:event-channel #:handlers #:name #:channel-of #:wait-for-event
                #:standard-event-channels)
  (:import-from :elmtui.state.update ; Assuming this is the correct package for handle-async-command
                #:handle-async-command)
  (:import-from :elmtui.core.system-events #:terminalresized-system-event)
  (:export :start-loop :elm-stop-loop :publish :subscribe :*event-loop* #:as-plist
           :get-event-loop-status :get-event-queue-length :instrument-event-loop
           ;; Make *consumer-thread* accessible for joining in driver.lisp
   :*consumer-thread*))

(in-package :elmtui.core.loop)

(defmacro with-thread-debugger ((thread-name) &body body)
  "Wrap BODY in an error handler that invokes the interactive debugger
   for threads, providing a more informative debugging session."
  `(handler-bind ((error (lambda (e)
                           (log-error "Error in thread ~A: ~A" ,thread-name e)
                           (uiop:print-backtrace :stream *debug-io* :condition e)
                           (invoke-debugger e))))
     ,@body))

;; Event processing variables
(defvar *consumer-thread* nil
  "Thread for consuming events from *active-event-channels*
- consumer is the dequeuing events/messages and running the update function
as well as the view function for the application.")

(defvar *shutdown-requested-cell* (list nil)
  "Shared cell storing the shutdown-requested flag across threads.")
(define-symbol-macro *shutdown-requested* (car *shutdown-requested-cell*))


(defvar *event-loop-metrics* (make-hash-table :test 'eq)
  "Metrics for event processing")

(defvar *event-processing-time-history*
  (make-array 100 :initial-element 0 :fill-pointer 0 :adjustable t)
  "History of event processing times in milliseconds (keeps last 100 entries).")

;; *active-event-channels* will now be a flat list of event-channel objects
(defvar *active-event-channels* nil
  "Flat list of active event-channel objects.")

(defun start-loop (&key (fps 60) (wait t))
  "Initialize and start the main event loop using the channel-based system."
  (declare (ignore fps wait)) ; These arguments seem to be unused currently.
  (log-debug "START-LOOP: Called. *active-event-channels* is currently ~:[NIL~;non-NIL~]."
             *active-event-channels*)
  (unless *active-event-channels*
    (log-debug "START-LOOP: *active-event-channels* is NIL, initializing.")
    ;; standard-event-channels returns an alist ((key . channel-obj) ...).
    ;; We want *active-event-channels* to be a flat list of channel objects.
    (setf *active-event-channels*
          (mapcar #'cdr (elmtui.core.event-channels:standard-event-channels)))
    (log-debug "START-LOOP: Initialized *active-event-channels*. Channel names: ~S"
               (mapcar #'elmtui.core.event-channels:name *active-event-channels*)))
  (log-debug "START-LOOP: *active-event-channels* is now active. Channel-based event system activated.")

  ;; Set the global *app-sender* to this system's publish function
  (setf elmtui.core.globals:*app-sender* #'publish)
  (log-debug "LOOP: *app-sender* set to #'elmtui.core.loop:publish (channel system)")
  (when (or (null *consumer-thread*)
            (and  (not *shutdown-requested*))
            (and *consumer-thread* (not (sb-thread:thread-alive-p *consumer-thread*))))
    (setf *shutdown-requested* nil)
    (setf *consumer-thread*
          (bt:make-thread #'event-consumer-loop :name "elmtui-event-consumer"))
    (log-info "LOOP: Started event consumer thread for channel system."))
  t)


;; (defun force-restart-loop )

(defun event-consumer-loop ()
  "Consumer loop for processing events from *active-event-channels*."
  (unwind-protect
       (with-thread-debugger ("elmtui-event-consumer")
         (log-info "EVENT-CONSUMER: Starting loop. Active channels count: ~D."
                   (length *active-event-channels*))
         (when (and *active-event-channels* (> (length *active-event-channels*) 0))
           (log-debug "EVENT-CONSUMER: First channel object name for consumer: ~A"
                      (elmtui.core.event-channels:name (first *active-event-channels*))))
         (loop
           (when *shutdown-requested*
             (log-info "EVENT-CONSUMER: Shutdown requested, exiting loop.")
             (return))
           (log-debug "EVENT-CONSUMER: *shutdown-requested* was false, continuing loop.")
           (if (null *active-event-channels*)
               (progn
                 (log-debug "EVENT-CONSUMER: No active event channels. Sleeping briefly.")
                 (sleep 0.1)
                 nil)
               (restart-case
                   (handler-case
                       (multiple-value-bind (event originating-event-channel-object)
                           (elmtui.core.event-channels:wait-for-event *active-event-channels* :timeout 0.0)
                         (if event
                             (progn
                               (log-debug "EVENT-CONSUMER: Dequeued event ~A from channel ~S."
                                          event
                                          (if originating-event-channel-object
                                              (elmtui.core.event-channels:name originating-event-channel-object)
                                              "unknown (event but no channel object)"))
                               (cond
                                 ((eq event :shutdown-loop)
                                  (log-info "EVENT-CONSUMER: Received :shutdown-loop signal on channel ~A."
                                            (if originating-event-channel-object
                                                (elmtui.core.event-channels:name originating-event-channel-object)
                                                "unknown"))
                                  (setf *shutdown-requested* t))
                                 ((not (null originating-event-channel-object))
                                  (process-channel-event event originating-event-channel-object))
                                 (t ; Should not happen if wait-for-event returns a valid channel object with an event
                                  (log-warn "EVENT-CONSUMER: Received event ~S but no originating channel object." event))))
                             (log-debug "EVENT-CONSUMER: wait-for-event timed out or returned nil event.")))
                     (error (e)
                       (log-error "EVENT-CONSUMER: Error during event polling: ~A. Invoking restart." e)
                       ;; prevent hard hang on shutdown: mark and exit loop
                       (setf *shutdown-requested* t)
                       (log-error "EVENT-CONSUMER: Error during polling; setting shutdown-requested. ~A" e)
                       (return)))
                 (restart-loop ()
                   :report "Restart the event loop by spawning a new consumer thread."
                   (log-warn "EVENT-CONSUMER: restart-loop invoked. Creating new thread.")
                   (start-loop)
                   (return))))))
    ;; Cleanup form of unwind-protect
    (progn
      (log-debug "event-loop> Cleanup form unwind-protect")
      (setf *shutdown-requested* t)))
  (log-info "EVENT-CONSUMER: Event consumer loop terminated."))

(defgeneric as-plist (style)
  (:method ((styles list))
    "Convert a style object to a property list. This method should be overridden by specific style objects."
    styles)
  (:documentation "Convert a style object to a property list."))

;;; ─────────────────────────────────────────────────────────────────
;;;  Public entry point
;;; ─────────────────────────────────────────────────────────────────
(defun process-channel-event (event source-event-channel-object)
  "Route EVENT that arrived on SOURCE-EVENT-CHANNEL-OBJECT through
   1) channel-local handlers,
   2) global routing (app-message-processor, async dispatcher, …),
   3) metrics bookkeeping."
  (log-info "PROCESS-CHANNEL-EVENT: Called with event ~S from channel ~S"
            event (elmtui.core.event-channels:name source-event-channel-object))
  (let* ((start-time (get-internal-real-time))
         (event* event)
         (channel-name (elmtui.core.event-channels:name source-event-channel-object)))
    ;; phase 1: channel-local handlers
    (dolist (handler (elmtui.core.event-channels:handlers source-event-channel-object))
      (handler-case
          (funcall handler (maybe-normalise-style event*) event*)
        (error (e)
          (log-error "EVENT-CONSUMER: Handler error for ~S on ~A: ~A"
                     event* channel-name e))))

    ;; basic metrics
    (setf (gethash :last-event *event-loop-metrics*) event*
          (gethash :last-event-time *event-loop-metrics*) (get-universal-time))

    ;; phase 2: global routing
    (cond
      ((eq event* :shutdown-command)
       (log-info "Received :shutdown-command. Stopping application loop.")
       (elm-stop-loop))
      ((typep event* 'elmtui.core.event-types:key-event)
       (if elmtui.core.globals:*app-message-processor*
           (progn
             (log-info "EVENT-CONSUMER: Processing event with ~A" event)
             (funcall elmtui.core.globals:*app-message-processor*
                      (keymsg-from-event event*)))
           (log-error "*app-message-processor* not set—cannot process key-event: ~S" event*)))
      ((not (consp event*))
       (log-warn "Ignoring malformed non-list event ~S on channel ~S" event* channel-name))
      (t
       (destructuring-bind (tag &rest payload) event*
         (case tag
           (:terminal-resized
            (log-info "Routing :terminal-resized ~S to *app-message-processor*" payload)
            (if elmtui.core.globals:*app-message-processor*
                (funcall elmtui.core.globals:*app-message-processor* event*)
                (log-error "*app-message-processor* not set—cannot process resize: ~S" payload)))
           (:app-message
            (let ((msg (first payload)))
              (log-info "Routing :app-message ~S to *app-message-processor*" msg)
              (if elmtui.core.globals:*app-message-processor*
                  (funcall elmtui.core.globals:*app-message-processor*
                           (if (typep msg 'elmtui.core.event-types:key-event)
                               (keymsg-from-event msg)
                               msg))
                  (log-error "*app-message-processor* not set—cannot process: ~S" msg))))
           ((:async :recurring-task :batch :dispatch)
            (log-debug "Handling async command ~S" event*)
            (handle-async-command event* elmtui.core.globals:*app-state*))
           (otherwise
            (log-warn "Unknown event tag ~S on channel ~S" tag channel-name))))))

    ;; phase 3: accounting
    (let ((ms (/ (* (- (get-internal-real-time) start-time) 1000.0)
                 internal-time-units-per-second)))
      (log-debug "EVENT-CONSUMER: Event processed in ~,2F ms." ms)
      (vector-push-extend ms *event-processing-time-history*)
      (when (> (fill-pointer *event-processing-time-history*) 100)
        (setf *event-processing-time-history*
              (make-array 100
                          :initial-contents (subseq *event-processing-time-history*
                                                    (- (fill-pointer *event-processing-time-history*) 100))
                          :fill-pointer 100
                          :adjustable t)))
      (setf (gethash :processed-event-count *event-loop-metrics*)
            (1+ (or (gethash :processed-event-count *event-loop-metrics*) 0)))
      (setf (gethash :total-processing-time *event-loop-metrics*)
            (+ (or (gethash :total-processing-time *event-loop-metrics*) 0)
               ms)))))

;;; ─────────────────────────────────────────────────────────────────
;;;  Small helper – ensure :STYLE is a plist
;;; ─────────────────────────────────────────────────────────────────
(defun maybe-normalise-style (evt)
  "If EVT is a list that contains a :STYLE slot whose value is not already
   a plist, return a copy where the value is wrapped in (as-plist …).
   Otherwise return EVT unchanged."
  (if (and (consp evt)
           (find :style evt)
           (let ((style (getf evt :style))) (and style (not (listp style)))))
      (let* ((clone (copy-list evt))
             (style (getf clone :style)))
        (setf (getf clone :style) (as-plist style))
        clone)
      evt))

(defun subscribe (event-type handler)
  "Subscribe a HANDLER to a specific EVENT-TYPE.
   EVENT-TYPE should be a keyword matching a channel name."
  (let ((channel-obj (find event-type *active-event-channels*
                           :key #'elmtui.core.event-channels:name
                           :test #'eq)))
    (if channel-obj
        (progn
          (pushnew handler (elmtui.core.event-channels:handlers channel-obj))
          (log-info "SUBSCRIBE: Handler ~S subscribed to ~S." handler event-type)
          t)
        (progn
          (log-warn "SUBSCRIBE: Channel for event type ~S not found." event-type)
          nil))))

(defun keymsg-from-event (e)
  (elmtui.state.msg:make-keyevent-appmsg :event e
                                             :key (elmtui.core.event-types:key-event-key e)
                                             :char (when (elmtui.core.event-types:key-event-code e)
                                                     (code-char (elmtui.core.event-types:key-event-code e)))
                                             :modifiers (elmtui.core.event-types:key-event-modifiers e)))

(defun elm-stop-loop ()
  "Gracefully stop the event loop and consumer thread."
  (log-info "ELM-STOP-LOOP: Function called. Current *shutdown-requested*: ~A" *shutdown-requested*)
  (unless *shutdown-requested*
    (log-info "LOOP: elm-stop-loop called. Initiating shutdown sequence.")
    (setf *shutdown-requested* t)

    ;; 1. Wake up the consumer thread if it's waiting on an event.
    (log-info "LOOP: Sending :shutdown-loop signal to wake consumer thread.")
    (when *active-event-channels*
      (let* ((ch-obj (first *active-event-channels*)))
        (when ch-obj
          (let ((raw-ch (elmtui.core.event-channels:channel-of ch-obj)))
            (when raw-ch
              (ignore-errors (-> raw-ch :shutdown-loop)))))))

    ;; 2. Wait for the consumer thread to exit cleanly.
    (when (and *consumer-thread* (bt:thread-alive-p *consumer-thread*))
      (log:info "LOOP: Waiting for consumer thread to terminate...")
      (if (bt:join-thread *consumer-thread*)
          (log:info "LOOP: Consumer thread terminated gracefully.")
          (progn
            (log:warn "LOOP: Consumer thread failed to terminate in 2 seconds. Forcing termination.")
            (when (and *consumer-thread* (bt:thread-alive-p *consumer-thread*))
              (bt:destroy-thread *consumer-thread*))))
      (setf *consumer-thread* nil))

    ;; 3. Now that the consumer is stopped, it's safe to clean up channels.
    (log-info "LOOP: Closing event channels.")
    (dolist (ch-obj *active-event-channels*)
      (ignore-errors (chan-close (elmtui.core.event-channels:channel-of ch-obj))))
    (setf *active-event-channels* nil)
    (log-info "LOOP: *active-event-channels* set to NIL.")

    (log-info "LOOP: Event system shutdown sequence complete.")))


(defun publish (event &key target-channel-name)
  "Publish EVENT to TARGET-CHANNEL-NAME (keyword or string). \
Returns T on success, NIL on drop. Safe after shutdown."
  (when (or *shutdown-requested*
            (null event))                         ;; early sanity
    ;; Silently drop - logging here can cause deadlock
    (return-from publish nil))

  ;; 1. Normalise target name → always a keyword
  (let* ((effective-target-name
           (cond
             ((null target-channel-name) :system-channel)
             ((stringp target-channel-name)
              (intern target-channel-name :keyword))
             ((keywordp target-channel-name) target-channel-name)
             ((symbolp target-channel-name)
              (intern (symbol-name target-channel-name) :keyword))
             (t (error "Unsupported channel designator: ~S" target-channel-name))))
         (channel-obj
           (find effective-target-name
                 *active-event-channels*
                 :key #'elmtui.core.event-channels:name
                 :test #'eql)))                  ;; eql safer for mixed symbols/keywords
    (unless channel-obj
      ;; Silently drop - logging here can cause deadlock
      (return-from publish nil))

    (let ((the-channel (elmtui.core.event-channels:channel-of channel-obj)))
      (unless the-channel
        ;; Silently drop - logging here can cause deadlock
        (return-from publish nil))

      ;; Wrap event if necessary
      (let* ((primary-tag (and (listp event) (first event)))
             (event* (if (or (eq event :shutdown-command)
                             (member primary-tag
                                     '(:app-message :async :recurring-task
                                       :batch :dispatch)))
                         event
                         (list :app-message event))))
        (handler-case
            (progn
              (-> the-channel event*)
              ;; Log outside of the critical section to avoid deadlock with Log4CL
              t)                                 ;; success
          (error (e)
            ;; Log outside of the critical section to avoid deadlock with Log4CL
            (declare (ignore e))
            nil))))))
;; Status and metrics functions
(defun get-event-loop-status ()
  "Get the current status of the event loop."
  (list :consumer-thread-active
        (and *consumer-thread*
             (bt:thread-alive-p *consumer-thread*))
        :active-channels
        (if *active-event-channels*
            (length *active-event-channels*)
            ;; (mapcar #'elmtui.core.event-channels:name *active-event-channels*)
            nil)
        ;; :channels
        ;; (if *active-event-channels*
        ;;     (mapcar
        ;;      (lambda (x)
        ;;        ;; get enqueued, dequeued, closed, name, and queue length
        ;;        (let ((raw-channel (elmtui.core.event-channels:channel-of x)))
        ;;          (list :name (elmtui.core.event-channels:name x)
        ;;                :enqueued (cl-events.channel:channel-length raw-channel)
        ;;                :closed (cl-events.channel:channel-closed raw-channel)
        ;;                :queue-length (cl-events.channel:channel-length raw-channel)))
        ;;      *active-event-channels*)
        ;;     nil)
        :shutdown-requested *shutdown-requested*
        :last-event-time (gethash :last-event-time *event-loop-metrics* 0)
        :last-event (gethash :last-event *event-loop-metrics* nil)
        :processed-event-count (gethash :processed-event-count *event-loop-metrics* 0)
        :average-processing-time-ms
        (if (> (gethash :processed-event-count *event-loop-metrics* 0) 0)
            (/ (gethash :total-processing-time *event-loop-metrics* 0.0)
               (gethash :processed-event-count *event-loop-metrics* 0))
            0.0)))

(defun get-event-queue-length ()
  "Get the sum of approximate queue lengths of all active event channels."
  (if *active-event-channels*
      (loop for channel-obj in *active-event-channels*
            sum (let ((raw-ch (elmtui.core.event-channels:channel-of channel-obj)))
                  (if raw-ch
                      (cl-events.channel:channel-length raw-ch)
                      0)))
      0))

(defvar *event-loop-instrumentation-hooks* nil
  "List of instrumentation hook functions for event loop metrics/tracing.")

(defun instrument-event-loop (event)
  "Instrumentation hook for debugging/profiling."
  (dolist (hook *event-loop-instrumentation-hooks*)
    (funcall hook event)))

;; (defmethod as-plist ((style style-set))
;;   "Convert a style-set to a property list."
;;   (styles-list style))
