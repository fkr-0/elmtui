(uiop:define-package #:elmtui.view.dsl
  (:use #:cl)
  (:import-from #:log4cl #:log-info)
  (:import-from #:elmtui.view.base-elements
                #:element-class)
  (:import-from #:elmtui.app.api
                #:get-component-class-for-dsl-type
                #:registered-dsl-component-p)
  (:export #:render-dsl-to-resolved-tree #:defcomponent-dsl #:dsl->ui-node))

(in-package #:elmtui.view.dsl)

(defmacro defcomponent-dsl (dsl-type class-name)
  (let ((helper-fn-name (intern (string-upcase (format nil "~A-VIEW" dsl-type)) *package*)))
    `(progn
       (elmtui.app.api:register-dsl-component-type ,dsl-type ',class-name)
       (defun ,helper-fn-name (id &rest args &key &allow-other-keys)
         (list* ,dsl-type :id id args))
       (export ',helper-fn-name))))



;; == elmtui/view/dsl/resolve.lisp ==
;; robust DSL resolver:
;; - never descends into property values (e.g. :style stays intact)
;; - :resolved-view is attached as a PROP, not under :children
;; - only lists that are *explicit children* are treated as DSL sibling bags

;; (defun split-props/children (args)
;;   (let ((props '()) (cursor args))
;;     (loop while (and cursor (keywordp (first cursor)))
;;           do (let ((key (pop cursor)))
;;                (when (null cursor) (error "Property list for ~S is missing a value." key))
;;                (push key props)
;;                (push (pop cursor) props)))
;;     (setf props (nreverse props))
;;     (let* ((positional cursor)
;;            (explicit (getf props :children)))
;;       (values (if explicit (alexandria:remove-from-plist props :children) props)
;;               (if explicit explicit (copy-tree positional))))))
;; (defun split-props/children (args)
;;   "Split the DSL tail into (values PROPS CHILDREN).
;;    PROPS is a plist of *top-level* k/v pairs with any top-level :children removed.
;;    CHILDREN is either the explicit :children value or the tail starting at the first
;;    non-keyword (positional children)."
;;   (let ((props '())
;;         (children nil)
;;         (cursor args))
;;     (loop
;;       (when (null cursor) (return))
;;       (let ((k (first cursor)))
;;         (cond
;;           ((keywordp k)
;;            (when (null (rest cursor))
;;              (error "Property list for ~S is missing a value." k))
;;            (let ((v (second cursor)))
;;              (if (eq k :children)
;;                  (setf children v)
;;                  (setf props (nconc props (list k v)))))
;;            (setf cursor (cddr cursor)))
;;           (t
;;            ;; First non-keyword → the remainder are positional children.
;;            (setf children cursor
;;                  cursor   nil)))))
;;     (values props (copy-tree children))))

(defun split-props/children (args)
  "Split top-level tail into (values PROPS CHILDREN), without touching prop values.
   CHILDREN is either the explicit :children value, or the positional tail
   (starting at the first non-keyword)."
  (let ((props '())
        (children nil)
        (cursor args))
    (loop
      (when (null cursor) (return))
      (let ((k (first cursor)))
        (cond
          ((keywordp k)
           (when (null (rest cursor))
             (error "Property list for ~S is missing a value." k))
           (let ((v (second cursor)))
             (if (eq k :children)
                 (setf children v)
                 (setf props (nconc (list k v) props ))))
           (setf cursor (cddr cursor)))
          (t
           (setf children cursor
                 cursor   nil)))))
    (values props (copy-tree children))))

(defun %emit-node (type props &optional children)
  "Emit `(TYPE ...props... [:children children])`. CHILDREN remains a list."
  (append (list type)
          props
          (when children (list :children children))))

(defun render-dsl-to-resolved-tree (dsl-spec app-state)
  "Resolve DSL to a tree. Only recurse into *children*. Prop values are opaque data.
   Treat a list as a DSL node only if its head keyword is a *known* DSL tag."
  (let ((resolved-something nil))
    (labels
        ((process-node (spec path &key (in-children-p nil))
           (cond
             ;; atoms pass through
             ((atom spec) spec)

             ;; sibling bag: only inside a children position
             ((and in-children-p (listp spec) (not (keywordp (first spec))))
              (mapcar (lambda (item) (process-node item path :in-children-p nil)) spec))

             ;; potential DSL node: only if head is a known DSL tag
             ((and (listp spec)
                   (keywordp (first spec))
                   (or (and (fboundp 'registered-dsl-component-p)
                            (ignore-errors (registered-dsl-component-p (first spec))))
                       (element-class (first spec))))
              (destructuring-bind (type &rest tail) spec
                ;; shorthand (:TEXT "hello")
                (when (and (= (length tail) 1) (stringp (first tail)))
                  (return-from process-node `(,type :content ,(first tail))))
                (multiple-value-bind (props children) (split-props/children tail)
                  (let* ((id (getf props :id))
                         (new-path (if id (append path (list id)) path)))
                    (when (and id (member id path :test #'equal))
                      (error "Circular dependency for ID ~S detected in path ~S" id path))
                    (if (and (fboundp 'registered-dsl-component-p)
                             (ignore-errors (registered-dsl-component-p type)))
                        ;; component → resolve view, attach as a PROP
                        (progn
                          (unless id (error "Component ~S requires an :id" type))
                          (setf resolved-something t)
                          (let* ((klass    (get-component-class-for-dsl-type type))
                                 (instance (make-instance klass))
                                 (view     (elmtui.ui.api:view instance app-state
                                                               :id-path new-path
                                                               :children children))
                                 (rv       (process-node view new-path :in-children-p nil)))
                            (%emit-node type (append props (list :resolved-view rv)) nil)))
                        ;; normal element → recurse only into CHILDREN
                        (%emit-node type props
                                    (when children
                                      (mapcar (lambda (c) (process-node c new-path :in-children-p t))
                                              children))))))))

             ;; any other list (including style plists like (:BORDER T ...)) is **data**
             ;; ((listp spec) spec)

             (t spec))))
      (values (process-node dsl-spec '()) resolved-something))))
;; == end/resolve.lisp ==
;; == end/resolve.lisp ==

(defun dsl->ui-node (dsl-spec app-state)
  (let ((spec (if (listp dsl-spec)
                  (getf (cdr dsl-spec) :resolved-view dsl-spec)
                  dsl-spec)))
    (loop for i from 1 to 10
          do (multiple-value-bind (next-dsl resolved-p)
                 (render-dsl-to-resolved-tree spec app-state)
               (setf spec (if (listp next-dsl)
                              (getf (cdr next-dsl) :resolved-view next-dsl)
                              next-dsl))
               (unless resolved-p (return)))
          finally (when (> i 9) (warn "DSL resolution took more than 10 iterations.")))
    (elmtui.view.base-elements:dsl->objects spec)))
