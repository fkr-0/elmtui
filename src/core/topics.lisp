;;;===============================================================
;;; File: src/core/topics.lisp
;;; Compatibility topic hierarchy and matching layer.
;;;===============================================================
(uiop:define-package :elmtui.core.topics
  (:use :cl)
  (:export
   #:topic
   #:make-topic
   #:topic-name
   #:topic-parent
   #:topic-children
   #:topic-description
   #:register-topic
   #:find-topic
   #:find-topics-by-pattern
   #:list-topics
   #:topic-match-p
   #:topic-pattern-match-p
   #:topic-ancestors
   #:topic-descendants
   #:topic-path
   #:topic-subscription
   #:make-topic-subscription
   #:topic-subscription-pattern
   #:topic-subscription-handler
   #:topic-subscription-priority))

(in-package :elmtui.core.topics)

(defstruct (topic (:constructor %make-topic))
  (name nil :type (or symbol string) :read-only t)
  (parent nil :type (or null topic))
  (children nil :type list)
  (description nil :type (or null string)))

(defun make-topic (name &key parent description)
  (let ((topic (%make-topic :name name :parent parent :description description)))
    (when parent
      (push topic (topic-children parent)))
    topic))

(defvar *topic-registry* (make-hash-table :test 'equal))

(defun register-topic (topic)
  (setf (gethash (topic-name topic) *topic-registry*) topic)
  topic)

(defun find-topic (name)
  (gethash name *topic-registry*))

(defun list-topics ()
  (let ((topics nil))
    (maphash (lambda (_ topic)
               (declare (ignore _))
               (push topic topics))
             *topic-registry*)
    (nreverse topics)))

(defun topic-path (topic)
  (if (topic-parent topic)
      (append (topic-path (topic-parent topic)) (list (topic-name topic)))
      (let ((name (topic-name topic)))
        (if (and (stringp name) (find #\/ name))
            (uiop:split-string name :separator "/")
            (list name)))))

(defun topic-ancestors (topic)
  (when (topic-parent topic)
    (cons (topic-parent topic) (topic-ancestors (topic-parent topic)))))

(defun topic-descendants (topic)
  (let ((descendants (copy-list (topic-children topic))))
    (dolist (child (topic-children topic))
      (setf descendants (append descendants (topic-descendants child))))
    descendants))

(defun topic-match-p (topic1 topic2)
  (or (eq topic1 topic2)
      (member topic2 (topic-ancestors topic1))))

(defun %topic-segments (topic)
  (etypecase topic
    (topic (mapcar #'string (topic-path topic)))
    (symbol (uiop:split-string (string topic) :separator "/"))
    (string (uiop:split-string topic :separator "/"))))

(defun topic-pattern-match-p (pattern topic)
  (let ((pattern-segments (%topic-segments pattern))
        (topic-segments (%topic-segments topic)))
    (labels ((matchp (ps ts)
               (cond
                 ((and (null ps) (null ts)) t)
                 ((null ps) nil)
                 ((string= (first ps) "#") t)
                 ((null ts) nil)
                 ((string= (first ps) "*")
                  (matchp (rest ps) (rest ts)))
                 ((string-equal (first ps) (first ts))
                  (matchp (rest ps) (rest ts)))
                 (t nil))))
      (matchp pattern-segments topic-segments))))

(defun find-topics-by-pattern (pattern)
  (remove-if-not (lambda (topic)
                   (topic-pattern-match-p pattern topic))
                 (list-topics)))

(defstruct (topic-subscription (:constructor make-topic-subscription))
  (pattern nil :type (or string symbol) :read-only t)
  (handler nil :type function :read-only t)
  (priority :normal :type (member :high :normal :low)))

(defvar *system-topic* (register-topic (make-topic "system" :description "System events")))
(defvar *ui-topic* (register-topic (make-topic "ui" :description "UI events")))
(defvar *keyboard-topic* (register-topic (make-topic "input/keyboard" :description "Keyboard events")))
(defvar *mouse-topic* (register-topic (make-topic "input/mouse" :description "Mouse events")))
(defvar *focus-topic* (register-topic (make-topic "ui/focus" :description "Focus events")))
