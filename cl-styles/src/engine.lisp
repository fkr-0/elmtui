(in-package :cl-styles.engine)

(defstruct style-patch path computed)

(defun %plist-merge! (a b)
  "Destructively merge plist B onto A (B wins)."
  (loop for (k v) on b by #'cddr do
    (setf (getf a k) v))
  a)

(defun %normalize-decls (plist sheet)
  (let* ((expanded (cl-styles.rule:expand-shorthands plist))
         (vars (and sheet (cl-styles.sheet:stylesheet-variables sheet)))
         (resolved (if vars (cl-styles.tokens:resolve-variables expanded vars) expanded))
         (normalized (cl-styles.properties:normalize-declarations resolved)))
    (cl-styles.properties:validate-declarations normalized)))

(defun match-rules (obj sheet)
  (loop for r in (or (and sheet (cl-styles.sheet:stylesheet-rules sheet)) '())
        for sel = (cl-styles.rule:rule-selector r)
        when (cl-styles.selector:match-selector-p sel obj)
          collect (cons r (or (cl-styles.rule:rule-specificity r)
                              (cl-styles.selector:selector-specificity sel)))))



(defun %spec< (a b)
  "Ascending compare for specificity triples (a b c)."
  (or (< (first a) (first b))
      (and (= (first a) (first b)) (< (second a) (second b)))
      (and (= (first a) (first b)) (= (second a) (second b)) (< (third a) (third b)))))



(defparameter *inheritable-keys* '(:color :font-size :font-family :font-weight))

(defun %inherit (parent child)
  (let ((out (copy-list child)))
    (dolist (k *inheritable-keys*)
      (let ((v (getf parent k nil)))
        (when (and (not (getf out k)) v)
          (setf (getf out k) v))))
    out))

(defun compute-style (obj rules &key inherit-from sheet)
  (let* ((inline (or (cl-styles.protocols:stylable-inline-style obj) nil))
         (acc (%normalize-decls (copy-list inline) sheet))
         ;; ASCENDING specificity so highest applies last
         (sorted (sort (copy-list rules) #'%spec< :key #'cdr)))
    (dolist (pr sorted)
      (let* ((rule (car pr))
             (decls (cl-styles.rule:rule-declarations rule)))
        (%plist-merge! acc (%normalize-decls decls sheet))))
    ;; apply inheritance first …
    (when inherit-from
      (setf acc (%inherit inherit-from acc)))
    ;; … then resolve/normalize again so inherited VAR() tokens are resolved
    (%normalize-decls acc sheet)))


(defun inherit-properties (parent child)
  (declare (ignore parent child))
  ;; Placeholder: implement CSS inheritance as needed
  nil)

(defun %apply-node (node sheet return &key (inherit-from nil))
  (let* ((pairs (match-rules node sheet))
         (style (compute-style node pairs :inherit-from inherit-from :sheet sheet))
         (res (cl-styles.protocols:set-computed-style node style)))
    (ecase return
      (:patches (if (typep res 'style-patch)
                    (list res)
                    (list (make-style-patch :path (list :by-key (cl-styles.protocols:stylable-key node))
                                            :computed style))))
      (:objects (list res)))))

(defun apply-stylesheet (sheet objects &key (return :patches))
  (apply #'append (mapcar (lambda (o) (%apply-node o sheet return)) objects)))

(defun apply-stylesheet-to-tree (root sheet &key (return :patches) cache previous-signature)
  (declare (ignore cache previous-signature))
  (labels ((walk (node inherit-style)
             ;; compute + set this node with inherited style from parent
             (let* ((self-patches (%apply-node node sheet return :inherit-from inherit-style))
                    (children (or (cl-styles.protocols:stylable-children node) nil))
                    ;; get what we just computed on NODE and hand it to children
                    (computed-here (cl-styles.protocols:get-computed-style node))
                    (child-patches (mapcan (lambda (c) (walk c computed-here)) children)))
               (append self-patches child-patches))))
    (walk root nil)))
