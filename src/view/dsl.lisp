;;;===============================================================
;;; File: src/view/dsl.lisp
;;; Declarative View DSL Macro
;;;===============================================================
(uiop:define-package :elmtui.view.dsl
  (:use :cl :alexandria)
  (:import-from :elmtui.view.core #:make-ui-node)
  (:import-from :elmtui.view.styled #:make-styled-node)
  ;; Import widget view functions
  (:import-from :elmtui.ui.widgets
                #:view-button-model #:view-label-model #:view-textinput-model
                #:view-listbox-model #:view-scrollable-container-model)
  (:export #:define-view #:*dsl-element-map*))
(in-package :elmtui.view.dsl)

;;; NOTES on DSL Design:
;;; Aiming for a Hiccup-like syntax: (element-keyword attribute-map child1 child2 ...)
;;; - element-keyword: :div, :button, :label, etc. Maps to node type or widget view function.
;;; - attribute-map: A plist or hash-map containing :id, :class, event handlers (:on-click), etc.
;;; - children: Nested DSL forms or literal strings/values.

;;; No forward declaration needed if helper functions are defined before use.

(defun %parse-attributes-and-children (args)
  "Separates attributes (plist) from children in a list of arguments."
  (let ((attrs nil)
        (children nil))
    (if (and (listp args) (keywordp (first args))) ; Check if first arg looks like a plist key
        (progn
          (setf attrs (loop for (key val) on args by #'cddr
                            while (keywordp key)
                            collect key collect val
                            finally (setf children (copy-list args)))) ; Remaining args are children
          (values attrs children))
        ;; No attribute map found, all args are children
        (values nil args))))

;; Mapping from DSL keywords to widget view functions or element types
(defparameter *dsl-element-map*
  (alexandria:plist-hash-table
   '(;; Widget view functions
     :button elmtui.ui.widgets:view-button ; Assuming view-button exists
     :label elmtui.ui.widgets:view-label ; Assuming view-label exists
     :text-input elmtui.ui.widgets:view-textinput ; Assuming view-textinput exists
     :list-box elmtui.ui.widgets.listbox:view-listbox ; Corrected mapping
     :scrollable elmtui.ui.widgets:view-scrollable-container-model ; Assuming view-scrollable-container exists

     ;; Standard HTML-like elements mapping to themselves (handled by make-styled-node)
     :container :container ; Added :container
     :div :div
     :span :span
     :p :p ; Added :p for paragraph/text
     :h1 :h1 :h2 :h2 :h3 :h3 :li :li :ul :ul :ol :ol
     ;; Special elements
     :text :text ; For explicit text nodes if needed, distinct from :p or :span
     :fragment :fragment)
   :test 'eq)
  "Maps DSL element keywords to view functions or node types.")

(defun %process-event-handler (handler-value dispatch-sym widget-id)
  "Processes an event handler attribute value.
   - If it's a list starting with a keyword, or a symbol, assume it's a message. Wrap it in a lambda to dispatch.
   - If it's already a function (e.g. a lambda form), pass it through."
  (declare (ignore widget-id))
  (cond
    ((or (and (listp handler-value) (keywordp (car handler-value))) ; e.g. '(:type :payload)
         (symbolp handler-value)) ; e.g. 'MyMessage or 'ButtonClicked
     ;; Wrap message (list or symbol) in a lambda for dispatching
     ;; Ensure the handler-value (message) itself is quoted in the generated lambda
     `(lambda () (funcall ,dispatch-sym ',handler-value)))
    ((and (listp handler-value) (eq (car handler-value) 'lambda)) ; Already a lambda form
     handler-value) ; Pass lambda forms through directly
    (t
     ;; Potentially a function symbol or something else.
     ;; For safety, warn or error if it's not a recognized form.
     (warn "DSL: Event handler ~S is not a recognized message format or lambda. Passing as-is." handler-value)
     handler-value)))


(defun %expand-element (element-keyword attrs children model-sym dispatch-sym)
  "Expands a single element form like (:div :id \"foo\" ...)"
  (let ((target (gethash element-keyword *dsl-element-map* element-keyword)) ; Default to keyword itself
        (props-accumulator nil) ; Accumulates all props: general, style, event handlers
        (widget-model nil)
        (direction nil))

    ;; Process attributes from the DSL form
    (loop for (key val) on attrs by #'cddr do
      (case key
        (:model (setf widget-model val))
        (:direction (setf direction val)) ; Will be processed into style props later
        ((:on-click :on-change :on-submit :on-focus :on-blur :on-keypress :on-scroll) ; Event handlers
         ;; Add event handler key and processed value to props-accumulator
         (push key props-accumulator)
         (push (%process-event-handler val dispatch-sym nil) props-accumulator))
        (otherwise ; Other properties
         (push key props-accumulator)
         (push val props-accumulator))))

    ;; If direction was specified, add corresponding flex style properties
    (when direction
      (push :display props-accumulator)
      (push :flex props-accumulator) ; e.g., :display :flex
      (push :flex-direction props-accumulator)
      (push (case direction
              (:row :row)
              (:column :column)
              (:row-reverse :row-reverse)
              (:column-reverse :column-reverse)
              (t :row))
            props-accumulator)) ; Default direction

    ;; All properties are pushed in reverse, so nreverse to get correct order
    (setf props-accumulator (nreverse props-accumulator))

    ;; Handle children: expand them first
    (let ((expanded-children (mapcar (lambda (child) (%expand-view-form child model-sym dispatch-sym))
                                     children)))
      (cond
        ((and (symbolp target) (fboundp target)) ; Target is a widget view function
         (let ((final-props props-accumulator))
           ;; Convention: For :button or :label, if a single string child is present
           ;; and no explicit :label attribute, use the string child as :label.
           (when (and (member element-keyword '(:button :label))
                      (null (getf attrs :label)) ; Check original attrs for explicit :label
                      (= 1 (length children))
                      (stringp (first children)))
             (setf final-props (list* :label (first children) final-props)))

           (unless widget-model
             ;; This warning might be too broad if some widgets are model-less by design.
             (warn "DSL: No :model provided for widget element ~S (which maps to function ~S)" element-keyword target))

           ;; Construct the funcall for the widget view function
           ;; Properties are passed flatly (e.g., :key1 val1 :key2 val2 ...)
           (if widget-model
               `(funcall ',target ,widget-model ,dispatch-sym ,@final-props)
               `(funcall ',target nil ,dispatch-sym ,@final-props))))

        ((keywordp target) ; Target is a basic element type (e.g., :div, :container)
         ;; These are handled by make-styled-node, which expects props in a list
         `(make-styled-node :type ,target
                            :props (list ,@props-accumulator) ; Note: props wrapped in a list here
                            :children (list ,@expanded-children)))

        ((and (symbolp target) (not (fboundp target))) ; Target symbol is not a defined function
         (error "DSL: Element keyword ~S maps to an undefined function symbol ~S" element-keyword target))

        (t (error "DSL: Unknown element type or unhandled target ~S for keyword ~S" target element-keyword))))))

;; (defun %expand-view-form (form model-sym dispatch-sym)
;;   "Recursively expands a form within the define-view macro."
;;   (cond
;;     ((atom form)
;;      ;; If atom, treat as literal value -> create text node? Or evaluate?
;;      ;; Let's assume evaluation for now, might need refinement.
;;      ;; If it evaluates to a string, wrap in a text node.
;;      `(let ((val ,form))
;;         (cond ((stringp val)
;;                (make-styled-node :type :text :props (list :value val) :children nil))
;;               ((typep val 'elmtui.view.core:ui-node) ; If it's already a node, pass it through
;;                val)
;;               (t val)))) ; Allow embedding other evaluated forms (e.g., results of other view calls that return nodes)
;;     ((keywordp (first form))
;;      ;; Element form: (:keyword attrs... children...)
;;      (multiple-value-bind (attrs children) (%parse-attributes-and-children (rest form))
;;        (%expand-element (first form) attrs children model-sym dispatch-sym)))
;;     ((listp form) ; Third main clause: form is a list but doesn't start with a keyword
;;      ;; This is where we handle general Lisp forms, including control structures.
;;      (let ((op (first form)))
;;        (cond
;;          ;; Handle common control flow and list-building forms by recursively expanding their relevant parts
;;          ((member op '(if progn when unless cond loop list) :test #'eq)
;;           (case op
;;             ('if ; (if condition then-form &optional else-form)
;;              `(,op ,(second form) ; condition (not expanded)
;;                ,(%expand-view-form (third form) model-sym dispatch-sym) ; then-form (expanded)
;;                ,@(when (fourth form) ; optional else-form (expanded if present)
;;                    `((%expand-view-form ,(fourth form) model-sym dispatch-sym)))))
;;             ((when unless) ; (when/unless condition body...)
;;              `(,op ,(second form) ; condition (not expanded)
;;                ,@(mapcar (lambda (sf) (%expand-view-form sf model-sym dispatch-sym)) (cddr form)))) ; body forms (expanded)
;;             ('progn ; (progn body...)
;;               `(,op ,@(mapcar (lambda (sf) (%expand-view-form sf model-sym dispatch-sym)) (rest form)))) ; body forms (expanded)
;;             ('cond ; (cond (test1 body1...) (test2 body2...)...)
;;               `(,op ,@(mapcar (lambda (clause)
;;                                 `(,(first clause) ; test (not expanded)
;;                                   ,@(mapcar (lambda (bf) (%expand-view-form bf model-sym dispatch-sym)) (rest clause)))) ; body forms (expanded)
;;                               (rest form))))
;;             ('loop
;;               ;; Simplified handling for 'loop ... collect <form-to-expand> ...'
;;               ;; This is a basic heuristic and might not cover all 'loop' variants.
;;               (let ((collect-pos (position 'collect form :test #'eq)))
;;                 (if (and collect-pos (< (+ collect-pos 1) (length form))) ; Check if 'collect' exists and has a form after it
;;                     (let ((pre-collect-part (subseq form 0 (+ collect-pos 1))) ; e.g., (loop for x in list collect)
;;                           (form-to-expand (nth (+ collect-pos 1) form)) ; The form to be collected
;;                           (post-collect-part (subseq form (+ collect-pos 2)))) ; Anything after the collected form
;;                       `(,@pre-collect-part
;;                         ,(%expand-view-form form-to-expand model-sym dispatch-sym) ; Expand the collected form
;;                         ,@post-collect-part))
;;                     form))) ; If not a recognized 'loop collect' pattern, return form as is
;;             ('list ; (list item1 item2 ...)
;;              `(,op ,@(mapcar (lambda (sf) (%expand-view-form sf model-sym dispatch-sym)) (rest form)))))) ; items (expanded)
;;          (t
;;           ;; Default for other Lisp list forms: return as is.
;;           ;; Assumes the form evaluates to a UI node or list of nodes, or nil.
;;           form))))
;;     (t ; Fallback for any other type of form that wasn't atom, keyword-led list, or general list.
;;      (error "DSL: Unexpected form type in %expand-view-form: ~S. Expected atom, keyword-led list, or general list." form))))
(defun %expand-view-form (form model-sym dispatch-sym)
  "Recursively expands a form within the define-view macro."
  (cond
    ;; 1. Atom: wrap literals (strings → text-nodes, ui-nodes pass through)
    ((atom form)
     `(let ((val ,form))
        (cond ((stringp val)
               (make-styled-node :type :text
                                 :props (list :value val)
                                 :children nil))
              ((typep val 'elmtui.view.core:ui-node)
               val)
              (t val))))
    ;; 2. Element form: list whose first element is a keyword
    ((and (listp form) (keywordp (first form)))
     (multiple-value-bind (attrs children)
         (%parse-attributes-and-children (rest form))
       (%expand-element (first form)
                        attrs
                        children
                        model-sym
                        dispatch-sym)))
    ;; 3. Other lists: control structures & list-building
    ((listp form)
     (let ((op (first form)))
       (cond
         ;; only handle these ops specially
         ((member op '(if when unless progn cond loop list) :test #'eq)
          (case op
            ;; ----- IF: condition, then, [else] -----
            (if
             (destructuring-bind (cond-form then-form &optional else-form)
                 (rest form) ; Destructure (rest form)
               `(if ,cond-form
                    ,(%expand-view-form then-form model-sym dispatch-sym)
                    ,@(when else-form
                        (list (%expand-view-form else-form
                                                 model-sym
                                                 dispatch-sym))))))
            ;; ----- WHEN -----
            (when
                (destructuring-bind (condition &rest body)
                    (rest form) ; Destructure (rest form)
                  `(when ,condition
                     ,@(mapcar (lambda (f)
                                 (%expand-view-form f model-sym dispatch-sym))
                               body))))
            ;; ----- UNLESS -----
            (unless
                (destructuring-bind (condition &rest body)
                    (rest form) ; Destructure (rest form)
                  `(unless ,condition
                     ,@(mapcar (lambda (f)
                                 (%expand-view-form f model-sym dispatch-sym))
                               body))))
            ;; ----- PROGN -----
            (progn
              `(progn
                 ,@(mapcar (lambda (f)
                             (%expand-view-form f model-sym dispatch-sym))
                           (rest form))))
            ;; ----- COND -----
            (cond
              `(cond
                 ,@(mapcar (lambda (clause)
                             `(,(first clause)
                               ,@(mapcar (lambda (f)
                                           (%expand-view-form f
                                                              model-sym
                                                              dispatch-sym))
                                         (rest clause))))
                           (rest form))))
            ;; ----- LOOP … COLLECT … -----
            (loop
              (let* ((collect-pos (position 'collect form :test #'eq)))
                (if (and collect-pos
                         (< (1+ collect-pos) (length form)))
                    (let ((prefix (subseq form 0 (1+ collect-pos)))
                          (expr   (nth (1+ collect-pos) form))
                          (suffix (subseq form (+ collect-pos 2))))
                      `(,@prefix
                        ,(%expand-view-form expr model-sym dispatch-sym)
                        ,@suffix))
                    form)))
            ;; ----- LIST -----
            (list
             `(list
               ,@(mapcar (lambda (f)
                           (%expand-view-form f model-sym dispatch-sym))
                         (rest form))))))
         ;; default: leave unknown forms untouched
         (t
          form))))
    ;; 4. Fallback: error out
    ;; (t
    ;;      (error "DSL: Unexpected form in %%expand-view-form: ~S; \
    ;; expected atom, keyword-led list, or list." form))
    ))

(defmacro define-view (name (model-arg dispatch-arg) &body body)
  "Defines a view function using a declarative DSL.
   Syntax is inspired by Hiccup: (element-keyword attribute-plist child1 child2...)
   Example:
     (define-view my-view (model dispatch)
       (:div :class \"container\"
         (:h1 \"Title\")
         (if (show-button model)
             (:button :on-click 'ButtonClicked \"Click Me\")
             nil)
         (loop for item in (items model)
               collect (:li (item-name item)))))
   Expands to a regular function definition that builds a UI node tree."
  (let ((model-sym (gensym "MODEL"))
        (dispatch-sym (gensym "DISPATCH")))
    `(defun ,name (,model-sym ,dispatch-sym)
       ;; Bind the arguments to the names provided by the user
       (let ((,model-arg ,model-sym)
             (,dispatch-arg ,dispatch-sym))
         (declare (ignorable ,model-arg ,dispatch-arg)) ; Mark as ignorable if not used directly
         ;; Expand the body forms.
         ;; If there's only one top-level form in the body, expand it directly.
         ;; If there are multiple, wrap their expansions in a (list ...).
         ;; This typically means a view should return a single root node.
         ;; If multiple nodes are returned, they should be implicitly wrapped in a fragment or list.
         ,(if (= 1 (length body))
              (%expand-view-form (first body) model-sym dispatch-sym)
              `(list ,@(mapcar (lambda (form) (%expand-view-form form model-sym dispatch-sym))
                               body)))))))
;; #|
;; (define-view my-view (model dispatch)
;;   (:button :on-click 'ButtonClicked "Slick Me")
;;   (:button :on-click 'ButtonClicked "Click Me"))
;; (:div :class \"container\"
;;       (:h1 \"Title\")
;;       (if (show-button model)
;;           (:button :on-click 'ButtonClicked \"Click Me\")
;;           nil)
;;       (loop for item in (items model)
;;             collect (:li (item-name item))))
;; )
;; |#

;;; Implementation Notes & TODOs:
;;; - Widget Mapping: Basic mapping via *dsl-element-map* implemented.
;;; - Event Handling: Rudimentary processing added. Needs proper message wrapping based on context (parent msg type, widget ID). How does the DSL get this context? Maybe define-view needs to take parent-msg-wrapper info?
;;; - Child Processing: Recursively expands children. Assumes results are nodes or lists of nodes.
;;; - Literal Strings: Handled by creating text nodes.
;;; - Embedded Lisp: Non-element lists are evaluated directly. Conditionals (if) and loops work.
;;; - Props Evaluation: Props are currently evaluated via backquote `(list ,@props)`. Ensure this handles values correctly.
;;; - Error Checking: Minimal. Needs more validation.
;;; - Fragments: Need a way to represent fragments (e.g., (:<> ...)) for grouping without a container.
