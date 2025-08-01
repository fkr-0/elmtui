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
  (:import-from :elmtui.app.api #:get-component-instance)
  (:import-from :elmtui.ui.api #:update)
  (:import-from :elmtui.style-lib.rule #:defrule)
  (:import-from :elmtui.style-lib.sheet #:defstylesheet)
  (:import-from :elmtui.style-lib.styles #:rgb)
  (:import-from :elmtui.style-lib.selector #:cls> #:type>)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.state.api #:make-update-result)
  (:export
    :run-rainbow-example-app
    :rainbow-content-view
    :rainbow-stylesheet
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
  (defstylesheet
    ;; Container base style
    (defrule (type> :container)
      :display :flex
      :flex-direction :row
      :width :fill
      :height :fill)
    (DEFRULE (CLS> "red-stripe")
      :BG-COLOR
      (list 255 0 0)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "pink-stripe")
      :BG-COLOR
      (list 255 192 203)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "orange-stripe")
      :BG-COLOR
      (list 255 165 0)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "yellow-stripe")
      :BG-COLOR
      (list 255 255 0)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "green-stripe")
      :BG-COLOR
      (list 0 255 0)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "blue-stripe")
      :BG-COLOR
      (list 0 0 255)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "indigo-stripe")
      :BG-COLOR
      (list 75 0 130)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "violet-stripe")
      :BG-COLOR
      (list 238 130 238)
      :WIDTH
      1
      :HEIGHT
      1)
    ;; Generate individual stripe rules
    ;; (generate-stripe-rules-forms)
    )

  "Stylesheet for the rainbow application.")

;;;--------------------------------------------------------------
;;; Application Update Function
;;;--------------------------------------------------------------
(defun app-update (message app-state)
  "Handles updates to the application state based on messages.
Any key event or :app-quit-requested sets :should-quit to t."
  (log-info "Rainbow: RECEIVED MESSAGE: ~S" message)
  (cond
    ((or (typep message 'key-event)
       (and (listp message) (eq (first message) :app-quit-requested)))
      (make-update-result :patches (list (list '(:should-quit) t))))
    ((and (listp message) (eq (car message) :terminal-resized))
      (let* ((root-vp-path '(:components :rainbow-root-vp))
              (root-vp-instance (get-component-instance root-vp-path app-state)))
        (if root-vp-instance
          (let ((patches (update root-vp-instance app-state message :id-path root-vp-path)))
            (make-update-result :patches patches))
          (make-update-result))))
    (t
      (make-update-result))))

(defun rainbow-content-view (app-state)
  "Defines the UI DSL for the rainbow app's content. The root viewport is set via :root-viewport-id in defapplication."
  (declare (ignore app-state))
  `(:container
     :id :rainbow-main-container
     :style (:display :flex :flex-direction :row :height :fill :width :fill :bg-color ,(rgb '(100 100 00)))
     :children ,(loop for (color-name class-name rgb-val) in rainbow-colors-with-names
                  collect
                  `(:container
                     :id ,(intern (format nil "STRIPE-~A" (string color-name)) :keyword)
                     :classes (,class-name)
                     :style (:width :fill
                              :height :fill
                              :min-width 1
                              :fg-color ,(rgb rgb-val)
                              :bg-color ,(rgb rgb-val))
                     :children nil)))) ;;,(list :text :content "abcdefgh123456")))))

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
;; (initialize-app-state-rainbow-example-app)
;; (elmtui.ui.api:initialize-components-from-dsl
;;           '(:root-viewport :id :rainbow-root-vp :initial-terminal-dimensions
;;             (1 1) :initial-cursor-pos (1 1) :children
;;             (:layout :id :rainbow-main-container :initial-terminal-dimensions
;;              (1 1) :initial-cursor-pos (1 1) :children nil)))
;; (elmtui.ui.api:initialize-components-from-dsl
;;           '(:root-viewport :id :rainbow-root-vp :initial-terminal-dimensions
;;             (1 1) :initial-cursor-pos (1 1) :children
;;             (:layout :id :rainbow-main-container :initial-terminal-dimensions
;;              (1 1) :initial-cursor-pos (1 1) :children
;;              ((:viewport :id :main)))))
;; (elmtui.ui.api:initialize-components-from-dsl
;;  '(:root-viewport :id :rainbow-root-vp :initial-terminal-dimensions
;;    (1 1) :initial-cursor-pos (1 1) :children
;;    (:container :id :rainbow-main-container :initial-terminal-dimensions
;;     (1 1) :initial-cursor-pos (1 1) :children
;;     ((:viewport :id :main)))))
