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
  "Report location only; the checked weighted summary is emitted by the gate."
  (format t "~&SB-COVER report: ~A~%" *coverage-dir*))

(defun primary-source-files ()
  "Return all Lisp source pathnames from the primary ASDF system tree."
  (let ((files nil))
    (labels ((visit (component)
               (typecase component
                 (asdf:cl-source-file
                  (push (asdf:component-pathname component) files))
                 (asdf:module
                  (mapc #'visit (asdf:component-children component))))))
      (visit (asdf:find-system "elmtui")))
    (sort (remove-duplicates files :test #'equal) #'string< :key #'namestring)))

(defun write-primary-inventory ()
  "Publish the ASDF system inventory used to reject coverage denominator drift."
  (let ((files (primary-source-files)))
    (unless files (error "Primary ASDF system yielded no source files"))
    (with-open-file (stream (merge-pathnames "primary-sources.txt" *coverage-dir*)
                      :direction :output :if-exists :supersede)
      (dolist (file files)
        (unless (uiop:string-prefix-p (namestring (truename *root*)) (namestring (truename file)))
          (error "Primary source escapes repository: ~A" file))
        (format stream "~A~%" (enough-namestring (truename file) (truename *root*)))))
    (format t "~&Primary ASDF Lisp sources: ~D~%" (length files))))

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

      ;; Instrumented and ordinary FASLs must not overwrite one another while
      ;; another developer process is compiling the same primary sources.
      ;; Configure this before loading dependencies so they remain uninstrumented.
      (let ((cache (uiop:getenv "ELMTUI_COVERAGE_FASL_DIR")))
        (when cache
          (asdf:initialize-output-translations
           `(:output-translations (t (,cache :implementation))
             :ignore-inherited-configuration))
          (format t "~&;; Isolated coverage FASL cache: ~A~%" cache)))

      ;; Compile/load dependency systems before enabling global SB-COVER.
      ;; A cold CI runner must not instrument bundled libraries incidentally.
      (let ((*package* (find-package :cl-user)))
        (dolist (dependency (asdf:system-depends-on (asdf:find-system "elmtui")))
          (asdf:load-system dependency)))

      ;; Setup
      (setup-coverage)
      (prepare-coverage-directory)
      (sb-cover:clear-coverage)

      ;; ASDF compilation inherits *PACKAGE*. Keep project/test compilation out
      ;; of ELMTUI.COVERAGE so reusable FASLs do not capture this script package.
      ;; Normal ASDF reloads can emit redefinition warnings for already-defined
      ;; generics; these are narrowly muffled rather than hiding other warnings.
      (let ((*package* (find-package :cl-user)))
        (format t "~%;; Loading elmtui with coverage instrumentation...~%")
        (handler-bind ((sb-kernel:redefinition-warning #'muffle-warning))
          (asdf:load-system "elmtui" :force t))

        (write-primary-inventory)

        ;; Tests and optional dependencies are not part of the primary metric.
        (teardown-coverage)

        ;; Load tests without forcing recompilation.
        (format t "~%;; Loading test system...~%")
        (handler-bind ((sb-kernel:redefinition-warning #'muffle-warning))
          (asdf:load-system "elmtui-tests" :force nil)
          ;; E4 coverage-only release regressions are part of the CI coverage gate;
          ;; absence or load error is fatal instead of silently omitting the suite.
          ;; These tests are loaded after instrumentation is disabled.
          (load (merge-pathnames "tests/coverage-release-quality-20261027.lisp" *root*))
          (unless (find-package :elmtui.tests.coverage-release-20261027)
            (error "E4 release quality suite failed to register"))))

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
