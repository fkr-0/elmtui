(uiop:define-package :cleve-elm.event-loop
  (:use #:log4cl #:cl #:cleve-elm.queue  :cleve-elm.thread)
  (:export #:enqueue-event
    #:make-event-loop
    #:stop-loop
    #:run-loop
    #:stat-loop
    #:defloop
    #:thread
    #:active
    #:until
    #:i-queue
    #:o-queue
    #:with-event-loop
    #:lock
    #:fps
    #:get-event-loop
    #:thread
    #:loop-fun
    #:event-loop-active-p
    #:notify-event
    #:event-loop
    #:enqueue-event
    #:dequeue-event
    #:process-single-event
    #:trigger-error-event
    #:process-loop-events
    #:start-event-loop
    #:evloop-state
    #:stop-event-loop
    #:toggle-event-loop
    #:error-event-handler)
  (:shadow     #:error-event-handler)
  (:documentation "Event loop package."))

(in-package #:cleve-elm.event-loop)

(defclass event-loop ()
  ((i-queue :initarg :i-queue
     :initform (make-queue)
     :accessor i-queue
     :documentation "The input queue of the event loop.
The loop function is called with the event as argument.")
    (state
      :initform :initialized
      :accessor evloop-state
      :documentation "Keyword describing the state of the event loop.
Possible values are :initialized, :running, :stopped and :error.")
    (o-queue :initarg :o-queue
      :initform (make-queue)
      :accessor o-queue
      :documentation "The output queue of the event loop. The return value
of the loop function is enqueued here if it is not equal nil.")
    (thread :initarg :thread
      :initform nil
      :accessor thread
      :documentation "The thread that executes the event loop.")
    (fps :initform nil
      :initarg :fps
      :accessor fps)
    (wait :initform t :accessor wait
      :initarg :wait
      :documentation "If true, the event loop will wait for an event to be enqueued,
otherwise it will return nil if no event is available.")
    (loop-function :initarg :loop-function
      :initform (lambda (event)
                  (format t "Received ~A. No loop function defined.~%" event))
      :accessor loop-function
      :initarg :loop-fun
      :documentation "The function that is executed
in the event loop thread."))
  (:documentation "An event loop."))

(defmethod print-object ((event-loop event-loop) stream)
  (print-unreadable-object (event-loop stream :type t :identity t)
    (format stream "<~A>[I:~A|O:~A]"
      (evloop-state event-loop)
      (queue-length (i-queue event-loop))
      (queue-length (o-queue event-loop)))))

(defmethod stat-loop ((event-loop event-loop))
  "Return plist of stats for each loop in the event system."
  (list (sb-thread:thread-name (slot-value event-loop 'CLEVE-ELM.EVENT-LOOP:THREAD))
    (slot-value event-loop 'CLEVE-ELM.EVENT-LOOP:EVLOOP-STATE)))


(defmacro with-fps (fps &body body)
  "Execute the body with the given fps."
  `(format t "FPS: ~A~%" ,fps)
  (if (and (not (null fps)) (numberp fps))
    `(let ((fpsreal (/ 1000000.0 ,fps))
            (time (get-internal-real-time)))
       (progn ,@body)
       (let ((time-diff (- (get-internal-real-time) time)))
         (if (< time-diff fpsreal)
           ;; (progn
           ;;   (format t "Sleep: ~A ~%" (- fpsreal time-diff))
           (sleep (/ (- fpsreal time-diff) 1000000.0))
           (warn "FPS too low! ~A" time-diff))))
    `(progn ,@body)))

(defmethod run-loop ((event-loop event-loop))
  (setf (evloop-state event-loop) :running)
  (loop while (eq (evloop-state event-loop) :running) do
    (with-fps (fps event-loop)
      (let* ((ev (dequeue (i-queue event-loop) (wait event-loop)))

              (quit-event-p (eq ev :quit))
              (r (unless quit-event-p
                   (funcall (loop-function event-loop) ev)))
              (o-l (o-queue event-loop)))
        ;; (format t "Received ~A.~%" ev)
        (when (and o-l r) (enqueue o-l r))
        (when (eq ev :quit)
          ;; (format t "~A: Quit event received.~%" (thread event-loop))
          (log-info "~A: Quit event received.~%" (thread event-loop))
          (setf (evloop-state event-loop) :stopped)
          (log-info "CLEVE-LOOP: :quit event processed, state set to ~S. Loop should terminate." (evloop-state event-loop))
          (return-from run-loop r))
        r))))

;; TODO typecase and proper quit event class
(defmethod stop-loop ((event-loop event-loop))
  "Stop the event loop by enqueuing the :quit event.
The loop will process events until the :quit event
is dequeued. It will dispatch it and terminate afterwards"
  (when (eq (evloop-state event-loop) :running)
    ;; (log-debug "Stopping event loop ~A" (thread event-loop))
    (format t "EXITING LOOP ~A~% (Enqueuing :quit)" (thread event-loop))
    (enqueue (i-queue event-loop) :quit)
    (log-info "CLEVE-LOOP: :quit event enqueued. Loop should terminate.")
    ;; (setf (evloop-state event-loop) :stopped) ; Removed this line
    ;; join thread
    ))

(defmethod event-loop-active-p ((event-loop event-loop))
  "Return true if the event loop is active."
  (eq (evloop-state event-loop) :running))

(defmacro defloop (name event-arg (&key (pool nil) (run t )
                                    (input-queue nil )
                                    (output-queue nil )
                                    (wait t ) (fps nil ) (mgr nil ))
                    &body body)
  "Define an event loop macro with the given name and @BODY operating on
  events EVENT-ARG dequeued from INPUT-QUEUE and enqueuing result values != NIL
  on OUTPUT-QUEUE.

  Allows specifying an event argument, optional run flag, input queue,
  output queue, wait flag, frames per second, and manager.
  The body is executed in the event loop thread. The event argument
  is passed to the body.

  Arguments:
  NAME: The name of the event loop.
  EVENT-ARG: The name of the event argument.
  optional keyword arguments:
  RUN: If true, the event loop is started immediately.
  INPUT-QUEUE: The input queue of the event loop. If not specified a
               new queue instance is created and attached. @BODY operates on
               EVENT-ARG dequeued from INPUT-QUEUE.
  OUTPUT-QUEUE: The output queue of the event loop. If not specified a
               new queue instance is created and attached. The last or 
               returned value of @BODY is enqueued to output-queue if it does not
               equal NIL.
  WAIT: If true, the event loop will wait for an event to be enqueued,
        otherwise it will return NIL if no event is available.
  FPS: The frames per second of the event loop.
  MGR: EVENT-SYSTEM that manages the event loop. Defining the mgr
       allows accessing the loop as member variable and defines helpers implemented
       as methods dispatching on the Event-System class and allow accessing the loop and
       thread through name-based methods.
  @BODY: The body of the event loop. It is executed in the event loop thread.
         The event argument is passed as EVENT-ARG to the body.

  The macro body specifies depending on NAME:
    Methods (all dispatching on MGR):
    - NAME-RUN: Run the event loop.
    - NAME-STOP: Stop the event loop by enqueuing an :QUIT event and
                 allowing @BODY to process it in its last iteration.
    - NAME-OUT-QUEUE: Return the output queue of the event loop.
    - NAME-IN-QUEUE: Return the input queue of the event loop.
    - NAME-LOOP: Return the event loop.
    - NAME-THREAD: Return the thread of the event loop.
    - NAME-STATE: Return the state of the event loop: One of keywords:
                  :init :running :error :stopped"

  ;; Generate internal symbols
  (let ((thread-sym (intern (string-upcase (format nil "~A-LOOP" name))))
         (run-meth (intern (string-upcase (format nil "~A-run" name))))
         (stop-meth (intern (string-upcase (format nil "~A-stop" name))))
         (out-queue-sym (intern (string-upcase(format nil "~A-out-queue" name))))
         (in-queue-sym (intern (string-upcase(format nil "~A-in-queue" name))))
         (state-sym (intern (string-upcase(format nil "~A-state" name))))
         (rendered-fun `(lambda (,event-arg) ,@body)))
    ;; declare about-to-be-defined-methods to the compiler
    (declare (ignorable run-meth stop-meth out-queue-sym in-queue-sym state-sym))
    ;; Ignore temporaries

    ;; `(declaim (ftype (function (t) (function)) ,run-meth))
    `(declare (ignorable  thread-sym stop-meth out-queue-sym in-queue-sym state-sym))
    `(declare (ignorable  thread-sym stop-meth out-queue-sym in-queue-sym state-sym))

    ;; Define methods on generated symbols
    `(progn
       ;; Create loop instance
       (let ((inst (make-instance 'event-loop :wait ,wait :fps ,fps :loop-fun ,rendered-fun)))
         ;; (declare (ignore ,run-meth))
         (defmethod ,run-meth ()

           ;; Start thread running loop
           (setf  (thread inst)
             (start-thread ,pool
               (lambda ()(run-loop inst))
               :description ,(format nil "~A-LOOP" name))))
         ;; Define stop method
         (defmethod ,stop-meth ()
           (stop inst)
           ;; (sb-thread:interrupt-thread (thread inst)
           ;;   (lambda () :dud;; (stop inst)
           ;;     ))
           )

         ;; Accessors
         (defmethod ,out-queue-sym ()
           (o-queue inst))
         (defgeneric ,in-queue-sym ())
         (defmethod ,in-queue-sym ()
           (i-queue inst))
         (defgeneric ,thread-sym ())
         (defmethod ,thread-sym ()
           inst)
         (defgeneric ,state-sym ())
         (defmethod ,state-sym ()
           (evloop-state inst))

         ;; Set queues if provided
         (when ,input-queue
           (setf (i-queue inst) ,input-queue))
         (when ,output-queue
           (setf (o-queue inst) ,output-queue))

         ;; `(declare (ignora run-meth))

         ;; Run if specified
         (when (and ,run (not (null ,mgr))) (funcall (function ,run-meth) ,mgr))))))
