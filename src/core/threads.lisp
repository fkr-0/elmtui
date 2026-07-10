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

