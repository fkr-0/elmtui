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
  (:export #:with-interruptable-signal #:cond-message #:interrupt-payload)) ; Added interrupt-payload
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
;; (defmacro with-interruptable-signal (signal-fn &optional (returns nil) &body body)
;;   "Execute BODY in a separate thread and allow interruption by SIGNAL-FN.

;; If the thread is interrupted, SIGNAL-FN is called and its result is returned.

;; ARGS:
;;   SIGNAL-FN  — the function name to generate, which when called interrupts the thread
;;   RETURNS    — a symbol naming the local return-value binding (defaults to NIL)
;;   BODY       — forms to run in the spawned thread

;; Example:
;;   (with-interruptable-signal abort-counter val
;;     (dotimes (i 100)
;;       (setf val i)
;;       (sleep 1)))
;;   ;; ... elsewhere ...
;;   (abort-counter)  ;; interrupts the above thread and returns the last val"
;;   (let ((condition-name (intern (concatenate 'string (symbol-name signal-fn) "-INTERRUPT-SIGNAL")))
;;         (thread-var (gensym "THREAD-"))
;;         (return-value-var (if returns (gensym "RETURN-VALUE-") (gensym "DUMMY-RETURN-"))))
;;     (declare (ignorable thread-var return-value-var condition-name))
;;     `(progn
;;        (define-condition ,condition-name (condition)
;;          ((payload :initarg :payload :reader interrupt-payload)))

;;        (let ((,thread-var nil)
;;              (,return-value-var nil))
;;          (declare (ignorable ,return-value-var))

;;          (defun ,signal-fn (&optional (interrupt-data ,(if returns returns "Interrupted")))
;;            "Signals the associated thread (if running) to interrupt its operation.
;;             Optionally, INTERRUPT-DATA is passed to the thread's interrupt handler."
;;            (when (and ,thread-var (bordeaux-threads:thread-alive-p ,thread-var))
;;              (bordeaux-threads:interrupt-thread
;;               ,thread-var
;;               (lambda ()
;;                 (signal ',condition-name :payload interrupt-data)))
;;              ;; Note: The actual return value from the thread comes via the handler-case.
;;              ;; This function's return value is less critical, maybe just T for signaled.
;;              t))

;;          (setf ,thread-var
;;                (bordeaux-threads:make-thread
;;                 (lambda ()
;;                   (handler-case
;;                       ;; Execute the body
;;                       (progn ,@body)
;;                     (,condition-name (c)
;;                       ;; When interrupted, set the return-value-var with the payload
;;                       ,(if returns
;;                            `(setf ,returns (interrupt-payload c))
;;                            `(progn (format *trace-output* "~&Thread interrupted by ~A with payload: ~S~%"
;;                                            ',condition-name (interrupt-payload c))
;;                                    ;; If no 'returns' var specified, just set the internal one
;;                                    (setf ,return-value-var (interrupt-payload c))))
;;                       ;; The value of 'returns' (or return-value-var) is implicitly the thread's result here
;;                       ,(if returns returns return-value-var))))
;;                 :name (format nil "~A-thread" ',signal-fn)))
;;          ;; The macro itself doesn't directly return the thread's result.
;;          ;; It sets up the mechanism. The caller of start-reader (for example)
;;          ;; would get the thread and the signal function.
;;          ;; The 'returns' variable is set *in the thread* when interrupted.
;;          ;; If the user needs this value, they must arrange to get it (e.g. if 'returns' is a lexical variable
;;          ;; in the scope where with-interruptable-signal is called).
;;          (values ,thread-var ',signal-fn)))))
;; (defmacro with-interruptable-signal
;;     (signal-fn &optional (returns nil) &body body)
;;   "Execute body in a separate thread and allow interruption by signal-fn.

;;   Args:
;;     signal-fn: The function to call to signal the thread.
;;     returns: The value to return when the thread is interrupted.
;;     body: The body to execute.
;;   Returns:
;;     The value of the last form in body or returns if the thread is interrupted.

;;   Examples:
;;     (with-interruptable-signal cancel-read
;;       (format t \"Reading~%\")
;;       (sleep 10)
;;       (format t \"Done~%\"))
;;        => \"Done~%\"
;;     (with-interruptable-signal (cancel-ctr c)
;;       (format t \"Reading~%\")
;;       (dot)

;;       (format t \"Done~%\"))
;;        => \"Aborted cancel-read\"
;;     (with-interruptable-signal cancel-read
;;       (format t \"Reading~%\")
;;       (sleep 10)
;;       (format t \"Done~%\"))
;;        => \"Done~%\"
;;     (with-interruptable-signal cancel-read
;;       (format t \"Reading~%\")
;;       (sleep 10)
;;       (format t \"Done~%\"))
;;        => \"Aborted cancel-read\"
;; "
;;   (let ((sig (intern (concatenate 'string (symbol-name signal-fn) "-SIGNAL")))
;;         (thread-var (gensym "THREAD-"))
;;         (fun-var
;;           (intern
;;            (concatenate 'string "ABORT-" (symbol-name signal-fn) "-INNERFN"))))
;;     `(let ((,returns nil) (,thread-var nil))
;;        (labels ((,fun-var ()
;;                   (bordeaux-threads:interrupt-thread ,thread-var
;;                                                      (lambda ()
;;                                                        (format t
;;                                                                "Aborting ~A operation~%"
;;                                                                ,(format nil
;;                                                                         "Start: Aborting ~A operation"
;;                                                                         sig))
;;                                                        (signal ',sig
;;                                                                :message (or ,returns
;;                                                                             ,(format
;;                                                                               nil
;;                                                                               "Aborted ~A"
;;                                                                               sig)))))))
;;          (setq ,thread-var
;;                (bordeaux-threads:make-thread
;;                 (lambda ()
;;                   (handler-case (progn ,@body)
;;                     (,sig (c)
;;                       (progn
;;                         (format t "ThreadAbort: ~A~%"
;;                                 ,(format nil "~A quit" sig))
;;                         (return-from ,fun-var (message c))))))))
;;          (define-condition ,sig (condition)
;;            ((message :initarg :message :reader message)))
;;          (defun ,signal-fn () (,fun-var))
;;          ,returns))))
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
;;     `(let* (
;;             (,return-var nil)
;;             (,returns nil)
;;             (,thread-var (bordeaux-threads:make-thread
;;                           (lambda ()
;;                             (handler-case (progn ,@body)
;;                               (,sig (c)
;;                                 (progn
;;                                   (format t "Signaled val: ~A ~A~%"
;;                                           (message c)
;;                                           ,(format nil "~A quit" sig))
;;                                   (setf ,return-var (message c)))))))))
;;        (declare (function ,signal-fn) (condition ,sig))
;;        (define-condition ,sig (condition)
;;          ((message :initarg :message :reader message)))
;;        (defun ,signal-fn ()
;;          (bordeaux-threads:interrupt-thread ,thread-var
;;                                             (lambda ()
;;                                               (format t "~A~%"
;;                                                       ,(format nil "Start: Aborting ~A operation" sig))
;;                                               (signal ',sig
;;                                                       :message (or ,returns ,(format nil "Aborted ~A" sig)))))
;;          ,returns)
;;        ;; (bordeaux-threads:join-thread ,thread-var)
;;        ,return-var
;;        ,thread-var)))

;; (with-interruptable-signal abort-fn val
;;   (dotimes (i 100)
;;     (setf val i)
;;     (format t "Thread: i: ~A~%" i)
;;     (sleep 1)))
;; (abort-fn)
;; (defmacro with-interruptable-signal (signal-fn return-var &body body)
;;   "Spawn a background thread running BODY.  RETURN-VAR is bound to NIL initially;
;; you can (setf RETURN-VAR <something>) anywhere in BODY to record a result or progress.
;; Defines a global function SIGNAL-FN which, when called, will:

;;  1. interrupt the thread,
;;  2. cause it to THROW the tag 'interrupt carrying the current RETURN-VAR,
;;  3. return that RETURN-VAR to you.

;; The macro itself returns the thread object (so you can join it if you like)."
;;   (let ((thread-sym (gensym "THREAD")))
;;     `(progn
;;        ;; 1) a global place to store your return value
;;        (defparameter ,return-var nil
;;          "Value set by the interruptible thread; returned when you call SIGNAL-FN.")

;;        ;; 2) a global var to hold the thread object
;;        (defparameter ,thread-sym nil
;;          "Thread running the interruptible code.")

;;        ;; 3) start the thread, wrapping BODY in a CATCH for 'interrupt
;;        (setf ,thread-sym
;;              (bordeaux-threads:make-thread
;;               (lambda ()
;;                 (catch 'interrupt
;;                   ,@body
;;                   ;; if BODY runs to completion without interruption,
;;                   ;; the thread simply returns NIL here
;;                   ))))

;;        ;; 4) define your interrupt function
;;        (setf (symbol-function ',signal-fn)
;;              (lambda ()
;;                "Interrupt the thread started above and return the last value of RETURN-VAR."
;;                (bordeaux-threads:interrupt-thread ,thread-sym
;;                                                   (lambda ()
;;                                                     (throw 'interrupt ,return-var)))
;;                ,return-var))

;;        ;; 5) return the thread object
;;        ,thread-sym)))

;; (let ((thread
;;         (with-interruptable-signal abort-testfn val
;;           (format t "Worker starting…~%")
;;           (dotimes (i 100)
;;             (setf val i)
;;             (format t "Worker: i = ~A~%" i)
;;             (sleep 1)))))
;;   (format t "Main: worker thread ~A started~%" thread)
;;   (sleep 5)
;;   (format t "Main: abort returns ~A~%" (abort-testfn)))
;; (defmacro with-interruptable-signal (signal-fn return-var &body body)
;;   "Spawn a background thread running BODY.  RETURN-VAR is a user-supplied symbol,
;; initialized to NIL; you can (SETF RETURN-VAR …) anywhere in BODY to record progress
;; or final result.  Defines a global function SIGNAL-FN which, when called, will:

;;  1. interrupt the thread,
;;  2. throw a tag 'interrupt carrying the current RETURN-VAR,
;;  3. return that RETURN-VAR to the caller of SIGNAL-FN.

;; The macro expands to evaluating to the thread object itself."
;;   (let* ((pkg *package*)
;;          (thread-name (format nil "__~A-THREAD__" (symbol-name signal-fn)))
;;          (thread-sym  (intern thread-name pkg)))
;;     `(progn
;;        ;; 1. A global place for the user to record a return value:
;;        (defvar ,return-var nil)

;;        ;; 2. A global var to hold the thread object:
;;        (defvar ,thread-sym nil)

;;        ;; export the thread-sym so it can be used in the signal function
;;        ;; export the signal-fn so it can be used in the thread
;;        ;; 3. Start the thread, wrapping BODY in a (CATCH 'interrupt …)
;;        (setf ,thread-sym
;;              (bordeaux-threads:make-thread
;;               (lambda ()
;;                 (catch 'interrupt
;;                   ,@body
;;                   ;; If BODY completes normally, thread returns NIL:
;;                   ))))

;;        ;; 4. Define the user’s interrupt function:
;;        (setf (symbol-function ',signal-fn)
;;              (lambda ()
;;                ,(format nil "Interrupt thread ~A% and return last value of ~A%." `,signal-fn return-var)
;;                (bordeaux-threads:interrupt-thread ,thread-sym
;;                                                   (lambda () (throw 'interrupt ,return-var)))
;;                ,return-var))

;;        ;; (export ,thread-sym)
;;        ;; (export ,signal-fn)
;;        ;; 5. Return the thread object
;;        ,thread-sym)))

(defmacro with-interruptable-signal (return-var &body body)
  "Spawn a background thread running BODY.  RETURN-VAR is a user-supplied symbol,
initialized to NIL; you can (SETF RETURN-VAR …) anywhere in BODY to record progress
or final result.  Defines a global function SIGNAL-FN which, when called, will:

 1. interrupt the thread,
 2. throw a tag 'interrupt carrying the current RETURN-VAR,
 3. return that RETURN-VAR to the caller of SIGNAL-FN.

The macro expands to evaluating to the thread object itself."
  (let* ((pkg *package*)
         (thread-name (format nil "__~A-THREAD__" (symbol-name return-var)))
         (thread-sym  (intern thread-name pkg))
         (ret-sym (gensym)))
    `(progn

       ;; export the thread-sym so it can be used in the signal function
       ;; export the signal-fn so it can be used in the thread
       ;; 3. Start the thread, wrapping BODY in a (CATCH 'interrupt …)
       (let* ((,return-var nil)
              (,ret-sym ,return-var)
              (,thread-sym
                (bordeaux-threads:make-thread
                 (lambda ()
                   (catch 'interrupt
                     ,@body))))
              (interrupt-fn
                (lambda ()
                  ;; ,(format
                  ;;   nil
                  ;;   "Interrupt thread ~A% and return last value of ~A%."
                  ;;   `,thread-name `,return-var)
                  (bordeaux-threads:interrupt-thread
                   ,thread-sym
                   (lambda () (throw 'interrupt ,ret-sym)))
                  ,return-var)))
         (values ,thread-sym interrupt-fn)))))

;; (let ((thread
;;         (with-interruptable-signal abort-testfn val
;;           (format t "Worker starting…~%")
;;           (dotimes (i 100)
;;             (setf val i)
;;             (format t "Worker: i = ~A~%" i)
;;             (sleep 1)))))
;;   (format t "Main: worker thread ~A started~%" thread)
;;   (sleep 5)
;;   (format t "Main: abort returns ~A~%" (abort-testfn)))
