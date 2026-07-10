;;;===============================================================
;;; File: src/core/topic-registry.lisp
;;; Compatibility topic subscription registry.
;;;===============================================================
(uiop:define-package :elmtui.core.topic-registry
  (:use :cl)
  (:import-from :elmtui.core.topics
                #:make-topic-subscription
                #:topic-subscription-pattern
                #:topic-subscription-handler
                #:topic-subscription-priority
                #:topic-pattern-match-p)
  (:export
   #:subscribe
   #:subscribe-if
   #:unsubscribe
   #:publish
   #:publish-to-topic
   #:publish-to-channel
   #:subscribe-to-topic-on-channel
   #:unsubscribe-from-channel
   #:get-channel-subscriptions
   #:find-subscriptions-for-topic
   #:find-handlers-for-topic
   #:dispatch-topic
   #:clear-registry
   #:list-subscriptions
   #:subscription-count
   #:subscription-info
   #:get-all-subscriptions
   #:get-topics-with-subscribers))

(in-package :elmtui.core.topic-registry)

(defvar *topic-subscriptions* (make-hash-table :test 'equal))
(defvar *channel-subscriptions* (make-hash-table :test 'equal))
(defvar *next-subscription-id* 0)

(defun %ensure-function (value role)
  (declare (ignore role))
  (unless (functionp value)
    (error 'type-error :datum value :expected-type 'function))
  value)

(defun %next-id ()
  (incf *next-subscription-id*))

(defun subscribe (pattern handler &key (priority :normal))
  "Subscribe HANDLER to PATTERN and return an unsubscribe token."
  (%ensure-function handler 'handler)
  (let* ((subscription (make-topic-subscription
                        :pattern pattern
                        :handler handler
                        :priority priority))
         (token (cons (%next-id) subscription)))
    (push token (gethash pattern *topic-subscriptions* nil))
    token))

(defun subscribe-if (pattern predicate-fn handler &key (priority :normal))
  "Subscribe HANDLER to PATTERN, guarded by PREDICATE-FN."
  (%ensure-function predicate-fn 'predicate)
  (%ensure-function handler 'handler)
  (subscribe pattern
             (lambda (message)
               (when (funcall predicate-fn message)
                 (funcall handler message)))
             :priority priority))

(defun unsubscribe (token)
  (destructuring-bind (id . subscription) token
    (let* ((pattern (topic-subscription-pattern subscription))
           (subscriptions (gethash pattern *topic-subscriptions*)))
      (setf subscriptions (remove id subscriptions :key #'car :test #'eql))
      (if subscriptions
          (setf (gethash pattern *topic-subscriptions*) subscriptions)
          (remhash pattern *topic-subscriptions*))
      t)))

(defun %priority-weight (priority)
  (ecase priority
    (:high 0)
    (:normal 1)
    (:low 2)))

(defun find-subscriptions-for-topic (topic-name)
  (let ((matches nil))
    (maphash (lambda (pattern subscriptions)
               (when (topic-pattern-match-p pattern topic-name)
                 (setf matches (append matches subscriptions))))
             *topic-subscriptions*)
    (stable-sort matches #'<
                 :key (lambda (entry)
                        (%priority-weight
                         (topic-subscription-priority (cdr entry)))))))

(defun find-handlers-for-topic (topic-name)
  (mapcar (lambda (entry)
            (topic-subscription-handler (cdr entry)))
          (find-subscriptions-for-topic topic-name)))

(defun publish-to-topic (topic-name message)
  (loop for handler in (find-handlers-for-topic topic-name)
        collect (funcall handler message)))

(defun publish (topic-name message)
  (publish-to-topic topic-name message))

(defun dispatch-topic (topic message &optional app-state)
  (loop for handler in (find-handlers-for-topic topic)
        collect (if app-state
                    (funcall handler message app-state)
                    (funcall handler message))))

(defstruct channel-subscription
  (id 0 :type integer)
  topic
  channel-id
  (handler (constantly nil) :type function)
  (active t :type boolean))

(defun subscribe-to-topic-on-channel (topic channel-id handler-fn)
  (%ensure-function handler-fn 'handler)
  (let* ((subscription (make-channel-subscription
                        :id (%next-id)
                        :topic topic
                        :channel-id channel-id
                        :handler handler-fn))
         (key (cons topic channel-id)))
    (push subscription (gethash key *channel-subscriptions* nil))
    subscription))

(defun unsubscribe-from-channel (subscription)
  (let* ((key (cons (channel-subscription-topic subscription)
                    (channel-subscription-channel-id subscription)))
         (existing (gethash key *channel-subscriptions*)))
    (setf existing (remove (channel-subscription-id subscription)
                           existing
                           :key #'channel-subscription-id
                           :test #'=))
    (if existing
        (setf (gethash key *channel-subscriptions*) existing)
        (remhash key *channel-subscriptions*))
    t))

(defun publish-to-channel (topic payload channel-id)
  (let ((results nil))
    (maphash (lambda (key subscriptions)
               (destructuring-bind (sub-topic . sub-channel-id) key
                 (when (and (eql sub-channel-id channel-id)
                            (topic-pattern-match-p sub-topic topic))
                   (dolist (subscription subscriptions)
                     (when (channel-subscription-active subscription)
                       (push (funcall (channel-subscription-handler subscription) payload)
                             results))))))
             *channel-subscriptions*)
    (nreverse results)))

(defun get-channel-subscriptions (channel-id)
  (let ((result nil))
    (maphash (lambda (key subscriptions)
               (when (eql (cdr key) channel-id)
                 (push (cons (car key) subscriptions) result)))
             *channel-subscriptions*)
    result))

(defun clear-registry ()
  (clrhash *topic-subscriptions*)
  (clrhash *channel-subscriptions*)
  (setf *next-subscription-id* 0)
  t)

(defun list-subscriptions (&optional pattern)
  (if pattern
      (copy-list (gethash pattern *topic-subscriptions*))
      (let ((all nil))
        (maphash (lambda (_ subscriptions)
                   (declare (ignore _))
                   (setf all (append all (copy-list subscriptions))))
                 *topic-subscriptions*)
        all)))

(defun subscription-count ()
  (+ (loop for subscriptions being the hash-values of *topic-subscriptions*
           sum (length subscriptions))
     (loop for subscriptions being the hash-values of *channel-subscriptions*
           sum (length subscriptions))))

(defun subscription-info (&optional pattern)
  (mapcar (lambda (entry)
            (destructuring-bind (id . subscription) entry
              (list :id id
                    :pattern (topic-subscription-pattern subscription)
                    :priority (topic-subscription-priority subscription))))
          (list-subscriptions pattern)))

(defun get-all-subscriptions ()
  (let ((result nil))
    (maphash (lambda (pattern subscriptions)
               (push (cons pattern
                           (mapcar (lambda (entry)
                                     (topic-subscription-handler (cdr entry)))
                                   subscriptions))
                     result))
             *topic-subscriptions*)
    result))

(defun get-topics-with-subscribers ()
  (let ((topics nil))
    (maphash (lambda (pattern subscriptions)
               (declare (ignore subscriptions))
               (push pattern topics))
             *topic-subscriptions*)
    (maphash (lambda (key subscriptions)
               (declare (ignore subscriptions))
               (push (car key) topics))
             *channel-subscriptions*)
    (remove-duplicates (sort topics #'string< :key #'princ-to-string) :test #'equal)))
