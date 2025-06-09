;; src/core/event-channels.lisp
;; Enhanced definition of standard event channel types with filtering and priority support

(uiop:define-package :cleve-elm.core.event-channels
  (:nicknames :elmtui.core.event-channels)
  (:use :cl :log4cl)
  (:import-from :cleve-elm.channel
   :make-channel :make-filtered-channel :channel-add-filter :-> :<- :select)
  (:import-from :cleve-elm.queue
   :make-priority-queue)
  ;; Removed duplicate :nicknames, :use, and :import-from clauses that were here
  (:export
   ;; class names
   #:event-channel #:keyboard-channel #:mouse-channel #:system-channel
   #:ui-channel #:command-channel #:focus-channel #:message-channel
   #:no-wait
   ;; instance readers
   #:channel-of #:name #:priority #:filters #:handlers
   ;; constructors / helpers
   #:make-event-channel #:standard-event-channels #:wait-for-event
   #:add-event-filter #:remove-event-filter
   #:register-event-handler #:unregister-event-handler
   #:send-event #:receive-event #:try-receive-event
   #:channel-priority #:set-channel-priority))
(in-package #:cleve-elm.core.event-channels)

;;; ------------------------------------------------------------------
;;; Basic event-channel prototype
;;; ------------------------------------------------------------------

(defclass event-channel ()
  ((%channel   :accessor channel-of ; Removed :initarg, will be set in initialize-instance
               :documentation "Underlying raw channel object.")
   (%name      :initarg  :name :reader name  :type symbol
               :documentation "Symbolic identifier (e.g. :keyboard).")
   (%priority  :initarg  :priority
               :accessor priority          :type (member :high :normal :low)
               :initform :normal
               :documentation "Dispatch priority.")
   (%channel-capacity :initarg :channel-capacity :reader channel-capacity :type fixnum :initform 0
                      :documentation "Capacity of the underlying channel. 0 for unbuffered.")
   (%filters   :initarg :filters ; Allow passing filters to make-instance
               :initform nil :accessor filters  :type list)
   (%handlers  :initform nil :accessor handlers :type list))
  (:documentation "Common superclass for all typed event channels."))

(defmethod initialize-instance :after ((ec event-channel) &key)
  ;; Create the underlying channel after the event-channel instance is initialized,
  ;; so (name ec) and (filters ec) are available.
  (let (
        (channel-name-string
          (string (if (slot-boundp ec '%name) ; Use slot-value to access %name)
                      (name ec)
                      (gensym))))
        (ec-filters (filters ec))
        (ec-capacity (channel-capacity ec))) ; Get capacity from the event-channel instance
    (setf (channel-of ec)
          (if ec-filters
              (make-filtered-channel :filters ec-filters
                                     :name channel-name-string
                                     :capacity ec-capacity)
              (make-channel :name channel-name-string :capacity ec-capacity)))))

(defun %priority-weight (p)
  "Translate symbolic PRIORITY into an integer for `sort` / `<`."
  (ecase p
    (:high   0)
    (:normal 1)
    (:low    2)))

;;; ------------------------------------------------------------------
;;; Concrete subclasses – they differ only in :name / :priority defaults
;;; ------------------------------------------------------------------

(defmacro define-event-channel-class (name default-priority &optional (default-capacity 0))
  `(defclass ,name (event-channel) ()
     (:default-initargs :name ,(intern (string name) :keyword)
                        :priority ,default-priority
                        :channel-capacity ,default-capacity)
     (:documentation ,(format nil "~A events." (string-capitalize name)))))

(define-event-channel-class keyboard-channel :high 10) ;; Input channels might benefit from small buffer
(define-event-channel-class mouse-channel    :normal 10)
(define-event-channel-class system-channel   :high 5)   ;; Critical for shutdown, needs buffer
(define-event-channel-class ui-channel       :normal 5)  ;; UI events, buffer might be good
(define-event-channel-class command-channel  :high 5)   ;; For app commands, buffer is good
(define-event-channel-class focus-channel    :high 1)   ;; Focus events are usually singular
(define-event-channel-class message-channel  :normal 5) ;; Generic messages

;;; ------------------------------------------------------------------
;;; Constructor helper & typed wrappers --------------------------------

(defun make-event-channel (class &key priority filters capacity)
  "Low-level helper – CLASS is a subclass symbol of `event-channel'."
  ;; The :name and default :channel-capacity for the event-channel are set by
  ;; :default-initargs in define-event-channel-class.
  ;; The initialize-instance :after method for event-channel will create the
  ;; underlying cleve-elm.channel using (name instance), (filters instance), and (channel-capacity instance).
  (let ((initargs (list :priority (or priority :normal))))
    (when filters (setf (getf initargs :filters) filters))
    (when capacity (setf (getf initargs :channel-capacity) capacity))
    (apply #'make-instance class initargs)))

;;; Thin convenience wrappers --------------------------------------------------
(macrolet ((defwrapper (name class)
             `(defun ,name (&rest args)
                (apply #'make-event-channel ',class args))))
  (defwrapper make-keyboard-channel keyboard-channel)
  (defwrapper make-mouse-channel    mouse-channel)
  (defwrapper make-system-channel   system-channel)
  (defwrapper make-ui-channel       ui-channel)
  (defwrapper make-command-channel  command-channel)
  (defwrapper make-focus-channel    focus-channel)
  (defwrapper make-message-channel  message-channel))

;;; ------------------------------------------------------------------
;;; Filtering helpers -------------------------------------------------

(defun add-event-filter (chan fn)
  (push fn (filters chan))
  (setf (channel-of chan)
        (channel-add-filter (channel-of chan) fn))
  chan)

(defun remove-event-filter (chan fn)
  (setf (filters chan) (remove fn (filters chan)))
  (setf (channel-of chan)
        (if (filters chan)
            (make-filtered-channel :filters (filters chan))
            (make-channel)))
  chan)

;;; ------------------------------------------------------------------
;;; Dispatch & utility API -------------------------------------------

(defun register-event-handler (chan fn) (push fn (handlers chan)) chan)
(defun unregister-event-handler (chan fn) (setf (handlers chan) (remove fn (handlers chan))) chan)

(defun send-event (chan ev) (-> (channel-of chan) ev))
(defun receive-event (chan)  (<- (channel-of chan)))


(defun try-receive-event (chan &optional timeout)
  "Attempt to pull a message from CHAN.
Returns the message, or NIL on timeout / no data."
  (let* ((raw       (channel-of chan))
         (deadline  (when (and timeout (plusp timeout)) ; Ensure timeout is positive
                      (+ (get-internal-real-time)
                         (* timeout internal-time-units-per-second)))))
    (loop
      ;; fast path: data already waiting?
      (when (cleve-elm.channel:no-wait raw :send nil)
        (return (receive-event chan)))
      ;; timed-out?
      (when (and deadline ; Only check deadline if it was calculated
                 (> (get-internal-real-time) deadline))
        (return nil))
      ;; If no timeout, and no data, this loop would be infinite without a break.
      ;; However, try-receive-event is typically called when a timeout is expected
      ;; or in a context where blocking indefinitely is not desired.
      ;; For a non-timeout scenario, one might expect receive-event.
      ;; If timeout is nil or not positive, and no data, this will busy-wait with sleep.
      ;; This behavior might need further review based on intended use cases of try-receive-event without a valid timeout.
      (unless deadline ; If no valid timeout, and no data, don't loop indefinitely if not intended.
        (return nil)) ; Or, if it should block, this part needs rethinking. Assuming non-blocking intent if no valid timeout.

      ;; back-off a touch to avoid a busy loop
      (sleep 0.001))))

(defun set-channel-priority (chan new) (setf (priority chan) new))
(defun channel-priority      (chan)    (priority chan))

(defun standard-event-channels ()
  "Return an alist (KEY . CHANNEL) for all built-ins."
  (list (cons :keyboard (make-keyboard-channel))
        (cons :mouse    (make-mouse-channel))
        (cons :system   (make-system-channel))
        (cons :ui       (make-ui-channel))
        (cons :command  (make-command-channel))
        (cons :focus    (make-focus-channel))
        (cons :message  (make-message-channel))))

;; (defun wait-for-event (channels &key timeout)
;;   "Block until the **first ready event** arrives on one of CHANNELS.
;; Channels are probed in priority order.
;; Returns two values: *EVENT* and the originating *CHANNEL* object,
;; or NIL if TIMEOUT (seconds) expires."
;;   (let* ((sorted    (stable-sort (copy-seq channels)
;;                                  #'<
;;                                  :key (lambda (c)
;;                                         (%priority-weight (priority c)))))
;;          (deadline  (when timeout
;;                       (+ (get-internal-real-time)
;;                          (* timeout internal-time-units-per-second)))))
;;     (loop
;;       ;; 1) scan in priority order ---------------------------------
;;       (dolist (ec sorted)
;;         (when (cleve-elm.channel:no-wait (channel-of ec) :send nil)
;;           (return (values (receive-event ec) ec))))
;;       ;; 2) maybe timeout? -----------------------------------------
;;       (when (and timeout
;;                  (> (get-internal-real-time) deadline))
;;         (return nil))
;;       ;; 3) short pause – avoids pegging a core --------------------
;;       (sleep 0.001))))
(defun wait-for-event (event-channels &key timeout) ; Argument is now list of event-channel wrapper objects
  "Block until the **first ready event** arrives on one of EVENT-CHANNELS.
   Channels are probed in priority order.
   Returns two values: *EVENT* and the originating *EVENT-CHANNEL* object,
   or NIL if TIMEOUT (seconds) expires."
  (let* ((sorted-event-channels (stable-sort (copy-seq event-channels) ; Sort the wrapper objects
                                             #'<
                                             :key (lambda (ec) ; ec is an event-channel object
                                                    (%priority-weight (priority ec)))))
         (deadline  (when (and timeout (plusp timeout)) ; Ensure timeout is positive
                      (+ (get-internal-real-time)
                         (* timeout internal-time-units-per-second)))))
    (log-debug :event-channels.wait "WAIT-FOR-EVENT: Starting polling loop. Timeout: ~A s. Deadline: ~A" timeout deadline)
    (loop named event-poll-loop
          ;; 1) scan in priority order ---------------------------------
          do (dolist (ec sorted-event-channels) ; ec is an event-channel wrapper object
               (let ((raw-channel (channel-of ec)))
                 (if (cleve-elm.channel:no-wait raw-channel :send nil) ; Use channel-of to get raw channel
                     (progn
                       (log-info :event-channels.wait "WAIT-FOR-EVENT: Channel ~S indicated data via no-wait. Attempting receive." (name ec))
                       (let ((event (receive-event ec)))
                         (log-info :event-channels.wait "WAIT-FOR-EVENT: Received event ~S from channel ~S." event (name ec))
                         (return-from event-poll-loop (values event ec))))
                     nil
                     )))
             ;; 2) maybe timeout? -----------------------------------------
          when (and deadline ; Only check deadline if it was calculated
                    (> (get-internal-real-time) deadline))
            do (progn
                 (log-info :event-channels.wait "WAIT-FOR-EVENT: Timeout expired.")
                 (return-from event-poll-loop nil))
               ;; 3) short pause – avoids pegging a core --------------------
          do (progn
               (sleep 0.001)))))
