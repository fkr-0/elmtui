(uiop:define-package :elmtui.pipeline
  (:use :cl :elmtui.contracts)
  (:import-from :elmtui.view.dsl #:dsl->ui-node)
  (:import-from #:elmtui.utils #:split-props/children)
  (:import-from #:log4cl :log-info)
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
(defun make-component-path (parent-path component-id)
  "Return a canonical [:components …] path.
   Guarantees that :components appears exactly *once* at the head."
  (cond
    ;; first level – we are not inside any component yet
    ((null parent-path)
     (list :components component-id))

    ;; already inside the component subtree
    ((eq (first parent-path) :components)
     (append parent-path (list component-id)))

    ;; defensive fallback – shouldn’t happen, but stays correct
    (t
     (append (list :components) parent-path (list component-id)))))

(deftransformer ;; raw->styled (raw-tree) (styled-tree)
    dsl->raw (dsl-tree) (raw-tree)
    (dsl-tree &key state)
  "Transforms a DSL tree into a raw UI-node tree."
  (make-raw-tree
   :root
   (dsl->ui-node (root dsl-tree) state)))


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
         (laid-out (layout-view (list atomic)
                                :available-rect rect
                                :stylesheet stylesheet)))
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

;; (deftransformer render-to-buffer-stage (laid-out-tree) (virtual-buffer)
;;                 (laid-out-tree &key viewport-rect)
;;   "Renders the laid-out tree to a virtual buffer."
;;   (let* ((rect viewport-rect)
;;          (target-buffer (make-virtual-buffer (w rect) (h rect)))
;;          (rendered-buffer
;;            (render-laid-out-tree-to-buffer
;;             (list (root laid-out-tree))
;;             :buffer target-buffer)))
;;     rendered-buffer))

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
    (if (and backend (open-stream-p (elmtui.platform.api:term-stream backend)))
        (let ((diff (elmtui.platform.backend.terminal.diff-renderer:compute-buffer-diff front-buffer back-buffer)))
          (elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend diff backend origin-x origin-y)
          (elmtui.platform.api:flush-output backend)
          (setf (ctx-front-buffer ctx) (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer back-buffer))
          ctx)
        (progn
          (log:warn "PIPELINE: Display-buffer skipped as backend stream is closed.")
          ctx))))

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
