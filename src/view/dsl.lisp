;;;===============================================================
;;; File: src/view/dsl.lisp
;;; Enhanced View DSL with Standardized Widget Support
;;;===============================================================
(uiop:define-package #:elmtui.view.dsl
  (:use #:cl )
  (:import-from #:log4cl #:log-info)
  (:import-from #:elmtui.view.styled #:make-styled-node)
  (:import-from #:elmtui.app.api #:get-component-class-for-dsl-type #:registered-dsl-component-p)
  ;; (:import-from #:elmtui.utils #:split-props/children)
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

(defun remove-from-plist (plist key)
  "Remove KEY from PLIST and return a new plist without mutating the original.

   Arguments:
     PLIST -- (list) The property list to modify.
     KEY   -- (keyword) The key to remove.

   Returns:
     A new plist with KEY removed, or the original plist if KEY is not found.

   Example:
     (remove-from-plist '(:foo 1 :bar 2) :bar) ; => (:foo 1)

   (list, keyword) => list (pure, no side-effects)
  "
  (loop for (k v) on plist by #'cddr
        unless (eq k key)
          append (list k v)))


;;; ------------------------------------------------------------------
;;; helpers -----------------------------------------------------------
(defun normalise-shorthand (type tail)
  ;; ( :TEXT "bye" )      → (:TEXT :content "bye")
  ;; ( :ROW a b c )       → (:ROW  :children (a b c))
  (if (= 1 (length tail))
      `(,type :content ,(first tail))
      `(,type :children ,tail)))
(defun copy-plist (plist)
  "Return a deep copy of PLIST (keywords alternating with values).
   Any value that is a cons is copied with COPY-TREE so that the
   copy shares no structure with the original."
  (loop for (k v) on plist by #'cddr
        append (list k (if (consp v) (copy-tree v) v))))

(defun split-props/children (args)
  "Split ARGS into two values: PROPS (a plist) and CHILDREN (a list).

Any keyword/value pairs at the head of ARGS are regarded as properties.
Positional children start at the first non-keyword object.
If a :CHILDREN property is present it *overrides* any positional
children.

The function NEVER mutates ARGS."
  (let ((props '())
        (cursor args))
    ;; harvest leading keyword/value pairs
    (loop while (and cursor (keywordp (first cursor)))
          do (let ((key (pop cursor)))
               (when (null cursor)
                 (error "Property list for ~S is missing a value." key))
               (push key props)
               (push (pop cursor) props)))
    (setf props (nreverse props))
    ;; explicit children override positional ones
    (let* ((positional cursor)
           (explicit   (getf props :children)))
      (values (remove :children (if explicit
                                    (alexandria:remove-from-plist props :children)
                                    props))
              (if explicit
                  explicit
                  (copy-tree positional))))))

(registered-dsl-component-p :layout)
;;; ------------------------------------------------------------------
;;; main walker -------------------------------------------------------
(defun render-dsl-to-resolved-tree (dsl-spec app-state)
  "Replaces every component DSL form with its :RESOLVED-VIEW, but does NOT yet instantiate base-ui-nodes."
  (let ((resolved-something nil))
    (labels
        ((process-node (spec path)
           (cond
             ;; leaf
             ((or (null spec) (stringp spec) (numberp spec))
              spec)

             ;; list of items
             ((and (listp spec) (not (keywordp (first spec))))
              (mapcar (lambda (item) (process-node item path)) spec))

             ;; potential DSL form
             ((and (listp spec) (keywordp (first spec)))
              (destructuring-bind (type &rest tail) spec
                (multiple-value-bind (props children) (split-props/children tail)
                  (let* ((id (getf props :id))
                         (new-path (if id (append path (list id)) path)))
                    (log:info "Processing DSL node: ~S with path: ~S" spec new-path)
                    (log:info "type: ~S, props: ~S, children: ~S" type props children)
                    (when (and id (member id path :test #'equal))
                      (error "Circular dependency detected for ID ~S" id))
                    (if (registered-dsl-component-p type)
                        ;; Component → resolve to its :resolved-view
                        (progn
                          (log-info "Resolving DSL component: ~S with ID: ~S" type id)
                          (setf resolved-something t)
                          (let* ((klass (get-component-class-for-dsl-type type))
                                 (instance (make-instance klass))
                                 (view (elmtui.ui.api:view instance app-state
                                                           :id-path new-path
                                                           :children (if (listp (car children))
                                                                         children (list children)))))
                            (log:info "Resolved view for component ~S: ~S" type view)
                            (process-node view new-path))) ;; RECURSE into returned view
                        ;; Base DSL
                        (let ((resolved-children (mapcar (lambda (x)
                                                           (log-info "Processing child: ~S with path: ~S" x new-path)
                                                           (process-node x new-path))
                                                         (if (listp (car children))
                                                             children (list children)))))
                          `(,type ,@props
                            ,@(when resolved-children
                                (list :children resolved-children)))))))))
             ;; fallback
             (t
              spec))))
      (values (process-node dsl-spec '()) resolved-something))))

;; (defun render-dsl-to-resolved-tree (dsl-spec app-state)
;;   "Return a *new* DSL tree where every stateful component is replaced
;; with its :RESOLVED-VIEW.  DSL-SPEC itself is left untouched so the
;; function is idempotent and safe to call in a loop until no
;; :RESOLVED-VIEW remains.
;; Walks DSL-SPEC and returns a resolved DSL tree.

;;    In short, let components own :resolved-view, let layout tags own :children, and
;;    you’ll keep both your update loop and your mental model simple.

;;   • A: No injection at all**<br>*(component’s subtree is 100 % private)*
;;     • Components stay flack-box → strong encapsulation.
;;     • `view` always returns the same skeleton → simpler to reason about diffs & layout.
;;     • The public API is just `(state → view)` plus messages → minimal surface.
;;     • Caller can’t reuse the
;;       component as a layout wrapper.<br>• You end up cloning “header-body-footer” or
;;       “card” patterns as **three** almost-identical components.
;;     • Behaviour-centric or
;;       leaf widgets (e.g. `:counter`, `:spinner`).
;;     • Projects where strict invariants and predictable diffs trump flexibility.

;;   • B: Controlled injection via *named slots***<br>`(:dialog :header (…) :body (…) :footer (…))`
;;     • Flexibility **and** determinism: the component decides *where* each slot is
;;       placed.
;;     • Slot structure can be validated at macro-expansion time (using your
;;       `defcomponent-dsl`).
;;     • Easy theming: wrap the same content into a different skin
;;       component.
;;     • Slightly larger API: you document the accepted slot names and
;;       defaults.
;;     • Inside `view` you must resolve each slot (one extra `mapcar`).
;;     • Layout / container components (`:viewport`, `:dialog`, `:grid`) whose *purpose is
;;       exactly to position other views*.
;;     • Design systems that need “card with custom
;;       header”-style reuse.

;;   ---
;;   Design
;;   ---
;;   1. **Default to option A** for behaviour-driven widgets.
;;     `:counter`, `:progress-bar`, `:input-field` shouldn’t accept caller-supplied
;;     trees—keep them single-purpose and testable.

;;   2. **Named slots -- for container/layout components**.
;;     It fits TEA nicely:
;;     (defcomponent-dsl :viewport (:id &key content)
;;       (view (state slot-content)
;;         (let ((children (resolve-slot :content slot-content state)))
;;           `(:viewport
;;             :id ,(state-id state)
;;             :width  ,(state-width state)
;;             :height ,(state-height state)
;;             :children ,children))))

;;     * The macro can reject unknown slot keys at compile time.

;;     * In the caller you write:
;;       (:viewport :id :main
;;                  :content ((:label :content \"Hello\")
;;                            (:counter :id :c1)))

;;     * Inside `view` you still control **when** and **how** those children are resolved.
;;   ---
;;   Advice
;;   ---
;;   Injecting content *isn’t strictly necessary* for a TEA engine to work, but a
;;   **slot-based API (option B)** is highly advisable for components whose whole job is
;;   to lay out or decorate other views. It preserves encapsulation, keeps diffs
;;   predictable, and lets application code stay pleasant to read—without opening the door
;;   to the chaos of completely free positional children. "
;;   (let ((resolved-something nil))
;;     (labels
;;         ((process-node (spec path)
;;            (unless (and (listp spec) (keywordp (first spec)))
;;              (return-from process-node spec))
;;            (destructuring-bind (type &rest tail) spec
;;              (multiple-value-bind (props children) (split-props/children tail)
;;                (let* ((id (getf props :id))
;;                       (new-path (if id (append path (list id)) path)))
;;                  (when (and id (member id path :test #'equal))
;;                    (error "Circular dependency detected for ID ~S" id))
;;                  (if (registered-dsl-component-p type)
;;                      (progn
;;                        (setf resolved-something t)
;;                        (let* ((klass (get-component-class-for-dsl-type type))
;;                               (instance (make-instance klass))
;;                               (view (elmtui.ui.api:view instance app-state
;;                                                         :id-path new-path
;;                                                         :children children)))
;;                          view))
;;                      (let ((resolved-children (mapcar (lambda (c) (process-node c new-path))
;;                                                       children)))
;;                        (append (list type)
;;                                (copy-plist props)
;;                                (when resolved-children
;;                                  (list :children resolved-children))))))))))
;;       (values (process-node dsl-spec '())
;;               resolved-something))))
;;; --- DSL Rendering ---
;; (defun render-dsl-to-resolved-tree (dsl-spec app-state)
;;   (labels
;;       ((process-stateful-component (tag id path props children)
;;          (unless id
;;            (error "Stateful component ~S requires an :id." tag))
;;          (let* ((new-path (append path (list id)))
;;                 (class    (get-component-class-for-dsl-type tag))
;;                 (inst     (make-instance class))
;;                 (view-dsl (elmtui.ui.api:view inst
;;                                               app-state
;;                                               :id-path  new-path
;;                                               :children children
;;                                               :props    props)))
;;            `(,tag ,@props
;;              :resolved-view ,view-dsl)))

;;        (process-node (spec path)
;;          (unless (and (listp spec) (keywordp (first spec)))
;;            (return-from process-node spec))

;;          (destructuring-bind (tag &rest tail) spec
;;            (let (props children)
;;              ;; Phase 1: Separate props and children from the tail
;;              (loop with rest = tail
;;                    while (and rest (keywordp (first rest)))
;;                    do (progn
;;                         (unless (cdr rest) (error "Dangling keyword ~S in ~S" (first rest) spec))
;;                         (push (first rest) props)
;;                         (push (second rest) props)
;;                         (setf rest (cddr rest)))
;;                    finally (setf children rest)
;;                            (setf props (nreverse props)))

;;              ;; Phase 2: Handle special cases for children
;;              (when (null props)
;;                (cond
;;                  ((and (= 1 (length children)) (atom (first children)))
;;                   (setf props `(:content ,(first children)))
;;                   (setf children nil))
;;                  (t t)))

;;              ;; Phase 3: Unwrap children if they are in a single list
;;              (when (and (= 1 (length children)) (listp (first children)))
;;                (setf children (first children)))

;;              ;; Phase 4: Check for :children prop and merge if necessary
;;              (let ((children-prop (getf props :children)))
;;                (when children-prop
;;                  (when children (error "Children specified twice in ~S" spec))
;;                  (setf children children-prop)
;;                  (setf props (loop for (k v) on props by #'cddr
;;                                    unless (eq k :children)
;;                                      append (list k v)))))

;;              ;; Phase 5: Recurse and build result
;;              (let* ((id (getf props :id))
;;                     (new-path (if id (append path (list id)) path)))
;;                (when (and id (member id path :test #'equal))
;;                  (error "Circular dependency: ~S in ~S" id path))

;;                (if (registered-dsl-component-p tag)
;;                    (process-stateful-component tag id path props children)
;;                    (let ((resolved-children
;;                            (mapcar (lambda (ch) (process-node ch new-path))
;;                                    children)))
;;                      (if resolved-children
;;                          `(,tag ,@props :children ,resolved-children)
;;                          `(,tag ,@props)))))))))
;;     (process-node dsl-spec '())))


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
  (let ((spec nil))
    (loop with current-dsl = dsl-spec
          for i from 1 to 10
          do (multiple-value-bind (next-dsl resolved-p)
                 (render-dsl-to-resolved-tree current-dsl app-state)
               (setf spec current-dsl)
               (setf current-dsl next-dsl)
               (unless resolved-p
                 (return)))
          finally (when (> i 9)
                    (warn "DSL resolution took more than 10 iterations.")))
    (elmtui.utils:as :styled-ui-node
                     (elmtui.view.base-elements:dsl->objects
                      spec))))
;; (if (and (listp dsl-spec)
;;          (keywordp (first dsl-spec))
;;          (not (getf (rest dsl-spec) :id))) ; Raw DSL doesn't require :id
;;     ;; Handle raw DSL directly
;;     (progn
;;       ;; Log conversion for debugging
;;       (log-info "dsl->ui: Converting raw DSL to styled node directly: ~S" dsl-spec)
;;       (convert-raw-dsl-to-ui-node dsl-spec))
;;     ;; Handle component-based DSL
;;     (let ((resolved (render-dsl-to-resolved-tree dsl-spec app-state)))
;;       (unless resolved
;;         (error "dsl->ui-node: Conversion returned NIL for ~S" dsl-spec))
;;       (convert-raw-dsl-to-ui-node resolved))))
;; (dsl->ui-node '(:container :id :main :style (:bg-color :red) :children ((:text :id :child1 :content "Hello")))
;; (elmtui.tea-state.state:make-state nil))
;; Example Usage (conceptual - actual components need to be defined and registered)
;; (defcomponent-dsl :my-box my-box-component)
;; (defcomponent-dsl :my-label my-label-component)

;; (render-dsl-to-resolved-tree
;;  '(:my-box :id :root-box :children
;;    ((:my-label :id :label1 :text "Hello")
;;     (:my-label :id :label2 :text "World")))
;;  (elmtui.tea-state:make-application-state))
