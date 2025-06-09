;;;===============================================================
;;; File: examples/rainbow-app.lisp
;;; Example application demonstrating colored vertical stripes
;;; using stylesheets and flexbox, quitting on any key press.
;;; Adapted to modern app design with defapplication.
;;;===============================================================
(uiop:define-package :elmtui.examples.rainbow-app
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.style-lib.rule #:defrule)
  (:import-from :elmtui.style-lib.sheet #:defstylesheet)
  (:import-from :elmtui.state.update #:defupdate)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.state #:make-update-result)
  (:export
   :main))

(in-package :elmtui.examples.rainbow-app)

;;;--------------------------------------------------------------
;;; Stylesheet Definition
;;;--------------------------------------------------------------
(defvar *rainbow-colors-with-names* '((:red "red-stripe" (255 0 0))
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
  (loop for (color-name class-name rgb) in *rainbow-colors-with-names*
        collect (defrule class-name
                  :bg-color (funcall #'elmtui.style-lib.styles:rgb rgb)
                  :width 12
                  :height :fill)))

;; Define the stylesheet for the rainbow app
(defparameter rainbow-stylesheet
  (defstylesheet (generate-stripe-rules-forms)))

;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------

(defun app-init ()
  "Initializes the application model."
  (values
   ;; Initial application state (plist)
   (list :current-stylesheet rainbow-stylesheet
         :should-quit nil)
   ;; No initial commands
   nil))

(defupdate app-update (app-state message)
  "Handles updates to the application state based on messages.
   Any key press will quit the application."
  (declare (ignore app-state)) ; app-state not used directly, patches are absolute
  (log-info "RAINBOW-APP: app-update called with message: ~S (Type: ~A)" message (type-of message))
  (let ((patch nil))
    (cond
      ((typep message 'elmtui.core.event-types:key-event)
       (log-info "RAINBOW-APP: Key event condition met for ~A, setting :should-quit to t." message)
       (setf patch (list :should-quit t))) ; Patch to set should-quit to t

      ((and (listp message) (eq (first message) :app-quit-requested))
       (log-info "RAINBOW-APP: :APP-QUIT-REQUESTED condition met for ~A, setting :should-quit to t." message)
       (setf patch (list :should-quit t))) ; Patch to set should-quit to t
      (t (setf patch nil)))
    (values patch nil))) ; Explicitly return (values patches commands)

(defun rainbow-content-view (app-state)
  "Defines the UI DSL for the rainbow app's content."
  (declare (ignore app-state)) ; app-state not used in this simple static view
  ;; This is the DSL for the content that will be the child of the root-viewport
  (make-styled-node
   :type :container
   :props (list :id :rainbow-main-container
                :direction :row ; Stripes are laid out horizontally
                :height :fill
                :width :fill
                :style (list :bg-color (elmtui.style-lib.styles:rgb '(10 10 10)))); Dark background for main container
   :children (loop for (color-name class-name rgb-val) in *rainbow-colors-with-names*
                   collect (make-styled-node
                            :type :container ; Each stripe is a container
                            :props (list :id (intern (format nil "STRIPE-~A" (string color-name)) :keyword)
                                         :classes (string-downcase (symbol-name class-name)) ; Ensure class name is a string
                                         ;; width and height come from the stylesheet class
                                         )
                            :children nil))))

(defapplication rainbow-example-app
  :root-viewport-id :rainbow-root-vp
  :initial-state-plist (app-init) ; Get initial state from app-init (which returns a plist)
  :root-component-dsl (rainbow-content-view nil) ; Initial DSL for the content
  :update-fn 'app-update
  :view-fn 'rainbow-content-view  ; Function that generates the content DSL
  :subscriptions-fn (lambda (model)
                      (declare (ignore model))
                      (log-debug "RAINBOW-APP: Subscriptions function called.")))
