(uiop:define-package #:elmtui.view.dsl
  (:use #:cl)
  (:import-from #:log4cl #:log-debug)
  (:import-from #:elmtui.view.base-elements
    #:element-class)
  (:import-from #:elmtui.ui.dsl-resolution
    #:resolve-dsl-type)
  (:import-from #:elmtui.core.errors
    #:dsl-error #:signal-dsl-validation-error
    #:with-error-context #:error-with-context)
  (:export #:render-dsl-to-resolved-tree #:defcomponent-dsl #:dsl->ui-node))

(in-package #:elmtui.view.dsl)

(defmacro defcomponent-dsl (dsl-type class-name)
  "Register a new DSL component type and define a helper function for node creation.

DSL-TYPE is a keyword representing the component type (e.g., :root-viewport).
CLASS-NAME is the symbol naming the class associated with this component.

This macro:
+ Defines a dsl-type method for DSL-TYPE that returns CLASS-NAME.
+ Defines a helper function named DSL-TYPE-VIEW (e.g., ROOT-VIEWPORT-VIEW) that constructs a DSL node of this type.
+ Exports the helper function from the current package.

The generated helper function has the signature:
  (DSL-TYPE-VIEW id &rest args &key &allow-other-keys)
where:
  id   -- the identifier for the DSL node
  args -- additional keyword arguments for the node

Example:
  (defcomponent-dsl :root-viewport elmtui.view.base-elements:RootViewport)
  (ROOT-VIEWPORT-VIEW \"main\" :width 800 :height 600)
  ;; => (:ROOT-VIEWPORT :ID \"main\" :WIDTH 800 :HEIGHT 600)

This macro is useful for building extensible DSLs, especially for UI or data structure construction."
  (let ((helper-fn-name (intern (string-upcase (format nil "~A-VIEW" dsl-type)) (find-package *package*))))
    `(progn
       ;; Define a dsl-type method for this component type
       (defmethod elmtui.ui.dsl-resolution:dsl-type ((type (eql ,dsl-type)) &optional props)
         (values ',class-name props))
       (defun ,helper-fn-name (id &rest args &key &allow-other-keys)
         (declare (ignore &allow-other-keys))
         (list* ,dsl-type :id id args))
       (export ',helper-fn-name))))


(defparameter *dsl-summary-max-length* 200
  "Maximum number of characters emitted when logging DSL summaries.
If NIL, summaries are not truncated.")

(defun %truncate-dsl-summary (text)
  (if (and *dsl-summary-max-length*
        (> (length text) *dsl-summary-max-length*))
    (concatenate 'string
      (subseq text 0 (max 0 (1- *dsl-summary-max-length*)))
      "…")
    text))



(defun %dsl-summary (dsl)
  "Return a concise description of a DSL node for logging."
  (%truncate-dsl-summary
    (cond
      ((atom dsl) (format nil "~A" dsl))
      ((and (listp dsl) (keywordp (first dsl)))
        (multiple-value-bind (props children) (split-props/children (rest dsl))
          (let* ((id (getf props :id))
                  (child-list (cond
                                ((null children) nil)
                                ((listp children) children)
                                (t (list children))))
                  (child-count (length child-list)))
            (format nil "~(~a~)~@[ id=~a~] (~d child~:p)"
              (first dsl) id child-count))))
      (t (format nil "~A" dsl)))))

(defun split-props/children (args)
  "Split top-level tail into (values PROPS CHILDREN), without touching prop values.
   CHILDREN is either the explicit :children value, or the positional tail
   (starting at the first non-keyword)."
  (with-error-context (:operation "split-props-children" :module "view.dsl")
    (unless (listp args)
      (signal-dsl-validation-error args nil "Arguments must be a list"
        "Use a list of keyword-value pairs or positional arguments"))

    (let ((props '())
           (children nil)
           (cursor args))
      (loop
        (when (null cursor) (return))
        (let ((k (first cursor)))
          (cond
            ((keywordp k)
              (when (null (rest cursor))
                (signal-dsl-validation-error args (position k args)
                  (format nil "Property list for ~S is missing a value." k)
                  "Ensure every keyword has a corresponding value"
                  "Example: (:width 100 :height 50) not (:width)"))
              (let ((v (second cursor)))
                (cond
                  ((eq k :children)
                   (setf children v)
                   (setf cursor (cddr cursor)))
                  ;; If v looks like a DSL element (list starting with keyword),
                  ;; then (k v) is actually the first child, not a property
                  ;; Check if k is a component type (child) vs a property key
                  ;; Component types include layout elements, widgets, etc.
                  ;; Property keys are structural: :id, :class, :style, etc.
                  ((and (listp v) (keywordp (first v))
                        (member k '(:row :column :text :container :vbox :hbox
                                       :layout :viewport :root-viewport
                                       :grid-container :scroll-panel
                                       :button :label :input
                                       :counter)))  ; Add more as needed
                   ;; k looks like a component type, so (k v) is actually the first child
                   (setf children cursor)
                   (setf cursor nil))
                  (t
                   (setf props (nconc (list k v) props))
                   (setf cursor (cddr cursor))))))
            (t
              (setf children cursor
                cursor   nil)))))
      (values props (copy-tree children)))))

(defun %emit-node (type props &optional children)
  "Emit `(TYPE ...props... [:children children])`. CHILDREN remains a list."
  (append (list type)
    props
    (when children (list :children children))))

(defun render-dsl-to-resolved-tree (dsl-spec app-state)
  "Resolve DSL to a tree. Only recurse into *children*. Prop values are opaque data.
   Treat a list as a DSL node only if its head keyword is a *known* DSL tag."
  (with-error-context (:operation "render-dsl-to-resolved-tree" :module "view.dsl")
    (log-debug "Resolving DSL root ~A" (%dsl-summary dsl-spec))
    (when (null dsl-spec)
      (signal-dsl-validation-error dsl-spec nil "DSL specification cannot be nil"
        "Provide a valid DSL specification like (:text \"Hello\")"
        "Check if you accidentally passed nil instead of a DSL form"))

    ;; Allow atomic leaves (e.g., strings/numbers) to pass through unchanged
    (when (atom dsl-spec)
      (return-from render-dsl-to-resolved-tree dsl-spec))

    (let ((resolved-something nil))
      (block resolve
        (labels
          ((process-node (spec path &key (in-children-p nil))
             ;; (with-error-context (:operation "process-node" :module "view.dsl")
             ;; (log-info "Processing node: ~S (path ~S, in-children-p ~A)" spec path in-children-p)
             (cond
               ;; atoms pass through
               ((atom spec) spec)

               ;; sibling bag: only inside a children position
               ((and in-children-p (listp spec) (not (keywordp (first spec))))
                 (mapcar (lambda (item) (process-node item path :in-children-p nil)) spec))

               ;; potential DSL node: only if head is a known DSL tag
               ((and (listp spec)
                  (keywordp (first spec))
                  (or (ignore-errors (nth-value 0 (resolve-dsl-type (first spec))))
                    (element-class (first spec)))) ;; (element-class :root-viewport)
                 (destructuring-bind (type &rest tail) spec
                   ;; shorthand (:TEXT "hello")
                   (when (and (= (length tail) 1) (stringp (first tail)))
                     (return-from process-node `(,type :content ,(first tail))))
                   (multiple-value-bind (props children) (split-props/children tail)
                     (let* ((id (getf props :id))
                             (new-path (if id (append path (list id)) path)))
                       (when (and id (member id path :test #'equal))
                         (signal-dsl-validation-error spec 0
                           (format nil "Circular dependency for ID ~S detected in path ~S" id path)
                           "Use unique IDs within the component hierarchy"
                           "Check that no parent and child share the same ID"))
                       (if (ignore-errors (nth-value 0 (resolve-dsl-type type)))
                         ;; component → resolve view, attach as a PROP
                         (if id
                             ;; Has :id, so instantiate as a component
                             (progn
                               (setf resolved-something t)
                               (handler-case
                                 (multiple-value-bind (klass default-props)
                                     (resolve-dsl-type type)
                                   (declare (ignore default-props))
                                   (let* ((instance (make-instance klass))
                                          (view     (elmtui.ui.api:view instance app-state
                                                              :id-path new-path
                                                              :children children))
                                          (_ (when (null view)
                                               (log-debug "Component ~A at ~A returned NIL view; delaying DSL resolution."
                                                 type new-path)
                                               (return-from resolve (values nil nil))))
                                          (rv       (process-node view new-path :in-children-p nil)))
                                     (declare (ignore _))
                                     (%emit-node type (append props (list :resolved-view rv)) nil)))
                                 (error (e)
                                   (progn (format t "Error resolving component ~S at path ~S: ~A~%" type new-path e)
                                     (signal-dsl-validation-error spec 0
                                       (format nil "Failed to resolve component ~S: ~A" type e))))))
                             ;; No :id, treat as base element
                             (%emit-node type props
                               (when children
                                 (mapcar (lambda (c) (process-node c new-path :in-children-p t))
                                   children))))
                         ;; normal element → recurse only into CHILDREN
                         (%emit-node type props
                           (when children
                             (mapcar (lambda (c) (process-node c new-path :in-children-p t))
                               children))))))))

               ;; any other list (including style plists like (:BORDER T ...)) is **data**
               ;; ((listp spec) spec)

               (t spec))));)
          (values (process-node dsl-spec '()) resolved-something))))))
;; == end/resolve.lisp ==
;; == end/resolve.lisp ==

(defun dsl->ui-node (dsl-spec app-state)
  (with-error-context (:operation "dsl->ui-node" :module "view.dsl")
    (when (null dsl-spec)
      (signal-dsl-validation-error dsl-spec nil "DSL specification cannot be nil"
        "Provide a valid DSL specification"
        "Check if you accidentally passed nil as the DSL form"))

    (let ((spec (if (listp dsl-spec)
                  (getf (cdr dsl-spec) :resolved-view dsl-spec)
                  dsl-spec)))
      (loop for i from 1 to 10
        do (handler-case
             (multiple-value-bind (next-dsl resolved-p)
               (render-dsl-to-resolved-tree spec app-state)
               (setf spec (if (listp next-dsl)
                            (getf (cdr next-dsl) :resolved-view next-dsl)
                            next-dsl))
               (unless resolved-p (return)))
             (error (e)
               (signal-dsl-validation-error dsl-spec 0
                 (format nil "DSL resolution failed at iteration ~D: ~A" i e)
                 (format nil "~A~%" e)
                 (format nil "spec ~A~%" spec)
                 "Ensure all component types are properly registered"
                 "Verify the DSL syntax is correct")))
        finally (when (> i 19)
                  (warn "DSL resolution took more than 10 iterations. Possible circular reference.")
                  (signal-dsl-validation-error dsl-spec 0
                    "DSL resolution exceeded maximum iterations")))
      (when (null spec)
        (log-debug "dsl->ui-node: unresolved spec; returning NIL.")
        (return-from dsl->ui-node nil))
      (handler-case
        (elmtui.view.base-elements:dsl->objects spec)
        (error (e)
          (signal-dsl-validation-error spec 0
            (format nil "Failed to convert DSL to UI objects: ~A" e)
            "Check that all element types are valid"
            "Ensure proper DSL structure"
            "Verify all required properties are provided"))))))
