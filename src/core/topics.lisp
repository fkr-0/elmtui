;;;===============================================================
;;; File: src/core/topics.lisp
;;; Topic Hierarchy and Matching for Event System
;;;===============================================================
(uiop:define-package :elmtui.core.topics
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:export 
   ;; Topic creation and management
   #:topic
   #:make-topic
   #:topic-name
   #:topic-parent
   #:topic-children
   #:topic-description
   
   ;; Topic registry
   #:register-topic
   #:find-topic
   #:find-topics-by-pattern
   #:list-topics
   
   ;; Topic matching
   #:topic-match-p
   #:topic-pattern-match-p
   #:topic-ancestors
   #:topic-descendants
   #:topic-path
   
   ;; Topic subscription
   #:topic-subscription
   #:make-topic-subscription
   #:topic-subscription-pattern
   #:topic-subscription-handler))

(in-package :elmtui.core.topics)

;;;-----------------------------------------------------------------------------
;;; Topic Structure
;;;-----------------------------------------------------------------------------

(defstruct (topic (:constructor %make-topic))
  "Represents a hierarchical topic for event routing."
  (name nil :type (or symbol string) :read-only t)
  (parent nil :type (or null topic))
  (children nil :type list)
  (description nil :type (or null string)))

(defun make-topic (name &key parent description)
  "Create a new topic with the given name and optional parent and description."
  (let ((topic (%make-topic :name name
                            :parent parent
                            :description description)))
    (when parent
      (push topic (topic-children parent)))
    topic))

;;;-----------------------------------------------------------------------------
;;; Topic Registry
;;;-----------------------------------------------------------------------------

(defvar *topic-registry* (make-hash-table :test 'equal)
  "Global registry of topics for lookup by name.")

(defun register-topic (topic)
  "Register a topic in the global registry."
  (setf (gethash (topic-name topic) *topic-registry*) topic)
  topic)

(defun find-topic (name)
  "Find a topic by name in the registry."
  (gethash name *topic-registry*))

(defun list-topics ()
  "Return a list of all registered topics."
  (let ((topics nil))
    (maphash (lambda (k v) 
               (declare (ignore k))
               (push v topics))
             *topic-registry*)
    (nreverse topics)))

;;;-----------------------------------------------------------------------------
;;; Topic Path and Hierarchy
;;;-----------------------------------------------------------------------------

(defun topic-path (topic)
  "Return the full path of a topic as a list of names from root to this topic."
  (if (topic-parent topic)
      (append (topic-path (topic-parent topic)) (list (topic-name topic)))
      (list (topic-name topic))))

(defun topic-ancestors (topic)
  "Return a list of all ancestor topics (parent, grandparent, etc.)."
  (when (topic-parent topic)
    (cons (topic-parent topic) (topic-ancestors (topic-parent topic)))))

(defun topic-descendants (topic)
  "Return a list of all descendant topics (recursive children)."
  (let ((descendants (copy-list (topic-children topic))))
    (dolist (child (topic-children topic))
      (setf descendants (append descendants (topic-descendants child))))
    descendants))

;;;-----------------------------------------------------------------------------
;;; Topic Matching
;;;-----------------------------------------------------------------------------

(defun topic-match-p (topic1 topic2)
  "Check if topic1 matches topic2 (exact match or ancestor)."
  (or (eq topic1 topic2)
      (member topic2 (topic-ancestors topic1))))

(defun topic-pattern-match-p (pattern topic)
  "Check if a topic matches a pattern. Patterns can include:
   - Exact name match
   - Wildcards (*)
   - Multi-level wildcards (#)
   - Parent-child notation (parent/child)"
  (labels ((split-pattern (pat)
             "Split pattern into segments based on '/'"
             (str:split (string pat) #\/)
             ;; (split-sequence:split-sequence #\/ (string pat))
             )
           
           (split-topic (top)
             "Get the topic path as a list of name segments"
             (mapcar #'string (topic-path top)))
           
           (segments-match-p (pattern-segments topic-segments)
             "Check if pattern segments match topic segments"
             (cond
               ;; Both empty - we matched everything
               ((and (null pattern-segments) (null topic-segments))
                t)
               
               ;; Pattern ended but topic continues - no match
               ((null pattern-segments)
                nil)
               
               ;; Topic ended but pattern continues - no match unless wildcard
               ((null topic-segments)
                nil)
               
               ;; Multi-level wildcard - matches rest of topic
               ((string= (first pattern-segments) "#")
                t)
               
               ;; Single-level wildcard - match this level and continue
               ((string= (first pattern-segments) "*")
                (segments-match-p (rest pattern-segments) (rest topic-segments)))
               
               ;; Exact match - continue matching
               ((string-equal (first pattern-segments) (first topic-segments))
                (segments-match-p (rest pattern-segments) (rest topic-segments)))
               
               ;; No match
               (t nil))))
    
    (segments-match-p (split-pattern pattern) (split-topic topic))))

(defun find-topics-by-pattern (pattern)
  "Find all topics that match the given pattern."
  (remove-if-not (lambda (topic)
                   (topic-pattern-match-p pattern topic))
                 (list-topics)))

;;;-----------------------------------------------------------------------------
;;; Topic Subscriptions
;;;-----------------------------------------------------------------------------

(defstruct (topic-subscription (:constructor make-topic-subscription))
  "Represents a subscription to a topic pattern."
  (pattern nil :type (or string symbol) :read-only t)
  (handler nil :type function :read-only t)
  (priority :normal :type (member :high :normal :low)))

;; Initialize some standard system topics
(defvar *system-topic* (register-topic (make-topic "system" :description "System events")))
(defvar *ui-topic* (register-topic (make-topic "ui" :description "UI events")))
(defvar *keyboard-topic* (register-topic (make-topic "input/keyboard" :description "Keyboard events")))
(defvar *mouse-topic* (register-topic (make-topic "input/mouse" :description "Mouse events")))
(defvar *focus-topic* (register-topic (make-topic "ui/focus" :description "Focus events")))
