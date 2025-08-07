;;;===============================================================
;;; File: examples/mini-rainbow.lisp
;;;
;;; Description: A minimal example demonstrating a 7x7 rainbow-colored
;;; box that spawns below the cursor.
;;;===============================================================

(uiop:define-package :elmtui.examples.mini-rainbow
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.style-lib.styles #:rgb)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.tea-state.api #:make-update-result)
  (:export #:run-mini-rainbow))

(in-package :elmtui.examples.mini-rainbow)

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
    :style (:width 7 :height 7)
    :children
    ,(loop for i from 0 below 7
           collect
           `(:container
             :id ,(intern (format nil "ROW-~D" i) :keyword)
             :style (:width 7 :height 1 :display :flex :flex-direction :row)
             :children
             ,(loop for j from 0 below 7
                    collect
                    `(:container
                      :id ,(intern (format nil "CELL-~D-~D" i j) :keyword)
                      :style (:width 1 :height 1
                              :bg-color ,`(,(random 256) ,(random 256) ,(random 256)))))))))

(defapplication mini-rainbow
  :root-component-dsl
  `(:root-viewport
    :initial-terminal-dimensions (1 1)
    :initial-cursor-pos (1 1)
    :id :root
    :anchor :below-cursor
    :child-dsl-spec (:view (view nil)))
  :update-fn 'app-update
  :view-fn #'view
  :root-viewport-id :root
  :initial-state-plist '(:should-quit nil))

;; (defun run-mini-rainbow ()
;;   "Run the mini-rainbow example."
;;   (elmtui.app.api:run-application (make-instance 'mini-rainbow)))
