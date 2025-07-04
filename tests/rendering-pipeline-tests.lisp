(uiop:define-package :elmtui.tests.rendering-pipeline
  (:use :cl :fiveam :elmtui.pipeline)
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

(defun setup-test-context (&optional (width 80) (height 24))
  "Helper to create a default context for pipeline tests."
  (let ((app-state (elmtui.tests.application-init:initialize-app-state-test-init-app
                    :initial-terminal-dimensions (list width height)
                    :initial-cursor-position (list 0 0))))
    (list
     :app-model app-state
     :view-fn (fdefinition 'elmtui.tests.application-init::test-init-app-view)
     :stylesheet rainbow-stylesheet
     :viewport-rect (make-rectangle :size (make-size :w width :h height) :pos (make-pos :x 0 :y 0) )
     :front-buffer (make-virtual-buffer width height)
     :backend nil ; Not needed for most stages
     :origin-x 0
     :origin-y 0)))

(test full-pipeline-macro-execution
  "Tests the entire full-view-pipeline from DSL generation to buffer rendering."
  (let* ((initial-context (setup-test-context))
         ;; We test up to the stage before display, as display has side-effects
         ;; and requires a backend.
         (final-context (render-pipeline-0-to-5 initial-context)))
    (is-true (getf final-context :tree) "Pipeline should produce a tree.")
    (is-true (getf final-context :back-buffer) "Pipeline should produce a back-buffer.")
    (is (typep (getf final-context :back-buffer) 'elmtui.platform.backend.common.virtual-buffer:virtual-terminal-buffer)
        "The back-buffer should be a virtual-terminal-buffer.")))

(test pipeline-step-by-step-transformation
  "Tests each stage of the rendering pipeline individually."
  (let ((context (setup-test-context)))
    ;; Stage 0: Generate DSL
    (let ((ctx-after-dsl (generate-dsl context)))
      (is-true (listp (getf ctx-after-dsl :tree)) "generate-dsl should add a DSL list to the context tree.")
      (is (eq :column (first (getf ctx-after-dsl :tree))) "The root of the DSL should be a :column.")
      (setf context ctx-after-dsl))

    ;; Stage 1: Render DSL to UI-Node
    (let ((ctx-after-render (render-dsl context)))
      (is (ui-node-p (getf ctx-after-render :tree)) "render-dsl should produce a ui-node.")
      (setf context ctx-after-render))

    ;; Stage 2: Apply Styles
    (let ((ctx-after-style (apply-styles context)))
      (is (typep (getf ctx-after-style :tree) 'elmtui.view.styled:styled-ui-node)
          "apply-styles should produce a styled-ui-node.")
      (setf context ctx-after-style))

    ;; Stage 3: Resolve View
    (let ((ctx-after-resolve (resolve-view-stage context)))
      (is (typep (getf ctx-after-resolve :tree) 'elmtui.view.styled:styled-ui-node)
          "resolve-view-stage should return a styled-ui-node.")
      ;; More specific checks could be added here, e.g., for :overflow transformations
      (setf context ctx-after-resolve))

    ;; Stage 4: Layout View
    (let ((ctx-after-layout (layout-view-stage context)))
      (is (typep (getf ctx-after-layout :tree) 'elmtui.view.styled:styled-ui-node)
          "layout-view-stage should return a styled-ui-node.")
      (is-true (getf (elmtui.view.api:ui-node-props (getf ctx-after-layout :tree)) :layout-rect)
               "The laid-out node should have a :layout-rect property.")
      (setf context ctx-after-layout))

    ;; Stage 5: Render to Buffer
    (let ((ctx-after-render-buffer (render-to-buffer context)))
      (is (virtual-terminal-buffer-p (getf ctx-after-render-buffer :back-buffer))
          "render-to-buffer should produce a virtual-terminal-buffer in :back-buffer.")
      (setf context ctx-after-render-buffer))

    ;; Stage 6: Display Buffer (simulated)
    (let ((ctx-after-display (display-buffer context)))
      (is (virtual-terminal-buffer-p (getf ctx-after-display :front-buffer))
          "display-buffer should place a new buffer in :front-buffer."))))
(test render-dsl-contract-violation
  "Should signal pipeline-contract-violation if render-dsl receives a non-DSL input."
  (let ((bad-context (list :tree 42))) ; 42 is not a DSL list
    (signals elmtui.contracts:pipeline-contract-violation
      (render-dsl bad-context))))
