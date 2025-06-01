;;;==(uiop:define-package :elmtui.examples.rainbow-app 
;;; Example application demonstrating colored vertical stripes
;;; ;;; using stylesheets and flexbox, quitting on any key press.
;;; ;;; Adapted to modern app design.
;;; ;;;===============================================================
(uiop:define-package :elmtui.examples.rainbow-app
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.ui.widgets.utils
                #:widget-focused-p #:defwidget-view)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.runtime #:def-elm-app #:run-app)
  (:import-from :elmtui.style-lib.rule #:defrule)
  (:import-from :elmtui.style-lib.sheet #:defstylesheet)
  (:import-from :elmtui.state.update #:defupdate)
  (:import-from :elmtui.core.event-types #:key-event) ; Added import for key-event
  (:export
   :main
   :run-rainbow-example-app))

(in-package :elmtui.examples.rainbow-app)

;;;-------------------------------------------------------------- ;;; Stylesheet Definition ;;;--------------------------------------------------------------
(defvar *rainbow-colors-with-names* '((:red "red-stripe" (255 0 0))
                                      (:pink "pink-stripe" (255 192 203)) ; Corrected Pink RGB
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
                  :background-color (funcall #'elmtui.style-lib.styles:rgb rgb) ; Changed to :background-color
                  :width 12
                  :height 1)))

;; Define the stylesheet for the rainbow app
(defparameter rainbow-stylesheet ; Changed defvar to defparameter to force re-evaluation
  (defstylesheet (generate-stripe-rules-forms)))

;;;-------------------------------------------------------------- ;;; Application Definition ;;;--------------------------------------------------------------

(defun app-init ()
  "Initializes the application model."
  (values
   ;; Initial application state
   (list :current-stylesheet rainbow-stylesheet  ;; Changed :stylesheet to :current-stylesheet
         :should-quit nil)
   ;; No initial commands
   nil))

(defupdate app-update (app-state message)
  "Handles updates to the application state based on messages.
   Any key press will quit the application."
  (log-info "RAINBOW-APP: app-update called with message: ~S (Type: ~A)" message (type-of message))
  (cond
    ;; Handle key events to quit the app
    ;; ((and (listp message) (eq (first message) :key-event))
    ;;  (values (list :should-quit t) nil))

    ;; Handle struct-based key events
    ((typep message 'elmtui.core.event-types:key-event) ; Check for key event using fully qualified name
     (log-info "RAINBOW-APP: Key event condition met for ~A, setting :should-quit to t." message)
     (values (list :should-quit t) nil)) ; Update state to quit, NO commands

    ;; Handle :APP-QUIT-REQUESTED from SIGINT
    ((and (listp message) (eq (first message) :app-quit-requested))
     (log-info "RAINBOW-APP: :APP-QUIT-REQUESTED condition met for ~A, setting :should-quit to t." message)
     (values (list :should-quit t) nil))

    ;; Default: no state change
    (t (values nil nil))))

;; (define-view app-view (app-state dispatch-fn)
;;   "Defines the UI view for the rainbow app."
;;   `(:container :id :main-container
;;                :direction :row
;;                :height :fill
;;                :width :fill
;;                :dispatch ,dispatch-fn
;;                ;; Generate color stripes
;;                ,@(loop for (color class-name rgb) in *rainbow-colors-with-names*
;;                        collect `(:div :id ,(intern (format nil "STRIPE-~A" (string color)) :keyword)
;;                                       :class ,class-name))))

;; Redefine rainbow-view as a standard main view function
(defun rainbow-view (app-state dispatch-fn)
  (declare (ignore dispatch-fn)) ; dispatch-fn is not used in this simple view yet
  (log-info "Creating rainbow view. App state: ~S" app-state)
  ;; For now, just create the main container.
  ;; The actual rainbow stripes need to be added as children.
  (make-styled-node
   :type :container
   :props (list :id :rainbow-main-container
                :direction :column ; Changed from :row to :column
                :height :fill
                :width :fill)
   :children (loop for (color-name class-name rgb-val) in *rainbow-colors-with-names*
                   collect (make-styled-node
                            :type :container ; or :div if that's a styled type
                            :props (list :id (intern (format nil "STRIPE-~A" (string color-name)) :keyword)
                                         :classes class-name ; Changed :class to :classes
                                         ;; :width 12 ; These would typically come from styles
                                         ;; :height :fill ; or be set here if not styled
                                         )
                            :children nil))))
;; (view-listbox app-state
;;                    :widget-id :my-listbox
;;                    :items '(\"Item 1\" \"Item 2\" \"Item 3\")
;;                    :height 5
;;                    :selected-index 1
;;                    :on-select (list :msg-type :item-selected)
;;                    :empty-text \"No items available\"
;;                    :tooltip \"Select an item\"
;;                    :aria-label \"List of items\"
;;                    :class \"custom-listbox\"
;;                    :width 20)
;; (def-elm-app rainbow-example-app
;;   :init #'app-init
;;   :update #'app-update
;;   :view #'app-view)


(def-elm-app rainbow-example-app
  :init #'app-init
  :update #'app-update
  :view #'rainbow-view)

(defun main ()
  "Run the boxes example application."
  (elmtui.runtime:run-app :app-name 'rainbow-example-app))

;; Note: run-rainbow-example-app is automatically defined by def-elm-app macro
