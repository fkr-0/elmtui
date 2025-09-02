(uiop:define-package :elmtui.tests.rainbow
  (:use :cl :fiveam :elmtui.contracts :elmtui.pipeline)
  (:import-from :elmtui.view.core #:ui-node-p)

  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.app.api #:get-component-instance)
  (:import-from :elmtui.ui.api #:update)
  (:import-from :cl-styles.api #:defrule #:defstylesheet #:rgb)
  (:import-from :cl-styles.selector #:cls> #:type>)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.tea-state.api #:make-update-result #:state-ref)
  (:export
   :run-rainbow-example-app
   :rainbow-content-view
   :rainbow-stylesheet
   :initialize-app-state-rainbow-example-app))
(in-package :elmtui.tests.rainbow)

(defvar rainbow-colors-with-names
  '((:red "red-stripe" (255 0 0))
    (:pink "pink-stripe" (255 192 203))
    (:orange "orange-stripe" (255 165 0))
    (:yellow "yellow-stripe" (255 255 0))
    (:green "green-stripe" (0 255 0))
    (:blue "blue-stripe" (0 0 255))
    (:indigo "indigo-stripe" (75 0 130))
    (:violet "violet-stripe" (238 130 238)))
  "List of colors and their corresponding class names for stripes.")

;; (defun generate-stripe-rules-forms ()
;;   (loop for (color-name class-name rgb-vals) in rainbow-colors-with-names
;;         collect `(defrule (cls> ,class-name)
;;                    :bg-color ,(rgb (first (last (list rgb-vals))))
;;                    :width 2 :height :fill)))

;; Define the stylesheet for the rainbow app
(defparameter rainbow-stylesheet
  (defstylesheet
    ;; Container base style
    (defrule (type> :container)
      :display :block
      :flex-direction :row
      :width :fill
      :height :fill)
    (defrule (cls> "red-stripe")
      :bg-color (rgb 255 0 0)
      :width 1 :height 1)
    (defrule (cls> "pink-stripe") :bg-color (rgb 255 192 203) :width 1 :height 1)
    (defrule (cls> "orange-stripe") :bg-color (rgb 255 165 0) :width 1 :height 1)
    (defrule (cls> "yellow-stripe") :bg-color (rgb 255 255 0) :width 1 :height 1)
    (defrule (cls> "green-stripe") :bg-color (rgb 0 255 0) :width 1 :height 1)
    (defrule (cls> "blue-stripe") :bg-color (rgb 0 0 255) :width 1 :height 1)
    (defrule (cls> "indigo-stripe") :bg-color (rgb 75 0 130) :width 1 :height 1)
    (defrule (cls> "violet-stripe") :bg-color (rgb 238 130 238) :width 1 :height 1)
    ;; Generate individual stripe rules
    ;; (generate-stripe-rules-forms)
    )

  "Stylesheet for the rainbow application.")

;;;--------------------------------------------------------------
;;; Application Update Function
;;;--------------------------------------------------------------
;; (defun app-update (message app-state)
;;   "Handles updates to the application state based on messages."
;;   (log-info "Rainbow: RECEIVED MESSAGE: ~S" message)
;;   (cond
;;     ((typep message 'key-event)
;;      (let* ((current-count (state-ref app-state :switch-count 0))
;;             (new-count (1+ current-count)))
;;        (if (>= new-count 15)
;;            (make-update-result :patches `(((:should-quit) t)))
;;            (let ((new-orientation (if (eql (state-ref app-state :orientation) :row)
;;                                       :column
;;                                       :row)))
;;              (make-update-result :patches `(((:switch-count) ,new-count)
;;                                             ((:orientation) ,new-orientation)))))))
;;     ((and (listp message) (eq (first message) :app-quit-requested))
;;      (make-update-result :patches `(((:should-quit) t))))
;;     (t
;;      (make-update-result))))

;; (defun rainbow-content-view (app-state)
;;   "Defines the UI DSL for the rainbow app's content. The root viewport is set via :root-viewport-id in defapplication."
;;   (declare (ignore app-state))
;;   `(:container
;;     :style (:display :flex :flex-direction :row :height :fill :width :fill)
;;     :children
;;     ,(loop for (color-name class-name rgb-val) in rainbow-colors-with-names
;;            collect
;;            `(:container
;;              :id ,(intern (format nil "STRIPE-~A" (string color-name)) :keyword)
;;              :classes (,class-name)
;;              :style (:width :fill
;;                      :height :fill
;;                      :min-width 10
;;                      :fg-color ,(rgb rgb-val)
;;                      :bg-color ,(rgb rgb-val))))))


(defun rainbow-content-view (app-state)
  "Defines the UI DSL for the rainbow app's content."
  (let* ((orientation (state-ref app-state :orientation :row))
         (flex-direction orientation)
         (stripe-style (if (eq orientation :row)
                           '(:width 1 :height :fill :flex-grow 1)
                           '(:width :fill :height 1 :flex-grow 1))))
    `(:container
      :id :rainbow-content
      :style (:display :flex :flex-grow 1 :flex-direction ,flex-direction :height 7 :width 7)
      :children ,(loop for i from 0 below 7
                       for (color-name class-name rgb-val) in rainbow-colors-with-names
                       collect
                       `(:container
                         :id ,(intern (format nil "STRIPE-~A" (string color-name)) :keyword)
                         :classes (,class-name)
                         :style ,(append (list :fg-color (apply #'rgb rgb-val)
                                               :bg-color (apply #'rgb rgb-val))
                                         stripe-style)
                         :children nil)))))
(defun rainbow-app-subscriptions (model)
  (declare (ignore model))
  (log-debug "RAINBOW-APP: Subscriptions function called.")
  nil)

;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------
(defapplication rainbow-example-app
  :root-viewport-id :rainbow-root-vp
  :initial-state-plist (list :current-stylesheet rainbow-stylesheet
                             :should-quit nil
                             :orientation :row
                             :switch-count 0)
  ;; :root-component-dsl `(:column)
  :root-component-dsl
  '(:layout :id :rainbow-main-container

    :initial-terminal-dimensions (1 1)
    :initial-cursor-pos (1 1)
    :children ((:viewport ;; column
                :id :main)))
                                        ; or make nil and let view return full tree

  :update-fn 'app-update
  :view-fn 'rainbow-content-view)
