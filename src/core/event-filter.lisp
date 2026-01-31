;; src/core/event-filter.lisp
;; Implementation of event filter predicates and transformers

(uiop:define-package :cleve-elm.core.event-filter
  (:nicknames :elmtui.core.event-filter)
  (:use :cl :log4cl)
  (:import-from :cl-events.types
                :message :message-type :message-data)
  (:export :filter-by-type
           :filter-by-priority
           :filter-by-source
           :filter-by-predicate
           :combine-filters
           :transform-message
           :filter-chain
           :filter-threshold
           :make-filter))

(in-package :cleve-elm.core.event-filter)

(defun message-type-of (message)
  "Extract a message type keyword from MESSAGE."
  (typecase message
    (message (message-type message))
    (keyword message)
    (symbol (intern (string-upcase (symbol-name message)) :keyword))
    (cons (or (getf message :type)
              (getf message :message-type)
              (first message)))
    (t (type-of message))))

(defun message-priority-of (message)
  "Extract a priority keyword from MESSAGE."
  (typecase message
    (message (getf (message-data message) :priority :normal))
    (cons (or (getf message :priority) :normal))
    (t :normal)))

(defun message-source-of (message)
  "Extract a source identifier from MESSAGE."
  (typecase message
    (message (getf (message-data message) :source))
    (cons (getf message :source))
    (t nil)))

;; Basic filter predicates
(defun filter-by-type (type-or-types)
  "Create a filter function that matches messages of a specific type or types"
  (if (listp type-or-types)
      ;; Multiple types
      (lambda (message)
        (member (message-type-of message) type-or-types :test #'eq))
      ;; Single type
      (lambda (message)
        (eq (message-type-of message) type-or-types))))

(defun filter-by-priority (min-priority)
  "Create a filter function that matches messages with at least the specified priority"
  (lambda (message)
    (let ((msg-priority (message-priority-of message))
          (priority-values '(:low 0 :normal 1 :high 2 :urgent 3)))
      (>= (getf priority-values msg-priority 0)
          (getf priority-values min-priority 0)))))

(defun filter-by-source (source)
  "Create a filter function that matches messages from a specific source"
  (lambda (message)
    (equal (message-source-of message) source)))

(defun filter-by-predicate (predicate)
  "Create a filter function that applies a custom predicate to the message"
  predicate)

;; Combinators for filters
(defun combine-filters (filters &key (mode :and))
  "Combine multiple filters with AND or OR semantics"
  (case mode
    (:and (lambda (message)
            (every (lambda (filter) (funcall filter message)) filters)))
    (:or (lambda (message)
           (some (lambda (filter) (funcall filter message)) filters)))
    (otherwise (error "Unknown filter combination mode: ~A" mode))))

;; Message transformers
(defun transform-message (transformer-fn)
  "Create a transformer function to modify messages"
  transformer-fn)

;; Advanced filter patterns
(defun filter-chain (&rest filter-functions)
  "Create a chain of filters where each filter is applied in sequence"
  (lambda (message)
    (loop for filter in filter-functions
          for result = (funcall filter message)
          when result return result
          finally (return nil))))

(defun filter-threshold (count-max type-or-types)
  "Create a filter that passes only a limited number of messages of a specific type"
  (let ((counter 0)
        (type-filter (filter-by-type type-or-types)))
    (lambda (message)
      (when (funcall type-filter message)
        (if (< counter count-max)
            (progn
              (incf counter)
              t)
            nil)))))

(defun make-filter (&key type priority source predicate)
  "Create a filter from a combination of common filtering criteria"
  (let ((filters nil))
    (when type
      (push (filter-by-type type) filters))
    (when priority
      (push (filter-by-priority priority) filters))
    (when source
      (push (filter-by-source source) filters))
    (when predicate
      (push (filter-by-predicate predicate) filters))
    
    (if filters
        (combine-filters filters :mode :and)
        (lambda (message) t))))  ;; Default filter passes everything
