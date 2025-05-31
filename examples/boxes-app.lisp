;;;===============================================================
;;; File: examples/boxes-app.lisp
;;; Example application demonstrating a scrollable container
;;; with differently styled boxes, using stylesheets.
;;; Adapted to modern app design.
;;;===============================================================
(uiop:define-package :elmtui.examples.boxes-app
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.runtime #:def-elm-app #:run-app)
  (:import-from :elmtui.style-lib.rule #:defrule)
  (:import-from :elmtui.state #:application-state #:state-ref ) ; Added defmodel
  (:import-from :elmtui.view.dsl #:define-view)
  (:import-from :elmtui.ui.widgets.utils
                #:widget-focused-p #:defwidget-view)
  (:import-from :elmtui.style-lib.sheet #:defstylesheet)
  (:import-from :elmtui.state.update #:defupdate)
  (:export
   :main
   :run-boxes-example-app))

(in-package :elmtui.examples.boxes-app)

(defparameter *scroller-id* :my-scrollable-container)


;;;--------------------------------------------------------------
;;; Stylesheet Definition
;;;--------------------------------------------------------------
(defvar boxes-stylesheet (defstylesheet
                           (defrule ".container"
                             :display :flex
                             :flex-direction :column
                             :padding 1
                             :background (list 30 30 30)
                             :color (list 200 200 200))

                           (defrule ".box"
                             :margin-bottom 1
                             :padding 1
                             :width 100
                             :background (list 60 60 60)
                             :color (list 230 230 230))

                           (defrule ".box-red"
                             :border-style :single
                             :border-color (list 255 100 100))

                           (defrule ".box-green"
                             :border-style :double
                             :border-color (list 100 255 100))

                           (defrule ".box-blue"
                             :border-style :single
                             :border-color (list 100 100 255))

                           (defrule ".scrollable"
                             :overflow :auto
                             :height 10
                             :width 10)))


;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------

(defun app-init ()
  "Initialize the boxes example application state."
  (values
   ;; Initial application state
   (list :stylesheet boxes-stylesheet
         :scroll-offset 0
         :should-quit nil)
   ;; No initial commands
   nil))

(defupdate app-update (app-state message)
  "Handle updates to the boxes application state based on messages."
  (let ((app-patch nil)
        (commands nil))

    ;; Handle different types of messages
    (cond
      ;; Handle scroll events
      ((and (listp message) (eq (first message) :scroll))
       (let* ((current-offset (or (state-ref app-state :scroll-offset) 0))
              (direction (getf (rest message) :direction))
              (amount (getf (rest message) :amount 1))
              (new-offset (if (eq direction :up)
                              (max 0 (- current-offset amount))
                              (+ current-offset amount))))
         (setf app-patch (list :scroll-offset new-offset))))

      ;; Handle key events to quit (press 'q' or ESC)
      ((and (listp message) (eq (first message) :key-event))
       (let ((key (getf (rest message) :key)))
         (when (or (eql key #\q) (eql key :escape))
           (setf app-patch (list :should-quit t)))))

      ;; Handle struct-based key events
      ((typep message 'elmtui.core.event-types:key-event)
       (let ((key (elmtui.core.event-types:key-event-key message)))
         (when (or (eql key #\q) (eql key :escape))
           (setf app-patch (list :should-quit t))))))

    ;; Return state changes and commands
    (values app-patch commands)))

(define-view app-view (app-state dispatch-fn)
  "Define the UI view for the boxes app."
  (:scrollable :id *scroller-id*
               :class "scrollable"
               :scroll-offset (or (state-ref app-state :scroll-offset) 0)
               :dispatch-fn dispatch-fn
               (:container :class "container"
                           :height :fill
                           :width :fill

                           ;; Box 1 - Red border
                           (:box :id :box1
                                 :class "box box-red"
                                 :title "Box with Red Border"
                                 (:p :id :box1-content
                                     :value (format nil "This is Box 1 with a red border.~%
Line 2 of Box 1~%
Line 3 of Box 1~%
Line 4 of Box 1~%
Line 5 of Box 1")))

                           ;; Box 2 - Green border
                           (:box :id :box2
                                 :class "box box-green"
                                 :title "Box with Green Border"
                                 (:p :id :box2-content
                                     :value (format nil "This is Box 2 with a green border.~%
 This box is a bit wider.~%And also has five lines.~%To test scrolling properly.~%
The fifth line is here.")))

                           ;; Box 3 - Blue border
                           (:box :id :box3
                                 :class "box box-blue"
                                 :title "Box with Blue Border"
                                 (:p :id :box3-content
                                     :value (format nil "This is Box 3 with a blue border.~%
With a styled border.~%
Content flows within.~%
Making it all scrollable."))))))

(def-elm-app boxes-example-app
  :init #'app-init
  :update #'app-update
  :view #'app-view)

(defun main ()
  "Run the boxes example application."
  (elmtui.runtime:run-app :app-name 'boxes-example-app))
