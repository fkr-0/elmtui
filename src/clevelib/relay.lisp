(uiop:define-package :cleve-elm.relay
  (:use :cl :log4cl)
  (:export :relay
    :relay-pool
    :sink-handlers
    :relay-update-fn
    :relay-message-loop
    :produce-emission-fn
    :link-emitter
    :exec-handle
    :message-loop-error
    :message-loop-error-relay
    :message-loop-error-message
    :message-loop-error-handler
    :message-loop-error-cause
    :relay-receive-handler
    :message-handlers)
  (:import-from :cleve-elm.event :make-event :event-source)
  (:import-from :cleve-elm.message
    :message :message-type :message-target :async-handle :reenqueue-handle)
  (:import-from :cleve-elm.emitter :emitter :emission-sinks :append-hash)
  (:import-from :cleve-elm.translator :translate)
  (:import-from :cleve-elm.thread-pool :start-thread)
  (:import-from :cleve-elm.queue :enqueue))

(in-package :cleve-elm.relay)



(defclass relay ()
  ((pool :initform (cleve-elm.thread-pool:make-thread-pool)
     :accessor relay-pool
     :documentation "A thread pool to handle asyncronicity.")
    (handlers :initform (make-hash-table :test #'equal) :accessor sink-handlers :documentation "A hash table of event handlers")
    (update-fn :initarg :update-fn :initform nil :accessor relay-update-fn :documentation "A function to be called when the relay is updated")
    (message-loop :initform nil :accessor relay-message-loop :documentation "The message loop for this relay"))
  (:documentation "A relay is an object that can receive events and is
          responsible for allowing sinks to register handlers processing them as well
          as the dispatching process."))

(defmethod print-object ((relay relay) stream)
  (print-unreadable-object (relay stream :type t :identity t)
    (format stream "<L:~a|H:~a|P:~a>"
      (relay-message-loop relay) (hash-table-count (sink-handlers relay))
      (relay-pool relay))))

(defmethod start ((relay relay))
  (cleve-elm.thread-pool:start-thread (relay-pool relay)
    (lambda ()
      (log-debug "Relay ~a started" relay)
      (cleve-elm.event-loop:run-loop (relay-message-loop relay)))
    :description (format nil "Relay ~a Event Loop Thread" relay)))

(defmethod running-p ((relay relay))
  (cleve-elm.event-loop:event-loop-active-p (relay-message-loop relay)))

(defmethod stop ((relay relay))
  (cleve-elm.event-loop:stop-loop (relay-message-loop relay)))

;; (defmethod new ((relay (eql relay)) &key)
;;   (make-instance 'relay))

(defmethod initialize-instance :after ((relay relay) &key)
  ;; (when parent
  ;;   (setf (relay-parent relay) parent))
  ;; (when name
  ;;   (setf (relay-name relay) name))
  (setf (relay-message-loop relay)
    (make-instance 'cleve-elm.event-loop:event-loop
      :wait t
      :fps 10
      :loop-fun (relay-receive-handler relay))))

;; Emit

(defgeneric produce-emission-fn (translator event-type emitter)
  (:documentation "Generates a function to emit events for a given event type.

   Arguments:
   - translator: The object responsible for translating and handling events.
   - event-type: The type of event for which the emission function is being created.
   - emitter: The source of the event emission.

   Returns:
   - A lambda function capable of emitting events of the specified type.

   Throws an error if no specific method is defined for the provided event type.")
  (:method (translator event-type emitter)
    (error "No event emitter translator defined for event type ~a" event-type)))

(defmethod produce-emission-fn ((translator relay) event-type emitter)
  "Produces a function for relaying events of a specific type from an emitter.

   Arguments:
   - translator: The relay instance handling event translation and forwarding.
   - event-type: The type of event to be handled.
   - emitter: The source emitting the events.

   Returns:
   - A lambda function that, when called, creates and enqueues an event of the specified type."
  (log-debug "Register EmissionFN: ~a received event-type:~a  source:~a" translator event-type emitter)
  (lambda (&rest args)
    ;; (log-debug "Relay ~a received event-type:~a args:~a source:~a" translator event-type args emitter)
    (let ((e (apply #'make-event event-type args))
           (event-type (intern (string-upcase (symbol-name event-type)) 'keyword)))
      (setf (event-source e) emitter)
      (enqueue-message translator (translate e event-type)))))

(defgeneric link-emitter (translator emitter &rest types)
  (:documentation "Associates an emitter with a translator for specific event types.

   Arguments:
   - translator: The object handling the translation of events.
   - emitter: The source object emitting events.
   - types: A list of event types to be linked to the emitter.

   This function establishes a connection between an emitter and a translator for specified event types."))

(defmethod link-emitter ((translator relay) (emitter emitter) &rest types)
  "Links an emitter to a relay for specified event types.

   Arguments:
   - translator: The relay instance to handle event translation.
   - emitter: The emitter instance to be linked.
   - types: A rest argument specifying the event types to be linked.

   This method iterates over the given event types and registers an emission function for each."
  (loop for event-type in types do
    (append-hash (emission-sinks emitter)
      (produce-emission-fn translator event-type emitter)
      event-type)))

;; Translate & Enqueue

(defmethod enqueue-message ((relay relay) message)
  (cleve-elm.queue:enqueue
    (cleve-elm.event-loop:i-queue
      (relay-message-loop relay))
    message))

(defmethod exec-handle ((relay relay))
  "Return a function that can be used to execute a function in the relay's thread pool.
  The function will enqueue the result of the function in the relay's message queue."
  ;; (apply #'cleve-elm.thread:submit-job (event-system-pool relay) function args)
  (lambda (function &rest args)
    (apply #'cleve-elm.thread-pool:start-thread
      (list (relay-pool relay)
        (lambda ()
          (let ((r (apply function args)))
            (when r (enqueue-message relay r))))
        :description (format nil "Relay ~a" "placeholder")))))



;; (defmethod target-handler ((relay relay) target)
;;   (gethash target (sink-handlers relay)))

;; (defmethod link-relay ((target message-handler) (relay relay))
;;   "Link RELAY to TARGET. This method is called by the event-sink when a relay is
;;           connected to it. The target should store the relay and use it to send
;;           messages to the relay.
;;           Arguments:
;;           TARGET - the event target
;;           RELAY - the relay
;;           Return value: nil
;;           Side effects: the relay is stored"
;;   (setf (gethash (relay-handlers relay) (handler-id target)) target))


;; FILEPATH: /home/user/code/lisp/clevelib/src/relay.lisp

(define-condition message-loop-error (error)
  ((relay :initarg :relay :reader message-loop-error-relay)
    (message :initarg :message :reader message-loop-error-message)
    (handler :initarg :handler :reader message-loop-error-handler)
    (cause :initarg :cause :reader message-loop-error-cause)))

(defmethod relay-message ((relay relay) message &rest args &key &allow-other-keys)
  "The message loop for a relay. This method is called by the event-loop when a message is received.
  Arguments:
  RELAY - the relay
  MESSAGE - the message
  Return value: nil"
  (log-debug "Relay ~a received message ~a" relay message)
  (let* ((message-handlers (message-handlers relay message)))
    (log-info "Relay ~a received message ~a. Found ~A handlers"
      relay message (length message-handlers))
    (when (eql :quit (message-type message))
      (stop relay))
    (setf (async-handle message) (exec-handle relay)) ; callback to enque async tasks
    (setf (reenqueue-handle message) (lambda (message )(enqueue-message relay message)))
    (if (relay-update-fn relay)
      (funcall (relay-update-fn relay) message)
      (loop for target-handlers in message-handlers
        do (loop for handler in target-handlers do
             (handler-case
               (let ((result (funcall handler message))) ; call the handler
                 (when result
                   (enqueue-message relay result))) ; enqueue the result
               (error (c)
                 (signal 'message-loop-error
                   :relay relay
                   :message message
                   :handler handler
                   :cause c)
                 (error c)
                 ;; (error 'message-loop-error
                 ;;   :relay relay
                 ;;   :message message
                 ;;   :handler handler
                 ;;   :cause c)
                 )))))))
;; (cond
;;   ((eq message-dispatch-strategy :bubble)
;;     (bubble-message relay message))
;;   ((eq message-dispatch-strategy :capture)
;;     (capture-message relay message))
;;   ((eq message-dispatch-strategy :broadcast)
;;     (broadcast-message relay message))
;;   (t
;;     (error "Unknown dispatch strategy ~a" message-dispatch-strategy)))
;; ))

(defmethod relay-receive-handler ((relay relay))
  (lambda (message) (relay-message relay message)))

(defmethod message-handlers ((relay relay) (m message))
  "Return a list of functions that can handle the message M.
The handlers are grouped by message type and (optionally) by message target.
If message target is nil, all handlers of same type match."
  (log-info "Relay ~a received message ~a, type:~a" relay m (message-type m))
  (let* ((trgt (message-target m))
          (r nil)
          (hdl (or (gethash (intern (string-upcase (symbol-name (message-type m))) 'keyword) (sink-handlers relay) ) (make-hash-table)))
          ;; (dud (log-info "Target: ~a, handlers: ~a" trgt hdl))
          (fns (if trgt (gethash trgt hdl)
                 (maphash
                   (lambda (k v) (declare (ignorable k)) ;; (log-info "~a v r ~a" v r)
                     (push v r))
                   hdl))))
    (log-info "Target: ~a, handlers: ~a" trgt fns)
    (if trgt fns r)))
