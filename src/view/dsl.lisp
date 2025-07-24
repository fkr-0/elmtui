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
  "Registers a component class for a given DSL-TYPE keyword and defines a helper function
   to generate the DSL spec for this component type.

   Arguments:
     DSL-TYPE    -- (keyword) The DSL type keyword to register (e.g. :column).
     CLASS-NAME  -- (symbol) The component class implementing the view logic.

   Returns:
     Registers the component class for DSL-TYPE and defines a helper function named
     DSL-TYPE-VIEW (e.g. COLUMN-VIEW) that constructs a DSL spec for this type.

   Example:
     (defcomponent-dsl :my-component my-component-class)
     ;; Registers 'my-component-class' for ':my-component' and defines MY-COMPONENT-VIEW.

     (MY-COMPONENT-VIEW :id :foo :content \"bar\")
     ;; => (:MY-COMPONENT :ID :foo :CONTENT \"bar\")

   (keyword, symbol) => macro-expansion (side-effect: registers type, defines function, exports symbol)

   Side-effects:
     - Registers the DSL type/class mapping globally.
     - Defines and exports a helper function.

   Purity: impure (global registry, symbol export)
  "
  (let ((helper-fn-name (intern (string-upcase (format nil "~A-VIEW" dsl-type)) *package*)))
    `(progn
       ;; Register the DSL type/class mapping
       (elmtui.app.api:register-dsl-component-type ,dsl-type ',class-name)
       ;; Define the helper function for constructing DSL specs
       (defun ,helper-fn-name (id &rest args &key &allow-other-keys)
         "Helper function for DSL-TYPE. Arguments: ID (any), ARGS (plist). Returns: list (DSL spec)."
         ;; Ensure :id is always present and is the first element after the type keyword
         (list* ,dsl-type :id id args))
       ;; Export the helper function
       (export ',helper-fn-name))))

(defun proper-plist-p (tail)
  "Checks if TAIL is a well-formed property list (plist).

   Arguments:
     TAIL -- (list) The list to check.

   Returns:
     T if TAIL is an even-length list and all keys are keywords, NIL otherwise.

   Example:
     (proper-plist-p '(:foo 1 :bar 2)) ; => T
     (proper-plist-p '(:foo 1 bar 2))  ; => NIL

   (list) => boolean (pure, no side-effects)
  "
  ;; Check even length and all keys are keywords
  (and (evenp (length tail))
       (loop for (k v . rest) on tail by #'cddr
             always (keywordp k))))

;;; --- DSL Rendering ---
(defun render-dsl-to-resolved-tree (dsl-spec app-state)
  "Walks DSL-SPEC and returns a resolved DSL tree.

   In short, let components own :resolved-view, let layout tags own :children, and
   you’ll keep both your update loop and your mental model simple.

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

  (labels ((normalise-shorthand (type tail)
             ;; ( :TEXT "bye" )      → (:TEXT :content "bye")
             ;; ( :ROW a b c )       → (:ROW  :children (a b c))
             (if (= 1 (length tail))
                 `(,type :content ,(first tail))
                 `(,type :children ,tail)))

           (process-stateful-component (tag id path children)
             (unless id
               (error "Stateful component ~S requires an :id." tag))
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
             (cond
               ;; --------------- raw leaf ---------------------------
               ((not (and (listp spec) (keywordp (first spec))))
                spec)

               ;; --------------- element ----------------------------
               (t
                (destructuring-bind (type &rest tail) spec
                  (if (proper-plist-p tail)
                      ;; ----- full plist element --------------------
                      (let* ((id       (getf tail :id))
                             (new-path (if id (append path (list id)) path)))
                        (when (and id (member id path :test #'equal))
                          (error "Circular dependency detected for ID ~S" id))
                        (multiple-value-bind (props children)
                            (split-props/children tail)
                          (if (registered-dsl-component-p type)
                              (process-stateful-component type id new-path children)
                              ;; layout element
                              (let ((resolved-children
                                      (mapcar (lambda (ch) (process-node ch new-path))
                                              children)))
                                (if  (< 0 (length resolved-children))
                                     `(,type ,@props :children ,resolved-children)
                                     `(,type ,@props))))))
                      ;; ----- shorthand element ----------------------
                      (process-node (normalise-shorthand type tail) path)))))))
    ;; (process-node (spec path)
    ;;   (log-info "Processing DSL node: ~S at path: ~S" spec path)
    ;;   (cond
    ;;     ;; --- Leaf node (string, number, etc.) ---
    ;;     ((not (and (listp spec) (keywordp (first spec))))
    ;;      spec)

    ;;     ;; --- Element node ---
    ;;     (t
    ;;      (let* ((type (first spec))
    ;;             (id (getf (rest spec) :id))
    ;;             (new-path (if id (append path (list id)) path))
    ;;             (props (rest spec)))

    ;;        ;; --- Cycle detection ---
    ;;        (when (and id (member id path :test #'equal))
    ;;          (error "Circular dependency detected: component ID ~S is already in the rendering path ~S" id path))

    ;;        (multiple-value-bind (properties children) (split-props/children props)
    ;;          (log-info "Properties: ~S, Children: ~S" properties children)
    ;;          (if (registered-dsl-component-p type)
    ;;              ;; --- Stateful Component ---
    ;;              (process-stateful-component type id new-path children)
    ;;              ;; --- Layout Element ---
    ;;              (let ((resolved-children (mapcar (lambda (child) (process-node child new-path)) children)))
    ;;                `(,type ,@properties :children ,resolved-children))))))))
    (process-node dsl-spec nil)))

;;; --- DSL to UI-Node Conversion Utility ---
(defun dsl->ui-node (dsl-spec app-state)
  "Converts a DSL-SPEC to a ui-node tree, handling both raw and component-based DSL.

   Arguments:
     DSL-SPEC   -- (list) The DSL specification (raw or component-based).
     APP-STATE  -- (object) The current application state.

   Returns:
     A tree of ui-node objects representing the UI structure.

   Example:
     (dsl->ui-node
       '(:container :id :main :children ((:text :content \"hi\")))
       app-state)
     ;; => styled-ui-node tree

   (list, object) => ui-node (side-effect: logs info, error on invalid input)

   Side-effects:
     - Logs info messages.
     - Signals error if conversion fails.

   Purity: impure (logging, error signaling)
  "
  (if (and (listp dsl-spec)
           (keywordp (first dsl-spec))
           (not (getf (rest dsl-spec) :id))) ; Raw DSL doesn't require :id
      ;; Handle raw DSL directly
      (progn
        ;; Log conversion for debugging
        (log-info "dsl->ui: Converting raw DSL to styled node directly: ~S" dsl-spec)
        (convert-raw-dsl-to-styled-node dsl-spec))
      ;; Handle component-based DSL
      (let ((resolved (render-dsl-to-resolved-tree dsl-spec app-state)))
        (unless resolved
          (error "dsl->ui-node: Conversion returned NIL for ~S" dsl-spec))
        resolved)))
;; (dsl->ui-node '(:container :id :main :style (:bg-color :red) :children ((:text :id :child1 :content "Hello")))
;; (elmtui.tea-state.state:make-state nil))
(defun convert-raw-dsl-to-styled-node (dsl-spec)
  "Converts a raw DSL-SPEC (property list format) directly to a styled-ui-node.

   Arguments:
     DSL-SPEC -- (list) A property list describing a UI node.
                 Must start with a keyword (node type).

   Returns:
     A styled-ui-node object representing the DSL node and its children.

   Example:
     (convert-raw-dsl-to-styled-node
       '(:container :id :main :style (:bg-color red)
                    :children ((:text :content \"hi\"))))
     ;; => styled-ui-node

   (list) => styled-ui-node (side-effect: logs info, error on invalid input)

   Side-effects:
     - Logs info messages.
     - Signals error if DSL-SPEC is invalid.

   Purity: impure (logging, error signaling)
  "
  ;; Validate DSL-SPEC format
  (unless (and (listp dsl-spec) (keywordp (first dsl-spec)))
    (error "Invalid DSL spec: ~S" dsl-spec))

  ;; Extract node properties
  (let* ((node-type (first dsl-spec))
         (props (rest dsl-spec))
         (id (getf props :id))
         (style (getf props :style))
         (classes (getf props :classes))
         (children-specs (getf props :children))
         (text (getf props :text)))

    ;; Recursively convert children if present
    (let ((converted-children
            (when children-specs
              (mapcar #'convert-raw-dsl-to-styled-node children-specs))))

      ;; Log and create the styled node
      (log-info "Converting raw DSL to styled node: ~S"
                (make-styled-node
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
