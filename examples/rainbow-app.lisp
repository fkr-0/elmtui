;;;===============================================================
;;; File: examples/rainbow-app.lisp
;;; Example application demonstrating colored vertical stripes
;;; using stylesheets and flexbox, quitting on any key press.
;;; Adapted to modern app design with defapplication.
;;;===============================================================
(uiop:define-package :elmtui.examples.rainbow-app
  (:use :cl :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.app.api #:get-component-instance)
  (:import-from :elmtui.ui.api #:update)
  (:import-from :cl-styles.api #:defrule #:defstylesheet #:rgb)
  (:import-from :cl-styles.selector #:cls> #:type>)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
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
(defun app-update (message app-state)
  "Handles updates to the application state based on messages."
  (log-info "Rainbow: RECEIVED MESSAGE: ~S" message)
  (cond
    ((and (typep message 'key-event)
          (member (elmtui.core.event-types:key-event-key message)
                  '(:q :escape :esc #\q #\Q) :test #'eql))
      (make-update-result :patches '(((:should-quit) t))))
    ((typep message 'key-event)
      (let* ((current-count (state-ref app-state :switch-count 0))
              (new-count (1+ current-count)))
        (if (>= new-count 15)
          (make-update-result :patches `(((:should-quit) t)))
          (let ((new-orientation (if (eql (state-ref app-state :orientation) :row)
                                   :column
                                   :row)))
            (make-update-result :patches `(((:switch-count) ,new-count)
                                            ((:orientation) ,new-orientation)))))))
    ((and (listp message) (eq (first message) :app-quit-requested))
      (make-update-result :patches `(((:should-quit) t))))
    (t
      (make-update-result))))

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


(defun rainbow-content-view (state)
  "Paint visible color bands rather than blank background-only cells."
  (let ((orientation (state-ref state :orientation :row))
        (colors (mapcar #'third rainbow-colors-with-names)))
    `(:container :id :rainbow-content
       :style (:display :flex :flex-direction :column :width 68 :height 14)
       :children
       ((:text :id :rainbow-heading :content "CHROMATIC / 08  |  Space rotate  |  Q quit"
               :style (:fg-color :cyan :bold t))
        (:text :id :rainbow-state :content ,(format nil "Layout: ~A" orientation))
        (:container :id :rainbow-bands
           :style (:display :flex
                   :flex-direction ,(if (eq orientation :row) :row :column)
                   :width 64 :height 10)
           :children
           ,(loop for color in colors for index from 0
                  collect `(:text
                             :id ,(intern (format nil "RAINBOW-BAND-~D" index) :keyword)
                             :content ,(if (eq orientation :row) "██████"
                                           (make-string 60 :initial-element #\#))
                             :style (:fg-color ,(cons :rgb color)
                                     :height ,(if (eq orientation :row) 10 1)
                                     :width ,(if (eq orientation :row) 6 60)))))))))

(defun rainbow-app-subscriptions (model)
  (declare (ignore model))
  (log-debug "RAINBOW-APP: Subscriptions function called.")
  nil)

;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------
(defun %rainbow-initial-state ()
  (list :current-stylesheet nil
        :should-quit nil
        :orientation :row
        :switch-count 0))

(defapplication rainbow-example-app
  :root-viewport-id :rainbow-root-vp
  :initial-state-fn #'%rainbow-initial-state
  ;; :root-component-dsl `(:column)
  :root-component-dsl '(:root-viewport :id :rainbow-root-vp :anchor :below-cursor :width 70 :height 14 :blank-on-exit t :child-dsl-spec (:view nil))

  :update-fn 'app-update
  :view-fn 'rainbow-content-view)

;; (elmtui.view.dsl:dsl->ui-node (elmtui.app::maybe-wrap-with-root-viewport
;;                                (funcall 'rainbow-content-view (elmtui.state:make-application-state)) :root-id
;;                                ':rainbow-root-vp)(elmtui.state:make-application-state))

;; (let* ((o (elmtui.view.dsl:render-dsl-to-resolved-tree
;;             '(:ROOT-VIEWPORT :ID :RAINBOW-ROOT-VP :INITIAL-TERMINAL-DIMENSIONS (1 1)
;;                :INITIAL-CURSOR-POS (1 1) :CHILDREN
;;                (:CONTAINER :STYLE :ID :SWIBBLE
;;                  (:DISPLAY :FLEX :FLEX-DIRECTION :ROW :HEIGHT :FILL :WIDTH :FILL) :CHILDREN
;;                  ((:CONTAINER :ID :STRIPE-RED :CLASSES ("red-stripe") :STYLE
;;                     (:WIDTH :FILL :HEIGHT :FILL :MIN-WIDTH 10 :FG-COLOR (255 0 0) :BG-COLOR
;;                       (255 0 0)))
;;                    (:CONTAINER :ID :STRIPE-PINK :CLASSES ("pink-stripe") :STYLE
;;                      (:WIDTH :FILL :HEIGHT :FILL :MIN-WIDTH 10 :FG-COLOR (255 192 203) :BG-COLOR
;;                        (255 192 203)))
;;                    (:CONTAINER :ID :STRIPE-ORANGE :CLASSES ("orange-stripe") :STYLE
;;                      (:WIDTH :FILL :HEIGHT :FILL :MIN-WIDTH 10 :FG-COLOR (255 165 0) :BG-COLOR
;;                        (255 165 0)))
;;                    (:CONTAINER :ID :STRIPE-YELLOW :CLASSES ("yellow-stripe") :STYLE
;;                      (:WIDTH :FILL :HEIGHT :FILL :MIN-WIDTH 10 :FG-COLOR (255 255 0) :BG-COLOR
;;                        (255 255 0)))
;;                    (:CONTAINER :ID :STRIPE-GREEN :CLASSES ("green-stripe") :STYLE
;;                      (:WIDTH :FILL :HEIGHT :FILL :MIN-WIDTH 10 :FG-COLOR (0 255 0) :BG-COLOR
;;                        (0 255 0)))
;;                    (:CONTAINER :ID :STRIPE-BLUE :CLASSES ("blue-stripe") :STYLE
;;                      (:WIDTH :FILL :HEIGHT :FILL :MIN-WIDTH 10 :FG-COLOR (0 0 255) :BG-COLOR
;;                        (0 0 255)))
;;                    (:CONTAINER :ID :STRIPE-INDIGO :CLASSES ("indigo-stripe") :STYLE
;;                      (:WIDTH :FILL :HEIGHT :FILL :MIN-WIDTH 10 :FG-COLOR (75 0 130) :BG-COLOR
;;                        (75 0 130)))
;;                    (:CONTAINER :ID :STRIPE-VIOLET :CLASSES ("violet-stripe") :STYLE
;;                      (:WIDTH :FILL :HEIGHT :FILL :MIN-WIDTH 10 :FG-COLOR (238 130 238) :BG-COLOR
;;                        (238 130 238)))))) (elmtui.state:make-application-state)))
;;         (r (getf (cdr o)
;;              :resolved-view)))r)
;;         (i (getf (cdr (elmtui.view.dsl:render-dsl-to-resolved-tree r (elmtui.state:make-application-state)))
;;              :resolved-view))
;;         (j (elmtui.view.dsl:render-dsl-to-resolved-tree i (elmtui.state:make-application-state))))
;; (elmtui.view.dsl:render-dsl-to-resolved-tree r (elmtui.state:make-application-state))
;; (elmtui.utils:as :styled-ui-node
;;                    r)
;; j)

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
;; (elmtui.style-lib.api:make-style-set :styles (getf (cdr (car (getf (cdr `(:container
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
;;                      :bg-color ,(rgb rgb-val)))))) :children))) :style))
;; `(:container
;;   :style (:display :flex :flex-direction :row :height :fill :width :fill)
;;   :children
;;   ,(loop for (color-name class-name rgb-val) in rainbow-colors-with-names
;;          collect
;;          `(:container
;;            :id ,(intern (format nil "STRIPE-~A" (string color-name)) :keyword)
;;            :classes (,class-name)
;;            :style (:width :fill
;;                    :height :fill
;;                    :min-width 10
;;                    :fg-color ,(rgb rgb-val)
;;                    :bg-color ,(rgb rgb-val)))))
