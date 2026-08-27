(in-package :elmtui.docs)

(defparameter *api-prefixes*
  '("ELMTUI" "CL-EVENTS" "CL-STATE" "CL-INPUTS" "CL-STYLES")
  "Package-name prefixes included in generated ElmTUI API documentation.")

(defun %prefixp (prefix string)
  (and (<= (length prefix) (length string))
       (string= prefix string :end2 (length prefix))))

(defun %interesting-package-p (package)
  (let ((name (package-name package)))
    (some (lambda (prefix) (%prefixp prefix name)) *api-prefixes*)))

(defun %binding-kinds (symbol)
  (remove nil
          (list (when (macro-function symbol) :macro)
                (when (and (fboundp symbol) (not (macro-function symbol)))
                  :function)
                (when (boundp symbol) :variable)
                (when (ignore-errors (find-class symbol nil)) :type))))

(defun %binding-documentation (symbol kinds)
  (or (when (intersection kinds '(:macro :function))
        (documentation symbol 'function))
      (when (member :variable kinds)
        (documentation symbol 'variable))
      (when (member :type kinds)
        (documentation symbol 'type))))

(defun public-api-bindings ()
  "Return de-duplicated metadata for exported ElmTUI and sublibrary bindings.

Arguments:
  None.

Returns:
  A fresh list of plists. Each plist contains :SYMBOL, :PACKAGE, :KINDS, and
  :DOCUMENTATION. Re-exported symbols occur once, keyed by symbol identity.

Mutation:
  Allocates result data and an internal hash table; project packages and symbols
  are not modified.

Conditions:
  Documentation methods supplied by implementation extensions may signal; such
  failures are not suppressed except for FIND-CLASS probes used for kind
  detection.

Example:
  (remove-if-not (lambda (entry) (getf entry :documentation))
                 (public-api-bindings))"
  (let ((seen (make-hash-table :test #'eq))
        (bindings nil))
    (dolist (package (remove-if-not #'%interesting-package-p
                                    (list-all-packages)))
      (do-external-symbols (symbol package)
        (unless (gethash symbol seen)
          (setf (gethash symbol seen) t)
          (let ((kinds (%binding-kinds symbol)))
            (when kinds
              (let ((home (or (symbol-package symbol) package)))
                (push (list :symbol symbol
                            :package (package-name home)
                            :kinds kinds
                            :documentation (%binding-documentation symbol kinds))
                      bindings)))))))
    (sort bindings
          (lambda (left right)
            (let ((left-package (getf left :package))
                  (right-package (getf right :package)))
              (or (string< left-package right-package)
                  (and (string= left-package right-package)
                       (string< (symbol-name (getf left :symbol))
                                (symbol-name (getf right :symbol))))))))))

(defun docstring-audit ()
  "Return current public API documentation coverage.

Arguments:
  None.

Returns:
  Three values: total public bindings, bindings without documentation metadata,
  and a fresh alist mapping home package names to missing counts.

Mutation:
  None outside temporary result allocation.

Conditions:
  Propagates conditions from PUBLIC-API-BINDINGS.

Example:
  (multiple-value-bind (total missing packages) (docstring-audit)
    (format t \"~D of ~D missing: ~S~%\" missing total packages))"
  (let* ((bindings (public-api-bindings))
         (missing (remove-if (lambda (entry) (getf entry :documentation)) bindings))
         (counts (make-hash-table :test #'equal)))
    (dolist (entry missing)
      (incf (gethash (getf entry :package) counts 0)))
    (let (packages)
      (maphash (lambda (package count) (push (cons package count) packages)) counts)
      (values (length bindings)
              (length missing)
              (sort packages #'> :key #'cdr)))))

(defun %html-escape (value)
  (with-output-to-string (stream)
    (loop for char across (princ-to-string value)
          do (case char
               (#\& (write-string "&amp;" stream))
               (#\< (write-string "&lt;" stream))
               (#\> (write-string "&gt;" stream))
               (#\" (write-string "&quot;" stream))
               (t (write-char char stream))))))

(defun build-api-docs (&key
                         (directory
                           (asdf:system-relative-pathname
                            :elmtui-docs "docs/api/generated/")))
  "Render Markdown and HTML API references from live Common Lisp docstrings.

Arguments:
  DIRECTORY is a pathname designator for generated files. It defaults to
  docs/api/generated/ inside the ELMTUI-DOCS system.

Returns:
  Two values: the API Markdown pathname and the API HTML pathname.

Mutation:
  Creates DIRECTORY as needed and overwrites api.md and api.html. Runtime
  packages, application state, and source files are not modified.

Conditions:
  File-system errors and documentation lookup errors propagate normally so CI
  and interactive debuggers retain the original condition.

Example:
  (asdf:load-system :elmtui-docs)
  (elmtui.docs:build-api-docs)"
  (let* ((directory (uiop:ensure-directory-pathname directory))
         (markdown (merge-pathnames "api.md" directory))
         (html (merge-pathnames "api.html" directory))
         (bindings (public-api-bindings)))
    (ensure-directories-exist markdown)
    (with-open-file (stream markdown
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
      (format stream "# ElmTUI API Reference~%~%")
      (format stream "Generated from live Common Lisp DOCUMENTATION metadata.~%~%")
      (dolist (entry bindings)
        (format stream "## ~A::~A~%~%" (getf entry :package)
                (symbol-name (getf entry :symbol)))
        (format stream "Kinds: ~{~(~A~)~^, ~}~%~%" (getf entry :kinds))
        (let ((doc (getf entry :documentation)))
          (if doc
              (format stream "~A~%~%" doc)
              (format stream "_No documentation metadata._~%~%")))))
    (with-open-file (stream html
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
      (write-string "<!doctype html><html><head><meta charset='utf-8'><title>ElmTUI API</title></head><body>" stream)
      (write-string "<h1>ElmTUI API Reference</h1><p>Generated from live Common Lisp DOCUMENTATION metadata.</p>" stream)
      (dolist (entry bindings)
        (format stream "<section><h2>~A::~A</h2><p>Kinds: ~{~(~A~)~^, ~}</p><pre>~A</pre></section>"
                (%html-escape (getf entry :package))
                (%html-escape (symbol-name (getf entry :symbol)))
                (getf entry :kinds)
                (%html-escape (or (getf entry :documentation)
                                  "No documentation metadata."))))
      (write-string "</body></html>" stream))
    (values markdown html)))
