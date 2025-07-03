;;;===============================================================
;;; File: examples/rainbow-app.lisp
;;; Example application demonstrating colored vertical stripes
;;; using stylesheets and flexbox, quitting on any key press.
;;; Adapted to modern app design with defapplication.
;;;===============================================================
(uiop:define-package :elmtui.examples.rainbow-app
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.style-lib.rule #:defrule)
  (:import-from :elmtui.style-lib.sheet #:defstylesheet)
  (:import-from :elmtui.style-lib.styles #:rgb)
  (:import-from :elmtui.style-lib.selector #:cls> #:type>)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.state.api #:make-update-result)
  (:export
   :run-rainbow-example-app
   :initialize-app-state-rainbow-example-app))

(in-package :elmtui.examples.rainbow-app)

;;;--------------------------------------------------------------
;;; Stylesheet Definition
;;;--------------------------------------------------------------
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

(defun generate-stripe-rules-forms ()
  "Generates a list of (defrule ...) forms for stripes."
  (loop for (color-name class-name rgb-vals) in rainbow-colors-with-names
        collect `(defrule (cls> ,class-name)
                   :bg-color ,(rgb rgb-vals)
                   :width 12
                   :height :fill)))

;; Define the stylesheet for the rainbow app
(defparameter rainbow-stylesheet
  `(defstylesheet
       ;; Container base style
       (defrule (type> :container)
         :display :flex
         :flex-direction :row
         :width :fill
         :height :fill)

       ;; Generate individual stripe rules
       ,@(generate-stripe-rules-forms))

  "Stylesheet for the rainbow application.")

;;;--------------------------------------------------------------
;;; Application Update Function
;;;--------------------------------------------------------------
(defun app-update (app-state message)
  "Handles updates to the application state based on messages.
Any key event or :app-quit-requested sets :should-quit to t."
  (declare (ignore app-state)) ; app-state not used for this logic
  (cond
    ((or (typep message 'key-event)
         (and (listp message) (eq (first message) :app-quit-requested)))
     (make-update-result :patches (list (list '(:should-quit) t))))
    (t
     (make-update-result))))

(defun rainbow-content-view (app-state)
  "Defines the UI DSL for the rainbow app's content. The root viewport is set via :root-viewport-id in defapplication."
  (declare (ignore app-state))
  `(:container
    :id :rainbow-main-container
    :style (:display :flex :flex-direction :row :height :fill :width :fill :bg-color ,(rgb '(10 10 10)))
    :children ,(loop for (color-name class-name rgb-val) in rainbow-colors-with-names
                     collect
                     `(:container
                       :id ,(intern (format nil "STRIPE-~A" (string color-name)) :keyword)
                       :classes (,class-name)
                       :style (:width 12
                               :height :fill
                               :bg-color ,(rgb rgb-val))
                       :children nil))))

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
                             :should-quit nil)
  :root-component-dsl `(:column)
  :update-fn 'app-update
  :view-fn 'rainbow-content-view)

;;;--------------------------------------------------------------
;;; Application Runner Function
;;;--------------------------------------------------------------
;; (defun run-rainbow-example-app (&rest args)
;;   "Run the rainbow example application."
;;   (apply #'elmtui.app.api:run-application
;;          (initialize-app-state-rainbow-example-app)
;;          args))

;; To run from REPL:
;; (elmtui.examples.rainbow-app:run-rainbow-example-app)
