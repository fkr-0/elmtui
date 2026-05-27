;;;===============================================================
;;; File: src/core/topic-registry.lisp
;;; Central Registry for Topic Subscription Management
;;;===============================================================
(uiop:define-package :elmtui.core.topic-registry
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :elmtui.core.topics
                #:topic
                #:topic-name
                #:topic-match-p
                #:topic-pattern-match-p
                #:find-topic
                #:topic-subscription
                #:make-topic-subscription
                #:topic-subscription-pattern
                #:topic-subscription-handler
                #:topic-subscription-priority)
  (:export
   ;; Subscription management
   #:subscribe
   #:subscribe-if
   #:unsubscribe
   #:publish-to-topic
   #:publish-to-channel

   ;; Channel-based topic subscription
   #:subscribe-to-topic-on-channel
   #:unsubscribe-from-channel
   #:get-channel-subscriptions

   ;; Subscription filtering
   #:find-subscriptions-for-topic
   #:find-handlers-for-topic
   #:dispatch-topic

   ;; Registry management
   #:clear-registry
   #:list-subscriptions
   #:subscription-count
   #:subscription-info
   #:get-all-subscriptions
   #:get-topics-with-subscribers))

(in-package :elmtui.core.topic-registry)

;;;-----------------------------------------------------------------------------
;;; Topic Subscription Registry
;;;-----------------------------------------------------------------------------
(defgeneric publish-to-topic (topic-name message)
  (:documentation "Generic function to publish a message to a named topic.
Specific implementations will handle the dispatch logic, potentially using elmtui.core.topics."))
(defvar *topic-subscriptions* (make-hash-table :test 'equal)
  "Registry of subscriptions indexed by pattern")

(defvar *channel-subscriptions* (make-hash-table :test 'equal)
  "Registry of channel-based subscriptions indexed by (topic . channel-id)")

(defvar *next-subscription-id* 0
  "Counter for generating unique subscription IDs")

(defun generate-subscription-id ()
  "Generate a unique subscription ID"
  (incf *next-subscription-id*))

(defun subscribe (pattern handler &key (priority :normal))
  "Subscribe to a topic pattern with the given handler.
   Returns a subscription token that can be used for unsubscribing."
  (check-type handler function)
  (log-debug "Subscribing to pattern: ~A with priority: ~A" pattern priority)
  (let* ((subscription (make-topic-subscription
                        :pattern pattern
                        :handler handler
                        :priority priority))
         (id (generate-subscription-id))
         (token (cons id subscription)))

    ;; Store the subscription
    (push token (gethash pattern *topic-subscriptions* nil))

    (log-debug "Created subscription with ID: ~A" id)
    ;; Return the token for later unsubscription
    token))

(defun subscribe-if (pattern predicate-fn handler &key (priority :normal))
  "Subscribe to a topic pattern with handler, but only invoke handler
   if the predicate function returns true when passed the message.
   Returns a subscription token that can be used for unsubscribing."
  (check-type predicate-fn function)
  (check-type handler function)
  (log-debug "Subscribing conditionally to pattern: ~A" pattern)

  (let ((filtered-handler
          (lambda (message)
            (when (funcall predicate-fn message)
              (funcall handler message)))))

    (subscribe pattern filtered-handler :priority priority)))

(defun unsubscribe (token)
  "Unsubscribe using a subscription token."
  (destructuring-bind (id . subscription) token
    (let* ((pattern (topic-subscription-pattern subscription))
           (current-subs (gethash pattern *topic-subscriptions*))
           (updated-subs (remove id current-subs :key #'car)))

      (log-debug "Unsubscribing ID: ~A from pattern: ~A" id pattern)

      (if updated-subs
          (setf (gethash pattern *topic-subscriptions*) updated-subs)
          (remhash pattern *topic-subscriptions*))
      t)))

(defun find-subscriptions-for-topic (topic-name)
  "Find all subscriptions that match the given topic name."
  (let ((result nil))
    ;; Check each registered pattern against this topic
    (maphash (lambda (pattern subscriptions)
               (when (topic-pattern-match-p pattern topic-name)
                 (setf result (append result subscriptions))))
             *topic-subscriptions*)

    ;; Sort by priority
    (sort result #'subscription-priority-compare)
    result))

(defun subscription-priority-compare (sub1 sub2)
  "Compare subscriptions by priority for sorting."
  (let ((prio1 (topic-subscription-priority (cdr sub1)))
        (prio2 (topic-subscription-priority (cdr sub2))))
    (cond
      ((eq prio1 :high) t)
      ((eq prio2 :high) nil)
      ((eq prio1 :normal) t)
      (t nil))))

(defun find-handlers-for-topic (topic-name)
  "Find all handlers for subscriptions matching the given topic name."
  (mapcar (lambda (sub) (topic-subscription-handler (cdr sub)))
          (find-subscriptions-for-topic topic-name)))

(defmethod publish-to-topic (topic-name message)
  "Publish a message to a topic, invoking all matching subscription handlers."
  (log-debug "Publishing to topic: ~A" topic-name)
  (let ((handlers (find-handlers-for-topic topic-name))
        (results nil))

    (log-debug "Found ~A matching handlers for topic ~A" (length handlers) topic-name)

    ;; Call each handler with the message
    (dolist (handler handlers)
      (handler-case
          (push (funcall handler message) results)
        (error (e)
          (log-warn "Error in topic handler for ~A: ~A" topic-name e))))

    ;; Return results in order of handler execution (reverse of how we collected them)
    (nreverse results)))

(defun dispatch-topic (topic message &optional app-state)
  "Dispatch a message to a topic with optional application state context.
   This is typically called by the main event loop consumer."
  (log-debug "Dispatching to topic: ~A" topic)
  (let ((handlers (find-handlers-for-topic topic))
        (results nil))

    ;; Call each handler with the message and optional app-state
    (dolist (handler handlers)
      (handler-case
          (if app-state
              (push (funcall handler message app-state) results)
              (push (funcall handler message) results))
        (error (e)
          (log-warn "Error in topic dispatch for ~A: ~A" topic e))))

    (nreverse results)))

;;;-----------------------------------------------------------------------------
;;; Channel-Based Topic Messaging
;;;-----------------------------------------------------------------------------

(defstruct channel-subscription
  "Structure representing a subscription to a topic on a specific channel"
  (id 0 :type integer)
  (topic nil)
  (channel-id nil)
  (handler nil :type function)
  (active t :type boolean))

(defun subscribe-to-topic-on-channel (topic channel-id handler-fn)
  "Subscribe to a topic on a specific channel.
   Messages published to this topic on this channel will invoke the handler.
   Returns a subscription object that can be used for unsubscribing."
  (log-debug "Subscribing to topic ~A on channel ~A" topic channel-id)

  (let* ((id (generate-subscription-id))
         (subscription (make-channel-subscription
                        :id id
                        :topic topic
                        :channel-id channel-id
                        :handler handler-fn))
         ;; Store by composite key (topic . channel-id)
         (key (cons topic channel-id))
         (existing (gethash key *channel-subscriptions*)))
    (push subscription existing)
    (setf (gethash key *channel-subscriptions*) existing)

    ;; Return the subscription object
    subscription))

(defun unsubscribe-from-channel (subscription)
  "Unsubscribe from a topic on a channel using a subscription object."
  (let* ((topic (channel-subscription-topic subscription))
         (channel-id (channel-subscription-channel-id subscription))
         (key (cons topic channel-id))
         (existing (gethash key *channel-subscriptions*))
         (subscription-id (channel-subscription-id subscription)))

    (setf (gethash key *channel-subscriptions*)
          (remove subscription-id existing
                  :key #'channel-subscription-id
                  :test #'=))

    (when (null (gethash key *channel-subscriptions*))
      (remhash key *channel-subscriptions*))

    t))

(defun publish-to-channel (topic payload channel-id)
  "Publish a message to a topic on a specific channel.
   Only subscribers to this topic on this channel will receive it."
  (log-debug "Publishing to topic ~A on channel ~A" topic channel-id)

  (let* ((key (cons topic channel-id))
         (subscriptions (gethash key *channel-subscriptions*))
         (results nil))

    ;; Process exact matches first
    (dolist (subscription subscriptions)
      (when (channel-subscription-active subscription)
        (handler-case
            (push (funcall (channel-subscription-handler subscription)
                           payload)
                  results)
          (error (e)
            (log-warn "Error in channel topic handler for ~A: ~A" topic e)))))

    ;; Also check for wildcard subscriptions
    (maphash (lambda (k subs)
               (destructuring-bind (sub-topic . sub-channel) k
                 (when (and (eq sub-channel channel-id)
                            (topic-pattern-match-p sub-topic topic)
                            (not (equal sub-topic topic)))
                   (dolist (subscription subs)
                     (when (channel-subscription-active subscription)
                       (handler-case
                           (push (funcall (channel-subscription-handler subscription)
                                          payload)
                                 results)
                         (error (e)
                           (log-warn "Error in wildcard channel topic handler for ~A (~A): ~A"
                                     sub-topic topic e))))))))
             *channel-subscriptions*)

    (nreverse results)))

(defun get-channel-subscriptions (channel-id)
  "Get all subscriptions for a specific channel."
  (let ((result nil))
    (maphash (lambda (k subs)
               (destructuring-bind (topic . sub-channel) k
                 (when (eq sub-channel channel-id)
                   (push (cons topic subs) result))))
             *channel-subscriptions*)
    result))

;;;-----------------------------------------------------------------------------
;;; Registry Utilities
;;;-----------------------------------------------------------------------------

(defun clear-registry ()
  "Clear all topic subscriptions."
  (clrhash *topic-subscriptions*)
  (clrhash *channel-subscriptions*)
  (setf *next-subscription-id* 0))

(defun list-subscriptions (&optional pattern)
  "List all subscriptions, optionally filtered by pattern."
  (if pattern
      (gethash pattern *topic-subscriptions*)
      (let ((all-subs nil))
        (maphash (lambda (pattern subscriptions)
                   (declare (ignore pattern))
                   (setf all-subs (append all-subs subscriptions)))
                 *topic-subscriptions*)
        all-subs)))

(defun subscription-count ()
  "Return the total number of subscriptions."
  (let ((count 0))
    (maphash (lambda (pattern subscriptions)
               (declare (ignore pattern))
               (incf count (length subscriptions)))
             *topic-subscriptions*)
    (maphash (lambda (key subscriptions)
               (declare (ignore key))
               (incf count (length subscriptions)))
             *channel-subscriptions*)
    count))

(defun subscription-info (&optional pattern)
  "Return information about subscriptions, optionally filtered by pattern."
  (let ((subs (if pattern
                  (gethash pattern *topic-subscriptions*)
                  (list-subscriptions))))
    (mapcar (lambda (sub)
              (destructuring-bind (id . subscription) sub
                (list :id id
                      :pattern (topic-subscription-pattern subscription)
                      :priority (topic-subscription-priority subscription))))
            subs)))

(defun get-all-subscriptions ()
  "Get information about all subscriptions in the system."
  (let ((result nil))
    ;; Regular topic subscriptions
    (maphash (lambda (pattern subs)
               (push (cons pattern
                           (mapcar (lambda (sub)
                                     (topic-subscription-handler (cdr sub)))
                                   subs))
                     result))
             *topic-subscriptions*)

    ;; Channel-based subscriptions
    (maphash (lambda (key subs)
               (destructuring-bind (topic . channel-id) key
                 (push (cons (format nil "~A (channel: ~A)" topic channel-id)
                             (mapcar #'channel-subscription-handler subs))
                       result)))
             *channel-subscriptions*)

    (sort result #'string< :key (lambda (pair)
                                  (if (stringp (car pair))
                                      (car pair)
                                      (format nil "~A" (car pair)))))))

(defun get-topics-with-subscribers ()
  "Get a list of all topics that have subscribers."
  (let ((topics nil))
    (maphash (lambda (pattern subs)
               (declare (ignore subs))
               (push pattern topics))
             *topic-subscriptions*)
    (maphash (lambda (key subs)
               (declare (ignore subs))
               (push (car key) topics))
             *channel-subscriptions*)
    (remove-duplicates (sort topics #'string<) :test #'equal)))

