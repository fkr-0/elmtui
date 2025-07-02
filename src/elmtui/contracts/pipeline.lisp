(in-package #:elmtui.contracts)

(defmacro define-pipeline (name &rest stage-fns)
  "Compose STAGE-FNS into a single function that threads a context plist through them."
  (let ((context (gensym "CONTEXT"))) 
    `(defun ,name (,context)
       (reduce (lambda (ctx fn) (funcall fn ctx))
               ',stage-fns
               :initial-value ,context))))