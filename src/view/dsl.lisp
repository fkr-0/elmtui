;;;===============================================================
;;; File: src/view/dsl.lisp
;;; Enhanced View DSL with Standardized Widget Support
;;;===============================================================
(uiop:define-package #:elmtui.view.dsl
  (:use #:cl #:log4cl)
  (:import-from #:elmtui.view.styled #:make-styled-node)
  (:import-from #:elmtui.app.api #:get-component-class-for-dsl-type #:registered-dsl-component-p)
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
  "Walks DSL-SPEC and returns a resolved DSL tree.

In short, let components own :resolved-view, let layout tags own :children, and you’ll
keep both your update loop and your mental model simple.

### Should your framework **let callers inject arbitrary children into a component?**

  • A: No injection at all**<br>*(component’s subtree is 100 % private)*
    • Components stay flack-box → strong encapsulation.
    • `view` always returns the same skeleton → simpler to reason about diffs & layout.
    • The public API is just `(state → view)` plus messages → minimal surface.
    • Caller can’t reuse the
      component as a layout wrapper.<br>• You end up cloning “header-body-footer” or
      “card” patterns as **three** almost-identical components.
    • Behaviour-centric or
      leaf widgets (e.g. `:counter`, `:spinner`).
    • Projects where strict invariants and predictable diffs trump flexibility.

  • B: Controlled injection via *named slots***<br>`(:dialog :header (…) :body (…) :footer (…))`
    • Flexibility **and** determinism: the component decides *where* each slot is
      placed.
    • Slot structure can be validated at macro-expansion time (using your
      `defcomponent-dsl`).
    • Easy theming: wrap the same content into a different skin
      component.
    • Slightly larger API: you document the accepted slot names and
      defaults.
    • Inside `view` you must resolve each slot (one extra `mapcar`).
    • Layout / container components (`:viewport`, `:dialog`, `:grid`) whose *purpose is
      exactly to position other views*.
    • Design systems that need “card with custom
      header”-style reuse.

  ---
  Design
  ---
  1. **Default to option A** for behaviour-driven widgets.
    `:counter`, `:progress-bar`, `:input-field` shouldn’t accept caller-supplied
    trees—keep them single-purpose and testable.

  2. **Named slots -- for container/layout components**.
    It fits TEA nicely:
    (defcomponent-dsl :viewport (:id &key content)
      (view (state slot-content)
        (let ((children (resolve-slot :content slot-content state)))
          `(:viewport
            :id ,(state-id state)
            :width  ,(state-width state)
            :height ,(state-height state)
            :children ,children))))

    * The macro can reject unknown slot keys at compile time.

    * In the caller you write:
      (:viewport :id :main
                 :content ((:label :content \"Hello\")
                           (:counter :id :c1)))

    * Inside `view` you still control **when** and **how** those children are resolved.
  ---
  Advice
  ---
  Injecting content *isn’t strictly necessary* for a TEA engine to work, but a
  **slot-based API (option B)** is highly advisable for components whose whole job is
  to lay out or decorate other views. It preserves encapsulation, keeps diffs
  predictable, and lets application code stay pleasant to read—without opening the door
  to the chaos of completely free positional children."

  (labels ((process-stateful-component (tag id path children)
             ;; ── STATEFUL COMPONENT ──────────────────────────────────────
             (let* ;; (props     (extract-props rest))        ; everything except :children
                 ;; (raw-slot  (getf rest :children))       ; may be NIL
                 ;;(comp-id   (getf props :id))
                 ;; (slice     (sub-state app-state comp-id))
                 ;; call the component’s VIEW, handing the raw, *unresolved* slot
                 ((component-class (get-component-class-for-dsl-type tag))
                  (component (make-instance component-class))
                  (view-dsl (elmtui.ui.api:view component app-state :id-path path :children children)))
               ;; wrap it
               `(,tag :id ,id :resolved-view ,view-dsl)))
           (process-node (spec path)
             (log-info "Processing DSL node: ~S at path: ~S" spec path)
             (cond
               ;; --- Leaf node (string, number, etc.) ---
               ((not (and (listp spec) (keywordp (first spec))))
                spec)

               ;; --- Element node ---
               (t
                (let* ((type (first spec))
                       (id (getf (rest spec) :id))
                       (new-path (if id (append path (list id)) path))
                       (props (rest spec)))

                  ;; --- Cycle detection ---
                  (when (and id (member id path :test #'equal))
                    (error "Circular dependency detected: component ID ~S is already in the rendering path ~S" id path))

                  (multiple-value-bind (properties children) (split-props/children props)
                    (log-info "Properties: ~S, Children: ~S" properties children)
                    (if (registered-dsl-component-p type)
                        ;; --- Stateful Component ---
                        (process-stateful-component type id new-path children)
                        ;; --- Layout Element ---
                        (let ((resolved-children (mapcar (lambda (child) (process-node child new-path)) children)))
                          ;; (progn
                          ;;   (log-info "Resolving layout ~S at ~S" type new-path)
                          ;;   ;; (list* type (append properties (list :children resolved-children)))
                          ;;   )
                          `(,type ,@properties :children ,resolved-children)))))))))
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
