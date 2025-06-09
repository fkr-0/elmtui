;;;===============================================================
;;; File: examples/boxes-app.lisp
;;; Example application demonstrating a scrollable container
;;; with differently styled boxes, using stylesheets.
;;; Adapted to modern app design using defapplication.
;;;===============================================================
(uiop:define-package :elmtui.examples.boxes-app
  (:use :cl :alexandria :elmtui.app)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.view.dsl #:element #:vbox #:label #:viewport) ; Updated for DSL
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:key-event-modifiers)
  (:import-from :elmtui.style #:merge-styles #:make-style #:get-style-value)
  (:import-from :elmtui.style.presets #:dark-theme)
  (:export #:main #:run-boxes-example-app))

(in-package :elmtui.examples.boxes-app)

;;;--------------------------------------------------------------
;;; Stylesheet Definition (as plists)
;;;--------------------------------------------------------------
(defparameter *style-scrollable-viewport*
  (make-style :overflow-y :auto :height 15 :width :fill ; Changed :overflow to :overflow-y
              :border-style :single :border-color '(:rgb 100 100 100)
              :padding 0))

(defparameter *style-container*
  (make-style :display :flex :flex-direction :column :padding 1
              :background-color '(:rgb 30 30 30) :color '(:rgb 200 200 200)
              :width :fill :min-height :fill ; Use min-height for scrollable content
              ))

(defparameter *style-box*
  (make-style :margin-bottom 1 :padding 1 :width :fill
              :background-color '(:rgb 60 60 60) :color '(:rgb 230 230 230)))

(defparameter *style-box-red*
  (make-style :border-style :single :border-color '(:rgb 255 100 100)))

(defparameter *style-box-green*
  (make-style :border-style :double :border-color '(:rgb 100 255 100)))

(defparameter *style-box-blue*
  (make-style :border-style :single :border-color '(:rgb 100 100 255)))

(defparameter *app-stylesheet*
  (merge-styles
   dark-theme ; Base theme
   `((:viewport . ,*style-scrollable-viewport*)
     (:container . ,*style-container*)
     (:box . ,*style-box*)
     (:box-red . ,*style-box-red*)
     (:box-green . ,*style-box-green*)
     (:box-blue . ,*style-box-blue*))))

;;;--------------------------------------------------------------
;;; Application Definition using defapplication
;;;--------------------------------------------------------------
(defapplication boxes-app
  :initial-state-fn
  (lambda ()
    (list :scroll-offset-y 0
          :current-stylesheet *app-stylesheet*
          :terminal-width 80 :terminal-height 24 ; Default, will be updated
          ))
  :update-fn
  (lambda (app-state message)
    (let ((patch nil)
          (commands nil))
      (typecase message
        (key-event
         (let ((key (key-event-key message)))
           (cond
             ((or (eql key #\q) (eql key :escape)
                  (and (equal key "q") (member :control (key-event-modifiers message))))
              (setf patch (list :should-quit t)))
             ((eql key :up-arrow)
              (setf patch (list :scroll-offset-y (max 0 (- (getf app-state :scroll-offset-y 0) 1)))))
             ((eql key :down-arrow)
              ;; For now, let viewport clamp. A more robust solution would check content height.
              (setf patch (list :scroll-offset-y (+ (getf app-state :scroll-offset-y 0) 1))))
             ((eql key :page-up)
                (let ((vp-height (get-style-value (getf app-state :current-stylesheet) :viewport :height 15)))
                  (setf patch (list :scroll-offset-y (max 0 (- (getf app-state :scroll-offset-y 0) vp-height))))))
             ((eql key :page-down)
                (let ((vp-height (get-style-value (getf app-state :current-stylesheet) :viewport :height 15)))
                  (setf patch (list :scroll-offset-y (+ (getf app-state :scroll-offset-y 0) vp-height))))))))
        (cons ; Handle list-based messages like :terminal-resized
         (case (car message)
           (:terminal-resized
            (let ((new-width (getf (cdr message) :width))
                  (new-height (getf (cdr message) :height)))
              (setf patch (list :terminal-width new-width
                                :terminal-height new-height
                                ;; Potentially adjust viewport height based on terminal height
                                ;; For now, keep it fixed as per style
                                )))))))
      (values patch commands)))
  :view-fn
  (lambda (app-state)
    (viewport :id :my-scrollable-container
              :style-id :viewport ; Use style ID from stylesheet
              :content-offset-y (getf app-state :scroll-offset-y 0)
              ;; :content-height could be calculated if needed for precise scrollbar
              (vbox :id :main-content-container :style-id :container
                    (label :id :box1 :style-id '(:box :box-red) :text (format nil "Box 1: Red Border~%This is Box 1 with a red border.~%Line 2 of Box 1~%Line 3 of Box 1~%Line 4 of Box 1~%Line 5 of Box 1"))
                    (label :id :box2 :style-id '(:box :box-green) :text (format nil "Box 2: Green Border~%This is Box 2 with a green border.~% This box is a bit wider.~%And also has five lines.~%To test scrolling properly.~%The fifth line is here."))
                    (label :id :box3 :style-id '(:box :box-blue) :text (format nil "Box 3: Blue Border~%This is Box 3 with a blue border.~%With a styled border.~%Content flows within.~%Making it all scrollable."))
                    (label :id :box4 :style-id :box :text "Box 4: Standard")
                    (label :id :box5 :style-id :box :text (format nil "Box 5: More Content~%L1~%L2~%L3~%L4~%L5~%L6~%L7~%L8~%L9~%L10"))
                    (label :id :box6 :style-id '(:box :box-red) :text "Box 6: Another Red Box")
                    (label :id :box7 :style-id '(:box :box-green) :text "Box 7: Another Green Box")
                    (label :id :box8 :style-id :box :text "Box 8: Standard")
                    (label :id :box9 :style-id :box :text "Box 9: Standard")
                    (label :id :box10 :style-id :box :text "Box 10: Standard")
                    (label :id :box11 :style-id :box :text "Box 11: Standard")
                    (label :id :box12 :style-id :box :text "Box 12: Standard to make it scroll more"))))
  :command-processor-fn nil
  :event-translator-fn nil
  :quit-flag-path '(:should-quit)
  :style-sheet-path '(:current-stylesheet))

;;;--------------------------------------------------------------
;;; Main Entry Point
;;;--------------------------------------------------------------
(defun main ()
  "Run the boxes example application."
  (run-application #'boxes-app))

(defun run-boxes-example-app ()
  "Alias to run the boxes example application."
  (main))

;; To run from SLIME:
;; (ql:quickload :elmtui.examples.boxes-app)
;; (elmtui.examples.boxes-app:main)
