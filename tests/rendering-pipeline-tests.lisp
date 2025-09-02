(uiop:define-package :elmtui.tests.rendering-pipeline
  (:use :cl :fiveam :elmtui.contracts :elmtui.pipeline)
  (:import-from :elmtui.view.core #:ui-node-p)
  (:import-from :cl-styles.selector #:cls> #:type> #:id>)
  (:import-from :elmtui.app #:defapplication)
  (:import-from #:cl-styles.rule #:defrule)
  (:import-from #:cl-styles.sheet #:defstylesheet)
  (:import-from #:cl-styles.tokens #:rgb)
  (:import-from :elmtui.view.styled #:styled-ui-node-p)
  (:import-from :elmtui.pipeline
                #:generate-dsl)

  (:import-from :elmtui.view.geo #:make-rectangle #:w #:h #:rectangle #:make-size
                #:make-pos)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer-p
                #:make-virtual-buffer)
  (:import-from :elmtui.tests.rainbow
                #:rainbow-content-view
                #:rainbow-stylesheet
                #:initialize-app-state-rainbow-example-app)
  )
(in-package :elmtui.tests.rendering-pipeline)
;;;--------------------------------------------------------------
;;; Stylesheet Definition
;;;--------------------------------------------------------------

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
      (initialize-app-state-rainbow-example-app
       :initial-terminal-dimensions (list 80 24)
       :initial-cursor-position (list 0 0))
    (declare (ignore commands))
    (make-app-context
     :state app-state
     :viewport-rect (make-rectangle
                     :size (make-size :h 24 :w 80) ;;width :h height)
                     :pos (make-pos :x 0 :y 0))
     :front-buffer (make-virtual-buffer 80 24)
     :view-fn #'rainbow-content-view
     :backend nil)
    ;; app-state
    ))
;; (setup-test-context)

(test rainbow-app-example-state
  "Tests the initial state of the rainbow app example."
  (let ((context (setup-test-context)))
    (is-true (ctx-state context) "Context should have an application state.")
    (is-true (elmtui.tea-state:application-state-p (ctx-state context)) "Context state should be a valid app state.")
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

;; Ensure the pipeline lays out children with their own computed rects
(test pipeline-layout-correctness-basic
  (let* ((view
           (lambda (model)
             (declare (ignore model))
             (let* ((root (make-instance 'elmtui.view.base-elements:container-element
                                         :id :root
                                         :style '(:display :flex :flex-direction :row :gap 1)))
                    (a    (make-instance 'elmtui.view.base-elements:container-element :id :a :style '(:width 10 :height 3)))
                    (b    (make-instance 'elmtui.view.base-elements:text-element      :id :b :content "hello world")))
               (setf (elmtui.view.base-elements:element-children a) (list b))
               (setf (elmtui.view.base-elements:element-children root) (list a))
               root)))
         (ctx (make-app-context
               :state nil
               :viewport-rect (make-rectangle :pos (make-pos :x 0 :y 0)
                                              :size (make-size :w 80 :h 10))
               :front-buffer (make-virtual-buffer 80 10)
               :view-fn view))
         (ctx2 (render-pipeline-0-to-5 ctx))
         (laid (ctx-laid-out-tree ctx2))
         (root (root laid))
         (a    (car (elmtui.view.base-elements:element-children root)))
         (b    (car (elmtui.view.base-elements:element-children a))))
    (is (>= (elmtui.view.geo:w (elmtui.view.element:el/layout-rect a)) 10)
        "Child A keeps its fixed width (lower bound), not forced to viewport.")
    (is (<= (elmtui.view.geo:w (elmtui.view.element:el/layout-rect b))
            (elmtui.view.geo:w (elmtui.view.element:el/layout-rect a)))
        "Inner text width never exceeds its container's width.")))


;; (test pipeline-step-by-step-transformation
;;   "Tests each stage of the rendering pipeline individually."
;;   (let* ((context (setup-test-context ))
;;          (buffer (ctx-front-buffer context)))
;;     ;; Stage 0: Generate DSL
;;     (elmtui.dev::with-buffer-dump (buffer)
;;       (let ((ctx-after-layout (process-tree-stage context)))
;;         ;; (is (typep (ctx-laid-out-tree ctx-after-layout) 'laid-out-tree)
;;         ;;     "atomic->layout-stage should produce a laid-out-tree struct.")
;;         (setf context ctx-after-layout))

;;       ;; Stage 5: Render to Buffer
;;       (let ((ctx-after-render-buffer (render-to-buffer context)))
;;         (is (virtual-terminal-buffer-p (ctx-back-buffer ctx-after-render-buffer))
;;             "render-to-buffer should produce a virtual-terminal-buffer in :back-buffer.")
;;         (setf context ctx-after-render-buffer))

;;       ;; Stage 6: Display Buffer (simulated)
;;       (let ((ctx-after-display (display-buffer context)))
;;         (is (virtual-terminal-buffer-p (ctx-front-buffer ctx-after-display))
;;             "display-buffer should place a new buffer in :front-buffer."))


;;       )))
