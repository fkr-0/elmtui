(in-package :cl-styles.tokens)

;; Colors
(defun rgb  (r g b)  (list :rgb r g b))
(defun rgba (r g b a) (list :rgba r g b a))
(defun hsl  (h s l)  (list :hsl h s l))
(defun color-p (x) (and (consp x) (member (first x) '(:rgb :rgba :hsl))))

;; Lengths
(defun px (n)       (list :px n))
(defun percent (n)  (list :percent n))
(defun em (n)       (list :em n))
(defun root-em (n)  (list :rem n))
(defun ch (n)       (list :ch n))
(defun len (n unit) (list unit n))
(defun length-p (x) (and (consp x) (member (first x) '(:px :percent :em :rem :ch))))

;; Variables
(defun var (name) (list :var name))
(defun variable-ref-p (x) (and (consp x) (eql (first x) :var)))

;; Resolve variable refs in a plist using VARS (plist or alist or hash-table)
(defun %lookup-var (name vars)
  (cond
    ((hash-table-p vars) (multiple-value-bind (v p) (gethash name vars) (and p v)))
    ((and (listp vars) (listp (car vars))) ; alist
     (or (cdr (assoc name vars :test #'equal))
         (cdr (assoc (if (stringp name) (intern (string-upcase name) :keyword) (string-downcase (symbol-name name))) vars :test #'equal))))
    ((listp vars) (or (getf vars name nil)
                      (let ((alt (if (stringp name) (intern (string-upcase name) :keyword)
                                   (string-downcase (symbol-name name)))))
                        (getf vars alt nil))))
    (t nil)))

(defun resolve-variables (plist vars)
  (let ((out (copy-list (or plist nil))))
    (loop for (k v) on out by #'cddr do
          (when (variable-ref-p v)
            (let* ((name (second v))
                   (val (%lookup-var name vars)))
              (when val (setf (getf out k) val)))))
    out))
