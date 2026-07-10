;;; src/events/bus.lisp
(in-package :cl-events.bus)

(defstruct (subscriber (:constructor %make-subscriber))
  topic ch)
(defstruct (event-bus (:constructor %make-event-bus))
  subs lock)

(defun make-event-bus () (%make-event-bus :subs (make-hash-table :test 'equal)
                                          :lock (bt:make-lock "bus")))

(defun %valid-topic-p (topic)
  (or (keywordp topic)
      (and (symbolp topic) (not (null topic)))
      (and (stringp topic) (> (length topic) 0))))

(defun subscribe (bus topic)
  (unless (%valid-topic-p topic)
    (error "Invalid event topic: ~S" topic))
  (let ((ch (cl-events.channel:make-channel)))
    (bt:with-lock-held ((event-bus-lock bus))
      ;; Preserve subscription order so delivery is deterministic.
      (setf (gethash topic (event-bus-subs bus))
            (append (gethash topic (event-bus-subs bus))
                    (list (%make-subscriber :topic topic :ch ch)))))
    ch))

(defun unsubscribe (bus topic ch)
  (bt:with-lock-held ((event-bus-lock bus))
    (setf (gethash topic (event-bus-subs bus))
          (remove ch (gethash topic (event-bus-subs bus))
                  :key #'subscriber-ch :test #'eq))))

(defmacro with-subscription ((ch bus topic) &body body)
  `(let ((,ch (subscribe ,bus ,topic)))
     (unwind-protect (progn ,@body)
       (unsubscribe ,bus ,topic ,ch))))

(defun %subscription-channel-closed-p (ch)
  (let ((real-ch (if (typep ch 'cl-events.channel:filtered-channel)
                     (cl-events.channel::filtered-channel-channel ch)
                     ch)))
    (cl-events.channel::channel-closed-p real-ch)))

(defun cleanup-closed-subscriptions (bus)
  "Remove subscribers whose channels have been closed. Returns removed count."
  (let ((removed 0))
    (bt:with-lock-held ((event-bus-lock bus))
      (maphash
       (lambda (topic subs)
         (let* ((live (remove-if (lambda (sub)
                                  (%subscription-channel-closed-p (subscriber-ch sub)))
                                subs))
                (dropped (- (length subs) (length live))))
           (incf removed dropped)
           (if live
               (setf (gethash topic (event-bus-subs bus)) live)
               (remhash topic (event-bus-subs bus)))))
       (event-bus-subs bus)))
    removed))

(defun publish-event (bus event)
  (let* ((topic (cl-events.protocols:event-topic event))
         (subs (progn
                 (unless (%valid-topic-p topic)
                   (error "Invalid event topic: ~S" topic))
                 (cleanup-closed-subscriptions bus)
                 (bt:with-lock-held ((event-bus-lock bus))
                   (copy-list (gethash topic (event-bus-subs bus)))))))
    ;; SUBSCRIBE appends, so DOLIST now delivers in subscription order.
    (dolist (s subs)
      (cl-events.channel:chan-put (subscriber-ch s) event))
    t))
