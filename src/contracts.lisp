(uiop:define-package :elmtui.contracts
  (:use :cl)
  (:export #:define-stage #:define-pipeline #:pipeline-contract-violation #:full-view-pipeline))

(in-package #:elmtui.contracts)

(define-condition pipeline-contract-violation (error)
  ((stage         :initarg :stage :reader violation-stage)
   (expected-type :initarg :expected-type :reader violation-expected)
   (got-object    :initarg :got-object :reader violation-got))
  (:report (lambda (c s)
             (with-slots (stage expected-type got-object) c
               (format s "~a expected ~s but got ~s (~s)."
                       stage expected-type got-object (type-of got-object))))))
;;; == elmtui/contracts/stage.lisp (fixed) ==
(in-package #:elmtui.contracts)

(defmacro define-stage (name (in-type out-type) arglist &body body)
  "Wrap BODY in run-time CHECK-TYPE and restartable contract checks."
  (unless (and (listp arglist)
               (symbolp (first arglist)))
    (error "define-stage: arglist must be a list whose FIRST element is the input symbol"))
  (let* ((input-sym  (first arglist))
         (result-sym (gensym "RES")))
    `(progn
       ;; record the declared types for pipeline-linkage
       (setf (get ',name :pipeline/in-type)  ',in-type
             (get ',name :pipeline/out-type) ',out-type)
       (defun ,name ,arglist
         ;; --- pre-condition -------------------------------------------------
         (check-type ,input-sym ,in-type
                     ,(format nil "~a input violated contract (expected ~a)."
                              name in-type))
         (handler-bind
             ((error (lambda (e)
                       (error 'pipeline-contract-violation
                              :stage ',name
                              :expected-type ',in-type
                              :got-object e))))
           (let ((,result-sym (progn ,@body)))
             ;; --- post-condition -------------------------------------------
             (unless (typep ,result-sym ',out-type)
               (restart-case
                   (error 'pipeline-contract-violation
                          :stage ',name
                          :expected-type ',out-type
                          :got-object ,result-sym)
                 (coerce-result (new)
                   :report "Provide replacement value and continue."
                   :interactive (lambda ()
                                  (format t "~%New value? ")
                                  (list (eval (read))))
                   (setq ,result-sym new))
                 (skip-stage ()
                   :report "Skip this stage and propagate input forward."
                   (setq ,result-sym ,input-sym))))
             ,result-sym))))))
;;; == end stage.lisp ==

;; (defmacro define-stage (name (in-type out-type) arglist &body body)
;;   "Wrap BODY in run-time CHECK-TYPE and restartable contract checks."
;;   (let ((result (gensym "RES")))
;;     `(defun ,name ,arglist
;;        (check-type (first ,arglist) ,in-type
;;          ,(format nil "~a input violated contract (expected ~a)." name in-type))
;;        (handler-bind
;;            ((error (lambda (e)
;;                      (error 'pipeline-contract-violation
;;                             :stage ',name
;;                             :expected-type ',in-type
;;                             :got-object e))))
;;          (let ((,result (progn ,@body)))
;;            (unless (typep ,result ',out-type)
;;              (restart-case
;;                  (error 'pipeline-contract-violation
;;                         :stage ',name
;;                         :expected-type ',out-type
;;                         :got-object ,result)
;;                (coerce-result (new)
;;                  :report "Provide replacement value and continue."
;;                  :interactive (lambda ()
;;                                 (format t "~%New value? ")
;;                                 (list (eval (read))))
;;                  (setq ,result new))
;;                (skip-stage ()
;;                  :report "Skip this stage and propagate input forward."
;;                  (setq ,result (first ,arglist)))))
;;            ,result)))))

(defmacro define-pipeline (name &rest stage-fns)
  "Compose STAGE-FNS into a single function that threads a context plist through them."
  (let ((context (gensym "CONTEXT")))
    `(defun ,name (,context)
       (reduce (lambda (ctx fn) (funcall fn ctx))
               ',stage-fns
               :initial-value ,context))))
