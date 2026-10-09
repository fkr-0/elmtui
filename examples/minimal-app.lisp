(uiop:define-package :elmtui.examples.minimal
  (:use :cl :log4cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.core.event-types #:key-event)
  (:export #:run-minimal))

(in-package :elmtui.examples.minimal)

(defun minimal-view (state)

  (let ((key (or (state-ref state :last-key) "-")))
    `(:container
       :id :root
       :style (:display :block :width 20 :height 3
                :padding 1
                :bg-color :black :fg-color :white)
       :children
       ((:text :id :label
          :content ,(format nil "Hello ~A" key))))))

(defun minimal-update (msg app-state)
  (declare (ignore app-state))

  (cond
    ((and (consp msg) (eq (car msg) :keyevent))
      (let ((ch (getf (cdr msg) :key "whoops")))


        (make-update-result :patches
          `(((:last-key) ,(if (characterp ch) (char-upcase ch) ch))))))
    ((typep msg 'key-event)
      (let* ((ch (or (elmtui.core.event-types:key-event-char msg)
                   (elmtui.core.event-types:key-event-key msg))))

        (make-update-result :patches `(((:last-key) ,(if (characterp ch) (char-upcase ch) ch))))))
    ((and (listp msg) (eq (first msg) :app-quit-requested))
      (progn

        (make-update-result :patches '(((:should-quit) t)))))
    (t (make-update-result))))

(defun %minimal-initial-state ()
  (list :should-quit nil :last-key "slurp"))

(defapplication minimal
  :root-component-dsl
  '(:root-viewport :id :minimal-root :anchor :below-cursor :child-dsl-spec (:view nil))
  :view-fn #'minimal-view
  :update-fn #'minimal-update
  :root-viewport-id :minimal-root
  :initial-state-fn #'%minimal-initial-state)

