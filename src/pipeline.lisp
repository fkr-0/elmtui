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
   #:display-buffer
   ;; Transformers
   #:dsl->raw-stage
   #:raw->styled-stage
   #:styled->atomic-stage
   #:atomic->layout-stage
   #:render-to-buffer-stage
   #:display-buffer-stage
   ;; Stages
   #:generate-dsl-stage
   #:dsl->raw-stage
   #:raw->styled-stage
   #:styled->atomic-stage
   ))

(in-package #:elmtui.pipeline)

;;; STAGE 0: Generate DSL from the component's view function
(define-stage generate-dsl
    (app-context app-context)
    (ctx)
  "Generates a DSL tree from the view function and model, storing it in the context."
  (let* ((view-fn (ctx-view-fn ctx)) ; assuming :state holds the model and view-fn
         (model (ctx-state ctx))
         (dsl (funcall view-fn model)))
    (setf (ctx-dsl-tree ctx) (make-dsl-tree :root dsl))
    ctx))

;; As transformers:
;; STAGE 0: Generate DSL from the component's view function
;; (deftransformer generate-dsl (nil) (dsl-tree)
;;                 (abc &key state view-fn)
;;   (make-dsl-tree :root (funcall view-fn state)))
;;; STAGE 1: DSL tree -> Raw tree (pure, typed)
(deftransformer ;; raw->styled (raw-tree) (styled-tree)
    dsl->raw (dsl-tree) (raw-tree)
    (dsl-tree &key state)
  "Transforms a DSL tree into a raw UI-node tree."
  (let ((dsl (root dsl-tree)))
    (labels ((expand-components (dsl parent-path)
               (if (and (consp dsl) (elmtui.app.api:registered-dsl-component-p (first dsl)))
                   (let* ((component-id (getf (cdr dsl) :id))
                          (id-path (append parent-path (list component-id)))
                          (full-id-path `(:components ,@id-path))
                          (instance (elmtui.app.api:get-component-instance full-id-path state)))
                     (if instance
                         (funcall #'expand-components (elmtui.ui.api:view instance state :id-path full-id-path)
                                  id-path)
                         (error "Component instance not found for ID ~A in state ~A" component-id state)))
                   (if (and (consp dsl) (getf (cdr dsl) :children))
                       (let* ((children (getf (cdr dsl) :children))
                              (expanded-children (mapcar (lambda (child-dsl)
                                                           (expand-components child-dsl parent-path))
                                                         children))
                              (new-dsl (copy-list dsl)))
                         (setf (getf (cdr new-dsl) :children) expanded-children)
                         new-dsl)
                       dsl))))
      (make-raw-tree :root (dsl->ui-node (expand-components dsl nil)
                                         state)))))


(deftransformer raw->styled (raw-tree) (styled-tree)
                (tree &key stylesheet)
  (make-styled-tree
   :root
   (elmtui.view.styled:apply-stylesheet-to-tree
    (root tree) stylesheet)))

;; STAGE 2: Apply styles to the raw UI-Node tree
;; (define-stage apply-styles
;;     (list list) ; context -> context
;;     (context)
;;   (let* ((raw-tree (getf context :tree))
;;          (stylesheet (getf context :stylesheet)))
;;     (if (and raw-tree stylesheet)
;;         (let ((styled-tree (elmtui.view.styled:apply-stylesheet-to-tree (root raw-tree) stylesheet)))
;;           (setf (getf context :tree) (make-styled-tree :root styled-tree)))
;;         (error "Raw tree or stylesheet not found in context"))))



;;; STAGE 2: Raw tree -> Styled tree (pure, typed)
;; (deftransform raw->styled (raw-tree) (styled-tree) (raw-tree)
;;   "Applies stylesheet to the raw tree."
;;   (let* ((raw (root raw-tree))
;;          (stylesheet (ctx-state *ctx*)) ; dynamic context if needed
;;          (styled (elmtui.view.styled:apply-stylesheet-to-tree raw stylesheet)))
;;     (make-styled-tree :root styled)))

;;; STAGE 3: Styled tree -> Atomic tree (pure, typed)
(deftransformer styled->atomic (styled-tree) (atomic-tree) (styled-tree &key state)
  "Resolves view (e.g., overflow, display: none) on the styled tree."
  (let* ((styled (root styled-tree))
         (app-state state)
         (atomic (resolve-view (list styled) app-state)))
    (make-atomic-tree :root (first atomic))))

;;; STAGE 4: Atomic tree -> Laid-out tree (pure, typed)
(deftransformer atomic->layout (atomic-tree) (laid-out-tree)
                (atomic-tree &key viewport-rect stylesheet)
  "Computes layout for the atomic tree."
  (let* ((atomic (root atomic-tree))
         (rect viewport-rect)
         ;; (stylesheet (ctx-state *ctx*))
         (laid-out (layout-view (list atomic) rect stylesheet)))
    (make-laid-out-tree :root (first laid-out))))

;;; STAGE 5: Render the laid-out tree to a virtual buffer (back buffer)
(define-stage render-to-buffer
    (app-context app-context)
    (ctx)
  "Renders the laid-out tree to a virtual buffer."
  (let* ((laid-out-tree (ctx-laid-out-tree ctx))
         (rect (ctx-viewport-rect ctx))
         (target-buffer (make-virtual-buffer (w rect) (h rect)))
         (rendered-buffer (render-laid-out-tree-to-buffer (list (root laid-out-tree)) :buffer target-buffer)))
    (setf (ctx-back-buffer ctx) rendered-buffer)
    ctx))

;;; STAGE 6: Display the back buffer, handling diffing.
(define-stage display-buffer
    (app-context app-context)
    (ctx)
  "Displays the back buffer, handling diffing and updating the front buffer."
  (let* ((back-buffer (ctx-back-buffer ctx))
         (front-buffer (ctx-front-buffer ctx))
         (backend (ctx-backend ctx))
         (origin-x 0)
         (origin-y 0))
    (let ((diff (elmtui.platform.backend.terminal.diff-renderer:compute-buffer-diff front-buffer back-buffer)))
      (elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend diff backend origin-x origin-y)
      (setf (ctx-front-buffer ctx) (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer back-buffer))
      ctx)))

;;; Compose stages 0-5 into a pipeline for rendering without display
(define-pipeline render-pipeline-0-to-5
  generate-dsl
  dsl->raw-stage
  raw->styled-stage
  styled->atomic-stage
  atomic->layout-stage
  render-to-buffer)

;;; Compose all stages into the full view pipeline
(define-pipeline full-view-pipeline
  generate-dsl
  dsl->raw-stage
  raw->styled-stage
  styled->atomic-stage
  atomic->layout-stage
  render-to-buffer
  display-buffer)
