(uiop:define-package :elmtui.core.threads
  (:use :cl)
  (:import-from :sb-thread
   :make-thread :interrupt-thread)
  (:import-from :elmtui.core.globals
                ;; :*app-sender*
                )
  (:import-from :elmtui.core.conditions
                ;; :signal-condition
                )
  (:export with-interruptible-signal :cond-message) )
(in-package :elmtui.core.threads)



(defgeneric cond-message (condition)
  (:documentation "Get the message from a condition object."))
;; (defmacro with-interruptable-signal (signal-fn &optional (returns nil) &body body)
;;   "Execute body in a separate thread and allow interruption by signal-fn.

;; If the thread is interrupted, the signal-fn is called and the returns value is return
;; value of the signal-fn function call.

;;   Args:
;;     signal-fn: The function to call to signal the thread.
;;     returns: The value to return when the thread is interrupted.
;;     body: The body to execute.
;;   Returns:
;;     NIL

;;   Example:
;;     (progn (with-interruptable-signal abort-testfn  val
;;              (format t \"Thread: Thread Started, setf\")
;;              (dotimes (i 100)
;;                (setf val i)
;;                (format t \"Thread: i: ~A~%\" i)
;;                (sleep 1)))
;;       (format t \"Main: Thread Started\")
;;       (format t \"Main: Sleeping 5s\")
;;       (sleep 5)
;;       (format t \"Main: AbortFn Returns: ~A~%\"(abort-testfn)))
;;     => Main: AbortFn Returns: 200"
;;   (let ((sig (intern (concatenate 'string (symbol-name signal-fn) "-SIGNAL")))
;;         (thread-var (gensym "THREAD-"))
;;         (return-var (gensym "RETURN-")))
;;     `(declare (function ,signal-fn))
;;     `(let* ((,return-var nil)
;;             (,returns nil)
;;             (,thread-var (bordeaux-threads:make-thread
;;                           (lambda ()
;;                             (handler-case (progn ,@body)
;;                               (,sig (c)
;;                                 (progn
;;                                   (format t "Signaled val: ~A ~A~%"
;;                                           (cond-message c)
;;                                           ,(format nil "~A quit" sig))
;;                                   (setf ,return-var (cond-message c)))))))))
;;        (define-condition ,sig (condition)
;;          ((cond-message :initarg :message :reader cond-message)))
;;        (defun ,signal-fn ()
;;          (bordeaux-threads:interrupt-thread ,thread-var
;;                                             (lambda ()
;;                                               (format t "~A~%"
;;                                                       ,(format nil "Start: Aborting ~A operation" sig))
;;                                               (signal ',sig
;;                                                       :message (or ,returns ,(format nil "Aborted ~A" sig)))))
;;          ,returns)
;;        ;; (bordeaux-threads:join-thread ,thread-var)
;;        ,return-var)))
(defmacro with-interruptable-signal (signal-fn &optional (returns nil) &body body)
  "Execute BODY in a separate thread and allow interruption by SIGNAL-FN.

If the thread is interrupted, SIGNAL-FN is called and its result is returned.

ARGS:
  SIGNAL-FN  — the function name to generate, which when called interrupts the thread
  RETURNS    — a symbol naming the local return-value binding (defaults to NIL)
  BODY       — forms to run in the spawned thread

Example:
  (with-interruptable-signal abort-counter val
    (dotimes (i 100)
      (setf val i)
      (sleep 1)))
  ;; ... elsewhere ...
  (abort-counter)  ;; interrupts the above thread and returns the last val"
  (let ((condition-name (intern (concatenate 'string (symbol-name signal-fn) "-INTERRUPT-SIGNAL")))
        (thread-var (gensym "THREAD-"))
        (return-value-var (if returns (gensym "RETURN-VALUE-") (gensym "DUMMY-RETURN-"))))
    `(progn
       (define-condition ,condition-name (condition)
         ((payload :initarg :payload :reader interrupt-payload)))

       (let ((,thread-var nil)
             (,return-value-var nil))
         (declare (ignorable ,return-value-var))

         (defun ,signal-fn (&optional (interrupt-data ,(if returns returns "Interrupted")))
           "Signals the associated thread (if running) to interrupt its operation.
            Optionally, INTERRUPT-DATA is passed to the thread's interrupt handler."
           (when (and ,thread-var (bordeaux-threads:thread-alive-p ,thread-var))
             (bordeaux-threads:interrupt-thread
              ,thread-var
              (lambda ()
                (signal ',condition-name :payload interrupt-data)))
             ;; Note: The actual return value from the thread comes via the handler-case.
             ;; This function's return value is less critical, maybe just T for signaled.
             t))

         (setf ,thread-var
               (bordeaux-threads:make-thread
                (lambda ()
                  (handler-case
                      ;; Execute the body
                      (progn ,@body)
                    (,condition-name (c)
                      ;; When interrupted, set the return-value-var with the payload
                      ,(if returns
                           `(setf ,returns (interrupt-payload c))
                           `(progn (format *trace-output* "~&Thread interrupted by ~A with payload: ~S~%"
                                           ',condition-name (interrupt-payload c))
                                   ;; If no 'returns' var specified, just set the internal one
                                   (setf ,return-value-var (interrupt-payload c))))
                      ;; The value of 'returns' (or return-value-var) is implicitly the thread's result here
                      ,(if returns returns return-value-var))))
                :name (format nil "~A-thread" ',signal-fn)))
         ;; The macro itself doesn't directly return the thread's result.
         ;; It sets up the mechanism. The caller of start-reader (for example)
         ;; would get the thread and the signal function.
         ;; The 'returns' variable is set *in the thread* when interrupted.
         ;; If the user needs this value, they must arrange to get it (e.g. if 'returns' is a lexical variable
         ;; in the scope where with-interruptable-signal is called).
         (values ,thread-var ',signal-fn)))))
