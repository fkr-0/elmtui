
(in-package #:elmtui.contracts)

;; This file defines the stages of the rendering pipeline using a context-passing style.
;; Each stage is a function that takes a context (plist) and returns an updated context.

;; Define a more specific type for the atomic node if needed for clarity
(defclass atomic-ui-node (styled-ui-node) ())

;; STAGE 0: Generate DSL from the component's view function
(define-stage generate-dsl
    (list list) ; context -> context
    (context)
  (let* ((view-fn (getf context :view-fn))
         (model (getf context :app-model))
         (dsl (funcall view-fn model)))
    (list* :tree dsl context)))

;; STAGE 1: Render DSL to a raw UI-Node tree
(define-stage render-dsl
    (list list) ; context -> context
    (context)
  (let* ((dsl-tree (getf context :tree))
         (model (getf context :app-model))
         (raw-tree (dsl->ui-node dsl-tree model)))
    (list* :tree raw-tree context)))

;; STAGE 2: Apply styles to the raw UI-Node tree
(define-stage apply-styles
    (list list) ; context -> context
    (context)
  (let* ((raw-tree (getf context :tree))
         (stylesheet (getf context :stylesheet))
         (styled-tree (elmtui.view.styled:apply-stylesheet-to-tree raw-tree stylesheet)))
    (list* :tree styled-tree context)))

;; STAGE 3: Resolve view (e.g., handle :overflow, :display: none)
(define-stage resolve-view-stage
    (list list) ; context -> context
    (context)
  (let* ((styled-tree (getf context :tree))
         (app-state (getf context :app-model))
         (atomic-tree (resolve-view (list styled-tree) app-state)))
    (list* :tree (first atomic-tree) context)))

;; STAGE 4: Layout view
(define-stage layout-view-stage
    (list list) ; context -> context
    (context)
  (let* ((atomic-tree (getf context :tree))
         (rect (getf context :viewport-rect))
         (stylesheet (getf context :stylesheet))
         (laid-out-tree (layout-view (list atomic-tree) rect stylesheet)))
    (list* :tree (first laid-out-tree) context)))

;; STAGE 5: Render the laid-out tree to a virtual buffer (back buffer)
(define-stage render-to-buffer
    (list list) ; context -> context
    (context)
  (let* ((laid-out-tree (getf context :tree))
         (rect (getf context :viewport-rect))
         (target-buffer (make-virtual-buffer (w rect) (h rect)))
         (rendered-buffer (render-laid-out-tree-to-canvas laid-out-tree target-buffer)))
    (list* :back-buffer rendered-buffer context)))

;; Compose stages 0-5 into a pipeline for rendering without display
(define-pipeline render-pipeline-0-to-5
    generate-dsl
    render-dsl
    apply-styles
    resolve-view-stage
    layout-view-stage
    render-to-buffer)

;; Compose all stages into the full view pipeline
(define-pipeline full-view-pipeline
    generate-dsl
    render-dsl
    apply-styles
    resolve-view-stage
    layout-view-stage
    render-to-buffer
    display-buffer) ; Defined in stages-6.lisp
