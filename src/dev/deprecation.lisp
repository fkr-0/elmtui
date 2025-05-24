;;;===============================================================
;;; File: src/dev/deprecation.lisp
;;; Utilities for marking and managing deprecated functionality
;;;===============================================================

(uiop:define-package :elmtui.dev.deprecation
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-warn #:log-info #:log-debug)
  (:export #:mark-deprecated
           #:define-deprecated-function
           #:define-deprecated-macro
           #:define-deprecated-class
           #:define-deprecated-method
           #:find-deprecated-symbols
           #:print-deprecation-report))

(in-package :elmtui.dev.deprecation)

(defparameter *deprecated-symbols* (make-hash-table :test 'eq)
  "Hash table storing deprecated symbols and their metadata.")

(defstruct deprecation-info
  "Stores information about a deprecated symbol."
  symbol
  type          ; :function, :macro, :class, :method, etc.
  since         ; Version when deprecated
  alternatives  ; List of recommended alternatives
  removal       ; Planned removal version
  doc           ; Documentation explaining the deprecation
  package)      ; Package containing the symbol

(defun mark-deprecated (symbol type &key since alternatives removal doc)
  "Mark a symbol as deprecated. Returns the symbol.
   SYMBOL - The symbol to deprecate
   TYPE - Type of the symbol: :function, :macro, :class, :method, etc.
   SINCE - Version when deprecated (string)
   ALTERNATIVES - List of alternative symbols to use instead
   REMOVAL - Planned removal version (string)
   DOC - Documentation explaining the deprecation"
  (let ((info (make-deprecation-info 
               :symbol symbol
               :type type
               :since (or since "unknown")
               :alternatives alternatives
               :removal (or removal "future")
               :doc doc
               :package (symbol-package symbol))))
    (setf (gethash symbol *deprecated-symbols*) info)
    
    ;; Log warning about deprecation
    (log-warn "~A ~S is deprecated since version ~A and will be removed in ~A. ~A"
              (string-capitalize (symbol-name type))
              symbol
              (deprecation-info-since info)
              (deprecation-info-removal info)
              (if (deprecation-info-alternatives info)
                  (format nil "Use ~{~S~^, ~} instead." 
                          (deprecation-info-alternatives info))
                  "No direct alternative provided."))
    
    ;; Return the symbol itself for composability
    symbol))

(defmacro define-deprecated-function (name args &key since alternatives removal doc)
  "Define a function that's marked as deprecated but forwards to a real implementation.
   NAME - Name of the deprecated function
   ARGS - Lambda list for the function
   BODY - Implementation or call to actual function
   SINCE - Version when deprecated (string)
   ALTERNATIVES - List of alternative functions to use instead
   REMOVAL - Planned removal version (string)
   DOC - Documentation explaining the deprecation"
  (let ((actual-name (symbolicate name '#:-impl))
        (doc-with-warning (format nil "DEPRECATED: ~A~%~A~%Will be removed in version ~A.~%~@[Use ~{~S~^, ~} instead.~]"
                                  (or doc "")
                                  (if since (format nil "Deprecated since version ~A." since) "")
                                  (or removal "a future version")
                                  alternatives)))
    `(progn
       ;; Define the actual implementation
       (defun ,actual-name ,args
         ,@(when doc `(,doc-with-warning))
         (log-warn ,(format nil "Function ~S is deprecated. ~A" 
                            name 
                            (if alternatives 
                                (format nil "Use ~{~S~^, ~} instead." alternatives) 
                                "")))
         nil)  ; Implementation goes here
         
       ;; Define the deprecated wrapper
       (defun ,name ,args
         ,doc-with-warning
         (apply #',actual-name (list ,@(mapcar #'first (remove-if (lambda (x) (member x lambda-list-keywords)) args)))))
         
       ;; Mark as deprecated in our registry
       (mark-deprecated ',name :function 
                        :since ,since 
                        :alternatives ',alternatives
                        :removal ,removal
                        :doc ,doc))))

(defmacro define-deprecated-macro (name args &key since alternatives removal doc)
  "Define a macro that's marked as deprecated but forwards to a real implementation.
   Similar to define-deprecated-function but for macros."
  (let ((actual-name (symbolicate name '#:-impl))
        (doc-with-warning (format nil "DEPRECATED: ~A~%~A~%Will be removed in version ~A.~%~@[Use ~{~S~^, ~} instead.~]"
                                  (or doc "")
                                  (if since (format nil "Deprecated since version ~A." since) "")
                                  (or removal "a future version")
                                  alternatives)))
    `(progn
       ;; Define the actual implementation macro
       (defmacro ,actual-name ,args
         ,@(when doc `(,doc-with-warning))
         (log-warn ,(format nil "Macro ~S is deprecated. ~A" 
                            name 
                            (if alternatives 
                                (format nil "Use ~{~S~^, ~} instead." alternatives) 
                                "")))
         nil)  ; Implementation goes here
         
       ;; Define the deprecated wrapper macro
       (defmacro ,name ,args
         ,doc-with-warning
         (macroexpand-1 `(,',actual-name ,@(list ,@(mapcar #'first (remove-if (lambda (x) (member x lambda-list-keywords)) args))))))
         
       ;; Mark as deprecated in our registry
       (mark-deprecated ',name :macro 
                        :since ,since 
                        :alternatives ',alternatives
                        :removal ,removal
                        :doc ,doc))))

(defmacro define-deprecated-class (name superclasses slots &rest options)
  "Define a class that's marked as deprecated.
   Similar to defclass but adds deprecation warnings."
  (let* ((since (getf options :since))
         (alternatives (getf options :alternatives))
         (removal (getf options :removal))
         (doc (getf options :doc))
         (doc-with-warning (format nil "DEPRECATED: ~A~%~A~%Will be removed in version ~A.~%~@[Use ~{~S~^, ~} instead.~]"
                                   (or doc "")
                                   (if since (format nil "Deprecated since version ~A." since) "")
                                   (or removal "a future version")
                                   alternatives))
         (clean-options (remove-from-plist options :since :alternatives :removal :doc)))
    `(progn
       ;; Define the actual class
       (defclass ,name ,superclasses
         ,slots
         ,@(when doc `((:documentation ,doc-with-warning)))
         ,@clean-options)
         
       ;; Add a method to initialize-instance that warns about deprecation
       (defmethod initialize-instance :before ((instance ,name) &key)
         (declare (ignorable instance))
         (log-warn ,(format nil "Class ~S is deprecated. ~A" 
                            name 
                            (if alternatives 
                                (format nil "Use ~{~S~^, ~} instead." alternatives) 
                                ""))))
         
       ;; Mark as deprecated in our registry
       (mark-deprecated ',name :class 
                        :since ,since 
                        :alternatives ',alternatives
                        :removal ,removal
                        :doc ,doc))))

(defmacro define-deprecated-method (name specialized-params &body body)
  "Define a method that's marked as deprecated.
   Similar to defmethod but adds deprecation warnings."
  (let ((method-name (if (listp name) (first name) name))  ; Handle qualifier lists
        (qualifiers (when (listp name) (rest name))))
    `(progn
       ;; Define the actual method
       (defmethod ,method-name ,@qualifiers ,specialized-params
         (log-warn ,(format nil "Method ~S~A is deprecated." 
                           method-name
                           (format nil " (~{~S~^ ~})" 
                                   (mapcar (lambda (param)
                                             (if (listp param)
                                                 (second param)
                                                 t))
                                           (remove-if (lambda (x) (member x lambda-list-keywords)) 
                                                      specialized-params)))))
         ,@body)
         
       ;; Mark as deprecated in our registry
       (mark-deprecated ',method-name :method))))

(defun find-deprecated-symbols (&optional package)
  "Find all deprecated symbols in the system or a specific package.
   Returns a list of deprecation-info structures."
  (let ((result '()))
    (if package
        ;; Search only in the specified package
        (maphash (lambda (symbol info)
                   (when (eq (symbol-package symbol) (find-package package))
                     (push info result)))
                 *deprecated-symbols*)
        ;; Search in all packages
        (maphash (lambda (symbol info)
                   (declare (ignore symbol))
                   (push info result))
                 *deprecated-symbols*))
    result))

(defun print-deprecation-report (&optional (stream *standard-output*) package)
  "Print a report of all deprecated symbols to the specified stream."
  (let ((deprecated-symbols (find-deprecated-symbols package)))
    (format stream "~&~%===== DEPRECATION REPORT =====~%")
    (format stream "Total deprecated symbols: ~D~%" (length deprecated-symbols))
    
    ;; Group by package
    (let ((by-package (make-hash-table :test 'eq)))
      (dolist (info deprecated-symbols)
        (push info (gethash (deprecation-info-package info) by-package)))
      
      ;; Print by package
      (maphash 
       (lambda (package symbols)
         (format stream "~&~%Package: ~A~%" (package-name package))
         (format stream "------------------------~%")
         
         ;; Group by type within package
         (let ((by-type (make-hash-table)))
           (dolist (info symbols)
             (push info (gethash (deprecation-info-type info) by-type)))
           
           ;; Print by type
           (maphash
            (lambda (type infos)
              (format stream "~&~A:~%" (string-capitalize (symbol-name type)))
              (dolist (info infos)
                (format stream "  ~S~%" (deprecation-info-symbol info))
                (format stream "    Since: ~A~%" (deprecation-info-since info))
                (format stream "    Removal: ~A~%" (deprecation-info-removal info))
                (when (deprecation-info-alternatives info)
                  (format stream "    Alternatives: ~{~S~^, ~}~%" 
                          (deprecation-info-alternatives info)))
                (when (deprecation-info-doc info)
                  (format stream "    Documentation: ~A~%" (deprecation-info-doc info)))))
            by-type)))
       by-package))
    
    (format stream "~&~%===== END DEPRECATION REPORT =====~%")
    (values)))
