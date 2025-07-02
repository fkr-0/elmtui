;;; == elmtui/contracts/types.lisp ==
(in-package #:elmtui.contracts)

(defclass ui-node        () ())
(defclass styled-ui-node () ()     ) ; your existing classes, re-exported

;; ------------------------------------------------------------------------
;; Condition hierarchy
;; ------------------------------------------------------------------------
(define-condition pipeline-contract-violation (error)
  ((stage         :initarg :stage :reader violation-stage)
   (expected-type :initarg :expected-type :reader violation-expected)
   (got-object    :initarg :got-object :reader violation-got))
  (:report (lambda (c s)
             (with-slots (stage expected-type got-object) c
               (format s "~a expected ~s but got ~s (~s)."
                       stage expected-type got-object (type-of got-object))))))

(define-condition undefined-layout (pipeline-contract-violation) ())
;;; == end/types.lisp ==