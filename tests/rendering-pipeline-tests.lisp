(uiop:define-package :elmtui.tests.rendering-pipeline
  (:use :cl :fiveam :elmtui.contracts :elmtui.pipeline)
  (:import-from :elmtui.view.core #:ui-node-p)
  (:import-from :elmtui.view.styled #:styled-ui-node-p)
  (:import-from :elmtui.pipeline
                #:generate-dsl)

  (:import-from :elmtui.view.geo #:make-rectangle #:w #:h #:rectangle #:make-size
                #:make-pos)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer-p
                #:make-virtual-buffer)
  (:import-from :elmtui.examples.rainbow-app
                #:rainbow-content-view
                #:rainbow-stylesheet))
(in-package :elmtui.tests.rendering-pipeline)

(def-suite rendering-pipeline-suite
  :in elmtui.tests:elmtui-test
  :description "Tests for the rendering pipeline contracts.")
(in-suite rendering-pipeline-suite)

;; (defun setup-test-context (&optional (width 80) (height 24))
;;   "Helper to create a default context for pipeline tests."
;;   (let ((app-state
;;           (elmtui.tests.application-init:initialize-app-state-test-init-app
;;            :initial-terminal-dimensions (list width height)
;;            :initial-cursor-position (list 0 0))))
;;     (make-app-context
;;      :state app-state
;;      :viewport-rect (make-rectangle
;;                      :size (make-size :w width :h height)
;;                      :pos (make-pos :x 0 :y 0))
;;      :front-buffer (make-virtual-buffer width height)
;;      :backend nil)))
(defun setup-test-context (&optional (width 80) (height 24))
  "Helper to create a default context for pipeline tests."
  (declare (ignorable width height))
  (multiple-value-bind (app-state commands)
      (elmtui.examples.rainbow-app:initialize-app-state-rainbow-example-app
       :initial-terminal-dimensions (list 80 24)
       :initial-cursor-position (list 0 0))
    (declare (ignore commands))
    (make-app-context
     :state app-state
     :viewport-rect (make-rectangle
                     :size (make-size :h 24 :w 80) ;;width :h height)
                     :pos (make-pos :x 0 :y 0))
     :front-buffer (make-virtual-buffer 80 24)
     :view-fn #'elmtui.examples.rainbow-app:rainbow-content-view
     :backend nil)
    ;; app-state
    ))
;; (setup-test-context)
;; (setup-test-context)

(test rainbow-app-example-state
  "Tests the initial state of the rainbow app example."
  (let ((context (setup-test-context)))
    (is-true (ctx-state context) "Context should have an application state.")
    (is-true (elmtui.tea-state.api:application-state-p (ctx-state context)) "Context state should be a valid app state.")
    (is-true (ctx-viewport-rect context) "Context should have a viewport rectangle.")
    (is-true (ctx-front-buffer context) "Context should have a front buffer.")
    (is-true (virtual-terminal-buffer-p (ctx-front-buffer context))
             "Front buffer should be a virtual-terminal-buffer.")))

(test full-pipeline-macro-execution
  "Tests the entire full-view-pipeline from DSL generation to buffer rendering."
  (let* ((initial-context (setup-test-context))
         (final-context (render-pipeline-0-to-5 initial-context)))
    (is-true (ctx-laid-out-tree final-context) "Pipeline should produce a laid-out tree.")
    (is-true (ctx-back-buffer final-context) "Pipeline should produce a back-buffer.")
    (is (typep (ctx-back-buffer final-context) 'elmtui.platform.backend.common.virtual-buffer:virtual-terminal-buffer)
        "The back-buffer should be a virtual-terminal-buffer.")))

(let ((styled-context
        (styled->atomic-stage (raw->styled-stage (dsl->raw-stage (generate-dsl (setup-test-context )))))))
  (atomic->layout-stage
   styled-context)
  )
;; (test styled->atomic-stage-contract
;;   "Tests that styled->atomic-stage produces an atomic-tree from a styled-tree."
;;   (is (typep (ctx-atomic-tree styled-context) 'atomic-tree)
;;       "styled->atomic-stage should produce an atomic-tree struct.")))

(test pipeline-step-by-step-transformation
  "Tests each stage of the rendering pipeline individually."
  (let ((context (setup-test-context )))
    ;; Stage 0: Generate DSL
    ;; (let ((ctx-after-dsl ( context)))
    (let ((ctx-after-dsl (generate-dsl context)))
      ;; ctx-after-dsl))
      ;; (is (typep (ctx-dsl-tree ctx-after-dsl) 'dsl-tree) "generate-dsl should add a dsl-tree struct to the context.")
      ;; (is (eq :container (first (root (ctx-dsl-tree ctx-after-dsl))))
      ;;     "The root of the DSL should be a :column.")
      (setf context ctx-after-dsl))

    ;; Stage 1: DSL -> Raw
    (let ((ctx-after-raw (dsl->raw-stage context)))
      ;; context))
      (is (typep (ctx-raw-tree ctx-after-raw) 'raw-tree)
          "dsl->raw-stage should produce a raw-tree struct.")
      (setf context ctx-after-raw))

    ;; Stage 2: Raw -> Styled
    (let ((ctx-after-styled (raw->styled-stage context)))
      (is (typep (ctx-styled-tree ctx-after-styled) 'styled-tree)
          "raw->styled-stage should produce a styled-tree struct.")
      (setf context ctx-after-styled))

    ;; Stage 3: Styled -> Atomic
    (let ((ctx-after-atomic (styled->atomic-stage context)))
      (is (typep (ctx-atomic-tree ctx-after-atomic) 'atomic-tree) "styled->atomic-stage should produce an atomic-tree struct.")
      (setf context ctx-after-atomic))

    ;; Stage 4: Atomic -> Laid-out
    (let ((ctx-after-layout (atomic->layout-stage context)))
      (is (typep (ctx-laid-out-tree ctx-after-layout) 'laid-out-tree) "atomic->layout-stage should produce a laid-out-tree struct.")
      (setf context ctx-after-layout))

    ;; Stage 5: Render to Buffer
    (let ((ctx-after-render-buffer (render-to-buffer context)))
      (is (virtual-terminal-buffer-p (ctx-back-buffer ctx-after-render-buffer))
          "render-to-buffer should produce a virtual-terminal-buffer in :back-buffer.")
      (setf context ctx-after-render-buffer))

    ;; Stage 6: Display Buffer (simulated)
    (let ((ctx-after-display (display-buffer context)))
      (is (virtual-terminal-buffer-p (ctx-front-buffer ctx-after-display))
          "display-buffer should place a new buffer in :front-buffer."))))
(test dsl->raw-contract-violation
  "Should signal pipeline-contract-violation if dsl->raw-stage receives a non-dsl-tree input."
  (let ((bad-context (make-app-context :dsl-tree 42)))
    (signals elmtui.contracts:pipeline-contract-violation
      (dsl->raw-stage bad-context))))
