;;;; elmtui.view.tree-transforms --- Implementation of tree transformation functions
;;;; This file is part of the ElmTUI project.
;;;; License: MIT  •  Version: 0.2.0  •  2025-06-07

(uiop:define-package :elmtui.view.tree-transforms
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.view.api
    render-view apply-style resolve-view layout-view render-to-buffer diff-buffer apply-diff)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-type #:ui-node-props #:ui-node-children #:ui-node-p #:make-ui-node)
  (:import-from :elmtui.view.styled
                #:styled-ui-node #:styles #:make-styled-node #:copy-styled-node
                #:apply-stylesheet-to-tree #:style-value)
  (:import-from :elmtui.view.geo #:make-rectangle #:x #:y #:w #:h #:copy-rectangle #:rectangle)
  ;; Import the layout system's entry point and box model accessors
  (:import-from :elmtui.view.layout #:layout-tree #:layout-node #:box-model #:padding-box #:content-box #:border-box)
  (:import-from :elmtui.style-lib.api #:stylesheet #:style-set)
  (:import-from :elmtui.ui.api #:component #:view #:id)
  (:import-from :split-sequence #:split-sequence))
(in-package :elmtui.view.tree-transforms)

;;; ----------------------------------------------------------------------
;;; Tree Transformation Pipeline Implementations
;;; ----------------------------------------------------------------------

(defmethod render-view ((app-state list) (root-component component))
  "High-level entry point of the view-pipeline (Stage 1).
  Calls the view method of the ROOT-COMPONENT with APP-STATE.
  Returns a raw UI-Node tree."
  (log:debug "TREE-TRANSFORMS: render-view - Root component ID: ~S" (id root-component))
  ;; Assuming the root component's view method returns a single ui-node or a list
  ;; which should be wrapped in a root list for the pipeline.
  (let ((raw-view (view root-component app-state :id-path `(:components ,(id root-component)))))
    (if (listp raw-view)
        raw-view ; If view already returns a list (e.g. multiple top-level for a fragment)
        (list raw-view)))) ; Wrap single node in a list

(defmethod apply-style ((raw-tree list) (stylesheet stylesheet))
  "Apply styles to the RAW-TREE using the STYLESHEET (Stage 2).
  Wraps elmtui.view.styled:apply-stylesheet-to-tree.
  Returns a new tree of styled-ui-nodes."
  (log:debug "TREE-TRANSFORMS: apply-style - Processing ~D raw top-level node(s)."
             (length raw-tree))
  (if (null raw-tree)
      nil
      ;; apply-stylesheet-to-tree expects a single root node or a list of nodes.
      ;; If raw-tree is a list of multiple top-level nodes, process each.
      ;; However, typically a component view should return a single root ui-node.
      ;; For now, assume apply-stylesheet-to-tree can handle a list of roots if necessary,
      ;; or that raw-tree will usually contain one root.
      (elmtui.view.styled:apply-stylesheet-to-tree (first raw-tree) stylesheet nil)
      ;; If apply-stylesheet-to-tree is designed for a single root, and raw-tree might have multiple:
      ;; (mapcar (lambda (node) (elmtui.view.styled:apply-stylesheet-to-tree node stylesheet nil))
      ;; raw-tree)
      ;; For now, assuming the pipeline expects a single root from render-view, wrapped in a list.
      ;; And apply-stylesheet-to-tree returns that single root, also styled.
      ;; So, the output should be a list containing one styled root node.
      ;; Let's adjust to return a list, consistent with other stages
      (list (elmtui.view.styled:apply-stylesheet-to-tree (first raw-tree) stylesheet nil))))

(defmethod resolve-view ((styled-tree list) (app-state list))
  "Resolve non-atomic nodes and apply style-driven transformations (Stage 3).
  STYLED-TREE is a list containing one styled root node.
  APP-STATE is the global application state, potentially needed by component view methods.
  Returns an atomic UI-Node tree (list containing one root atomic node)."
  (log:debug "TREE-TRANSFORMS: resolve-view - Processing ~D styled top-level node(s)."
             (length styled-tree))
  (labels ((resolve-node (item parent-id-path)
             (cond
               ((typep item 'component)
                (log:debug "TREE-TRANSFORMS: resolve-view - Resolving component ID: ~S" (id item))
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
                (log:warn "TREE-TRANSFORMS: resolve-view - Encountered a component ~S directly in styled-tree. This might indicate an issue in prior pipeline stages." (id item))
                item) ; Pass through if this unexpected case occurs

               ((typep item 'styled-ui-node)
                (log:debug "TREE-TRANSFORMS: resolve-view - Resolving styled-ui-node ID: ~S, Type: ~S"
                           (getf (ui-node-props item) :id) (ui-node-type item))
                (let* ((node-type (ui-node-type item))
                       (props (ui-node-props item))
                       (children (ui-node-children item))
                       (display-style (style-value item :display :block)) ; Default to block
                       (overflow-x (style-value item :overflow-x :visible))
                       (overflow-y (style-value item :overflow-y :visible))
                       (resolved-item item))

                  ;; 1. Handle :overflow style for scrollable content
                  (when (or (member overflow-x '(:scroll :auto :hidden))
                            (member overflow-y '(:scroll :auto :hidden)))
                    (log:debug "TREE-TRANSFORMS: resolve-view - Applying :overflow transformation for node ID: ~S" (getf props :id))
                    ;; Wrap children in a :viewport node.
                    ;; The original node becomes the container for this viewport.
                    (let* ((viewport-id (gensym "VIEWPORT-"))
                           (viewport-props `(:id ,viewport-id
                                             :overflow-x ,overflow-x
                                             :overflow-y ,overflow-y
                                             ;; Viewport itself might need some default styles or inherit relevant ones
                                             :style (:width :fill :height :fill))) ; Basic viewport style
                           (viewport-node (make-styled-node :type :viewport
                                                            :props viewport-props
                                                            :children children
                                                            ;; Parent of viewport is the original node, but this happens structurally
                                                            ))
                           ;; The original node now has the viewport as its single child.
                           (new-original-node (copy-styled-node resolved-item :children (list viewport-node))))
                      (setf resolved-item new-original-node)
                      ;; Children of the viewport are already set, they will be resolved in the recursive call later.
                      (setf children (list viewport-node)))) ; Update children for subsequent processing

                  ;; 2. Handle :display style (structural implications)
                  (cond
                    ((eq display-style :none)
                     (log:debug "TREE-TRANSFORMS: resolve-view - Node ID: ~S has display:none. Returning NIL." (getf props :id))
                     (return-from resolve-node nil)) ; Node and its children are not rendered

                    ((member display-style '(:flex :grid))
                     ;; Ensure the node type is suitable for flex/grid layout or transform it.
                     ;; For now, assume :layout node type is used for these, or that layout-view handles it.
                     ;; If the node is not already :layout, we could wrap its children or change its type.
                     ;; Let's assume layout-view will correctly interpret display:flex/grid on any styled-node.
                     ;; No structural change here, but layout-view will use this display property.
                     (log:debug "TREE-TRANSFORMS: resolve-view - Node ID: ~S has display:~A. No structural change, layout will handle." (getf props :id) display-style))

                    ((eq node-type :text-input) ; Example of resolving a complex component to simpler ones
                     ;; A text-input might resolve to a :drawable-content for text and a :cursor node
                     ;; This is more of a component's own view logic, but resolve-view could do it if needed.
                     ;; For now, assume :text-input is atomic enough or its view handles this.
                     )
                    ;; Add other type-specific resolutions here if needed.
                    )

                  ;; 3. Recursively resolve children of the (potentially transformed) node
                  (let ((resolved-children (loop for child in children
                                                 for resolved-child = (resolve-node child (cons (getf props :id) parent-id-path))
                                                 when resolved-child collect resolved-child)))
                    (if (eq children resolved-children) ; No change in children list
                        resolved-item ; Return original (or overflow-transformed) item
                        (copy-styled-node resolved-item :children resolved-children))))) ; Return copy with new children

               ((ui-node-p item) ; Plain ui-node, should ideally not happen after 'apply-style'
                (log:warn "TREE-TRANSFORMS: resolve-view - Encountered plain ui-node ~S. Should be styled-ui-node." item)
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


(defmethod layout-view ((atomic-tree list) (available-rect rectangle) (stylesheet stylesheet))
  "Compute absolute geometry for every node in ATOMIC-TREE (Stage 4).
  ATOMIC-TREE is assumed to be a list containing a single root UI-Node.
  AVAILABLE-RECT is the rectangle (border-box) for the root node.
  STYLESHEET is needed if layout decisions depend on re-querying styles (should be rare here).
  Returns a laid-out atomic UI-Node tree (list containing one root node).
  Each node in the returned tree will have a :layout-rect (its border-box) and a :box-model property."
  (log:debug "TREE-TRANSFORMS: layout-view - Processing ~D atomic top-level node(s). Available-rect: ~S"
             (length atomic-tree) available-rect)
  (declare (ignore stylesheet)) ; Stylesheet should have been fully applied by now.

  (labels (;; Helper to calculate box model for a node given its available space (border-box)
           (calculate-box-model (node parent-content-rect)
             (let* ((styled-node (if (typep node 'styled-ui-node) node
                                     (error "Layout-view expects styled-ui-nodes. Got: ~S" node)))
                    ;; Get padding values from the styled node
                    (pt (or (style-value styled-node :padding-top 0) 0))
                    (pr (or (style-value styled-node :padding-right 0) 0))
                    (pb (or (style-value styled-node :padding-bottom 0) 0))
                    (pl (or (style-value styled-node :padding-left 0) 0))
                    ;; Get border widths
                    (bt (if (eq (style-value styled-node :border-style :none) :none) 0 (or (style-value styled-node :border-top-width 0) 0)))
                    (br (if (eq (style-value styled-node :border-style :none) :none) 0 (or (style-value styled-node :border-right-width 0) 0)))
                    (bb (if (eq (style-value styled-node :border-style :none) :none) 0 (or (style-value styled-node :border-bottom-width 0) 0)))
                    (bl (if (eq (style-value styled-node :border-style :none) :none) 0 (or (style-value styled-node :border-left-width 0) 0)))

                    ;; Determine node's own border-box size based on its style and parent-content-rect
                    ;; This is where :width, :height, :min-width, :max-width, etc. styles are used
                    ;; For now, let's assume it takes up parent-content-rect space unless specified
                    ;; This part will be handled by the specific layout engines (flex, grid, block)
                    ;; Here, we are given the node's border-box (node-border-box argument to layout-node-internal)
                    ;; So, we use that to derive padding and content boxes.

                    (node-border-box parent-content-rect) ; This is the given available space for this node

                    (padding-rect (make-rectangle
                                   :x (+ (x node-border-box) bl)
                                   :y (+ (y node-border-box) bt)
                                   :w (max 0 (- (w node-border-box) bl br))
                                   :h (max 0 (- (h node-border-box) bt bb))))
                    (content-rect (make-rectangle
                                   :x (+ (x padding-rect) pl)
                                   :y (+ (y padding-rect) pt)
                                   :w (max 0 (- (w padding-rect) pl pr))
                                   :h (max 0 (- (h padding-rect) pt pb)))))
               (make-instance 'box-model
                              :border-box node-border-box
                              :padding-box padding-rect
                              :content-box content-rect)))

           (layout-node-internal (node current-available-rect parent-abs-pos)
             (if (typep node 'styled-ui-node)
                 (let* (;; Calculate the node's own border-box based on its styles and current-available-rect.
                        ;; This is the core of the specific layout engine (flex, grid, block).
                        ;; For now, we'll have a placeholder for block, and flex/grid will be called.
                        (display-type (style-value node :display :block))
                        (node-box-model nil) ; Will be set by specific layout logic
                        (laid-out-node-children nil))

                   ;; The actual layout calculation happens here, determining node-border-box-final
                   ;; For block layout (placeholder):
                   (let ((node-border-box-final current-available-rect)) ; Simplistic: takes all available space
                     (setf node-box-model (calculate-box-model node node-border-box-final))

                     ;; Recursively lay out children within this node's content-box
                     (let ((children-available-rect (content-box node-box-model)))
                       (setf laid-out-node-children
                             (loop for child in (ui-node-children node)
                                   collect (layout-node-internal child
                                                                 children-available-rect ; Each child gets the same content box for now (block)
                                                                 (make-rectangle :x (x children-available-rect)
                                                                                 :y (y children-available-rect)
                                                                                 :w 0 :h 0) ; Parent abs pos for children
                                                                 ))))

                     ;; Create a new node with layout information
                     (let ((new-props (copy-list (ui-node-props node))))
                       (setf (getf new-props :layout-rect) (border-box node-box-model)) ; Store the absolute border-box
                       (setf (getf new-props :box-model) node-box-model)
                       (make-styled-node :type (ui-node-type node)
                                         :props new-props
                                         :children laid-out-node-children
                                         ;; Need to ensure other styled-node slots are preserved
                                         :style-set (styles node) ; Preserve original style-set
                                         ;; sid, classes, parents-of, dirty should be copied by copy-styled-node if used
                                         ))))
                 node))) ; Non-styled-nodes pass through (should not happen here)

    (if (and atomic-tree (= 1 (length atomic-tree)) (typep (first atomic-tree) 'styled-ui-node))
        (let ((root-node (first atomic-tree)))
          ;; elmtui.view.layout:layout-tree is the main entry point for layout
          ;; It should handle the box model calculations internally and recursively.
          ;; The `layout-tree` function itself will call calculate-box-model or similar logic.
          (list (layout-tree root-node available-rect)))
        (progn
          (warn "LAYOUT-VIEW: Expected atomic-tree to be a list with a single styled root UI-Node. Got: ~A" atomic-tree)
          atomic-tree))))