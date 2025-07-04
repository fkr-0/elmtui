;;;===============================================================
;;; File: src/view/pipeline.lisp
;;; Consolidated View Rendering Pipeline
;;; Combines all pipeline functionality into a single, clear location
;;;===============================================================
(uiop:define-package :elmtui.view.pipeline
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
   ;; Main pipeline functions
   #:full-view-pipeline
   #:render-pipeline-without-display
   #:render-frame
   ;; Individual stage functions
   #:generate-dsl-stage
   #:render-dsl-stage
   #:apply-styles-stage
   #:resolve-view-stage
   #:layout-view-stage
   #:render-to-buffer-stage
   #:display-buffer-stage))

(in-package :elmtui.view.pipeline)

;;;--------------------------------------------------------------
;;; Pipeline Stage Definitions
;;;--------------------------------------------------------------

;; STAGE 0: Generate DSL from the component's view function
(define-stage generate-dsl-stage
    (list list) ; context -> context
    (context)
  "Generates DSL representation from view function and model"
  (let* ((view-fn (getf context :view-fn))
         (model (getf context :app-model))
         (dsl (funcall view-fn model)))
    (list* :tree dsl context)))

;; STAGE 1: Render DSL to a raw UI-Node tree
(define-stage render-dsl-stage
    (list list) ; context -> context
    (context)
  "Converts DSL representation to UI node tree"
  (let* ((dsl-tree (getf context :tree))
         (model (getf context :app-model))
         (raw-tree (dsl->ui-node dsl-tree model)))
    (list* :tree raw-tree context)))

;; STAGE 2: Apply styles to the raw UI-Node tree
(define-stage apply-styles-stage
    (list list) ; context -> context
    (context)
  "Applies stylesheet to UI node tree"
  (let* ((raw-tree (getf context :tree))
         (stylesheet (getf context :stylesheet))
         (styled-tree (apply-stylesheet-to-tree raw-tree stylesheet)))
    (list* :tree styled-tree context)))

;; STAGE 3: Resolve view (e.g., handle :overflow, :display: none)
(define-stage resolve-view-stage
    (list list) ; context -> context
    (context)
  "Resolves view properties like overflow, visibility, etc."
  (let* ((styled-tree (getf context :tree))
         (app-state (getf context :app-model))
         (atomic-tree (resolve-view (list styled-tree) app-state)))
    (list* :tree (first atomic-tree) context)))

;; STAGE 4: Layout view
(define-stage layout-view-stage
    (list list) ; context -> context
    (context)
  "Calculates layout and positioning for all elements"
  (let* ((atomic-tree (getf context :tree))
         (rect (getf context :viewport-rect))
         (stylesheet (getf context :stylesheet))
         (laid-out-tree (layout-view (list atomic-tree) rect stylesheet)))
    (list* :tree (first laid-out-tree) context)))

;; STAGE 5: Render the laid-out tree to a virtual buffer (back buffer)
(define-stage render-to-buffer-stage
    (list list) ; context -> context
    (context)
  "Renders the laid-out tree to a virtual buffer"
  (let* ((laid-out-tree (getf context :tree))
         (rect (getf context :viewport-rect))
         (target-buffer (make-virtual-buffer (w rect) (h rect)))
         (rendered-buffer (render-laid-out-tree-to-buffer (list laid-out-tree) :buffer target-buffer)))
    (list* :back-buffer rendered-buffer context)))

;; STAGE 6: Display the back buffer, handling diffing
(define-stage display-buffer-stage
    (list list) ; context -> context (with side-effects)
    (context)
  "Computes diff and applies changes to display backend"
  (let* ((back-buffer (getf context :back-buffer))
         (front-buffer (getf context :front-buffer))
         (backend (getf context :backend))
         (origin-x (getf context :origin-x 0))
         (origin-y (getf context :origin-y 0)))
    (let ((diff (compute-buffer-diff front-buffer back-buffer)))
      (apply-diff-to-backend diff backend origin-x origin-y)
      ;; The new front-buffer for the next frame is the current back-buffer
      (list* :front-buffer (copy-virtual-buffer back-buffer) context))))

;;;--------------------------------------------------------------
;;; Pipeline Compositions
;;;--------------------------------------------------------------

;; Compose stages 0-5 into a pipeline for rendering without display
(define-pipeline render-pipeline-without-display
  generate-dsl-stage
  render-dsl-stage
  apply-styles-stage
  resolve-view-stage
  layout-view-stage
  render-to-buffer-stage)

;; Compose all stages into the full view pipeline
(define-pipeline full-view-pipeline
  generate-dsl-stage
  render-dsl-stage
  apply-styles-stage
  resolve-view-stage
  layout-view-stage
  render-to-buffer-stage
  display-buffer-stage)

;; Alternative name for compatibility
(define-pipeline render-frame
  generate-dsl-stage
  render-dsl-stage
  apply-styles-stage
  resolve-view-stage
  layout-view-stage
  render-to-buffer-stage
  display-buffer-stage)

;;;--------------------------------------------------------------
;;; Pipeline Utilities
;;;--------------------------------------------------------------

(defun make-render-context (&key view-fn app-model stylesheet viewport-rect
                              backend front-buffer origin-x origin-y)
  "Creates a rendering context for pipeline execution"
  (list :view-fn view-fn
        :app-model app-model
        :stylesheet stylesheet
        :viewport-rect viewport-rect
        :backend backend
        :front-buffer front-buffer
        :origin-x (or origin-x 0)
        :origin-y (or origin-y 0)))

(defun validate-render-context (context)
  "Validates that a render context has all required fields"
  (unless (getf context :view-fn)
    (error "Render context missing :view-fn"))
  (unless (getf context :app-model)
    (error "Render context missing :app-model"))
  (unless (getf context :stylesheet)
    (error "Render context missing :stylesheet"))
  (unless (getf context :viewport-rect)
    (error "Render context missing :viewport-rect")))

(defun execute-pipeline-stage (stage-name context)
  "Executes a single pipeline stage by name"
  (ecase stage-name
    (:generate-dsl (generate-dsl-stage context))
    (:render-dsl (render-dsl-stage context))
    (:apply-styles (apply-styles-stage context))
    (:resolve-view (resolve-view-stage context))
    (:layout-view (layout-view-stage context))
    (:render-to-buffer (render-to-buffer-stage context))
    (:display-buffer (display-buffer-stage context))))

;;;--------------------------------------------------------------
;;; Development & Debugging Support
;;;--------------------------------------------------------------

(defvar *pipeline-debugging* nil
  "Enable pipeline debugging and stage timing")

(defvar *stage-timings* nil
  "Log of pipeline stage execution times")

(defun enable-pipeline-debugging (&optional (enabled t))
  "Enable/disable pipeline debugging"
  (setf *pipeline-debugging* enabled)
  (when enabled
    (setf *stage-timings* nil)))

(defmacro with-stage-timing (stage-name &body body)
  "Times execution of pipeline stage"
  `(if *pipeline-debugging*
       (let ((start-time (get-internal-real-time)))
         (prog1 (progn ,@body)
           (let ((end-time (get-internal-real-time)))
             (push (list :stage ',stage-name
                         :duration (/ (- end-time start-time)
                                      internal-time-units-per-second))
                   *stage-timings*))))
       (progn ,@body)))

(defun get-pipeline-performance-report ()
  "Returns performance report for pipeline stages"
  (when *stage-timings*
    (let ((report (make-hash-table :test 'eq)))
      (dolist (timing *stage-timings*)
        (let ((stage (getf timing :stage))
              (duration (getf timing :duration)))
          (push duration (gethash stage report))))

      ;; Calculate averages
      (maphash (lambda (stage durations)
                 (setf (gethash stage report)
                       (list :count (length durations)
                             :total (reduce #'+ durations)
                             :average (/ (reduce #'+ durations) (length durations))
                             :min (reduce #'min durations)
                             :max (reduce #'max durations))))
               report)

      report)))

;;;--------------------------------------------------------------
;;; Error Recovery & Resilience
;;;--------------------------------------------------------------

(define-condition pipeline-execution-error (error)
  ((stage :initarg :stage :reader pipeline-error-stage)
   (context :initarg :context :reader pipeline-error-context)
   (original-error :initarg :original-error :reader pipeline-error-original))
  (:report (lambda (condition stream)
             (format stream "Pipeline execution failed at stage ~A: ~A"
                     (pipeline-error-stage condition)
                     (pipeline-error-original condition)))))

(defun execute-pipeline-with-recovery (pipeline context &key recovery-strategy)
  "Executes pipeline with error recovery options"
  (let ((current-context context))
    (dolist (stage-fn pipeline)
      (handler-case
          (setf current-context
                (with-stage-timing (stage-fn)
                  (funcall stage-fn current-context)))
        (error (e)
          (case recovery-strategy
            (:skip-stage
             (warn "Skipping failed stage ~A: ~A" stage-fn e))
            (:use-fallback
             (setf current-context (apply-fallback-stage stage-fn current-context e)))
            (t
             (error 'pipeline-execution-error
                    :stage stage-fn
                    :context current-context
                    :original-error e))))))
    current-context))

(defun apply-fallback-stage (failed-stage-fn context error)
  "Applies fallback behavior for failed pipeline stage"
  (declare (ignore failed-stage-fn error))
  ;; Simple fallback: return context unchanged
  (warn "Using fallback: returning context unchanged")
  context)
