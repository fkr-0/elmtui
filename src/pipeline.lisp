(uiop:define-package :elmtui.pipeline
  (:use :cl :elmtui.contracts)
  (:import-from #:elmtui.utils #:split-props/children)
  (:import-from #:log4cl :log-debug)
  (:import-from :elmtui.view.styled #:apply-stylesheet-to-tree)
  (:import-from :elmtui.platform.tree-renderer #:render-laid-out-tree-to-buffer)
  (:import-from :elmtui.view.tree-transforms #:process-tree)
  (:import-from :elmtui.platform.backend.common.virtual-buffer #:make-virtual-buffer #:copy-virtual-buffer)
  (:import-from :elmtui.contracts #:define-stage)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer #:compute-buffer-diff #:apply-diff-to-backend)
  (:import-from :elmtui.view.geo #:w #:h #:make-rectangle #:make-pos #:make-size)
  (:import-from :elmtui.utils #:get-path)
  ;; (:import-from :elmtui.style-lib.api #:stylesheet) ; legacy
  (:import-from :elmtui.view.core #:ui-node)
  ;; (:import-from :elmtui.view.tree-transforms #:process-tree)
  (:import-from :elmtui.view.styled #:styled-ui-node)
  (:export
    #:full-view-pipeline
    #:render-pipeline-0-to-5
    #:pre-render-terminal-prep
    #:generate-dsl
    #:process-tree-stage
    #:render-dsl
    #:apply-styles
    #:resolve-view-stage
    #:layout-view-stage
    #:render-to-buffer
    #:display-buffer
    ;; Transformers
    #:styled->atomic-stage
    #:atomic->layout-stage
    #:render-to-buffer-stage
    #:display-buffer-stage
    ;; Stages
    #:generate-dsl-stage
    #:styled->atomic-stage
    ))

(in-package #:elmtui.pipeline)

(defun %root-viewport-offset (ctx)
  "Return (values offset-x offset-y) for the root viewport, defaulting to 0."
  (let* ((state (ctx-state ctx))
          (rv-path (%root-viewport-id-path ctx)))
    (if (and state rv-path)
      (let* ((st-path (append rv-path '(:state)))
              (ox (or (get-path (append st-path '(:offset-x)) state 0) 0))
              (oy (or (get-path (append st-path '(:offset-y)) state 0) 0)))
        (values ox oy))
      (values 0 0))))

(defun %root-viewport-id-path (ctx)
  "Return the root viewport id-path when it can be derived from the DSL or driver."
  (or (%root-viewport-id-path-from-dsl ctx)
    (%root-viewport-id-path-from-driver)))

(defun %root-viewport-id-path-from-dsl (ctx)
  (let* ((tree (ctx-dsl-tree ctx))
          (dsl (and tree (root tree))))
    (when (and (consp dsl) (keywordp (first dsl)))
      (multiple-value-bind (props children)
        (split-props/children (rest dsl))
        (declare (ignore children))
        (let ((id (getf props :id)))
          (when id
            (list :components id)))))))

(defun %root-viewport-id-path-from-driver ()
  (let* ((pkg (find-package :elmtui.platform.driver))
          (sym (and pkg (find-symbol "*ROOT-VIEWPORT-ID-PATH*" pkg)))
          (rv-path (and sym (boundp sym) (symbol-value sym))))
    rv-path))

(defun %root-viewport-rect (ctx)
  "Return a viewport rect sized to the root viewport state, clamped to the terminal."
  (let* ((rect (ctx-viewport-rect ctx))
          (state (ctx-state ctx))
          (rv-path (%root-viewport-id-path ctx)))
    (if (and rect state rv-path)
      (let* ((st-path (append rv-path '(:state)))
              (desired-w (get-path (append st-path '(:width)) state nil))
              (desired-h (get-path (append st-path '(:height)) state nil))
              (w* (if (and (numberp desired-w) (> desired-w 0))
                    (min desired-w (w rect))
                    (w rect)))
              (h* (if (and (numberp desired-h) (> desired-h 0))
                    (min desired-h (h rect))
                    (h rect))))
        (make-rectangle :pos (make-pos :x 0 :y 0)
          :size (make-size :w w* :h h*)))
      rect)))

;;; STAGE 0: Generate DSL from the component's view function
(define-stage generate-dsl
  (app-context app-context)
  (ctx)
  "Generates a DSL tree from the view function and model, storing it in the context."
  (let* ((view-fn (ctx-view-fn ctx))
          (model (ctx-state ctx))
          (dsl (funcall view-fn model)))
    (if (null dsl)
      (progn
        (log:debug "PIPELINE: View returned NIL; skipping tree processing this frame.")
        (setf (ctx-laid-out-tree ctx) nil)
        ctx)
      (progn
        (setf (ctx-dsl-tree ctx) (make-dsl-tree :root dsl))
        (let ((viewport-rect (%root-viewport-rect ctx)))
          (setf (ctx-viewport-rect ctx) viewport-rect)
          (setf (ctx-laid-out-tree ctx)
            (make-laid-out-tree
              :root
              (elmtui.view.tree-transforms:process-tree
                dsl
                :ctx ctx
                :root-rect viewport-rect))))
        ctx))))

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


(defun summarize-dsl-root (dsl)
  "Return a compact description of a DSL root node for logging."
  (cond
    ((and (consp dsl) (keywordp (first dsl)))
      (multiple-value-bind (props children) (split-props/children (rest dsl))
        (let* ((id (getf props :id))
                (child-list (cond
                              ((null children) nil)
                              ((listp children) children)
                              (t (list children))))
                (child-count (length child-list)))
          (format nil "~(~a~)~@[ id=~a~] (~d child~:p)"
            (first dsl) id child-count))))
    ((null dsl) "NIL")
    (t (format nil "~A" (type-of dsl)))))

;;; STAGE 5: Render the laid-out tree to a virtual buffer (back buffer)
(define-stage render-to-buffer
  (app-context app-context)
  (ctx)
  "Renders the laid-out tree to a virtual buffer."
  (let* ((laid-out-tree (ctx-laid-out-tree ctx)))
    (if (null laid-out-tree)
      (progn
        (log:debug "PIPELINE: No laid-out tree; skipping render-to-buffer.")
        ctx)
      (let* ((rect (ctx-viewport-rect ctx))
              (target-buffer (make-virtual-buffer (w rect) (h rect)))
              (rendered-buffer (render-laid-out-tree-to-buffer
                                 (list (root laid-out-tree))
                                 :buffer target-buffer)))
        (setf (ctx-back-buffer ctx) rendered-buffer)
        ctx))))

;;; STAGE: Pre-render terminal preparation (anchoring/scroll)
(define-stage pre-render-terminal-prep
  (app-context app-context)
  (ctx)
  "Apply terminal operations prior to rendering (scroll, clear-below-cursor) based on root-viewport state."
  (let* ((backend (ctx-backend ctx))
          ;; (state (ctx-state ctx))
          ;; (rv-path (or elmtui.platform.driver::*root-viewport-id-path* nil))
          )
    (log-debug "PIPELINE: Pre-render terminal prep with backend ~A" backend );rv-path)
    ;; (when (and backend rv-path)
    ;;   (let* ((st-path (append rv-path '(:state)))
    ;;          (pending (ignore-errors (elmtui.state:get-path st-path state :pending-scroll))))
    ;;     (declare (ignore pending))
    ;;     ;; If we had a reliable pending-scroll in state, we could read it here.
    ;;     ;; However, the backend terminal already tracks scrolled lines; we can
    ;;     ;; still clear below cursor when anchored below.
    ;;     (ignore-errors (elmtui.platform.api:clear-below-cursor backend))))
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
(defun %backend-ready-for-display-p (backend)
  "Return true when BACKEND appears writable for display."
  (when backend
    (let ((stream (ignore-errors (elmtui.platform.api:term-stream backend))))
      (cond
        ((and stream (ignore-errors (open-stream-p stream))) t)
        ((typep backend 'elmtui.platform.backend.terminal:terminal-instance)
          (and (elmtui.platform.backend.terminal:terminal-instance-cl-device backend) t))
        (t nil)))))

(define-stage display-buffer
  (app-context app-context)
  (ctx)
  "Displays the back buffer, handling diffing and updating the front buffer."
  (let* ((back-buffer (ctx-back-buffer ctx))
          (front-buffer (ctx-front-buffer ctx))
          (backend (ctx-backend ctx))
          (origin-x 0)
          (origin-y 0))
    (if (and back-buffer (%backend-ready-for-display-p backend))
      (multiple-value-bind (ox oy)
        (%root-viewport-offset ctx)
        (setf origin-x ox
          origin-y oy)
        (when (or (/= (elmtui.platform.backend.common.virtual-buffer:buffer-width front-buffer)
                    (elmtui.platform.backend.common.virtual-buffer:buffer-width back-buffer))
                (/= (elmtui.platform.backend.common.virtual-buffer:buffer-height front-buffer)
                  (elmtui.platform.backend.common.virtual-buffer:buffer-height back-buffer)))
          (setf front-buffer
            (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer
              (elmtui.platform.backend.common.virtual-buffer:buffer-width back-buffer)
              (elmtui.platform.backend.common.virtual-buffer:buffer-height back-buffer))))
        (let ((diff (elmtui.platform.backend.terminal.diff-renderer:compute-buffer-diff front-buffer back-buffer)))
          (log:debug "PIPELINE: Displaying buffer with diff: ~A" (length diff))
          (elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend diff backend origin-y origin-x)
          (elmtui.platform.api:flush-output backend)
          (setf (ctx-front-buffer ctx) (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer back-buffer))
          ctx))
      (progn
        (log:warn "PIPELINE: Display-buffer skipped as backend is not ready for output.")
        ctx))))

;;; Compose stages 0-5 into a pipeline for rendering without display
(define-pipeline render-pipeline-0-to-5
  process-tree-stage
  pre-render-terminal-prep
  render-to-buffer)

;;; Compose all stages into the full view pipeline
(define-pipeline full-view-pipeline
  process-tree-stage
  pre-render-terminal-prep
  render-to-buffer
  display-buffer)

(define-stage process-tree-stage
  (t app-context)
  (app-ctx )
  ;; NOTE: this stage *replaces* the following former steps in your common pipeline:
  ;;   - in-tree DSL resolution (plist -> objects) if it ran there
  ;;   - any ad-hoc stylegroup expansion on nodes
  ;;   - ad-hoc semantic wrappers (e.g., padding wrappers)
  ;;   - bottom-up measurement
  ;;   - bottom-up layout
  ;;   - dirty flag marking

  ;; Be defensive: only operate on a valid app-context; otherwise propagate unchanged
  (unless (typep app-ctx 'elmtui.contracts:app-context)
    (return-from process-tree-stage app-ctx))
  (let* ((view-fn (ctx-view-fn app-ctx)) ; assuming :state holds the model and view-fn
          (model (ctx-state app-ctx))
          (dsl (funcall view-fn model)))
    (if (null dsl)
      (progn
        (log:debug "PIPELINE: View returned NIL; skipping tree processing this frame.")
        (setf (ctx-laid-out-tree app-ctx) nil)
        app-ctx)
      (progn
        (log:debug "PIPELINE: Processing DSL root ~A" (summarize-dsl-root dsl))
        (let* ((viewport-rect (%root-viewport-rect app-ctx))
                (root (elmtui.view.tree-transforms:process-tree
                        dsl
                        :ctx app-ctx
                        :root-rect viewport-rect)))
          (setf (ctx-viewport-rect app-ctx) viewport-rect)
          (if root
            (setf (ctx-laid-out-tree app-ctx)
              (make-laid-out-tree :root root))
            (progn
              (log:debug "PIPELINE: Tree processing returned NIL; skipping frame.")
              (setf (ctx-laid-out-tree app-ctx) nil))))
        app-ctx))))
