(uiop:define-package #:elmtui.view.dsl
  (:use #:cl)
  (:import-from #:log4cl #:log-info)
  (:import-from #:elmtui.app.api #:get-component-class-for-dsl-type #:registered-dsl-component-p)
  (:export #:render-dsl-to-resolved-tree #:defcomponent-dsl #:dsl->ui-node))

(in-package #:elmtui.view.dsl)

(defmacro defcomponent-dsl (dsl-type class-name)
  (let ((helper-fn-name (intern (string-upcase (format nil "~A-VIEW" dsl-type)) *package*)))
    `(progn
       (elmtui.app.api:register-dsl-component-type ,dsl-type ',class-name)
       (defun ,helper-fn-name (id &rest args &key &allow-other-keys)
         (list* ,dsl-type :id id args))
       (export ',helper-fn-name))))

(defun split-props/children (args)
  (let ((props '()) (cursor args))
    (loop while (and cursor (keywordp (first cursor)))
          do (let ((key (pop cursor)))
               (when (null cursor) (error "Property list for ~S is missing a value." key))
               (push key props)
               (push (pop cursor) props)))
    (setf props (nreverse props))
    (let* ((positional cursor)
           (explicit (getf props :children)))
      (values (if explicit (alexandria:remove-from-plist props :children) props)
              (if explicit explicit (copy-tree positional))))))

(defun render-dsl-to-resolved-tree (dsl-spec app-state)
  "Walks DSL-SPEC and returns a resolved DSL tree where component views are expanded,
   handling shorthand and preserving structure."
  (let ((resolved-something nil))
    (labels ((process-node (spec path)
               (cond
                 ;; Atomic values are returned as-is.
                 ((atom spec) spec)

                 ;; A list of specs is processed recursively.
                 ((and (listp spec) (not (keywordp (first spec))))
                  (let ((processed-children (remove nil (mapcar (lambda (item) (process-node item path)) spec))))
                    (if (= 1 (length processed-children))
                        (first processed-children)
                        processed-children)))

                 ;; A DSL form (e.g., (:BOX ...))
                 ((and (listp spec) (keywordp (first spec)))
                  (destructuring-bind (type &rest tail) spec
                    (multiple-value-bind (props children) (split-props/children tail)
                      (let* ((id (getf props :id))
                             (new-path (if id (append path (list id)) path)))

                        ;; Check for circular dependencies.
                        (when (and id (member id path :test #'equal))
                          (error "Circular dependency for ID ~S detected in path ~S" id path))

                        (if (registered-dsl-component-p type)
                            ;; This is a component that needs to be resolved.
                            (progn
                              (unless id (error "Component ~S requires an :id" type))
                              (setf resolved-something t)
                              (let* ((klass (get-component-class-for-dsl-type type))
                                     (instance (make-instance klass))
                                     (view (elmtui.ui.api:view instance app-state :id-path new-path :children children)))
                                ;; The resolved view is wrapped to preserve the component's identity and props.
                                `(,type ,@props :resolved-view ,(process-node view new-path))))

                            ;; This is a standard element (e.g., :BOX, :TEXT).
                            (let ((resolved-children (remove nil (mapcar (lambda (c) (process-node c new-path)) children) :test #'equalp)))
                              (cond
                                ;; Shorthand for content: (:TEXT "hello") -> (:TEXT :content "hello")
                                ((and (null (cdr tail)) (stringp (car tail)))
                                 `(,type :content ,(car tail)))
                                ;; Retain children only if there are any.
                                (resolved-children
                                 `(,type ,@props :children ,(if (= 1 (length resolved-children)) (car resolved-children) resolved-children)))
                                ;; No children, just props.
                                (t `(,type ,@props)))))))))
                 (t spec))))
      (values (process-node dsl-spec '()) resolved-something))))

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
