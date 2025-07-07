;;;===============================================================
;;; File: src/view/dsl.lisp
;;; Enhanced View DSL with Standardized Widget Support
;;;===============================================================
(uiop:define-package #:elmtui.view.dsl
  (:use #:cl)
  (:import-from #:elmtui.view.styled #:make-styled-node)
  (:import-from #:elmtui.app.api #:registered-dsl-component-p)
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

(defun parse-plist-and-children (args)
  "Parses a list of arguments into a property list and a list of children."
  (let ((i (loop for i from 0 below (length args) by 2
                 unless (and (< (1+ i) (length args)) (keywordp (nth i args)))
                   return i)))
    (values (subseq args 0 i) (subseq args i))))

;;; --- DSL Rendering ---
(defun render-dsl-to-resolved-tree (dsl-spec app-state)
  "Renders a view DSL spec into a tree of resolved component nodes.
   This function is called by the application's renderer."
  (labels ((process-node (spec current-path)
             (if (and spec (listp spec) (keywordp (first spec)))
                 (let* ((component-type (first spec))
                        (args (rest spec)))
                   (if (registered-dsl-component-p component-type)
                       ;; It's a stateful component.
                       (let* ((id (getf args :id))
                              (component-path (append current-path (list id))))
                         (unless id (error "View DSL spec for component ~S missing :id at path ~S" component-type current-path))
                         (let* ((component (elmtui.state:get-component-by-path app-state component-path))
                                (view-result (elmtui.ui.api:view component app-state)))
                           ;; The view-result itself is a DSL spec. We need to recursively process it.
                           (list component-type :id id :resolved-view (process-node view-result component-path))))
                       ;; It's a layout element. It doesn't have a view method.
                       (multiple-value-bind (props children)
                           (parse-plist-and-children args)
                         (let ((id (getf props :id)))
                           (list* component-type props
                                  (mapcar (lambda (child-spec)
                                            (process-node child-spec (if id (append current-path (list id)) current-path)))
                                          (or (getf props :children) children)))))))
                 spec))) ; If not a component spec, return as is (e.g. string, number)
    (process-node dsl-spec nil)))

;;; --- DSL to UI-Node Conversion Utility ---
(defun dsl->ui-node (dsl-spec app-state)
  "Converts a DSL spec to a ui-node tree. Handles both component-based DSL and raw DSL.
   For raw DSL (simple property lists), converts directly to styled-ui-node.
   For component-based DSL, uses render-dsl-to-resolved-tree."
  (if (and (listp dsl-spec)
           (keywordp (first dsl-spec))
           (not (getf (rest dsl-spec) :id))) ; Raw DSL doesn't require :id
      ;; Handle raw DSL directly
      (convert-raw-dsl-to-styled-node dsl-spec)
      ;; Handle component-based DSL
      (let ((resolved (render-dsl-to-resolved-tree dsl-spec app-state)))
        (unless (and resolved (not (listp (first resolved))))
          (error "dsl->ui-node: Conversion did not produce a ui-node. Got: ~S" resolved))
        resolved)))

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
