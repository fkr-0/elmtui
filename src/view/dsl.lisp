;;;===============================================================
;;; File: src/view/dsl.lisp
;;; Enhanced View DSL with Standardized Widget Support
;;;===============================================================
(uiop:define-package #:elmtui.view.dsl
  (:use #:cl)
  (:export #:render-dsl-to-resolved-tree
           #:defcomponent-dsl))

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
  "Converts a DSL spec to a ui-node tree using render-dsl-to-resolved-tree.
   Ensures the result is a ui-node, not a raw DSL/plist. Raises an error if not."
  (let ((resolved (render-dsl-to-resolved-tree dsl-spec app-state)))
    (unless (and resolved (not (listp (first resolved))))
      (error "dsl->ui-node: Conversion did not produce a ui-node. Got: ~S" resolved))
    resolved))
;; Example Usage (conceptual - actual components need to be defined and registered)
;; (defcomponent-dsl :my-box my-box-component)
;; (defcomponent-dsl :my-label my-label-component)

;; (render-dsl-to-resolved-tree
;;  '(:my-box :id :root-box :children
;;    ((:my-label :id :label1 :text "Hello")
;;     (:my-label :id :label2 :text "World")))
;;  *application-state*)
