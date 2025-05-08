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
  (:export #:define-view))
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
   '(:button view-button-model
     :label view-label-model
     :text-input view-textinput-model
     :list-box view-listbox-model
     :scrollable view-scrollable-container-model
     ;; Add standard HTML-like elements
     :div :div
     :span :span
     :h1 :h1 :h2 :h2 :h3 :h3 :p :p :li :li :ul :ul :ol :ol
     ;; Fragment for grouping without a container node?
     :fragment :fragment)
   :test 'eq)
  "Maps DSL element keywords to view functions or node types.")

(defun %process-event-handler (handler-value dispatch-sym widget-id)
  "Processes an event handler attribute value.
   - If it's a list, assume it's a message to be dispatched. Wrap it.
   - If it's a function/lambda, it needs careful handling (potential side effects)."
  (declare (ignore widget-id)) ; Add ignore for unused parameter
  ;; TODO: Refine event handling - how to wrap messages correctly?
  ;; Need a convention for how parent passes down wrapping info or widget ID.
  ;; For now, just dispatch the raw message using the passed dispatch-sym.
  ;; This assumes dispatch-sym is already correctly wrapped by the parent caller.
  (if (and (listp handler-value) (keywordp (car handler-value)))
      `(lambda () (funcall ,dispatch-sym ',handler-value)) ; Dispatch the message list
      handler-value)) ; Pass other values (like functions) through, needs careful use.


(defun %expand-element (element-keyword attrs children model-sym dispatch-sym)
  "Expands a single element form like (:div :id \"foo\" ...)"
  (let ((target (gethash element-keyword *dsl-element-map* element-keyword)) ; Default to keyword itself
        (props-plist nil)
        (event-handlers nil)
        (widget-model nil))

    ;; Separate model, event handlers, and other props from attrs plist
    (loop for (key val) on attrs by #'cddr do
      (case key
        (:model (setf widget-model val))
        ((:on-click :on-change :on-submit :on-focus :on-blur :on-keypress :on-scroll) ; Event handlers
         (push (list key (%process-event-handler val dispatch-sym nil)) event-handlers)) ; TODO: Pass widget ID for wrapping
        (otherwise (push val props-plist) (push key props-plist))))
    (setf props-plist (nreverse props-plist))

    (let ((expanded-children (mapcar (lambda (child) (%expand-view-form child model-sym dispatch-sym))
                                     children)))
      (cond
        ((symbolp target) ; It's a view function (like view-button-model)
         (unless widget-model
           (warn "DSL: No :model provided for widget element ~S" element-keyword))
         ;; Call the widget view function: (view-fn model dispatch-fn :props props)
         ;; We need to construct the dispatch function wrapper here if needed.
         ;; For now, passing dispatch-sym directly.
         `(funcall ',target ,widget-model ,dispatch-sym :props (list ,@props-plist ,@event-handlers)))

        ((keywordp target) ; It's a basic element type (like :div)
         ;; Create a styled node directly
         `(make-styled-node :type ,target
                            :props (list ,@props-plist ,@event-handlers) ; Combine props and handlers
                            :children (list ,@expanded-children))) ; Wrap expanded children

        (t (error "DSL: Unknown element type ~S" element-keyword))))))

(defun %expand-view-form (form model-sym dispatch-sym)
  "Recursively expands a form within the define-view macro."
  (cond
    ((atom form)
     ;; If atom, treat as literal value -> create text node? Or evaluate?
     ;; Let's assume evaluation for now, might need refinement.
     ;; If it evaluates to a string, wrap in a text node.
     `(let ((val ,form))
        (if (stringp val)
            (make-ui-node :type :text :props (list :value val))
            val))) ; Allow embedding other evaluated forms (e.g., results of other view calls)
    ((keywordp (first form))
     ;; Element form: (:keyword attrs... children...)
     (multiple-value-bind (attrs children) (%parse-attributes-and-children (rest form))
       (%expand-element (first form) attrs children model-sym dispatch-sym)))
    (t
     ;; Assume it's a Lisp form to evaluate (e.g., a loop, conditional, function call)
     ;; Its result should be a node or list of nodes.
     form)))

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
         ;; Expand the body forms
         ;; If body has multiple top-level forms, wrap in a fragment or similar?
         ;; For now, assume body is a single top-level DSL form.
         ;; Expand the body forms. Handle multiple forms by wrapping in a list.
         (if (= 1 (length body))
             (%expand-view-form (first body) ',model-arg ',dispatch-arg) ; Pass symbols for context
             `(list ,@(mapcar (lambda (form) (%expand-view-form form ',model-arg ',dispatch-arg)) body)))))))

;;; Implementation Notes & TODOs:
;;; - Widget Mapping: Basic mapping via *dsl-element-map* implemented.
;;; - Event Handling: Rudimentary processing added. Needs proper message wrapping based on context (parent msg type, widget ID). How does the DSL get this context? Maybe define-view needs to take parent-msg-wrapper info?
;;; - Child Processing: Recursively expands children. Assumes results are nodes or lists of nodes.
;;; - Literal Strings: Handled by creating text nodes.
;;; - Embedded Lisp: Non-element lists are evaluated directly. Conditionals (if) and loops work.
;;; - Props Evaluation: Props are currently evaluated via backquote `(list ,@props)`. Ensure this handles values correctly.
;;; - Error Checking: Minimal. Needs more validation.
;;; - Fragments: Need a way to represent fragments (e.g., (:<> ...)) for grouping without a container.
