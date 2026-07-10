(in-package :cl-styles.engine)

(defstruct style-patch path computed)

(defun %plist-merge (a b)
  "Non Destructively merge plist B onto A (B wins).

Returns merged list, a is not modified.

Example:
 (let ((a '(:color :red :width 10))
       (b '(:width 20 :height 30)))
   (list (%plist-merge a b) a b))
  => ((:COLOR :RED :WIDTH 20 :HEIGHT 30)
(:COLOR :RED :WIDTH 10)
(:WIDTH 20 :HEIGHT 30))"
   (loop for (k v) on b by #'cddr
         do (setf (getf a k) v))
   (copy-list a))
;; (let* ((a '(:color :red :width 10))
;;        (b '(:width 20 :height 30))
;;        (x (list a b))
;;        (y (%plist-merge a b)))
;;    (list y a b x))

;; (defun %normalize-decls (plist sheet)
;;   "Normalize and validate declarations in PLIST, using SHEET for variable resolution.
;; Returns normalized and validated plist.
;; Arguments:
;;  PLIST  A property list of declarations.
;;  SHEET  (optional) A cl-styles.sheet:stylesheet object for variable resolution.
;; Example:
;;  (let ((sheet (cl-styles.sheet:make-stylesheet
;;                 :variables '((\"--main-color\" . :blue)))))
;;    (%normalize-decls '(:color (var \"--main-color\") :padding 10 :margin (5 10)) sheet))
;;  => (:COLOR :BLUE :PADDING 10 :MARGIN (5 10))"
;;   (let* ((expanded (cl-styles.rule:expand-shorthands plist))
;;          (vars (and sheet (cl-styles.sheet:stylesheet-variables sheet)))
;;          (resolved (if vars (cl-styles.tokens:resolve-variables expanded vars) expanded))
;;          (normalized (cl-styles.properties:normalize-declarations resolved)))
;;     (cl-styles.properties:validate-declarations normalized)))
(defun %normalize-decls (plist &optional sheet)
  "Normalize and validate declarations in PLIST, using SHEET for variable resolution.

Arguments:
 PLIST  A property list of declarations.
 SHEET  (optional) A cl-styles.sheet:stylesheet object for variable resolution.

Returns:
 A normalized and validated property list.

Example:
 (let ((sheet (cl-styles.sheet:make-stylesheet
                :variables '((\"--font-family\" . \"Arial\")
                             (\"--main-color\" . :blue)))))
   (%normalize-decls (list :color (var \"--main-color\") :padding 10 :margin '(5 10)) sheet))
 => (:COLOR :BLUE :PADDING 10 :MARGIN (5 10))

If SHEET is nil or does not contain variables, variable resolution is skipped."
  (let* ((expanded-shorthands (cl-styles.rule:expand-shorthands plist))
         (vars (and sheet (cl-styles.sheet:stylesheet-variables sheet)))
         (resolved-vars (if vars
                            (cl-styles.tokens:resolve-variables expanded-shorthands vars)
                            expanded-shorthands))
         (normalized-decls (cl-styles.properties:normalize-declarations resolved-vars)))
    (cl-styles.properties:validate-declarations normalized-decls)))
;; (let ((sheet (cl-styles.sheet:make-stylesheet
;;                 :variables '(("--font-family" . "Arial")
;;                              ("--main-color" . :blue)))))
;;    (%normalize-decls (list :color (var "--main-color") :padding 10 :margin '(5 10) :font-family (var "--font-family")) sheet))
;; (let ((sheet (cl-styles.sheet:make-stylesheet
;;                 :variables '(("--main-color" . :blue)))))
;;    (%normalize-decls (list :color (var "--main-color") :padding 10 :margin '(5 10)) sheet))


(defun match-rules (obj sheet)
  (loop for r in (or (and sheet (cl-styles.sheet:stylesheet-rules sheet)) )
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
  "Inherit inheritable properties from PARENT to CHILD if not already set in CHILD.
Returns a new plist with inherited properties applied.
Arguments:
 PARENT  A plist of parent styles.
 CHILD   A plist of child styles.
Example:
 (let ((parent '(:color :red :font-size 12 :margin 5))
       (child '(:font-size 14 :padding 10)))
   (%inherit parent child))
 => (:FONT-SIZE 14 :PADDING 10 :COLOR :RED)"
  (let ((out (copy-list child)))
    (dolist (k *inheritable-keys*)
      (let ((v (getf parent k nil)))
        (when (and (not (getf out k)) v)
          (setf (getf out k) v))))
    out))

(defun compute-style (obj rules &key (inherit-from nil) (sheet nil))
  "Compute the final style for OBJ given matching RULES, optional INHERIT-FROM style and SHEET for variable resolution.

Computation order:
 1. Start with inline styles from OBJ.
 2. Apply RULES in order of ascending specificity (later rules override earlier ones).
 3. Apply INHERIT-FROM styles for inheritable properties if not already set.
 4. Resolve variables using SHEET's variables if provided.
 5. Normalize and validate the final declarations.
Returns a plist of computed styles.
Arguments:
 OBJ          An object implementing cl-styles.protocols.
 RULES        A list of (rule . specificity) pairs matching OBJ.
 INHERIT-FROM (optional) A plist of styles to inherit from (e.g., parent's computed style).
 SHEET        (optional) A cl-styles.sheet:stylesheet for variable resolution.
Returns:
 A plist of computed styles for OBJ.
Example:
 (let* ((obj (make-instance 'node :id :btn1 :nodetype :button :style '(:color :blue)))
        (sheet (cl-styles.sheet:make-stylesheet
                :rules (list (cl-styles.rule:defrule (cl-styles.selector:type> :button)
                               :color :red
                               :font-size 12)
                             (cl-styles.rule:defrule (cl-styles.selector:id> :btn1)
                               :color :green))
                :variables '((\"--main-color\" . :purple))))
        (pairs (match-rules obj sheet)))
   (compute-style obj pairs :inherit-from '(:font-family \"Arial\") :sheet sheet))
  => (:COLOR :GREEN :FONT-SIZE 12 :FONT-FAMILY \"Arial\")"
  (let* ((inline (or (cl-styles.protocols:stylable-inline-style obj) nil))
         (acc '())
         (sorted (stable-sort (copy-list (reverse rules)) #'%spec< :key #'cdr)))
    (dolist (pr sorted)
      (let* ((rule (car pr))
             (decls (cl-styles.rule:rule-declarations rule)))
        ;; (format t "Applying rule ~a~% to acc ~a%" rule acc)
        (setf acc (%plist-merge acc decls))))
    (when inherit-from
      (setf acc (%inherit inherit-from acc)))
    (when inline
      (setf acc (%plist-merge acc inline)))
    ;; (format t "Final acc before normalization: ~a~%" acc)
    (let* ((vars (and sheet (cl-styles.sheet:stylesheet-variables sheet)))
           (resolved (if vars (cl-styles.tokens:resolve-variables acc vars) acc))
           (normalized (%normalize-decls resolved sheet)))
      ;; (format t "Normalized final style: ~a~%" normalized)
      normalized)))


(defun inherit-properties (parent child)
  (declare (ignore parent child))
  ;; Placeholder: implement CSS inheritance as needed
  nil)

(defun %apply-node (node sheet return &key (inherit-from nil))
  ;; (format *trace-output* "~&[apply-node] Applying to ~a" (cl-styles.protocols:stylable-id node))
  (let* ((pairs (match-rules node sheet))
         (style (compute-style node pairs :inherit-from inherit-from :sheet sheet))
         (res (cl-styles.protocols:set-computed-style node style)))
    ;; (format *trace-output* "~&[apply-node] Computed style for ~a: ~a" (cl-styles.protocols:stylable-id node) style)
    (ecase return
      (:patches (if (typep res 'style-patch)
                    (list res)
                    (list (make-style-patch :path (list :by-key (cl-styles.protocols:stylable-key node))
                                            :computed style))))
      (:objects (list res)))))

(defun apply-stylesheet (sheet objects &key (return :patches))
  "Apply SHEET to a flat list of OBJECTS, returning either :patches or :objects.

If :patches, return a list of style-patch structs with the path to the object and its computed style.
If :objects, return a list of the objects themselves with their computed styles set.

Objects must implement the cl-styles.protocols interface.

Arguments:
 SHEET    A cl-styles.sheet:stylesheet object.
 OBJECTS  A list of objects implementing cl-styles.protocols.
 RETURN   Either :patches (default) or :objects.

Returns:
 A list of style-patch structs or objects with computed styles set.

Example:
 (apply-stylesheet (make-stylesheet :rules ((defrule (type> :button) :color :red)))
                   (list (make-object :id :btn1 :type :button)
                        (make-object :id :lbl1 :type :label))
                   :return :patches)
 => (#<STYLE-PATCH path (:BY-KEY :BTN1) computed (:COLOR :RED)
      #<STYLE-PATCH path (:BY-KEY :LBL1) computed NIL)
or if :return :objects:
  => (#<OBJECT id :BTN1 type :BUTTON computed (:COLOR :RED)>
      #<OBJECT id :LBL1 type :LABEL computed NIL>)"
  (apply #'append (mapcar (lambda (o) (%apply-node o sheet return)) objects)))

(defun apply-stylesheet-to-tree (root sheet &key (return :patches) cache previous-signature)
  "Apply SHEET to ROOT. CACHE may be a hash-table keyed by PREVIOUS-SIGNATURE."
  (let* ((cache-key (and cache previous-signature
                         (list root sheet return previous-signature)))
         (cached (and cache-key (gethash cache-key cache))))
    (if cached
        cached
        (labels ((walk (node inherit-style)
                   (let* ((self-patches (%apply-node node sheet return
                                                     :inherit-from inherit-style))
                          (children (or (cl-styles.protocols:stylable-children node) nil))
                          (computed-here (cl-styles.protocols:get-computed-style node))
                          (child-patches (mapcan (lambda (child)
                                                   (walk child computed-here))
                                                 children)))
                     (append self-patches child-patches))))
          (let ((result (walk root nil)))
            (when cache-key
              (setf (gethash cache-key cache) result))
            result)))))

;; (cl-styles.rule:defrule (cl-styles.selector:type> :text) :color :red)
