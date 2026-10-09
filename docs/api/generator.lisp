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
  "Return canonical, exported, de-duplicated metadata for the live public API.

The :PACKAGE is always an actual exporting package, so PACKAGE:SYMBOL resolves
with the normal single-colon syntax. :HOME-PACKAGE records the defining
symbol's home when it differs. Re-exports are de-duplicated by identity."
  (let ((seen (make-hash-table :test #'eq))
        (bindings nil)
        (packages (sort (remove-if-not #'%interesting-package-p
                                       (list-all-packages))
                        #'string< :key #'package-name)))
    (dolist (package packages)
      (do-external-symbols (symbol package)
        (unless (gethash symbol seen)
          (setf (gethash symbol seen) t)
          (let ((kinds (%binding-kinds symbol)))
            (when kinds
              (let* ((home (symbol-package symbol))
                     (publisher (if (and home (%interesting-package-p home)
                                         (eq (nth-value 1 (find-symbol
                                            (symbol-name symbol) home)) :external))
                                    home package)))
                (push (list :symbol symbol
                            :package (package-name publisher)
                            :home-package (and home (package-name home))
                            :kinds kinds
                            :documentation (%binding-documentation symbol kinds))
                      bindings)))))))
    (sort bindings
          (lambda (left right)
            (let ((a (getf left :package))
                  (b (getf right :package)))
              (or (string< a b)
                  (and (string= a b)
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

(defun %normalized-docstring (doc)
  "Remove insignificant end-of-line whitespace from rendered docstrings."
  (format nil "~{~A~^~%~}"
          (mapcar (lambda (line)
                    (string-right-trim '(#\Space #\Tab #\Return) line))
                  (uiop:split-string doc :separator '(#\Newline)))))

(defun build-api-docs (&key
                         (directory
                           (asdf:system-relative-pathname
                            :elmtui-docs "docs/api/generated/")))
  "Write live-symbol Markdown and HTML references with public export paths.

Returns two values: API Markdown and HTML paths. The documents explicitly
report missing metadata, and document text is fenced/escaped as literal text."
  (let* ((directory (uiop:ensure-directory-pathname directory))
         (markdown (merge-pathnames "api.md" directory))
         (html (merge-pathnames "api.html" directory))
         (bindings (public-api-bindings))
         (last-binding (car (last bindings)))
         (total (length bindings))
         (missing (count-if-not (lambda (entry) (getf entry :documentation))
                                bindings)))
    (ensure-directories-exist markdown)
    (with-open-file (stream markdown
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
      (format stream "# ElmTUI API Reference~%~%")
      (format stream "Generated from live Common Lisp DOCUMENTATION metadata.~%~%")
      (format stream "**Scope:** exported, live bindings in ElmTUI and its CL-EVENTS, CL-STATE, CL-INPUTS, CL-STYLES support packages. Re-exports appear once; each qualified name uses an exporting package.~%~%")
      (format stream "**Coverage:** ~D of ~D bindings documented; ~D have no metadata (~,1F% documented). Missing entries are intentionally shown, not silently omitted.~%~%"
              (- total missing) total missing
              (if (zerop total) 100.0 (* 100.0 (/ (- total missing) total))))
      (dolist (entry bindings)
        (format stream "## ~A:~A~%~%" (getf entry :package)
                (symbol-name (getf entry :symbol)))
        (format stream "Kinds: ~{~(~A~)~^, ~}~%~%" (getf entry :kinds))
        (let ((doc (and (getf entry :documentation)
                               (%normalized-docstring (getf entry :documentation)))))
          (if doc
              (let ((fence "```"))
                (loop while (search fence doc)
                      do (setf fence (concatenate 'string fence "`")))
                (format stream "~Atext~%~A~%~A~%~@[~%~]"
                        fence doc fence (not (eq entry last-binding))))
              (format stream "_No documentation metadata._~%~@[~%~]"
                      (not (eq entry last-binding)))))))
    (with-open-file (stream html
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
      (write-string "<!doctype html><html lang='en'><head><meta charset='utf-8'><title>ElmTUI API</title></head><body>" stream)
      (format stream "<h1>ElmTUI API Reference</h1><p>~D of ~D bindings documented; ~D missing documentation metadata.</p>"
              (- total missing) total missing)
      (dolist (entry bindings)
        (format stream "<section><h2>~A:~A</h2><p>Kinds: ~{~(~A~)~^, ~}</p><pre>~A</pre></section>"
                (%html-escape (getf entry :package))
                (%html-escape (symbol-name (getf entry :symbol)))
                (getf entry :kinds)
                (%html-escape (or (and (getf entry :documentation)
                                        (%normalized-docstring (getf entry :documentation)))
                                  "No documentation metadata."))))
      (write-string "</body></html>" stream))
    (values markdown html)))