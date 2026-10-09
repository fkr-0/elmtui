#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export ELMTUI_DOCSTRING_MAX_MISSING="${ELMTUI_DOCSTRING_MAX_MISSING:-444}"
export ELMTUI_DOCSTRING_STRICT="${ELMTUI_DOCSTRING_STRICT:-0}"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

cat >"$tmp" <<'LISP'
(require :asdf)
(asdf:load-system :elmtui)
(dolist (system '(:cl-events :cl-state :cl-inputs :cl-styles))
  (asdf:load-system system))

(defun prefixp (prefix string)
  (and (<= (length prefix) (length string))
       (string= prefix string :end2 (length prefix))))

(defun interesting-package-p (package)
  (let ((name (package-name package)))
    (some (lambda (prefix) (prefixp prefix name))
          '("ELMTUI" "CL-EVENTS" "CL-STATE" "CL-INPUTS" "CL-STYLES"))))

(defun symbol-kinds (symbol)
  (remove nil
          (list (when (macro-function symbol) :macro)
                (when (and (fboundp symbol) (not (macro-function symbol))) :function)
                (when (boundp symbol) :variable)
                (when (ignore-errors (find-class symbol nil)) :type))))

(defun documented-p (symbol kinds)
  (some (lambda (kind)
          (case kind
            ((:macro :function) (documentation symbol 'function))
            (:variable (documentation symbol 'variable))
            (:type (documentation symbol 'type))))
        kinds))

(let ((seen (make-hash-table :test #'eq))
      (total 0)
      (missing 0)
      (by-home (make-hash-table :test #'equal)))
  (dolist (package (remove-if-not #'interesting-package-p (list-all-packages)))
    (do-external-symbols (symbol package)
      (unless (gethash symbol seen)
        (setf (gethash symbol seen) t)
        (let ((kinds (symbol-kinds symbol)))
          (when kinds
            (incf total)
            (unless (documented-p symbol kinds)
              (incf missing)
              (let* ((home (symbol-package symbol))
                     (name (if home (package-name home) "#:UNINTERNED")))
                (incf (gethash name by-home 0)))))))))
  (let (rows)
    (maphash (lambda (package count) (push (cons package count) rows)) by-home)
    (dolist (row (sort rows #'> :key #'cdr))
      (format t "~4D  ~A~%" (cdr row) (car row))))
  (format t "DOCSTRING-AUDIT unique=~D missing=~D coverage=~,1F%~%"
          total missing (* 100.0 (/ (- total missing) total)))
  (let* ((strict (string= "1" (or (uiop:getenv "ELMTUI_DOCSTRING_STRICT") "0")))
         (max-missing (parse-integer
                       (or (uiop:getenv "ELMTUI_DOCSTRING_MAX_MISSING") "444")))
         (limit (if strict 0 max-missing)))
    (when (> missing limit)
      (format *error-output*
              "Docstring debt regressed: ~D missing, allowed maximum is ~D.~%"
              missing limit)
      (uiop:quit 1))))
LISP

clpm bundle exec --with-client sbcl -- --noinform --script "$tmp"
