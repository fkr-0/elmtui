;;;===============================================================
;;; File: src/app/application-extension.lisp
;;; Defapplication extensions for binary and CLI option support
;;;===============================================================

(uiop:define-package :elmtui.app.extension
  (:use :cl)
  (:import-from :uiop
                #:getenv)
  (:export
   #:validate-cli-option-specs
   #:normalize-binary-options
   #:parse-cli-options))

(in-package :elmtui.app.extension)

(defun %kw (x)
  (etypecase x
    (keyword x)
    (symbol (intern (string-upcase x) "KEYWORD"))
    (string (intern (string-upcase x) "KEYWORD"))))

(defun %coerce-cli-value (raw type option-name)
  (case type
    ((string) raw)
    ((integer)
     (or (parse-integer raw :junk-allowed nil)
         (error "CLI option ~S expects integer, got ~S" option-name raw)))
    ((keyword)
     (%kw raw))
    ((boolean)
     (cond
       ((or (string= raw "1") (string-equal raw "true") (string-equal raw "yes")) t)
       ((or (string= raw "0") (string-equal raw "false") (string-equal raw "no")) nil)
       (t (error "CLI option ~S expects boolean, got ~S" option-name raw))))
    (t
     (error "Unsupported CLI option type ~S for ~S" type option-name))))

(defun validate-cli-option-specs (specs)
  "Validate CLI option SPECS and return them unchanged."
  (unless (listp specs)
    (error ":cli-options must be a list of option spec plists, got ~S" specs))
  (let ((seen-names (make-hash-table :test 'equal))
        (seen-longs (make-hash-table :test 'equal))
        (seen-shorts (make-hash-table :test 'equal)))
    (dolist (spec specs)
      (unless (listp spec)
        (error "CLI option spec must be plist, got ~S" spec))
      (let* ((name (%kw (or (getf spec :name)
                            (error "CLI option spec missing :name in ~S" spec))))
             (long (or (getf spec :long)
                       (error "CLI option ~S missing :long in ~S" name spec)))
             (short (getf spec :short))
             (type (or (getf spec :type) 'string)))
        (unless (member type '(string integer keyword boolean) :test #'eq)
          (error "CLI option ~S has unsupported :type ~S" name type))
        (when (gethash name seen-names)
          (error "Duplicate CLI option :name ~S" name))
        (setf (gethash name seen-names) t)
        (when (gethash long seen-longs)
          (error "Duplicate CLI option :long ~S" long))
        (setf (gethash long seen-longs) t)
        (when short
          (when (gethash short seen-shorts)
            (error "Duplicate CLI option :short ~S" short))
          (setf (gethash short seen-shorts) t))))
    specs))

(defun normalize-binary-options (binary app-name)
  "Normalize :binary setting into a plist, or NIL when disabled."
  (cond
    ((null binary) nil)
    ((eq binary t)
     (list :enabled t
           :name (string-downcase (symbol-name app-name))
           :entry-point (intern (format nil "RUN-~A" app-name))
           :build-operation "program-op"))
    ((listp binary)
     (list* :enabled t binary))
    (t
     (error ":binary must be NIL, T, or plist, got ~S" binary))))

(defun parse-cli-options (specs argv)
  "Parse ARGV according to SPECS and return a plist keyed by :name."
  (let ((values nil))
    ;; defaults/env pass
    (dolist (spec specs)
      (let* ((name (%kw (getf spec :name)))
             (type (or (getf spec :type) 'string))
             (default (getf spec :default :__none__))
             (env (getf spec :env))
             (env-value (and env (getenv env))))
        (cond
          (env-value
           (setf (getf values name) (%coerce-cli-value env-value type name)))
          ((not (eq default :__none__))
           (setf (getf values name) default)))))
    ;; argv pass
    (loop with rest = (or argv '())
          while rest
          do (let ((arg (pop rest)))
               (dolist (spec specs)
                 (let* ((name (%kw (getf spec :name)))
                        (long (getf spec :long))
                        (short (getf spec :short))
                        (type (or (getf spec :type) 'string)))
                   (when (or (and long (string= arg long))
                             (and short (string= arg short)))
                     (if (eq type 'boolean)
                         (setf (getf values name) t)
                         (let ((raw (pop rest)))
                           (unless raw
                             (error "CLI option ~S expects a value" arg))
                           (setf (getf values name)
                                 (%coerce-cli-value raw type name)))))))))
    values))
