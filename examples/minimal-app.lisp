(uiop:define-package :elmtui.examples.minimal
  (:use :cl :log4cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.tea-state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.core.event-types #:key-event)
  (:export #:run-minimal))

(in-package :elmtui.examples.minimal)

(defun minimal-view (state)
  (log-info "minimal:> Rendering view with state: ~S" state)
  (let ((key (or (state-ref state :last-key) "-")))
    `(:container
       :id :root
       :style (:display :block :width 20 :height 3
                :padding 1
                :bg-color :black :fg-color :white)
       :children
       ((:text :id :label
          :content ,(format nil "Hello ~A" key))))))

(defun minimal-update (msg state)
  (declare (ignore state))
  (log-info "minimal:> Received message: ~S" msg)
  (cond
    ((eq (car msg) :keyevent)
      (let ((ch (getf (cdr msg) :key "whoops")))
        (log-info "minimal:> car-msg-Key event received: ~S" ch)
        
        (make-update-result :patches `(((:last-key) ,ch)))))
    ((typep msg 'key-event)
      (let* ((ch (or (elmtui.core.event-types:key-event-char msg)
                   (elmtui.core.event-types:key-event-key msg))))
        (log-info "minimal:> Key event received: ~S" ch)
        (make-update-result :patches `(((:last-key) ,ch)))))
    ((and (listp msg) (eq (first msg) :app-quit-requested))
      (progn
        (log-info "minimal:> Quit requested")
        (make-update-result :patches '(((:should-quit) t)))))
    (t (make-update-result))))

(defapplication minimal
  :root-component-dsl
  '(:root-viewport :id :minimal-root :anchor :below-cursor :child-dsl-spec (:view nil))
  :view-fn #'minimal-view
  :update-fn #'minimal-update
  :root-viewport-id :minimal-root
  :initial-state-plist (list :should-quit nil :last-key "slurp"))

