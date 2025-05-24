(uiop:define-package :elmtui.examples.colorblocks-app
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.ui.widgets.utils 
                #:widget-focused-p #:defwidget-view)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.runtime #:def-elm-app #:run-app)
  (:import-from :elmtui.style-lib.rule #:defrule)
  (:import-from :elmtui.style-lib.sheet #:defstylesheet)
  (:import-from :elmtui.state.update #:defupdate)
  (:export
   :main
   :run-colorblocks-example-app))

(in-package :elmtui.examples.colorblocks-app)

;;;-------------------------------------------------------------- 
;;; Stylesheet Definition 
;;;--------------------------------------------------------------
(defvar *colors-with-names* '((:red "red-block" (255 0 0))
                              (:pink "pink-block" (255 192 203))
                              (:orange "orange-block" (255 165 0))
                              (:yellow "yellow-block" (255 255 0))
                              (:green "green-block" (0 255 0))
                              (:blue "blue-block" (0 0 255))
                              (:indigo "indigo-block" (75 0 130))
                              (:violet "violet-block" (238 130 238)))
  "List of colors and their corresponding class names for blocks.")

(defun generate-block-rules-forms ()
  "Generates a list of (defrule ...) forms for color blocks."
  (loop for (color-name class-name rgb) in *colors-with-names*
        collect (defrule class-name
                  :background-color (funcall #'elmtui.style-lib.styles:rgb rgb)
                  :width 2  ; 2 columns wide
                  :height 6 ; 6 rows tall
                  :margin 1 ; Add margin to better see separation between blocks
                  )))

;; Define the stylesheet for the colorblocks app
(defparameter colorblocks-stylesheet
  (defstylesheet (generate-block-rules-forms)))

;;;-------------------------------------------------------------- 
;;; Application Definition 
;;;--------------------------------------------------------------

(defun app-init ()
  "Initializes the application model."
  (values
   ;; Initial application state
   (list :current-stylesheet colorblocks-stylesheet
         :should-quit nil)
   ;; No initial commands
   nil))

(defupdate app-update (app-state message)
  "Handles updates to the application state based on messages.
   Any key press will quit the application."
  (cond
    ;; Handle key events to quit the app
    ((and (listp message) (eq (first message) :key-event))
     (values (list :should-quit t) nil))

    ;; Handle struct-based key events
    ((typep message 'elmtui.core.event-types:key-event)
     (values (list :should-quit t) nil))

    ;; Default: no state change
    (t (values nil nil))))

(defun colorblocks-view (app-state dispatch-fn)
  (declare (ignore dispatch-fn))
  (log-info "Creating colorblocks view. App state: ~S" app-state)
  
  ;; Create a container with rows of colored blocks
  (make-styled-node
   :type :container
   :props (list :id :colorblocks-main-container
                :direction :row ; Set row direction to place blocks horizontally
                :height :fill
                :width :fill)
   :children 
     ;; Create the 2x6 colored blocks in a row
     (loop for (color-name class-name rgb-val) in *colors-with-names*
           collect (make-styled-node
                    :type :container
                    :props (list :id (intern (format nil "BLOCK-~A" (string color-name)) :keyword)
                                 :classes class-name)
                    :children nil))))

(def-elm-app colorblocks-example-app
  :init #'app-init
  :update #'app-update
  :view #'colorblocks-view)

(defun main ()
  "Run the colorblocks example application."
  (elmtui.runtime:run-app :app-name 'colorblocks-example-app))
