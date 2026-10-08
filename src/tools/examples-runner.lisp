;;; src/tools/examples-runner.lisp
;;; CLI tool to list, run, or dump binaries for examples/*.lisp entries.

(uiop:define-package :elmtui.examples.runner
  (:use :cl)
  (:import-from :asdf #:find-system #:load-system #:system-source-directory)
  (:import-from :uiop
                #:command-line-arguments
                #:directory-files
                #:ensure-pathname
                #:file-exists-p
                #:quit
                #:split-string)
  (:export #:main
           #:normalize-example-name
           #:list-implemented-examples
           #:%resolve-example-file
           #:%default-output-path))

(in-package :elmtui.examples.runner)

(defun %project-root ()
  (system-source-directory (find-system "elmtui")))

(defun %examples-dir ()
  (merge-pathnames #P"examples/" (%project-root)))

(defun %truthy-env-p (name)
  (member (string-downcase (or (uiop:getenv name) ""))
          '("1" "true" "yes" "on")
          :test #'string=))

(defun %configure-cli-logging ()
  "Reduce log chatter for normal example usage.
Set ELMTUI_VERBOSE_LOGS=1 to keep info/debug output."
  (unless (%truthy-env-p "ELMTUI_VERBOSE_LOGS")
    (handler-case
        (log4cl:log-config :warn :clear)
      (error () nil))))

(defun %binary-log-path ()
  "Return <binary-name>.log for the currently running executable."
  (let* ((argv0 #+sbcl (or (first sb-ext:*posix-argv*) "example")
                #-sbcl "example")
         (pn (uiop:ensure-pathname argv0)))
    (uiop:ensure-pathname
     (concatenate 'string
                  (or (pathname-name pn) "example")
                  ".log")
     :defaults (or (ignore-errors (truename "."))
                   #P"./"))))

(defun %configure-binary-logging ()
  "Configure root logger to append to <binary-name>.log at DEBUG level."
  (handler-case
      (let* ((log-file (%binary-log-path))
             (file-appender (make-instance 'log4cl:file-appender :file log-file))
             (level (if (%truthy-env-p "ELMTUI_VERBOSE_LOGS") :debug :warn)))
        (log4cl:remove-all-appenders log4cl:*root-logger*)
        (log4cl:add-appender log4cl:*root-logger* file-appender)
        (log4cl:set-log-level log4cl:*root-logger* level)
        (log4cl:log-info "binary logging initialized: ~A (level ~A)" log-file level))
    (error (e)
      (format *error-output* "warning: failed to initialize binary logging: ~A~%" e))))

(defun normalize-example-name (name)
  (let* ((text (string-downcase (string name)))
         (suffix ".lisp"))
    (if (and (>= (length text) (length suffix))
             (string= suffix text
                      :start1 0
                      :end1 (length suffix)
                      :start2 (- (length text) (length suffix))
                      :end2 (length text)))
        (subseq text 0 (- (length text) (length suffix)))
        text)))

(defun list-implemented-examples ()
  (sort (loop for file in (directory-files (%examples-dir) "*.lisp")
              collect (normalize-example-name (pathname-name file)))
        #'string<))

(defun %resolve-example-file (example-name)
  (let* ((normalized (normalize-example-name example-name))
         (candidate (merge-pathnames
                     (make-pathname :name normalized :type "lisp")
                     (%examples-dir))))
    (unless (file-exists-p candidate)
      (error "Unknown example ~S. Available examples:~%  ~{~A~^, ~}"
             example-name (list-implemented-examples)))
    candidate))

(defun %default-output-path (example-name)
  (let ((normalized (normalize-example-name example-name)))
    (merge-pathnames (make-pathname :name normalized :type nil)
                     (truename "."))))

(defun %read-example-package-designator (example-file)
  (with-open-file (in example-file :direction :input)
    (loop for form = (read in nil :eof)
          until (eq form :eof)
          do (when (and (consp form)
                        (symbolp (first form))
                        (string= (symbol-name (first form)) "DEFINE-PACKAGE")
                        (let ((pkg (symbol-package (first form))))
                          (and pkg (string= (package-name pkg) "UIOP/PACKAGE"))))
               (return (second form)))
          finally (error "Could not find uiop:define-package form in ~A" example-file))))

(defun %string-prefix-p (prefix value)
  (and (<= (length prefix) (length value))
       (string= prefix value :end2 (length prefix))))

(defun %string-suffix-p (suffix value)
  (let ((ls (length suffix))
        (lv (length value)))
    (and (<= ls lv)
         (string= suffix value :start1 0 :end1 ls :start2 (- lv ls) :end2 lv))))

(defun %strip-suffix (value suffix)
  (if (%string-suffix-p suffix value)
      (subseq value 0 (- (length value) (length suffix)))
      value))

(defun %package-name-string (package-designator)
  (string-upcase
   (typecase package-designator
     (package (package-name package-designator))
     (t (string package-designator)))))

(defun %name-tokens (name)
  (remove-if (lambda (s) (zerop (length s)))
             (split-string (string-downcase name) :separator '(#\- #\_))))

(defun %token-overlap-score (example-name symbol-name)
  (let* ((example-tokens (%name-tokens example-name))
         (symbol-tokens (%name-tokens symbol-name)))
    (loop for tok in example-tokens
          count (member tok symbol-tokens :test #'string=))))

(defun %best-token-matching-entry (run-syms example-name)
  (let ((best nil)
        (best-score 0))
    (dolist (sym run-syms best)
      (let ((score (%token-overlap-score example-name (symbol-name sym))))
        (when (> score best-score)
          (setf best sym
                best-score score))))))

(defun %entry-name-candidates (example-name)
  (let* ((normalized (string-upcase (normalize-example-name example-name)))
         (base (substitute #\- #\_ normalized))
         (without-real (%strip-suffix base "-REAL")))
    (remove-duplicates
     (remove nil
             (list (format nil "RUN-~A" base)
                   (format nil "RUN-~A-APP" base)
                   (unless (string= without-real base)
                     (format nil "RUN-~A" without-real))
                   (unless (string= without-real base)
                     (format nil "RUN-~A-APP" without-real))
                   "RUN"
                   "MAIN"))
     :test #'string=)))

(defun %collect-run-like-symbols (package)
  (let* ((pkg-name (%package-name-string package))
         (out '()))
    (do-symbols (sym package (nreverse out))
      (when (and (let ((owner (symbol-package sym)))
                   (and owner (string= (package-name owner) pkg-name)))
                 (fboundp sym)
                 (let ((name (symbol-name sym)))
                   (or (string= name "MAIN")
                       (string= name "RUN")
                       (%string-prefix-p "RUN-" name))))
        (push sym out)))))

(defun %package-function-by-name (package-designator candidate)
  "Return function symbol named CANDIDATE in PACKAGE-DESIGNATOR, or NIL."
  (let ((wanted (string-upcase candidate)))
    (do-symbols (sym package-designator nil)
      (when (and (fboundp sym)
                 (string= (symbol-name sym) wanted))
        (return sym)))))

(defun %resolve-entry-symbol (package-designator example-name)
  (or (loop for candidate in (%entry-name-candidates example-name)
            for sym = (%package-function-by-name package-designator candidate)
            when (and sym (fboundp sym))
              return sym)
      (let* ((run-syms (%collect-run-like-symbols package-designator))
             (stem (string-upcase (normalize-example-name example-name)))
             (stem-hyphen (substitute #\- #\_ stem))
             (scored (find-if (lambda (sym)
                                (search stem-hyphen (symbol-name sym)))
                              run-syms))
             (token-best (%best-token-matching-entry run-syms example-name)))
        (or scored
            token-best
            (when (= 1 (length run-syms))
              (first run-syms))
            (error "Could not resolve entry function for ~A in package ~A. Candidates seen: ~{~A~^, ~}"
                   example-name
                   package-designator
                   (mapcar #'symbol-name run-syms))))))

(defun %load-example-file (example-file)
  (load-system "elmtui")
  (when (string-equal "fzy-picker" (pathname-name example-file))
    (handler-case
        (load-system "cl-fzy")
      (error (condition)
        (error "The fzy-picker example requires the optional cl-fzy system: ~A"
               condition))))
  (load example-file))

(defun %parse-backend-type (value)
  (let* ((raw (string value))
         (trimmed (if (and (> (length raw) 0) (char= (char raw 0) #\:))
                      (subseq raw 1)
                      raw))
         (name (string-upcase trimmed)))
    (unless (> (length name) 0)
      (error "Backend name cannot be empty"))
    (intern name "KEYWORD")))

(defun %backend-dispatch-program-error-p (condition)
  (let ((msg (string-downcase (format nil "~A" condition))))
    (or (search "keyword argument" msg)
        (search "invalid number of arguments" msg)
        (search "too many arguments" msg)
        (search "too few arguments" msg))))

(defun %invoke-entry (entry &key backend-type)
  (let ((fn (symbol-function entry)))
    (if backend-type
        (handler-case
            (funcall fn :backend-type backend-type)
          (program-error (e)
            (if (%backend-dispatch-program-error-p e)
                (funcall fn)
                (error e))))
        (funcall fn))))

(defun %parse-command-options (args &key allow-output)
  (let ((backend-type nil)
        (output-path nil))
    (loop while args do
      (let ((arg (pop args)))
        (cond
          ((string= arg "--backend")
           (unless args
             (error "Missing value for --backend"))
           (setf backend-type (%parse-backend-type (pop args))))
          ((%string-prefix-p "--backend=" arg)
           (setf backend-type (%parse-backend-type (subseq arg (length "--backend=")))))
          ((and allow-output
                (null output-path)
                (not (%string-prefix-p "--" arg)))
           (setf output-path arg))
          (t
           (error "Unknown option or argument: ~A" arg)))))
    (list :backend-type backend-type
          :output-path output-path)))

(defun run-example (example-name &key backend-type)
  (let* ((example-file (%resolve-example-file example-name))
         (_ (%load-example-file example-file))
         (package-designator (%read-example-package-designator example-file)))
    (declare (ignore _))
    (let ((entry (%resolve-entry-symbol package-designator example-name)))
      (%invoke-entry entry :backend-type backend-type))))

(defun build-example-binary (example-name &key output-path backend-type)
  #+sbcl
  (let* ((example-file (%resolve-example-file example-name))
         (_ (%load-example-file example-file))
         (package-designator (%read-example-package-designator example-file))
         (entry (%resolve-entry-symbol package-designator example-name))
         (output (ensure-pathname (or output-path (%default-output-path example-name)))))
    (declare (ignore _))
    (format t "Dumping ~A to ~A using ~A::~A~@[ (backend ~A)~]~%"
            (normalize-example-name example-name)
            output
            package-designator
            (symbol-name entry)
            backend-type)
    (finish-output)
    (sb-ext:save-lisp-and-die (namestring output)
                              :toplevel (let ((entry entry)
                                              (backend-type backend-type))
                                          (lambda ()
                                            (%configure-binary-logging)
                                            (%invoke-entry entry :backend-type backend-type)))
                              :executable t
                              :compression 9))
  #-sbcl
  (error "Binary dumping is currently supported only on SBCL."))

(defun print-usage (&optional (stream *standard-output*))
  (format stream
          "Usage: examples.sh <command> [args]~%~%~
Commands:~%~
  list~%~
      List implemented examples (without .lisp suffix).~%~
  run <example-name|example-name.lisp>~%~
      Run the selected example. Optional: --backend <keyword>.~%~
  build <example-name|example-name.lisp> [output-path] [--backend <keyword>]~%~
      Dump a standalone binary for the selected example.~%"))

(defun main (&optional (argv (command-line-arguments)))
  (%configure-cli-logging)
  (handler-case
      (progn
        (when (or (null argv)
                  (member (first argv) '("-h" "--help") :test #'string=))
          (print-usage)
          (quit 0))
        (let ((cmd (first argv)))
          (cond
            ((string= cmd "list")
             (dolist (name (list-implemented-examples))
               (format t "~A~%" name))
             (quit 0))
            ((string= cmd "run")
             (unless (second argv)
               (error "Missing example name for run command"))
             (let* ((opts (%parse-command-options (cddr argv) :allow-output nil))
                    (backend-type (getf opts :backend-type)))
               (run-example (second argv) :backend-type backend-type))
             (quit 0))
            ((string= cmd "build")
             (unless (second argv)
               (error "Missing example name for build command"))
             (let* ((opts (%parse-command-options (cddr argv) :allow-output t))
                    (backend-type (getf opts :backend-type))
                    (output-path (getf opts :output-path)))
               (build-example-binary (second argv)
                                     :output-path output-path
                                     :backend-type backend-type))
             (quit 0))
            (t
             (error "Unknown command: ~A" cmd)))))
    (error (e)
      (format *error-output* "examples.sh error: ~A~%" e)
      (print-usage *error-output*)
      (quit 2))))
