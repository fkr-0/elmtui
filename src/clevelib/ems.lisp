(uiop:define-package :cleve-elm.ems
  (:use :cl :log4cl)
  (:import-from :cleve-elm.event
   :event)
  (:import-from :cleve-elm.queue
   :enqueue)
  (:import-from :cleve-elm.event-loop
   :i-queue)
  (:import-from :cleve-elm.api
   :on-message
                :broadcast
   :capture-p
                :bubble-p
   :broadcast-p
                :propagation-stopped-p
   :target-messengers
                :relay-message
   :root-to-target-path
                :relay-message
   :on-event
                :add-response-handler
   :add-async-exec-handler
                :ems-root
   :get-children
                :get-parent
   :translate-event-to-message
                :relay-message)
  (:import-from :cleve-elm.message
   :async-handle
                :message-state
   :message-type
                :message-data
   :reenqueue-handle
                :message
   :event-message)
  (:import-from :cleve-elm.thread-pool :start-thread :make-thread-pool)
  (:documentation "Event Management System")
  (:export
   :start
   :stop
   :running-p
   :messenger
   :messenger-name
   :messenger-parent
   :messenger-children
   :enqueue-message
   :on-message
   :ems
   :ems-pool
   :ems-message-loop
   :add-response-handler
   :add-async-exec-handler))

(in-package :cleve-elm.ems)

(defclass ems ()
  ((root :initform nil :accessor ems-root-acc :initarg :root)
   (message-loop :initform nil
                 :accessor ems-message-loop
                 :documentation "The message loop for this relay")
   (pool :initform (make-thread-pool)
         :accessor ems-pool
         :documentation "A thread pool to handle asyncronicity.")
   (message-filter :initform nil :initarg :message-filter :accessor ems-message-filter
                   :documentation "A function (predicate) called with a message. If it returns NIL, the message is dropped.")
   (enable-logging :initform nil :initarg :enable-logging :accessor ems-enable-logging
                   :documentation "If T, processed messages are stored in message-log.")
   (message-log :initform (make-array 0 :adjustable t :fill-pointer 0) :accessor ems-message-log
                :documentation "Vector storing logged messages if enable-logging is T.")
   (enable-deduplication :initform nil :initarg :enable-deduplication :accessor ems-enable-deduplication
                         :documentation "If T, attempts to filter duplicate messages.")
   (dedup-table :initform (make-hash-table :test 'equal) :accessor ems-dedup-table
                :documentation "Hash table storing recent message keys and timestamps for deduplication.")
   (dedup-window :initform 1.0 :initarg :dedup-window :accessor ems-dedup-window
                 :documentation "Time window (in seconds) for message deduplication.")
   ;; Lifecycle Hooks
   (before-dispatch-hook :initform nil :initarg :before-dispatch-hook :accessor ems-before-dispatch-hook
                         :documentation "Function called with (ems message) before relaying.")
   (after-dispatch-hook :initform nil :initarg :after-dispatch-hook :accessor ems-after-dispatch-hook
                        :documentation "Function called with (ems message) after relaying (if not filtered/deduped).")
   (on-shutdown-hook :initform nil :initarg :on-shutdown-hook :accessor ems-on-shutdown-hook
                     :documentation "Function called with (ems) when stop is called."))
  (:documentation "Event Management System"))

(defmethod relay-message ((propagating-message-system ems) propagating-message &rest args &key &allow-other-keys)
  (declare (ignorable args))
  (log-debug "Relay message ~a, args: ~a, root: ~a" propagating-message args (ems-root propagating-message-system))
  (if (broadcast-p propagating-message)
      (progn
        (log-debug "Broadcasting message ~a ~a" propagating-message (append (list (ems-root propagating-message-system) propagating-message :state :broadcast) args))

        (apply #'on-message (append (list (ems-root propagating-message-system) propagating-message :state :broadcast) args))
        (apply #'broadcast (append (list propagating-message-system (ems-root propagating-message-system) propagating-message) args)))
      (let ((trgs (if (listp (target-messengers propagating-message))
                      (target-messengers propagating-message)
                      (list (target-messengers propagating-message)) )))
        (dolist (trg trgs)
          (log-debug "Relaying message ~a to target ~a" propagating-message trg)
          (let ((path (apply #'root-to-target-path (append (list trg) args))))
            (when (capture-p propagating-message)
              (dolist (node (butlast path))
                (unless (propagation-stopped-p propagating-message)
                  (apply #'on-message (append (list node propagating-message :state :capture) args))
                  ;; (on-message node propagating-message :state :capture)
                  )))
            (unless (propagation-stopped-p propagating-message)
              (apply #'on-message (append (list (car (last path)) propagating-message :state :at-target) args))
              ;; (on-message (car (last path)) propagating-message :state :at-target)
              )
            (when (bubble-p propagating-message)
              (dolist (node (cdr (reverse path)))
                (unless (propagation-stopped-p propagating-message)
                  (apply #'on-message (append (list node propagating-message :state :bubble) args))
                  ;; (on-message node propagating-message :state :bubble)
                  ))))))))

(defmethod print-object ((ems ems) stream)
  "Print the EMS to STREAM."
  (print-unreadable-object (ems stream :type t :identity t)
    (format stream "~a|Root:~a|Pool:~a"
            (type-of ems)
            (ems-root-acc ems)
            (ems-pool ems))))

(defmethod ems-root ((ems ems) &rest args)
  (declare (ignorable args))
  (ems-root-acc ems))
(defmethod (setf ems-root) (new-value (ems ems) &rest args)
  (declare (ignorable args))
  (setf (ems-root-acc ems) new-value))

;; Helper for deduplication
(defun get-message-key (msg)
  "Generates a key for message deduplication (simple version)."
  (sxhash (cons (message-type msg) (message-data msg)))) ; Hash based on type and data

(defmethod initialize-instance :after ((relay ems) &key)
  (setf (ems-message-loop relay)
        (make-instance 'cleve-elm.event-loop:event-loop
                       :wait t
                       :fps 10
                       :loop-fun (let ((filter (ems-message-filter relay))
                                       (dedup-enabled (ems-enable-deduplication relay))
                                       (dedup-table (ems-dedup-table relay))
                                       (dedup-window-internal (* (ems-dedup-window relay) internal-time-units-per-second)))
                                   (lambda (msg)
                                     (when msg ; Ignore nil dequeued events
                                       (let ((is-duplicate nil))
                                         ;; 1. Deduplication Check
                                         (when dedup-enabled
                                           (let* ((key (get-message-key msg))
                                                  (now (get-internal-real-time))
                                                  (last-seen (gethash key dedup-table 0)))
                                             (if (<= (- now last-seen) dedup-window-internal)
                                                 (progn
                                                   (setf is-duplicate t)
                                                   (log-debug "Duplicate message detected: ~S" msg))
                                                 (setf (gethash key dedup-table) now)))) ; Update timestamp

                                         (unless is-duplicate
                                           ;; 2. Filtering Check
                                           (if (or (not filter) (funcall filter msg)) ; Check filter
                                               (progn
                                                 ;; 3. Before Dispatch Hook
                                                 (when (ems-before-dispatch-hook relay)
                                                   (funcall (ems-before-dispatch-hook relay) relay msg))
                                                 ;; 4. Logging
                                                 (when (ems-enable-logging relay)
                                                   (vector-push-extend msg (ems-message-log relay)))
                                                 ;; 5. Relay
                                                 (relay-message relay msg)
                                                 ;; 6. After Dispatch Hook
                                                 (when (ems-after-dispatch-hook relay)
                                                   (funcall (ems-after-dispatch-hook relay) relay msg)))
                                               (log-debug "Message filtered out: ~S" msg)))))))))) ; End filter check

(defmethod translate-event-to-message ((ems ems) (e event) &rest args)
  ""
  (declare (ignorable args))
  (make-instance 'event-message :event e))

(defmethod on-event ((ems ems) event &rest args)
  "handle the event by translating it to a message
and sending it to the message bus."
  (declare (ignorable args))
  (on-message ems (translate-event-to-message ems event)))

(defmethod enqueue-message ((ems ems) message)
  (cleve-elm.queue:enqueue
   (cleve-elm.event-loop:i-queue
    (ems-message-loop ems))
   message))

(defmethod add-async-exec-handler ((ems ems) (m message) &rest args)
  "Return a function that can be used to execute a function in the relay's thread pool.
  The function will enqueue the result of the function in the relay's message queue."
  (declare (ignorable args))
  (setf (async-handle m)
        ;; (apply #'cleve-elm.thread:submit-job (event-system-pool relay) function args)
        (lambda (function &rest args)
          (apply #'cleve-elm.thread-pool:start-thread
                 (list (ems-pool ems)
                       (lambda ()
                         (let ((r (apply function args)))
                           (when r (enqueue-message ems r))))
                       :description (format nil "Relay ~a" "placeholder")))))) ; callback to enque async tasks

(defmethod add-response-handler ((ems ems)
                                 (m message) &rest args)
  (declare (ignorable args))
  (setf (reenqueue-handle m)
        (lambda (new-message)
          (on-message ems new-message))))

(defmethod on-message ((ems ems) message &rest args)
  (declare (ignorable args))
  (add-async-exec-handler ems message)
  (add-response-handler ems message)
  (enqueue-message ems message))


(defmethod start ((ems ems))
  (cleve-elm.thread-pool:start-thread (ems-pool ems)
                                      (lambda ()
                                        ;; (log-debug "Ems ~a started" ems)
                                        (cleve-elm.event-loop:run-loop (ems-message-loop ems)))
                                      :description (format nil "Relay ~a Event Loop Thread" ems)))

(defmethod running-p ((ems ems))
  (cleve-elm.event-loop:event-loop-active-p (ems-message-loop ems)))

(defmethod stop ((ems ems))
  (cleve-elm.event-loop:stop-loop (ems-message-loop ems))
  ;; Call shutdown hook
  (when (ems-on-shutdown-hook ems)
    (funcall (ems-on-shutdown-hook ems) ems)))

;; Message Log / Replay Functions
(defun get-message-log (ems)
  "Returns the current message log (as a vector)."
  (copy-seq (ems-message-log ems)))

(defun clear-message-log (ems)
  "Clears the message log."
  (setf (fill-pointer (ems-message-log ems)) 0))

(defun replay-messages (ems messages-to-replay)
  "Enqueues a sequence of messages for replay."
  (log-info "Replaying ~D messages..." (length messages-to-replay))
  (map nil (lambda (msg) (enqueue-message ems msg)) messages-to-replay))


(defclass messenger ()
  ((name :initarg :name :accessor messenger-name :documentation "The name of the entity." :initform (symbol-name (gensym)))
   (parent :initform nil :accessor messenger-parent :documentation "The parent entity." :initarg :parent)
   (handlers :initform (make-hash-table :test #'equal) :accessor entity-handlers :documentation "A hash table of message handlers.")
   (children :initform nil :accessor messenger-children
             :documentation "The list of child entities."))
  (:documentation "An entity that supports propagation in a hierarchical structure."))

(defmethod print-object ((entity messenger) stream)
  "Print the PROPAGATION-ENTITY to STREAM."
  (print-unreadable-object (entity stream :type t :identity t)
    (format stream "~a|Parent:~a|Children:~a"
            (messenger-name entity)
            (and (messenger-parent entity) (messenger-name (messenger-parent entity)))
            (length (messenger-children entity)))))

(defmethod initialize-instance :after ((entity messenger) &key parent)
  (setf (messenger-children entity) nil)
  (if parent
      (add-child parent entity)))

(defmethod get-children ((entity messenger) &rest args &key &allow-other-keys)
  (declare (ignorable args))
  (messenger-children entity))

(defmethod get-parent ((entity messenger) &rest args &key &allow-other-keys)
  (declare (ignorable args))
  (messenger-parent entity))

(defmethod add-child ((entity messenger) child)
  (push child (messenger-children entity))
  (setf (messenger-parent child) entity))
