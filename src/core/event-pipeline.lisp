;;;===============================================================
;;; File: src/core/event-pipeline.lisp
;;; Small compatibility event pipeline used by regression tests.
;;;===============================================================
(uiop:define-package :elmtui.core.event-pipeline
  (:use :cl)
  (:export
   #:pipeline
   #:make-pipeline
   #:pipeline-pipes
   #:pipeline-fallthrough
   #:pipe
   #:filter-pipe
   #:transform-pipe
   #:conditional-pipe
   #:process-event))

(in-package :elmtui.core.event-pipeline)

(defclass pipeline ()
  ((pipes :initarg :pipes :accessor pipeline-pipes :initform nil)
   (fallthrough :initarg :fallthrough :accessor pipeline-fallthrough :initform t)))

(defun make-pipeline (&key pipes (fallthrough t))
  (make-instance 'pipeline :pipes pipes :fallthrough fallthrough))

(defclass pipe () ())

(defgeneric process-pipe (pipe event pipeline))

(defclass filter-pipe (pipe)
  ((filter :initarg :filter :reader filter-pipe-filter)))

(defclass transform-pipe (pipe)
  ((transform :initarg :transform :reader transform-pipe-transform)))

(defclass conditional-pipe (pipe)
  ((condition :initarg :condition :reader conditional-pipe-condition)
   (then :initarg :then :reader conditional-pipe-then)
   (else :initarg :else :reader conditional-pipe-else)))

(defmethod process-pipe ((pipe filter-pipe) event pipeline)
  (declare (ignore pipeline))
  (and (funcall (filter-pipe-filter pipe) event) event))

(defmethod process-pipe ((pipe transform-pipe) event pipeline)
  (declare (ignore pipeline))
  (funcall (transform-pipe-transform pipe) event))

(defmethod process-pipe ((pipe conditional-pipe) event pipeline)
  (process-pipe (if (funcall (conditional-pipe-condition pipe) event)
                    (conditional-pipe-then pipe)
                    (conditional-pipe-else pipe))
                event
                pipeline))

(defun process-event (pipeline event)
  (loop with current = event
        for pipe in (pipeline-pipes pipeline)
        do (let ((next (process-pipe pipe current pipeline)))
             (cond
               (next (setf current next))
               ((pipeline-fallthrough pipeline) (setf current nil))
               (t (return-from process-event nil))))
        finally (return current)))
