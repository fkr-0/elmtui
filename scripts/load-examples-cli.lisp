;;; Quicklisp log4cl 2023-06-18 defines these methods in logger.lisp before
;;; declaring their generic functions in appender-base.lisp. SBCL reports
;;; their subsequent explicit declarations as redefinitions. Limit this
;;; compatibility handler to those upstream declarations; other warnings,
;;; including ElmTUI redefinitions, remain visible.
(handler-bind
    ((sb-ext:compiler-note #'muffle-warning)
     (sb-kernel:redefinition-warning
       (lambda (condition)
         (let ((name (sb-kernel::redefinition-warning-name condition)))
           (when (and (symbolp name)
                      (string= (package-name (symbol-package name)) "LOG4CL-IMPL")
                      (member (symbol-name name)
                              '("APPENDER-ADDED" "APPENDER-REMOVED" "PROPERTY-ALIST")
                              :test #'string=))
             (muffle-warning condition))))))
  (asdf:load-system "elmtui-examples-cli"))
