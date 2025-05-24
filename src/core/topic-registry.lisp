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
                #:topic-subscription-priority
                #:topic-subscription-handler)
  (:export 
   ;; Subscription management
   #:subscribe
   #:unsubscribe
   #:publish
   
   ;; Subscription filtering
   #:find-subscriptions-for-topic
   #:find-handlers-for-topic
   
   ;; Registry management
   #:clear-registry
   #:list-subscriptions
   #:subscription-count
   #:subscription-info))

(in-package :elmtui.core.topic-registry)

;;;-----------------------------------------------------------------------------
;;; Topic Subscription Registry
;;;-----------------------------------------------------------------------------

(defvar *topic-subscriptions* (make-hash-table :test 'equal)
  "Registry of subscriptions indexed by pattern")

(defvar *next-subscription-id* 0
  "Counter for generating unique subscription IDs")

(defun generate-subscription-id ()
  "Generate a unique subscription ID"
  (incf *next-subscription-id*))

(defun subscribe (pattern handler &key (priority :normal))
  "Subscribe to a topic pattern with the given handler.
   Returns a subscription token that can be used for unsubscribing."
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

(defun publish (topic-name message)
  "Publish a message to a topic, invoking all matching subscription handlers."
  (log-debug "Publishing to topic: ~A" topic-name)
  (let ((handlers (find-handlers-for-topic topic-name))
        (results nil))
    
    (log-debug "Found ~A matching handlers" (length handlers))
    
    ;; Call each handler with the message
    (dolist (handler handlers)
      (handler-case
          (push (funcall handler message) results)
        (error (e)
          (log-warn "Error in topic handler for ~A: ~A" topic-name e))))
    
    ;; Return results in order of handler execution (reverse of how we collected them)
    (nreverse results)))

;;;-----------------------------------------------------------------------------
;;; Registry Utilities
;;;-----------------------------------------------------------------------------

(defun clear-registry ()
  "Clear all topic subscriptions."
  (clrhash *topic-subscriptions*)
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
