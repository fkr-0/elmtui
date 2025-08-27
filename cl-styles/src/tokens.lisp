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
  "Look up variable NAME in VARS (plist, alist, or hash-table).
Returns the value associated with NAME, or nil if not found.
Arguments:
- NAME: The name of the variable to look up (string or symbol).
- VARS: A property list, association list, or hash-table mapping variable names to their values.
Returns:
- The value associated with NAME in VARS, or nil if not found.
Example:
  (let ((vars '((\"--main-color\" . (rgb 255 0 0))
                (\"--padding\" . (px 10)))))
    (%lookup-var \"--main-color\" vars)) ;; Returns: (RGB 255 0 0)"
  (cond
    ((hash-table-p vars) (multiple-value-bind (v p) (gethash name vars) (and p v)))
    ((and (listp vars) (listp (car vars))) ; alist
     (or (cdr (assoc name vars :test #'equal))
         (cdr (assoc (if (stringp name)
                         (intern (string-upcase name) :keyword)
                         (string-downcase (symbol-name name)))
                     vars :test #'equal))))
    ((listp vars)
     (or (getf vars name nil) ;; plist access for name
         (let ((alt
                 (if (stringp name)
                     (intern (string-upcase name) :keyword) ;; string->keyword
                     (string-downcase (symbol-name name))))) ;; symbol->string
           (getf vars alt nil)))) ;; plist access for alt
    (t nil)))
;; (let ((vars '(("--main-color" . (rgb 255 0 0))
;;               ("--padding" . (px 10)))))
;;   (%lookup-var "--main-color" vars))
;; (defun resolve-variables (plist vars)
;;   "Resolve variable references in PLIST using VARS.
;; VARS can be a plist, alist, or hash-table.
;; Returns a new plist with variable references replaced by their values.

;; Arguments:
;; - PLIST: A property list that may contain variable references (e.g., (:color (var \"--main-color\"))).
;; - VARS: A property list, association list, or hash-table mapping variable names to their values.
;; Returns:
;; - A new property list with variable references resolved to their corresponding values from VARS.

;; Example:
;;   (let ((vars '((\"--main-color\" . (rgb 255 0 0))
;;                 (\"--padding\" . (px 10)))))
;;     (resolve-variables '(:color (var \"--main-color\") :padding (var \"--padding\") :margin (px 5)) vars))
;;   ;; Returns: (:color (rgb 255 0 0) :padding (px 10) :margin (px 5))"
;;   (let ((out (copy-list (or plist nil))))
;;     (loop for (k v) on out by #'cddr do
;;       (when (variable-ref-p v)
;;         (let* ((name (second v))
;;                (val (%lookup-var name vars)))
;;           (when val (setf (getf out k) val)))))
;;     out))


;; (let ((vars '((:main-color . (rgb 255 0 0))
;;               (:padding . (px 10)))))
;;   (resolve-variables '(:color (var :main-color) :padding (var :padding) :margin (px 5)) vars))
;;
;; (let ((sheet (cl-styles.sheet:make-stylesheet
;;               :variables '(("--main-color" . :blue)))))
;;   (%normalize-decls '(:color (var "--main-color") :padding 10 :margin (5 10)) sheet))
;; ;; => (:MARGIN-LEFT 10 :MARGIN-RIGHT 10 :MARGIN-BOTTOM 5 :MARGIN-TOP 5 :PADDING-LEFT
;; ;;  10 :PADDING-BOTTOM 10 :PADDING-RIGHT 10 :PADDING-TOP 10 :COLOR
;;  (VAR "--main-color") :PADDING 10 :MARGIN (5 10))
(defun resolve-variables (plist vars)
  "Resolve variable references in PLIST using VARS.

VARS can be a property list, association list, or hash-table mapping variable names to their values.
This function replaces variable references in PLIST (e.g., (:color (var \"--main-color\")))
with their corresponding values from VARS.

Arguments:
- PLIST: A property list that may contain variable references (e.g., (:color (var \"--main-color\"))).
- VARS: A property list, association list, or hash-table mapping variable names to their values.

Returns:
- A new property list with variable references resolved to their corresponding values from VARS.
  If a variable reference cannot be resolved, it is left unchanged.

Example:
  (let ((vars '((\"--main-color\" . (rgb 255 0 0))
                (\"--padding\" . (px 10)))))
    (resolve-variables `(:color ,(var \"--main-color\") :padding ,(var \"--padding\") :margin (px 5)) vars))
  ;; Returns: (:color (rgb 255 0 0) :padding (px 10) :margin (px 5))"
  (cond
    ;; If PLIST is nil, return an empty list.
    ((null plist) nil)
    ;; Otherwise, process the PLIST.
    (t
     (let ((resolved-plist (copy-list plist)))
       (loop for (key value) on resolved-plist by #'cddr do
         (when (variable-ref-p value)
           (let* ((name (second value))
                  (resolved-value (%lookup-var name vars)))
             ;; Replace the variable reference with its resolved value, if found.
             (when resolved-value
               (setf (getf resolved-plist key) resolved-value)))))
       resolved-plist))))
