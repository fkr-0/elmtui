;;;===============================================================
;;; File: src/view/dsl.lisp
;;; Enhanced View DSL with Standardized Widget Support
;;;===============================================================
(uiop:define-package #:elmtui.view.dsl
  (:use #:cl #:log4cl)
  (:import-from #:elmtui.view.styled #:make-styled-node)
  (:import-from #:elmtui.app.api #:registered-dsl-component-p)
  (:import-from #:elmtui.state.utils #:split-props/children)
  (:export #:render-dsl-to-resolved-tree
           #:defcomponent-dsl
           #:dsl->ui-node))

(in-package #:elmtui.view.dsl)

;;; --- defcomponent-dsl Macro ---
(defmacro defcomponent-dsl (dsl-type class-name)
  "Registers a component class for a given DSL type keyword and defines a helper function
   to generate the DSL spec for this component type.

   DSL type is a keyword that represents the component type in the DSL. class-name is
   the name of the component class that implements the view logic for this DSL type.

  component class that implements the component's behavior.

  Example usage:
    (defcomponent-dsl :my-component my-component-class) ; =>
    This will register the component class 'my-component-class' for the DSL type ':my-component'
    (defcomponent-dsl :column my-container-class) ; =>
    This will register the component class 'my-container-class' for the DSL type ':column'"
  (let ((helper-fn-name (intern (string-upcase (format nil "~A-VIEW" dsl-type)) *package*)))
    `(progn
       (elmtui.app.api:register-dsl-component-type ,dsl-type ',class-name)
       (defun ,helper-fn-name (id &rest args &key &allow-other-keys)
         ;; Ensure :id is always present and is the first element after the type keyword
         (list* ,dsl-type :id id args))
       (export ',helper-fn-name))))


;;; --- DSL Rendering ---
(defun render-dsl-to-resolved-tree (dsl-spec app-state)
  "Walks DSL-SPEC and returns a resolved DSL tree."
  (labels ((process-node (spec path)
             (cond
               ;; Scalar Leaf
               ((not (and (listp spec) (keywordp (first spec))))
                spec)

               ;; Keyword-led list
               (t
                (let* ((type (first spec))
                       (args (rest spec)))
                  (if (registered-dsl-component-p type)
                      ;; Stateful Component
                      (let* ((id (getf args :id)))
                        (unless id
                          (error "Stateful component ~S at path ~S requires an :id" type path))
                        (log-info "Resolving component ~S with ID ~S at path ~S: ~A" type id (append path (list id))
                                  (elmtui.state:get-component-by-path app-state (append path (list id))))
                        (let* ((new-path (append path (list id)))
                               (component (elmtui.state:get-component-by-path app-state new-path))
                               (view-dsl (elmtui.ui.api:view component app-state)))
                          (list* type
                                 (append (copy-list args)
                                         (list :resolved-view (process-node view-dsl new-path))))))

                      ;; Layout Element
                      (let* ((props (loop for (k v) on args by #'cddr
                                          while (keywordp k)
                                          collect k collect v))
                             (positional-children (nthcdr (length props) args))
                             (id (getf props :id))
                             (new-path (if id (append path (list id)) path))
                             (children-from-prop (getf props :children))
                             (all-children (append children-from-prop positional-children))
                             (resolved-children (mapcar (lambda (child) (process-node child new-path))
                                                        all-children)))
                        (let ((clean-props (copy-list props)))
                          (remf clean-props :children)
                          (list* type (append clean-props (list :children resolved-children)))))))))))
    (process-node dsl-spec nil)))

;;; --- DSL to UI-Node Conversion Utility ---
(defun dsl->ui-node (dsl-spec app-state)
  "Converts a DSL spec to a ui-node tree. Handles both component-based DSL and raw DSL.
   For raw DSL (simple property lists), converts directly to styled-ui-node.
   For component-based DSL, uses render-dsl-to-resolved-tree.

  Arguments:
    dsl-spec - The DSL specification, which can be a raw DSL or a component-based DSL.
    app-state - The current application state, used to resolve component instances.

  Returns:
    A tree of ui-node objects representing the UI structure defined by the DSL spec.

    If the DSL spec is a raw DSL (a property list with a keyword as the first element),
    it is converted directly to a ui-node. If it is a component-based DSL,
    it is processed to resolve the component instances and their properties.

    A raw DSL is a simple property list that defines a UI node with properties like
    :id, :style, :classes, and :children. It does not require a component type to be registered,
    e.g.:
    (:container :id :main :style (:bg-color red) :children ((:text :id :child1 :content \"Hello\"))),
    it simply relies on the DSL structure to define the node without needing a component class for custom behavior.
    When trying to access application state through a raw dsl, query the application state directly through, e.g.
    `elmtui.state.api:get-path` or `elmtui.state.api:plist-to-application-state`, as the raw DSL does not
    resolve component instances or their properties. The container example above, e.g. could dynamically
    render child1 text content by specifying the content as follows:
    (:text :id :child1
           :content
           (elmtui.state.api:state-ref :headline app-state))

    A component-based DSL is a more complex structure that uses registered component types:
    A registered component type is a keyword that represents a component class in the DSL. Therefore
    the registered component class is resolved and used to create the ui-node tree through
    `render-dsl-to-resolved-tree`, allowing a component to define its own behavior and properties
    depending on the application state


   Example:
    (dsl->ui-node '(:container :id :main :style (:bg-color red) :children ((:text :id :child1 :content \"Hello\")))
                  *application-state*)
    => Returns a styled-ui-node tree with the specified properties and children."
  (if (and (listp dsl-spec)
           (keywordp (first dsl-spec))
           (not (getf (rest dsl-spec) :id))) ; Raw DSL doesn't require :id
      ;; Handle raw DSL directly
      (progn
        (log-info "dsl->ui: Converting raw DSL to styled node directly: ~S" dsl-spec)
        (convert-raw-dsl-to-styled-node dsl-spec))
      ;; Handle component-based DSL
      ;; (let ((resolved (render-dsl-to-resolved-tree dsl-spec app-state)))
      ;;   (when  (listp resolved)
      ;;     (unless (and resolved (not (listp (first resolved))))
      ;;       (error "dsl->ui-node: Conversion did not produce a ui-node. Got: ~S" resolved)))
      ;;   (log-info "dsl->ui: Rendered to resolved-tree: ~S" resolved)
      ;;   resolved)
      (let ((resolved (render-dsl-to-resolved-tree dsl-spec app-state)))
        (unless resolved
          (error "dsl->ui-node: Conversion returned NIL for ~S" dsl-spec))
        resolved)))
;; (dsl->ui-node '(:container :id :main :style (:bg-color :red) :children ((:text :id :child1 :content "Hello")))
;; (elmtui.tea-state.state:make-state nil))
(defun convert-raw-dsl-to-styled-node (dsl-spec)
  "Converts raw DSL (property list format) directly to styled-ui-node.
   Example: (:container :id :main :style (:bg-color red) :children (...))
   -> styled-ui-node"
  (unless (and (listp dsl-spec) (keywordp (first dsl-spec)))
    (error "Invalid DSL spec: ~S" dsl-spec))

  (let* ((node-type (first dsl-spec))
         (props (rest dsl-spec))
         (id (getf props :id))
         (style (getf props :style))
         (classes (getf props :classes))
         (children-specs (getf props :children))
         (text (getf props :text)))

    ;; Convert children recursively
    (let ((converted-children
            (when children-specs
              (mapcar #'convert-raw-dsl-to-styled-node children-specs))))

      ;; Create the styled node using the imported function
      (log-info "Converting raw DSL to styled node: ~S" (make-styled-node
                                                         :type node-type
                                                         :props (append (when id (list :id id))
                                                                        (when classes (list :classes classes))
                                                                        (when text (list :text text))
                                                                        (when style (list :style style)))
                                                         :children converted-children))
      (make-styled-node
       :type node-type
       :props (append (when id (list :id id))
                      (when classes (list :classes classes))
                      (when text (list :text text))
                      (when style (list :style style)))
       :children converted-children))))
;; Example Usage (conceptual - actual components need to be defined and registered)
;; (defcomponent-dsl :my-box my-box-component)
;; (defcomponent-dsl :my-label my-label-component)

;; (render-dsl-to-resolved-tree
;;  '(:my-box :id :root-box :children
;;    ((:my-label :id :label1 :text "Hello")
;;     (:my-label :id :label2 :text "World")))
;;  *application-state*)
