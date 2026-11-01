;;;; examples/tea-list-detail.lisp
;;;; A deftea-app that manages a list of items, with a defcomponent
;;;; rendering the detail view for the selected item.
;;;;
;;;; Demonstrates:
;;;;   - deftea-app managing list state (selection, items)
;;;;   - A defcomponent reading app-model to render selected-item detail
;;;;   - Separation of concerns: navigation in transition, display in component
;;;;
;;;; Run:  (elmtui.examples.tea-list-detail:run-tea-list-detail)

(uiop:define-package :elmtui.examples.tea-list-detail
  (:use :cl)
  (:import-from :elmtui.app.tea-core #:deftea-app #:app-model)
  (:import-from :elmtui.app #:key-pressed-p #:quit-requested-p)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.ui.api #:component #:id-from-path)
  (:export #:run-tea-list-detail))

(in-package :elmtui.examples.tea-list-detail)

;;; ===================================================================
;;; Data
;;; ===================================================================

(defparameter +items+
  '((:name "Apples"   :desc "Crisp and sweet, good for pies.")
    (:name "Bananas"  :desc "Rich in potassium, great snack.")
    (:name "Cherries" :desc "Small, red, perfect for desserts.")
    (:name "Dates"    :desc "Naturally sweet, energy-dense.")
    (:name "Figs"     :desc "Soft, jammy, pairs with cheese."))
  "The list of items to browse.")

;;; ===================================================================
;;; Component: detail-panel
;;; Reads the app model to display the currently selected item.
;;; ===================================================================

(defcomponent detail-panel (component)
  (:state
    (header "Detail" :type string))
  (:view (local-state app-state id-path children)
    (let* ((model  (app-model app-state))
           (items  (if model (getf model :items +items+) +items+))
           (idx    (if model (getf model :selected 0) 0))
           (item   (nth idx items))
           (name   (if item (getf item :name "???") "???"))
           (desc   (if item (getf item :desc "")    "")))
      `(:container :id ,(id-from-path id-path)
         :style (:display :block :width 50 :height 4 :padding 1
                  :bg-color :black :fg-color :cyan)
         :children
         ((:text :id :detail-name :content ,(format nil ">> ~A" name))
          (:text :id :detail-desc :content ,(format nil "   ~A" desc)))))))

;;; ===================================================================
;;; deftea-app: list navigation
;;; ===================================================================

(defun list-init ()
  (values (list :items +items+
                :selected 0
                :should-quit nil)
          nil))

(defun list-transition (msg model)
  (let* ((items (getf model :items))
         (sel   (getf model :selected 0))
         (len   (length items)))
    (cond
      ((or (quit-requested-p msg) (key-pressed-p msg :char #\q))
       (values (list :items items :selected sel :should-quit t) nil))
      ((or (key-pressed-p msg :key :down) (key-pressed-p msg :char #\j))
       (values (list :items items :selected (mod (1+ sel) len)) nil))
      ((or (key-pressed-p msg :key :up) (key-pressed-p msg :char #\k))
       (values (list :items items :selected (mod (1- sel) len)) nil))
      (t (values model nil)))))

(defun list-view (model)
  "Render a simple list with a selection cursor."
  (let* ((items (getf model :items))
         (sel   (getf model :selected 0)))
    `(:container :id :list-root
       :style (:display :block :width 50 :height ,(+ 2 (length items))
                :bg-color :black :fg-color :white)
       :children
       ,(loop for item in items
              for i from 0
              collect `(:text :id ,(intern (format nil "ITEM-~D" i) :keyword)
                         :content ,(format nil "~A ~A"
                                    (if (= i sel) ">" " ")
                                    (getf item :name)))))))

;;; ===================================================================
;;; Application definition
;;; ===================================================================

(deftea-app tea-list-detail
  :init       #'list-init
  :transition #'list-transition
  :view       #'list-view
  :root-component-dsl '(:root-viewport :id :root-viewport
                         :anchor :below-cursor :height 12
                         :children
                         ((:detail-panel :id :detail
                           :initial-header "Selected Item"))))
