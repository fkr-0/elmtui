(uiop:define-package :elmtui.pipeline
  (:use :cl :elmtui.contracts)
  (:import-from :elmtui.view.dsl #:dsl->ui-node)
  (:import-from :elmtui.view.styled #:apply-stylesheet-to-tree)
  (:import-from :elmtui.view.tree-transforms #:resolve-view #:layout-view)
  (:import-from :elmtui.platform.tree-renderer #:render-laid-out-tree-to-buffer)
  (:import-from :elmtui.platform.backend.common.virtual-buffer #:make-virtual-buffer #:copy-virtual-buffer)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer #:compute-buffer-diff #:apply-diff-to-backend)
  (:import-from :elmtui.view.geo #:w #:h #:make-rectangle)
  (:import-from :elmtui.style-lib.api #:stylesheet)
  (:import-from :elmtui.view.core #:ui-node)
  (:import-from :elmtui.view.styled #:styled-ui-node)
  (:export
   #:full-view-pipeline
   #:render-pipeline-0-to-5
   #:generate-dsl
   #:render-dsl
   #:apply-styles
   #:resolve-view-stage
   #:layout-view-stage
   #:render-to-buffer
   #:display-buffer))

(in-package #:elmtui.pipeline)

;; STAGE 0: Generate DSL from the component's view function
(define-stage generate-dsl
    (list list) ; context -> context
    (context)
  (let* ((view-fn (getf context :view-fn))
         (model (getf context :app-model))
         (dsl (funcall view-fn model)))
    (let ((new-context (copy-list context)))
      (setf (getf new-context :tree) dsl)
      new-context)))

;; STAGE 1: Render DSL to a raw UI-Node tree
(define-stage render-dsl
    (list list) ; context -> context
    (context)
  (let* ((dsl-tree (getf context :tree))
         (model (getf context :app-model)))
    (labels ((expand-components (dsl)
               (if (and (consp dsl) (elmtui.app.api:get-component-class-for-dsl-type (first dsl)))
                   (let* ((component-id (getf (cdr dsl) :id))
                          (id-path `(:components ,component-id))
                          (instance (elmtui.app.api:get-component-instance id-path model)))
                     (if instance
                         (expand-components (elmtui.ui.api:view instance model :id-path id-path))
                         (error "Component instance not found for ID ~A in state ~A" component-id model)))
                   (if (and (consp dsl) (getf (cdr dsl) :children))
                       (let* ((children (getf (cdr dsl) :children))
                              (expanded-children (mapcar #'expand-components children))
                              (new-dsl (copy-list dsl)))
                         (setf (getf (cdr new-dsl) :children) expanded-children)
                         new-dsl)
                       dsl))))
      (let* ((expanded-dsl (expand-components dsl-tree))
             (raw-tree (dsl->ui-node expanded-dsl model)))
        (setf (getf context :tree) raw-tree))
      context
      ;; (let ((new-context (copy-list context)))
      ;;   (setf (getf new-context :tree) raw-tree)
      ;;   new-context)
      )))

;; STAGE 2: Apply styles to the raw UI-Node tree
(define-stage apply-styles
    (list list) ; context -> context
    (context)
  (let* ((raw-tree (getf context :tree))
         (stylesheet (getf context :stylesheet))
         (styled-tree
           (elmtui.view.styled:apply-stylesheet-to-tree raw-tree stylesheet)))
    (if raw-tree
        (let ((new-context (copy-list context)))
          (setf (getf new-context :tree) styled-tree)
          new-context)
        context)))

;; STAGE 3: Resolve view (e.g., handle :overflow, :display: none)
(define-stage resolve-view-stage
    (list list) ; context -> context
    (context)
  (let* ((styled-tree (getf context :tree))
         (app-state (getf context :app-model))
         (atomic-tree (resolve-view (list styled-tree) app-state)))
    (let ((new-context (copy-list context)))
      (setf (getf new-context :tree) (first atomic-tree))
      new-context)))

;; STAGE 4: Layout view
(define-stage layout-view-stage
    (list list) ; context -> context
    (context)
  (let* ((atomic-tree (getf context :tree))
         (rect (getf context :viewport-rect))
         (stylesheet (getf context :stylesheet))
         (laid-out-tree (layout-view (list atomic-tree) rect stylesheet)))
    (let ((new-context (copy-list context)))
      (setf (getf new-context :tree) (first laid-out-tree))
      new-context)))

;; STAGE 5: Render the laid-out tree to a virtual buffer (back buffer)
(define-stage render-to-buffer
    (list list) ; context -> context
    (context)
  (let* ((laid-out-tree (getf context :tree))
         (rect (getf context :viewport-rect))
         (target-buffer (make-virtual-buffer (w rect) (h rect)))
         (rendered-buffer (render-laid-out-tree-to-buffer (list laid-out-tree) :buffer target-buffer)))
    (let ((new-context (copy-list context)))
      (setf (getf new-context :back-buffer) rendered-buffer)
      new-context)))

;; STAGE 6: Display the back buffer, handling diffing.
(define-stage display-buffer
    (list list) ; context -> context (with side-effects)
    (context)
  (let* ((back-buffer (getf context :back-buffer))
         (front-buffer (getf context :front-buffer))
         (backend (getf context :backend))
         (origin-x (getf context :origin-x 0))
         (origin-y (getf context :origin-y 0)))
    (let ((diff (elmtui.platform.backend.terminal.diff-renderer:compute-buffer-diff front-buffer back-buffer)))
      (elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend diff backend origin-x origin-y)
      ;; The new front-buffer for the next frame is the current back-buffer
      (let ((new-context (copy-list context)))
        (setf (getf new-context :front-buffer) (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer back-buffer))
        new-context))))

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
  display-buffer)
