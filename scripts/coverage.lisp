;;; coverage.lisp - Test coverage analysis for cl-inputs system
;;;
;;; Usage:
;;;   clpm bundle exec --with-client sbcl -- --noinform --load coverage.lisp
;;;
;;; Environment Variables:
;;;   COVERAGE_WHITELIST - Colon-separated list of directories to instrument
;;;                        (default: "src")
;;;   COVERAGE_BLACKLIST - Colon-separated list of directories to exclude
;;;   COVERAGE_DIR       - Output directory (default: "coverage/")

;;; Keep coverage helpers out of COMMON-LISP and project runtime packages.
(require :asdf)
(uiop:define-package :elmtui.coverage
  (:use :cl))
(in-package :elmtui.coverage)

;;; Load SB-COVER before reading package-qualified coverage forms below.
(require :sb-cover)

;;; ----------------------------------------------------------------------------
;;; Configuration
;;; ----------------------------------------------------------------------------

(defvar *root*
  (uiop:pathname-directory-pathname
    (merge-pathnames "../"
      (uiop:pathname-directory-pathname
        (or *load-truename* *compile-file-truename* *default-pathname-defaults*))))
  "Root directory of the project.")

(defvar *coverage-dir*
  (merge-pathnames
    (or (uiop:getenv "COVERAGE_DIR") #p"coverage/")
    *root*)
  "Directory where coverage reports will be generated.")
;;; Clean and create coverage directory
(when (uiop:directory-exists-p *coverage-dir*)
  (uiop:delete-directory-tree *coverage-dir* :validate t :if-does-not-exist :ignore))
(ensure-directories-exist *coverage-dir*)

(defvar *default-whitelist* '("src")
  "Default directories to instrument for coverage (relative to *root*).")

(defvar *default-blacklist* '("tests" "test" "t")
  "Default directories to exclude from coverage instrumentation.")

;;; ----------------------------------------------------------------------------
;;; Utilities
;;; ----------------------------------------------------------------------------

(defun parse-path-list (env-var)
  "Parse a colon-separated list of paths from an environment variable."

  (let ((e-value (uiop:getenv env-var)))
    (when e-value
      (remove-if #'uiop:emptyp
        (uiop:split-string e-value :separator ":")))))

(defun normalize-directory-path (path)
  "Ensure PATH is a directory pathname relative to *root*."
  (uiop:ensure-directory-pathname
    (merge-pathnames path *root*)))

(defun get-coverage-paths ()
  "Return a list of directories to instrument for coverage."
  (let ((whitelist (or (parse-path-list "COVERAGE_WHITELIST")
                     *default-whitelist*))
         (blacklist (or (parse-path-list "COVERAGE_BLACKLIST")
                      *default-blacklist*)))
    (values (mapcar #'normalize-directory-path whitelist)
      (mapcar #'normalize-directory-path blacklist))))

(defun path-matches-any-p (pathname patterns)
  "Check if PATHNAME is under any of the PATTERNS directories."
  (some (lambda (pattern)
          (uiop:subpathp pathname pattern))
    patterns))

(defun coverage-file-p (pathname whitelist blacklist)
  "Determine if PATHNAME should be instrumented for coverage."
  (and (uiop:file-pathname-p pathname)
    (member (pathname-type pathname) '("lisp" "lsp" "cl") :test #'equal)
    (path-matches-any-p pathname whitelist)
    (not (path-matches-any-p pathname blacklist))))

;;; ----------------------------------------------------------------------------
;;; Coverage Instrumentation
;;; ----------------------------------------------------------------------------

(defun setup-coverage ()
  "Initialize code coverage instrumentation."
  (format t "~&~%;; Loading SB-COVER...~%")
  (require :sb-cover)

  (format t ";; Enabling coverage instrumentation...~%")
  (proclaim '(optimize sb-cover:store-coverage-data)))

(defun teardown-coverage ()
  "Disable code coverage instrumentation."
  (proclaim '(optimize (sb-cover:store-coverage-data 0))))

(defun prepare-coverage-directory ()
  "Clean and create the coverage output directory."
  (format t ";; Coverage output: ~A~%" *coverage-dir*)

  (when (uiop:directory-exists-p *coverage-dir*)
    (handler-case
      (uiop:delete-directory-tree *coverage-dir* :validate t)
      (error (e)
        (warn "Failed to clean coverage directory: ~A" e))))

  (ensure-directories-exist *coverage-dir*))

;;; ----------------------------------------------------------------------------
;;; Coverage Reporting
;;; ----------------------------------------------------------------------------
(defun %parse-decimal (str)
  "Parse STR as a decimal float, or return NIL when STR is not a float."
  (handler-case
    (let ((dot-pos (position #\. str)))
      (when dot-pos
        (let ((num (read-from-string str)))
          (and (floatp num) num))))
    (error () nil)))

(defun parse-number (str)
  "Parse STR as an integer or decimal float, returning NIL on invalid input."
  (when str
    (or (ignore-errors (parse-integer str :junk-allowed nil))
        (%parse-decimal str))))

(defun parse-coverage-file (filepath)
  "Extract coverage statistics from an SB-COVER HTML file."
  (with-open-file (stream filepath :direction :input
                    :if-does-not-exist nil)
    (when stream
      (loop for line = (read-line stream nil nil)
        while line
        when (search "Code coverage:" line)
        do (let* ((pct-start (search "(" line))
                   (pct-end (search "%" line)))
             (when (and pct-start pct-end)
               (let ((pct-str (subseq line (1+ pct-start) pct-end)))
                 (return-from parse-coverage-file
                   (ignore-errors (parse-number pct-str))))))))))

(defun generate-ascii-report ()
  "Generate and display an ASCII coverage summary."
  (format t "~&~%=== Coverage Summary ===~%~%")
  (format t "~&~A ~A~%"
    (format nil "~32A" "File")
    (format nil "~10@A" "Coverage"))
  (format t "~&~A~%" (make-string 44 :initial-element #\-))

  (let ((files (uiop:directory-files *coverage-dir* "*.html"))

         (total-coverage 0.0)
         (file-count 0))

    (format t "~&Processing ~A coverage files...~%" (length files))
    (dolist (file (sort files #'string< :key #'pathname-name))
      (let* ((name (pathname-name file))
              (coverage (or (parse-coverage-file file) 0.0)))
        (when (and (not (string= name "cover-index"))
                (plusp coverage))
          (format t "~&~A ~10,1F%~%"
            (format nil "~32A"
              (subseq name 0 (min 32 (length name))))
            coverage)
          (incf total-coverage coverage)
          (incf file-count))))

    (format t "~&~A~%" (make-string 44 :initial-element #\-))
    (when (plusp file-count)
      (format t "~&~A ~10,1F%~%~%"
        (format nil "~32A" "AVERAGE")
        (/ total-coverage file-count)))))

;;; ----------------------------------------------------------------------------
;;; Main Coverage Workflow
;;; ----------------------------------------------------------------------------

(defun run-coverage-analysis ()
  "Execute the complete coverage analysis workflow."
  (handler-case
    (multiple-value-bind (whitelist blacklist)
      (get-coverage-paths)

      (format t "~&~%;; ========================================~%")
      (format t ";; Test Coverage Analysis~%")
      (format t ";; ========================================~%~%")
      (format t ";; Whitelist: ~{~A~^, ~}~%"
        (mapcar #'uiop:native-namestring whitelist))
      (format t ";; Blacklist: ~{~A~^, ~}~%~%"
        (mapcar #'uiop:native-namestring blacklist))

      ;; Setup
      (setup-coverage)
      (prepare-coverage-directory)

      ;; ASDF compilation inherits *PACKAGE*. Keep project/test compilation out
      ;; of ELMTUI.COVERAGE so reusable FASLs do not capture this script package.
      ;; Normal ASDF reloads can emit redefinition warnings for already-defined
      ;; generics; these are narrowly muffled rather than hiding other warnings.
      (let ((*package* (find-package :cl-user)))
        (format t "~%;; Loading elmtui with coverage instrumentation...~%")
        (handler-bind ((sb-kernel:redefinition-warning #'muffle-warning))
          (asdf:load-system "elmtui" :force t))

        ;; Load tests without forcing recompilation.
        (format t "~%;; Loading test system...~%")
        (handler-bind ((sb-kernel:redefinition-warning #'muffle-warning))
          (asdf:load-system "elmtui-tests" :force nil)))

      ;; Run tests
      (format t "~%;; Running test suite...~%~%")
      (let* ((test-pkg (find-package "ELMTUI.TESTS"))
              (test-fn (and test-pkg
                         (find-symbol "RUN-ALL-ELMTUI-TESTS" test-pkg))))
        (unless (and test-fn (fboundp test-fn))
          (error "ELMTUI.TESTS:RUN-ALL-ELMTUI-TESTS is unavailable"))
        (let ((test-result (funcall test-fn)))
          (format t "~&~%;; ========================================~%")
          (format t ";; Generating Coverage Report~%")
          (format t ";; ========================================~%~%")

          ;; Generate HTML report.
          (sb-cover:report *coverage-dir*)
          (let ((index-path (merge-pathnames #p"cover-index.html" *coverage-dir*)))
            (unless (and (uiop:file-exists-p index-path)
                         (plusp (with-open-file (stream index-path :direction :input)
                                  (file-length stream))))
              (error "Coverage report index was not generated: ~A" index-path))

            ;; Generate ASCII summary. Failure is a coverage workflow failure,
            ;; not a warning to be ignored by the command wrapper.
            (generate-ascii-report)
            (format t "~&HTML Report: ~A~%~%" index-path))

          ;; Cleanup
          (teardown-coverage)

          ;; Exit with appropriate code.
          (uiop:quit (if test-result 0 1)))))

    (error (e)
      (format *error-output* "~&ERROR: Coverage analysis failed: ~A~%" e)
      (uiop:quit 2))))

;;; ----------------------------------------------------------------------------
;;; Entry Point
;;; ----------------------------------------------------------------------------

;; Execute when loaded.
(run-coverage-analysis)
