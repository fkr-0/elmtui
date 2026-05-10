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
   #:normalize-simple-args-specs
   #:merge-cli-option-specs
   #:normalize-binary-options
   #:parse-cli-options
   #:extract-platform-options))

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

(defun %boolean-token-p (raw)
  (or (string= raw "1")
      (string= raw "0")
      (string-equal raw "true")
      (string-equal raw "false")
      (string-equal raw "yes")
      (string-equal raw "no")))

(defun %long-option-p (x)
  (and (stringp x)
       (>= (length x) 3)
       (string= x "--" :end1 2 :end2 2)))

(defun %short-option-p (x)
  (and (stringp x)
       (= (length x) 2)
       (char= (char x 0) #\-)
       (alpha-char-p (char x 1))))

(defun %value-compatible-p (value type)
  (case type
    ((string) (stringp value))
    ((integer) (integerp value))
    ((keyword) (keywordp value))
    ((boolean) (or (null value) (eq value t)))
    (t nil)))

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
             (type (or (getf spec :type) 'string))
             (default (getf spec :default :__none__)))
        (unless (member type '(string integer keyword boolean) :test #'eq)
          (error "CLI option ~S has unsupported :type ~S" name type))
        (unless (%long-option-p long)
          (error "CLI option ~S has invalid :long ~S (expected --name form)" name long))
        (when short
          (unless (%short-option-p short)
            (error "CLI option ~S has invalid :short ~S (expected -x form)" name short)))
        (when (and (not (eq default :__none__))
                   (not (%value-compatible-p default type)))
          (error "CLI option ~S default ~S incompatible with type ~S" name default type))
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

(defun normalize-simple-args-specs (args)
  "Normalize :args simple specs into internal CLI option specs."
  (unless (listp args)
    (error ":args must be a list of arg spec plists, got ~S" args))
  (let ((normalized
          (mapcar
           (lambda (spec)
             (unless (listp spec)
               (error ":args entry must be plist, got ~S" spec))
             (let* ((name (%kw (or (getf spec :name)
                                   (error ":args spec missing :name in ~S" spec))))
                    (long (or (getf spec :long)
                              (error ":args spec ~S missing :long in ~S" name spec)))
                    (short (getf spec :short))
                    (type (or (getf spec :type)
                              (error ":args spec ~S missing :type in ~S" name spec))))
               (list :name name
                     :long long
                     :short short
                     :type type
                     :default (getf spec :default :__none__)
                     :env (getf spec :env)
                     :doc (getf spec :doc)
                     ;; :args are app-level by default; do not auto-forward to platform.
                     :platform-option nil)))
           args)))
    ;; Remove :default sentinel for cleaner runtime specs.
    (dolist (spec normalized)
      (when (eq (getf spec :default :__none__) :__none__)
        (remf spec :default)))
    (validate-cli-option-specs normalized)))

(defun merge-cli-option-specs (raw-cli-options raw-simple-args)
  "Merge :cli-options and :args into one validated option spec list."
  (let* ((cli-options (or raw-cli-options '()))
         (simple-args (or raw-simple-args '()))
         (merged (append cli-options simple-args)))
    (validate-cli-option-specs merged)))

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
          do (let* ((arg (pop rest))
                    (spec (find-if
                           (lambda (s)
                             (or (and (getf s :long) (string= arg (getf s :long)))
                                 (and (getf s :short) (string= arg (getf s :short)))))
                           specs)))
               (when spec
                 (let* ((name (%kw (getf spec :name)))
                        (type (or (getf spec :type) 'string)))
                   (if (eq type 'boolean)
                       (let ((raw (first rest)))
                         (if (and raw (%boolean-token-p raw))
                             (progn
                               (pop rest)
                               (setf (getf values name)
                                     (%coerce-cli-value raw type name)))
                             (setf (getf values name) t)))
                       (let ((raw (pop rest)))
                         (unless raw
                           (error "CLI option ~S expects a value" arg))
                         (setf (getf values name)
                               (%coerce-cli-value raw type name))))))))
    values))

(defun extract-platform-options (specs parsed-values)
  "Select options marked with :platform-option from PARSED-VALUES."
  (let ((result nil))
    (dolist (spec specs)
      (when (getf spec :platform-option)
        (let* ((name (%kw (getf spec :name)))
               (tail (member name parsed-values :test #'eq)))
          (when tail
            (setf (getf result name) (second tail))))))
    result))
