;;;; audit-api-bindings.lisp: report exported ElmTUI symbols with no binding.
;;;;
;;;; A "phantom" export is a symbol an ElmTUI package exports from its own home
;;;; package that names no function, macro, special operator, variable, class
;;;; or type. Callers that use it get an undefined-function/variable error, and
;;;; a same-named working symbol elsewhere is a different identity. The facade
;;;; re-export audit (scripts/audit-facade-exports.py) cannot see these, because
;;;; it only inspects symbols whose home differs from the exporting package.
;;;;
;;;; With ELMTUI_API_PHANTOM_MAX=N set, exit non-zero when more than N
;;;; phantom exports exist (the release gate's ratchet).
;;;;
;;;; Run from the repository root:
;;;;   clpm bundle exec --with-client sbcl -- --noinform --non-interactive \
;;;;     --load scripts/audit-api-bindings.lisp
(require :asdf)
(asdf:load-system :elmtui)

(defpackage :api-binding-audit (:use :cl))
(in-package :api-binding-audit)

(defun binding-kind (symbol)
  (cond ((special-operator-p symbol) :special-operator)
        ((macro-function symbol) :macro)
        ((fboundp symbol) :function)
        ((boundp symbol) :variable)
        ;; DEFVAR without a value: a declared special variable, not a phantom.
        ((eq (sb-int:info :variable :kind symbol) :special) :special-variable)
        ((find-class symbol nil) :class)
        ((ignore-errors (sb-ext:valid-type-specifier-p symbol)) :type)))

(defun elmtui-packages ()
  (sort (remove-if-not (lambda (p) (eql 0 (search "ELMTUI" (package-name p))))
                       (list-all-packages))
        #'string< :key #'package-name))

(let ((total 0) (phantom-total 0) (rows '()))
  (dolist (package (elmtui-packages))
    (let ((own 0) (phantoms '()))
      (do-external-symbols (symbol package)
        (when (eq (symbol-package symbol) package)
          (incf own)
          (unless (binding-kind symbol) (push symbol phantoms))))
      (incf total own)
      (incf phantom-total (length phantoms))
      (when phantoms
        (push (list (package-name package) own
                    (sort (mapcar #'symbol-name phantoms) #'string<))
              rows))))
  (format t "~&API-BINDING-AUDIT packages=~D own-exports=~D phantom=~D in ~D packages~%"
          (length (elmtui-packages)) total phantom-total (length rows))
  (dolist (row (sort rows #'> :key (lambda (r) (length (third r)))))
    (format t "~%~A (~D of ~D own exports unbound):~%  ~{~(~A~)~^ ~}~%"
            (first row) (length (third row)) (second row) (third row)))
  (let ((limit (uiop:getenv "ELMTUI_API_PHANTOM_MAX")))
    (when (and limit (plusp (length limit)))
      (let ((max (parse-integer limit)))
        (when (> phantom-total max)
          (format t "~&API-BINDING-AUDIT FAIL: ~D phantom exports exceed the allowed ~D~%"
                  phantom-total max)
          (uiop:quit 1))
        (format t "~&API-BINDING-AUDIT PASS: ~D phantom exports (allowed ~D)~%"
                phantom-total max)))))
