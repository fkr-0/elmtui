;;;===============================================================
;;; File: src/view/dsl.lisp
;;; Enhanced View DSL with Standardized Widget Support
;;;===============================================================
(uiop:define-package :elmtui.view.dsl
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :elmtui.view.core #:make-ui-node #:ui-node-type #:ui-node-children #:ui-node)
  (:import-from :elmtui.view.styled #:make-styled-node #:styled-ui-node)
  ;; Import new widget view functions
  (:import-from :elmtui.ui.widgets.button #:view-button)
  ;; TODO: Import other standardized widget view functions
  (:export #:define-view #:*dsl-element-map*))
(in-package :elmtui.view.dsl)

;;;-----------------------------------------------------------------------------
;;; DSL Configuration
;;;-----------------------------------------------------------------------------

(defparameter *dsl-element-map*
  (alexandria:plist-hash-table
   '(;; Standardized Widget view functions
     :button view-button
     ;; TODO: Add more standardized widgets as they're implemented

     ;; Standard HTML-like elements mapping to themselves (handled by make-styled-node)
     :container :container
     :div :div
     :span :span
     :p :p
     :h1 :h1 :h2 :h2 :h3 :h3 :h4 :h4 :h5 :h5 :h6 :h6
     :li :li :ul :ul :ol :ol
     :text :text
     :fragment :fragment)
   :test 'eq)
  "Maps DSL element keywords to view functions or node types.

   Element keywords can map to:
   - A function symbol (e.g., view-button) that will be called with app-state and props
   - A keyword (e.g., :div) that will be used as the node type with make-styled-node")

;;;-----------------------------------------------------------------------------
;;; Helper Functions
;;;-----------------------------------------------------------------------------

(defun %parse-attributes-and-children (args)
  "Separates attributes (plist) from children in a list of arguments."
  (let ((attrs '())
        (remaining-args args))
    ;; Collect keyword arguments from the beginning of the list
    (loop while (and remaining-args (keywordp (first remaining-args)))
          do
             ;; Ensure there's a value for the keyword
             (unless (cdr remaining-args)
               (error "DSL: Attribute ~S is missing a value in args: ~S" (first remaining-args) args))
             (push (pop remaining-args) attrs) ; Push key
             (push (pop remaining-args) attrs)) ; Push value
    ;; remaining-args now holds the children
    (values (nreverse attrs) remaining-args)))

(defun %process-event-handler (handler-value dispatch-sym widget-id)
  "Processes an event handler value to ensure it's a valid function.
   Returns a lambda that calls dispatch-sym with the appropriate message."
  (declare (ignorable widget-id))
  (cond
    ;; Handler is a keyword or list starting with keyword - treat as a message
    ((or (keywordp handler-value)
         (and (listp handler-value) (keywordp (car handler-value))))
     `(lambda (_) (funcall ,dispatch-sym ,handler-value)))

    ;; Handler is a symbol (not keyword) - treat as message symbol
    ((and (symbolp handler-value) (not (keywordp handler-value)))
     `(lambda (_) (funcall ,dispatch-sym ',handler-value)))

    ;; Handler is already a lambda - pass through
    ((and (listp handler-value) (eq (car handler-value) 'lambda))
     handler-value)

    ;; Handler is a function name as a symbol
    ((and (symbolp handler-value) ;; (fboundp handler-value)
          )
     handler-value)

    ;; Unknown handler format - warn and pass through
    (t
     (warn "DSL: Event handler ~S is not a recognized message format or lambda. Passing as-is." handler-value)
     handler-value)))

(defun %expand-element (element-keyword attrs children app-state-sym dispatch-sym)
  "Expands a single element form like (:div :id \"foo\" ...).

   ELEMENT-KEYWORD: The keyword identifying the element type.
   ATTRS: Plist of attributes.
   CHILDREN: List of child elements or content.
   APP-STATE-SYM: Symbol bound to the application state.
   DISPATCH-SYM: Symbol bound to the dispatch function."

  (log:debug "DSL: Expanding element: ~S, Attrs: ~S, Children count: ~A"
             element-keyword attrs (length children))

  (let* ((target (gethash element-keyword *dsl-element-map* element-keyword))
         (props '())
         (widget-id nil))

    ;; Process attributes
    (loop for (key val) on attrs by #'cddr do
      (case key
        ;; Extract widget-id for standardized widgets
        (:widget-id (setf widget-id val)
         (push key props)
         (push val props))

        ;; Process event handlers into lambda functions
        ((:on-click :on-change :on-focus :on-blur :on-keypress :on-submit :on-select :on-scroll)
         (push key props)
         (push (%process-event-handler val dispatch-sym widget-id) props))

        ;; All other props pass through
        (otherwise (push key props)
         (push val props))))

    ;; Ensure widget-id is present for standardized widgets
    (when (and (symbolp target) (fboundp target) (not widget-id))
      (setf widget-id (gensym (format nil "~A-" element-keyword)))
      (push :widget-id props)
      (push widget-id props))

    ;; Reverse props to maintain correct order
    (setf props (nreverse props))

    ;; Process children
    (let ((expanded-children (mapcar (lambda (child)
                                       (%expand-view-form child app-state-sym dispatch-sym))
                                     children)))

      ;; Handle different types of target
      (cond
        ;; Target is a function - call it with app-state and props
        ((and (symbolp target) (fboundp target))
         `(funcall ',target ,app-state-sym ,@props))

        ;; Target is a keyword - create a styled node
        ((keywordp target)
         `(make-styled-node
           :type ,target
           :props (list ,@props)
           :children (remove nil (list ,@expanded-children))))

        ;; Unknown target type
        (t (error "DSL: Unknown element type or unhandled target ~S for keyword ~S"
                  target element-keyword))))))

(defun %expand-view-form (form app-state-sym dispatch-sym)
  "Recursively expands a form within the define-view macro."
  (log:debug "DSL: %expand-view-form processing: ~S" form)

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
                        app-state-sym
                        dispatch-sym)))

    ;; 3. Other lists: control structures & list-building
    ((listp form)
     (let ((op (first form)))
       (cond
         ;; Handle specific control structures
         ((member op '(if when unless progn cond loop list) :test #'eq)
          (case op
            ;; IF: condition, then, [else]
            (if
             (destructuring-bind (cond-form then-form &optional else-form)
                 (rest form)
               `(if ,cond-form
                    ,(%expand-view-form then-form app-state-sym dispatch-sym)
                    ,(when else-form
                       (%expand-view-form else-form app-state-sym dispatch-sym)))))

            ;; WHEN: condition, body...
            (when
                `(when ,(second form)
                   ,@(mapcar (lambda (f)
                               (%expand-view-form f app-state-sym dispatch-sym))
                             (cddr form))))

            ;; UNLESS: condition, body...
            (unless
                `(unless ,(second form)
                   ,@(mapcar (lambda (f)
                               (%expand-view-form f app-state-sym dispatch-sym))
                             (cddr form))))

            ;; PROGN: body...
            (progn
              `(progn
                 ,@(mapcar (lambda (f)
                             (%expand-view-form f app-state-sym dispatch-sym))
                           (rest form))))

            ;; COND: clauses...
            (cond
              `(cond
                 ,@(mapcar (lambda (clause)
                             `(,(first clause)
                               ,@(mapcar (lambda (f)
                                           (%expand-view-form f app-state-sym dispatch-sym))
                                         (rest clause))))
                           (rest form))))

            ;; LOOP ... COLLECT ...
            (loop
              (let* ((collect-pos (position 'collect form :test #'eq)))
                (if (and collect-pos
                         (< (1+ collect-pos) (length form)))
                    (let ((prefix (subseq form 0 (1+ collect-pos)))
                          (expr   (nth (1+ collect-pos) form))
                          (suffix (subseq form (+ collect-pos 2))))
                      `(,@prefix
                        ,(%expand-view-form expr app-state-sym dispatch-sym)
                        ,@suffix))
                    form)))

            ;; LIST
            (list
             `(list
               ,@(mapcar (lambda (f)
                           (%expand-view-form f app-state-sym dispatch-sym))
                         (rest form))))))

         ;; Default for other function calls
         (t form))))

    ;; Default case
    (t form)))

;;;-----------------------------------------------------------------------------
;;; Main DSL Macro
;;;-----------------------------------------------------------------------------

(defmacro define-view (name (app-state-arg dispatch-arg) &body body)
  "Defines a view function using the enhanced declarative DSL.

   NAME: Name of the view function to define.
   APP-STATE-ARG: Symbol to bind to the application state.
   DISPATCH-ARG: Symbol to bind to the dispatch function.
   BODY: DSL forms defining the view structure. Can include an optional docstring.

   Example:
     (define-view my-view (app-state dispatch)
       \"This is my awesome view.\"
       (:div :class \"container\"
         (:h1 \"Title\")
         (:button :widget-id \"submit-btn\" :on-click :submit-form \"Submit\")
         (when (show-more? app-state)
           (:p \"Additional content\"))))"

  (log:info "DSL: Defining view ~S" name)

  (let ((app-state-sym (gensym "APP-STATE"))
        (dispatch-sym (gensym "DISPATCH"))
        (docstring nil)
        (forms body))

    ;; Handle optional docstring
    ;; A docstring is present if the first form is a string and there are more forms.
    (when (and (stringp (car forms)) (cdr forms))
      (setf docstring (pop forms)))

    `(defun ,name (,app-state-sym ,dispatch-sym)
       ,@(when docstring (list docstring)) ; Add docstring to defun if present
       (log:debug "DSL: Calling view function ~S" ',name)

       ;; Bind the arguments to the names provided by the user
       (let ((,app-state-arg ,app-state-sym)
             (,dispatch-arg ,dispatch-sym))
         (declare (ignorable ,app-state-arg ,dispatch-arg))

         ;; Expand the remaining forms
         (let ((view-result
                 ,(cond
                    ((null forms) ; No forms left after docstring (should be rare for a view)
                     (log-warn "DSL: View ~S has no definition forms after docstring." `,name)
                     nil)
                    ((= 1 (length forms)) ; Single top-level form
                     (%expand-view-form (first forms) app-state-sym dispatch-sym))
                    (t ; Multiple top-level forms (should ideally be wrapped by user in a single root)
                     (log-warn "DSL: View ~S has multiple top-level forms after docstring. Consider a single root element. Wrapping in a list." `,name)
                     `(list ,@(mapcar (lambda (form)
                                        (%expand-view-form form app-state-sym dispatch-sym))
                                      forms))))))
           (log:debug "DSL: View function ~S produced result (type: ~A, children: ~A)"
                      ',name
                      (if (typep view-result 'ui-node)
                          (ui-node-type view-result)
                          (if (listp view-result)
                              (format nil "List of ~A element(s)" (length view-result))
                              (type-of view-result)))
                      (if (typep view-result 'ui-node)
                          (length (ui-node-children view-result))
                          "N/A"))
           view-result)))))
