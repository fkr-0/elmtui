(uiop:define-package :elmtui.examples.root-viewport-test-app
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.app.api #:run-application)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.core.event-types #:key-event #:key-event-key)
  (:export #:main #:run-root-viewport-test-app))

(in-package :elmtui.examples.root-viewport-test-app)

(defconstant +rect-width+ 10)
(defconstant +rect-height+ 5)
(defparameter +rect-color+ '(0 255 0))

(defun root-viewport-test-update (message app-state)
  (let* ((x (state-ref app-state :offset-x 10))
         (y (state-ref app-state :offset-y 5)))
    (labels ((move (nx ny)
               (make-update-result :patches `(((:offset-x) ,(max 0 nx))
                                              ((:offset-y) ,(max 0 ny)))))
             (quit ()
               (make-update-result :patches '(((:should-quit) t)))))
      (cond
        ((typep message 'key-event)
         (case (key-event-key message)
           (:left (move (1- x) y))
           (:right (move (1+ x) y))
           (:up (move x (1- y)))
           (:down (move x (1+ y)))
           ((#\q #\Q :escape) (quit))
           (t (make-update-result))))
        ((and (listp message) (eq (first message) :app-quit-requested))
         (quit))
        (t
         (make-update-result))))))

(defun root-viewport-test-view (app-state)
  (let ((x (state-ref app-state :offset-x 10))
        (y (state-ref app-state :offset-y 5)))
    `(:container :id :rv-root :style (:display :flex :flex-direction :column)
      :children
      ((:text :id :help :content "Arrows move the block, q/Esc quits")
       (:container :id :moving-rect
        :style (:offset-x ,x :offset-y ,y :width ,+rect-width+ :height ,+rect-height+ :bg-color ,+rect-color+))))))

(defapplication root-viewport-test-app
  :root-viewport-id :movable-root-vp
  :initial-state-plist '(:offset-x 10 :offset-y 5 :should-quit nil)
  :root-component-dsl '(:layout :id :rv-root)
  :update-fn #'root-viewport-test-update
  :view-fn #'root-viewport-test-view)

(defun main ()
  (run-root-viewport-test-app))
