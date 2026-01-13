(uiop:define-package :elmtui.ui.transaction-controls
  (:use :cl :alexandria)
  (:import-from :elmtui.view.core #:make-node)
  (:import-from :elmtui.ui.widgets.button #:make-button)
  (:import-from :elmtui.state.api
                #:application-state-history
                #:application-state-undone)
  (:export #:view-transaction-controls
           ;; Messages that these controls might dispatch
           #:msg-undo-last
           #:msg-redo-last
           #:msg-undo-category
           #:msg-selective-undo))
(in-package :elmtui.ui.transaction-controls)

;; Define message types (keywords for simplicity)
(defparameter msg-undo-last :undo-last-transaction)
(defparameter msg-redo-last :redo-last-transaction)
(defparameter msg-undo-category :undo-transaction-category) ; Payload: (:category <keyword>)
(defparameter msg-selective-undo :selective-undo-transaction) ; Payload: (:id <integer>)

(defun view-transaction-controls (id &key app-state (default-can-undo t) (default-can-redo t) available-categories)
  "Renders basic transaction control buttons.
   ID: A unique ID for the control group.
   APP-STATE: The current application state (used to determine if undo/redo is possible).
   DEFAULT-CAN-UNDO, DEFAULT-CAN-REDO: Fallback if app-state is not provided.
   AVAILABLE-CATEGORIES: A list of keywords representing categories that can be undone.

   Returns a UI node tree for the controls."
  (let ((can-undo (if app-state
                      (not (null (application-state-history app-state)))
                      default-can-undo))
        (can-redo (if app-state
                      (not (null (application-state-undone app-state)))
                      default-can-redo)))
    (make-node :row
               :id id
               :properties '(:gap 1)
               :children
               (append
                (list
                 (make-button :id (symbolicate id '-undo)
                              :label "Undo"
                              :on-click msg-undo-last
                              :disabled (not can-undo))
                 (make-button :id (symbolicate id '-redo)
                              :label "Redo"
                              :on-click msg-redo-last
                              :disabled (not can-redo)))
                ;; Add buttons for undoing categories if any are provided
                (when available-categories
                  (loop for category in available-categories
                        collect (make-button :id (symbolicate id '-undo-category- category)
                                             :label (format nil "Undo ~A" (string-capitalize category))
                                             :on-click `(,msg-undo-category (:category ,category))
                                             :disabled (not can-undo))))))))

;; Example of how this might be used in an app's view function:
;; (view-transaction-controls :my-tx-controls
;;                            :app-state *app-state*
