;;;===============================================================
;;; File: src/ui/widgets/label.lisp
;;; Standardized Elm-style Label Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.label
  (:use :cl :elmtui.ui.defcomponent)
  (:import-from :elmtui.ui.api #:id-from-path #:component) ; Keep only used API functions
  (:import-from :elmtui.tea-state.api #:app-state #:make-update-result) ; Keep app-state and make-update-result
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:export #:label)) ; Export only the component name

(in-package :elmtui.ui.widgets.label)

;; Define component with its state properties
(defcomponent label ()
  (:state
   (text "Label" :type string :documentation "The text content of the label."
                 :initarg :text :accessor label-text)
   (for nil :type (or null string symbol) :documentation "The ID of the component this label is for."
            :initarg :for :accessor label-for))
  (:documentation "A text label widget, refactored to the new defcomponent style.")
  (:on-unhandled-message :log) ; Or :no-op if strictly static

  (:init (props self-id-path)
         ;; (declare (ignore self-id-path))
         ;; The :initargs :text and :for (if provided to make-instance) will be handled by defcomponent's
         ;; default initarg processing. This inline :init can still override or supplement.
         ;; Here, we allow :initial-text and :initial-for as aliases from props.
         (values `(:text ,(getf props :text (getf props :initial-text "Label"))
                   :for ,(getf props :for (getf props :initial-for nil)))
                 nil))

  (:update (message local-state app-state self-id-path)
                                        ; local-state is used implicitly by handlers
           (:set-text (new-text)
                      (values `(:text ,new-text) nil))
           (:set-for (new-for-target)
                     (values `(:for ,new-for-target) nil)))

  (:view (local-state app-state self-id-path children)
         ;; (declare (ignore app-state))
                                        ; app-state not directly used in this simple view
         (let* ((component-id (id-from-path self-id-path))
                (text (getf local-state :text "Label"))
                (for-target (getf local-state :for))
                (props `(:id ,component-id
                         :text-content ,text
                         :aria-role "label"
                         ,@(when for-target `(:label-for ,for-target)))))
           (list :drawable-content
                 :type :drawable-content
                 :props props
                 :children nil))))

;; To make a label instance: (make-instance 'label :id :my-label :text "My Label Text" :for :my-input-id)
