;;;===============================================================
;;; File: examples/mini-rainbow.lisp
;;;
;;; Description: A minimal example demonstrating a 7x7 rainbow-colored
;;; box that spawns below the cursor.
;;;===============================================================

(uiop:define-package :elmtui.examples.mini-rainbow
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :cl-styles.api #:rgb #:defrule #:defstylesheet #:cls> #:type>)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.tea-state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.tea-state.api #:make-update-result)
  (:export #:run-mini-rainbow))

(in-package :elmtui.examples.mini-rainbow)
(defparameter rainbow-stylesheet
  (defstylesheet
    ;; Container base style
    (defrule (type> :container)
      :display :block
      :box :single
      :gap 0
      :width 1
      :height 1)
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
      2
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
      3
      :HEIGHT
      1)
    (DEFRULE (CLS> "indigo-stripe")
      :BG-COLOR
      (list 75 0 130)
      :WIDTH
      3
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
(defun app-update (message app-state)
  (declare (ignore message app-state))
  ;; (if (typep message 'key-event)
  ;;     (make-update-result :patches '((:should-quit . t)))
  ;;     (make-update-result))
  (make-update-result)
  )

(defun view (app-state)
  (declare (ignore app-state))
  `(:container
    :id :main
    :style (:box :ascii :width :auto :height 34 :display :block
            :fg-color ,`(,(random 256) ,(random 256) ,(random 256))
                                        ; :bg-color ,`(,(random 256) ,(random 256) ,(random 256))
            :display :flex :flex-direction :column
            :padding 0
            :margin 0
            :spacing 0
            :gap 0
            :border-style :double :border-width 1 )
    :children
    ,(loop for i from 0 below 7
           collect
           `(:container
             :id ,(intern (format nil "ROW-~D" i) :keyword)
             :style (:box :ascii
                                        ;:min-height :auto
                     :height 3
                     :min-height 3
                     :width :fill
                     :min-width 3
                     :border-style :ascii :border-width 1
                     :display :flex :flex-direction :row
                     :bg-color ,`(,(random 256) ,(random 256) ,(random 256))
                     :fg-color ,`(,(random 256) ,(random 256) ,(random 256)))
             :children
             ,(loop for j from 0 below 7
                    collect
                    `(:container
                      :id ,(intern (format nil "CELL-~D-~D" i j) :keyword)
                      :style (:width 1 :height 1
                              :min-width 1
                              :min-height 1
                              :display :flex :flex-direction :column
                              ;; :display :block
                              ;; :border-style :double :border-width 1
                              ;; :box :ascii
                                        ;:min-height 0
                              :fg-color ,`(,(random 256) ,(random 256) ,(random 256))
                              :bg-color ,`(,(random 256) ,(random 256) ,(random 256)))))))))

(defapplication mini-rainbow
  :root-component-dsl
  `(:root-viewport
    :initial-terminal-dimensions (1 1)
    :initial-cursor-pos (1 1)
    :id :root
    :anchor :below-cursor
    :child-dsl-spec (:view ,(view nil)))
  :update-fn 'app-update
  ;; :stylesheet rainbow-stylesheet
  :view-fn #'view
  :root-viewport-id :root
  :initial-state-plist (list :current-stylesheet rainbow-stylesheet
                             :should-quit nil
                             :orientation :row
                             :switch-count 0))

;; (defun run-mini-rainbow ()
;;   "Run the mini-rainbow example."
;;   (elmtui.app.api:run-application (make-instance 'mini-rainbow)))
