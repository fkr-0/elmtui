(uiop:define-package :elmtui.contracts
  (:use :cl)
  (:export #:define-stage #:define-pipeline #:pipeline-contract-violation))

(in-package #:elmtui.contracts)

(define-condition pipeline-contract-violation (error)
  ((stage         :initarg :stage :reader violation-stage)
   (expected-type :initarg :expected-type :reader violation-expected)
   (got-object    :initarg :got-object :reader violation-got))
  (:report (lambda (c s)
             (with-slots (stage expected-type got-object) c
               (format s "~a expected ~s but got ~s (~s)."
                       stage expected-type got-object (type-of got-object))))))

(defmacro define-stage (name (in-type out-type) arglist &body body)
  "Wrap BODY in run-time CHECK-TYPE and restartable contract checks."
  (let ((result (gensym "RES")))
    `(defun ,name ,arglist
       (check-type (first ,arglist) ,in-type
         ,(format nil "~a input violated contract (expected ~a)." name in-type))
       (handler-bind
           ((error (lambda (e)
                     (error 'pipeline-contract-violation
                            :stage ',name
                            :expected-type ',in-type
                            :got-object e))))
         (let ((,result (progn ,@body)))
           (unless (typep ,result ',out-type)
             (restart-case
                 (error 'pipeline-contract-violation
                        :stage ',name
                        :expected-type ',out-type
                        :got-object ,result)
               (coerce-result (new)
                 :report "Provide replacement value and continue."
                 :interactive (lambda ()
                                (format t "~%New value? ")
                                (list (eval (read))))
                 (setq ,result new))
               (skip-stage ()
                 :report "Skip this stage and propagate input forward."
                 (setq ,result (first ,arglist)))))
           ,result)))))

(defmacro define-pipeline (name &rest stage-fns)
  "Compose STAGE-FNS into a single function that threads a context plist through them."
  (let ((context (gensym "CONTEXT")))
    `(defun ,name (,context)
       (reduce (lambda (ctx fn) (funcall fn ctx))
               ',stage-fns
               :initial-value ,context))))
