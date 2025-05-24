(uiop:define-package :cleve-elm.api
  (:use :cl)
  (:nicknames :cleve.api)
  (:export
    :get-children
    :ems-root
    :on-event
    :translate-event-to-message
    :emit
    :get-parent
    :root-to-target-path
    :events
    :event-type
    :simple-emitter
    :simple-sink
    :simple-translator
    :on-event
    :on-message
    :connected-sinks
    :relay-message
    :connected-messengers
    :target-messengers
    :set-target-messengers
    :broadcast-p
    :propagation-stopped-p
    :capture-p
    :bubble-p
    :simple-sink
    :connect-sink))

(in-package :cleve-elm.api)



;; Events
;; We do not want to make assumptions about characteristics of events.
;; While we find it reasonable that they should carry a type, we give a default
;; implementation in case someone disagrees
(defgeneric event-type (event)
  (:method ((ev t)) :untyped-event)
  (:documentation "An event has a type."))
;; (defgeneric events (sink))

;; Event Handling and Emitting - Emitter and Sink
;; on-event: an event-handler is anyone that implements this method
;; our sinks will use this method to translate events into messages
;; and relay them to a message system
(defgeneric on-event (event-handler event &rest args)
  (:documentation "Handle an event."))

;; An Emitter emits events that get sunk in sinks. Therefore
;; they need to have a link. Emission will turn out to boil down
;; to calling a sinks on-event method.
(defgeneric connect-sink (emitter sink event-type &rest args)
  (:documentation "Connect a sink to the emitter."))

;; Emitter - connect, emit.
;; albeit being unintuitive and i do not thoroughly understand the
;; principle behind it, the concept here is:
;; "while you might as well take care of the full emitters semantics
;; by just implementing your own emit method, one could argue that
;; managing connected sinks is a strict subset of the complexity of an
;; emit behavior, but it is exactly the implementation detail that when
;; we assume its existence allows us to offer you a generic emit method
;; (albeit in this case the work we save for the user is minimal)"
(defgeneric connected-sinks (emitter event-type &rest args)
  (:documentation "Return the sinks connected to the emitter."))

;; either you use the impl below with your connected-sinks method
;; or you implement your own emit method, pick one.
(defgeneric emit (emitter event &rest args)
  (:documentation "Emit an event."))

(defmethod emit ((emitter t) event &rest args)
  (declare (ignorable args))
  (dolist (sink (connected-sinks emitter event))
    (handler-case
      (on-event sink event)
      (error (e)
        (format t "Error handling event ~A: ~A~%" event e)))))

;; Event to Message Translation
;; special characteristic of an ems is that at some point the gap between
;; events and messages needs to be bridged. this is the responsibility of
;; a translation mechanism abstracted in the requirement of a generic
;; translate-event-to-message method. core idea here is as in general, that we
;; do not want to rely on any assumptions, what an concrete event or message is
;; in the users implementation
(defgeneric translate-event-to-message (event-message-system event &rest args)
  (:documentation "Translate an event to a message."))

;; Messaging - Messenger, Message-System
;; a messenger is anyone that you can pass a message to. its a bit tricky
;; because at this point we can argue that an ems and a participating client are
;; somehow equal in the sense that they both provide handlers that allows anyone to
;; pass them a message.
(defgeneric on-message (messenger message &rest args)
  (:documentation "Handle a message."))

;; Message Handling and Relaying
;; but for now it seems as if this is simply ok. because while you can give an
;; ems a message much the same as a messenger, it is special in that it enforces
;; some relay mechanism. so we can say that an ems is a messenger, but a messenger
;; is not necessarily an ems.
;; it is an pretty much arbitrary decision to centralize relay responsibility on
;; message-systems
(defgeneric relay-message (message-system message &rest args &key &allow-other-keys)
  (:documentation "Relay a message."))

;; pretty much analogous to the connected-sinks method, we can offer a generic
;; implementation of the connected-messengers method, but you can also implement
;; your own relay-message method, pick one.
(defgeneric connected-messengers (message-system &rest args)
  (:documentation "Return the messengers connected to the message-system."))

(defmethod relay-message ((broadcasting-message-system t) message &rest args &key &allow-other-keys)
  (declare (ignorable args))
  (dolist (messenger (connected-messengers broadcasting-message-system))
    (handler-case
      (on-message messenger message)
      (error (e)
        (format t "Error relaying message ~A: ~A~%" message e)))))

;; Summary: in the simplest case we only require: give us some means of
;; retrieving the list of messengers, we will give them messsages. since
;; we have no means of directing messages to specific messengers, we
;; simply broadcast the message to all connected messengers.


;; Targeting Messages
;;
;;our implementation so far basically allows us to
;; broadcast messages to all connected messengers. but in many cases we want to
;; target messages to specific messengers. this is the responsibility as such
;; the minimal requirement for the "optional feature" of targeted messaging
;; is trivally: a method on messages that returns target(s)
(defgeneric target-messengers (message &rest args)
  (:documentation "Return the target messengers of the message.")
  (:method ((message t) &rest args)
    (declare (ignorable args message))
    nil))  ;; Default implementation returns nil

;; here i am not totally certain that we do the most sensible
;; thing. but it seems necessary to demand this facility...
(defgeneric set-target-messengers (message new-target-messengers &rest args)
  (:documentation "Set the target messengers of the message."))
;; ... to at least provide the ever so comfy setf impl.
(defmethod (setf target-messengers) (new-target-messengers (message t))
  (set-target-messengers message new-target-messengers))

;; thanks to default impl of target-messengers, we default for untargetted,
;; any more refined facility will have to take care of declaring the intention
;; to broadcast itself by specializing
(defmethod broadcast-p ((message t) &rest args)
  (declare (ignorable args))
  (or
    (not (target-messengers message))
    (eq (target-messengers message) :broadcast)))


;; now that we got an api to make a message adressable,
;; we can imagine a more directed implemtation of a relay:
(defmethod relay-message (targeting-message-system  (targeting-message t) &rest args &key &allow-other-keys)
  (declare (ignorable args))
  (if (target-messengers targeting-message)
    (dolist (messenger (target-messengers targeting-message))
      (on-message messenger targeting-message)) ;; all targets given by the message are processed
    ;; no targets exist, by convention, we fall back to the default behavior of relaying the message to all messengers
    (dolist (messenger (connected-messengers targeting-message-system))
      (on-message messenger targeting-message)))
  (values nil))

;; summary: we provide the complex mechanism of message targeting, by only
;; requiring the user to give us some notion of retrieving and setting a messages target.
;; still quite obvious but hey.



;; Propagation Mechanisms - capture, bubble, inhibit probagation
;;
;; The concepts above are quite specialized mechanisms to simplify message/event
;; direction in uis by operating on the assumption that receivers are nested in a DAG
;; therefore we require basic operations that allow us to navigate the dag:

;; we used the now well known concept of tiered or cascaded abstraction (my term,
;; do not know the approp one)
;; give us the absolute minimum for the required features (get-parent)
;; and we derive some generic solution for this.
;; if you have more specific requirements, implement the generic solution instead

;; since all those capture bubble mechanisms are simply options that you tick
;; for your message(ing system), we can not avoid to demand their definition
;; here.

;; helpers:
;; should we query propagation-stopped-p or force an implemetation
;; of stop-propagation?
(defgeneric propagation-stopped-p (message &rest args)
  (:documentation "Return T if the propagation of the message should be stopped."))

(defgeneric capture-p (message &rest args)
  (:documentation "Return T if the message should be captured."))

(defgeneric bubble-p (message &rest args)
  (:documentation "Return T if the message should be bubbled."))

(defgeneric get-parent (nested-messenger &rest args &key &allow-other-keys)
  (:documentation "Return the parent of the nested messenger, or NIL if it is the root."))

;; we do not need this, but it feels wrong to not at least mention it
(defgeneric get-children (nested-messenger &rest args &key &allow-other-keys)
  (:documentation "Return the children of the nested messenger, or NIL if it has none."))

(defgeneric root-to-target-path (nested-messenger &rest args &key &allow-other-keys)
  (:documentation "Some means of obtaining the order of messengers from root
to target that we use to facilitate the propagation of events."))

;; as before: if you do not want to rely on our squishy parental structures,
;; better just specialize the method to not call the get-parent meth.
(defmethod target-to-root-path ((target t) &rest args &key &allow-other-keys)
  "Return the path from the target to the root."
  (let ((path nil)
         (current target))
    (loop
      (push current path)
      (let ((parent (apply #'get-parent (append (list current) args))))
        (if parent
          (setf current parent)
          (return path))))))
(defmethod root-to-target-path ((target t) &rest args &key &allow-other-keys)
  (apply #'target-to-root-path (append (list target) args)))

;; discuss: should we have a separate method for each state? is without any
;; bells and whistles introducing the state parameter a good idea? in general,
;; we have to acknowledge the fact that we can approach this processing in two
;; fundamental different ways. either we let our pms call all the
;; propagated+at-target handling as some overlord, or we truly travel along with
;; the message from node to node with each deciding what their job is to do. my
;; intuition that the latter, while allowing to implicitly inhibit propagation
;; by simply not passing it along. however it sound plausible that we would somehow have to track
;; states of messages more closely to ensure each messenger knows its position in the path,
;; but this is hypothetical.
;; the first variant appears to be pretty straight forward. a malus is that  we can not just
;; let anyone stop a message propagation while handling. it needs to be signaled to the
;; orchestring loop below
(defgeneric ems-root (ems &rest args)
  (:method ((ems t) &rest args)
    (declare (ignorable args ems))
    (when (connected-messengers ems)
      (ems-root (car (connected-messengers ems)))))
  (:documentation "Return the root of the ems."))

(defmethod broadcast (ems root message &rest args &key &allow-other-keys)
  "Broadcast a message from the root of the ems by iteratively retrieving children
through get-children and calling on-message on them."
  (declare (ignorable args))
  (set-target-messengers message :broadcast)
  (let ((children (apply #'get-children (append (list root) args))))
    (dolist (child children)
      (apply #'on-message (append (list child message :state :broadcast) args))
      (apply #'broadcast (append (list ems child message) args)))))



(defmethod relay-message ((propagating-message-system t) (propagating-message t) &rest args &key &allow-other-keys)
  (declare (ignorable args))
  (if (broadcast-p propagating-message)
    (progn ;; TODO make broadcast call on-message on target + children, for now:
      (apply #'on-message ;; on target
        (append (list (ems-root propagating-message-system)
                  propagating-message
                  :state :broadcast)
          args))
      (apply #'broadcast ;; on children
        (append (list propagating-message-system
                  (ems-root propagating-message-system)
                  propagating-message)
          args))) ;;
    (let ((trgs (if (listp (target-messengers propagating-message))
                  (target-messengers propagating-message)
                  (list (target-messengers propagating-message)) )))
      (dolist (trg trgs)
        (let ((path (apply #'root-to-target-path (append (list trg) args))))
          (when (capture-p propagating-message)
            (dolist (node (butlast path))
              (unless (propagation-stopped-p propagating-message)
                (apply #'on-message (append (list node propagating-message :state :capture) args)))))
          (unless (propagation-stopped-p propagating-message)
            (apply #'on-message (append (list (car (last path)) propagating-message :state :at-target) args)))
          (when (bubble-p propagating-message)
            (dolist (node (cdr (reverse path)))
              (unless (propagation-stopped-p propagating-message)
                (apply #'on-message (append (list node propagating-message :state :bubble) args))))))))))


;; summary. we achieved a good subset of necessary features by closely following those
;; minimal assumptions

;; while keeping requirements minimal, it is possible that in the (full fledged?)
;; relay method above we make performance compromises that would not be strictly necessary

;; note that at this stage even at the api level only a toy version of a ems is
;; declared.

;; the correct way to enforce queues for events and messages on an api level is unclear
;; it may be an implementation detail that would be wrong to list here. discuss.

;; we also do not have means to empower messengers handling a message to in turn
;; enqueue messages or async tasks with the ems

;; to see whether this will turn out feasible, we decide to sketch a mechanism that
;; requires the ems to pass handlers allowing the enqueuing of new tasks/messages
;; to each message

(defgeneric async-exec (message task &rest args))
(defgeneric respond (message new-message &rest args))

(defgeneric add-async-exec-handler(ems message &rest args))
(defgeneric add-response-handler(ems message &rest args))


;; == Example Ems ==


(defclass simple-sink () ((events :initform nil :initarg :sinks :accessor events)
                           (message-system :initform nil :initarg :message-system :accessor message-system)))
(defclass simple-emitter () ((sinks :initform nil :initarg :sinks :accessor sinks)))

(defmethod connected-sinks ((emitter simple-emitter) event-type &rest args)
  (declare (ignorable args))
  (sinks emitter))

(defmethod on-event ((sink simple-sink) event &rest args)
  (declare (ignorable args))
  (push event (events sink))
  (format t "Event received: ~A (~A)~%" event (events sink))
  (if (message-system sink)
    (on-message (message-system sink)
      (translate-event-to-message
        (message-system sink)
        event))))

(defmethod emit ((emitter simple-emitter) event &rest args)
  (declare (ignorable args))
  (dolist (sink (connected-sinks  emitter (event-type event)))
    (handler-case
      (on-event sink event)
      (error (e)
        (format t "Error handling event ~A: ~A~%" event e)))))




(defclass simple-translator () ())

(defmethod translate-event-to-message ((translator t) event &rest args)
  (declare (ignorable args))
  (list 'message event))

(defclass simple-receiver () ())

(defmethod on-message ((receiver simple-receiver) message &rest args)
  (declare (ignorable args))
  (format t "Message received: ~A~%" message))

(defclass simple-message-system ()
  ((messengers :initform nil :initarg :messengers :accessor messengers)))

(defmethod connected-messengers ((system simple-message-system) &rest args)
  (declare (ignorable args))
  (messengers system))

;; (defmethod relay-message ((system simple-message-system) message &rest args &key &allow-other-keys)
;;   (declare (ignorable args))
;;   (dolist (messenger (connected-messengers system))
;;     (handler-case
;;       (on-message messenger message)
;;       (error (e)
;;         (format t "Error relaying message ~A: ~A~%" message e)))))
