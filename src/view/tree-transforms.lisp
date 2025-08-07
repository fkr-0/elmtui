;;;; elmtui.view.tree-transforms --- Implementation of tree transformation functions
;;;; This file is part of the ElmTUI project.
;;;; License: MIT  •  Version: 0.2.0  •  2025-06-07

(uiop:define-package :elmtui.view.tree-transforms
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.contracts #:define-stage #:pipeline-contract-violation)
  (:import-from :elmtui.view.api
   :resolve-view :layout-view)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-type #:ui-node-props #:ui-node-children #:ui-node-p #:make-ui-node)
  (:import-from :elmtui.view.styled
                #:styled-ui-node #:styles #:make-styled-node #:copy-styled-node
                #:apply-stylesheet-to-tree #:style-value)
  (:import-from :elmtui.view.geo #:make-rectangle #:x #:y #:w #:h #:copy-rectangle #:rectangle)
  ;; Import the layout system's entry point and box model accessors
  (:import-from :elmtui.view.layout #:layout-tree #:layout-node #:box-model #:padding-box #:content-box #:border-box)
  (:import-from :elmtui.style-lib.api #:stylesheet #:style-set)
  (:import-from :elmtui.ui.api #:component #:view #:id)
  ;; (:import-from :str :split)
  )

(in-package :elmtui.view.tree-transforms)

;;; ----------------------------------------------------------------------
;;; Tree Transformation Pipeline Implementations
;;; ----------------------------------------------------------------------

(define-stage resolve-view
    ((or null (cons styled-ui-node null)) ; Input: list with 0 or 1 styled-ui-node
     (or null (cons styled-ui-node null))) ; Output: list with 0 or 1 styled-ui-node
    (styled-tree &optional app-state)
  "Resolve non-atomic nodes and apply style-driven transformations (Stage 3).
  STYLED-TREE is a list containing one styled root node.
  APP-STATE is the global application state, potentially needed by component view methods.
  Returns an atomic UI-Node tree (list containing one root atomic node)."
                                        ; Ignore app-state for now, as it's not used in this stage
  ;; (declare (ignore app-state))
  (log-info "TREE-TRANSFORMS: resolve-view - Processing ~D styled top-level node(s)."
            (length styled-tree))
  (labels ((resolve-node (item parent-id-path)
             (cond
               ((typep item 'component)
                (log-info "TREE-TRANSFORMS: resolve-view - Resolving component ID: ~S" (id item))
                ;; If it's a component instance, call its view method,
                ;; then recursively resolve the resulting UI-node tree.
                ;; The view returns a raw ui-node, which then needs styling and further resolution.
                ;; This implies a mini-pipeline loop here, or components should return atomic nodes.
                ;; For now, assume component views produce ui-nodes that are then resolved.
                ;; This part needs careful thought: if a component's view returns another component, or complex ui-node.
                ;; Let's assume components in the styled-tree are already expanded by a prior stage or their
                ;; view methods are called to get ui-nodes before this stage if they are part of the structure.
                ;; If 'item' is a component here, it means it wasn't resolved by render-view, which is unlikely.
                ;; This path should ideally not be hit if render-view fully resolves components to ui-nodes.
                ;; For now, let's assume 'styled-tree' contains only styled-ui-nodes.
                (log-info "TREE-TRANSFORMS: resolve-view - Encountered a component ~S directly in styled-tree. This might indicate an issue in prior pipeline stages." (id item))
                item) ; Pass through if this unexpected case occurs

               ((typep item 'styled-ui-node)
                (log-info "TREE-TRANSFORMS: resolve-view - Resolving styled-ui-node ID: ~S, Type: ~S"
                          (getf (ui-node-props item) :id) (ui-node-type item))
                (let* ((node-type (ui-node-type item))
                       (props (ui-node-props item))
                       (children (ui-node-children item))
                       (display-style (style-value item :display :block)) ; Default to block
                       (overflow-x :visible);(style-value item :overflow-x :visible))
                       (overflow-y :visible );(style-value item :overflow-y :visible))
                       (resolved-item item))
                  (log-info "TREE-TRANSFORMS: resolve-view - Node ID: ~S, Type: ~S, Display: ~A, Overflow-X: ~A, Overflow-Y: ~A"
                            (getf props :id) node-type display-style overflow-x overflow-y)

                  ;; 1. Handle :overflow style for scrollable content
                  (when (or (member overflow-x '(:scroll :auto :hidden))
                            (member overflow-y '(:scroll :auto :hidden)))
                    (log-info "TREE-TRANSFORMS: resolve-view - Applying :overflow transformation for node ID: ~S" (getf props :id))
                    ;; Wrap children in a :viewport node.
                    ;; The original node becomes the container for this viewport.
                    ;; (let* ((viewport-id (gensym "VIEWPORT-"))
                    ;;        (viewport-props `(:id ,viewport-id
                    ;;                          :overflow-x ,overflow-x
                    ;;                          :overflow-y ,overflow-y
                    ;;                          ;; Viewport itself might need some default styles or inherit relevant ones
                    ;;                          :style (:width :fill :height :fill))) ; Basic viewport style
                    ;;        (viewport-node (make-styled-node :type :viewport
                    ;;                                         :props viewport-props
                    ;;                                         :children children
                    ;;                                         ;; Parent of viewport is the original node, but this happens structurally
                    ;;                                         ))
                    ;;        ;; The original node now has the viewport as its single child.
                    ;;        (new-original-node (copy-styled-node resolved-item :children (list viewport-node))))
                    ;;   (setf resolved-item new-original-node)
                    ;;   ;; Children of the viewport are already set, they will be resolved in the recursive call later.
                    ;;   (setf children (list viewport-node)))
                    ) ; Update children for subsequent processing

                  ;; 2. Handle :display style (structural implications)
                  (cond
                    ((eq display-style :none)
                     (log-info "TREE-TRANSFORMS: resolve-view - Node ID: ~S has display:none. Returning NIL." (getf props :id))
                     (return-from resolve-node nil)) ; Node and its children are not rendered

                    ((member display-style '(:flex :grid))
                     ;; Ensure the node type is suitable for flex/grid layout or transform it.
                     ;; For now, assume :layout node type is used for these, or that layout-view handles it.
                     ;; If the node is not already :layout, we could wrap its children or change its type.
                     ;; Let's assume layout-view will correctly interpret display:flex/grid on any styled-node.
                     ;; No structural change here, but layout-view will use this display property.
                     (log-info "TREE-TRANSFORMS: resolve-view - Node ID: ~S has display:~A. No structural change, layout will handle." (getf props :id) display-style))

                    ((eq node-type :text-input) ; Example of resolving a complex component to simpler ones
                     ;; A text-input might resolve to a :drawable-content for text and a :cursor node
                     ;; This is more of a component's own view logic, but resolve-view could do it if needed.
                     ;; For now, assume :text-input is atomic enough or its view handles this.
                     )
                    ;; Add other type-specific resolutions here if needed.
                    )

                  ;; 3. Recursively resolve children of the (potentially transformed) a
                  (let ((resolved-children (loop for child in children
                                                 for resolved-child = (resolve-node child (cons (getf props :id) parent-id-path))
                                                 when resolved-child collect resolved-child)))
                    (if (eq children resolved-children) ; No change in children list
                        resolved-item ; Return original (or overflow-transformed) item
                        (copy-styled-node resolved-item :children resolved-children))))) ; Return copy with new children

               ((ui-node-p item) ; Plain ui-node, should ideally not happen after 'apply-style'
                (log-info "TREE-TRANSFORMS: resolve-view - Encountered plain ui-node ~S. Should be styled-ui-node." item)
                ;; Fallback: try to resolve its children
                (let ((resolved-children (mapcar (lambda (c) (resolve-node c parent-id-path)) (ui-node-children item))))
                  (if (eq (ui-node-children item) resolved-children)
                      item
                      (let ((new-node (make-ui-node :type (ui-node-type item)
                                                    :props (ui-node-props item)
                                                    :children resolved-children)))
                        new-node))))

               (t item)))) ; Pass through other data types (e.g., strings, numbers if allowed)

    (if (null styled-tree)
        nil
        (let ((resolved-root (resolve-node (first styled-tree) nil)))
          (if resolved-root (list resolved-root) nil)))))


(define-stage layout-view
    ((or null (cons styled-ui-node null)) ; Input: list with 0 or 1 styled-ui-node
     (or null (cons styled-ui-node null))) ; Output: list with 0 or 1 styled-ui-node
    (atomic-tree &key available-rect stylesheet)
  "Compute absolute geometry for every node in ATOMIC-TREE (Stage 4).
  ATOMIC-TREE is assumed to be a list containing a single root UI-Node.
  AVAILABLE-RECT is the rectangle (border-box) for the root node.
  STYLESHEET is needed if layout decisions depend on re-querying styles (should be rare here).
  Returns a laid-out atomic UI-Node tree (list containing one root node).
  Each node in the returned tree will have a :layout-rect (its border-box) and a :box-model property."
  ;; (declare (ignore stylesheet))
  (log-info "TREE-TRANSFORMS: layout-view - Processing ~D atomic top-level node(s). Available-rect: ~S"
            (length atomic-tree) available-rect)

  (if (and atomic-tree (= 1 (length atomic-tree)) (typep (first atomic-tree) 'styled-ui-node))
      (let ((root-node (first atomic-tree)))
        ;; elmtui.view.layout:layout-tree is the main entry point for layout
        ;; It should handle the box model calculations internally and recursively.
        (list (layout-tree root-node available-rect)))
      (progn
        (warn "LAYOUT-VIEW: Expected atomic-tree to be a list with a single styled root UI-Node. Got: ~A" atomic-tree)
        atomic-tree)))
