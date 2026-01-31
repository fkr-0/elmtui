;; src/core/event-pipeline.lisp
;; Pipeline for event preprocessing and transformation

(uiop:define-package :cleve-elm.core.event-pipeline
  (:nicknames :elmtui.core.event-pipeline)
  (:use :cl :log4cl)
  (:import-from :cl-events.channel
                #:->)
  (:export :pipeline
           :make-pipeline
           :add-pipe
           :remove-pipe
           :process-event
           :filter-pipe
           :transform-pipe
           :log-pipe
           :broadcast-pipe
           :conditional-pipe))

(in-package :cleve-elm.core.event-pipeline)

;; Base pipe class
(defclass pipe ()
  ((name :accessor name :initarg :name :initform nil :documentation "Name of the pipe")
   (enabled :accessor enabled-p :initarg :enabled :initform t :documentation "Whether the pipe is enabled"))
  (:documentation "Base class for event pipeline processors"))

(defclass filter-pipe (pipe)
  ((filter-fn :accessor filter-fn :initarg :filter :documentation "Filter function to apply"))
  (:documentation "A pipe that filters events based on a predicate"))

(defclass transform-pipe (pipe)
  ((transform-fn :accessor transform-fn :initarg :transform :documentation "Transform function to apply"))
  (:documentation "A pipe that transforms events"))

(defclass log-pipe (pipe)
  ((log-level :accessor log-level :initarg :log-level :initform :debug :documentation "Log level to use"))
  (:documentation "A pipe that logs events as they pass through"))

(defclass broadcast-pipe (pipe)
  ((targets :accessor targets :initarg :targets :initform nil :documentation "Target channels to broadcast to"))
  (:documentation "A pipe that broadcasts events to multiple targets"))

(defclass conditional-pipe (pipe)
  ((condition-fn :accessor condition-fn :initarg :condition :documentation "Condition to check")
   (then-pipe :accessor then-pipe :initarg :then :documentation "Pipe to use if condition is true")
   (else-pipe :accessor else-pipe :initarg :else :initform nil :documentation "Optional pipe to use if condition is false"))
  (:documentation "A pipe that conditionally routes events based on a predicate"))

;; Pipeline container
(defclass pipeline ()
  ((pipes :accessor pipes :initform nil :initarg :pipes :documentation "List of pipes in processing order")
   (fallthrough :accessor fallthrough-p :initform t :initarg :fallthrough :documentation "Whether events should fall through all pipes"))
  (:documentation "Container for processing pipes that events flow through"))

;; Pipe processing methods
(defgeneric process-pipe (pipe event)
  (:documentation "Process an event through a pipe"))

(defmethod process-pipe ((pipe filter-pipe) event)
  "Process an event through a filter pipe"
  (when (and (enabled-p pipe) (funcall (filter-fn pipe) event))
    event))

(defmethod process-pipe ((pipe transform-pipe) event)
  "Process an event through a transform pipe"
  (when (enabled-p pipe)
    (funcall (transform-fn pipe) event)))

(defmethod process-pipe ((pipe log-pipe) event)
  "Process an event through a log pipe"
  (when (enabled-p pipe)
    (ecase (log-level pipe)
      (:debug (log-debug "Event: ~A" event))
      (:info (log-info "Event: ~A" event))
      (:warn (log-warn "Event: ~A" event))
      (:error (log-error "Event: ~A" event)))
    event))

(defmethod process-pipe ((pipe broadcast-pipe) event)
  "Process an event through a broadcast pipe"
  (when (enabled-p pipe)
    (dolist (target (targets pipe))
      (handler-case
          (-> target event)
        (error (e)
          (log-warn "Failed to broadcast event to target: ~A - ~A" target e))))
    event))

(defmethod process-pipe ((pipe conditional-pipe) event)
  "Process an event through a conditional pipe"
  (when (enabled-p pipe)
    (if (funcall (condition-fn pipe) event)
        (process-pipe (then-pipe pipe) event)
        (when (else-pipe pipe)
          (process-pipe (else-pipe pipe) event)))))

;; Pipeline functions
(defun make-pipeline (&key (fallthrough t) pipes)
  "Create a new event pipeline"
  (make-instance 'pipeline
                 :fallthrough fallthrough
                 :pipes pipes))

(defun add-pipe (pipeline pipe &optional position)
  "Add a pipe to the pipeline"
  (if position
      (setf (pipes pipeline)
            (append (subseq (pipes pipeline) 0 position)
                    (list pipe)
                    (subseq (pipes pipeline) position)))
      (setf (pipes pipeline)
            (append (pipes pipeline) (list pipe))))
  pipeline)

(defun remove-pipe (pipeline pipe-or-name)
  "Remove a pipe from the pipeline"
  (setf (pipes pipeline)
        (remove pipe-or-name (pipes pipeline)
                :test (lambda (item pipe)
                        (cond
                          ((typep item 'pipe) (eq item pipe))
                          ((symbolp item) (eq item (name pipe)))
                          (t nil)))))
  pipeline)

(defun process-event (pipeline event)
  "Process an event through the pipeline"
  (let ((result event))
    (dolist (pipe (pipes pipeline))
      (let ((pipe-result (process-event pipe event)))
        (setf result pipe-result)
        (when (and (not (fallthrough-p pipeline)) (null pipe-result))
          ;; If not fallthrough and a pipe returned nil, stop processing
          (return-from process-event nil))))
    result))
