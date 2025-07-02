;;; == elmtui/contracts/stage.lisp ==
(in-package #:elmtui.contracts)

;; Helper to turn DEFPipeline-stage declarations into wrapper functions
(defmacro define-stage (name (in-type out-type) arglist &body body)
  "Wrap BODY in run-time CHECK-TYPE and restartable contract checks."
  (let ((result (gensym "RES")))
    `(defun ,name ,arglist
       ;; --- pre-condition -------------------------------------------------
       (check-type (first ,arglist) ,in-type
         ,(format nil "~a input violated contract (expected ~a)." name in-type))
       (handler-bind
           ((error (lambda (e)
                     (error 'pipeline-contract-violation
                            :stage ',name
                            :expected-type ',in-type
                            :got-object e))))
         (let ((,result (progn ,@body)))
           ;; --- post-condition -------------------------------------------
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
           ,result))))
;;; == end/stage.lisp ==