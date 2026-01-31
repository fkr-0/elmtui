;;;===============================================================
;;; File: src/core/topic-subscription.lisp
;;; Pattern Matching for Topic Subscriptions
;;;===============================================================
(uiop:define-package :elmtui.core.topic-subscription
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :elmtui.core.topics
                #:topic
                #:topic-name
                #:topic-pattern-match-p
                #:topic-subscription
                #:topic-subscription-pattern
                #:topic-subscription-handler)
  (:import-from :elmtui.core.topic-registry
                #:subscribe
                #:unsubscribe
                #:publish)
  (:import-from :elmtui.core.message-bus
                #:message-bus
                #:register-channel
                #:add-routing-rule)
  (:import-from :cl-events.channel
                #:make-channel #:->)
  (:import-from :cl-events.types
                #:message
                #:message-type
                #:message-data)
  (:export 
   ;; Topic subscription creation
   #:create-topic-subscription
   #:remove-topic-subscription
   
   ;; Topic pattern utilities
   #:compile-topic-pattern
   #:topic-pattern-contains-wildcards-p
   #:tokenize-topic-pattern
   
   ;; Channel integration
   #:create-topic-channel
   #:integrate-with-message-bus))

(in-package :elmtui.core.topic-subscription)

;;;-----------------------------------------------------------------------------
;;; Topic Pattern Compilation
;;;-----------------------------------------------------------------------------

(defun tokenize-topic-pattern (pattern)
  "Split a topic pattern into individual tokens based on '/' separator."
  (split-sequence:split-sequence #\/ (string pattern)))

(defun topic-pattern-contains-wildcards-p (pattern)
  "Check if a topic pattern contains wildcard characters (* or #)."
  (let ((tokens (tokenize-topic-pattern pattern)))
    (some (lambda (token)
            (or (string= token "*")
                (string= token "#")))
          tokens)))

(defun compile-topic-pattern (pattern)
  "Compile a topic pattern into a more efficient matcher function."
  (let ((tokens (tokenize-topic-pattern pattern)))
    (lambda (topic-name)
      (let ((topic-tokens (tokenize-topic-pattern topic-name)))
        (labels ((match-tokens (pat-tokens top-tokens)
                   (cond
                     ;; Both empty - success
                     ((and (null pat-tokens) (null top-tokens))
                      t)
                     
                     ;; Pattern empty but topic not - failure
                     ((null pat-tokens)
                      nil)
                     
                     ;; Topic empty but pattern not - only succeed with #
                     ((null top-tokens)
                      (and (= 1 (length pat-tokens))
                           (string= (first pat-tokens) "#")))
                     
                     ;; Multi-level wildcard - matches everything
                     ((string= (first pat-tokens) "#")
                      t)
                     
                     ;; Single-level wildcard - match one level
                     ((string= (first pat-tokens) "*")
                      (match-tokens (rest pat-tokens) (rest top-tokens)))
                     
                     ;; Exact match - compare and continue
                     ((string-equal (first pat-tokens) (first top-tokens))
                      (match-tokens (rest pat-tokens) (rest top-tokens)))
                     
                     ;; No match
                     (t nil))))
          (match-tokens tokens topic-tokens))))))

;;;-----------------------------------------------------------------------------
;;; Topic Subscription Management with Pattern Matching
;;;-----------------------------------------------------------------------------

(defun create-topic-subscription (pattern handler &key (priority :normal))
  "Create a subscription to a topic pattern with optimized matching.
   Returns a subscription token for unsubscription."
  (let ((matcher (compile-topic-pattern pattern)))
    (subscribe pattern 
               (lambda (message)
                 (when (funcall matcher (topic-of-message message))
                   (funcall handler message)))
               :priority priority)))

(defun topic-of-message (message)
  "Extract the topic from a message."
  (typecase message
    (message (or (getf (message-data message) :topic)
                 (string (message-type message))))
    (keyword (string message))
    (symbol (string message))
    (cons (or (getf message :topic)
              (getf message :message-type)
              (getf message :type)
              (string (first message))))
    (t "unknown")))

(defun remove-topic-subscription (token)
  "Remove a topic subscription using its token."
  (unsubscribe token))

;;;-----------------------------------------------------------------------------
;;; Integration with Channel System
;;;-----------------------------------------------------------------------------

(defun create-topic-channel (pattern &key (buffer-size 10))
  "Create a channel that forwards messages matching a topic pattern."
  (let* ((channel (make-channel :capacity buffer-size))
         (subscription (create-topic-subscription 
                        pattern
                        (lambda (message)
                          (-> channel message)))))
    ;; Return both the channel and subscription token for management
    (values channel subscription)))

(defun integrate-with-message-bus (bus &key (standard-topics t))
  "Integrate topic subscriptions with a message bus."
  ;; Set up channels for standard topics if requested
  (when standard-topics
    (multiple-value-bind (system-channel system-sub)
        (create-topic-channel "system/#")
      (register-channel bus :system system-channel))
    
    (multiple-value-bind (keyboard-channel keyboard-sub)
        (create-topic-channel "input/keyboard/#")
      (register-channel bus :keyboard keyboard-channel))
    
    (multiple-value-bind (mouse-channel mouse-sub)
        (create-topic-channel "input/mouse/#")
      (register-channel bus :mouse mouse-channel))
    
    (multiple-value-bind (ui-channel ui-sub)
        (create-topic-channel "ui/#")
      (register-channel bus :ui ui-channel))
    
    (multiple-value-bind (focus-channel focus-sub)
        (create-topic-channel "ui/focus/#")
      (register-channel bus :focus focus-channel)))
  
  ;; Set up routing rules for messages to be sent to appropriate topics
  (add-routing-rule bus :any :topic-router
                    :condition (lambda (message)
                                 (getf (message-data message) :topic))
                    :transform (lambda (message)
                                 (let ((topic (getf (message-data message) :topic)))
                                   (publish topic message)
                                   message)))
  bus)
