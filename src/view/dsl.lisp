;;;===============================================================
;;; File: src/view/dsl.lisp
;;; Enhanced View DSL with Standardized Widget Support
;;;===============================================================
(uiop:define-package #:elmtui.view.dsl
  (:use #:cl)
  (:import-from #:elmtui.view.styled #:make-styled-node)
  (:export #:render-dsl-to-resolved-tree
           #:defcomponent-dsl
           #:dsl->ui-node))

(in-package #:elmtui.view.dsl)

;;; --- defcomponent-dsl Macro ---
(defmacro defcomponent-dsl (dsl-type class-name)
  "Registers a component class for a given DSL type keyword and defines a helper function
   to generate the DSL spec for this component type."
  (let ((helper-fn-name (intern (string-upcase (format nil "~A-VIEW" dsl-type)) *package*)))
    `(progn
       (elmtui.app.api:register-dsl-component-type ,dsl-type ',class-name)
       (defun ,helper-fn-name (id &rest args &key &allow-other-keys)
         ;; Ensure :id is always present and is the first element after the type keyword
         (list* ,dsl-type :id id args))
       (export ',helper-fn-name))))

;;; --- DSL Rendering ---
(defun render-dsl-to-resolved-tree (dsl-spec app-state)
  "Renders a view DSL spec into a tree of resolved component nodes.
   This function is called by the application's renderer."
  (labels ((process-node (spec current-path)
             (if (and spec (listp spec) (keywordp (first spec)))
                 (let* ((component-type (first spec))
                        (args (rest spec))
                        (id (getf args :id))
                        (component-path (append current-path (list id))))
                   (unless id (error "View DSL spec ~S missing :id at path ~S" spec current-path))

                   (let* ((component-instance (elmtui.state:get-component-by-path app-state component-path)))
                     (unless component-instance
                       (error "Component not found at path ~S for DSL spec ~S. App state: ~S"
                              component-path spec app-state))

                     ;; Call the component's view method. It should return a new DSL spec for its content.
                     (let ((view-result (elmtui.ui.api:view component-instance app-state)))
                       ;; The view-result itself is a DSL spec. We need to recursively process it.
                       ;; The children of this component will be under its ID in the path.
                       (if (and view-result (listp view-result) (keywordp (first view-result)))
                           ;; If the view returns a single component spec (e.g. a viewport for its child)
                           (list component-type :id id :resolved-view (process-node view-result component-path))
                           (list component-type :id id :resolved-view view-result)) ; Leaf node or simple content
                       )))
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
