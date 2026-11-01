;;;; examples/tea-counter-component.lisp
;;;; A deftea-app counter that hosts a defcomponent display child.
;;;;
;;;; Demonstrates:
;;;;   - deftea-app with :root-component-dsl hosting a defcomponent
;;;;   - elmtui:app-model to read the user model from component code
;;;;   - Transition logic in deftea-app, presentation in a component
;;;;
;;;; Run:  (elmtui.examples.tea-counter-component:run-tea-counter-component)

(uiop:define-package :elmtui.examples.tea-counter-component
  (:use :cl)
  (:import-from :elmtui.app.tea-core #:deftea-app #:app-model)
  (:import-from :elmtui.app #:key-pressed-p #:quit-requested-p)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.ui.api #:component #:id-from-path)
  (:export #:run-tea-counter-component))

(in-package :elmtui.examples.tea-counter-component)

;;; ===================================================================
;;; Component: count-display
;;; A reusable display component that reads the app model to show the
;;; current count with simple formatting.
;;; ===================================================================

(defcomponent count-display (component)
  (:state
    (prefix "Count" :type string :documentation "Label prefix"))
  (:view (local-state app-state id-path children)
    (let* ((model (app-model app-state))
           (count (if model (getf model :count 0) 0))
           (prefix (getf local-state :prefix "Count")))
      `(:container :id ,(id-from-path id-path)
         :style (:display :block :width 40 :height 3
                  :padding 1 :bg-color :black :fg-color :white)
         :children
         ((:text :id :count-text
            :content ,(format nil "~A: ~A  [+/-/q]" prefix count)))))))

;;; ===================================================================
;;; deftea-app: counter logic
;;; ===================================================================

(defun counter-init ()
  "Return the initial counter model and no startup commands."
  (values (list :count 0 :should-quit nil) nil))

(defun counter-transition (msg model)
  "Process key messages: +/- to inc/dec, q/Ctrl-C to quit."
  (cond
    ((or (quit-requested-p msg) (key-pressed-p msg :char #\q))
     (values (list :count (getf model :count 0) :should-quit t) nil))
    ((key-pressed-p msg :char #\+)
     (values (list :count (1+ (getf model :count 0))) nil))
    ((key-pressed-p msg :char #\-)
     (values (list :count (1- (getf model :count 0))) nil))
    (t (values model nil))))

(defun counter-view (model)
  "Fallback view (unused when :root-component-dsl is provided)."
  (declare (ignore model))
  '(:text :id :fallback :content "view not used"))

;;; ===================================================================
;;; Application definition
;;; ===================================================================

(deftea-app tea-counter-component
  :init       #'counter-init
  :transition #'counter-transition
  :view       #'counter-view
  :root-component-dsl '(:root-viewport :id :root-viewport
                         :anchor :below-cursor :height 5
                         :children
                         ((:count-display :id :display
                           :initial-prefix "Counter"))))
