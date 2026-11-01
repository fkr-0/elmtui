;;;; examples/tea-destructured-init.lisp
;;;; A deftea-app that hosts a defcomponent using the new destructured
;;;; :init syntax.
;;;;
;;;; Demonstrates:
;;;;   - defcomponent with (:init ((name &key style) id-path) ...)
;;;;   - Props are destructured from the plist automatically
;;;;   - Keyword defaults provide fallback values
;;;;
;;;; Run:  (elmtui.examples.tea-destructured-init:run-tea-destructured-init)

(uiop:define-package :elmtui.examples.tea-destructured-init
  (:use :cl)
  (:import-from :elmtui.app.tea-core #:deftea-app #:app-model)
  (:import-from :elmtui.app #:key-pressed-p #:quit-requested-p)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.ui.api #:component #:id-from-path)
  (:export #:run-tea-destructured-init))

(in-package :elmtui.examples.tea-destructured-init)

;;; ===================================================================
;;; Component: greeting-card
;;; Uses destructured :init to extract :name and :style from props.
;;; ===================================================================

(defcomponent greeting-card (component)
  (:state
    (name "World" :type string :documentation "Name to greet")
    (style :normal :documentation "Display style: :normal or :bold")
    (greeting-count 0 :type integer :documentation "Times greeted"))

  (:init ((name &key (style :normal)) self-id-path)
    ;; name and style are extracted from the props plist automatically.
    ;; No (getf props :name) needed.
    (values `(:name ,(or name "World")
              :style ,style
              :greeting-count 0)
            nil))

  (:update (msg local-state app-state id-path)
    (:greet ()
      (values `(:greeting-count ,(1+ (getf local-state :greeting-count 0)))
              nil)))

  (:view (local-state app-state id-path children)
    (let* ((name (getf local-state :name "World"))
           (style-kw (getf local-state :style :normal))
           (count (getf local-state :greeting-count 0))
           (model (app-model app-state))
           (mood (if model (getf model :mood "happy") "happy")))
      `(:container :id ,(id-from-path id-path)
         :style (:display :block :width 50 :height 4 :padding 1
                  :bold ,(eq style-kw :bold)
                  :bg-color :black :fg-color :green)
         :children
         ((:text :id :greeting
            :content ,(format nil "Hello, ~A! (~A, greeted ~D time~:P) [g/q]"
                        name mood count)))))))

;;; ===================================================================
;;; deftea-app: mood toggler
;;; ===================================================================

(defun mood-init ()
  (values (list :mood "happy" :should-quit nil) nil))

(defun mood-transition (msg model)
  (cond
    ((or (quit-requested-p msg) (key-pressed-p msg :char #\q))
     (values (list :mood (getf model :mood) :should-quit t) nil))
    ((key-pressed-p msg :char #\g)
     ;; Cycle mood
     (let ((next (if (string= (getf model :mood) "happy") "excited" "happy")))
       (values (list :mood next) nil)))
    (t (values model nil))))

(defun mood-view (model)
  (declare (ignore model))
  '(:text :id :fallback :content "view not used"))

;;; ===================================================================
;;; Application definition
;;; ===================================================================

(deftea-app tea-destructured-init
  :init       #'mood-init
  :transition #'mood-transition
  :view       #'mood-view
  :root-component-dsl '(:root-viewport :id :root-viewport
                         :anchor :below-cursor :height 6
                         :children
                         ((:greeting-card :id :card
                           :initial-name "Lisper"
                           :initial-style :bold))))
