(uiop:define-package :cleve-elm.emitter
  (:use :cl )
  (:import-from :cleve-elm.api :on-event :connect-sink :connected-sinks :emit)
  (:import-from :cleve-elm.event :make-event :event-source :event-type)
  (:documentation "Event emitter and event sink classes and functions.")
  (:export
    :emit
    :emitter
    :connect-sink
    :emission-sinks
    :append-hash))

(in-package :cleve-elm.emitter)

(defclass emitter ()
  ((sinks :initform (make-hash-table :test #'equal) :accessor emission-sinks :documentation "A hash table of event hooks linking
  event types emittet to sinks that are responsible to translate them into relevant messages for the user interface."))
  (:documentation "An event emitter is an object that can emit events. It is linked
          to event sinks, which receive the events. The event emitter is responsible for
          calling the event sinks with the correct arguments. It may request a \"event-translatoring\" function
          from the event event-translator, which it can call with the correct arguments."))

(defun append-hash (h-map val hashkey)
  "Append VAL to the list of values stored in H-MAP under HASHKEY.
If no value is stored under HASHKEY,
create a new list with VAL as its only element."
  (let ((old (gethash hashkey h-map)))
    (if old
      (setf (gethash hashkey h-map) (append old (list val)))
      (setf (gethash hashkey h-map) (list val))))
  h-map)

(defmethod connect-sink ((event-emitter emitter) event-sink event-type &rest other-event-types)
  "Connect EVENT-SINK to EVENT-EMITTER for EVENT-TYPE. The event sink is
responsible for implementing the on-event generic method.

Arguments:
EVENT-EMITTER - the event emitter
EVENT-SINK - the event sink
EVENT-TYPE - the event type
&rest OTHER-EVENT-TYPES - additional event types to connect to the event sink
Return value: nil

Example:
(connect-sink emitter sink 'event-type-1 'event-type-2)"
  (dolist (ev-type (append (list event-type) other-event-types))
    (append-hash (emission-sinks event-emitter) event-sink ev-type)))

(defmethod connected-sinks ((event-emitter emitter) event-type &rest args)
  "Return a list of all connected sinks for EVENT-TYPE."
  (declare (ignorable args))
  (gethash event-type (emission-sinks event-emitter)))

;; (defgeneric emit (event-emitter event-type &rest args) ; &key target data priority)
;;   (:documentation "Emit an event of type EVENT-TYPE. The event is passed to all
;; linked EVENT-SINKs with the following keyword arguments:
;; :TARGET - the target of the event
;; :DATA - the data of the event
;; :PRIORITY - the priority of the event
;; Dispatching to relevant targets is the responsibility of the EVENT-SINK. The
;; EVENT-EMITTER is responsible for calling the SINK-EVENT-FN function of the
;; EVENT-SINK with the correct arguments.
;; Arguments:
;; EVENT-EMITTER - the event emitter
;; EVENT-TYPE - the event type
;; &key
;; TARGET - the target of the event
;; DATA - the data of the event
;; PRIORITY - the priority of the event
;; Return value: nil"))

;; (defmethod emit ((event-emitter emitter) event-type &rest args) ; &key target data priority)
;;   "Emit an event of type EVENT-TYPE. The event is passed to all"
;;   (let ((sinks (gethash event-type (emission-sinks event-emitter))))
;;     (loop for event-translator-producer in sinks
;;       do (apply event-translator-producer args))))
(defmethod emit ((event-emitter emitter) event-type &rest args) ; &key target data priority)
  "Emit an event of type EVENT-TYPE. The event is passed to all"
  (let ((sinks (connected-sinks event-emitter event-type)))
    (loop for sink in sinks
      do (let ((e (apply #'make-event event-type args))
                ;; (event-type (intern (string-upcase (symbol-name event-type)) 'keyword))
                )
           (setf (event-source e) event-emitter)
           (on-event sink e)))))

;; (defgeneric event-translator-event-fn (event-translator event-type)
;;   (:documentation "Return the event-translator-event function for
;;     EVENT-TYPE with PRIORITY. The event-translator SINK provides this function
;; to the event emitter. If no event-translator-event is found, return NIL.
;;   Arguments:
;;     SINK - the event event-translator
;;     EVENT-TYPE - the event type
;;   Return value: the event-translator-event function (lambda (target data priority"))

;; (defmethod event-translator-event-fn ((event-translator event-event-translator) (event-type symbol) )
;;   "Return the event-translator-event function for EVENT-TYPE with PRIORITY. If no event-translator-event is
;;           found, return NIL."
;;   (lambda (&rest args)
;;     (let ((ev
;;             (apply #'make-event (append (list event-type) args) )))
;;       (translate-event event-translator ev))))
